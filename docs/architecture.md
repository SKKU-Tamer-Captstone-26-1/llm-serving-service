# Architecture

`llm-serving-service` is separate from `chatbot-service` because the two services have different runtime needs and ownership.

`chatbot-service` is CPU-oriented orchestration. It authenticates users, calls ONTHEBLOCK backend services, builds grounded prompt context, applies chatbot guardrails, and decides when to call the LLM. It should remain lightweight and cheap to scale.

`llm-serving-service` is GPU-oriented inference. It loads one open LLM and exposes an OpenAI-compatible `/v1/chat/completions` endpoint. It does not know how recommendations are chosen and does not query product databases.

## MSA Boundaries

- `recommendation-service` owns recommendation truth, ranking, scoring, filtering, and recommendation business rules.
- `chatbot-service` owns orchestration, prompt construction, grounding, guardrails, and client-facing chatbot behavior.
- `llm-serving-service` owns model serving only.

This split keeps expensive GPU resources isolated. The CPU chatbot layer can scale for request orchestration, while the GPU serving layer can use conservative concurrency, long cold-start settings, and model-specific capacity planning.

The LLM service does not own truth. Recommendation facts, venue facts, pricing, profile state, and guardrail decisions arrive from the upstream services through chatbot-service prompt context.

## Runtime Choice

The starter uses Hugging Face Text Generation Inference (TGI) because it already provides:

- Official Docker images.
- OpenAI-compatible `/v1/chat/completions`.
- NVIDIA GPU support.
- Runtime configuration through environment variables.
- Continuous batching and production-oriented inference controls.

The service contract intentionally stays OpenAI-compatible so the backend can later switch from TGI to vLLM without changing chatbot-service code.
