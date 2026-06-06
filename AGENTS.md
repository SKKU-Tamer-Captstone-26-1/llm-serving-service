# AGENTS.md

This repository is only for LLM serving in the ONTHEBLOCK system.

## Service Ownership

- `llm-serving-service` exposes OpenAI-compatible LLM inference.
- `chatbot-service` owns orchestration, prompt assembly, request guardrails, and caller-facing chatbot behavior.
- `recommendation-service` owns recommendation truth, ranking, scoring, and recommendation business rules.

## Hard Boundaries

- Do not add ranking, scoring, filtering, survey, map, venue, price, user profiling, RAG retrieval, or business recommendation logic here.
- Do not connect this service to recommendation, survey, auth, map, chatbot, venue, or analytics databases.
- Do not add database access.
- Do not store raw user messages by default.
- Do not commit Hugging Face tokens, Google credentials, service-account keys, or model secrets.
- Keep the API OpenAI-compatible at `/v1/chat/completions`.

## Engineering Defaults

- Prefer small, production-focused changes.
- Prefer the serving runtime's native OpenAI-compatible server over custom wrappers.
- Keep the model replaceable by environment variable.
- Validate `/v1/chat/completions` behavior before deployment.
- Keep docs updated when environment variables, deployment commands, runtime choices, auth mode, model choices, or security defaults change.
- Keep Cloud Run private by default unless public access is explicitly requested.
