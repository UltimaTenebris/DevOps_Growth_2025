variable "location" {
  default = "East US"
}

variable "sql_admin_login" {
  description = "Username for SQL Admin"
  default     = "bestrongadmin"
}

variable "sql_admin_password" {
  description = "Password for SQL Admin"
  sensitive   = true # Terraform will redact this in CLI output
}