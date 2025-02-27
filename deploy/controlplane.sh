#!/bin/bash
set -e

# Configuration
PROXMOX_URL="https://proxmox-host.example.com:8006/api2/json"
PROXMOX_NODE="proxmox-node"
PROXMOX_TOKEN_ID="root@pam!terraform"
# Read secrets from environment variables or prompt for them
PROXMOX_PASSWORD=${PROXMOX_PASSWORD:-$(read -sp "Proxmox Password: " pwd; echo $pwd)}
PROXMOX_TOKEN_SECRET=${PROXMOX_TOKEN_SECRET:-$(read -sp "Proxmox API Token Secret: " token; echo $token)}
SSH_PASSWORD=${SSH_PASSWORD:-$(read -sp "SSH Password for VMs: " ssh_pwd; echo $ssh_pwd)}

# Create a log directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="deployment_logs_${TIMESTAMP}"
mkdir -p $LOG_DIR

echo "Starting deployment process at $(date)"
echo "Logs will be saved to $LOG_DIR directory"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required tools
for cmd in packer terraform jq curl; do
    if ! command_exists $cmd; then
        echo "Error: $cmd is required but not installed. Please install it and try again."
        exit 1
    fi
done

echo "======= Step 1: Building Packer Template ======="
# Create variables file for Packer
cat > packer_vars.json << EOF
{
  "proxmox_password": "$PROXMOX_PASSWORD",
  "ssh_password": "$SSH_PASSWORD"
}
EOF

# Initialize Packer plugins
echo "Initializing Packer..."
packer init proxmox-docker-template.pkr.hcl > "$LOG_DIR/packer_init.log" 2>&1

# Build the template
echo "Building VM template with Packer..."
packer build -var-file=packer_vars.json proxmox-docker-template.pkr.hcl > "$LOG_DIR/packer_build.log" 2>&1

# Wait for template to be fully available
echo "Waiting for template to be fully available..."
sleep 30

echo "======= Step 2: Creating Terraform Configuration ======="
# Create terraform.tfvars file
cat > terraform.tfvars << EOF
proxmox_api_url = "$PROXMOX_URL"
proxmox_api_token_id = "$PROXMOX_TOKEN_ID"
proxmox_api_token_secret = "$PROXMOX_TOKEN_SECRET"
EOF

# Initialize Terraform
echo "Initializing Terraform..."
terraform init > "$LOG_DIR/terraform_init.log" 2>&1

# Create a Terraform plan
echo "Creating Terraform plan..."
terraform plan -out=tfplan > "$LOG_DIR/terraform_plan.log" 2>&1

# Apply the Terraform configuration
echo "Applying Terraform configuration..."
terraform apply -auto-approve tfplan > "$LOG_DIR/terraform_apply.log" 2>&1

# Get the IPs of the deployed VMs
echo "Getting VM IPs..."
terraform output -json vm_ips > "$LOG_DIR/vm_ips.json"
VM_IPS=$(cat "$LOG_DIR/vm_ips.json" | jq -r 'to_entries | map("\(.key): \(.value)") | .[]')

echo "======= Step 3: Verifying Docker Containers ======="
# Check if containers are running on each VM
for VM_INFO in $VM_IPS; do
    VM_NAME=$(echo $VM_INFO | cut -d':' -f1)
    VM_IP=$(echo $VM_INFO | cut -d':' -f2 | tr -d ' ')
    
    echo "Checking Docker containers on $VM_NAME ($VM_IP)..."
    
    # Wait for SSH to be available
    echo "Waiting for SSH to be available..."
    for i in {1..10}; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$VM_IP "exit" 2>/dev/null; then
            break
        fi
        if [ $i -eq 10 ]; then
            echo "Could not connect to $VM_NAME after 10 attempts."
            continue
        fi
        echo "Attempt $i: SSH not available yet, waiting..."
        sleep 10
    done
    
    # Check Docker containers
    echo "Checking Docker containers on $VM_NAME..."
    ssh -o StrictHostKeyChecking=no ubuntu@$VM_IP "docker ps" > "$LOG_DIR/${VM_NAME}_docker_ps.log" 2>&1
    
    # Get container count
    CONTAINER_COUNT=$(ssh -o StrictHostKeyChecking=no ubuntu@$VM_IP "docker ps -q | wc -l")
    echo "$VM_NAME has $CONTAINER_COUNT running containers"
    
    # Check container logs briefly
    echo "Checking container logs on $VM_NAME..."
    ssh -o StrictHostKeyChecking=no ubuntu@$VM_IP "for c in \$(docker ps -q); do docker logs --tail 5 \$c; done" > "$LOG_DIR/${VM_NAME}_container_logs.log" 2>&1
done

echo "======= Deployment Summary ======="
echo "Deployment completed at $(date)"
echo "VM Template created: docker-template"
echo "VMs deployed:"
echo "$VM_IPS"
echo "All logs are available in the $LOG_DIR directory"

# Cleanup sensitive files
echo "Cleaning up sensitive files..."
rm -f packer_vars.json terraform.tfvars

echo "======= Deployment Complete ======="