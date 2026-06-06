# Chatbot Integration

The chatbot-service calls this service after it has already authenticated the user and assembled grounded recommendation context.

## Environment

```env
CHATBOT_LLM_ENDPOINT_URL=https://<llm-cloud-run-url>/v1/chat/completions
CHATBOT_LLM_MODEL=Qwen/Qwen2.5-7B-Instruct
CHATBOT_LLM_AUTH_MODE=none
```

Keep the endpoint path unchanged. The staging deployment is private by default, which means the chatbot-service caller must send a Google ID token and its runtime service account must have `roles/run.invoker`. If the current chatbot-service deployment can only use `CHATBOT_LLM_AUTH_MODE=none`, set `_ALLOW_UNAUTHENTICATED=true` for that environment intentionally.

`CHATBOT_LLM_AUTH_MODE=none` means there is no application-level LLM API key. It does not bypass Cloud Run IAM. Private Cloud Run still requires a Google-signed ID token in the request.

## Request Example

```bash
curl "$CHATBOT_LLM_ENDPOINT_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-7B-Instruct",
    "messages": [
      {
        "role": "system",
        "content": "너는 ONTHEBLOCK 추천 챗봇의 한국어 응답 작성기다. 제공된 사실만 사용하고 새로운 추천을 만들지 않는다."
      },
      {
        "role": "user",
        "content": "근거 사실: 추천 음료=진토닉, 추천 이유=라임 향과 탄산감이 사용자 취향과 맞음, 장소=홍대 A바. 한 문장으로 답하세요."
      }
    ],
    "max_tokens": 160,
    "temperature": 0.2,
    "stream": false
  }'
```

## Grounding Contract

The chatbot-service supplies all recommendation facts in the prompt. The LLM service does not verify those facts, fetch missing facts, or change recommendation order. It should only generate concise Korean prose from the supplied context.

If the prompt lacks enough facts, the response should be conservative. Truth verification belongs in chatbot-service and recommendation-service, not here.
