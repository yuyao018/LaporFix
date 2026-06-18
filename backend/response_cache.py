"""
response_cache.py
-----------------
Dual-layer vector search with cached responses optimization.

This module implements a response caching layer that stores successfully generated
LLM responses as embeddings, allowing semantic search for similar queries before
falling back to the full RAG pipeline.

Architecture:
  1. Query comes in → Search cached responses first (cosine similarity > 0.92)
  2. If cache hit → Return pre-generated response immediately
  3. If cache miss → Fall back to standard RAG (retrieve docs → LLM)
  4. After successful LLM generation → Cache the query-response pair

Benefits:
  - Reduced latency for recurring questions
  - Lower API token usage
  - Consistent answers for similar queries
"""

import logging
from typing import Optional, Dict
from datetime import datetime
import numpy as np

logger = logging.getLogger(__name__)

# Similarity threshold for cache hits (0.92 = very high similarity)
CACHE_HIT_THRESHOLD = 0.92

# Maximum cache size (prevent unbounded growth)
MAX_CACHE_SIZE = 1000


class ResponseCache:
    """
    Manages cached question-response pairs using vector embeddings
    for semantic similarity search.
    """

    def __init__(self, embedding_model, chroma_client=None):
        """
        Initialize the response cache.

        Args:
            embedding_model: The embedding model instance (e.g., OllamaEmbeddings)
            chroma_client: Optional ChromaDB client for persistent storage
        """
        self.embedding_model = embedding_model
        self.chroma_client = chroma_client
        self.collection = None
        self.cache_hits = 0
        self.cache_misses = 0

        self._init_cache_collection()

    def _init_cache_collection(self):
        """Initialize ChromaDB collection for cached responses."""
        if self.chroma_client is None:
            logger.warning("No ChromaDB client provided, response cache disabled")
            return

        try:
            # Create or get the cached responses collection
            self.collection = self.chroma_client.get_or_create_collection(
                name="cached_responses",
                metadata={
                    "description": "Cached LLM responses for semantic query matching",
                    "threshold": CACHE_HIT_THRESHOLD,
                }
            )
            logger.info(
                f"✅  Response cache initialized with {self.collection.count()} cached responses"
            )
        except Exception as e:
            logger.error(f"Failed to initialize response cache: {e}")
            self.collection = None

    def search(self, query: str) -> Optional[Dict]:
        """
        Search for a cached response using semantic similarity.

        Args:
            query: User's question

        Returns:
            Dict with 'response' and 'metadata' if cache hit, None otherwise
        """
        if self.collection is None or self.collection.count() == 0:
            self.cache_misses += 1
            return None

        try:
            # Generate embedding for the query
            query_embedding = self._embed_text(query)

            # Search cached responses
            results = self.collection.query(
                query_embeddings=[query_embedding],
                n_results=1,
                include=["documents", "metadatas", "distances"]
            )

            # Check if we have results
            if not results or not results['documents'] or not results['documents'][0]:
                self.cache_misses += 1
                logger.debug("Cache miss: No similar cached responses found")
                return None

            # Get the most similar result
            distance = results['distances'][0][0]
            similarity = 1 - distance  # Convert distance to similarity

            logger.debug(f"Cache query similarity: {similarity:.4f} (threshold: {CACHE_HIT_THRESHOLD})")

            if similarity >= CACHE_HIT_THRESHOLD:
                self.cache_hits += 1
                response = results['documents'][0][0]
                metadata = results['metadatas'][0][0]

                logger.info(
                    f"✅  CACHE HIT (similarity: {similarity:.4f}) - "
                    f"Returning cached response (cached {metadata.get('cached_at', 'unknown')})"
                )

                return {
                    'response': response,
                    'metadata': metadata,
                    'similarity': similarity,
                    'is_cache_hit': True
                }

            # Similar but not confident enough
            self.cache_misses += 1
            logger.debug(
                f"Cache miss: Similarity {similarity:.4f} below threshold {CACHE_HIT_THRESHOLD}"
            )
            return None

        except Exception as e:
            logger.error(f"Error searching response cache: {e}")
            self.cache_misses += 1
            return None

    def store(
        self,
        query: str,
        response: str,
        metadata: Optional[Dict] = None
    ) -> bool:
        """
        Store a query-response pair in the cache.

        Args:
            query: Original user question
            response: LLM-generated answer
            metadata: Optional metadata (e.g., session_id, timestamp)

        Returns:
            True if stored successfully, False otherwise
        """
        if self.collection is None:
            return False

        # Don't cache very short responses (likely errors or incomplete)
        if len(response.strip()) < 20:
            logger.debug("Skipping cache: Response too short")
            return False

        # Check cache size limit
        if self.collection.count() >= MAX_CACHE_SIZE:
            logger.warning(
                f"Cache size limit reached ({MAX_CACHE_SIZE}), "
                "oldest entries should be pruned (not implemented yet)"
            )
            # TODO: Implement LRU eviction policy
            return False

        try:
            # Generate embedding for the query
            query_embedding = self._embed_text(query)

            # Prepare metadata
            cache_metadata = metadata or {}
            cache_metadata.update({
                "cached_at": datetime.utcnow().isoformat(),
                "query": query[:500],  # Store truncated query for debugging
                "response_length": len(response),
            })

            # Generate unique ID for this cache entry
            import hashlib
            cache_id = hashlib.md5(
                f"{query}_{datetime.utcnow().isoformat()}".encode()
            ).hexdigest()

            # Store in ChromaDB
            self.collection.add(
                ids=[cache_id],
                embeddings=[query_embedding],
                documents=[response],
                metadatas=[cache_metadata]
            )

            logger.info(
                f"💾 Cached response (cache size: {self.collection.count()}/{MAX_CACHE_SIZE})"
            )
            return True

        except Exception as e:
            logger.error(f"Failed to store response in cache: {e}")
            return False

    def _embed_text(self, text: str):
        """
        Generate embedding for text using the embedding model.

        Args:
            text: Text to embed

        Returns:
            Embedding vector as a list
        """
        try:
            # Check if using LangChain embedding model
            if hasattr(self.embedding_model, 'embed_query'):
                embedding = self.embedding_model.embed_query(text)
            # Check if using direct Ollama embeddings
            elif hasattr(self.embedding_model, '_embed'):
                embedding = self.embedding_model._embed([text])[0]
            # Check if using sentence-transformers style
            elif hasattr(self.embedding_model, 'encode'):
                embedding = self.embedding_model.encode([text])[0]
            else:
                raise ValueError("Unsupported embedding model type")

            # Ensure it's a list for ChromaDB
            if isinstance(embedding, np.ndarray):
                embedding = embedding.tolist()

            return embedding
        except Exception as e:
            logger.error(f"Failed to generate embedding: {e}")
            raise

    def get_stats(self) -> Dict:
        """
        Get cache performance statistics.

        Returns:
            Dictionary with hit rate, miss rate, and cache size
        """
        total_queries = self.cache_hits + self.cache_misses
        hit_rate = (
            self.cache_hits / total_queries * 100 if total_queries > 0 else 0.0
        )
        miss_rate = (
            self.cache_misses / total_queries * 100 if total_queries > 0 else 0.0
        )

        return {
            "cache_size": self.collection.count() if self.collection else 0,
            "max_cache_size": MAX_CACHE_SIZE,
            "cache_hits": self.cache_hits,
            "cache_misses": self.cache_misses,
            "total_queries": total_queries,
            "hit_rate_percent": round(hit_rate, 2),
            "miss_rate_percent": round(miss_rate, 2),
            "threshold": CACHE_HIT_THRESHOLD,
        }

    def clear(self) -> bool:
        """
        Clear all cached responses.

        Returns:
            True if cleared successfully, False otherwise
        """
        if self.collection is None:
            return False

        try:
            # Delete the collection and recreate it
            if self.chroma_client:
                self.chroma_client.delete_collection("cached_responses")
                self._init_cache_collection()
                logger.info("🗑️  Response cache cleared")
                return True
        except Exception as e:
            logger.error(f"Failed to clear cache: {e}")

        return False


