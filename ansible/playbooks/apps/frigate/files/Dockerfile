ARG FRIGATE_IMAGE

# Stage 1: Install dependencies and generate YOLO-NAS model
FROM ghcr.io/astral-sh/uv:python3.10-bookworm-slim AS model-builder

ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy

RUN apt-get update && apt-get install -y \
    build-essential cmake \
    libgl1-mesa-glx libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install dependencies (cached unless pyproject.toml changes)
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --no-install-project

# Copy source files and generate model
COPY pyproject.toml generate_model.py coco-80.txt ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync

# Patch defunct sghub.deci.ai URL to CloudFront CDN
RUN sed -i 's/sghub.deci.ai/d2gjn4b69gu75n.cloudfront.net/' \
    .venv/lib/python3.10/site-packages/super_gradients/training/pretrained_models.py \
    .venv/lib/python3.10/site-packages/super_gradients/training/utils/checkpoint_utils.py
RUN uv run python generate_model.py

# Stage 2: Frigate with YOLO model baked in
FROM ${FRIGATE_IMAGE}

COPY --from=model-builder /app/yolo_nas_s.onnx /models/yolo_nas_s.onnx
COPY --from=model-builder /app/coco-80.txt /models/coco-80.txt
