variable "config_root" {
  description = "Path to the environment configuration folders."
  type        = string
  default     = "../config-generated"
}

variable "config_environment" {
  description = "Environment folder under config_root. Defaults to the active Terraform workspace."
  type        = string
  default     = null
  nullable    = true
}
