locals {
  # compute, iam, sts and iamcredentials were enabled by gcp-baseline/bootstrap.
  # These two are new: IAP carries SSH to machines with no public IP, and
  # OS Login decides who may log in using IAM instead of keys copied by hand.
  services = [
    "iap.googleapis.com",
    "oslogin.googleapis.com",
  ]

  # Two pipelines, two identities. The one that CREATES machines cannot log in
  # to them; the one that CONFIGURES them cannot create or delete anything.
  terraform_roles = [
    "roles/compute.instanceAdmin.v1", # create, change, start, stop and delete VMs
    "roles/compute.securityAdmin",    # the firewall rules this repository owns
  ]

  ansible_roles = [
    "roles/compute.viewer",             # list the VMs: the inventory is built from this
    "roles/iap.tunnelResourceAccessor", # open the IAP tunnel to port 22
    "roles/compute.osAdminLogin",       # log in over SSH with sudo
  ]
}

resource "google_project_service" "required" {
  for_each = toset(local.services)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# State bucket for this repository only.
# ---------------------------------------------------------------------------

resource "google_storage_bucket" "state" {
  name     = var.state_bucket_name
  project  = var.project_id
  location = var.region

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# The identity the VMs run as. It has no roles on purpose: nothing running on
# these machines needs to call a Google API. Without it, GCP would attach the
# default compute service account, which holds Editor on the whole project.
# ---------------------------------------------------------------------------

resource "google_service_account" "vm" {
  project      = var.project_id
  account_id   = "fleet-vm"
  display_name = "Fleet VMs"
  description  = "Attached to the web VMs. Deliberately holds no roles."
}

# ---------------------------------------------------------------------------
# GitHub -> Google, no keys. The pool belongs to gcp-baseline; this adds a
# second door to it that only this repository's workflows can use.
# ---------------------------------------------------------------------------

# The pool is referenced by its full name, built from the project NUMBER.
# (There is a data source for pools, but only in the beta provider.)
data "google_project" "this" {
  project_id = var.project_id
}

locals {
  pool_name = "projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${var.workload_identity_pool_id}"
}

resource "google_iam_workload_identity_pool_provider" "fleet" {
  project                            = var.project_id
  workload_identity_pool_id          = var.workload_identity_pool_id
  workload_identity_pool_provider_id = "fleet-gcp"
  display_name                       = "GitHub OIDC - gcp-fleet"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.owner"      = "assertion.repository_owner"
  }

  # Owner AND repository. A token from any other repository is refused here,
  # before any service account is even considered.
  attribute_condition = "assertion.repository_owner == \"${var.github_owner}\" && assertion.repository == \"${var.github_repository}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  depends_on = [google_project_service.required]
}

# --- Terraform pipeline ------------------------------------------------------

resource "google_service_account" "terraform" {
  project      = var.project_id
  account_id   = "fleet-terraform"
  display_name = "Fleet - Terraform CI"
  description  = "Creates and deletes the fleet. Cannot log in to it."
}

resource "google_project_iam_member" "terraform" {
  for_each = toset(local.terraform_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_storage_bucket_iam_member" "terraform_state" {
  bucket = google_storage_bucket.state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.terraform.email}"
}

# --- Ansible pipeline --------------------------------------------------------

resource "google_service_account" "ansible" {
  project      = var.project_id
  account_id   = "fleet-ansible"
  display_name = "Fleet - Ansible CI"
  description  = "Logs in to the fleet and configures it. Cannot create or delete it."
}

resource "google_project_iam_member" "ansible" {
  for_each = toset(local.ansible_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.ansible.email}"
}

# --- Both pipelines need to "act as" the VM identity --------------------------
# Terraform, to attach it to a VM it creates. Ansible, because OS Login refuses
# a login to a VM that runs as a service account the caller cannot act as.
# Granted on this one service account, not on the project.

resource "google_service_account_iam_member" "act_as_vm" {
  for_each = {
    terraform = google_service_account.terraform.email
    ansible   = google_service_account.ansible.email
  }

  service_account_id = google_service_account.vm.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${each.value}"
}

# --- Which workflow may become which identity ---------------------------------

resource "google_service_account_iam_member" "wif" {
  for_each = {
    terraform = google_service_account.terraform.name
    ansible   = google_service_account.ansible.name
  }

  service_account_id = each.value
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${local.pool_name}/attribute.repository/${var.github_repository}"
}