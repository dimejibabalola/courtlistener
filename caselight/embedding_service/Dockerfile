# Sentence-transformers embedding service (CPU). Built and run as its own
# Railway service; the Rails app reaches it over the private network. Default
# model bge-small-en-v1.5 fits a small host; override EMBEDDING_MODEL for Qwen.
FROM python:3.11-slim

WORKDIR /app

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/app/hf-cache \
    EMBEDDING_MODEL=BAAI/bge-small-en-v1.5

# CPU-only torch first so sentence-transformers doesn't drag in CUDA wheels.
RUN pip install torch --index-url https://download.pytorch.org/whl/cpu

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY app.py .

# Bake the model weights into the image so boots need no network and are fast.
RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('${EMBEDDING_MODEL}')"

EXPOSE 8000
# Bind IPv6 (::) — Railway's private network is IPv6-only; this dual-stacks
# so localhost (IPv4) still works in dev.
CMD ["sh", "-c", "uvicorn app:app --host :: --port ${PORT:-8000}"]
