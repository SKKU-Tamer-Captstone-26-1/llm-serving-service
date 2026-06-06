# Tests

There is no application wrapper in this repository, so runtime tests are deployment and API compatibility checks.

Recommended checks:

```bash
bash -n scripts/*.sh
scripts/build_local.sh
LLM_ENDPOINT_URL=http://localhost:8080/v1/chat/completions scripts/smoke_chat_completion.sh
```

For Cloud Run staging:

```bash
gcloud run services proxy llm-serving-service-staging \
  --project=on-the-block-2026 \
  --region=asia-southeast1 \
  --port=18080

LLM_ENDPOINT_URL=http://127.0.0.1:18080/v1/chat/completions \
scripts/smoke_chat_completion.sh
```

Acceptance criteria:

- `/v1/chat/completions` returns OpenAI-compatible JSON.
- Korean response is concise.
- Response uses supplied facts only.
- No recommendation logic or database access is added to this repository.
