# Chatbot API and pilot handoff

Date: 2026-10-22, Asia/Ho_Chi_Minh. Software implementation is present; live pilot approval is pending. Do not treat mocked-model tests or valid citation IDs as proof of answer correctness.

Approved local corpus update: after the project owner's explicit chat approval on 2026-10-22, all six documents were imported (19 chunks), first in an isolated database and then in the local application database. The development endpoint is enabled with `RAG_MIN_SCORE=0.4423`. Real-model checks returned the expected status for 20/20 cases, with 14/15 expected-source citations; authenticated API answers and source opening also passed. See `chatbot-local-setup-2026-10-22.md`. Historical statements below about a disabled runtime describe the earlier software-verification run. Pilot remains unapproved: answer correctness review, benchmark and memory gates are still outstanding.

## API contract

- POST /api/v1/chatbot/ask accepts message (1-1,000 trimmed characters) and optional propertyId. Only the authenticated LANDLORD is allowed. Unknown fields and explicit null scopes are rejected.
- GET /api/v1/chatbot/sources/:id accepts optional propertyId. Ownership and active status are checked again. Content is returned as text, never a model-controlled URL.
- Successful responses use the data envelope. Answer status is answered or insufficient_evidence; answered always has verified sources. A missing/changed source invalidates the generated answer.
- Missing/invalid JWT: 401; other roles: 403; inaccessible property/source: 404; invalid DTO: 400. Chatbot errors use error.code and error.message.
- AI_BUSY and AI_RATE_LIMITED return 429 with Retry-After (5 and 60 seconds). There is one inference slot per instance and five POST attempts per authenticated user per minute. The existing global API IP limit remains unchanged.
- AI_DISABLED / AI_UNAVAILABLE: 503; AI_TIMEOUT: 504; AI_INVALID_RESPONSE: 502. Incompatible or oversized indexes return 503 rather than masquerading as insufficient evidence.
- Default deadline: 60 seconds, shared across scope checks, retrieval, model generation and final source checks. Context overflow retries once with one source only. No other model/network retry, cloud fallback, live-data tools or writes are implemented.
- Runtime logs contain server request ID, embedding digest, duration, retrieved chunk count and error code. Questions/answers are not logged or stored in the database. The local evaluation report contains only the fixed evaluation dataset's answers for human review.

## Software verification

Verified on 2026-10-22: all 153 backend unit/DB tests pass; the 23 chatbot E2E cases pass with real JWT/PostgreSQL and mocked Ollama; npm run build passes. Flutter passes 145 tests and flutter analyze reports no issues. The repository-wide backend E2E run passes 30/32 tests: unrelated existing billing-flow expectations fail at test/e2e/lease-billing-dashboard.e2e-spec.ts:175 (current-month count 0, expected >=1) and test/e2e/tenant-portal-priority.e2e-spec.ts:153 (3,670,000, expected 3,650,000). Their business code/fixtures were not changed for this feature. Model-quality and warm/cold/RAM acceptance remains pending.

Use a dedicated local database whose name starts with rental_chatbot_test_. The E2E suite enforces this. Do not aim the repository's full E2E reset helpers at any database containing user data.

Commands from the backend root:

    DATABASE_URL=postgresql://<local-user>@127.0.0.1:5432/rental_chatbot_test_<suffix>?schema=public npm exec prisma migrate deploy
    KNOWLEDGE_TEST_DATABASE_URL=<test-url> npm test -- --runInBand
    DATABASE_URL=<test-url> npm run test:e2e -- chatbot.e2e-spec.ts
    npm run build
    DATABASE_URL=<test-url> npm run chatbot:evaluate -- --software-only

The runner executes chatbot unit/DB tests and real JWT/PostgreSQL endpoint tests with Ollama mocked. Ten permission/lifecycle cases are backed by those suites. Twenty model-quality cases are explicitly recorded as not_run in software-only mode. A software-only report never declares pilot readiness. The runtime feature flag remains disabled.

This implementation used the newly created rental_chatbot_test_20261022 database. No migration or corpus import was performed against the application's configured operational database. The older 2026-10-17 migration incident remains documented in chatbot-mvp-runbook.md.

