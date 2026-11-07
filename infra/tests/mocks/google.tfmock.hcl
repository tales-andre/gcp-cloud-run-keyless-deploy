# Values the fake Google provider returns for computed attributes, in the
# same shape the real API uses, so the provider's own format checks pass.
# Nothing here talks to Google Cloud.

mock_resource "google_service_account" {
  defaults = {
    email     = "mock-sa@acme-chatbot-staging.iam.gserviceaccount.com"
    member    = "serviceAccount:mock-sa@acme-chatbot-staging.iam.gserviceaccount.com"
    name      = "projects/acme-chatbot-staging/serviceAccounts/mock-sa@acme-chatbot-staging.iam.gserviceaccount.com"
    unique_id = "100000000000000000001"
  }
}

mock_resource "google_iam_workload_identity_pool" {
  defaults = {
    name = "projects/123456789012/locations/global/workloadIdentityPools/github-mock"
  }
}

mock_resource "google_iam_workload_identity_pool_provider" {
  defaults = {
    name = "projects/123456789012/locations/global/workloadIdentityPools/github-mock/providers/github"
  }
}

mock_resource "google_cloud_run_v2_service" {
  defaults = {
    uri = "https://pdf-chatbot-mock-uc.a.run.app"
  }
}

mock_resource "google_secret_manager_secret" {
  defaults = {
    name = "projects/123456789012/secrets/mock-secret"
  }
}

mock_resource "google_sql_database_instance" {
  defaults = {
    connection_name = "acme-chatbot-staging:us-central1:mock-db"
  }
}
