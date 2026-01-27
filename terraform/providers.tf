
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# AWS Provider
# Credentials are provided via environment variables set by GitHub Actions
# after retrieving temporary credentials from Vault
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "DevSecOps-Demo"
      Terraform = "true"
    }
  }
}
