# This file is used to specify the required providers for the Vault Secrets module.
terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0" ## allow for minor version updates, but not major version updates
    }
  }
}