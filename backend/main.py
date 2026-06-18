"""
main.py
-------
FastAPI application exposing the RAG chatbot endpoints.

Endpoints:
  POST /chat          — send a message, get an AI answer
  POST /chat/reset    — clear conversation history for a session
  GET  /health        — health check
"""

import uuid
import logging
import traceback
import os

# Must be set before chromadb is imported anywhere
os.environ["ANONYMIZED_TELEMETRY"] = "False"
os.environ["CHROMA_TELEMETRY"] = "False"
from contextlib import asynccontextmanager
from typing import Optional

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

from ingest import get_embeddings, get_or_load_vector_store
from rag_chain import build_rag_chain, messages_from_history, SYSTEM_INSTRUCTION
from response_cache import ResponseCache
from firestore_service import (
    init_firestore,
    save_turn,
    save_local_turn,
    delete_session,
    delete_all_user_sessions,
)
from firebase_admin import firestore
from image_doc_reader import extract_text_from_file

# ── Shared state ───────────────────────────────────────────────────────────────
# sessions: maps session_id → list of {"role": "user"|"assistant", "content": str}
sessions: dict[str, list[dict]] = {}

vector_store = None
rag_chain = None
response_cache = None

MAX_EXTRACTED_CHARS = 6000


async def _extract_uploaded_text(file_bytes: bytes, filename: str) -> str:
    """Save upload to a temp file and extract text via image_doc_reader."""
    import asyncio
    import tempfile
    import pathlib

    suffix = pathlib.Path(filename).suffix or ".bin"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(file_bytes)
        tmp_path = pathlib.Path(tmp.name)

    try:
        loop = asyncio.get_event_loop()
        extracted = await loop.run_in_executor(
            None, extract_text_from_file, str(tmp_path)
        )
    finally:
        tmp_path.unlink(missing_ok=True)

    if not extracted or not extracted.strip():
        raise HTTPException(
            status_code=422,
            detail="Could not extract text from the uploaded file.",
        )

    text = extracted.strip()
    if len(text) > MAX_EXTRACTED_CHARS:
        text = text[:MAX_EXTRACTED_CHARS] + "\n\n[Content truncated for length]"
    return text


# ── App lifespan ───────────────────────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    global vector_store, rag_chain, response_cache
    print("🚀  Starting LaporFix RAG backend...")
    try:
        embeddings = get_embeddings()
        vector_store = get_or_load_vector_store(embeddings)
        
        # Initialize response cache with the same ChromaDB client
        try:
            import chromadb
            from chromadb.config import Settings as ChromaSettings
            chroma_client = chromadb.PersistentClient(
                path="./chroma_db",
                settings=ChromaSettings(anonymized_telemetry=False)
            )
            response_cache = ResponseCache(embeddings, chroma_client)
            print(f"✅  Response cache initialized with {response_cache.collection.count() if response_cache.collection else 0} cached responses")
        except Exception as cache_err:
            logger.warning(f"Failed to initialize response cache: {cache_err}")
            response_cache = None
        
        rag_chain = build_rag_chain(vector_store, response_cache)
        init_firestore()
        print("✅  Backend ready.")
    except Exception as e:
        logger.error("Startup error:\n%s", traceback.format_exc())
        raise
    yield
    print("🛑  Shutting down.")


