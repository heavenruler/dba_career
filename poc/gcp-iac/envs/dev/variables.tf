variable "project" {
  default = "lab-service-project-dba"
}

variable "region" {
  default = "asia-east1"
}

variable "subnetwork" {
  default = "projects/lab-host-project-104/regions/asia-east1/subnetworks/lab-dba-subnet"
}

variable "service_account_email" {
  default = "350556399058-compute@developer.gserviceaccount.com"
}

variable "ssh_public_key" {
  description = "SSH public key for root login"
  type        = string
  sensitive   = true
}

variable "disk_size" {
  type    = number
  default = 100
}

variable "root_password" {
  description = "Root password for VM instances"
  type        = string
  sensitive   = true
}
