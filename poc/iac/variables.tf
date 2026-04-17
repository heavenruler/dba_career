variable "vsphere_user" {
  type      = string
  sensitive = true
}

variable "vsphere_password" {
  type      = string
  sensitive = true
}

variable "vsphere_server" {
  type    = string
  default = "sd-vcsa.e104.com.tw"
}

variable "vms" {
  description = "VM name => IPv4 address"
  default = {
    "l-test-poc-1" = "172.24.40.32"
    "l-test-poc-2" = "172.24.40.33"
    "l-test-poc-3" = "172.24.40.34"
  }
}

variable "vm_cpu" {
  type    = number
  default = 4
}

variable "vm_memory" {
  type    = number
  default = 16384
}

variable "vm_disk_size" {
  type    = number
  default = 30
}

variable "vm_netmask" {
  type    = number
  default = 20
}

variable "vm_gateway" {
  type    = string
  default = "172.24.32.1"
}

variable "vm_dns" {
  type    = string
  default = "10.0.1.5"
}

variable "vm_domain" {
  type    = string
  default = "db.104dc-dev.com"
}

variable "vm_custom_attrs" {
  description = "Custom Attributes"
  default = {
    "AZ"            = "AZ_INFRA_DB"
    "BillDomain"    = "unknow1"
    "BillUnit"      = "unknow2"
    "DeveloperOwner" = "unknow3"
    "Group"         = "unknow4"
    "SystemOwner"   = "unknow5"
  }
}
