locals {
  instance_configs = {
    0 = { zone = "asia-east1-a", tags = ["zone-a-vm"] }
    1 = { zone = "asia-east1-b", tags = ["zone-b-vm"] }
    2 = { zone = "asia-east1-c", tags = ["zone-c-vm"] }
    3 = { zone = "asia-east1-a", tags = ["zone-a-vm"] }
  }
}

resource "google_compute_instance" "poc" {
  count = 4

  name         = "g-test-poc-${count.index + 1}"
  machine_type = "e2-standard-4"
  zone         = local.instance_configs[count.index].zone
  project      = var.project

  boot_disk {
    auto_delete = true
    device_name = "g-test-poc-${count.index + 1}"

    initialize_params {
      image = "projects/almalinux-cloud/global/images/family/almalinux-8"
      size  = var.disk_size
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
      set -e
      STARTUP_DONE="/var/lib/startup-done"
      [ -f "$STARTUP_DONE" ] && exit 0

      # Proxy (GCP -> gproxy; dnf 才連得到外網 repo)
      PROXY='http://gproxy.104-dev.com.tw:3128'
      NO_PROXY='localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.104-dev.com.tw'
      export http_proxy=$PROXY HTTPS_PROXY=$PROXY https_proxy=$PROXY HTTP_PROXY=$PROXY
      export no_proxy=$NO_PROXY NO_PROXY=$NO_PROXY
      grep -q '^proxy=' /etc/dnf/dnf.conf || echo "proxy=$PROXY" >> /etc/dnf/dnf.conf
      cat > /etc/profile.d/proxy.sh <<PROXYEOF
      export http_proxy=$PROXY HTTPS_PROXY=$PROXY https_proxy=$PROXY HTTP_PROXY=$PROXY
      export no_proxy=$NO_PROXY NO_PROXY=$NO_PROXY
      PROXYEOF
      chmod 644 /etc/profile.d/proxy.sh

      # SSH: allow root login
      sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
      systemctl restart sshd

      # SELinux / firewalld off
      setenforce 0 || true
      sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
      systemctl disable --now firewalld || true

      # PowerTools + python3.12 (EPEL 留給 ansible 處理；gproxy 不放 fedoraproject metalink)
      dnf config-manager --set-enabled powertools
      dnf -y install python3.12 python3.12-pip
      alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 100
      alternatives --set python3 /usr/bin/python3.12

      # 共通工具 (僅 BaseOS/AppStream，jq/htop 需 EPEL 故略)
      dnf -y install tar gzip rsync unzip lvm2 nmap-ncat bind-utils \
                     git wget tmux vim-enhanced iotop sysstat \
                     policycoreutils-python-utils perl chrony tuned

      systemctl enable --now chronyd
      systemctl enable --now tuned

      dnf clean all
      touch "$STARTUP_DONE"
    EOF
  }
}
