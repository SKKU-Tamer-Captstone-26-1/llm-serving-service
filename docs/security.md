# Security

## Secrets

- Do not commit Hugging Face tokens, Google credentials, service-account keys, or model secrets.
- Use Secret Manager for `HF_TOKEN` only when the model is private, gated, or protected.
- Prefer pinned secret versions for Cloud Run environment variables.
- `.env` files are ignored by git; `.env.example` contains no secret values.

## Cloud Run Access

Cloud Run should be private by default. The staging deployment uses `--no-allow-unauthenticated`.

For private invocation:

- Grant chatbot-service runtime service account `roles/run.invoker` on this service.
- Have chatbot-service call with a Google ID token/IAM flow.
- Keep service-to-service auth in chatbot-service, not in this TGI container.

Public access should be an explicit deployment choice through `ALLOW_UNAUTHENTICATED=true` / `_ALLOW_UNAUTHENTICATED=true`.

## Prompt And Log Handling

- Do not log full prompts or raw user messages by default.
- Do not log full grounded context or model responses by default.
- Do not add prompt persistence unless there is a separate privacy review and retention policy.
- Keep incident logs focused on request metadata, status, latency, model id, revision, and error class.

## Data Boundary

This service must not connect to ONTHEBLOCK databases. It should not fetch recommendation, survey, map, venue, auth, price, or profile data. Those facts are supplied by chatbot-service after it calls the proper owners.
