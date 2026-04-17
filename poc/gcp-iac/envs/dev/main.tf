locals {
  instance_configs = {
    0 = { zone = "asia-east1-a", tags = ["zone-a-vm"] }
    1 = { zone = "asia-east1-b", tags = ["zone-b-vm"] }
  }
}

resource "google_compute_instance" "poc" {
  count = 2

  name         = "g-test-poc-${count.index + 1}"
  machine_type = "e2-standard-4"
  zone         = local.instance_configs[count.index].zone
  project      = var.project

  boot_disk {
    auto_delete = true
    device_name = "g-test-poc-${count.index + 1}"

    initialize_params {
      image = "projects/almalinux-cloud/global/images/family/almalinux-10"
      size  = 30
      type  = "pd-standard"
    }

    mode = "READ_WRITE"
  }

  network_interface {
    network_ip = "10.160.152.${count.index + 11}"
    subnetwork = var.subnetwork
  }

  scheduling {
    automatic_restart   = false
    on_host_maintenance = "TERMINATE"
    preemptible         = true
    provisioning_model  = "SPOT"
  }

  service_account {
    email = var.service_account_email
    scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append",
    ]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }

  allow_stopping_for_update = true

  tags = local.instance_configs[count.index].tags

  metadata = {
    ssh-keys       = "root:${var.ssh_public_key}"
    startup-script = <<-EOF
      #!/bin/bash
      STARTUP_DONE="/var/lib/startup-done"
      if [ ! -f "$STARTUP_DONE" ]; then
        sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
        systemctl restart sshd
        touch "$STARTUP_DONE"
      fi
    EOF
  }
}
