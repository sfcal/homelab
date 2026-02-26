# syntax=docker/dockerfile:1

# --- Build stage: install Python deps via uv ---
FROM python:3.12-slim-bookworm AS build

COPY --from=ghcr.io/astral-sh/uv:0.6.6 /uv /uvx /bin/

WORKDIR /homelab/tui

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

# Install dependencies first (cached layer — only changes when lock/toml change)
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev

# Copy the project source and install the project itself
COPY . /homelab/tui

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev --no-editable

# --- Runtime stage: slim image with app + IaC tools ---
FROM python:3.12-slim-bookworm

# System deps needed at runtime (for go-task, terraform, ansible, git-based ops)
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
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | \
        gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com bookworm main" \
        > /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends terraform && \
    rm -rf /var/lib/apt/lists/*

# Install SOPS (for decrypting Ansible vault secrets)
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSLo /usr/local/bin/sops \
        "https://github.com/getsops/sops/releases/download/v3.9.4/sops-v3.9.4.linux.${ARCH}" && \
    chmod +x /usr/local/bin/sops

# Install Ansible (via uv tool — keeps it isolated from the app venv)
COPY --from=ghcr.io/astral-sh/uv:0.6.6 /uv /uvx /bin/
ENV UV_TOOL_BIN_DIR=/usr/local/bin
RUN uv tool install ansible-core --with docker && \
    ansible-galaxy collection install community.docker community.sops

# Copy the pre-built venv from the build stage
COPY --from=build /homelab/tui/.venv /homelab/tui/.venv

# The TUI's find_project_root() walks up from __file__ looking for Taskfile.yaml,
# so the app must be nested under the homelab root at runtime.
WORKDIR /homelab/tui

# Create a minimal Taskfile.yaml at /homelab so the image works standalone
# (without bind mounts). When running with compose, the bind mount overlays this.
RUN echo 'version: "3"' > /homelab/Taskfile.yaml

# Place venv and uv tool executables on PATH
ENV PATH="/homelab/tui/.venv/bin:$PATH"

# Textual needs truecolor support for correct rendering
ENV TERM=xterm-256color
ENV COLORTERM=truecolor

# Reset the entrypoint (the uv base image sets one for uv)
ENTRYPOINT []

# Default command runs the TUI
CMD ["homelab-tui"]
