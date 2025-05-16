# Default environment
ENV ?= dev

# Environment directory
ENV_DIR := environments/$(ENV)

.PHONY: deploy destroy clean

# Deploy infrastructure
deploy:
	@echo "Deploying infrastructure for $(ENV) environment..."
	cd $(ENV_DIR) && terraform init
	cd $(ENV_DIR) && terraform apply -auto-approve

# Destroy infrastructure
destroy:
	@echo "Destroying $(ENV) infrastructure..."
	cd $(ENV_DIR) && terraform init
	cd $(ENV_DIR) && terraform destroy -auto-approve

# Clean up Terraform files
clean:
	@echo "Cleaning Terraform files for $(ENV)..."
	rm -rf $(ENV_DIR)/.terraform
	rm -f $(ENV_DIR)/.terraform.lock.hcl
	rm -f $(ENV_DIR)/terraform.tfstate*