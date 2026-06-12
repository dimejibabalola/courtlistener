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

Embeddings default to a deterministic offline hash embedder
(`Embeddings::HashEmbedder`, 768-dim) so the demo runs with zero keys; set
`EMBEDDINGS_PROVIDER=openai` (+ `OPENAI_API_KEY`) and re-index to use hosted
embeddings.

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

```bash
cd caselight
bundle install
pip3 install eyecite              # optional but recommended
cp .env.example .env              # fill in provider keys you have
bin/rails db:prepare db:seed      # builds the fictional demo corpus
bin/dev                           # web + tailwind watcher (+ sidekiq if USE_SIDEKIQ=1)
```

Sign in with **alex@example.com / password123** (admin → `/sidekiq`).

Requirements: Ruby 3.3+, PostgreSQL 16 with the `vector` + `pg_trgm`
extensions, Redis (cache/Action Cable/Sidekiq). OpenSearch optional.
Background jobs run inline-ish (`:async`) in development unless
`USE_SIDEKIQ=1` is set.

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
