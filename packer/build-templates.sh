#!/bin/bash
# Script to build all Packer templates for a specific environment

set -e

# Default environment
ENV="dev"
TEMPLATE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --env)
      ENV="$2"
      shift 2
      ;;
    --template)
      TEMPLATE="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [--env dev|prod] [--template base|docker|k8s]"
      echo ""
      echo "Options:"
      echo "  --env ENV        Environment to build for (dev or prod, default: dev)"
      echo "  --template TYPE  Specific template to build (base, docker, k8s)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Verify environment
if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
  echo "Invalid environment: $ENV. Must be 'dev' or 'prod'."
  exit 1
fi

# Check if credentials file exists
if [[ ! -f "credentials.pkrvars.hcl" ]]; then
  echo "Error: credentials.pkrvars.hcl not found!"
  echo "Please copy credentials.pkrvars.hcl.example to credentials.pkrvars.hcl and fill in your credentials."
  exit 1
fi

# Set environment variables file
ENV_VAR_FILE="environments/$ENV/variables.pkrvars.hcl"

# Function to build a template
build_template() {
  local template_type=$1
  local template_file="templates/ubuntu-server-$template_type.pkr.hcl"
  
  echo "===================================="
  echo "Building $template_type template for $ENV environment"
  echo "===================================="
  
  # Initialize the plugins first
  echo "Initializing Packer plugins..."
  packer init "$template_file"
  
  # Build the template
  echo "Building template..."
  PACKER_LOG=1 packer build \
    -var-file="credentials.pkrvars.hcl" \
    -var-file="$ENV_VAR_FILE" \
    -var "environment=$ENV" \
    -var "template_prefix=ubuntu-server" \
    "$template_file"
}

# Main execution
echo "Building templates for $ENV environment"

# Build specific template or all
if [[ -n "$TEMPLATE" ]]; then
  build_template "$TEMPLATE"
else
  # Build all templates
  for t in base docker k8s; do
    if [[ -f "templates/ubuntu-server-$t.pkr.hcl" ]]; then
      build_template "$t"
    else
      echo "Template file for $t not found, skipping..."
    fi
  done
fi

echo "All templates built successfully!"