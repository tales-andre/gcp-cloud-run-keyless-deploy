# Deliberately unsafe: the policy check must reject this file.
resource "google_service_account" "ci" {
  account_id = "ci-deployer"
}

resource "google_service_account_key" "ci" {
  service_account_id = google_service_account.ci.name
}
