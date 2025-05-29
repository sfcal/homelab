# Makefile for Ansible Infrastructure Management
SHELL := /bin/bash
.DEFAULT_GOAL := help

# Variables
ENV ?= dev
ANSIBLE_PLAYBOOK := ansible-playbook -i environments/$(ENV)/hosts.ini
ANSIBLE_VAULT := ansible-vault

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

.PHONY: help
help: ## Show this help message
	@echo -e "$(GREEN)Ansible Infrastructure Management$(NC)"
	@echo -e "$(YELLOW)Usage:$(NC)"
	@echo -e "  make [target] ENV=[dev|prod]"
	@echo ""
	@echo -e "$(YELLOW)Available targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $1, $2}'
	@echo ""
	@echo -e "$(YELLOW)Examples:$(NC)"
	@echo -e "  make deploy-k3s ENV=dev     # Deploy K3s to dev environment"
	@echo -e "  make reset-k3s ENV=prod     # Reset K3s in prod environment"

# K3s targets
.PHONY: deploy-k3s
deploy-k3s: ## Deploy K3s cluster
	@echo -e "$(GREEN)Deploying K3s cluster in $(ENV) environment...$(NC)"
	$(ANSIBLE_PLAYBOOK) playbooks/k3s/deploy.yml

.PHONY: reset-k3s
reset-k3s: ## Reset K3s cluster
	@echo -e "$(RED)Resetting K3s cluster in $(ENV) environment...$(NC)"
	$(ANSIBLE_PLAYBOOK) playbooks/k3s/reset.yml

.PHONY: upgrade-k3s
upgrade-k3s: ## Upgrade K3s cluster
	@echo -e "$(YELLOW)Upgrading K3s cluster in $(ENV) environment...$(NC)"
	$(ANSIBLE_PLAYBOOK) playbooks/k3s/upgrade.yml

# DNS targets
.PHONY: deploy-dns
deploy-dns: ## Deploy DNS servers
	@echo -e "$(GREEN)Deploying DNS servers in $(ENV) environment...$(NC)"
	$(ANSIBLE_PLAYBOOK) playbooks/dns/deploy.yml

.PHONY: configure-dns
configure-dns: ## Configure DNS servers
	@echo -e "$(GREEN)Configuring DNS servers in $(ENV) environment...$(NC)"
	$(ANSIBLE_PLAYBOOK) playbooks/dns/configure.yml

.PHONY: update-dns
update-dns: ## Update DNS servers from repository
	@echo -e "$(YELLOW)Updating DNS servers in $(ENV) environment...$(NC)"
	$(ANSIBLE_PLAYBOOK) playbooks/dns/update.yml

.PHONY: update-dns-zones
update-dns-zones: ## Update DNS zone files
	@echo -e "$(YELLOW)Updating DNS zone files in $(ENV) environment...$(NC)"
	$(ANSIBLE_PLAYBOOK) playbooks/dns/update-zones.yml

.PHONY: restart-dns
restart-dns: ## Restart DNS containers
	@echo -e "$(YELLOW)Restarting DNS servers in $(ENV) environment...$(NC)"
	ansible -i environments/$(ENV)/hosts.ini dns_servers -b -m shell -a "cd ~/homelab/docker/bind9* && docker compose restart"

.PHONY: status-dns
status-dns: ## Check DNS server status
	@echo -e "$(YELLOW)Checking DNS server status in $(ENV) environment...$(NC)"
	ansible -i environments/$(ENV)/hosts.ini dns_servers -b -m shell -a "docker ps --filter 'name=nyc-dns' --format 'table {{.Names}}\t{{.Status}}'"

.PHONY: test-dns
test-dns: ## Test DNS resolution
	@echo -e "$(YELLOW)Testing DNS resolution in $(ENV) environment...$(NC)"
	@echo -e "$(GREEN)Testing local domain resolution:$(NC)"
	ansible -i environments/$(ENV)/hosts.ini dns_servers -m shell -a "dig @localhost home.samuel.computer +short"
	@echo -e "$(GREEN)Testing external domain resolution:$(NC)"
	ansible -i environments/$(ENV)/hosts.ini dns_servers -m shell -a "dig @localhost google.com +short"

# MaaS targets (future)
.PHONY: deploy-maas
deploy-maas: ## Deploy MaaS
	@echo -e "$(GREEN)Deploying MaaS in $(ENV) environment...$(NC)"
	$(ANSIBLE_PLAYBOOK) playbooks/maas/deploy.yml

# Proxmox targets
.PHONY: deploy-proxmox
deploy-proxmox: ## Install Proxmox VE
	@echo -e "$(GREEN)Installing Proxmox VE in $(ENV) environment...$(NC)"
	$(ANSIBLE_PLAYBOOK) playbooks/proxmox/install.yml

.PHONY: configure-proxmox
configure-proxmox: ## Configure Proxmox settings
	@echo -e "$(GREEN)Configuring Proxmox in $(ENV) environment...$(NC)"
	$(ANSIBLE_PLAYBOOK) playbooks/proxmox/configure.yml

.PHONY: join-proxmox-cluster
join-proxmox-cluster: ## Join nodes to Proxmox cluster
	@echo -e "$(GREEN)Joining nodes to Proxmox cluster in $(ENV) environment...$(NC)"
	$(ANSIBLE_PLAYBOOK) playbooks/proxmox/cluster.yml

.PHONY: status-proxmox
status-proxmox: ## Check Proxmox cluster status
	@echo -e "$(YELLOW)Checking Proxmox cluster status in $(ENV) environment...$(NC)"
	ansible -i environments/$(ENV)/hosts.ini proxmox_nodes -b -m shell -a "pvecm status"

# Utility targets
.PHONY: ping
ping: ## Ping all hosts in inventory
	@echo -e "$(YELLOW)Pinging all hosts in $(ENV) environment...$(NC)"
	ansible -i environments/$(ENV)/hosts.ini all -m ping

.PHONY: facts
facts: ## Gather facts from all hosts
	@echo -e "$(YELLOW)Gathering facts from $(ENV) environment...$(NC)"
	ansible -i environments/$(ENV)/hosts.ini all -m setup

.PHONY: lint
lint: ## Run ansible-lint on all playbooks
	@echo -e "$(YELLOW)Running ansible-lint...$(NC)"
	ansible-lint playbooks/

.PHONY: validate
validate: ## Validate inventory file
	@echo -e "$(YELLOW)Validating inventory for $(ENV) environment...$(NC)"
	ansible-inventory -i environments/$(ENV)/hosts.ini --list

# Clean targets
.PHONY: clean
clean: ## Clean temporary files
	@echo -e "$(YELLOW)Cleaning temporary files...$(NC)"
	find . -name "*.retry" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} +