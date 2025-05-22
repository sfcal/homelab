# Start from your existing homelab image
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    KUBECONFIG="/home/devops/.kube/config" \
    ENV="dev"

# Install common utilities and prerequisites
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    git \
    unzip \
    wget \
    ssh \
    make \
    jq \
    vim \
    python3 \
    python3-pip \
    python3-venv \
    rsync \
    # Dotfiles required dependencies
    zsh \
    stow \
    fzf \
    ripgrep \
    highlight \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install HashiCorp repository and tools (Terraform and Packer)
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update \
    && apt-get install -y terraform packer \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Ansible and required collections
RUN pip3 install --no-cache-dir ansible ansible-core netaddr \
    && ansible-galaxy collection install community.general ansible.posix

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# Install Helm
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
    && chmod 700 get_helm.sh \
    && ./get_helm.sh \
    && rm get_helm.sh

# Install FluxCD CLI
RUN curl -s https://fluxcd.io/install.sh | bash

# Create a non-root user for running commands
RUN useradd -m -s /bin/bash devops \
    && mkdir -p /home/devops/.ssh /home/devops/.kube \
    && chown -R devops:devops /home/devops/.ssh /home/devops/.kube \
    && chmod 700 /home/devops/.ssh /home/devops/.kube

# Create Ansible configuration directory
RUN mkdir -p /etc/ansible \
    && echo "[defaults]\ninterpreter_python = /usr/bin/python3\nhost_key_checking = False\nroles_path = /workspace/ansible/roles" > /etc/ansible/ansible.cfg \
    && chown -R devops:devops /etc/ansible

# Set up workspace and dotfiles directories
RUN mkdir -p /workspace /home/devops/.home \
    && chown -R devops:devops /workspace /home/devops/.home

# Set working directory
WORKDIR /workspace

# Add volumes for ssh keys, kube config, workspace, and dotfiles
VOLUME ["/home/devops/.ssh", "/home/devops/.kube", "/workspace", "/home/devops/.home", "/home/devops/.gitconfig"]

# Create a non-interactive entrypoint script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Setup dotfiles silently if available\n\
if [ -d "/home/devops/.home" ] && [ "$(ls -A /home/devops/.home 2>/dev/null)" ]; then\n\
  cd /home/devops/.home\n\
  su - devops -c "cd ~/.home && make >/dev/null 2>&1" || true\n\
  chsh -s /usr/bin/zsh devops >/dev/null 2>&1 || true\n\
fi\n\
\n\
# If no command provided, show help\n\
if [ "$#" -eq 0 ]; then\n\
  echo "🏠 Homelab Infrastructure Container"\n\
  echo "Usage: docker run --rm homelab-exe <command>"\n\
  echo ""\n\
  echo "Available tools:"\n\
  echo "  - terraform"\n\
  echo "  - ansible"\n\
  echo "  - kubectl"\n\
  echo "  - helm"\n\
  echo "  - flux"\n\
  echo "  - packer"\n\
  echo ""\n\
  echo "Example: docker run --rm homelab-exe terraform version"\n\
  exit 1\n\
fi\n\
\n\
# Execute command as devops user\n\
exec su - devops -c "cd /workspace && $*"\n\
' > /entrypoint.sh \
&& chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]