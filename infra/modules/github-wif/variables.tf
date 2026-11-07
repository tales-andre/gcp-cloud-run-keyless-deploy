variable "project_id" {
  description = "Project that holds the pool and the deployer service account."
  type        = string
}

variable "pool_id" {
  description = "Workload Identity pool ID, for example github-staging. A deleted pool ID stays reserved for 30 days."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}[a-z0-9]$", var.pool_id)) && !startswith(var.pool_id, "gcp-")
    error_message = "pool_id must be 4 to 32 lowercase letters, digits or hyphens and must not start with gcp-."
  }
}

variable "github_repository" {
  description = "The only GitHub repository whose workflows may log in, as owner/name."
  type        = string

  validation {
    # Also keeps quotes and operators out of the CEL condition built from it.
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9._-]{1,100}$", var.github_repository))
    error_message = "github_repository must look like owner/name, with no spaces or quotes."
  }
}

variable "github_repository_id" {
  description = "Numeric ID of the repository (Settings or the API). When set, a repository deleted and re-created under the same name by someone else cannot log in. Empty skips this check."
  type        = string
  default     = ""

  validation {
    condition     = var.github_repository_id == "" || can(regex("^[0-9]+$", var.github_repository_id))
    error_message = "github_repository_id must be digits only, or empty."
  }
}

variable "branch" {
  description = "The only branch whose workflows may log in."
  type        = string
  default     = "main"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.branch))
    error_message = "branch must be a plain branch name, with no spaces or quotes."
  }
}

variable "github_environment" {
  description = "When set, only a job that runs in this GitHub environment may log in (the environment can require a reviewer). Empty skips this check."
  type        = string
  default     = ""

  validation {
    condition     = var.github_environment == "" || can(regex("^[A-Za-z0-9._-]+$", var.github_environment))
    error_message = "github_environment must be a plain environment name, with no spaces or quotes."
  }
}

variable "deployer_account_id" {
  description = "Account ID of the service account CI impersonates."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.deployer_account_id))
    error_message = "deployer_account_id must be 6 to 30 lowercase letters, digits or hyphens."
  }
}
