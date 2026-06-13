# Caselight — open-source legal research & matter intelligence

A production-grade legal research platform built with Ruby on Rails + Hotwire.
Server-rendered, no SPA framework: Turbo Drive navigation, Turbo Frames for
independent panes, Turbo Streams for live updates, Stimulus for client behavior.

> Everything in the seed corpus is **original fiction** written for this
> project. Citations like `987 F.3d 1234` are deliberately impossible
> placeholders. Nothing here is legal advice, editorial content from any
> commercial research product, or real law.

## What's inside

| Section (route) | Capability |
|---|---|
| `/research` | Unified search bar (natural language, terms-and-connectors, citations), live facets, three-pane workspace, saved searches with alerting |
| `/documents/:slug` | Reader: treatment flag, parallel citations, headnotes, notes/highlights, copy-with-citation, save-to-folder, download |
| `/citations` + `/documents/:slug/citator` | Citation check, treatment history, depth-of-treatment filters, interactive citing-references graph |
| `/topics` | Hierarchical topic taxonomy (original codes), browse headnotes by point of law |
| `/history` | Timestamped, resumable trail of searches and document views |
| `/matters`, `/folders` | Matter workspaces and shared research folders (individual + firm roles) |
| `/uploads` | Document uploads with OCR/extraction (MinerU → pdftotext → pdf-reader → tesseract), brief-to-authority checking, ToA export (CSV/DOCX) |
| `/drafts` | Drafting editor with grounded "Insert" paragraphs and tone switching |
| `/ai_conversations` | Source-grounded AI answers (RAG over pgvector) with switchable providers |
| `/settings`, `/archive`, `/trash` | Profile, AI provider/model + keys, archive & trash with restore and 30-day purge |

## The three-layer search

Queried together by `Search::Engine` via `Search::QueryPlanner`:

1. **OpenSearch/Elasticsearch** (`Search::OpenSearchAdapter`) — primary
   full-text engine: query_string terms-and-connectors, highlighting,
   aggregations for facets. Optional: the app transparently falls back when
   no cluster is reachable (`OPENSEARCH_URL`, `DISABLE_OPENSEARCH=1`).
2. **Postgres full-text** (`Search::PostgresAdapter`) — tsvector column
   maintained by trigger; fallback engine, structured-metadata search, and
   the source of truth for exact citation lookups.
3. **pgvector** (`Search::VectorAdapter`) — embeddings over document chunks
   *and* headnotes for semantic search and "more like this".

Routing: citation → direct fetch (Postgres); connectors → OpenSearch/PG
boolean; prose → hybrid BM25 + cosine, fused with reciprocal-rank fusion
(`Search::ReciprocalRankFusion`).

### Embedding providers

Vectors are 1024-dim. Pick a provider with `EMBEDDINGS_PROVIDER`:

| Provider | Notes |
|---|---|
| `hash` (default) | Deterministic offline feature-hash embedder — zero setup, but only models lexical overlap. Fine for the demo/tests. |
| `qwen` | **Real semantic search** via the open-source **Qwen3-Embedding-0.6B** model, served by the bundled `embedding_service/` (FastAPI + sentence-transformers). Set `EMBEDDINGS_URL` to the service. |
| `openai` | Hosted `text-embedding-3-*` (`OPENAI_API_KEY`). |

The Qwen path is asymmetric the way the model was trained: search queries are
encoded with its retrieval instruction, documents plain. Run it locally with:

```bash
cd embedding_service
pip install -r requirements.txt
uvicorn app:app --port 8000
# then, in the app: EMBEDDINGS_PROVIDER=qwen EMBEDDINGS_URL=http://localhost:8000
bin/rails embeddings:reindex   # re-embed the corpus after switching providers
```

## Citator

- `CitingReference` is the directed edge spine: treatment enum (grouped
  positive/cautionary/negative), depth-of-treatment, pin cite, quoted passage.
- `Citator::TreatmentResolver` denormalizes the **worst inbound signal** onto
  `documents.treatment_status` ("Good Law" / "Caution" / "Negative" /
  "Unreviewed"), recomputed incrementally by `Citator::RecomputeTreatmentJob`
  whenever edges change or documents ingest.
- `Citator::EdgeBuilder` parses opinions for citations and infers treatment
  from signal verbs near each cite.

## Citation parsing

`Citations::Extractor` picks the backend:

- **eyecite** (Free Law Project — the parser CourtListener itself uses) via a
  small Python shim (`lib/python/extract_citations.py`). Requires
  `pip install eyecite`; auto-detected.
- **Pure-Ruby fallback** (`Citations::Parser`) with the same `Found` interface:
  reporters, statutes (U.S.C.), regulations (C.F.R.), short forms, and
  `id.`/`supra` resolution back to the first full cite.

Force one with `CITATION_PARSER=eyecite|ruby`.

## AI providers (switchable in Settings)

| Provider | Notes |
|---|---|
| `local` | Deterministic extractive answerer — offline, never invents text |
| `deepseek` | OpenAI-compatible API (`DEEPSEEK_API_KEY`, `DEEPSEEK_BASE_URL`, `DEEPSEEK_MODEL`) |
| `anthropic` | Official `anthropic` gem; default model `claude-opus-4-8` |
| `openai` | Chat completions (`OPENAI_API_KEY`) |

