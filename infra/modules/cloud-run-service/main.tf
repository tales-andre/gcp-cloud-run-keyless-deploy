# The identity the container runs as. It gets no project-wide roles here:
# only read access to its own secrets (below) and, when a database is attached,
# the Cloud SQL roles granted by the cloud-sql module.
resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = "${var.name}-run"
  display_name = "Runtime identity of the ${var.name} Cloud Run service"
}

resource "google_cloud_run_v2_service" "this" {
  project             = var.project_id
  location            = var.region
  name                = var.name
  ingress             = var.ingress
  deletion_protection = var.deletion_protection
  labels              = var.labels

  # Never let a request skip the IAM check, even when `public` is true:
  # public access is an IAM grant to allUsers, visible and reviewable.
  invoker_iam_disabled = false

  template {
    service_account                  = google_service_account.runtime.email
    max_instance_request_concurrency = var.concurrency
    timeout                          = var.request_timeout

    scaling {
      min_instance_count = var.min_instance_count
      max_instance_count = var.max_instance_count
    }

    containers {
      image = var.image

      ports {
        container_port = var.container_port
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
        # CPU is only billed while a request is being handled.
        cpu_idle          = true
        startup_cpu_boost = true
      }

      dynamic "env" {
        for_each = var.env
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secrets are passed by reference. The value never appears in Terraform
      # code, variables or state; Cloud Run reads it from Secret Manager at startup.
      dynamic "env" {
        for_each = var.secret_env
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }

      startup_probe {
        initial_delay_seconds = 2
        period_seconds        = 3
        timeout_seconds       = 2
        failure_threshold     = 20
        http_get {
          path = var.health_path
        }
      }

      liveness_probe {
        period_seconds    = 30
        timeout_seconds   = 5
        failure_threshold = 3
        http_get {
          path = var.health_path
        }
      }
    }

    # Direct VPC egress, so the app reaches a private-IP database over the VPC.
    dynamic "vpc_access" {
      for_each = var.vpc_access == null ? [] : [var.vpc_access]
      content {
        egress = "PRIVATE_RANGES_ONLY"
        network_interfaces {
          network    = vpc_access.value.network
          subnetwork = vpc_access.value.subnetwork
        }
      }
    }
  }

  lifecycle {
    # CI deploys new images by digest with gcloud. Terraform owns everything
    # else about the service and does not roll the image back on the next apply.
    ignore_changes = [
      client,
      client_version,
      template[0].containers[0].image,
    ]
  }

  # A revision that reads a secret fails to start if the grant is not there yet.
  depends_on = [google_secret_manager_secret_iam_binding.runtime_reads_secret]
}

# Authoritative for this role on each secret: only the runtime service account
# can read it. A grant added by hand in the console is removed on the next apply.
resource "google_secret_manager_secret_iam_binding" "runtime_reads_secret" {
  for_each = toset(values(var.secret_env))

  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  members   = [google_service_account.runtime.member]
}

# Authoritative for roles/run.invoker on this service: the list in code is
# the whole list. Staging stays private; production is public only when
# `public = true` is set on purpose.
resource "google_cloud_run_v2_service_iam_binding" "invokers" {
  count = length(local.invokers) > 0 ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  members  = local.invokers
}

locals {
  invokers = concat(var.public ? ["allUsers"] : [], var.invoker_members)
}