app = FastAPI(
    title="LaporFix RAG Chatbot API",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Request / Response models ──────────────────────────────────────────────────
class ChatRequest(BaseModel):
    message: str
    session_id: Optional[str] = None
    user_id: Optional[str] = "anonymous"  # Firebase Auth UID


class ChatResponse(BaseModel):
    answer: str
    session_id: str


class ResetRequest(BaseModel):
    session_id: str


class ClearAllRequest(BaseModel):
    user_id: str


class AssistantMessagePayload(BaseModel):
    content: str = ""
    disruption_notice: Optional[dict] = None
    ticket: Optional[dict] = None


class SaveTurnRequest(BaseModel):
    user_message: str
    assistant_messages: list[AssistantMessagePayload]
    session_id: Optional[str] = None
    user_id: Optional[str] = "anonymous"


class SaveTurnResponse(BaseModel):
    session_id: str


# ── Routes ─────────────────────────────────────────────────────────────────────
@app.get("/health")
async def health():
    cache_stats = {}
    if response_cache:
        try:
            cache_stats = response_cache.get_stats()
        except Exception as e:
            logger.warning(f"Could not get cache stats: {e}")
    
    return {
        "status": "ok",
        "sessions_active": len(sessions),
        "cache_stats": cache_stats,
    }


@app.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    if rag_chain is None:
        raise HTTPException(status_code=503, detail="RAG chain not ready yet.")

    # Get or create session
    session_id = (
        req.session_id
        if req.session_id and req.session_id in sessions
        else str(uuid.uuid4())
    )
    if session_id not in sessions:
        sessions[session_id] = []

    history = sessions[session_id]
    user_id = req.user_id or "anonymous"

    try:
        answer = rag_chain.invoke({
            "question": req.message,
            "chat_history": history,
            "session_id": session_id,
        })
    except Exception as e:
        logger.error("RAG chain error:\n%s", traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"LLM error: {str(e)}")

    # Update in-memory history (keep last 20 messages = 10 turns)
    history.append({"role": "user", "content": req.message})
    history.append({"role": "assistant", "content": answer})
    if len(history) > 20:
        sessions[session_id] = history[-20:]

    # Persist to Firestore (non-blocking — failure won't affect the response)
    is_first = len(history) == 2  # just added user + assistant = first turn
    save_turn(session_id, user_id, req.message, answer, is_first=is_first)

    return ChatResponse(answer=answer, session_id=session_id)


@app.post("/chat/vision", response_model=ChatResponse)
async def chat_vision(
    message: str = Form(""),
    session_id: Optional[str] = Form(None),
    user_id: Optional[str] = Form("anonymous"),
    image_url: Optional[str] = Form(None),
    image: UploadFile = File(...),
):
    """
    Extract text and visual content from an image using image_doc_reader
    (Gemini Vision), then answer with the RAG chain.
    """
    image_bytes = await image.read()
    filename = image.filename or "upload.png"
    user_question = message.strip() or "What is in this image? Describe it in detail."

    try:
        image_content = await _extract_uploaded_text(image_bytes, filename)
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Image extraction error:\n%s", traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Image extraction error: {str(e)}")

    session_id = session_id or str(uuid.uuid4())
    if session_id not in sessions:
        sessions[session_id] = []

    history = sessions[session_id]
    user_id = user_id or "anonymous"

    prompt = (
        f"The user uploaded an image named '{filename}'. "
        f"Here is the extracted content:\n\n"
        f"{image_content}\n\n"
        f"User question: {user_question}"
    )

    try:
        answer = rag_chain.invoke({
            "question": prompt,
            "chat_history": history,
        })
    except Exception as e:
        logger.error("Vision RAG error:\n%s", traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"LLM error: {str(e)}")

    history.append({"role": "user", "content": f"[Image] {user_question}"})
    history.append({"role": "assistant", "content": answer})
    if len(history) > 20:
        sessions[session_id] = history[-20:]

    save_turn(
        session_id,
        user_id,
        f"[Image] {user_question}",
        answer,
        is_first=len(history) == 2,
        user_image_url=image_url.strip() if image_url else None,
    )

    return ChatResponse(answer=answer, session_id=session_id)



@app.post("/chat/document", response_model=ChatResponse)
async def chat_document(
    message: str = Form(""),
    session_id: Optional[str] = Form(None),
    user_id: Optional[str] = Form("anonymous"),
    document: UploadFile = File(...),
):
    """Extract text from an uploaded document using image_doc_reader (Docling), then answer with RAG."""
    file_bytes = await document.read()
    filename = document.filename or "upload.pdf"

    try:
        doc_text = await _extract_uploaded_text(file_bytes, filename)
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Document extraction error:\n%s", traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"Document extraction error: {str(e)}")

    session_id = session_id or str(uuid.uuid4())
    if session_id not in sessions:
        sessions[session_id] = []

    history = sessions[session_id]
    user_id = user_id or "anonymous"
    user_question = message.strip() or "Please summarise this document."

    prompt_with_doc = (
        f"The user has uploaded a document named '{filename}'.\n\n"
        f"Document contents:\n{doc_text}\n\n"
        f"User question: {user_question}"
    )

    try:
        answer = rag_chain.invoke({
            "question": prompt_with_doc,
            "chat_history": history,
        })
    except Exception as e:
        logger.error("Document RAG error:\n%s", traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"LLM error: {str(e)}")

    history.append({"role": "user", "content": f"[Document: {filename}] {user_question}"})
    history.append({"role": "assistant", "content": answer})
    if len(history) > 20:
        sessions[session_id] = history[-20:]

    save_turn(session_id, user_id,
              f"[Document: {filename}] {user_question}", answer,
              is_first=len(history) == 2)

    return ChatResponse(answer=answer, session_id=session_id)


@app.post("/chat/save-turn", response_model=SaveTurnResponse)
async def save_turn_endpoint(req: SaveTurnRequest):
    """
    Persist a client-side chat turn (e.g. water/power cut card, ticket lookup)
    to Firestore without invoking the LLM.
    """
    session_id = req.session_id or str(uuid.uuid4())
    user_id = req.user_id or "anonymous"

    if session_id not in sessions:
        sessions[session_id] = []

    assistant_payloads = [
        {
            "content": m.content,
            "disruption_notice": m.disruption_notice,
            "ticket": m.ticket,
        }
        for m in req.assistant_messages
    ]
    save_local_turn(session_id, user_id, req.user_message, assistant_payloads)

    sessions[session_id].append({"role": "user", "content": req.user_message})
    for m in req.assistant_messages:
        sessions[session_id].append({
            "role": "assistant",
            "content": m.content or "[Disruption notice]",
        })
    if len(sessions[session_id]) > 20:
        sessions[session_id] = sessions[session_id][-20:]

    return SaveTurnResponse(session_id=session_id)


