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

data "vsphere_datastore" "iso_ds" {
  name          = "D1_D_DBA_dev_worker"
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

resource "vsphere_virtual_machine" "poc" {
  name             = var.vm_name
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.vm_ds.id

  num_cpus             = var.vm_cpu
  memory               = var.vm_memory
  guest_id             = "almaLinux64Guest"
  firmware             = "efi"
  hardware_version     = 19

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = "vmxnet3"
  }

  disk {
    label            = "disk0"
    size             = var.vm_disk_size
    thin_provisioned = true
  }

  cdrom {
    datastore_id = data.vsphere_datastore.iso_ds.id
    path         = "0_ISO/AlmaLinux-10.1-x86_64-minimal.iso"
  }

  # 不等 VMware Tools（ISO 裝機時尚未安裝）
  wait_for_guest_net_timeout = 0
  wait_for_guest_ip_timeout  = 0
}

output "vm_name" {
  value = vsphere_virtual_machine.poc.name
}

output "vm_uuid" {
  value = vsphere_virtual_machine.poc.id
}