def test_response_cache():
    """Test function to verify response cache functionality."""
    print("\n" + "="*60)
    print("RESPONSE CACHE TEST")
    print("="*60)

    # Mock embeddings for testing
    class MockEmbeddings:
        def embed_query(self, text):
            import random
            random.seed(hash(text))  # Consistent embeddings for same text
            return [random.random() for _ in range(768)]

    import chromadb
    from chromadb.config import Settings

    client = chromadb.Client(Settings(anonymized_telemetry=False))
    embeddings = MockEmbeddings()

    cache = ResponseCache(embeddings, client)

    # Test 1: Cache miss (first time)
    print("\n📌 Test 1: First query (expect miss)")
    result = cache.search("How do I report a pothole?")
    print(f"Result: {'HIT' if result else 'MISS'}")

    # Test 2: Store response
    print("\n📌 Test 2: Cache the response")
    success = cache.store(
        "How do I report a pothole?",
        "To report a pothole, open the app, tap the '+' button, and fill in the location details.",
        metadata={"model": "qwen2.5:3b"}
    )
    print(f"Cached: {success}")

    # Test 3: Cache hit (same query)
    print("\n📌 Test 3: Same query (expect hit)")
    result = cache.search("How do I report a pothole?")
    if result:
        print(f"Result: HIT (similarity: {result['similarity']:.4f})")
        print(f"Response: {result['response'][:80]}...")
    else:
        print("Result: MISS")

    # Test 4: Similar query (semantic match)
    print("\n📌 Test 4: Similar query (expect hit if similarity > 0.92)")
    result = cache.search("How can I report potholes?")
    if result:
        print(f"Result: HIT (similarity: {result['similarity']:.4f})")
    else:
        print("Result: MISS")

    # Test 5: Different query (expect miss)
    print("\n📌 Test 5: Different query (expect miss)")
    result = cache.search("How to check water cut schedule?")
    print(f"Result: {'HIT' if result else 'MISS'}")

    # Stats
    print("\n📊 Cache Statistics:")
    stats = cache.get_stats()
    for key, value in stats.items():
        print(f"   {key}: {value}")

    print("\n" + "="*60)


if __name__ == "__main__":
    test_response_cache()
