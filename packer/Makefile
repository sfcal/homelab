# Default environment
ENV ?= dev

# Default template
TEMPLATE ?= base

# Available templates
TEMPLATES = base docker k8s

# Paths
ENV_VAR_FILE = environments/$(ENV)/variables.pkrvars.hcl
CRED_VAR_FILE = environments/$(ENV)/credentials.$(ENV).pkrvars.hcl

.PHONY: build all clean

# Build a specific template
build:
	@template_file="templates/ubuntu-server-$(TEMPLATE).pkr.hcl"; \
	echo "===================================="; \
	echo "Building $(TEMPLATE) template for $(ENV) environment"; \
	echo "Using environment vars: $(ENV_VAR_FILE)"; \
	echo "Using credential vars: $(CRED_VAR_FILE)"; \
	echo "===================================="; \
	echo "Initializing Packer plugins for $$template_file..."; \
	packer init "$$template_file"; \
	echo "Building template $$template_file..."; \
	PACKER_LOG=1 packer build \
		-var-file="$(CRED_VAR_FILE)" \
		-var-file="$(ENV_VAR_FILE)" \
		"$$template_file"; \
	echo "Finished building $(TEMPLATE) template for $(ENV) environment."

# Clean up
clean:
	@echo "Cleaning up Packer artifacts..."
	rm -f packer.log
	rm -rf downloaded_iso_path