output "host_ip_mapping" {
  description = "Mapping of hostname to internal IP"
  value = {
    for instance in google_compute_instance.poc :
    instance.name => instance.network_interface[0].network_ip
  }
}
