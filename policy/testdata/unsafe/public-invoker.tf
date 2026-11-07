# Deliberately unsafe: the policy check must reject this file.
resource "google_cloud_run_v2_service_iam_member" "open" {
  name     = "pdf-chatbot-staging"
  location = "us-central1"
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_v2_service" "no_iam_check" {
  name                 = "pdf-chatbot-staging"
  location             = "us-central1"
  invoker_iam_disabled = true

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
    }
  }
}
