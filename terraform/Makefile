# Default environment
ENV ?= dev

# Environment directory
ENV_DIR := environments/$(ENV)

# SOPS files
SOPS_TFVARS := $(ENV_DIR)/terraform.tfvars.sops
DECRYPTED_TFVARS := $(ENV_DIR)/terraform.tfvars

.PHONY: deploy destroy clean decrypt

# Decrypt SOPS files
decrypt:
	@echo "Checking for encrypted tfvars..."
	@if [ -f "$(SOPS_TFVARS)" ]; then \
		echo "Decrypting $(SOPS_TFVARS)..."; \
		sops -d $(SOPS_TFVARS) > $(DECRYPTED_TFVARS); \
		echo "✓ Decrypted to $(DECRYPTED_TFVARS)"; \
	else \
		echo "No encrypted tfvars found at $(SOPS_TFVARS)"; \
	fi

# Deploy infrastructure
deploy: decrypt
	@echo "Deploying infrastructure for $(ENV) environment..."
	cd $(ENV_DIR) && terraform init
	cd $(ENV_DIR) && terraform apply -auto-approve
	@# Clean up decrypted file after deployment
	@rm -f $(DECRYPTED_TFVARS)

# Destroy infrastructure
destroy: decrypt
	@echo "Destroying $(ENV) infrastructure..."
	cd $(ENV_DIR) && terraform init
	cd $(ENV_DIR) && terraform destroy -auto-approve
	@# Clean up decrypted file after destroy
	@rm -f $(DECRYPTED_TFVARS)

# Clean up Terraform files
clean:
	@echo "Cleaning Terraform files for $(ENV)..."
	rm -rf $(ENV_DIR)/.terraform
	rm -f $(ENV_DIR)/.terraform.lock.hcl
	rm -f $(ENV_DIR)/terraform.tfstate*
	rm -f $(DECRYPTED_TFVARS)