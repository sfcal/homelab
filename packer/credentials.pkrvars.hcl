// Credentials for Proxmox
// Copy this file to credentials.pkr.hcl and fill in your values

// Development cluster credentials
# variable "dev_proxmox_api_url" {
#   type    = string
#   default = "https://10.1.20.11:8006/api2/json"
# }

# variable "dev_proxmox_api_token_id" {
#   type    = string
#   default = "root@pam!packer"
# }

# variable "dev_proxmox_api_token_secret" {
#   type      = string
#   sensitive = true
#   default   = "7d6374bc-6fce-47bf-9e45-5ef030f89cfd"
# }

# // Production cluster credentials
# variable "prod_proxmox_api_url" {
#   type    = string
#   default = "https://10.2.20.11:8006/api2/json"
# }

# variable "prod_proxmox_api_token_id" {
#   type    = string
#   default = "root@pam!packer"
# }

# variable "prod_proxmox_api_token_secret" {
#   type      = string
#   sensitive = true
#   default   = "0856d1ae-13fc-43f6-b610-dd2abbf83c00"
# }

# // SSH credentials
# variable "ssh_password" {
#   type      = string
#   sensitive = true
#   default   = "SuperSecure00"
# }
// Credentials for Proxmox
// Copy this file to credentials.pkrvars.hcl and fill in your values

// Update these values with your actual credentials
proxmox_api_url = "https://10.1.20.11:8006/api2/json"
proxmox_api_token_id = "root@pam!packer"
proxmox_api_token_secret = "7d6374bc-6fce-47bf-9e45-5ef030f89cfd"
ssh_password = "SuperSecure00"