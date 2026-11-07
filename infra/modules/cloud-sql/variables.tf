variable "project_id" {
  description = "Project that holds the instance."
  type        = string
}

variable "region" {
  description = "Region of the instance. Use the Cloud Run region."
  type        = string
}

variable "name" {
  description = "Instance name. Cloud SQL keeps a deleted name reserved for about a week."
  type        = string
}

variable "network_id" {
  description = "VPC the instance gets a private IP in (projects/<p>/global/networks/<name>). The instance has no public IP."
  type        = string
}

variable "create_private_service_access" {
  description = "Create the private services access range and peering on the VPC. Set false when the VPC already has it."
  type        = bool
  default     = true
}

variable "database_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "POSTGRES_18"
}

variable "tier" {
  description = "Machine size. db-f1-micro is shared-core and has no SLA; pick a db-custom tier for real traffic."
  type        = string
  default     = "db-f1-micro"
}

variable "availability_type" {
  description = "ZONAL (one zone) or REGIONAL (standby in a second zone, about twice the price)."
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "availability_type must be ZONAL or REGIONAL."
  }
}

variable "disk_size_gb" {
  description = "Starting disk size. It grows on its own up to disk_autoresize_limit_gb."
  type        = number
  default     = 10
}

variable "disk_autoresize_limit_gb" {
  description = "Upper bound for automatic disk growth, so storage cost cannot grow without limit."
  type        = number
  default     = 50
}

variable "database_name" {
  description = "Database created for the app."
  type        = string
  default     = "app"
}

variable "runtime_service_account_email" {
  description = "Cloud Run runtime identity. It logs in with IAM database authentication: no password exists."
  type        = string
}

variable "deletion_protection" {
  description = "Blocks deleting the instance from Terraform and from the API."
  type        = bool
  default     = true
}
