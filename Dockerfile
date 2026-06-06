# syntax=docker/dockerfile:1

ARG TGI_IMAGE=ghcr.io/huggingface/text-generation-inference:sha-db931fc
FROM ${TGI_IMAGE}

# TGI reads these official launcher environment variables directly.
ENV MODEL_ID=Qwen/Qwen2.5-7B-Instruct \
    HOSTNAME=0.0.0.0 \
    PORT=8080 \
    NUM_SHARD=1 \
    MAX_INPUT_TOKENS=2048 \
    MAX_TOTAL_TOKENS=3072 \
    MAX_BATCH_PREFILL_TOKENS=4096 \
    MAX_CONCURRENT_REQUESTS=4 \
    DTYPE=float16 \
    TRUST_REMOTE_CODE=false \
    USAGE_STATS=off

EXPOSE 8080
