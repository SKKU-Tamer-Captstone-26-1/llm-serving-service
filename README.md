# llm-serving-service

`llm-serving-service` is ONTHEBLOCK's GPU-backed LLM inference service. It exposes an OpenAI-compatible endpoint for `chatbot-service`:

```text
POST /v1/chat/completions
```

The service is a Korean response writer. `chatbot-service` authenticates the user, calls `recommendation-service`, builds grounded recommendation context, applies orchestration and guardrails, and calls this service only to turn supplied facts into concise Korean natural-language responses.

## Boundaries

This service does:

- Serve an open LLM with Hugging Face Text Generation Inference (TGI).
- Keep the API compatible with OpenAI-style chat completions.
- Load the model selected by `MODEL_ID`.
- Run on GCP Cloud Run GPU with NVIDIA L4.

This service does not:

- Rank, score, filter, or generate recommendations.
- Implement RAG retrieval, user profiling, survey logic, map lookup, venue lookup, or price lookup.
- Connect to recommendation, survey, auth, map, chatbot, venue, or service databases.
- Store raw user messages by default.
- Log full prompts, grounded context, user messages, or model responses by default.
- Own chatbot guardrails or recommendation truth.

## Runtime

The starter uses the official Hugging Face TGI container image. TGI already serves `/v1/chat/completions`, so this repository does not add a Python wrapper.

Pinned image:

```text
ghcr.io/huggingface/text-generation-inference:sha-db931fc
```

The official TGI docs currently show `3.3.5` in examples, but that tag did not resolve from GHCR during local verification on June 6, 2026. The pinned `sha-db931fc` tag was verified with `docker manifest inspect` for `linux/amd64`, and local/Cloud Build commands request `linux/amd64` explicitly.

Default model:

```text
Qwen/Qwen2.5-7B-Instruct
```

TGI can later be replaced by vLLM behind the same OpenAI-compatible route without requiring a chatbot-service endpoint change.

## Chatbot Integration

The chatbot-service should point at the Cloud Run URL:

```env
CHATBOT_LLM_ENDPOINT_URL=https://<llm-cloud-run-url>/v1/chat/completions
CHATBOT_LLM_MODEL=Qwen/Qwen2.5-7B-Instruct
CHATBOT_LLM_AUTH_MODE=none
```

`CHATBOT_LLM_AUTH_MODE=none` means no application-level LLM API key. It does not bypass Cloud Run IAM. The deployment config keeps Cloud Run private by default with `--no-allow-unauthenticated`, so chatbot-service must send a Google-signed ID token and its runtime service account must have `roles/run.invoker`. Use `_ALLOW_UNAUTHENTICATED=true` only for an explicitly approved temporary public smoke-test environment.

## Environment Variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `MODEL_ID` | `Qwen/Qwen2.5-7B-Instruct` | TGI model identifier to load. |
| `PORT` | `8080` | Local/TGI port default. Cloud Run injects `PORT`; do not pass it via `--set-env-vars`. |
| `REVISION` | empty | Optional Hugging Face model revision. |
| `HF_TOKEN` | empty | Only for private or gated Hugging Face model pulls. |
| `NUM_SHARD` | `1` | One shard for one Cloud Run L4 GPU. |
| `MAX_INPUT_TOKENS` | `2048` | Maximum prompt/input tokens. |
| `MAX_TOTAL_TOKENS` | `3072` | Maximum input plus generated tokens. |
| `MAX_BATCH_PREFILL_TOKENS` | `4096` | TGI prefill batch token limit. |
| `MAX_CONCURRENT_REQUESTS` | `4` | TGI request backpressure limit. |
| `DTYPE` | `float16` | Model dtype for NVIDIA L4. |
| `QUANTIZE` | empty | Optional TGI quantization mode. |
| `TRUST_REMOTE_CODE` | `false` | Keep false unless a pinned model revision requires it. |
| `ALLOW_UNAUTHENTICATED` | `false` | Deployment switch, not a TGI runtime variable. |

`HOSTNAME=0.0.0.0` and `USAGE_STATS=off` are also set for the container.

