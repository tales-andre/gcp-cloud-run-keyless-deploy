variable "project_id" {
  description = "Google Cloud project for this environment. One project per environment keeps staging mistakes out of production."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6 to 30 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "region" {
  description = "Region for Cloud Run, Artifact Registry and the optional database."
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "staging or production. Also the GitHub environment a deploy job must run in."
  type        = string

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production."
  }
}

variable "app_name" {
  description = "Short app name used in resource names."
  type        = string
  default     = "pdf-chatbot"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,13}[a-z0-9]$", var.app_name))
    error_message = "app_name must be 4 to 15 lowercase letters, digits or hyphens, so every derived name stays within Google's limits."
  }
}

variable "image" {
  description = "Image for the very first revision, before CI has pushed one. Google's public sample image works for that."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "max_instance_count" {
  description = "Hard cap on Cloud Run instances: the main protection against a surprise bill."
  type        = number

  validation {
    condition     = var.max_instance_count >= 1 && var.max_instance_count <= 20 && floor(var.max_instance_count) == var.max_instance_count
    error_message = "max_instance_count must be a whole number from 1 to 20."
  }
}

variable "min_instance_count" {
  description = "Instances kept warm. 0 scales to zero when idle."
  type        = number
  default     = 0
}

variable "memory" {
  description = "Memory per instance."
  type        = string
  default     = "512Mi"
}

variable "cpu" {
  description = "CPU per instance."
  type        = string
  default     = "1"
}

variable "public" {
  description = "Let anyone on the internet use the chatbot. Never allowed in staging."
  type        = bool
  default     = false

  validation {
    condition     = !(var.environment == "staging" && var.public)
    error_message = "Staging must not be public: anyone could use it and run up the bill. Grant invoker_members instead."
  }
}

variable "invoker_members" {
  description = "Who may call the service when it is not public, for example group:testers@example.com."
  type        = list(string)
  default     = []

  validation {
    condition     = length(setintersection(toset(var.invoker_members), toset(["allUsers", "allAuthenticatedUsers"]))) == 0
    error_message = "Do not put allUsers or allAuthenticatedUsers in invoker_members. Use public = true (production only)."
  }
}

variable "llm_provider" {
  description = "none runs the chatbot offline with no AI key. openai, anthropic or gemini reads the key from Secret Manager, and needs an image built with WITH_LLM=1 (the image deploy.yml builds is offline only and stops at startup otherwise)."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "openai", "anthropic", "gemini"], var.llm_provider)
    error_message = "llm_provider must be none, openai, anthropic or gemini."
  }
}

variable "llm_model" {
  description = "Model name exactly as the provider lists it. Ignored when llm_provider is none."
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "The only repository whose workflows may deploy, as owner/name."
  type        = string
  default     = "tales-andre/gcp-cloud-run-keyless-deploy"

  validation {
    # Also keeps quotes and operators out of the login condition built from it.
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9._-]{1,100}$", var.github_repository))
    error_message = "github_repository must look like owner/name, with no spaces or quotes."
  }
}

variable "github_repository_id" {
  description = "Numeric ID of that repository. Recommended once the repository exists; empty skips the check."
  type        = string
  default     = ""
}

variable "github_branch" {
  description = "The only branch whose workflows may deploy."
  type        = string
  default     = "main"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.github_branch))
    error_message = "github_branch must be a plain branch name, with no spaces or quotes."
  }
}

variable "deletion_protection" {
  description = "Protect the service (and the database, if any) from `terraform destroy`."
  type        = bool
  default     = true
}

variable "cloud_sql" {
  description = "Optional PostgreSQL with a private IP. null (the default) creates no database."
  type = object({
    network_id                    = string
    subnetwork_id                 = string
    tier                          = optional(string, "db-f1-micro")
    availability_type             = optional(string, "ZONAL")
    create_private_service_access = optional(bool, true)
  })
  default = null
}