## Content approval and calibration

1. Start Ollama as documented in chatbot-mvp-runbook.md, bound to loopback with one model resident. Inspect actual tags/digests; do not silently accept a changed embedding tag.
2. Review all six knowledge/vi documents against the running application. Only the human reviewer may approve the manifest. Keep unconfirmed house rules and legal/payment policies out of the corpus.
3. Import explicitly approved content into the isolated evaluation database with the existing knowledge:import command. Use an isolated landlord ID for evaluation. Do not rewrite approvals to make tests pass.
4. Run knowledge:evaluate with KNOWLEDGE_EVAL_LANDLORD_ID and the verified embedding digest. It reports positive matching scores and negative top-score distributions. These are hybrid ranking scores, not probabilities. Choose and record RAG_MIN_SCORE using those results. If the distributions do not separate, improve retrieval/model/data and evaluate again instead of relaxing access control.
5. Configure the candidate score, exact embedding digest, selected chat model and dimension, then run the full fixed-dataset evaluator:

    DATABASE_URL=<test-url> KNOWLEDGE_EVAL_LANDLORD_ID=<test-owner> npm run chatbot:evaluate -- --benchmark=30

Optional KNOWLEDGE_EVAL_PROPERTY_ID adds one owned property to the scope. KNOWLEDGE_ROOT selects the approved manifest directory. CHATBOT_EVAL_REPORT changes the output path (default docs/chatbot-eval-report.local.json, ignored by Git).

The runner refuses unapproved manifests, incomplete corpora, non-isolated databases and incompatible embedding metadata. It records the dataset hash, model digests, corpus hashes, ranking scores, fixed-question answers, citation metadata, errors and warm p50/p95 at the service-pipeline layer (without HTTP/Flutter overhead). Confirm the actual API/app end-to-end timings separately before pilot. Cold measurements are explicitly not inferred from this run: measure after restarting/unloading models and report separately, along with peak RAM/swap.

Automated gate: at least 14/15 expected documents retrieved in top 3, at least 13/15 answers with expected-source citations, all 5/5 negative fallbacks, passing permission/lifecycle suites, at least 30 successful warm answered requests, no timeouts and warm p95 <=30 seconds. Expected-source citation presence is NOT a correctness score. A human must independently mark at least 13/15 answers correct against the dataset checklists and review negative answers before enabling pilot. The report always leaves pilotReady=false until an operator completes those external approvals; the evaluator never changes feature flags.

## Start Flutter and enable the reviewed pilot

After the content, model, memory and quality gates pass, set CHATBOT_ENABLED=true in the intended backend environment and restart the backend with npm run start:dev. Keep embedding digest and the approved corpus in sync. Start Flutter from the Flutter root:

    flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1

Use a backend address reachable from a physical device rather than the device's own loopback. Sign in as a landlord, open the dashboard book icon, ask how to create an invoice and open its source. Then ask for the current debt of a room: the assistant must explain that live data is unsupported, without inventing an amount.

## Operations and rollback

- Model unavailable: check the local Ollama service, tags, loopback binding and resource pressure. Do not expose Ollama publicly or redirect requests to a cloud provider.
- AI_BUSY: wait before sending again. There is no unbounded queue. Flutter retries only after the user asks, except for the application's existing JWT refresh flow.
- KNOWLEDGE_INDEX_INCOMPATIBLE: disable chat, reindex the complete approved corpus with the exact new digest/dimension, recalibrate and reevaluate before reenabling. No vector-database migration is needed for this MVP.
- Revoke immediately with knowledge:revoke -- --key <stable-key>. Opening the old source fails; answers in flight are discarded after final active/hash/ownership checks. Reimporting an approved manifest republishes the document deliberately.
- Run ingestion offline/maintenance, not concurrently with chat. Snapshot/back up the database/index before planned updates. Import computes all vectors before the short per-document replacement transaction, so a failed document import retains its old index.
- Roll back by setting CHATBOT_ENABLED=false and restarting; business functions continue. Do not drop tables or erase old indexes as an emergency rollback.
