#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-llm-serving-service:local}"
PLATFORM="${PLATFORM:-linux/amd64}"

docker build --platform "${PLATFORM}" -t "${IMAGE_NAME}" .

cat <<EOF
Built ${IMAGE_NAME} for ${PLATFORM}

Run with:
  docker run --rm --gpus all -e MODEL_ID=Qwen/Qwen2.5-7B-Instruct -e PORT=8080 -p 8080:8080 ${IMAGE_NAME}

Smoke test:
  LLM_ENDPOINT_URL=http://localhost:8080/v1/chat/completions scripts/smoke_chat_completion.sh

Actual inference requires NVIDIA GPU support and model download access.
EOF
