# A separate root module for bringing resources that were clicked together in
# the console under Terraform. It has its own state and is never part of the
# `terraform test` run in infra/: an import needs a real project.
#
# The resources below describe a hand-made setup as it is, not as it should
# be. The goal of the first pass is a plan with no changes; fixes come after,
# one reviewed pull request at a time (see WALKTHROUGH.md).
#
# Never executed: this module has only been through `terraform init
# -backend=false` and `terraform validate`.

terraform {
  required_version = ">= 1.9.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.10"
    }
  }

  # Point this at the state bucket before the first plan:
  #   terraform init -backend-config="bucket=<state bucket>" -backend-config="prefix=imported"
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "Project that holds the hand-made resources."
  type        = string
}

variable "region" {
  description = "Region of the Cloud Run service."
  type        = string
  default     = "us-central1"
}

variable "service_name" {
  description = "Name of the Cloud Run service created in the console."
  type        = string
  default     = "pdf-chatbot"
}

variable "current_image" {
  description = "Image the live service runs, copied from `gcloud run services describe` (keep the @sha256 digest)."
  type        = string
}

variable "runtime_service_account" {
  description = "Service account the live service runs as. A console deploy usually leaves the default compute account: copy it from the describe output."
  type        = string
}

variable "bucket_name" {
  description = "Bucket the PDFs were uploaded to."
  type        = string
}

variable "secret_id" {
  description = "Secret that holds the AI provider key."
  type        = string
  default     = "openai-api-key"
}

resource "google_cloud_run_v2_service" "chatbot" {
  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  # A Terraform-only setting, not stored on Google's side.
  deletion_protection = true

  template {
    service_account = var.runtime_service_account

    # The console default. Lowering it is the first reviewed change after the
    # import, not part of it.
    scaling {
      max_instance_count = 100
    }

    containers {
      image = var.current_image

      ports {
        container_port = 8000
      }

      env {
        name  = "DOCS_DIR"
        value = "/docs"
      }

      env {
        name = "OPENAI_API_KEY"
        value_source {
          secret_key_ref {
            secret  = var.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      volume_mounts {
        name       = "docs"
        mount_path = "/docs"
      }
    }

    volumes {
      name = "docs"
      gcs {
        bucket    = var.bucket_name
        read_only = true
      }
    }
  }

  lifecycle {
    # Set by whichever tool deployed last (console, gcloud); not worth a diff.
    ignore_changes = [client, client_version]
  }
}

resource "google_storage_bucket" "documents" {
  name                        = var.bucket_name
  location                    = upper(var.region)
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  soft_delete_policy {
    retention_duration_seconds = 604800
  }
}

# Only the secret container is imported. Its versions (the key itself) are
# left out on purpose, so the key never lands in Terraform state.
resource "google_secret_manager_secret" "api_key" {
  secret_id = var.secret_id

  replication {
    auto {}
  }
}
