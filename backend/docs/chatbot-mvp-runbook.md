# Chatbot Knowledge MVP Runbook

> Pilot only. This MVP supports independent questions from landlord accounts against explicitly approved Markdown documents. It does not read live billing/property data and does not perform business actions.

## Implementation update (2026-10-22, Asia/Ho_Chi_Minh)

Tasks 4-6 now have implementation and software tests: authenticated ask/source endpoints, a single inference slot, a whole-pipeline deadline, actor-based rate limiting, and the landlord Flutter chat/source sheet. **Pilot acceptance has not passed.** During the initial implementation verification, the documents were unapproved and Ollama was offline. Subsequently, the project owner explicitly approved all six documents in chat; they are now imported into the local application database as 19 chunks. The local endpoint is enabled with verified models and a candidate score of 0.4423. Real-model and API checks are recorded in `chatbot-local-setup-2026-10-22.md`; they do not replace pilot acceptance. The model/memory measurements in the next historical section are from 2026-10-17, not newly reproduced values.

Flutter entry: the book icon in the dashboard header or More / Management Menu → Trợ lý tài liệu. Header entry carries the displayed property into chat. Each question is independent. Changing account/property clears messages, hides an open source, cancels pending requests, and discards late responses even if the transport ignores cancellation. Clearing/leaving chat also cancels active requests.

## Local model check (measured 2026-10-17, M4 16 GB)

| Model | Tag / digest | Details | Smoke result |
| --- | --- | --- | --- |
| Qwen chat | `qwen2.5:7b` / `845dbda0ea48ed749caafd9e6037047aa19acfcfd82e704d7ca97d631a0b697e` | Qwen2 7.6B, Q4_K_M, Ollama 0.12.6, Apache-2.0 | Structured Vietnamese answer, valid cited ID and explicit no-evidence response in 5 fixed cases; cold 15.2s, 4 warm cases 2.7–3.9s |
| Embedding | `embeddinggemma:latest` / `85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1` | Gemma3 307.58M, BF16, 768 dimensions, Gemma Terms of Use | 2 Vietnamese paragraphs embedded consistently; cold 1.52s, warm 78ms |

This is a small smoke test, not a quality benchmark or a production SLA. The embedding model uses Gemma Terms of Use, which differ from Apache-2.0; review those terms before redistributing or offering the service. Only Qwen and embeddinggemma were tested. A separate Llama comparison was not run. Swap usage was already about 8.2 GB before model loading, rose to about 10.4 GB during first chat-model load, and was about 9.9 GB after the smoke evaluation; the model was unloaded afterward. These readings reflect the whole active desktop, not Ollama-only allocation.

### Preliminary retrieval check

The approved-guide format was exercised using temporary, explicitly labeled test-fixture copies in the isolated `rental_chatbot_test_mvp` database. An embedding + cosine + Vietnamese keyword rerank returned the expected document in top 3 for 4/5 fixed questions. Invoice, payment, room-management and no-live-balance queries retrieved the expected guide; the device-repair question initially did not. The maintenance draft was made more explicit about broken equipment and repair wording, but the re-index/recheck was not completed during that early handoff. The threshold was intentionally unset at that stage. This historical result is superseded for local startup by the approved-corpus check recorded above; full pilot calibration/acceptance remains pending.

## Run Ollama with one model resident

The local machine showed about 8.2 GB swap already in use before loading a model. Keep Ollama single-model and sequential to limit memory pressure; switching between embedding and chat may increase cold latency.

```sh
OLLAMA_HOST=127.0.0.1:11434 \
OLLAMA_NUM_PARALLEL=1 \
OLLAMA_MAX_LOADED_MODELS=1 \
OLLAMA_CONTEXT_LENGTH=4096 \
ollama serve
```

In another terminal:

```sh
ollama pull qwen2.5:7b
ollama pull embeddinggemma:latest
ollama list
```

Check digests using `curl http://127.0.0.1:11434/api/tags`. Keep Ollama bound to loopback/private networking; do not publish port 11434 to the internet.

## Configure NestJS

Start with `CHATBOT_ENABLED=false`. Add the verified embedding digest, not the chat model digest:

