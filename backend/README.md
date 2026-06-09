# LaporFix RAG Backend

FastAPI + LangChain + Ollama + ChromaDB

The backend powers **LAPI**, the in-app AI assistant. It runs fully locally — no LLM API costs. On startup it loads (or builds) a ChromaDB vector store from local docs and curated Malaysian government websites, then serves a RAG chain backed by `qwen2.5:3b` via Ollama.

---

## Prerequisites

- Python 3.11+
- [Ollama](https://ollama.com) installed and running
- A Firebase project with a service account key

---

## Setup

### 1. Create and activate a virtual environment

```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate

# macOS / Linux
source venv/bin/activate
```

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

### 3. Pull Ollama models

```bash
ollama pull qwen2.5:3b           # LLM used for chat responses
ollama pull embeddinggemma:300m  # Embedding model for ChromaDB
```

### 4. Configure environment variables

```bash
cp .env.example .env
```

Edit `.env`:

```
GEMINI_API_KEY=...               # For image uploads via Gemini Vision
GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json  # Firebase service account
```

Place your Firebase service account JSON at `backend/serviceAccountKey.json` (already in `.gitignore`).

### 5. Add knowledge base documents (optional)

Drop `.txt` or `.pdf` files into `backend/docs/`. They are indexed automatically on first startup.

To manually re-index (e.g. after adding new documents):

```bash
python ingest.py

# Skip government website scraping (faster, local docs only):
python ingest.py --docs-only
```

The vector store is persisted to `backend/chroma_db/` and reused on subsequent startups. It only rebuilds if the `docs/` folder has been modified since the last index.

### 6. Start the server

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

---

## API Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check — returns active session count |
| `POST` | `/chat` | Text message → RAG answer |
| `POST` | `/chat/vision` | Image upload → Gemini Vision extract → RAG answer |
| `POST` | `/chat/document` | PDF/DOC/TXT upload → Docling extract → RAG answer |
| `POST` | `/chat/save-turn` | Persist a client-generated turn without calling the LLM |
| `POST` | `/chat/reset` | Clear a single session (memory + Firestore) |
| `POST` | `/chat/clear-all` | Delete all sessions for a user |
| `GET` | `/chat/sessions/{user_id}` | List all sessions for a user |
| `GET` | `/chat/sessions/{user_id}/{session_id}/messages` | Get all messages in a session |

### POST /chat

```json
// Request
{
  "message": "How do I report a pothole?",
  "session_id": "optional-existing-session-id",
  "user_id": "firebase-auth-uid"
}

// Response
{
  "answer": "To report a pothole...",
  "session_id": "uuid-for-this-session"
}
```

### POST /chat/vision and /chat/document

Multipart form fields:
- `message` (optional text)
- `session_id` (optional)
- `user_id`
- `image` (file) — for `/chat/vision`
- `document` (file) — for `/chat/document`

---

## Architecture

```
User message
  │
  ▼
Condense follow-up question (if chat history exists)
  │
  ▼
ChromaDB similarity search (k=4 chunks, embeddinggemma:300m)
  │
  ▼
Build prompt: system instruction + history + context + question
  │
  ▼
qwen2.5:3b via Ollama (OpenAI-compatible API at localhost:11434/v1)
  │
  ▼
Response saved to Firestore chat_sessions (non-blocking)
```

**Knowledge base sources** (`ingest.py`):
- Local `backend/docs/` — any `.txt` or `.pdf` files
- Curated Malaysian government websites: `malaysia.gov.my`, `mot.gov.my`, `dbkl.gov.my`, `kkr.gov.my`, `tnb.com.my`, `water.gov.my`
- Only `.gov.my` domains and explicitly allowed utility domains (TNB, SPAN) are permitted

**Vector store:**
- Persisted to `backend/chroma_db/` (gitignored, `.gitkeep` keeps the folder tracked)
- Chunk size: 800 tokens, overlap: 100
- Collection name: `laporfix_kb`

**AI persona — LAPI:**
- Replies in under 60 words
- No bullet lists or filler
- Direct and friendly
- Helps citizens report and track urban infrastructure issues

---

## Flutter Connection

Update `_baseUrl` in `lib/features/AI_chatbot/services/chatbot_service.dart`:

| Target | URL |
|---|---|
| Android emulator | `http://10.0.2.2:8000` |
| iOS simulator | `http://localhost:8000` |
| Physical device | `http://192.168.x.x:8000` (your machine's local IP) |

---

## Environment Variables Reference

| Variable | Required | Description |
|---|---|---|
| `GEMINI_API_KEY` | Yes (for image/doc uploads) | Google Gemini API key for Vision and Docling |
| `GOOGLE_APPLICATION_CREDENTIALS` | Yes | Path to Firebase service account JSON |
| `SKIP_WEB_INGEST` | No | Set to `1` to skip government website scraping on rebuild |
