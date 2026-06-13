"""Embedding microservice.

A tiny FastAPI wrapper around an open-source sentence-transformers model. The
default is BAAI/bge-small-en-v1.5 (384-dim, ~133 MB) so it runs on a small host;
set EMBEDDING_MODEL=Qwen/Qwen3-Embedding-0.6B (with EMBEDDING_DIM=384 to match
the schema) on a larger host. It loads the model once at startup and exposes a
JSON `/embed` endpoint that the Rails app's `Embeddings::ServiceEmbedder` calls
over the private network.

Retrieval is asymmetric: search *queries* are encoded with the model's retrieval
instruction, *documents* plain. bge models take a manual instruction prefix
(QUERY_INSTRUCTION); Qwen exposes a built-in "query" prompt. Embeddings are
L2-normalized so cosine == dot product, matching the pgvector
`vector_cosine_ops` indexes on the Rails side.
"""

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer

MODEL_NAME = os.environ.get("EMBEDDING_MODEL", "BAAI/bge-small-en-v1.5")
# bge-small-en-v1.5's retrieval query instruction. Override for other models;
# leave empty for symmetric models. Ignored if the model has a built-in prompt.
QUERY_INSTRUCTION = os.environ.get(
    "QUERY_INSTRUCTION", "Represent this sentence for searching relevant passages: "
)
# Matryoshka models (e.g. Qwen3-Embedding) can be truncated; leave unset for the
# model's native dimension (bge-small is natively 384).
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

    texts = req.texts
    encode_kwargs: dict = {"normalize_embeddings": True, "convert_to_numpy": True}
    if req.mode == "query":
        # Apply the retrieval instruction to the query side only.
        if "query" in (getattr(model, "prompts", None) or {}):
            encode_kwargs["prompt_name"] = "query"  # Qwen-style built-in prompt
        elif QUERY_INSTRUCTION:
            texts = [f"{QUERY_INSTRUCTION}{t}" for t in texts]  # bge-style prefix

    vectors = model.encode(texts, **encode_kwargs)
    return {
        "embeddings": [v.tolist() for v in vectors],
        "dim": int(vectors.shape[1]),
        "model": MODEL_NAME,
        "mode": req.mode,
    }
