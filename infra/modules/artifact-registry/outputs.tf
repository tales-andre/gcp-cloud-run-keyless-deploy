output "id" {
  description = "Full resource ID of the repository."
  value       = google_artifact_registry_repository.this.id
}

output "repository_id" {
  description = "Short repository name."
  value       = google_artifact_registry_repository.this.repository_id
}

output "url" {
  description = "Docker host and path to push to, for example us-central1-docker.pkg.dev/my-project/pdf-chatbot."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.repository_id}"
}
