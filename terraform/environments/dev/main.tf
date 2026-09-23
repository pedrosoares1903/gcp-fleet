module "web_fleet" {
  source = "../../modules/web-fleet"

  project_id  = var.project_id
  environment = "dev"
  zone        = var.zone

  # Created by gcp-baseline. This repository uses them; it does not own them.
  network    = "dev-baseline-vpc"
  subnetwork = "dev-baseline-apps"

  web_count          = 2
  vm_service_account = var.vm_service_account
}

output "web_instances" {
  value = module.web_fleet.web_instances
}

output "zone" {
  value = module.web_fleet.zone
}