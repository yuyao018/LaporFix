"""
firestore_service.py
--------------------
Handles all Firestore read/write operations for chat sessions.

Firestore structure:
  chat_sessions/{session_id}          — session metadata
    messages/{auto_id}                — individual chat turns

Each session document:
  {
    "user_id":    str,
    "created_at": timestamp,
    "updated_at": timestamp,
  }

Each message document:
  {
    "role":      "user" | "assistant",
    "content":   str,
    "timestamp": timestamp,
    "image_url": str (optional — user image uploads only),
    "disruption_notice": map (optional — water/power/road disruption cards),
  }
"""

import os
import logging
from datetime import datetime, timezone

import firebase_admin
from firebase_admin import credentials, firestore

logger = logging.getLogger(__name__)

_db = None  # Firestore client, initialised once


def init_firestore():
    """
    Initialise the Firebase Admin SDK.
    Uses GOOGLE_APPLICATION_CREDENTIALS env var (path to service account JSON)
    if set, otherwise falls back to Application Default Credentials (ADC).
    """
    global _db
    if _db is not None:
        return _db

    if not firebase_admin._apps:
        sa_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        if sa_path and os.path.exists(sa_path):
            cred = credentials.Certificate(sa_path)
            logger.info("Firebase: using service account from %s", sa_path)
        else:
            # ADC — works on GCP / Cloud Run automatically
            cred = credentials.ApplicationDefault()
            logger.info("Firebase: using Application Default Credentials")

        firebase_admin.initialize_app(cred)

    _db = firestore.client()
    logger.info("Firestore client initialised.")
    return _db


def save_message(
    session_id: str,
    user_id: str,
    role: str,
    content: str,
    image_url: str | None = None,
    disruption_notice: dict | None = None,
):
    """
    Append a single message to the session's messages sub-collection.
    Also upserts the parent session document with metadata.
    """
    try:
        db = init_firestore()
        now = datetime.now(timezone.utc)

        session_ref = db.collection("chat_sessions").document(session_id)

        # Upsert session metadata (merge=True so we don't overwrite on first msg)
        session_ref.set(
            {
                "user_id": user_id,
                "updated_at": now,
            },
            merge=True,
        )

        # Set created_at only on first write (won't overwrite if already exists)
        session_doc = session_ref.get()
        if not session_doc.exists or "created_at" not in (session_doc.to_dict() or {}):
            session_ref.set({"created_at": now}, merge=True)

        payload = {
            "role": role,
            "content": content,
            "timestamp": now,
        }
        if image_url:
            payload["image_url"] = image_url
        if disruption_notice:
            payload["disruption_notice"] = disruption_notice

        session_ref.collection("messages").add(payload)
    except Exception as e:
        # Log but don't crash the request — Firestore is non-critical
        logger.warning("Firestore write failed (non-fatal): %s", e)


def save_turn(
    session_id: str,
    user_id: str,
    question: str,
    answer: str,
    is_first: bool = False,
    user_image_url: str | None = None,
):
    """Save both the user question and assistant answer in one call.
    If is_first=True, also saves the question as the session preview."""
    if is_first:
        try:
            db = init_firestore()
            preview = question[:80] if not user_image_url else f"[Image] {question[:60]}"
            db.collection("chat_sessions").document(session_id).set(
                {"preview": preview}, merge=True
            )
        except Exception as e:
            logger.warning("Firestore preview write failed: %s", e)
    save_message(session_id, user_id, "user", question, image_url=user_image_url)
    save_message(session_id, user_id, "assistant", answer)


def save_local_turn(
    session_id: str,
    user_id: str,
    user_message: str,
    assistant_messages: list[dict],
) -> bool:
    """
    Persist a client-generated turn (suggestion cards, ticket lookup, etc.)
    without calling the LLM. Each assistant_messages item may include:
      - content (str)
      - disruption_notice (dict, optional)
    Returns True if this is the first message in the session.
    """
    try:
        db = init_firestore()
        session_ref = db.collection("chat_sessions").document(session_id)
        is_first = not session_ref.get().exists

        if is_first:
            session_ref.set({"preview": user_message[:80]}, merge=True)

        save_message(session_id, user_id, "user", user_message)

        for msg in assistant_messages:
            save_message(
                session_id,
                user_id,
                "assistant",
                msg.get("content", "") or "",
                disruption_notice=msg.get("disruption_notice"),
            )
        return is_first
    except Exception as e:
        logger.warning("Firestore local turn write failed (non-fatal): %s", e)
        return False


def delete_session(session_id: str):
    """
    Delete a session document and all its messages.
    Called when the user resets the chat.
    """
    try:
        db = init_firestore()
        session_ref = db.collection("chat_sessions").document(session_id)

        # Delete all messages in the sub-collection first
        messages = session_ref.collection("messages").stream()
        for msg in messages:
            msg.reference.delete()

        session_ref.delete()
        logger.info("Deleted Firestore session %s", session_id)
    except Exception as e:
        logger.warning("Firestore delete failed (non-fatal): %s", e)


def delete_all_user_sessions(user_id: str) -> list[str]:
    """Delete every chat session (and its messages) belonging to user_id."""
    deleted_ids: list[str] = []
    try:
        db = init_firestore()
        docs = (
            db.collection("chat_sessions")
            .where("user_id", "==", user_id)
            .stream()
        )
        for doc in docs:
            delete_session(doc.id)
            deleted_ids.append(doc.id)
        logger.info("Deleted %d Firestore session(s) for user %s", len(deleted_ids), user_id)
    except Exception as e:
        logger.warning("Firestore bulk delete failed (non-fatal): %s", e)
    return deleted_ids
