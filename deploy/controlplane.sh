#!/bin/bash
set -e

# Configuration
PROXMOX_URL="https://10.1.10.23:8006/api2/json"
PROXMOX_NODE="pve-dev01"
PROXMOX_TOKEN_ID="root@pam!packer"
# Read secrets from environment variables or prompt for them
#PROXMOX_PASSWORD=${PROXMOX_PASSWORD:-$(read -sp "Proxmox Password: " pwd; echo $pwd)}
PROXMOX_TOKEN_SECRET=${PROXMOX_TOKEN_SECRET:-$(read -sp "Proxmox API Token Secret: " token; echo $token)}
SSH_PASSWORD=${SSH_PASSWORD:-$(read -sp "SSH Password for VMs: " ssh_pwd; echo $ssh_pwd)}


# Function to check and install a package if missing
install_if_missing() {
    local package=$1
    if ! dpkg -l | grep -qw "$package"; then
        echo "Installing $package..."
        sudo apt update && sudo apt install -y "$package"
    else
        echo "$package is already installed."
    fi
}

# Install essential packages
for package in git curl unzip gpg lsb-release; do
    install_if_missing "$package"
done

# Install Terraform
if ! command -v terraform &> /dev/null; then
    echo "Installing Terraform..."
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
    sudo apt update
    sudo apt install -y terraform
else
    echo "Terraform is already installed."
fi

# Install Packer
if ! command -v packer &> /dev/null; then
    echo "Installing Packer..."
    sudo apt install -y packer
else
    echo "Packer is already installed."
fi

# Ensure SSH configuration is set up
SSH_CONFIG_PATH="$HOME/.ssh/config"
if [ ! -f "$SSH_CONFIG_PATH" ]; then
    echo "Creating SSH configuration..."
    mkdir -p "$HOME/.ssh"
    cat <<EOL > "$SSH_CONFIG_PATH"
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
EOL
    chmod 400 "$SSH_CONFIG_PATH"
    echo "SSH configuration created and permissions set."
else
    echo "SSH configuration already exists."
fi

SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "Generating SSH key..."
    ssh-keygen -t ed25519 -C "ssh@homelab.home" -f "$SSH_KEY_PATH" -N ""
    
    echo -e "\e[32mYour public key is:\e[0m"
    cat "${SSH_KEY_PATH}.pub"
    if [ "$REPO_TYPE" == "private" ]; then
        echo -e "\e[33mAdd the public key to GitHub under Deploy Keys and press Enter...\e[0m"
        read -r
    fi
else
    echo "SSH key already exists at $SSH_KEY_PATH."
fi

echo "======= Step 1: Building Packer Template ======="
#clone repo
git clone https://github.com/sfcal/homelab
cd homelab/packer/proxmox
#Create variables file for Packer
cat > proxmox_credentials.env << EOF
PROXMOX_URL="$PROXMOX_URL"
PROXMOX_TOKEN_ID="$PROXMOX_TOKEN_ID"
PROXMOX_TOKEN_SECRET="$PROXMOX_TOKEN_SECRET"
SSH_PASSWORD="$SSH_PASSWORD"
EOF

cd ubuntu-server-noble

# Initialize Packer plugins
echo "Initializing Packer..."
packer init ubuntu-server-noble-docker.pkr.hcl

# Build the template
echo "Building VM template with Packer..."
packer build -var-file=../credentials.pkr.hcl ubuntu-server-noble-docker.pkr.hcl

# Wait for template to be fully available
echo "Waiting for template to be fully available..."
sleep 30

# echo "======= Step 2: Creating Terraform Configuration ======="
# # Create terraform.tfvars file
# cat > terraform.tfvars << EOF
# proxmox_api_url = "$PROXMOX_URL"
# proxmox_api_token_id = "$PROXMOX_TOKEN_ID"
# proxmox_api_token_secret = "$PROXMOX_TOKEN_SECRET"
# EOF

# # Initialize Terraform
# echo "Initializing Terraform..."
# terraform init > "$LOG_DIR/terraform_init.log" 2>&1

# # Create a Terraform plan
# echo "Creating Terraform plan..."
# terraform plan -out=tfplan > "$LOG_DIR/terraform_plan.log" 2>&1

# # Apply the Terraform configuration
# echo "Applying Terraform configuration..."
# terraform apply -auto-approve tfplan > "$LOG_DIR/terraform_apply.log" 2>&1

# # Get the IPs of the deployed VMs
# echo "Getting VM IPs..."
# terraform output -json vm_ips > "$LOG_DIR/vm_ips.json"
# VM_IPS=$(cat "$LOG_DIR/vm_ips.json" | jq -r 'to_entries | map("\(.key): \(.value)") | .[]')

# echo "======= Step 3: Verifying Docker Containers ======="
# # Check if containers are running on each VM
# for VM_INFO in $VM_IPS; do
#     VM_NAME=$(echo $VM_INFO | cut -d':' -f1)
#     VM_IP=$(echo $VM_INFO | cut -d':' -f2 | tr -d ' ')
    
#     echo "Checking Docker containers on $VM_NAME ($VM_IP)..."
    
#     # Wait for SSH to be available
#     echo "Waiting for SSH to be available..."
#     for i in {1..10}; do
#         if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$VM_IP "exit" 2>/dev/null; then
#             break
#         fi
#         if [ $i -eq 10 ]; then
#             echo "Could not connect to $VM_NAME after 10 attempts."
#             continue
#         fi
#         echo "Attempt $i: SSH not available yet, waiting..."
#         sleep 10
#     done
    
#     # Check Docker containers
#     echo "Checking Docker containers on $VM_NAME..."
#     ssh -o StrictHostKeyChecking=no ubuntu@$VM_IP "docker ps" > "$LOG_DIR/${VM_NAME}_docker_ps.log" 2>&1
    
#     # Get container count
#     CONTAINER_COUNT=$(ssh -o StrictHostKeyChecking=no ubuntu@$VM_IP "docker ps -q | wc -l")
#     echo "$VM_NAME has $CONTAINER_COUNT running containers"
    
#     # Check container logs briefly
#     echo "Checking container logs on $VM_NAME..."
#     ssh -o StrictHostKeyChecking=no ubuntu@$VM_IP "for c in \$(docker ps -q); do docker logs --tail 5 \$c; done" > "$LOG_DIR/${VM_NAME}_container_logs.log" 2>&1
# done

# echo "======= Deployment Summary ======="
# echo "Deployment completed at $(date)"
# echo "VM Template created: docker-template"
# echo "VMs deployed:"
# echo "$VM_IPS"
# echo "All logs are available in the $LOG_DIR directory"

# # Cleanup sensitive files
# echo "Cleaning up sensitive files..."
# rm -f packer_vars.json terraform.tfvars

# echo "======= Deployment Complete ======="