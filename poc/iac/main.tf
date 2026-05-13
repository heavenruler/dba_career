provider "vsphere" {
  user                 = var.vsphere_user
  password             = var.vsphere_password
  vsphere_server       = var.vsphere_server
  allow_unverified_ssl = true
}

data "vsphere_datacenter" "dc" {
  name = "sd-datacenter"
}

data "vsphere_compute_cluster" "cluster" {
  name          = "sd-cluster"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "vm_ds" {
  name          = "D1_D_DBA_dev_poc"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = "DBA/VLAN241-172.24.32.0/20"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = "DB-DEV"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_custom_attribute" "attrs" {
  for_each = var.vm_custom_attrs
  name     = each.key
}

data "vsphere_virtual_machine" "template" {
  name          = var.vm_template
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_virtual_machine" "poc" {
  for_each = var.vms

  name             = each.key
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.vm_ds.id

  num_cpus         = var.vm_cpu
  memory           = var.vm_memory
  guest_id         = data.vsphere_virtual_machine.template.guest_id
  firmware         = data.vsphere_virtual_machine.template.firmware
  hardware_version = data.vsphere_virtual_machine.template.hardware_version

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = var.vm_disk_size
    thin_provisioned = true
  }

  dynamic "disk" {
    for_each = data.vsphere_virtual_machine.template.disks.* != null ? range(length(data.vsphere_virtual_machine.template.disks) - 1) : []
    content {
      label            = "disk${disk.key + 1}"
      size             = data.vsphere_virtual_machine.template.disks[disk.key + 1].size
      thin_provisioned = true
      unit_number      = disk.key + 1
    }
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = each.key
        domain    = var.vm_domain
      }
      network_interface {
        ipv4_address = each.value
        ipv4_netmask = var.vm_netmask
      }
      ipv4_gateway    = var.vm_gateway
      dns_server_list = [var.vm_dns]
      dns_suffix_list = [var.vm_domain]
    }
  }

  custom_attributes = {
    for k, v in var.vm_custom_attrs :
    data.vsphere_custom_attribute.attrs[k].id => v
  }

  wait_for_guest_net_timeout = 5
  wait_for_guest_ip_timeout  = 5
}

output "vm_names" {
  value = { for k, v in vsphere_virtual_machine.poc : k => v.name }
}

output "vm_uuids" {
  value = { for k, v in vsphere_virtual_machine.poc : k => v.id }
}

output "vm_ips" {
  value = { for k, v in vsphere_virtual_machine.poc : k => v.default_ip_address }
}
