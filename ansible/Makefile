# ========================================
# Homelab Infrastructure Makefile
# ========================================
# Enhanced Makefile for managing homelab infrastructure
# with Ansible in a well-structured project

# Default configuration
ENV ?= dev                  # Default environment (dev, prod)
VERBOSITY ?= 0              # Ansible verbosity level (0-4)
LIMIT ?=                    # Optional host limit
TAGS ?=                     # Optional tags to filter tasks
EXTRA_ARGS ?=               # Additional ansible-playbook arguments

# Directory structure
ANSIBLE_DIR := .
INVENTORIES_DIR := $(ANSIBLE_DIR)/inventories
PLAYBOOKS_DIR := $(ANSIBLE_DIR)/playbooks
ENV_DIR := $(INVENTORIES_DIR)/$(ENV)
INVENTORY := $(ENV_DIR)/hosts.yml

# Ansible command construction
ANSIBLE_CONFIG := $(ANSIBLE_DIR)/ansible.cfg
ANSIBLE_CMD := ANSIBLE_CONFIG=$(ANSIBLE_CONFIG) ansible-playbook
ANSIBLE_ARGS := -i $(INVENTORY) $(if $(filter-out 0,$(VERBOSITY)),-v$(VERBOSITY),) $(if $(LIMIT),--limit=$(LIMIT),) $(if $(TAGS),--tags=$(TAGS),) $(EXTRA_ARGS)

# Playbook paths
K3S_PLAYBOOK := $(PLAYBOOKS_DIR)/k3s.yml
DNS_PLAYBOOK := $(PLAYBOOKS_DIR)/dns.yml
PROXMOX_PLAYBOOK := $(PLAYBOOKS_DIR)/proxmox.yml
NTP_PLAYBOOK := $(PLAYBOOKS_DIR)/ntp.yml
MAAS_PLAYBOOK := $(PLAYBOOKS_DIR)/maas.yml
INFRA_PLAYBOOK := $(PLAYBOOKS_DIR)/infrastructure.yml

# Declare all phony targets
.PHONY: help deploy deploy-server deploy-agent reset clean kubeconfig \
        deploy-dns deploy-proxmox deploy-ntp deploy-maas deploy-all \
        lint check debug provision-all inventory-graph

# ========================================
# Help target - shows available commands
# ========================================
help:
	@echo "Homelab Infrastructure Management"
	@echo "----------------------------------"
	@echo "Available commands:"
	@echo ""
	@echo "Infrastructure Deployment:"
	@echo "  deploy-all        Deploy all infrastructure components"
	@echo "  provision-all     Provision all infrastructure (includes VM creation)"
	@echo ""
	@echo "K3s Kubernetes Management:"
	@echo "  deploy            Deploy K3s cluster to $(ENV) environment"
	@echo "  deploy-server     Deploy only K3s server components"
	@echo "  deploy-agent      Deploy only K3s agent components"
	@echo "  reset             Reset the K3s cluster"
	@echo "  kubeconfig        Show kubeconfig information"
	@echo ""
	@echo "Component Deployment:"
	@echo "  deploy-dns        Deploy DNS servers"
	@echo "  deploy-proxmox    Deploy Proxmox virtualization"
	@echo "  deploy-ntp        Deploy NTP services"
	@echo "  deploy-maas       Deploy Metal as a Service"
	@echo ""
	@echo "Maintenance and Debugging:"
	@echo "  clean             Clean temporary files"
	@echo "  lint              Lint Ansible playbooks and roles"
	@echo "  check             Perform a dry run (--check mode)"
	@echo "  debug             Run in debug mode (increased verbosity)"
	@echo "  inventory-graph   Generate inventory visualization"
	@echo ""
	@echo "Parameters:"
	@echo "  ENV=dev|prod      Target environment (default: dev)"
	@echo "  VERBOSITY=0-4     Set verbosity level (default: 0)"
	@echo "  LIMIT=host        Limit execution to specific hosts"
	@echo "  TAGS=tag1,tag2    Only run tasks with specified tags"
	@echo "  EXTRA_ARGS=args   Additional ansible-playbook arguments"
	@echo ""
	@echo "Examples:"
	@echo "  make deploy ENV=prod"
	@echo "  make deploy-dns LIMIT=10.1.0.53"
	@echo "  make deploy TAGS=download,server"
	@echo "  make debug ENV=dev LIMIT=master"