@app.post("/chat/reset")
async def reset_session(req: ResetRequest):
    # Clear in-memory history
    if req.session_id in sessions:
        del sessions[req.session_id]

    # Delete from Firestore
    delete_session(req.session_id)

    return {"message": "Session cleared.", "session_id": req.session_id}


@app.post("/chat/clear-all")
async def clear_all_sessions(req: ClearAllRequest):
    """Delete all chat sessions for a user (triggered by /clear in the app)."""
    user_id = req.user_id or "anonymous"
    deleted_ids = delete_all_user_sessions(user_id)

    for session_id in deleted_ids:
        sessions.pop(session_id, None)

    return {
        "message": f"Cleared {len(deleted_ids)} session(s).",
        "deleted_count": len(deleted_ids),
    }


@app.get("/cache/stats")
async def get_cache_stats():
    """Get response cache performance statistics."""
    if not response_cache:
        raise HTTPException(
            status_code=503,
            detail="Response cache is not initialized"
        )
    
    try:
        stats = response_cache.get_stats()
        return stats
    except Exception as e:
        logger.error("Cache stats error: %s", traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/cache/clear")
async def clear_response_cache():
    """Clear all cached responses (admin endpoint)."""
    if not response_cache:
        raise HTTPException(
            status_code=503,
            detail="Response cache is not initialized"
        )
    
    try:
        success = response_cache.clear()
        if success:
            return {"message": "Response cache cleared successfully"}
        else:
            raise HTTPException(status_code=500, detail="Failed to clear cache")
    except Exception as e:
        logger.error("Cache clear error: %s", traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/chat/sessions/{user_id}")
async def get_sessions(user_id: str):
    """Return all session metadata for a user, ordered by most recent."""
    try:
        db = init_firestore()
        try:
            # Requires a composite index on (user_id ASC, updated_at DESC).
            # If the index doesn't exist yet, Firestore raises FailedPrecondition
            # and includes a URL in the message to create it — check server logs.
            docs = (
                db.collection("chat_sessions")
                .where("user_id", "==", user_id)
                .order_by("updated_at", direction=firestore.Query.DESCENDING)
                .limit(50)
                .stream()
            )
            result = _docs_to_sessions(docs)
        except Exception as index_err:
            # Fallback: fetch without ordering (no composite index needed),
            # then sort in Python. Works until the index is created.
            logger.warning(
                "Ordered query failed (missing index?), falling back to unordered fetch.\n"
                "Error: %s\n"
                "If you see a URL above, open it to create the required Firestore index.",
                index_err,
            )
            docs = (
                db.collection("chat_sessions")
                .where("user_id", "==", user_id)
                .limit(50)
                .stream()
            )
            result = sorted(
                _docs_to_sessions(docs),
                key=lambda s: s["updated_at"] or "",
                reverse=True,
            )
        return {"sessions": result}
    except Exception as e:
        logger.error("get_sessions error: %s", traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))


def _docs_to_sessions(docs) -> list[dict]:
    result = []
    for doc in docs:
        data = doc.to_dict()
        result.append({
            "session_id": doc.id,
            "updated_at": data.get("updated_at").isoformat() if data.get("updated_at") else None,
            "created_at": data.get("created_at").isoformat() if data.get("created_at") else None,
            "preview": data.get("preview", ""),
        })
    return result


@app.get("/chat/sessions/{user_id}/{session_id}/messages")
async def get_messages(user_id: str, session_id: str):
    """Return all messages for a session, ordered by timestamp."""
    try:
        db = init_firestore()
        session_ref = db.collection("chat_sessions").document(session_id)
        session_doc = session_ref.get()

        if not session_doc.exists:
            raise HTTPException(status_code=404, detail="Session not found.")
        if session_doc.to_dict().get("user_id") != user_id:
            raise HTTPException(status_code=403, detail="Access denied.")

        msgs = (
            session_ref.collection("messages")
            .order_by("timestamp")
            .stream()
        )
        result = []
        for msg in msgs:
            data = msg.to_dict()
            entry = {
                "role": data.get("role"),
                "content": data.get("content"),
                "timestamp": data.get("timestamp").isoformat() if data.get("timestamp") else None,
            }
            if data.get("image_url"):
                entry["image_url"] = data["image_url"]
            if data.get("disruption_notice"):
                entry["disruption_notice"] = data["disruption_notice"]
            if data.get("ticket"):
                entry["ticket"] = data["ticket"]
            result.append(entry)
        return {"messages": result}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("get_messages error: %s", traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))
