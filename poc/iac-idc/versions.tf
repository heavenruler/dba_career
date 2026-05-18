terraform {
  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = "~> 2.12"
    }
  }
  required_version = ">= 1.5"
}
