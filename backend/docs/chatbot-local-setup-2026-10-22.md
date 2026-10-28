# Local chatbot and approved-corpus status

Checked on 2026-10-22, Asia/Ho_Chi_Minh. Following the project owner's explicit chat approval, the local application now answers against the six approved documents. This is not pilot approval or completed RAG acceptance.

## Applied configuration

The backend `.env` now has `CHATBOT_ENABLED=true`, loopback Ollama at `http://127.0.0.1:11434`, `qwen2.5:7b` for chat, `embeddinggemma:latest` for embeddings, 768 dimensions, and a 60-second pipeline timeout. The embedding digest was read from the running local Ollama service:

    85462619ee721b466c5927d109d4cb765861907d5417b9109caebc4e614679f1

All previously configured database, JWT and CORS settings were preserved. A permission-600 backup of the original environment exists at `.env.before-chatbot-20261022.yQnk1e`. The example environment continues to default to disabled.

`RAG_MIN_SCORE=0.4423` is a measured local candidate, NOT an accepted pilot configuration. It lies between the off-topic weather question's top score (0.43675) and the next expected-source positive score (0.44783). Scores alone do not separate every negative: live-data and ambiguous questions also use deterministic refusals, while unsupported deposit policy requires the model to abstain. A full 20-case service run on the approved corpus in `rental_chatbot_test_setup_20261022` verified those outcomes before applying the candidate locally. The previous conservative bootstrap value of 0.5 retained only 7/15 expected positive sources.

## Verified behavior

- Backend build succeeds; the focused import, chunking, config and Ollama adapter suites pass 57 tests.
- The development server was restarted and listens on port 3000.
- All six manifest entries record the owner's explicit chat approval. Their Markdown content was not rewritten after approval.
- Both the isolated evaluation database and the local application database contain six documents and 19 chunks. A second import returned `unchanged` for all six entries, confirming idempotence. Application import ran while its backend was stopped.
- User, property, room, tenant, lease, invoice and payment row counts match the pre-import snapshot; no business model writes were performed.
- In the isolated real-model service run, 15/15 positive questions returned answers, 5/5 negative questions returned insufficient evidence, and there were no request errors. Expected-source retrieval and citations passed 14/15 positives.
- On the running application API, the invoice question returned an answer in about 12.1 seconds and the payment-proof question in about 8.5 seconds. Both source links were fetched successfully and matched the cited content hash.
- The current-room-debt question returned the explicit live-data refusal, not an invented balance. An inaccessible property scope returned HTTP 404. Authentication remains required.
- Detailed fixed-dataset service and API results are in the ignored local report `docs/chatbot-approved-smoke.local.json`. These single-run API timings are not cold/warm benchmark percentiles.

## Remaining pilot gates

Content approval is complete, but answer correctness approval is separate. The invoice-creation case q08 cites the general FAQ instead of its expected detailed billing guide. Its answer is therefore not counted as an expected-source success, even though it has a valid citation. Review the actual answer checklists, resolve quality gaps, and complete at least 30 successful warm requests plus cold/RAM/swap and app-level timing checks before declaring pilot readiness.

Flutter use: sign in as a landlord, open the dashboard book icon or More / Management Menu -> Tro ly tai lieu, and send a new question. Old insufficient-evidence messages in an existing conversation are not rewritten by the import.

See `chatbot-api-and-pilot.md` for the import, evaluation, permission and performance gates. Disable the feature again with `CHATBOT_ENABLED=false` and restart the backend if local testing is no longer needed.
