resource "google_artifact_registry_repository" "this" {
  #checkov:skip=CKV_GCP_84:Google-managed encryption is used. A customer-managed key adds a Cloud KMS key to pay for and look after; set kms_key_name if a compliance rule asks for one.
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  description   = "Container images for ${var.repository_id}. Pushed by CI, by digest."
  format        = "DOCKER"
  mode          = "STANDARD_REPOSITORY"

  # A tag can never be moved to a different image after it is pushed.
  docker_config {
    immutable_tags = true
  }

  cleanup_policy_dry_run = false

  # KEEP wins over DELETE: the most recent images survive, whatever their age.
  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.keep_recent_images
    }
  }

  cleanup_policies {
    id     = "delete-old"
    action = "DELETE"
    condition {
      tag_state  = "ANY"
      older_than = "${var.delete_after_days * 86400}s"
    }
  }
}
