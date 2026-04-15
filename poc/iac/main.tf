provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}

# Connection test: list datacenters
data "vsphere_datacenter" "all" {}

output "datacenter_id" {
  value = data.vsphere_datacenter.all.id
}
