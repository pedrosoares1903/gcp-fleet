variable "project_id" {
  description = "Project this environment is created in."
  type        = string
}

variable "region" {
  description = "Region of the provider. The VMs themselves go in var.zone."
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "Zone for the VMs."
  type        = string
  default     = "europe-west1-b"
}

variable "vm_service_account" {
  description = "The vm_service_account output of bootstrap/."
  type        = string
}