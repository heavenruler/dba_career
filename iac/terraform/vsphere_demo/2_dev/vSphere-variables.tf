#====================#
# vCenter connection #
#====================#

variable "vsphere_user" {
  description = "vSphere user name"
}

variable "vsphere_password" {
  description = "vSphere password"
}

variable "vsphere_vcenter" {
  description = "vCenter server FQDN or IP"
}

variable "vsphere_unverified_ssl" {
  description = "Is the vCenter using a self signed certificate (true/false)"
}

variable "vsphere_datacenter" {
  description = "vSphere datacenter"
}

variable "vsphere_cluster" {
  description = "vSphere cluster"
  default     = ""
}

variable "vsphere_resource_pool" {
  description = "The Resource Pool of the vSphere firmware type of the machine"
}

variable "vsphere_vm_folder" {
  description = "The VM Folder of the vSphere firmware type of the machine"
}

variable "vsphere_template_folder" {
  description = "The Template Folder of the vSphere firmware type of the machine"
}

#=========================#
# vSphere virtual machine #
#=========================#

variable "vm_datastore_test" {description = "Datastore used for the vSphere virtual machines"}

variable "vm_network" {
  description = "Network used for the vSphere virtual machines"
}

variable "vm_templates" {
  description = "Template used to create the vSphere virtual machines"
  type        = map(string)
  default = {
    db-template = "db-template"
    db-template-u16 = "db-template-u16"
    db-tpl-alma8u10 = "db-template-almalinux-8.10"
#    db-tpl-alma9u7  = "db-template-almalinux-9.7"
  }
}

variable "vm_template" {
  description = "Template used to create the vSphere virtual machines"
}

variable "vm_template2" {
  description = "Template used to create the vSphere virtual machines"
}

variable "vm_template_u16" {
  description = "Template used to create the vSphere virtual machines"
}

variable "vm_linked_clone" {
  description = "Use linked clone to create the vSphere virtual machine from the template (true/false)."
  default = "false"
}

variable "vm_ip" {
  description = "Ip used for the vSpgere virtual machine"
}

variable "vm_netmask" {
  description = "Netmask used for the vSphere virtual machine (example: 24)"
}

variable "vm_gateway" {
  description = "Gateway for the vSphere virtual machine"
}

variable "vm_dns" {
  description = "DNS for the vSphere virtual machine"
}

variable "vm_domain" {
  description = "Domain for the vSphere virtual machine"
}

variable "vm_cpu" {
  description = "Number of vCPU for the vSphere virtual machines"
}

variable "vm_ram" {
  description = "Amount of RAM for the vSphere virtual machines (example: 2048)"
}

variable "vm_name" {
  description = "The name of the vSphere virtual machines and the hostname of the machine"
}

variable "vm_firmware" {
  description = "The name of the vSphere firmware type of the machine"
}
