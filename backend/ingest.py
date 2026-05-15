"""
ingest.py
---------
Loads documents from two sources:
  1. Local /docs folder (.txt and .pdf files)
  2. Curated Malaysian government websites (*.gov.my only)

Embeddings are generated locally via Ollama (google/embedding-gemma-300m),
so there are no API rate limits or costs.

Run manually:  python ingest.py
Also called automatically on app startup if the vector store is missing.
"""

import os

# Must be set before chromadb is imported anywhere
os.environ["ANONYMIZED_TELEMETRY"] = "False"
os.environ["CHROMA_TELEMETRY"] = "False"
from pathlib import Path
from urllib.parse import urlparse
from typing import List

import requests
from dotenv import load_dotenv
from langchain_core.embeddings import Embeddings
from langchain_community.document_loaders import (
    TextLoader,
    PyPDFLoader,
    WebBaseLoader,
)
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_chroma import Chroma

load_dotenv()

DOCS_DIR = Path(__file__).parent / "docs"
CHROMA_DIR = Path(__file__).parent / "chroma_db"
COLLECTION_NAME = "laporfix_kb"

OLLAMA_BASE_URL = "http://localhost:11434"
EMBEDDING_MODEL = "embeddinggemma:300m"  # local Ollama model — pull with: ollama pull embeddinggemma:300m

# ── Curated Malaysian government URLs ─────────────────────────────────────────
# Only *.gov.my domains are permitted. Add more pages here as needed.
GOV_MY_URLS: list[str] = [
    # MyGovernment — public complaints & feedback portal
    "https://www.malaysia.gov.my/en/feedback",
    "https://www.malaysia.gov.my/en/feedback/integrated-complaint-management-system-sispaa",
    "https://www.malaysia.gov.my/en/feedback/malaysian-government-call-centre-mygcc",
    # Public service delivery & local government
    "https://www.malaysia.gov.my/en/my-initiative/public-service-delivery-and-local-government",
    # JPS — Department of Irrigation and Drainage (flood/drainage)
    "https://www.water.gov.my/",
    # Ministry of Transport — road safety & feedback
    "https://www.mot.gov.my/en/feedback",
    "https://www.mot.gov.my/en/land/safety/road-accident-and-facilities",
    # DBKL — Kuala Lumpur City Hall
    "https://www.dbkl.gov.my/en/contact-us/",
    # KKR — Ministry of Works (roads, bridges, public infrastructure)
    "https://www.kkr.gov.my/en/public-complaints",
    # TNB — national electricity (outage reporting info)
    "https://www.tnb.com.my/residential/report-an-outage",
    # SPAN — National Water Services Commission
    "https://www.span.gov.my/page/view/aduan-awam",
]

# Safety guard: reject any URL not under a .gov.my domain
_ALLOWED_DOMAIN_SUFFIX = ".gov.my"
_EXTRA_ALLOWED = {
    "www.tnb.com.my",   # TNB is a government-linked utility
    "www.span.gov.my",  # SPAN is a statutory body
}


def _is_allowed_url(url: str) -> bool:
    host = urlparse(url).netloc.lower()
    return host.endswith(_ALLOWED_DOMAIN_SUFFIX) or host in _EXTRA_ALLOWED


# ── Local Ollama embeddings ────────────────────────────────────────────────────
class OllamaEmbeddings(Embeddings):
    """
    LangChain-compatible embeddings using Ollama's local REST API.
    No rate limits, no API key, runs fully offline.
    """

    def __init__(self, model: str = EMBEDDING_MODEL, base_url: str = OLLAMA_BASE_URL):
        self._model = model
        self._url = f"{base_url}/api/embed"

    def _embed(self, texts: List[str]) -> List[List[float]]:
        response = requests.post(
            self._url,
            json={"model": self._model, "input": texts},
            timeout=120,
        )
        response.raise_for_status()
        return response.json()["embeddings"]

    def embed_documents(self, texts: List[str]) -> List[List[float]]:
        # Ollama handles batches natively — send all at once
        BATCH_SIZE = 50  # keep memory reasonable
        all_embeddings = []
        for i in range(0, len(texts), BATCH_SIZE):
            all_embeddings.extend(self._embed(texts[i:i + BATCH_SIZE]))
        return all_embeddings

    def embed_query(self, text: str) -> List[float]:
        return self._embed([text])[0]


# ── Helpers ────────────────────────────────────────────────────────────────────
def get_embeddings() -> OllamaEmbeddings:
    return OllamaEmbeddings()


def load_local_documents():
    """Load all .txt and .pdf files from the docs directory."""
    docs = []
    for path in DOCS_DIR.iterdir():
        if path.suffix == ".txt" and path.name != "placeholder.txt":
            loader = TextLoader(str(path), encoding="utf-8")
            docs.extend(loader.load())
        elif path.suffix == ".pdf":
            loader = PyPDFLoader(str(path))
            docs.extend(loader.load())
    return docs


def load_web_documents() -> list:
    """
    Scrape the curated Malaysian government URLs.
    Only URLs under *.gov.my (or the explicitly allowed utility domains) are
    fetched — any other URL is silently skipped as a safety measure.
    """
    docs = []
    for url in GOV_MY_URLS:
        if not _is_allowed_url(url):
            print(f"⛔  Skipped (not a .gov.my domain): {url}")
            continue
        try:
            loader = WebBaseLoader(url)
            loaded = loader.load()
            for doc in loaded:
                doc.metadata.setdefault("source", url)
            docs.extend(loaded)
            print(f"🌐  Loaded: {url}  ({len(loaded)} page(s))")
        except Exception as e:
            print(f"⚠️   Could not load {url}: {e}")
    return docs


def build_vector_store(embeddings: OllamaEmbeddings) -> Chroma:
    """Split documents and store embeddings in ChromaDB."""
    local_docs = load_local_documents()
    web_docs = load_web_documents()
    docs = local_docs + web_docs

    if not docs:
        print("⚠️  No documents found. Vector store will be empty.")
        return Chroma(
            collection_name=COLLECTION_NAME,
            embedding_function=embeddings,
            persist_directory=str(CHROMA_DIR),
        )

    print(f"\n📄  Local docs : {len(local_docs)} file(s)")
    print(f"🌐  Web pages  : {len(web_docs)} page(s)")

    splitter = RecursiveCharacterTextSplitter(chunk_size=800, chunk_overlap=100)
    chunks = splitter.split_documents(docs)
    print(f"✅  Total chunks: {len(chunks)} — embedding now...")

    vector_store = Chroma.from_documents(
        documents=chunks,
        embedding=embeddings,
        collection_name=COLLECTION_NAME,
        persist_directory=str(CHROMA_DIR),
    )
    print(f"✅  Vector store saved to {CHROMA_DIR}")
    return vector_store


def get_or_load_vector_store(embeddings: OllamaEmbeddings) -> Chroma:
    """Load existing ChromaDB store, or build it if it doesn't exist."""
    if CHROMA_DIR.exists():
        print("📂  Loading existing vector store from disk...")
        return Chroma(
            collection_name=COLLECTION_NAME,
            embedding_function=embeddings,
            persist_directory=str(CHROMA_DIR),
        )
    print("🔨  No vector store found — building from docs + web sources...")
    return build_vector_store(embeddings)


if __name__ == "__main__":
    embeddings = get_embeddings()
    build_vector_store(embeddings)
