# GitHub Actions logs in to Google Cloud with its own short-lived OIDC token.
# No service account key is created, stored in GitHub or written to state.

locals {
  # GitHub's default subject claim is repo:<owner>/<name>:environment:<env>
  # for a job that runs in an environment, and repo:<owner>/<name>:ref:<ref>
  # otherwise.
  subject_suffix = var.github_environment == "" ? "ref:refs/heads/${var.branch}" : "environment:${var.github_environment}"

  optional_checks = join("", [
    var.github_repository_id == "" ? "" : " && assertion.repository_id == '${var.github_repository_id}'",
    var.github_environment == "" ? "" : " && assertion.environment == '${var.github_environment}'",
  ])
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions"
  description               = "Short-lived logins for ${var.github_repository}, branch ${var.branch}."
}

resource "google_iam_workload_identity_pool_provider" "github" {
  #checkov:skip=CKV_GCP_125:Checkov cannot render this condition from module inputs. tests/github_wif.tftest.hcl asserts the exact planned condition (subject, repository, branch, environment) instead.
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_id"    = "assertion.repository_id"
    "attribute.ref"              = "assertion.ref"
    "attribute.environment"      = "assertion.environment"
    "attribute.workflow_ref"     = "assertion.job_workflow_ref"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  # Every check is ANDed. Google rejects a token that fails any of them
  # before it can be exchanged for credentials.
  attribute_condition = "assertion.sub == 'repo:${var.github_repository}:${local.subject_suffix}' && assertion.repository == '${var.github_repository}' && assertion.ref == 'refs/heads/${var.branch}'${local.optional_checks}"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# The identity CI acts as. What it may do is granted next to each resource
# in the root module: push to one repository, deploy one service.
resource "google_service_account" "deployer" {
  project      = var.project_id
  account_id   = var.deployer_account_id
  display_name = "GitHub Actions deployer for ${var.github_repository}"
}

# Only tokens that passed the condition above, from this repository, may
# impersonate the deployer.
resource "google_service_account_iam_member" "github_impersonates_deployer" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}
