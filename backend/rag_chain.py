"""
rag_chain.py
------------
RAG chain using Ollama (qwen2.5:3b) for the LLM,
and Gemini embeddings (via ingest.py) for retrieval.

**Enhanced with Response Caching:**
- Dual-layer vector search: cached responses → knowledge base
- Semantic similarity matching for recurring queries (threshold: 0.92)
- Automatic cache ingestion after successful LLM generation

Ollama must be running locally:  ollama run qwen2.5:3b

Flow:
  user question
    → 1. Search cached responses first (semantic similarity)
    → 2. If cache hit (similarity > 0.92) → return immediately
    → 3. If cache miss → retrieve relevant docs from ChromaDB (GeminiEmbeddings)
    → 4. Build prompt with context + history + question
    → 5. qwen2.5:3b generates answer via Ollama's OpenAI-compatible API
    → 6. Cache the query-response pair for future hits
"""

import logging
from pathlib import Path
from typing import Optional

from openai import OpenAI
from langchain_core.messages import HumanMessage, AIMessage

from response_cache import ResponseCache

logger = logging.getLogger(__name__)

_DOCS_DIR = Path(__file__).resolve().parent / "docs"

CHAT_MODEL = "qwen2.5:3b"
OLLAMA_BASE_URL = "http://localhost:11434/v1"

SYSTEM_INSTRUCTION = """You are LAPI, the AI assistant for the LaporFix app for Malaysian citizens.

CRITICAL RULES:
1. ONLY use information from the "Context from knowledge base" to answer.
2. If the context does not answer the question, say: "I don't have information about that. Please check the LaporFix app or ask another question."
3. NEVER invent or guess information not in the context.
4. Keep replies under 60 words, using only short complete sentences. No bullet points. Be friendly."""

def _get_client() -> OpenAI:
    # Ollama doesn't require a real API key, but the openai SDK requires a non-empty string
    return OpenAI(api_key="ollama", base_url=OLLAMA_BASE_URL)


def _format_docs(docs) -> str:
    if not docs:
        return "No relevant documents found in the knowledge base."
    return "\n\n---\n\n".join(doc.page_content for doc in docs)


def _is_clear_history_question(question: str) -> bool:
    q = question.lower()
    if "/clear" in q:
        return True
    wants_clear = any(w in q for w in ("clear", "delete", "remove", "wipe", "erase"))
    about_history = any(
        w in q for w in ("chat history", "chat session", "conversation", "lapi history", "my chats")
    )
    return wants_clear and about_history


def _load_clear_history_doc() -> str | None:
    path = _DOCS_DIR / "clear_chat_history.txt"
    if path.exists():
        return path.read_text(encoding="utf-8")
    return None


def _build_messages(
    question: str,
    context: str,
    chat_history: list[dict],
) -> list[dict]:
    """Build the messages list for the OpenAI-compatible chat completions API."""
    messages = [{"role": "system", "content": SYSTEM_INSTRUCTION}]

    # Add chat history turns
    for msg in chat_history:
        messages.append({"role": msg["role"], "content": msg["content"]})

    # Add current question with context injected
    user_message = f"""Context from knowledge base:
{context}

Question: {question}

Reply in under 60 words using only complete sentences."""

    messages.append({"role": "user", "content": user_message})
    return messages


class RagChain:
    """
    Stateless RAG chain with dual-layer response caching.
    Accepts question + chat_history per call.
    """

    def __init__(self, vector_store, response_cache: Optional[ResponseCache] = None):
        self._vector_store = vector_store
        self._client = _get_client()
        self._response_cache = response_cache
        
        if self._response_cache:
            logger.info("✅ Response cache enabled for RAG chain")

    def invoke(self, inputs: dict) -> str:
        question: str = inputs["question"]
        chat_history: list[dict] = inputs.get("chat_history", [])
        session_id: str = inputs.get("session_id", "unknown")

        # Step 1: condense follow-up question if there's history
        standalone_question = question
        if chat_history:
            standalone_question = self._condense_question(question, chat_history)

        # Step 2: Check response cache first (dual-layer optimization)
        if self._response_cache and not chat_history:
            # Only use cache for standalone questions (not follow-ups)
            cached = self._response_cache.search(standalone_question)
            if cached and cached.get('is_cache_hit'):
                logger.info(
                    f"⚡ Cache hit! Similarity: {cached['similarity']:.4f} - "
                    f"Skipping LLM call"
                )
                return cached['response']

        # Step 3: Cache miss - retrieve relevant docs from knowledge base
        docs = self._vector_store.similarity_search(standalone_question, k=6)
        context = _format_docs(docs)

        # Ensure /clear chat history answers use the dedicated doc (avoids "clear photo" matches)
        if _is_clear_history_question(question):
            clear_doc = _load_clear_history_doc()
            if clear_doc:
                context = f"{clear_doc}\n\n---\n\n{context}"

        # Step 4: Generate answer via LLM
        messages = _build_messages(question, context, chat_history)

        response = self._client.chat.completions.create(
            model=CHAT_MODEL,
            messages=messages,
            temperature=0.3,
        )

        answer = (response.choices[0].message.content or "").strip()

        # Step 5: Cache the successful response (only for standalone questions)
        if self._response_cache and not chat_history and answer:
            self._response_cache.store(
                query=standalone_question,
                response=answer,
                metadata={
                    "session_id": session_id,
                    "model": CHAT_MODEL,
                }
            )

        return answer

    def _condense_question(self, question: str, chat_history: list[dict]) -> str:
        """Rephrase a follow-up question to be standalone."""
        history_text = "\n".join(
            f"{m['role'].capitalize()}: {m['content']}" for m in chat_history[-6:]
        )
        prompt = f"""Given this conversation history:
{history_text}

Rephrase this follow-up question to be a standalone question.
If it's already standalone, return it unchanged.
Return ONLY the rephrased question.

Follow-up question: {question}"""

        response = self._client.chat.completions.create(
            model=CHAT_MODEL,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.0,
        )
        return response.choices[0].message.content.strip()


def build_rag_chain(vector_store, response_cache: Optional[ResponseCache] = None) -> RagChain:
    """
    Build a RAG chain with optional response caching.
    
    Args:
        vector_store: ChromaDB vector store for knowledge base retrieval
        response_cache: Optional ResponseCache instance for semantic query caching
    
    Returns:
        RagChain instance
    """
    return RagChain(vector_store, response_cache)


def messages_from_history(history: list[dict]) -> list:
    """Convert plain dicts to LangChain message objects (kept for compatibility)."""
    result = []
    for msg in history:
        if msg["role"] == "user":
            result.append(HumanMessage(content=msg["content"]))
        else:
            result.append(AIMessage(content=msg["content"]))
    return result
