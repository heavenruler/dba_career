# 使用說明書

## Origin: https://github.com/diodonfrost/terraform-vsphere-examples

## 確認環境 ; 需要先 init
```
wn.lin@wnlin-mac13 01-basic-server-without-variables % terraform validate                                                                                                     0s
╷
│ Error: Missing required provider
│
│ This configuration requires provider registry.terraform.io/hashicorp/vsphere, but that provider isn't available. You may be able to install it automatically by running:
│   terraform init
╵
```

## 初始化完畢
```
wn.lin@wnlin-mac13 01-basic-server-without-variables % terraform init                                                                                                         0s

Initializing the backend...

Initializing provider plugins...
- Finding latest version of hashicorp/vsphere...
- Installing hashicorp/vsphere v2.2.0...
- Installed hashicorp/vsphere v2.2.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

多了兩個目錄結構版本控制
```
drwxr-xr-x  3 wn.lin  Domain Users    96 12 28 10:45 .terraform
-rw-r--r--  1 wn.lin  Domain Users  1155 12 28 10:45 .terraform.lock.hcl
```

## Plan 確認哪些物件需要被異動
```
wn.lin@wnlin-mac13 01-basic-server-without-variables % terraform plan                                                                                                                                   0s
data.vsphere_datacenter.dc: Reading...
data.vsphere_datacenter.dc: Read complete after 0s [id=datacenter-1008]
data.vsphere_datastore.datastore: Reading...
data.vsphere_network.network: Reading...
data.vsphere_resource_pool.pool: Reading...
data.vsphere_virtual_machine.template: Reading...
data.vsphere_datastore.datastore: Read complete after 0s [id=datastore-1016]
data.vsphere_network.network: Read complete after 0s [id=network-1017]
data.vsphere_resource_pool.pool: Read complete after 0s [id=resgroup-2002]
data.vsphere_virtual_machine.template: Read complete after 1s [id=42318d2f-6683-cea3-e2f7-73598b9ae4ea]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # vsphere_virtual_machine.vm-test will be created
  + resource "vsphere_virtual_machine" "vm-test" {
      + annotation                              = (known after apply)
      + boot_retry_delay                        = 10000
      + change_version                          = (known after apply)
      + cpu_limit                               = -1
      + cpu_share_count                         = (known after apply)
      + cpu_share_level                         = "normal"
      + datastore_id                            = "datastore-1016"
      + default_ip_address                      = (known after apply)
      + ept_rvi_mode                            = "automatic"
      + firmware                                = "bios"
      + force_power_off                         = true
      + guest_id                                = "other4xLinux64Guest"
      + guest_ip_addresses                      = (known after apply)
      + hardware_version                        = (known after apply)
      + host_system_id                          = (known after apply)
      + hv_mode                                 = "hvAuto"
      + id                                      = (known after apply)
      + ide_controller_count                    = 2
      + imported                                = (known after apply)
      + latency_sensitivity                     = "normal"
      + memory                                  = 1024
      + memory_limit                            = -1
      + memory_share_count                      = (known after apply)
      + memory_share_level                      = "normal"
      + migrate_wait_timeout                    = 30
      + moid                                    = (known after apply)
      + name                                    = "vm-test"
      + num_cores_per_socket                    = 1
      + num_cpus                                = 1
      + power_state                             = (known after apply)
      + poweron_timeout                         = 300
      + reboot_required                         = (known after apply)
      + resource_pool_id                        = "resgroup-2002"
      + run_tools_scripts_after_power_on        = true
      + run_tools_scripts_after_resume          = true
      + run_tools_scripts_before_guest_shutdown = true
      + run_tools_scripts_before_guest_standby  = true
      + sata_controller_count                   = 0
      + scsi_bus_sharing                        = "noSharing"
      + scsi_controller_count                   = 1
      + scsi_type                               = "pvscsi"
      + shutdown_wait_timeout                   = 3
      + storage_policy_id                       = (known after apply)
      + swap_placement_policy                   = "inherit"
      + tools_upgrade_policy                    = "manual"
      + uuid                                    = (known after apply)
      + vapp_transport                          = (known after apply)
      + vmware_tools_status                     = (known after apply)
      + vmx_path                                = (known after apply)
      + wait_for_guest_ip_timeout               = 0
      + wait_for_guest_net_routable             = true
      + wait_for_guest_net_timeout              = 5
      + clone {
          + template_uuid = "42318d2f-6683-cea3-e2f7-73598b9ae4ea"
          + timeout       = 30

          + customize {
              + ipv4_gateway = "172.19.1.252"
              + timeout      = 10

              + linux_options {
                  + domain       = "test.local"
                  + host_name    = "vm-test"
                  + hw_clock_utc = true
                }

              + network_interface {
                  + dns_server_list = [
                      + "172.19.254.5",
                    ]
                  + ipv4_address    = "172.19.253.110"
                  + ipv4_netmask    = 16
                }
            }
        }

      + disk {
          + attach            = false
          + controller_type   = "scsi"
          + datastore_id      = "<computed>"
          + device_address    = (known after apply)
          + disk_mode         = "persistent"
          + disk_sharing      = "sharingNone"
          + eagerly_scrub     = false
          + io_limit          = -1
          + io_reservation    = 0
          + io_share_count    = 0
          + io_share_level    = "normal"
          + keep_on_remove    = false
          + key               = 0
          + label             = "vm-test"
          + path              = (known after apply)
          + size              = 30
          + storage_policy_id = (known after apply)
          + thin_provisioned  = true
          + unit_number       = 0
          + uuid              = (known after apply)
          + write_through     = false
        }
      + network_interface {
          + adapter_type          = "vmxnet3"
          + bandwidth_limit       = -1
          + bandwidth_reservation = 0
          + bandwidth_share_count = (known after apply)
          + bandwidth_share_level = "normal"
          + device_address        = (known after apply)
          + key                   = (known after apply)
          + mac_address           = (known after apply)
          + network_id            = "network-1017"
        }
    }

