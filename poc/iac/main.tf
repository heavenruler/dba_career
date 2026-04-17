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

data "vsphere_virtual_machine" "template" {
  name          = "temp-almalinux-10.1"
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_virtual_machine" "poc" {
  name             = var.vm_name
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

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = var.vm_name
        domain    = var.vm_domain
      }
      network_interface {
        ipv4_address = var.vm_ip
        ipv4_netmask = var.vm_netmask
      }
      ipv4_gateway    = var.vm_gateway
      dns_server_list = [var.vm_dns]
      dns_suffix_list = [var.vm_domain]
    }
  }

  wait_for_guest_net_timeout = 5
  wait_for_guest_ip_timeout  = 5
}

output "vm_name" {
  value = vsphere_virtual_machine.poc.name
}

output "vm_uuid" {
  value = vsphere_virtual_machine.poc.id
}

output "vm_ip" {
  value = vsphere_virtual_machine.poc.default_ip_address
}
