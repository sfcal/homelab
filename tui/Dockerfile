# syntax=docker/dockerfile:1

# --- Base stage with system deps ---
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS base

# Install system dependencies needed at runtime
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        unzip \
        git \
        openssh-client \
        gnupg \
        software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install go-task CLI (the TUI shells out to `task` commands)
RUN sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

# Install Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com bookworm main" \
        > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends terraform && \
    rm -rf /var/lib/apt/lists/*

# Install Ansible (via uv/pip into a system-level tool, keeps it isolated)
RUN uv tool install ansible-core

# The TUI's find_project_root() walks up from __file__ looking for Taskfile.yaml,
# so the app must be nested under the homelab root at runtime.
WORKDIR /homelab/tui

# Create a minimal Taskfile.yaml at /homelab so the image works standalone
# (without bind mounts). When running with compose, the bind mount overlays this.
RUN echo 'version: "3"' > /homelab/Taskfile.yaml

# Enable bytecode compilation for faster startup
ENV UV_COMPILE_BYTECODE=1

# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy

# Install dependencies first (cached layer — only changes when lock/toml change)
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project

# Copy the project source
COPY . /homelab/tui

# Sync again to install the project itself (editable-like install)
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked

# Place venv and uv tool executables on PATH
ENV PATH="/homelab/tui/.venv/bin:/root/.local/bin:$PATH"

# Reset the entrypoint (the base image sets one for uv)
ENTRYPOINT []

# Default command runs the TUI
CMD ["homelab-tui"]
