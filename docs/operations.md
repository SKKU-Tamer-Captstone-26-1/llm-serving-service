# Operations

## Latency

Latency depends on model load time, prompt length, generation length, GPU availability, and batching. The staging defaults use `concurrency=1` to avoid unpredictable latency while the service is young.

Track:

- Cold-start duration.
- Time to first token for streaming callers.
- Full response latency for non-streaming calls.
- Input and output token counts.
- 4xx validation failures and 5xx runtime failures.

## Cold Start And Model Loading

Cloud Run can scale to zero, but the first request must wait for GPU allocation, container start, model download or cache warmup, and TGI model load. Qwen 7B can take long enough that startup probes and request timeouts need generous values.

Use `min-instances=0` when saving GPU cost matters more than first-request latency. Use `min-instances=1` when chatbot latency must stay predictable during demos, launches, or high-traffic windows.

## GPU Cost

Cloud Run GPU uses instance-based billing characteristics. Keep `max-instances` low until there is measured demand. For staging, `max-instances=1` prevents accidental fan-out.

Cost controls:

- Scale to zero outside active testing if cold starts are acceptable.
- Keep token limits conservative.
- Avoid unnecessary public traffic.
- Use private Cloud Run and IAM.
- Remove stale revisions if they are retaining confusing configs.

Disable the staging GPU service after demos by keeping it at scale-to-zero:

```bash
gcloud run services update llm-serving-service-staging \
  --project=on-the-block-2026 \
  --region=asia-southeast1 \
  --min-instances=0 \
  --max-instances=1
```

Delete it entirely if no further smoke tests are planned:

```bash
gcloud run services delete llm-serving-service-staging \
  --project=on-the-block-2026 \
  --region=asia-southeast1
```

## Timeout

The staging deploy uses `--timeout 900s`. This is intentionally conservative for model loading and long generation. Chatbot-service should still set its own shorter request deadline appropriate for user experience.

## Basic Incident Checklist

1. Confirm whether the service has a healthy ready revision.
2. Check Cloud Run logs for model download, CUDA, GPU quota, or secret access errors.
3. Confirm `MODEL_ID`, token limits, and `HF_TOKEN` secret reference.
4. Confirm Cloud Run GPU quota in the selected region.
5. Confirm chatbot-service has `roles/run.invoker` if the service is private.
6. Run `scripts/smoke_chat_completion.sh` with a minimal grounded Korean prompt.
7. Roll back to the last known good revision if the new revision fails to load.
