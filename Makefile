# Homelab Infrastructure Makefile
# ------------------------------

# Variables
ANSIBLE_DIR = ./ansible
TERRAFORM_DIR = ./terraform/environments/dev
KUBERNETES_DIR = ./kubernetes
DOCKER_DIR = ./docker-compose

# Default environment
ENV ?= dev

# Default terraform workspace
TF_WORKSPACE ?= default

# Default ansible inventory
ANSIBLE_INVENTORY ?= environments/$(ENV)/hosts.ini

# Default ansible verbosity
ANSIBLE_VERBOSITY ?= -v

# Default targets
.PHONY: all
all: help

# Help target
.PHONY: help
help:
	@echo "Homelab Infrastructure Management"
	@echo "--------------------------------"
	@echo "Available targets:"
	@echo "  help              - Show this help message"
	@echo "  init              - Initialize Terraform and install Ansible requirements"
	@echo "  plan              - Run Terraform plan"
	@echo "  apply             - Apply Terraform changes"
	@echo "  destroy           - Destroy Terraform-managed infrastructure"
	@echo "  k3s-install       - Install K3s cluster using Ansible"
	@echo "  k3s-reset         - Reset K3s cluster using Ansible"
	@echo "  k8s-apply-dev     - Apply Kubernetes manifests for dev environment"
	@echo "  k8s-apply-prod    - Apply Kubernetes manifests for prod environment"
	@echo "  docker-up-media   - Start media stack with Docker Compose"
	@echo "  docker-up-monitor - Start monitoring stack with Docker Compose"
	@echo "  packer-build      - Build Packer VM template"
	@echo ""
	@echo "Environment selection:"
	@echo "  make <target> ENV=dev  - Target dev environment (default)"
	@echo "  make <target> ENV=prod - Target prod environment"

# Terraform targets
.PHONY: init plan apply destroy

init:
	@echo "Initializing Terraform in $(TERRAFORM_DIR)"
	cd $(TERRAFORM_DIR) && terraform init

plan:
	@echo "Planning Terraform changes in $(TERRAFORM_DIR)"
	cd $(TERRAFORM_DIR) && terraform plan

apply:
	@echo "Applying Terraform changes in $(TERRAFORM_DIR)"
	cd $(TERRAFORM_DIR) && terraform apply

destroy:
	@echo "Destroying Terraform-managed infrastructure in $(TERRAFORM_DIR)"
	cd $(TERRAFORM_DIR) && terraform destroy

# Ansible targets
.PHONY: k3s-install k3s-reset

k3s-install:
	@echo "Installing K3s cluster using Ansible playbook"
	cd $(ANSIBLE_DIR) && ansible-playbook $(ANSIBLE_VERBOSITY) -i $(ANSIBLE_INVENTORY) site.yml

k3s-reset:
	@echo "Resetting K3s cluster using Ansible playbook"
	cd $(ANSIBLE_DIR) && ansible-playbook $(ANSIBLE_VERBOSITY) -i $(ANSIBLE_INVENTORY) reset.yml

# Kubernetes targets
.PHONY: k8s-apply-dev k8s-apply-prod

k8s-apply-dev:
	@echo "Applying Kubernetes manifests for dev environment"
	kubectl apply -k $(KUBERNETES_DIR)/cluster/dev

k8s-apply-prod:
	@echo "Applying Kubernetes manifests for prod environment"
	kubectl apply -k $(KUBERNETES_DIR)/cluster/prod

# Docker Compose targets
.PHONY: docker-up-media docker-up-monitor

docker-up-media:
	@echo "Starting media stack with Docker Compose"
	cd $(DOCKER_DIR)/media-stack && docker-compose up -d

docker-up-monitor:
	@echo "Starting monitoring stack with Docker Compose"
	cd $(DOCKER_DIR)/monitoring-stack && docker-compose up -d

# Packer target
.PHONY: packer-build

packer-build:
	@echo "Building Packer VM template"
	cd packer/ubuntu-server-noble && packer build ubuntu-server-noble-docker.pkr.hcl