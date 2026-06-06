# Zero To Hero Plan

## Goal Objective

Create and deploy a production-ready starter repository for ONTHEBLOCK `llm-serving-service`, an OpenAI-compatible LLM inference service on GCP Cloud Run GPU.

## Non-Goals

- [ ] Do not build recommendation ranking.
- [ ] Do not build scoring, filtering, RAG retrieval, surveys, maps, venues, prices, auth, or profiling.
- [ ] Do not connect to any service database.
- [ ] Do not store raw user messages by default.
- [ ] Do not change chatbot-service except endpoint/auth configuration.

## Hard Boundaries

- [ ] `llm-serving-service` only serves `/v1/chat/completions`.
- [ ] `chatbot-service` owns authentication, orchestration, prompt grounding, and guardrails.
- [ ] `recommendation-service` owns recommendation truth.
- [ ] No secrets are committed.
- [ ] No full prompts, grounded context, user messages, or model responses are logged by default.

## Source-Of-Truth Services

- [ ] Recommendation truth: `recommendation-service`.
- [ ] Chatbot orchestration and guardrails: `chatbot-service`.
- [ ] LLM text generation only: `llm-serving-service`.

## Current Decisions

- [ ] Runtime: Hugging Face TGI.
- [ ] API: OpenAI-compatible `POST /v1/chat/completions`.
- [ ] Model: `Qwen/Qwen2.5-7B-Instruct`.
- [ ] Region: `asia-southeast1` because official Cloud Run L4 docs do not list `asia-northeast3`.
- [ ] GPU: one NVIDIA L4.
- [ ] CPU/memory: `8` CPU and `32Gi`.
- [ ] Auth: private Cloud Run by default.
- [ ] Scaling: `min-instances=0`, `max-instances=1`, `concurrency=1`.

## Required Official-Doc Verification

- [ ] Verify Cloud Run GPU L4 supported regions.
- [ ] Verify Cloud Run L4 CPU and memory requirements.
- [ ] Verify Cloud Run private service-to-service auth and `roles/run.invoker`.
- [ ] Verify Cloud Run rollback traffic command.
- [ ] Verify TGI `/v1/chat/completions` support.
- [ ] Verify TGI launcher env vars.
- [ ] Verify TGI private/gated model `HF_TOKEN` behavior.
- [ ] Verify pinned TGI image tag resolves.

## Phase Checklist

### Phase 1: Repository Skeleton

- [ ] Create required directories and files.
- [ ] Add `AGENTS.md` boundaries.
- [ ] Add `.gitignore` for secrets and model artifacts.
- [ ] Add `.env.example` with TGI-compatible variables.

Acceptance criteria:

- [ ] Required structure exists.
- [ ] No secret values are present.
- [ ] Boundaries are explicit.

### Phase 2: Runtime

- [ ] Add Dockerfile based on official TGI image.
- [ ] Pin a non-`latest` official image tag.
- [ ] Use TGI env vars instead of wrapper code.
- [ ] Confirm `/v1/chat/completions` is the primary endpoint.

Acceptance criteria:

- [ ] Dockerfile builds locally or failure is documented.
- [ ] No Python wrapper is added.
- [ ] Model can be changed with `MODEL_ID`.

### Phase 3: GCP Deployment

- [ ] Add Cloud Build staging config.
- [ ] Build and push to Artifact Registry.
- [ ] Deploy to Cloud Run with one L4 GPU.
- [ ] Use `asia-southeast1`.
- [ ] Use `--no-allow-unauthenticated` by default.
- [ ] Inject `HF_TOKEN` from Secret Manager only when needed.

Acceptance criteria:

- [ ] Config contains no secrets.
- [ ] GPU, CPU, memory, timeout, scaling, and auth defaults are explicit.
- [ ] Rollback command is documented.

### Phase 4: Integration

- [ ] Document chatbot-service env vars.
- [ ] Document private Cloud Run ID token/IAM requirement.
- [ ] Smoke test `/v1/chat/completions`.
- [ ] Confirm Korean grounded response generation.

Acceptance criteria:

- [ ] Smoke request succeeds.
- [ ] Response is Korean and concise.
- [ ] Response uses supplied facts only.

### Phase 5: Operations

- [ ] Document latency, cold starts, cost, scaling, timeout, and model loading.
- [ ] Document incident checklist.
- [ ] Document disable/delete steps for GPU cost control.

Acceptance criteria:

- [ ] On-call operator can identify auth, GPU quota, model load, and secret failures.
- [ ] Operator can roll back or scale to zero.

## Verification Commands

```bash
bash -n scripts/build_local.sh scripts/smoke_chat_completion.sh
git diff --check
docker manifest inspect ghcr.io/huggingface/text-generation-inference:sha-db931fc
scripts/build_local.sh
LLM_ENDPOINT_URL=http://localhost:8080/v1/chat/completions scripts/smoke_chat_completion.sh
```

For private Cloud Run:

```bash
gcloud run services proxy llm-serving-service-staging \
  --project=on-the-block-2026 \
  --region=asia-southeast1 \
  --port=18080

LLM_ENDPOINT_URL=http://127.0.0.1:18080/v1/chat/completions \
scripts/smoke_chat_completion.sh
```

## Rollback Path

- [ ] List revisions.
- [ ] Select last known-good revision.
- [ ] Route 100% traffic to it.
- [ ] Verify smoke test.

```bash
gcloud run revisions list \
  --service=llm-serving-service-staging \
  --region=asia-southeast1 \
  --project=on-the-block-2026

gcloud run services update-traffic llm-serving-service-staging \
  --region=asia-southeast1 \
  --project=on-the-block-2026 \
  --to-revisions=<revision-name>=100
```

## Cost Guardrails

- [ ] Keep `max-instances=1` for MVP.
- [ ] Keep `min-instances=0` outside demos and load tests.
- [ ] Keep GPU zonal redundancy off unless availability requirements change.
- [ ] Delete the staging service after temporary demos if no further tests are planned.
- [ ] Keep token limits conservative until measured.

## Human-Required Steps

- [ ] Confirm GCP project billing and APIs.
- [ ] Create Artifact Registry repository.
- [ ] Create or confirm runtime service account.
- [ ] Grant Cloud Build deploy permissions.
- [ ] Grant chatbot-service service account `roles/run.invoker`.
- [ ] Create `HF_TOKEN` Secret Manager secret only if the model needs it.
- [ ] Run Cloud Build deploy.
- [ ] Update chatbot-service endpoint configuration.

## Stop Conditions

- [ ] Official docs no longer list any acceptable Cloud Run L4 region.
- [ ] The pinned TGI image tag no longer resolves and no official replacement is selected.
- [ ] Required GCP quota is unavailable.
- [ ] Private model access requires a token that has not been created in Secret Manager.
- [ ] Chatbot-service cannot send Cloud Run IAM auth and public access is not approved.

## Definition Of Done

- [ ] Required repo structure exists.
- [ ] Official-doc-backed decisions are recorded.
- [ ] Dockerfile uses a pinned official TGI image.
- [ ] Cloud Build deploys private Cloud Run GPU staging in a supported L4 region.
- [ ] Smoke script can call `/v1/chat/completions`.
- [ ] Docs explain boundaries, security, operations, evaluation, rollback, and integration.
- [ ] No recommendation, ranking, scoring, filtering, RAG, survey, map, auth, or DB logic is implemented.
