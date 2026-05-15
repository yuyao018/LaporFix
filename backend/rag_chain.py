"""
rag_chain.py
------------
RAG chain using Ollama (qwen2.5:3b) for the LLM,
and Gemini embeddings (via ingest.py) for retrieval.

Ollama must be running locally:  ollama run qwen2.5:3b

Flow:
  user question
    → retrieve relevant docs from ChromaDB (GeminiEmbeddings)
    → build prompt with context + history + question
    → qwen2.5:3b generates answer via Ollama's OpenAI-compatible API
"""

from openai import OpenAI
from langchain_core.messages import HumanMessage, AIMessage

CHAT_MODEL = "qwen2.5:3b"
OLLAMA_BASE_URL = "http://localhost:11434/v1"

SYSTEM_INSTRUCTION = """You are LAPI, a helpful AI assistant for the LaporFix urban issue-reporting app.
You help citizens of Malaysia report and track urban infrastructure issues such as potholes,
water cuts, power outages, drainage problems, and other public complaints.

Use the retrieved context provided to answer questions.
If the context does not contain enough information, answer based on your general knowledge
but make it clear you are doing so.

LENGTH RULE: Keep every reply under 60 words — use at most 3 short, complete sentences.
Never cut off mid-sentence. No bullet lists, no filler, no repetition. Be direct and friendly."""

def _get_client() -> OpenAI:
    # Ollama doesn't require a real API key, but the openai SDK requires a non-empty string
    return OpenAI(api_key="ollama", base_url=OLLAMA_BASE_URL)


def _format_docs(docs) -> str:
    if not docs:
        return "No relevant documents found in the knowledge base."
    return "\n\n---\n\n".join(doc.page_content for doc in docs)


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
    Stateless RAG chain. Accepts question + chat_history per call.
    """

    def __init__(self, vector_store):
        self._vector_store = vector_store
        self._client = _get_client()

    def invoke(self, inputs: dict) -> str:
        question: str = inputs["question"]
        chat_history: list[dict] = inputs.get("chat_history", [])

        # Step 1: condense follow-up question if there's history
        standalone_question = question
        if chat_history:
            standalone_question = self._condense_question(question, chat_history)

        # Step 2: retrieve relevant docs
        docs = self._vector_store.similarity_search(standalone_question, k=4)
        context = _format_docs(docs)

        # Step 3: generate answer
        messages = _build_messages(question, context, chat_history)

        response = self._client.chat.completions.create(
            model=CHAT_MODEL,
            messages=messages,
            temperature=0.3,
        )

        return (response.choices[0].message.content or "").strip()

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


def build_rag_chain(vector_store) -> RagChain:
    return RagChain(vector_store)


def messages_from_history(history: list[dict]) -> list:
    """Convert plain dicts to LangChain message objects (kept for compatibility)."""
    result = []
    for msg in history:
        if msg["role"] == "user":
            result.append(HumanMessage(content=msg["content"]))
        else:
            result.append(AIMessage(content=msg["content"]))
    return result
