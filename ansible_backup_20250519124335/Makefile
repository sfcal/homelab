# Default environment
ENV ?= dev

# Ansible directories and files
ANSIBLE_DIR := .
PLAYBOOKS_DIR := $(ANSIBLE_DIR)/playbooks/k3s
ENV_DIR := $(ANSIBLE_DIR)/environments/$(ENV)
ANSIBLE_CMD := ANSIBLE_ROLES_PATH=$(ANSIBLE_DIR)/roles/k3s ansible-playbook

# Playbooks
DEPLOY_PLAYBOOK := $(PLAYBOOKS_DIR)/deploy.yml
RESET_PLAYBOOK := $(PLAYBOOKS_DIR)/reset.yml

DNS_PLAYBOOK := $(ANSIBLE_DIR)/playbooks/dns/deploy.yml

PROXMOX_PLAYBOOK := $(ANSIBLE_DIR)/playbooks/proxmox/deploy.yml
#PROXMOX_PLAYBOOK := $(ANSIBLE_DIR)/playbooks/proxmox/reset.yml

NTP_PLAYBOOK := $(ANSIBLE_DIR)/playbooks/ntp/deploy.yml

MAAS_PLAYBOOK := $(ANSIBLE_DIR)/playbooks/maas/deploy.yml

.PHONY: deploy reset clean kubeconfig

# Deploy k3s infrastructure
deploy:
	@echo "Deploying k3s to $(ENV) environment..."
	$(ANSIBLE_CMD) -i $(ENV_DIR)/hosts.ini $(DEPLOY_PLAYBOOK)

# Reset k3s infrastructure
reset:
	@echo "Resetting $(ENV) k3s infrastructure..."
	$(ANSIBLE_CMD) -i $(ENV_DIR)/hosts.ini $(RESET_PLAYBOOK)

# Clean up temporary files
clean:
	@echo "Cleaning up temporary files..."
	rm -f $(ANSIBLE_DIR)/kubeconfig

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


# Deploy DNS infrastructure
deploy-dns:
	@echo "Deploying DNS servers to $(ENV) environment..."
	$(ANSIBLE_CMD) -i $(ENV_DIR)/hosts.ini $(DNS_PLAYBOOK)

# Deploy Proxmox infrastructure
deploy-proxmox:
	@echo "Deploying Proxmox to $(ENV) environment..."
	$(ANSIBLE_CMD) -i $(ENV_DIR)/hosts.ini $(PROXMOX_PLAYBOOK)

# Deploy NTP infrastructure
deploy-proxmox:
	@echo "Deploying Proxmox to $(ENV) environment..."
	$(ANSIBLE_CMD) -i $(ENV_DIR)/hosts.ini $(PTP_PLAYBOOK)

deploy-maas:
	@echo "Deploying MaaS to $(ENV) environment..."
	$(ANSIBLE_CMD) -i $(ENV_DIR)/hosts.ini $(MAAS_PLAYBOOK)
