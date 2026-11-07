variable "project_id" {
  description = "Project that runs the service."
  type        = string
}

variable "region" {
  description = "Cloud Run region."
  type        = string
}

variable "name" {
  description = "Service name. Also used for the runtime service account (name + \"-run\"), so it is kept short."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,24}[a-z0-9]$", var.name))
    error_message = "name must be 6 to 26 lowercase letters, digits or hyphens, so the runtime service account ID fits in 30 characters."
  }
}

variable "image" {
  description = "Image for the first revision. Later revisions are deployed by CI, by digest, and Terraform ignores the image after that."
  type        = string
}

variable "container_port" {
  description = "Port the container listens on. Cloud Run sends it in the PORT variable too."
  type        = number
  default     = 8000
}

variable "health_path" {
  description = "HTTP path for the startup and liveness probes."
  type        = string
  default     = "/health"
}

variable "max_instance_count" {
  description = "Hard cap on instances. A traffic spike queues requests instead of adding servers past this number."
  type        = number

  validation {
    condition     = var.max_instance_count >= 1 && var.max_instance_count <= 20 && floor(var.max_instance_count) == var.max_instance_count
    error_message = "max_instance_count must be a whole number from 1 to 20. Raise the upper bound here on purpose, not by accident."
  }
}

variable "min_instance_count" {
  description = "Instances kept warm. 0 means the service scales to zero and costs nothing while idle."
  type        = number
  default     = 0

  validation {
    condition     = var.min_instance_count >= 0 && var.min_instance_count <= var.max_instance_count
    error_message = "min_instance_count must be between 0 and max_instance_count."
  }
}

variable "cpu" {
  description = "CPU limit per instance."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory limit per instance."
  type        = string
  default     = "512Mi"
}

variable "concurrency" {
  description = "Requests one instance handles at the same time."
  type        = number
  default     = 20
}

variable "request_timeout" {
  description = "Longest a request may take."
  type        = string
  default     = "60s"
}

variable "env" {
  description = "Plain environment variables. Never put a key or password here: use secret_env."
  type        = map(string)
  default     = {}
}

variable "secret_env" {
  description = "Environment variables read from Secret Manager at startup: variable name => secret ID. Only the runtime service account can read these secrets."
  type        = map(string)
  default     = {}
}

variable "public" {
  description = "true lets anyone on the internet call the service (allUsers gets roles/run.invoker)."
  type        = bool
  default     = false
}

variable "invoker_members" {
  description = "Principals allowed to call the service, for example group:testers@example.com. Use `public` for allUsers."
  type        = list(string)
  default     = []

  validation {
    condition     = length(setintersection(toset(var.invoker_members), toset(["allUsers", "allAuthenticatedUsers"]))) == 0
    error_message = "Do not list allUsers or allAuthenticatedUsers here. Set public = true so opening the service is an explicit choice."
  }
}

variable "ingress" {
  description = "Where requests may come from."
  type        = string
  default     = "INGRESS_TRAFFIC_ALL"

  validation {
    condition     = contains(["INGRESS_TRAFFIC_ALL", "INGRESS_TRAFFIC_INTERNAL_ONLY", "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"], var.ingress)
    error_message = "ingress must be INGRESS_TRAFFIC_ALL, INGRESS_TRAFFIC_INTERNAL_ONLY or INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER."
  }
}

variable "deletion_protection" {
  description = "Blocks `terraform destroy` from deleting the service."
  type        = bool
  default     = true
}

variable "vpc_access" {
  description = "Direct VPC egress (private ranges only), needed to reach a private-IP database. null when not used."
  type = object({
    network    = string
    subnetwork = string
  })
  default = null
}

variable "labels" {
  description = "Labels added to the service."
  type        = map(string)
  default     = {}
}
