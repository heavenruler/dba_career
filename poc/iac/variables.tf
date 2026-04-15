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
  default = 16384  # 16 GB in MB
}

variable "vm_disk_size" {
  type    = number
  default = 100  # GB
}
