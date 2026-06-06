# GCP Deployment

This directory contains the staging deployment path for Cloud Run GPU.

## Defaults

- Project: `on-the-block-2026`
- Region: `asia-southeast1`
- Artifact Registry repository: `ontheblock-llm`
- Cloud Run service: `llm-serving-service-staging`
- Runtime service account: `llm-serving-staging@on-the-block-2026.iam.gserviceaccount.com`
- GPU: one NVIDIA L4
- Public access: disabled by default

Google Cloud Run GPU availability is region-limited. Official Cloud Run GPU docs list `asia-southeast1` for L4 and do not list `asia-northeast3`, so staging uses Singapore. Seoul-hosted services can call this endpoint cross-region.

## One-Time Setup

Enable APIs:

```bash
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  secretmanager.googleapis.com \
  iam.googleapis.com \
  --project=on-the-block-2026
```

Create Artifact Registry:

```bash
gcloud artifacts repositories create ontheblock-llm \
  --project=on-the-block-2026 \
  --repository-format=docker \
  --location=asia-southeast1 \
  --description="ONTHEBLOCK LLM serving images"
```

Create the Cloud Run runtime service account:

```bash
gcloud iam service-accounts create llm-serving-staging \
  --project=on-the-block-2026 \
  --display-name="LLM serving staging"
```

Grant the deploying Cloud Build identity permission to deploy Cloud Run, push Artifact Registry images, and act as the runtime service account. Use the actual Cloud Build service account for the project.

## Optional Hugging Face Secret

`Qwen/Qwen2.5-7B-Instruct` is public at the time this starter was created. Add `HF_TOKEN` only for private or gated models.

```bash
printf '%s' "$HF_TOKEN" | gcloud secrets create hf-token \
  --project=on-the-block-2026 \
  --data-file=-

gcloud secrets add-iam-policy-binding hf-token \
  --project=on-the-block-2026 \
  --member="serviceAccount:llm-serving-staging@on-the-block-2026.iam.gserviceaccount.com" \
  --role=roles/secretmanager.secretAccessor
```

Use a pinned version during deploy, for example `_HF_TOKEN_SECRET_VERSION=hf-token:1`.

## Deploy

```bash
gcloud builds submit \
  --project=on-the-block-2026 \
  --config=deploy/gcp/cloudbuild.staging.yaml \
  --substitutions=_REGION=asia-southeast1,_REPOSITORY=ontheblock-llm,_SERVICE_NAME=llm-serving-service-staging,_SERVICE_ACCOUNT=llm-serving-staging@on-the-block-2026.iam.gserviceaccount.com,_MODEL_ID=Qwen/Qwen2.5-7B-Instruct
```

To inject `HF_TOKEN` from Secret Manager:

```bash
gcloud builds submit \
  --project=on-the-block-2026 \
  --config=deploy/gcp/cloudbuild.staging.yaml \
  --substitutions=_HF_TOKEN_SECRET_VERSION=hf-token:1
```

## Private Invocation

Grant the chatbot-service runtime service account invoker access:

```bash
gcloud run services add-iam-policy-binding llm-serving-service-staging \
  --project=on-the-block-2026 \
  --region=asia-southeast1 \
  --member="serviceAccount:<chatbot-service-runtime-sa>" \
  --role=roles/run.invoker
```

The chatbot-service should call the Cloud Run URL with a Google ID token when the service remains private.

If the chatbot-service environment is intentionally kept at `CHATBOT_LLM_AUTH_MODE=none`, deploy with `_ALLOW_UNAUTHENTICATED=true` for that environment and treat the public endpoint as a temporary or explicitly accepted exposure.

## Rollback

List revisions:

```bash
gcloud run revisions list \
  --service=llm-serving-service-staging \
  --region=asia-southeast1 \
  --project=on-the-block-2026
```

Send all traffic to the previous known-good revision:

```bash
gcloud run services update-traffic llm-serving-service-staging \
  --region=asia-southeast1 \
  --project=on-the-block-2026 \
  --to-revisions=<revision-name>=100
```
