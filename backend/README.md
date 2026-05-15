# LaporFix RAG Backend

FastAPI + LangChain + ChromaDB + Gemini

## Setup

### 1. Create a virtual environment
```bash
cd backend
python -m venv venv
# Windows
venv\Scripts\activate
# macOS/Linux
source venv/bin/activate
```

### 2. Install dependencies
```bash
pip install -r requirements.txt
```

### 3. Configure environment variables
```bash
cp .env.example .env
# Edit .env:
#   GEMINI_API_KEY — for chatbot image uploads (Gemini Vision)
#   GOOGLE_APPLICATION_CREDENTIALS — path to Firebase service account JSON
```

### 4. Add knowledge base documents (optional)
Drop `.txt` or `.pdf` files into the `backend/docs/` folder.
These will be indexed automatically on first startup.

To re-index after adding new documents:
```bash
python ingest.py
```

### 5. Run the server
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

## API Endpoints

| Method | Path          | Description                        |
|--------|---------------|------------------------------------|
| GET    | /health       | Health check                       |
| POST   | /chat         | Send a message, get an AI answer   |
| POST   | /chat/reset   | Clear conversation history         |

### POST /chat
```json
// Request
{
  "message": "How do I report a pothole?",
  "session_id": "optional-existing-session-id"
}

// Response
{
  "answer": "To report a pothole...",
  "session_id": "uuid-for-this-session"
}
```

## Flutter Connection

- **Android emulator**: `http://10.0.2.2:8000`
- **iOS simulator**: `http://localhost:8000`
- **Physical device**: Use your machine's local IP, e.g. `http://192.168.1.x:8000`

Update the `_baseUrl` in `lib/features/AI_chatbot/services/chatbot_service.dart`.
