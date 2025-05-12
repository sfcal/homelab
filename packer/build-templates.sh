#!/bin/bash
# Script to build all Packer templates for a specific environment

set -e

# Default environment
ENV="dev"
TEMPLATE="" # Default to empty, build all if not specified

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
      echo "  --env ENV         Environment to build for (dev or prod, default: dev)"
      echo "  --template TYPE   Specific template to build (base, docker, k8s). If omitted, builds all."
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

# Determine environment-specific variable files
ENV_VAR_FILE="environments/$ENV/variables.pkrvars.hcl"
CRED_VAR_FILE="environments/$ENV/credentials.${ENV}.pkrvars.hcl" # Path to credentials file inside env dir

# Check if the specific credentials file exists
if [[ ! -f "$CRED_VAR_FILE" ]]; then
  echo "Error: Credential file $CRED_VAR_FILE not found!"
  echo "Please ensure environments/$ENV/credentials.${ENV}.pkrvars.hcl exists."
  exit 1
fi

# Check if the environment variables file exists
if [[ ! -f "$ENV_VAR_FILE" ]]; then
  echo "Error: Environment variable file $ENV_VAR_FILE not found!"
  exit 1
fi


# Function to build a template
build_template() {
  local template_type=$1
  local template_file="templates/ubuntu-server-$template_type.pkr.hcl"

  # Check if template file exists before proceeding
  if [[ ! -f "$template_file" ]]; then
      echo "Template file $template_file not found, skipping..."
      return # Skip this iteration
  fi

  echo "===================================="
  echo "Building $template_type template for $ENV environment"
  echo "Using environment vars: $ENV_VAR_FILE"
  echo "Using credential vars:  $CRED_VAR_FILE"
  echo "===================================="

  # Initialize the plugins first
  echo "Initializing Packer plugins for $template_file..."
  packer init "$template_file"

  # Build the template
  # Inside the build_template function in build-templates.sh
# Inside the build_template function in build-templates.sh
echo "Building template $template_file..."
PACKER_LOG=1 packer build \
  -var-file="$CRED_VAR_FILE" \
  -var-file="$ENV_VAR_FILE" \
  "$template_file"

  echo "Finished building $template_type for $ENV."
  echo ""
}

# --- Main execution ---
echo "Starting Packer builds for $ENV environment"

# Build specific template or all
if [[ -n "$TEMPLATE" ]]; then
  build_template "$TEMPLATE"
else
  echo "No specific template requested, building all (base, docker, k8s)..."
  # Build all templates
  for t in base docker k8s; do
      build_template "$t"
  done
fi

echo "All requested Packer builds completed successfully!"

