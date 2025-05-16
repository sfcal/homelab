# Default environment
ENV ?= dev

# Ansible directories and files
ANSIBLE_DIR := ansible
PLAYBOOKS_DIR := $(ANSIBLE_DIR)/playbooks/k3s
ENV_DIR := $(ANSIBLE_DIR)/environments/$(ENV)
ANSIBLE_CMD := ansible-playbook

# Playbooks
DEPLOY_PLAYBOOK := $(PLAYBOOKS_DIR)/deploy.yml
RESET_PLAYBOOK := $(PLAYBOOKS_DIR)/reset.yml

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