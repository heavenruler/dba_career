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

variable "vm_name" {
  type    = string
  default = "l-test-poc-1"
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

variable "vm_ip" {
  type    = string
  default = "172.24.40.32"
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
