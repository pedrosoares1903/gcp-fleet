locals {
  # dev-web-01, dev-web-02, ... Keyed by name, so removing the last one removes
  # exactly that one and never renumbers the others.
  web_names = toset([
    for i in range(var.web_count) : format("%s-web-%02d", var.environment, i + 1)
  ])

  # IAP's source range. Same value gcp-baseline uses for SSH.
  iap_range = "35.235.240.0/20"

  # The network tag every rule in this module targets. gcp-baseline's SSH rule
  # targets "ssh-via-iap"; the VMs carry both.
  tag = "${var.environment}-fleet-web"
}

# ---------------------------------------------------------------------------
# The VMs. Terraform creates the machine; everything INSIDE it is Ansible's.
# ---------------------------------------------------------------------------

resource "google_compute_instance" "web" {
  for_each = local.web_names

  project      = var.project_id
  name         = each.key
  zone         = var.zone
  machine_type = var.machine_type

  # The bridge to Ansible. The inventory plugin reads these labels and turns
  # them into groups: env=dev -> env_dev, tier=web -> tier_web.
  labels = {
    env        = var.environment
    tier       = "web"
    managed_by = "terraform"
  }

  tags = ["ssh-via-iap", local.tag]

  boot_disk {
    initialize_params {
      image = var.image
      size  = 10
      # pd-standard: ~0.40 USD/month for 10 GB, and it is billed even while the
      # VM is stopped. pd-balanced would be 2.5x that for speed nobody needs here.
      type = "pd-standard"
    }
  }

  network_interface {
    subnetwork         = var.subnetwork
    subnetwork_project = var.project_id
    # No access_config block = no public IP. The only way in is IAP.
  }

  service_account {
    email  = var.vm_service_account
    scopes = ["cloud-platform"]
  }

  metadata = {
    # Who may log in is decided by IAM, not by keys pasted into metadata.
    enable-oslogin = "TRUE"
    # And project-wide keys, if anyone ever adds one, are ignored here.
    block-project-ssh-keys = "true"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  # A machine type change needs the VM stopped. Without this, Terraform refuses
  # the change instead of doing it.
  allow_stopping_for_update = true

  # `desired_status` is deliberately NOT set: starting and stopping is done by
  # the power workflow, and Terraform must not fight it on the next plan.
}

# ---------------------------------------------------------------------------
# Firewall rules owned by this repository. They live in gcp-baseline's VPC
# but only apply to VMs carrying this module's tag.
# ---------------------------------------------------------------------------

resource "google_compute_firewall" "allow_http_from_iap" {
  project     = var.project_id
  name        = "${var.environment}-fleet-allow-http-from-iap"
  network     = var.network
  description = "Port 80 through an IAP tunnel, to look at the site with no public IP."
  direction   = "INGRESS"
  priority    = 1000

  source_ranges = [local.iap_range]
  target_tags   = [local.tag]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_firewall" "allow_egress_web" {
  project     = var.project_id
  name        = "${var.environment}-fleet-allow-egress-web"
  network     = var.network
  description = "apt needs HTTP and HTTPS out. Beats gcp-baseline's deny-all-egress (priority 65000)."
  direction   = "EGRESS"
  priority    = 1000

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = [local.tag]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  log_config {
    metadata = "EXCLUDE_ALL_METADATA"
  }
}