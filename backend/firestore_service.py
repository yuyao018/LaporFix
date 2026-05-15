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


def save_message(session_id: str, user_id: str, role: str, content: str):
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

        # Add the message to the sub-collection
        session_ref.collection("messages").add(
            {
                "role": role,
                "content": content,
                "timestamp": now,
            }
        )
    except Exception as e:
        # Log but don't crash the request — Firestore is non-critical
        logger.warning("Firestore write failed (non-fatal): %s", e)


def save_turn(session_id: str, user_id: str, question: str, answer: str, is_first: bool = False):
    """Save both the user question and assistant answer in one call.
    If is_first=True, also saves the question as the session preview."""
    if is_first:
        try:
            db = init_firestore()
            db.collection("chat_sessions").document(session_id).set(
                {"preview": question[:80]}, merge=True
            )
        except Exception as e:
            logger.warning("Firestore preview write failed: %s", e)
    save_message(session_id, user_id, "user", question)
    save_message(session_id, user_id, "assistant", answer)

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
