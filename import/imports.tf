# Import blocks (Terraform 1.5+; variables in `id` need 1.6+). `terraform plan`
# shows each one as "will be imported"; `terraform apply` records them in state
# without changing anything on Google Cloud. Once applied they are no-ops and
# can be deleted.

import {
  to = google_cloud_run_v2_service.chatbot
  id = "projects/${var.project_id}/locations/${var.region}/services/${var.service_name}"
}

import {
  to = google_storage_bucket.documents
  id = "${var.project_id}/${var.bucket_name}"
}

import {
  to = google_secret_manager_secret.api_key
  id = "projects/${var.project_id}/secrets/${var.secret_id}"
}
