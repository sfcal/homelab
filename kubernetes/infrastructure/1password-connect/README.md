# 1Password Connect Integration

This directory contains the configuration for 1Password Connect server integration with External Secrets Operator.

## Setup Instructions

1. **Create a 1Password Connect Server**
   - Go to your 1Password account settings
   - Navigate to Integrations > Directory > Connect Server
   - Create a new server and download:
     - `1password-credentials.json` - The credentials file
     - Connect server token

2. **Configure Secrets**
   
   Update the following files with your actual credentials:
   
   - `secret.yaml`: Replace the placeholder with your actual `1password-credentials.json` content
   - `connect-token-secret.yaml`: Replace `YOUR_1PASSWORD_CONNECT_TOKEN_HERE` with your connect token

3. **Deploy the Stack**
   ```bash
   # Apply the infrastructure
   kubectl apply -k infrastructure/
   ```

4. **Create 1Password Items**
   
   In your 1Password vault named `k3s-dev`, create items that External Secrets will reference.
   
   Example item structure:
   - Item name: `example-app`
   - Fields:
     - username: your-username
     - password: your-password
     - api_key: your-api-key

5. **Use ExternalSecrets**
   
   See `../external-secrets/examples/1password-example.yaml` for an example of how to create an ExternalSecret that references 1Password items.

## Vault Configuration

The ClusterSecretStore is configured to use vault ID `1` which maps to vault name `k3s-dev`. Update this in `../external-secrets/secret-store-1password.yaml` if you need to use a different vault.

## Troubleshooting

1. Check 1Password Connect pod logs:
   ```bash
   kubectl logs -n 1password-connect -l app.kubernetes.io/name=connect
   ```

2. Check External Secrets Operator logs:
   ```bash
   kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
   ```

3. Verify the ExternalSecret status:
   ```bash
   kubectl describe externalsecret example-1password-secret -n default
   ```