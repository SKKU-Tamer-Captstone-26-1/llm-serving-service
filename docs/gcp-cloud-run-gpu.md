# GCP Cloud Run GPU

This service targets Cloud Run services with one NVIDIA L4 GPU.

## Required GCP Resources

- Artifact Registry repository for Docker images.
- Cloud Build to build, push, and deploy.
- Cloud Run service with GPU enabled.
- Runtime service account for the Cloud Run service.
- Secret Manager only when `HF_TOKEN` is needed.

## Region

The staging examples use `asia-southeast1`. Official Cloud Run GPU docs list `asia-southeast1` for L4 and do not list `asia-northeast3`. The chatbot-service may call this service cross-region from Seoul-hosted infrastructure until Cloud Run L4 is available in Seoul or the system standardizes on another GPU region.

## Deployment Flow

1. Enable APIs:

```bash
gcloud services enable \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  secretmanager.googleapis.com \
  iam.googleapis.com \
  --project=on-the-block-2026
```

2. Create Artifact Registry:

```bash
gcloud artifacts repositories create ontheblock-llm \
  --repository-format=docker \
  --location=asia-southeast1 \
  --project=on-the-block-2026
```

3. Create or confirm the runtime service account:

```bash
gcloud iam service-accounts describe \
  llm-serving-staging@on-the-block-2026.iam.gserviceaccount.com \
  --project=on-the-block-2026
```

4. Grant deploy permissions to the Cloud Build identity:

- `roles/artifactregistry.writer` on the repository.
- `roles/run.admin` for Cloud Run deployment.
- `roles/iam.serviceAccountUser` on the runtime service account.

5. If using a private or gated Hugging Face model, create a Secret Manager secret for `HF_TOKEN` and grant `roles/secretmanager.secretAccessor` to the runtime service account.

6. Deploy:

```bash
gcloud builds submit \
  --project=on-the-block-2026 \
  --config=deploy/gcp/cloudbuild.staging.yaml \
  --substitutions=_REGION=asia-southeast1,_REPOSITORY=ontheblock-llm,_SERVICE_NAME=llm-serving-service-staging,_SERVICE_ACCOUNT=llm-serving-staging@on-the-block-2026.iam.gserviceaccount.com,_MODEL_ID=Qwen/Qwen2.5-7B-Instruct
```

## Cloud Run Settings

The staging deployment uses:

- `--gpu 1`
- `--gpu-type nvidia-l4`
- `--cpu 8`
- `--memory 32Gi`
- `--no-cpu-throttling`
- `--concurrency 1`
- `--timeout 900s`
- `--min-instances 0`
- `--max-instances 1`
- `--no-allow-unauthenticated`
- TCP startup probe on port `8080`

These defaults prefer predictable inference over throughput. Increase concurrency only after load testing the selected model and token limits.

## Rollback

List revisions:

```bash
gcloud run revisions list \
  --service=llm-serving-service-staging \
  --region=asia-southeast1 \
  --project=on-the-block-2026
```

Route traffic back to a known good revision:

```bash
gcloud run services update-traffic llm-serving-service-staging \
  --region=asia-southeast1 \
  --project=on-the-block-2026 \
  --to-revisions=<revision-name>=100
```

If model loading fails after a deploy, first roll back traffic, then inspect Cloud Run logs for model download, GPU allocation, token limit, or secret access failures.

## Cost Controls

- Keep `--min-instances 0` outside demos and load tests.
- Keep `--max-instances 1` for MVP staging.
- Keep `--no-gpu-zonal-redundancy` while cost is more important than multi-zone GPU capacity reservation.
- Delete or disable the staging service after temporary demos if the endpoint will not be used.
