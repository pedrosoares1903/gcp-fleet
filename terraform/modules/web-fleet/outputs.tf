output "web_instances" {
  description = "Name -> internal IP of every web VM."
  value       = { for name, vm in google_compute_instance.web : name => vm.network_interface[0].network_ip }
}

output "zone" {
  description = "Where the VMs are. The IAP tunnel command needs it."
  value       = var.zone
}