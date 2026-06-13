"""Qwen3-Embedding-0.6B microservice.

A tiny FastAPI wrapper around the open-source Qwen3-Embedding-0.6B model
(https://github.com/QwenLM/Qwen3-Embedding, weights on Hugging Face). It loads
the model once at startup and exposes a JSON `/embed` endpoint that the Rails
app's `Embeddings::QwenEmbedder` calls over Railway's private network.

Qwen3-Embedding is asymmetric: search *queries* are encoded with the model's
built-in retrieval instruction (`prompt_name="query"`), while *documents* are
encoded plain. Embeddings are L2-normalized so cosine == dot product, matching
the pgvector `vector_cosine_ops` indexes on the Rails side.
"""

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer

MODEL_NAME = os.environ.get("EMBEDDING_MODEL", "Qwen/Qwen3-Embedding-0.6B")
# Qwen3-Embedding-0.6B is natively 1024-dim and trained with Matryoshka
# representation learning, so it can be truncated to a smaller dimension.
# Leave EMBEDDING_DIM unset to use the native 1024.
_dim = os.environ.get("EMBEDDING_DIM")
TRUNCATE_DIM = int(_dim) if _dim else None

state: dict[str, SentenceTransformer] = {}


@asynccontextmanager
async def lifespan(_app: FastAPI):
    state["model"] = SentenceTransformer(MODEL_NAME, truncate_dim=TRUNCATE_DIM)
    yield
    state.clear()


app = FastAPI(title="caselight-embeddings", lifespan=lifespan)


class EmbedRequest(BaseModel):
    texts: list[str]
    mode: str = "document"  # "query" | "document"


@app.get("/health")
def health() -> dict:
    model = state.get("model")
    return {
        "status": "ok" if model else "loading",
        "model": MODEL_NAME,
        "dim": model.get_sentence_embedding_dimension() if model else None,
    }


@app.post("/embed")
def embed(req: EmbedRequest) -> dict:
    model = state["model"]
    if not req.texts:
        return {"embeddings": [], "dim": model.get_sentence_embedding_dimension(),
                "model": MODEL_NAME, "mode": req.mode}

    encode_kwargs: dict = {"normalize_embeddings": True, "convert_to_numpy": True}
    if req.mode == "query":
        # Applies Qwen3-Embedding's retrieval instruction to the query side only.
        encode_kwargs["prompt_name"] = "query"

    vectors = model.encode(req.texts, **encode_kwargs)
    return {
        "embeddings": [v.tolist() for v in vectors],
        "dim": int(vectors.shape[1]),
        "model": MODEL_NAME,
        "mode": req.mode,
    }
