output "name" {
  description = "Service name."
  value       = google_cloud_run_v2_service.this.name
}

output "uri" {
  description = "HTTPS address Cloud Run gives the service."
  value       = google_cloud_run_v2_service.this.uri
}

output "runtime_service_account_email" {
  description = "Email of the identity the container runs as."
  value       = google_service_account.runtime.email
}

output "runtime_service_account_member" {
  description = "IAM member string of the runtime identity (serviceAccount:...)."
  value       = google_service_account.runtime.member
}

output "runtime_service_account_name" {
  description = "Full resource name of the runtime identity, for IAM grants on it."
  value       = google_service_account.runtime.name
}

output "invokers" {
  description = "Everyone who may call the service (roles/run.invoker). allUsers means public."
  value       = local.invokers
}

output "max_instance_count" {
  description = "The instance cap on the service."
  value       = google_cloud_run_v2_service.this.template[0].scaling[0].max_instance_count
}

output "secret_env_names" {
  description = "Environment variables filled from Secret Manager (names only, never values)."
  value       = sort(keys(var.secret_env))
}