# ========================================
# K3s Cluster Management
# ========================================

# Deploy full K3s infrastructure
deploy:
	@echo "Deploying K3s to $(ENV) environment..."
	@$(ANSIBLE_CMD) $(ANSIBLE_ARGS) $(K3S_PLAYBOOK)

# Deploy only K3s server components
deploy-server:
	@echo "Deploying K3s server components to $(ENV) environment..."
	@$(ANSIBLE_CMD) $(ANSIBLE_ARGS) --limit=master $(K3S_PLAYBOOK)

# Deploy only K3s agent components
deploy-agent:
	@echo "Deploying K3s agent components to $(ENV) environment..."
	@$(ANSIBLE_CMD) $(ANSIBLE_ARGS) --limit=node $(K3S_PLAYBOOK)

# Reset K3s infrastructure
reset:
	@echo "Resetting $(ENV) K3s infrastructure..."
	@$(ANSIBLE_CMD) $(ANSIBLE_ARGS) --tags=reset $(K3S_PLAYBOOK)

# Clean up temporary files
clean:
	@echo "Cleaning up temporary files..."
	@rm -f $(ANSIBLE_DIR)/kubeconfig

# Show kubeconfig information
kubeconfig:
	@if [ -f $(ANSIBLE_DIR)/kubeconfig ]; then \
		echo "Kubeconfig is available at: $(shell pwd)/$(ANSIBLE_DIR)/kubeconfig"; \
		echo ""; \
		echo "To use with kubectl, run:"; \
		echo "export KUBECONFIG=$(shell pwd)/$(ANSIBLE_DIR)/kubeconfig"; \
	else \
		echo "Kubeconfig not found. Deploy a cluster first."; \
	fi

# ========================================
# Component Deployment
# ========================================

# Deploy DNS infrastructure
deploy-dns:
	@echo "Deploying DNS servers to $(ENV) environment..."
	@$(ANSIBLE_CMD) $(ANSIBLE_ARGS) $(DNS_PLAYBOOK)

# Deploy Proxmox infrastructure
deploy-proxmox:
	@echo "Deploying Proxmox to $(ENV) environment..."
	@$(ANSIBLE_CMD) $(ANSIBLE_ARGS) $(PROXMOX_PLAYBOOK)

# Deploy NTP infrastructure
deploy-ntp:
	@echo "Deploying NTP to $(ENV) environment..."
	@$(ANSIBLE_CMD) $(ANSIBLE_ARGS) $(NTP_PLAYBOOK)

# Deploy MaaS infrastructure
deploy-maas:
	@echo "Deploying MaaS to $(ENV) environment..."
	@$(ANSIBLE_CMD) $(ANSIBLE_ARGS) $(MAAS_PLAYBOOK)

# Deploy all infrastructure
deploy-all:
	@echo "Deploying all infrastructure to $(ENV) environment..."
	@$(ANSIBLE_CMD) $(ANSIBLE_ARGS) $(INFRA_PLAYBOOK)

# Provision all infrastructure including VM creation
provision-all:
	@echo "Provisioning all infrastructure (including VM creation) in $(ENV) environment..."
	@$(ANSIBLE_CMD) $(ANSIBLE_ARGS) --tags=provision $(INFRA_PLAYBOOK)

# ========================================
# Maintenance and Debugging
# ========================================

# Lint playbooks and roles
lint:
	@echo "Linting playbooks and roles..."
	@ansible-lint $(PLAYBOOKS_DIR)/*.yml

# Check mode (dry run)
check:
	@echo "Performing check (dry run) on $(ENV) environment..."
	@$(ANSIBLE_CMD) $(ANSIBLE_ARGS) --check $(INFRA_PLAYBOOK)

# Debug mode with increased verbosity
debug:
	@echo "Running in debug mode on $(ENV) environment..."
	@$(MAKE) deploy-all VERBOSITY=3 EXTRA_ARGS="--diff"

# Generate inventory visualization
inventory-graph:
	@echo "Generating inventory visualization for $(ENV) environment..."
	@ansible-inventory -i $(INVENTORY) --graph