```env
CHATBOT_ENABLED=false
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_CHAT_MODEL=qwen2.5:7b
OLLAMA_EMBED_MODEL=embeddinggemma:latest
OLLAMA_EMBED_DIGEST=85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1
OLLAMA_EMBED_DIMENSIONS=768
CHATBOT_TIMEOUT_MS=60000
RAG_MIN_SCORE=<calibrate using the approved corpus before enabling chat>
KNOWLEDGE_ROOT=knowledge
```

The runtime controller is now registered by ChatbotModule. Model startup is lazy: disabling the feature does not contact Ollama or stop the business API. Enable CHATBOT_ENABLED only after approved-corpus evaluation and performance gates pass.

## Approve documents and import

The six files in `knowledge/vi/` are drafts generated from current UI/source patterns. Verify each procedure in the running app and source before approval. In particular, these files do not define actual house rules, service prices, deposit policy, or legal terms. Keep unconfirmed content out of the active corpus.

1. Edit `knowledge/manifest.json` and each selected Markdown document only after review.
2. For each approved entry, set `approved: true`, set `approvedBy` to the human reviewer and `approvedAt` to an ISO timestamp. The CLI enforces this metadata but cannot prove a human actually reviewed it.
3. Confirm `.env` points at the intended database. The importer writes to whichever `DATABASE_URL` is configured; use a dedicated database first.
4. Set `OLLAMA_EMBED_DIGEST` to the exact digest from `/api/tags`.
5. Run the explicit manifest command from the backend root:

```sh
npm run knowledge:import -- --manifest knowledge/manifest.json
```

The importer validates all manifest entries and scopes first, embeds content before opening the replacement transaction, rechecks model digest, and atomically replaces each document's metadata/chunks. Identical approved entries are skipped. An embedding error leaves that document's prior index unchanged. Revoke an entry using its stable key:

```sh
npm run knowledge:revoke -- --key guide-billing
```

Revocation sets the entry inactive. Re-importing the same explicitly approved manifest will publish it again.

## Database migration

The migration `20261017090000_chatbot_knowledge` creates `KnowledgeDocument`, `KnowledgeChunk` and the composite property-owner key. It was applied during development to the local database configured by backend `.env` and to the separate `rental_chatbot_test_mvp` verification database. That local database was unintended for the initial migration command; no automatic rollback was performed. Confirm the actual migration state and take a backup before any rollback decision. Do not apply production migrations until the destination and rollout are explicitly reviewed.

Verify a dedicated test database before running DB integration tests:

```sh
createdb rental_chatbot_test_mvp
DATABASE_URL=postgresql://<local-user>@127.0.0.1:5432/rental_chatbot_test_mvp?schema=public npx prisma migrate deploy
DATABASE_URL=postgresql://<local-user>@127.0.0.1:5432/rental_chatbot_test_mvp?schema=public npx prisma generate
KNOWLEDGE_TEST_DATABASE_URL=postgresql://<local-user>@127.0.0.1:5432/rental_chatbot_test_mvp?schema=public npm test -- --runInBand src/chatbot
```

The integration test refuses a non-loopback URL or a database name outside `rental_chatbot_test_*`. It creates and deletes only UUID-prefixed fixtures.

## Scope and limitations

- Retrieval accepts global help documents, the authenticated landlord's documents and the selected owned property's documents. It rejects cross-owner resources and fails closed if active documents use a different embedding-model digest.
- Retrieval uses exact in-process cosine similarity and supports at most 1,000 eligible chunks per request. The query is scoped in PostgreSQL before loading vectors.
- The chunker preserves Markdown headings, removes Markdown editorial HTML comments from searchable text, splits at no more than 1,200 characters per chunk and overlaps up to 150 characters. Embedding requests use `truncate: false`. Document hashes include the `chatbot-chunker-v1` revision so a chunking policy change forces reindexing.
- The implementation now includes authenticated ask/source endpoints and the Flutter screen. Live-data tools, persisted history, administrator document workflow, file upload, PDF/DOCX/OCR, streaming and multi-turn memory remain outside the MVP.
- CLI import is a local maintenance command. Do not expose it as an HTTP endpoint.
- Unit tests use mocked Ollama; live model checks are recorded in this runbook and are not CI requirements.
