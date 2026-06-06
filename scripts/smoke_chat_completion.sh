#!/usr/bin/env bash
set -euo pipefail

LLM_ENDPOINT_URL="${LLM_ENDPOINT_URL:-http://localhost:8080/v1/chat/completions}"
MODEL_ID="${MODEL_ID:-Qwen/Qwen2.5-7B-Instruct}"

curl_args=(-sS "${LLM_ENDPOINT_URL}" -X POST -H "Content-Type: application/json")
if [[ -n "${LLM_AUTH_TOKEN:-}" ]]; then
  curl_args+=(-H "Authorization: Bearer ${LLM_AUTH_TOKEN}")
fi

response_file="$(mktemp)"
trap 'rm -f "${response_file}"' EXIT

http_status="$(
  curl "${curl_args[@]}" -o "${response_file}" -w "%{http_code}" --data-binary @- <<JSON
{
  "model": "${MODEL_ID}",
  "messages": [
    {
      "role": "system",
      "content": "너는 ONTHEBLOCK 추천 챗봇의 한국어 응답 작성기다. 제공된 사실만 사용하고 새로운 추천을 만들지 않는다."
    },
    {
      "role": "user",
      "content": "근거 사실: 추천 음료는 진토닉입니다. 이유는 라임 향과 탄산감이 사용자의 산뜻한 취향과 맞기 때문입니다. 장소는 홍대 A바입니다. 위 사실만 사용해 한 문장으로 짧게 답하세요."
    }
  ],
  "max_tokens": 160,
  "temperature": 0.2,
  "stream": false
}
JSON
)"

cat "${response_file}"
printf "\n"

if [[ "${http_status}" -lt 200 || "${http_status}" -ge 300 ]]; then
  printf "smoke request failed with HTTP %s\n" "${http_status}" >&2
  exit 1
fi