## Local Build And Run

Build the image:

```bash
scripts/build_local.sh
```

Run with NVIDIA GPU support:

```bash
docker run --rm --gpus all \
  -e MODEL_ID=Qwen/Qwen2.5-7B-Instruct \
  -e PORT=8080 \
  -p 8080:8080 \
  llm-serving-service:local
```

TGI is GPU-oriented. Local CPU-only runs are not a meaningful Qwen 7B inference check.

## Smoke Test

Local:

```bash
LLM_ENDPOINT_URL=http://localhost:8080/v1/chat/completions \
MODEL_ID=Qwen/Qwen2.5-7B-Instruct \
scripts/smoke_chat_completion.sh
```

Private Cloud Run:

```bash
gcloud run services proxy llm-serving-service-staging \
  --project=on-the-block-2026 \
  --region=asia-southeast1 \
  --port=18080

LLM_ENDPOINT_URL=http://127.0.0.1:18080/v1/chat/completions \
scripts/smoke_chat_completion.sh
```

For CI or a service account caller, set `LLM_AUTH_TOKEN` to an audience-bound Google ID token for the Cloud Run service URL.

## Request Shape

```json
{
  "model": "Qwen/Qwen2.5-7B-Instruct",
  "messages": [
    {
      "role": "system",
      "content": "너는 ONTHEBLOCK 추천 챗봇의 한국어 응답 작성기다. 제공된 사실만 사용한다."
    },
    {
      "role": "user",
      "content": "사실: 추천 음료는 진토닉, 이유는 라임 향과 탄산감입니다. 한 문장으로 답하세요."
    }
  ],
  "max_tokens": 160,
  "temperature": 0.2,
  "stream": false
}
```

TGI returns OpenAI-compatible chat completion JSON with `choices[0].message.content`.

## Cloud Run GPU Deployment

Official Cloud Run GPU docs list NVIDIA L4 support in `asia-southeast1`, but not `asia-northeast3`. Staging therefore defaults to Singapore. A Seoul-hosted chatbot-service may call this service cross-region until Cloud Run GPU is available in Seoul or another ONTHEBLOCK GPU region is chosen.

Deploy:

```bash
gcloud builds submit \
  --project=on-the-block-2026 \
  --config=deploy/gcp/cloudbuild.staging.yaml \
  --substitutions=_REGION=asia-southeast1,_REPOSITORY=ontheblock-llm,_SERVICE_NAME=llm-serving-service-staging,_SERVICE_ACCOUNT=llm-serving-staging@on-the-block-2026.iam.gserviceaccount.com,_MODEL_ID=Qwen/Qwen2.5-7B-Instruct
```

The deployment uses one `nvidia-l4`, 8 CPU, 32Gi memory, concurrency 1, max instances 1, min instances 0, timeout 900 seconds, and private Cloud Run by default.

## Changing The Model

Set `MODEL_ID` at deployment time:

```bash
gcloud builds submit \
  --project=on-the-block-2026 \
  --config=deploy/gcp/cloudbuild.staging.yaml \
  --substitutions=_MODEL_ID=<new-hugging-face-model-id>
```

If the model is private or gated, store the Hugging Face read token in Secret Manager and pass `_HF_TOKEN_SECRET_VERSION=<secret-name>:<pinned-version>`. Do not commit token values.

## Verification Status

Shell syntax checks and repository static checks can run without GPU. The pinned TGI image manifest was verified for `linux/amd64`; a full local Docker build was started but intentionally stopped while pulling multi-GB TGI layers. Full Qwen inference was not run locally because it requires a completed image pull, model download access, and an NVIDIA GPU/runtime.

Staging was deployed on Cloud Run GPU in `asia-southeast1` with the image tag `staging-manual-20260606-1`, and the private `/v1/chat/completions` endpoint passed the smoke script through `gcloud run services proxy`. The checked-in Cloud Build deploy config was YAML-validated, but the first live deployment used a direct `gcloud run deploy` after build/push to avoid adding broader project-level deploy IAM during this setup.
