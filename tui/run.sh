#!/usr/bin/env bash
#
# Build and run the homelab TUI in a Docker container.
#
# Usage:
#   ./run.sh              # Run the TUI
#   ./run.sh /bin/bash    # Get a shell in the container
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

docker build -t homelab-tui "${SCRIPT_DIR}"

# Mount the entire homelab project root at /homelab so the TUI can find
# Taskfile.yaml, terraform/, ansible/, etc.
# Use an anonymous volume for .venv so the container's virtual environment
# isn't overwritten by the bind mount.
# If no arguments passed, default to running the TUI entry point
if [ $# -eq 0 ]; then
    set -- homelab-tui
fi

docker run -it --rm \
    --volume "${PROJECT_ROOT}:/homelab" \
    --volume /homelab/tui/.venv \
    --volume "${HOME}/.config/sops/age/keys.txt:/root/.config/sops/age/keys.txt:ro" \
    --volume "${HOME}/.ssh:/root/.ssh:ro" \
    homelab-tui \
    "$@"
