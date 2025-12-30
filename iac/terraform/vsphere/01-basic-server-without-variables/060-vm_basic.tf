# Basic configuration withour variables

# Define authentification configuration
provider "vsphere" {
  # If you use a domain set your login like this "MyDomain\\MyUser"
  user           = "username"
  password       = "password"
  vsphere_server = "${VC_IP}"

  # if you have a self-signed cert
  allow_unverified_ssl = true
}

#### RETRIEVE DATA INFORMATION ON VCENTER ####

data "vsphere_datacenter" "dc" {
#  name = "my-litle-datacenter"
  name = "DC"
}

data "vsphere_resource_pool" "pool" {
  # If you haven't resource pool, put "Resources" after cluster name
#  name          = "my-litle-cluster/Resources"
  name          = "HA/Resources"
  datacenter_id = data.vsphere_datacenter.dc.id
}

#data "vsphere_host" "host" {
#  name          = "vCenter-1"
#  datacenter_id = data.vsphere_datacenter.dc.id
#}

# Retrieve datastore information on vsphere
data "vsphere_datastore" "datastore" {
#  name          = "my-litle-datastore"
  name          = "vmware_pool"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Retrieve network information on vsphere
data "vsphere_network" "network" {
  name          = "VM Network"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Retrieve template information on vsphere
data "vsphere_virtual_machine" "template" {
  name          = "tbl-almalinux-86"
  datacenter_id = data.vsphere_datacenter.dc.id
}

#### VM CREATION ####

# Set vm parameters
resource "vsphere_virtual_machine" "vm-test" {
  name             = "vm-test"
  num_cpus         = 1
  memory           = 1024
  datastore_id     = data.vsphere_datastore.datastore.id
#  host_system_id   = data.vsphere_host.host.id
  resource_pool_id = data.vsphere_resource_pool.pool.id
  guest_id         = data.vsphere_virtual_machine.template.guest_id
  scsi_type        = data.vsphere_virtual_machine.template.scsi_type

  # Set network parameters
  network_interface {
    network_id = data.vsphere_network.network.id
  }

  # Use a predefined vmware template has main disk
  disk {
	label = "vm-test"
#    name = "vm-test.vmdk" # An argument named "name" is not expected here.
    size = "30"
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = "vm-test"
        domain    = "test.local"
      }

      network_interface {
        ipv4_address    = "172.19.253.110"
        ipv4_netmask    = 16
        dns_server_list = ["172.19.254.5"]
      }

      ipv4_gateway = "172.19.1.252"
    }
  }

#  # Execute script on remote vm after this creation
#  provisioner "remote-exec" {
#    script = "scripts/example-script.sh"
#    connection {
#      type     = "ssh"
#      user     = "username"
#      password = "password"
#      host     = "192.168.1.254"
#    }
#  }
}

