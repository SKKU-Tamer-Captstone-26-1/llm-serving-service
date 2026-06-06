# Scripts

## `build_local.sh`

Builds the local TGI image:

```bash
scripts/build_local.sh
```

The build verifies the Dockerfile and pinned base image. Running Qwen 7B inference still requires NVIDIA GPU support and model download access.

Override the image name:

```bash
IMAGE_NAME=llm-serving-service:test scripts/build_local.sh
```

## `smoke_chat_completion.sh`

Sends a minimal OpenAI-compatible request to `/v1/chat/completions`.

```bash
LLM_ENDPOINT_URL=http://localhost:8080/v1/chat/completions \
MODEL_ID=Qwen/Qwen2.5-7B-Instruct \
scripts/smoke_chat_completion.sh
```

For private Cloud Run from a developer machine, use an authenticated local proxy:

```bash
gcloud run services proxy llm-serving-service-staging \
  --project=on-the-block-2026 \
  --region=asia-southeast1 \
  --port=18080

LLM_ENDPOINT_URL=http://127.0.0.1:18080/v1/chat/completions \
scripts/smoke_chat_completion.sh
```

For CI or service-account callers, set `LLM_AUTH_TOKEN` to an audience-bound Google ID token.
