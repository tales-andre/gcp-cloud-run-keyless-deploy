variable "project_id" {
  description = "Project that holds the repository."
  type        = string
}

variable "region" {
  description = "Region of the repository. Use the same region as the Cloud Run service to avoid cross-region pulls."
  type        = string
}

variable "repository_id" {
  description = "Repository name, for example pdf-chatbot."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,61}[a-z0-9]$", var.repository_id))
    error_message = "repository_id must be lowercase letters, digits and hyphens."
  }
}

variable "keep_recent_images" {
  description = "How many recent image versions are always kept, so a rollback target is never cleaned up."
  type        = number
  default     = 10

  validation {
    condition     = var.keep_recent_images >= 2
    error_message = "Keep at least 2 images: the running one and the previous one for rollback."
  }
}

variable "delete_after_days" {
  description = "Images older than this, and not among the most recent ones, are deleted to keep storage cost flat."
  type        = number
  default     = 30
}
