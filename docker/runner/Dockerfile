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
RUN pip3 install --no-cache-dir ansible ansible-core \
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

# Set up workspace directory
RUN mkdir -p /workspace \
    && chown -R devops:devops /workspace

# Create helpful aliases and environment setup
RUN echo 'export PS1="🏠 homelab:\w \$ "' >> /home/devops/.bashrc \
    && echo 'alias tf="terraform"' >> /home/devops/.bashrc \
    && echo 'alias k="kubectl"' >> /home/devops/.bashrc \
    && echo 'alias a="ansible"' >> /home/devops/.bashrc \
    && echo 'alias ap="ansible-playbook"' >> /home/devops/.bashrc \
    && echo 'export KUBECONFIG=/home/devops/.kube/config' >> /home/devops/.bashrc \
    && chown devops:devops /home/devops/.bashrc

# Set working directory
WORKDIR /workspace

# Add volumes for ssh keys, kube config, and workspace
VOLUME ["/home/devops/.ssh", "/home/devops/.kube", "/workspace"]

# Switch to non-root user
USER devops

# Create an informative entrypoint script
USER root
RUN echo '#!/bin/bash\n\
echo "🏠 Homelab Infrastructure Container"\n\
echo "------------------------"\n\
echo "Terraform: $(terraform version | head -n1)"\n\
echo "Packer: $(packer version)"\n\
echo "Ansible: $(ansible --version | head -n1)"\n\
echo "Kubectl: $(kubectl version --client | grep -o "Client Version: [^,]*")"\n\
echo "Flux: $(flux --version)"\n\
echo "------------------------"\n\
echo "Environment: ${ENV}"\n\
echo "------------------------"\n\
exec "$@"' > /entrypoint.sh \
&& chmod +x /entrypoint.sh
USER devops

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]