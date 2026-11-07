# The optional database module: private IP, TLS, IAM login, backups and
# deletion protection. Off by default (see environments.tftest.hcl).

mock_provider "google" {
  source          = "./tests/mocks"
  override_during = plan
}

variables {
  project_id                    = "acme-chatbot-staging"
  region                        = "us-central1"
  name                          = "pdf-chatbot-staging-db"
  network_id                    = "projects/acme-chatbot-staging/global/networks/app"
  runtime_service_account_email = "pdf-chatbot-staging-run@acme-chatbot-staging.iam.gserviceaccount.com"
}

run "database_is_private_with_iam_login" {
  command = plan

  module {
    source = "./modules/cloud-sql"
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].ip_configuration[0].ipv4_enabled == false
    error_message = "The database must have no public IP."
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].ip_configuration[0].ssl_mode == "TRUSTED_CLIENT_CERTIFICATE_REQUIRED"
    error_message = "Connections must be encrypted and carry a client certificate (the Cloud SQL connector does this)."
  }

  assert {
    condition     = google_sql_database_instance.this.settings[0].backup_configuration[0].enabled && google_sql_database_instance.this.settings[0].backup_configuration[0].point_in_time_recovery_enabled
    error_message = "Backups and point-in-time recovery must be on."
  }

  assert {
    condition     = google_sql_database_instance.this.deletion_protection && google_sql_database_instance.this.settings[0].deletion_protection_enabled
    error_message = "The database must be protected from deletion in Terraform and in the API."
  }

  assert {
    condition     = anytrue([for f in google_sql_database_instance.this.settings[0].database_flags : f.name == "cloudsql.iam_authentication" && f.value == "on"])
    error_message = "IAM database login must be on."
  }

  assert {
    condition     = google_sql_user.runtime.type == "CLOUD_IAM_SERVICE_ACCOUNT" && google_sql_user.runtime.name == "pdf-chatbot-staging-run@acme-chatbot-staging.iam"
    error_message = "The app logs in as its runtime service account."
  }

  assert {
    condition     = google_sql_user.runtime.password == null && google_sql_database_instance.this.root_password == null
    error_message = "No database password may be set anywhere."
  }

  assert {
    condition = alltrue([
      for g in google_project_iam_member.runtime_sql :
      g.condition[0].expression == "resource.name == 'projects/acme-chatbot-staging/instances/pdf-chatbot-staging-db' && resource.type == 'sqladmin.googleapis.com/Instance'"
    ])
    error_message = "The Cloud SQL roles must be limited to this one instance by an IAM condition."
  }

  assert {
    condition     = toset([for g in google_project_iam_member.runtime_sql : g.role]) == toset(["roles/cloudsql.client", "roles/cloudsql.instanceUser"])
    error_message = "The runtime identity gets the two roles a connection needs, nothing else."
  }
}

run "root_wires_the_database_into_the_service" {
  command = plan

  variables {
    environment        = "staging"
    max_instance_count = 2
    cloud_sql = {
      network_id    = "projects/acme-chatbot-staging/global/networks/app"
      subnetwork_id = "projects/acme-chatbot-staging/regions/us-central1/subnetworks/app"
    }
  }

  assert {
    condition     = length(module.cloud_sql) == 1
    error_message = "Setting cloud_sql creates the database."
  }

  assert {
    condition     = module.cloud_sql[0].connection_name == "acme-chatbot-staging:us-central1:mock-db"
    error_message = "The service gets the instance connection name."
  }
}
