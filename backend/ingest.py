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
import shutil
import logging

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
from chromadb.config import Settings as ChromaSettings
from langchain_chroma import Chroma

# Chroma still tries to log telemetry on some versions; failures are harmless.
logging.getLogger("chromadb.telemetry.product.posthog").setLevel(logging.CRITICAL)

load_dotenv()

# Disable Chroma anonymous telemetry (passed to every Chroma client).
_CHROMA_CLIENT_SETTINGS = ChromaSettings(anonymized_telemetry=False)


def _chroma_kwargs() -> dict:
    return {
        "collection_name": COLLECTION_NAME,
        "persist_directory": str(CHROMA_DIR),
        "client_settings": _CHROMA_CLIENT_SETTINGS,
    }

DOCS_DIR = Path(__file__).parent / "docs"
CHROMA_DIR = Path(__file__).parent / "chroma_db"
COLLECTION_NAME = "laporfix_kb"

OLLAMA_BASE_URL = "http://localhost:11434"
EMBEDDING_MODEL = "embeddinggemma:300m"  # local Ollama model — pull with: ollama pull embeddinggemma:300m

# ── Curated Malaysian government URLs ─────────────────────────────────────────
# Only *.gov.my domains are permitted. Add more pages here as needed.
GOV_MY_URLS: list[str] = [
    # # MyGovernment — public complaints & feedback portal
    # "https://www.malaysia.gov.my/en/feedback",
    # "https://www.malaysia.gov.my/en/feedback/integrated-complaint-management-system-sispaa",
    # "https://www.malaysia.gov.my/en/feedback/malaysian-government-call-centre-mygcc",
    # # Public service delivery & local government
    # "https://www.malaysia.gov.my/en/my-initiative/public-service-delivery-and-local-government",
    # # JPS — Department of Irrigation and Drainage (flood/drainage)
    # "https://www.water.gov.my/",
    # # Ministry of Transport — road safety & feedback
    # "https://www.mot.gov.my/en/feedback",
    # "https://www.mot.gov.my/en/land/safety/road-accident-and-facilities",
    # # DBKL — Kuala Lumpur City Hall
    # "https://www.dbkl.gov.my/en/contact-us/",
    # # KKR — Ministry of Works (roads, bridges, public infrastructure)
    # "https://www.kkr.gov.my/en/public-complaints",
    # # TNB — national electricity (outage reporting info)
    # "https://www.tnb.com.my/residential/report-an-outage",
    # # SPAN — National Water Services Commission
    # "https://www.span.gov.my/page/view/aduan-awam",
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
        try:
            response = requests.post(
                self._url,
                json={"model": self._model, "input": texts},
                timeout=300,
            )
            response.raise_for_status()
            return response.json()["embeddings"]
        except requests.exceptions.ConnectionError as e:
            raise RuntimeError(
                "Cannot reach Ollama at http://localhost:11434. "
                "Start it with: ollama serve\n"
                f"Then pull the embedding model: ollama pull {self._model}"
            ) from e
        except requests.exceptions.HTTPError as e:
            if e.response is not None and e.response.status_code == 404:
                raise RuntimeError(
                    f"Ollama model '{self._model}' not found. "
                    f"Run: ollama pull {self._model}"
                ) from e
            raise

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
def ensure_ollama_ready(model: str = EMBEDDING_MODEL) -> None:
    """Verify Ollama is running and the embedding model is available."""
    try:
        r = requests.get(f"{OLLAMA_BASE_URL}/api/tags", timeout=5)
        r.raise_for_status()
    except requests.exceptions.ConnectionError as e:
        raise RuntimeError(
            "\n❌  Ollama is not running.\n"
            "   1. Install Ollama: https://ollama.com\n"
            "   2. Start it:       ollama serve\n"
            "   3. Pull models:    ollama pull qwen2.5:3b\n"
            f"                      ollama pull {model}\n"
            "   4. Re-run:         python ingest.py\n"
        ) from e

    names = {m.get("name", "") for m in r.json().get("models", [])}
    # Ollama may report "embeddinggemma:300m" or "embeddinggemma:300m-latest"
    if not any(n == model or n.startswith(f"{model}:") or model in n for n in names):
        raise RuntimeError(
            f"\n❌  Embedding model '{model}' is not installed.\n"
            f"   Run: ollama pull {model}\n"
            f"   Then: python ingest.py\n"
        )

    print(f"✅  Ollama ready — using embedding model: {model}")


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


def _local_docs_mtime() -> float:
    """Latest modification time of any indexed file in docs/."""
    latest = 0.0
    for path in DOCS_DIR.iterdir():
        if path.suffix in (".txt", ".pdf") and path.name != "placeholder.txt":
            latest = max(latest, path.stat().st_mtime)
    return latest


def _chroma_mtime() -> float:
    """Latest modification time of any file in the Chroma persist directory."""
    if not CHROMA_DIR.exists():
        return 0.0
    latest = 0.0
    for path in CHROMA_DIR.rglob("*"):
        if path.is_file():
            latest = max(latest, path.stat().st_mtime)
    return latest


def docs_newer_than_index() -> bool:
    """True when backend/docs has changed since the vector store was last built."""
    return _local_docs_mtime() > _chroma_mtime()


def build_vector_store(embeddings: OllamaEmbeddings, *, skip_web: bool = False) -> Chroma:
    """Split documents and store embeddings in ChromaDB (full rebuild)."""
    ensure_ollama_ready()

    if CHROMA_DIR.exists():
        shutil.rmtree(CHROMA_DIR)
        print("🗑️   Removed old vector store for fresh re-index.")

    local_docs = load_local_documents()
    if skip_web or os.getenv("SKIP_WEB_INGEST", "").lower() in ("1", "true", "yes"):
        print("⏭️   Skipping government website scrape (SKIP_WEB_INGEST set).")
        web_docs = []
    else:
        web_docs = load_web_documents()
    docs = local_docs + web_docs

    if not docs:
        print("⚠️  No documents found. Vector store will be empty.")
        return Chroma(
            embedding_function=embeddings,
            **_chroma_kwargs(),
        )

    print(f"\n📄  Local docs : {len(local_docs)} file(s)")
    print(f"🌐  Web pages  : {len(web_docs)} page(s)")

    splitter = RecursiveCharacterTextSplitter(chunk_size=800, chunk_overlap=100)
    chunks = splitter.split_documents(docs)
    print(f"✅  Total chunks: {len(chunks)} — embedding now...")

    vector_store = Chroma.from_documents(
        documents=chunks,
        embedding=embeddings,
        **_chroma_kwargs(),
    )
    print(f"✅  Vector store saved to {CHROMA_DIR}")
    return vector_store


def get_or_load_vector_store(embeddings: OllamaEmbeddings) -> Chroma:
    """Load ChromaDB from disk, or rebuild if missing or backend/docs changed."""
    if CHROMA_DIR.exists() and not docs_newer_than_index():
        print("📂  Loading existing vector store from disk...")
        return Chroma(
            embedding_function=embeddings,
            **_chroma_kwargs(),
        )
    if CHROMA_DIR.exists():
        print("🔄  backend/docs changed — rebuilding vector store...")
    else:
        print("🔨  No vector store found — building from docs + web sources...")
    return build_vector_store(embeddings)


if __name__ == "__main__":
    import sys

    skip_web = "--docs-only" in sys.argv
    embeddings = get_embeddings()
    try:
        build_vector_store(embeddings, skip_web=skip_web)
        print("\n✅  Ingest complete.")
    except RuntimeError as e:
        print(e)
        sys.exit(1)
