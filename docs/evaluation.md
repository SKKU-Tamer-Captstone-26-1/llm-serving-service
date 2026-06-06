# Evaluation

This service is evaluated as an LLM runtime, not as a recommender.

## What To Prove

- `/v1/chat/completions` is reachable.
- The deployed model can produce concise Korean responses.
- The response uses supplied grounded facts.
- The model stays stable under expected token limits.
- Private Cloud Run auth works when enabled.

## What Not To Prove Here

- Recommendation ranking quality.
- Recommendation truth.
- Survey/profile correctness.
- Venue, map, price, or menu correctness.
- Chatbot guardrail completeness.

Those checks belong to chatbot-service and recommendation-service.

## Smoke Test

Run:

```bash
LLM_ENDPOINT_URL=http://localhost:8080/v1/chat/completions \
MODEL_ID=Qwen/Qwen2.5-7B-Instruct \
scripts/smoke_chat_completion.sh
```

For a private Cloud Run service from a developer machine:

```bash
gcloud run services proxy llm-serving-service-staging \
  --project=on-the-block-2026 \
  --region=asia-southeast1 \
  --port=18080

LLM_ENDPOINT_URL=http://127.0.0.1:18080/v1/chat/completions \
MODEL_ID=Qwen/Qwen2.5-7B-Instruct \
scripts/smoke_chat_completion.sh
```

Expected behavior:

- HTTP request succeeds.
- JSON response contains `choices[0].message.content`.
- Korean response is short.
- Response does not invent a different recommendation.

## Stability Checks

Before promoting a revision:

- Send several short grounded prompts.
- Send one prompt near `MAX_INPUT_TOKENS`.
- Confirm errors are structured and do not leak secrets.
- Confirm logs do not contain full raw prompts by default.
- Confirm Cloud Run metrics show GPU-backed instances rather than CPU fallback.
