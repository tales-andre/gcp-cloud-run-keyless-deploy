output "service_name" {
  description = "Cloud Run service name."
  value       = module.service.name
}

output "service_url" {
  description = "HTTPS address of the service. Staging needs an identity token to call it."
  value       = module.service.uri
}

output "runtime_service_account" {
  description = "Identity the container runs as."
  value       = module.service.runtime_service_account_email
}

output "artifact_registry" {
  description = "Where CI pushes images."
  value       = module.registry.url
}

output "llm_api_key_secret" {
  description = "Secret to add the AI provider key to, or null in offline mode."
  value       = local.llm_needs_key ? google_secret_manager_secret.llm_api_key[0].secret_id : null
}

output "attribute_condition" {
  description = "What a GitHub token must prove before it can log in."
  value       = module.github.attribute_condition
}

# Copy these into the GitHub repository variables (Settings > Secrets and
# variables > Actions > Variables). None of them is a secret.
output "github_variables" {
  description = "Repository variables the deploy workflow reads for this environment."
  value = {
    "GCP_${upper(local.env_short)}_PROJECT"      = var.project_id
    "GCP_${upper(local.env_short)}_REGION"       = var.region
    "GCP_${upper(local.env_short)}_WIF_PROVIDER" = module.github.workload_identity_provider
    "GCP_${upper(local.env_short)}_DEPLOYER"     = module.github.deployer_email
    "GCP_${upper(local.env_short)}_SERVICE"      = module.service.name
    "GCP_${upper(local.env_short)}_REGISTRY"     = module.registry.url
    "GCP_${upper(local.env_short)}_PUBLIC"       = tostring(var.public)
  }
}

output "invokers" {
  description = "Who may call the service. allUsers means public."
  value       = module.service.invokers
}

output "max_instance_count" {
  description = "Instance cap: the most instances this environment can bill for at once."
  value       = module.service.max_instance_count
}
