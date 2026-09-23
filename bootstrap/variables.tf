variable "project_id" {
  description = "The GCP project. The same one gcp-baseline manages."
  type        = string
}

variable "region" {
  description = "Default region for regional resources."
  type        = string
  default     = "europe-west1"
}

variable "github_owner" {
  description = "GitHub account that owns this repository."
  type        = string
}

variable "github_repository" {
  description = "This repository, in owner/name form. Only its workflows can use the identities created here."
  type        = string
}

variable "state_bucket_name" {
  description = <<-EOT
    Globally unique name for THIS repository's state bucket.
    It is deliberately not the gcp-baseline bucket: the fleet pipeline must not
    be able to read or overwrite the network's state.
  EOT
  type        = string
}

variable "workload_identity_pool_id" {
  description = "The pool created by gcp-baseline/bootstrap. This repository adds a provider to it; it does not own it."
  type        = string
  default     = "github"
}