# Decisions

This document records deployment and runtime decisions checked against official sources on June 6, 2026.

## Official Sources Checked

- Google Cloud Run GPU services: https://docs.cloud.google.com/run/docs/configuring/services/gpu
- Google Cloud Run locations: https://docs.cloud.google.com/run/docs/locations
- Google Cloud Run service-to-service authentication: https://docs.cloud.google.com/run/docs/authenticating/service-to-service
- Google Cloud Run rollback and traffic migration: https://docs.cloud.google.com/run/docs/rollouts-rollbacks-traffic-migration
- Google Cloud Run secrets: https://docs.cloud.google.com/run/docs/configuring/services/secrets
- Hugging Face TGI Quick Tour: https://huggingface.co/docs/text-generation-inference/main/quicktour
- Hugging Face TGI consuming API: https://huggingface.co/docs/text-generation-inference/main/basic_tutorials/consuming_tgi
- Hugging Face TGI launcher environment variables: https://huggingface.co/docs/text-generation-inference/main/reference/launcher
- Hugging Face TGI private and gated models: https://huggingface.co/docs/text-generation-inference/basic_tutorials/gated_model_access
- Hugging Face GHCR package page: https://github.com/huggingface/text-generation-inference/pkgs/container/text-generation-inference

## Runtime

Decision: use Hugging Face Text Generation Inference first.

Rationale:

- Official TGI docs describe TGI as a toolkit for serving LLMs and show the official Docker container path.
- Official TGI docs state that `/v1/chat/completions` is OpenAI Chat Completion compatible.
- TGI supports NVIDIA GPU serving and the service does not need a Python wrapper.
- The service contract remains OpenAI-compatible so a future switch to vLLM does not require chatbot-service endpoint changes.

Pinned image:

```text
ghcr.io/huggingface/text-generation-inference:sha-db931fc
```

The official TGI docs currently show `3.3.5` in examples. During local verification, `docker build` failed because `ghcr.io/huggingface/text-generation-inference:3.3.5` did not resolve from GHCR. The official Hugging Face GHCR package page showed `sha-db931fc`, and `docker manifest inspect ghcr.io/huggingface/text-generation-inference:sha-db931fc` succeeded for `linux/amd64`. This repo pins that resolvable official tag rather than using `latest`, and build commands explicitly request `linux/amd64` for Cloud Run.

A full local Docker build with the pinned image was started but stopped while pulling multi-GB TGI layers. That means the Dockerfile metadata path and pinned manifest were verified locally, but local container startup and GPU inference were not verified.

## Model

Decision: default `MODEL_ID=Qwen/Qwen2.5-7B-Instruct`.

The model is used as a Korean response writer over facts provided by chatbot-service. It is not a recommender and does not own truth.

## Environment Variables

Decision: use official TGI launcher environment variable names for runtime configuration:

- `MODEL_ID`
- `PORT`
- `REVISION`
- `NUM_SHARD`
- `MAX_INPUT_TOKENS`
- `MAX_TOTAL_TOKENS`
- `MAX_BATCH_PREFILL_TOKENS`
- `MAX_CONCURRENT_REQUESTS`
- `DTYPE`
- `QUANTIZE`
- `TRUST_REMOTE_CODE`
- `USAGE_STATS`
- `HF_TOKEN`

`ALLOW_UNAUTHENTICATED` is not a TGI variable. It is a deployment switch used by Cloud Build/gcloud only.

`HF_TOKEN` is only for private or gated Hugging Face models. It must come from Secret Manager for Cloud Run.

Cloud Run reserves `PORT` and injects it automatically. This repo keeps `PORT=8080` for local TGI and image defaults, but Cloud Run deploy commands must use `--port 8080` and must not include `PORT` in `--set-env-vars`.

## Region

Decision: use `asia-southeast1` for staging.

Rationale:

- ONTHEBLOCK asked not to assume `asia-northeast3`.
- Official Cloud Run GPU docs list L4 support in `asia-southeast1`, `asia-south1`, `europe-west1`, `europe-west4`, `us-central1`, and `us-east4`.
- Official Cloud Run GPU docs do not list `asia-northeast3` for L4.
- `asia-southeast1` is the nearest broadly available Asia-based Cloud Run L4 region in the official list.

Consequence: a Seoul-hosted chatbot-service may call the LLM service cross-region. This is acceptable for MVP staging and should be measured for latency.

## Cloud Run GPU Settings

Decision: MVP staging defaults:

- GPU: `1`
- GPU type: `nvidia-l4`
- CPU: `8`
- Memory: `32Gi`
- Concurrency: `1`
- Max instances: `1`
- Min instances: `0`
- Timeout: `900s`
- GPU zonal redundancy: off for lower cost
- Auth: private by default with `--no-allow-unauthenticated`

Rationale: official Cloud Run GPU docs require at least 4 CPU and 16 GiB for L4 and recommend 8 CPU and 32 GiB. MVP staging uses the recommendation while keeping max instances at 1 for cost control.

## Authentication

Decision: private Cloud Run by default.

`CHATBOT_LLM_AUTH_MODE=none` means no application-level LLM API key. It does not mean Cloud Run IAM is disabled. If this service is private, chatbot-service must:

- Run as a service account with `roles/run.invoker` on the LLM Cloud Run service.
- Send a Google-signed ID token with the Cloud Run service URL as audience.

Temporary public staging smoke tests may use `_ALLOW_UNAUTHENTICATED=true`, but that is an explicit exposure.

## Rollback

Decision: rollback by routing 100% traffic to the previous known-good Cloud Run revision.

Command:

```bash
gcloud run services update-traffic llm-serving-service-staging \
  --region=asia-southeast1 \
  --project=on-the-block-2026 \
  --to-revisions=<revision-name>=100
```

Cloud Run revision traffic is the rollback mechanism; no database rollback exists because this service owns no database.

## Staging Deployment Verification

Completed on June 6, 2026:

- Cloud Build build/push ID: `586db302-5004-47e5-8234-b1dc44ef88dc`
- Artifact Registry image: `asia-southeast1-docker.pkg.dev/on-the-block-2026/ontheblock-llm/llm-serving-service-staging:staging-manual-20260606-1`
- Image digest: `sha256:c4745f5e1d867630e982bc163a607b26d049a21bf79cd4130c739c53403c719e`
- Cloud Run service: `llm-serving-service-staging`
- Ready revision: `llm-serving-service-staging-00001-rkg`
- Service URL: `https://llm-serving-service-staging-vcuepibcwq-as.a.run.app`
- IAM policy: no `allUsers` binding; service remains private.
- Smoke test: `scripts/smoke_chat_completion.sh` passed through `gcloud run services proxy` and returned OpenAI-compatible JSON with Korean content.

The checked-in `deploy/gcp/cloudbuild.staging.yaml` was YAML-validated after removing `PORT` from deploy-time env vars. The first live deployment used direct `gcloud run deploy` after build/push to avoid granting additional broad project-level deploy IAM during setup.
