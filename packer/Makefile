# Default environment
ENV ?= dev

# Default template
TEMPLATE ?= base

.PHONY: build all clean

# Build a specific template
build:
	@echo "Building $(TEMPLATE) template for $(ENV) environment..."
	./build-templates.sh --env $(ENV) --template $(TEMPLATE)

# Build all templates
all:
	@echo "Building all templates for $(ENV) environment..."
	./build-templates.sh --env $(ENV)

# Clean up
clean:
	@echo "Cleaning up Packer artifacts..."
	rm -f packer.log
	rm -rf downloaded_iso_path