variable "project_id" {
  description = "Project the fleet is created in."
  type        = string
}

variable "environment" {
  description = "dev or prod. Prefix of every name, and the value of the `env` label Ansible groups by."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod."
  }
}

variable "zone" {
  description = "Zone for the VMs. All of them live in one zone to keep this simple."
  type        = string
}

variable "network" {
  description = "Name of the VPC created by gcp-baseline, for example dev-baseline-vpc."
  type        = string
}

variable "subnetwork" {
  description = "Name of the subnet created by gcp-baseline, for example dev-baseline-apps."
  type        = string
}

variable "web_count" {
  description = <<-EOT
    How many web VMs. They are named <env>-web-01, <env>-web-02, ...
    Lowering the number deletes the ones with the highest suffix, and only those.
  EOT
  type        = number
  default     = 2

  validation {
    condition     = var.web_count >= 0 && var.web_count <= 5
    error_message = "web_count must be between 0 and 5. This is a free-trial project."
  }
}

variable "machine_type" {
  description = "e2-micro is the smallest shared-core type; nginx and apt fit in it."
  type        = string
  default     = "e2-micro"
}

variable "image" {
  description = "Boot image. Debian ships Python 3, which is all Ansible needs on the target."
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "vm_service_account" {
  description = "Email of the fleet-vm service account created by bootstrap/."
  type        = string
}