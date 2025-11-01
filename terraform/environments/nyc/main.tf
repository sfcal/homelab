/**
 * # NYC Environment
 *
 * Wrapper that calls the root module with NYC-specific configuration
 */

module "infrastructure" {
  source = "../../"

  # Provider configuration
  proxmox_api_url          = var.proxmox_api_url
  proxmox_api_token_id     = var.proxmox_api_token_id
  proxmox_api_token_secret = var.proxmox_api_token_secret

  # SSH configuration
  ssh_public_key = var.ssh_public_key

  # VMs to create
  vms = var.vms
}
