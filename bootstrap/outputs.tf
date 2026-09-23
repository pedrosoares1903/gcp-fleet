output "workload_identity_provider" {
  description = "GitHub variable WIF_PROVIDER."
  value       = google_iam_workload_identity_pool_provider.fleet.name
}

output "terraform_service_account" {
  description = "GitHub variable TF_SERVICE_ACCOUNT."
  value       = google_service_account.terraform.email
}

output "ansible_service_account" {
  description = "GitHub variable ANSIBLE_SERVICE_ACCOUNT."
  value       = google_service_account.ansible.email
}

output "vm_service_account" {
  description = "Goes into terraform/environments/*/terraform.tfvars."
  value       = google_service_account.vm.email
}

output "state_bucket" {
  description = "Hardcode into every terraform/environments/*/backend.tf."
  value       = google_storage_bucket.state.name
}