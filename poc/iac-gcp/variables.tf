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
  description = "Primary SSH public key for root login (usually the operator's workstation key)"
  type        = string
  sensitive   = true
}

variable "extra_ssh_public_keys" {
  description = "Additional SSH public keys authorized for root login (e.g. IDC .31 ansible controller). Each entry is a full 'ssh-... AAAA... comment' line."
  type        = list(string)
  default     = []
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