Answers are grounded: passages are retrieved from pgvector, the model is
instructed to cite `[n]` markers only from those sources, and the stored
sources render as linked chips in the UI. Per-user keys are encrypted at rest.

## Ingestion

`Ingest::BaseImporter` normalizes external corpora into `Document` +
`Citation` rows and enqueues `IngestDocumentJob` (index → embed → edge
extraction → treatment recompute). Included importers:

- `Ingest::CourtListenerImporter` — CourtListener REST API v4
  (`COURTLISTENER_API_KEY` / `COURTLISTENER_BASE_URL`)
- `Ingest::JsonImporter` — bulk JSON directories

## Getting started

Requirements: **Ruby 3.3+** (see `.ruby-version`), PostgreSQL 16+ with the
`vector` + `pg_trgm` extensions, Redis (cache/Action Cable/Sidekiq).
OpenSearch optional — the app falls back to Postgres without it.
Background jobs run inline-ish (`:async`) in development unless
`USE_SIDEKIQ=1` is set.

> ⚠️ macOS ships an ancient system Ruby (2.6 at `/usr/bin/ruby`) that
> cannot run this app and cannot install gems without sudo. If `ruby -v`
> says 2.6, do step 2 below before anything else — the
> "`windows` is not a valid platform" and "could not find bundler"
> errors both mean you're still on the system Ruby.

### macOS setup, start to finish

```bash
# 1. Services (Homebrew: https://brew.sh)
brew install postgresql@17 pgvector redis
brew services start postgresql@17
brew services start redis

# 2. A modern Ruby via rbenv (NOT the system Ruby)
brew install rbenv ruby-build
echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
exec zsh                          # reload your shell
rbenv install 3.3.6
cd caselight                      # picks up .ruby-version automatically
ruby -v                           # must print 3.3.6 — not 2.6!

# 3. The app
gem install bundler
bundle install
pip3 install eyecite              # optional but recommended
cp .env.example .env
open .env                         # paste in the API keys you have
bin/rails db:prepare db:seed      # builds the fictional demo corpus
bin/dev                           # web + tailwind watcher (+ sidekiq if USE_SIDEKIQ=1)
```

Then open <http://localhost:3000> and sign in with
**alex@example.com / password123** (admin → `/sidekiq`).

Notes for `.env`: one `VAR=value` per line, no comments on the same line
as a value, and `DEEPSEEK_MODEL` takes a **single** model name
(e.g. `DEEPSEEK_MODEL=deepseek-chat`).

### Linux

Same as above, minus Homebrew: install PostgreSQL 16 (+ the
`postgresql-16-pgvector` package), `redis-server`, and Ruby 3.3 via your
package manager or rbenv, then continue from step 3.

### Deploying

This is a full server app (Rails + PostgreSQL/pgvector + Redis + Sidekiq),
so it needs a host that runs persistent processes — **Railway, Render,
Fly.io, Hatchbox, or a VPS with Kamal** (a production `Dockerfile` is
included). Serverless platforms like **Vercel** and Netlify can't host it:
they only run short-lived functions and provide no Postgres, Redis, or
background workers.

On **Railway**, the layout is five services in one project:

| Service | Source | Notes |
|---|---|---|
| `web` | this repo, root dir `caselight` (Dockerfile) | first boot runs `db:prepare` + `db:seed`, then enqueues re-embedding if vectors are stale (all idempotent) |
| `worker` | same image | custom start command `bundle exec sidekiq`; processes the re-embedding jobs (it can reach `embeddings` over the private net) |
| `embeddings` | root dir `caselight/embedding_service` (Dockerfile) | Qwen3-Embedding-0.6B service; needs ~2 GB RAM, weights are baked into the image |
| `postgres` | image `pgvector/pgvector:pg17` | volume at `/var/lib/postgresql/data` |
| `redis` | Railway Redis template | |

Set on `web` + `worker`: `RAILS_MASTER_KEY` (from `config/master.key`),
`DATABASE_URL`, `REDIS_URL`, `DISABLE_OPENSEARCH=1`, `APP_HOST` (your
public domain), `EMBEDDINGS_PROVIDER=qwen`,
`EMBEDDINGS_URL=http://embeddings.railway.internal:8000`, plus any
AI/provider keys from `.env.example`. Single process on a budget? Skip
`worker` and set `ACTIVE_JOB_ADAPTER=async` on `web`. Attach a volume at
`/rails/storage` to keep uploads across deploys.

## Tests

```bash
bundle exec rspec
```

Focused coverage on the parts that are easy to get subtly wrong: the query
planner, the boolean translator (tsquery + OpenSearch query_string), RRF,
the citation parser (incl. short-form resolution), citation matching, the
treatment resolver (worst-wins, counters), the brief analyzer, and the
search engine's PG-fallback hybrid path.

## A note on the treatment flag in the demo

The featured seed case carries 7 "distinguished" + 9 other cautionary
citations (to match the demo design's treatment panel), so its flag resolves
to **Caution** — the resolver is strictly worst-wins per spec. A citator that
showed "Good Law" over live cautionary treatment would be lying to you.
