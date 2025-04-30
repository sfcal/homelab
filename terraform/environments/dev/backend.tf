# Add to backend.tf for a local backend
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}