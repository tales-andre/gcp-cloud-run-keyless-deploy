output "workload_identity_provider" {
  description = "Full provider name for google-github-actions/auth (workload_identity_provider)."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "attribute_condition" {
  description = "The CEL condition every GitHub token must pass."
  value       = google_iam_workload_identity_pool_provider.github.attribute_condition
}

output "deployer_email" {
  description = "Service account CI impersonates (service_account input of google-github-actions/auth)."
  value       = google_service_account.deployer.email
}

output "deployer_member" {
  description = "IAM member string of the deployer (serviceAccount:...)."
  value       = google_service_account.deployer.member
}
