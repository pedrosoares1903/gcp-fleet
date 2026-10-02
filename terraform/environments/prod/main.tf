module "web_fleet" {
  source = "../../modules/web-fleet"

  project_id  = var.project_id
  environment = "prod"
  zone        = var.zone

  # Created by gcp-baseline. This repository uses them; it does not own them.
  # prod has its own VPC and its own range (10.20.0.0/16), apart from dev's.
  network    = "prod-baseline-vpc"
  subnetwork = "prod-baseline-apps"

  web_count          = 0
  vm_service_account = var.vm_service_account
}

output "web_instances" {
  value = module.web_fleet.web_instances
}

output "zone" {
  value = module.web_fleet.zone
}
