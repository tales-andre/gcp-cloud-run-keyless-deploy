# Optional PostgreSQL for apps that need one. The PDF chatbot does not; the
# module is off unless `cloud_sql` is set in the environment's tfvars.
#
# Private IP only, TLS required, IAM login for the Cloud Run identity (no
# database password anywhere), daily backups with point-in-time recovery.

resource "google_compute_global_address" "private_services" {
  count = var.create_private_service_access ? 1 : 0

  project       = var.project_id
  name          = "${var.name}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = var.network_id
}

resource "google_service_networking_connection" "private_services" {
  count = var.create_private_service_access ? 1 : 0

  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services[0].name]
}

resource "google_sql_database_instance" "this" {
  #checkov:skip=CKV2_GCP_13:log_duration writes a log line for every statement; turn it on while tuning queries, not by default.
  project             = var.project_id
  region              = var.region
  name                = var.name
  database_version    = var.database_version
  deletion_protection = var.deletion_protection

  settings {
    edition                     = "ENTERPRISE"
    tier                        = var.tier
    availability_type           = var.availability_type
    disk_size                   = var.disk_size_gb
    disk_autoresize             = true
    disk_autoresize_limit       = var.disk_autoresize_limit_gb
    deletion_protection_enabled = var.deletion_protection

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network_id
      # The Cloud SQL connector presents a short-lived client certificate, so
      # only connections through it (or the Auth Proxy) get in.
      ssl_mode = "TRUSTED_CLIENT_CERTIFICATE_REQUIRED"
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "03:00"
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
      }
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }

    # Security-relevant logging flags required by the Checkov CIS checks.
    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }
    database_flags {
      name  = "log_connections"
      value = "on"
    }
    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }
    database_flags {
      name  = "log_min_messages"
      value = "error"
    }
    database_flags {
      name  = "log_temp_files"
      value = "0"
    }
    database_flags {
      name  = "log_min_duration_statement"
      value = "-1"
    }
    database_flags {
      name  = "cloudsql.enable_pgaudit"
      value = "on"
    }
    database_flags {
      name  = "log_statement"
      value = "ddl"
    }
    database_flags {
      name  = "log_min_error_statement"
      value = "error"
    }
    database_flags {
      name  = "log_hostname"
      value = "on"
    }
  }

  depends_on = [google_service_networking_connection.private_services]
}

resource "google_sql_database" "app" {
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = var.database_name
}

# IAM database user: Cloud SQL accepts the service account's own short-lived
# token. There is no password to create, rotate or leak.
resource "google_sql_user" "runtime" {
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  name     = trimsuffix(var.runtime_service_account_email, ".gserviceaccount.com")
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

# Cloud SQL has no per-instance IAM, so the grants are project-level with a
# condition that limits them to this one instance.
resource "google_project_iam_member" "runtime_sql" {
  for_each = toset(["roles/cloudsql.client", "roles/cloudsql.instanceUser"])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${var.runtime_service_account_email}"

  condition {
    title       = "only-${var.name}"
    description = "Limited to the ${var.name} instance."
    expression  = "resource.name == 'projects/${var.project_id}/instances/${var.name}' && resource.type == 'sqladmin.googleapis.com/Instance'"
  }
}