Plan: 1 to add, 0 to change, 0 to destroy.

───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────

Note: You didn't use the -out option to save this plan, so Terraform can't guarantee to take exactly these actions if you run "terraform apply" now.
```

## 套用執行 ; 以範例而言為新增一 VM 從 VMware Template: tbl-almalinux-86
```
wn.lin@wnlin-mac13 01-basic-server-without-variables % terraform apply
data.vsphere_datacenter.dc: Reading...
data.vsphere_datacenter.dc: Read complete after 0s [id=datacenter-1008]
data.vsphere_resource_pool.pool: Reading...
data.vsphere_network.network: Reading...
data.vsphere_datastore.datastore: Reading...
data.vsphere_virtual_machine.template: Reading...
data.vsphere_resource_pool.pool: Read complete after 1s [id=resgroup-2002]
data.vsphere_network.network: Read complete after 1s [id=network-1017]
data.vsphere_datastore.datastore: Read complete after 1s [id=datastore-1016]
data.vsphere_virtual_machine.template: Read complete after 1s [id=42318d2f-6683-cea3-e2f7-73598b9ae4ea]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # vsphere_virtual_machine.vm-test will be created
  + resource "vsphere_virtual_machine" "vm-test" {
      + annotation                              = (known after apply)
      + boot_retry_delay                        = 10000
      + change_version                          = (known after apply)
      + cpu_limit                               = -1
      + cpu_share_count                         = (known after apply)
      + cpu_share_level                         = "normal"
      + datastore_id                            = "datastore-1016"
      + default_ip_address                      = (known after apply)
      + ept_rvi_mode                            = "automatic"
      + firmware                                = "bios"
      + force_power_off                         = true
      + guest_id                                = "other4xLinux64Guest"
      + guest_ip_addresses                      = (known after apply)
      + hardware_version                        = (known after apply)
      + host_system_id                          = (known after apply)
      + hv_mode                                 = "hvAuto"
      + id                                      = (known after apply)
      + ide_controller_count                    = 2
      + imported                                = (known after apply)
      + latency_sensitivity                     = "normal"
      + memory                                  = 1024
      + memory_limit                            = -1
      + memory_share_count                      = (known after apply)
      + memory_share_level                      = "normal"
      + migrate_wait_timeout                    = 30
      + moid                                    = (known after apply)
      + name                                    = "vm-test"
      + num_cores_per_socket                    = 1
      + num_cpus                                = 1
      + power_state                             = (known after apply)
      + poweron_timeout                         = 300
      + reboot_required                         = (known after apply)
      + resource_pool_id                        = "resgroup-2002"
      + run_tools_scripts_after_power_on        = true
      + run_tools_scripts_after_resume          = true
      + run_tools_scripts_before_guest_shutdown = true
      + run_tools_scripts_before_guest_standby  = true
      + sata_controller_count                   = 0
      + scsi_bus_sharing                        = "noSharing"
      + scsi_controller_count                   = 1
      + scsi_type                               = "pvscsi"
      + shutdown_wait_timeout                   = 3
      + storage_policy_id                       = (known after apply)
      + swap_placement_policy                   = "inherit"
      + tools_upgrade_policy                    = "manual"
      + uuid                                    = (known after apply)
      + vapp_transport                          = (known after apply)
      + vmware_tools_status                     = (known after apply)
      + vmx_path                                = (known after apply)
      + wait_for_guest_ip_timeout               = 0
      + wait_for_guest_net_routable             = true
      + wait_for_guest_net_timeout              = 5

      + clone {
          + template_uuid = "42318d2f-6683-cea3-e2f7-73598b9ae4ea"
          + timeout       = 30

          + customize {
              + ipv4_gateway = "172.19.1.252"
              + timeout      = 10

              + linux_options {
                  + domain       = "test.local"
                  + host_name    = "vm-test"
                  + hw_clock_utc = true
                }

              + network_interface {
                  + dns_server_list = [
                      + "172.19.254.5",
                    ]
                  + ipv4_address    = "172.19.253.110"
                  + ipv4_netmask    = 16
                }
            }
        }
      + disk {
          + attach            = false
          + controller_type   = "scsi"
          + datastore_id      = "<computed>"
          + device_address    = (known after apply)
          + disk_mode         = "persistent"
          + disk_sharing      = "sharingNone"
          + eagerly_scrub     = false
          + io_limit          = -1
          + io_reservation    = 0
          + io_share_count    = 0
          + io_share_level    = "normal"
          + keep_on_remove    = false
          + key               = 0
          + label             = "vm-test"
          + path              = (known after apply)
          + size              = 30
          + storage_policy_id = (known after apply)
          + thin_provisioned  = true
          + unit_number       = 0
          + uuid              = (known after apply)
          + write_through     = false
        }

      + network_interface {
          + adapter_type          = "vmxnet3"
          + bandwidth_limit       = -1
          + bandwidth_reservation = 0
          + bandwidth_share_count = (known after apply)
          + bandwidth_share_level = "normal"
          + device_address        = (known after apply)
          + key                   = (known after apply)
          + mac_address           = (known after apply)
          + network_id            = "network-1017"
        }
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes`

vsphere_virtual_machine.vm-test: Creating...
vsphere_virtual_machine.vm-test: Still creating... [10s elapsed]
vsphere_virtual_machine.vm-test: Still creating... [5m50s elapsed]
vsphere_virtual_machine.vm-test: Creation complete after 5m51s [id=4231c055-aaf4-39fc-c4ae-f2923b604c09]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

目錄結構會多了 tfstate 紀錄狀態 ; 因為內含機敏資訊，所以就不 commit 了
```
-rw-r--r--  1 wn.lin  E104TW\Domain Users  12469 12 28 10:56 terraform.tfstate
```

## 執行刪除行為
```
wn.lin@wnlin-mac13 01-basic-server-without-variables % terraform destroy                                                                                                                                                                                                                  0s
data.vsphere_datacenter.dc: Reading...
data.vsphere_datacenter.dc: Read complete after 0s [id=datacenter-1008]
data.vsphere_network.network: Reading...
data.vsphere_resource_pool.pool: Reading...
data.vsphere_datastore.datastore: Reading...
data.vsphere_virtual_machine.template: Reading...
data.vsphere_datastore.datastore: Read complete after 1s [id=datastore-1016]
data.vsphere_network.network: Read complete after 1s [id=network-1017]
data.vsphere_resource_pool.pool: Read complete after 1s [id=resgroup-2002]
data.vsphere_virtual_machine.template: Read complete after 1s [id=42318d2f-6683-cea3-e2f7-73598b9ae4ea]
vsphere_virtual_machine.vm-test: Refreshing state... [id=4231c055-aaf4-39fc-c4ae-f2923b604c09]

Terraform used the selected providers to generate the following execution plan. Resource actions are indicated with the following symbols:
  - destroy

Terraform will perform the following actions:

  # vsphere_virtual_machine.vm-test will be destroyed
  - resource "vsphere_virtual_machine" "vm-test" {
      - boot_delay                              = 0 -> null
      - boot_retry_delay                        = 10000 -> null
      - boot_retry_enabled                      = false -> null
      - change_version                          = "2022-12-28T02:55:27.16462Z" -> null
      - cpu_hot_add_enabled                     = false -> null
      - cpu_hot_remove_enabled                  = false -> null
      - cpu_limit                               = -1 -> null
      - cpu_performance_counters_enabled        = false -> null
      - cpu_reservation                         = 0 -> null
      - cpu_share_count                         = 1000 -> null
      - cpu_share_level                         = "normal" -> null
      - custom_attributes                       = {} -> null
      - datastore_id                            = "datastore-1016" -> null
      - default_ip_address                      = "172.19.253.110" -> null
      - efi_secure_boot_enabled                 = false -> null
      - enable_disk_uuid                        = false -> null
      - enable_logging                          = false -> null
      - ept_rvi_mode                            = "automatic" -> null
      - extra_config                            = {} -> null
      - firmware                                = "bios" -> null
      - force_power_off                         = true -> null
      - guest_id                                = "other4xLinux64Guest" -> null
      - guest_ip_addresses                      = [
          - "172.19.253.110",
          - "fe80::250:56ff:feb1:4edf",
        ] -> null
      - hardware_version                        = 19 -> null
      - host_system_id                          = "host-1013" -> null
      - hv_mode                                 = "hvAuto" -> null
      - id                                      = "4231c055-aaf4-39fc-c4ae-f2923b604c09" -> null
      - ide_controller_count                    = 2 -> null
      - latency_sensitivity                     = "normal" -> null
      - memory                                  = 1024 -> null
      - memory_hot_add_enabled                  = false -> null
      - memory_limit                            = -1 -> null
      - memory_reservation                      = 0 -> null
      - memory_share_count                      = 10240 -> null
      - memory_share_level                      = "normal" -> null
      - migrate_wait_timeout                    = 30 -> null
      - moid                                    = "vm-4005" -> null
      - name                                    = "vm-test" -> null
      - nested_hv_enabled                       = false -> null
      - num_cores_per_socket                    = 1 -> null
      - num_cpus                                = 1 -> null
      - pci_device_id                           = [] -> null
      - power_state                             = "on" -> null
      - poweron_timeout                         = 300 -> null
      - reboot_required                         = false -> null
      - resource_pool_id                        = "resgroup-2002" -> null
      - run_tools_scripts_after_power_on        = true -> null
      - run_tools_scripts_after_resume          = true -> null
      - run_tools_scripts_before_guest_reboot   = false -> null
      - run_tools_scripts_before_guest_shutdown = true -> null
      - run_tools_scripts_before_guest_standby  = true -> null
      - sata_controller_count                   = 0 -> null
      - scsi_bus_sharing                        = "noSharing" -> null
      - scsi_controller_count                   = 1 -> null
      - scsi_type                               = "pvscsi" -> null
      - shutdown_wait_timeout                   = 3 -> null
      - swap_placement_policy                   = "inherit" -> null
      - sync_time_with_host                     = false -> null
      - sync_time_with_host_periodically        = false -> null
      - tags                                    = [] -> null
      - tools_upgrade_policy                    = "manual" -> null
      - uuid                                    = "4231c055-aaf4-39fc-c4ae-f2923b604c09" -> null
      - vapp_transport                          = [] -> null
      - vbs_enabled                             = false -> null
      - vmware_tools_status                     = "guestToolsRunning" -> null
      - vmx_path                                = "vm-test/vm-test.vmx" -> null
      - vvtd_enabled                            = false -> null
      - wait_for_guest_ip_timeout               = 0 -> null
      - wait_for_guest_net_routable             = true -> null
      - wait_for_guest_net_timeout              = 5 -> null

      - clone {
          - linked_clone    = false -> null
          - ovf_network_map = {} -> null
          - ovf_storage_map = {} -> null
          - template_uuid   = "42318d2f-6683-cea3-e2f7-73598b9ae4ea" -> null
          - timeout         = 30 -> null

          - customize {
              - dns_server_list = [] -> null
              - dns_suffix_list = [] -> null
              - ipv4_gateway    = "172.19.1.252" -> null
              - timeout         = 10 -> null

              - linux_options {
                  - domain       = "test.local" -> null
                  - host_name    = "vm-test" -> null
                  - hw_clock_utc = true -> null
                }

              - network_interface {
                  - dns_server_list = [
                      - "172.19.254.5",
                    ] -> null
                  - ipv4_address    = "172.19.253.110" -> null
                  - ipv4_netmask    = 16 -> null
                  - ipv6_netmask    = 0 -> null
                }
            }
        }
      - disk {
          - attach           = false -> null
          - controller_type  = "scsi" -> null
          - datastore_id     = "datastore-1016" -> null
          - device_address   = "scsi:0:0" -> null
          - disk_mode        = "persistent" -> null
          - disk_sharing     = "sharingNone" -> null
          - eagerly_scrub    = false -> null
          - io_limit         = -1 -> null
          - io_reservation   = 0 -> null
          - io_share_count   = 1000 -> null
          - io_share_level   = "normal" -> null
          - keep_on_remove   = false -> null
          - key              = 2000 -> null
          - label            = "vm-test" -> null
          - path             = "vm-test/vm-test.vmdk" -> null
          - size             = 30 -> null
          - thin_provisioned = true -> null
          - unit_number      = 0 -> null
          - uuid             = "6000C294-f4f7-220c-147a-99bb006145ed" -> null
          - write_through    = false -> null
        }

      - network_interface {
          - adapter_type          = "vmxnet3" -> null
          - bandwidth_limit       = -1 -> null
          - bandwidth_reservation = 0 -> null
          - bandwidth_share_count = 50 -> null
          - bandwidth_share_level = "normal" -> null
          - device_address        = "pci:0:7" -> null
          - key                   = 4000 -> null
          - mac_address           = "00:50:56:b1:4e:df" -> null
          - network_id            = "network-1017" -> null
          - use_static_mac        = false -> null
        }
    }

Plan: 0 to add, 0 to change, 1 to destroy.

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

vsphere_virtual_machine.vm-test: Destroying... [id=4231c055-aaf4-39fc-c4ae-f2923b604c09]
vsphere_virtual_machine.vm-test: Still destroying... [id=4231c055-aaf4-39fc-c4ae-f2923b604c09, 10s elapsed]
vsphere_virtual_machine.vm-test: Destruction complete after 11s

Destroy complete! Resources: 1 destroyed.
```

destroy 後目錄結構會新增 terraform.tfstate.backup 檔案結構待還原備用
```
-rw-r--r--   1 wn.lin  E104TW\Domain Users  12469 12 28 11:00 terraform.tfstate.backup
```
