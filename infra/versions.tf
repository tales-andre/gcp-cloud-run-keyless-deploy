terraform {
  # 1.9+ for cross-variable validation; 1.7+ for mock providers in `terraform test`.
  required_version = ">= 1.9.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.10"
    }
  }

  # One state per environment. Fill in the bucket with
  #   terraform init -backend-config=envs/staging.gcs.tfbackend
  # CI and the offline tests use `terraform init -backend=false` and never touch it.
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region

  default_labels = {
    app         = var.app_name
    environment = var.environment
    managed-by  = "terraform"
  }
}
