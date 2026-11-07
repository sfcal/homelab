/**
 * # Provider Configuration
 *
 * Provider configuration for NYC environment
 */

provider "proxmox" {
  endpoint  = replace(var.proxmox_api_url, "/api2/json", "")
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"
  insecure  = true
}
