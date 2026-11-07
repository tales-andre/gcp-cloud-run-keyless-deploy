# Deliberately unsafe: the policy check must reject this file.
variable "api_key" {
  type      = string
  sensitive = true
}

resource "google_secret_manager_secret_version" "key" {
  secret      = "projects/acme-chatbot-staging/secrets/llm-api-key"
  secret_data = var.api_key
}
