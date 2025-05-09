#!/bin/bash
# Script to initialize all Packer plugins

set -e

echo "Initializing Packer plugins for all templates..."

# Find all template files
for template_file in templates/*.pkr.hcl; do
  if [ -f "$template_file" ]; then
    echo "Initializing plugins for $template_file..."
    packer init "$template_file"
    echo "Done."
    echo ""
  fi
done

echo "All plugins initialized successfully!"