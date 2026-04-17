IAC_DIR     := iac
GCP_IAC_DIR := gcp-iac/envs/dev
ANSIBLE_DIR := ansible
INVENTORY   := $(ANSIBLE_DIR)/inventory/hosts.ini

.PHONY: help \
        apply-all destroy-all \
        vm-create vm-destroy inventory-refresh ansible-ping ansible-setup \
        gcp-create gcp-destroy gcp-tunnel-start gcp-tunnel-stop gcp-tunnel-ensure \
        gcp-inventory-refresh inventory-refresh-all \
        tidb-deploy

help:
	@echo "=== Global ==="
	@echo "  make apply-all              - 建立全部 VM (vSphere + GCP)"
	@echo "  make destroy-all            - 刪除全部 VM (vSphere + GCP)"
	@echo ""
	@echo "=== vSphere ==="
	@echo "  make vm-create              - Terraform apply (建立 VM)"
	@echo "  make vm-destroy             - Terraform destroy (刪除 VM)"
	@echo "  make inventory-refresh      - 從 Terraform output 重建 vSphere hosts.ini"
	@echo ""
	@echo "=== GCP ==="
	@echo "  make gcp-create             - Terraform apply (建立 GCP VM)"
	@echo "  make gcp-destroy            - Terraform destroy (刪除 GCP VM)"
	@echo "  make gcp-tunnel-start       - 啟動 IAP SSH tunnels"
	@echo "  make gcp-tunnel-stop        - 關閉 IAP SSH tunnels"
	@echo "  make gcp-inventory-refresh  - 從 Terraform output 重建 GCP hosts.ini"
	@echo ""
	@echo "=== Ansible ==="
	@echo "  make ansible-ping           - 重建全部清單 + 確認 tunnel + ping 所有 VM"
	@echo "  make ansible-setup          - 執行 site.yml (base 設定)"
	@echo ""
	@echo "=== TiDB ==="
	@echo "  make tidb-deploy            - 部署 TiDB cluster (tidb.yml)"

## Global
apply-all:
	$(MAKE) -j2 vm-create gcp-create
	@echo "==> All VMs created"

destroy-all:
	$(MAKE) -j2 vm-destroy gcp-destroy
	@echo "==> All VMs destroyed"

## vSphere Terraform
vm-create:
	cd $(IAC_DIR) && terraform init -upgrade && terraform apply -auto-approve

vm-destroy:
	cd $(IAC_DIR) && terraform destroy -auto-approve

## vSphere Inventory
inventory-refresh:
	cd $(IAC_DIR) && terraform output -json vm_ips | \
	  jq -r '"[poc_db]", (to_entries[] | .value + " ansible_hostname=" + .key)' \
	  > ../$(INVENTORY)
	@echo "==> $(INVENTORY) updated"
	@cat $(INVENTORY)

## vSphere Ansible
ansible-ping: inventory-refresh-all gcp-tunnel-ensure
	cd $(ANSIBLE_DIR) && ansible all -m ping

ansible-setup:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml

## GCP Terraform
gcp-create:
	cd $(GCP_IAC_DIR) && terraform init -upgrade && terraform apply -auto-approve

gcp-destroy:
	cd $(GCP_IAC_DIR) && terraform destroy -auto-approve

## GCP IAP Tunnel
gcp-tunnel-start:
	@$(GCP_IAC_DIR)/tunnel.sh start

gcp-tunnel-stop:
	@$(GCP_IAC_DIR)/tunnel.sh stop

gcp-tunnel-ensure:
	@if ! lsof -i :12211 | grep -q LISTEN 2>/dev/null; then \
	  echo "==> IAP tunnel not running, starting..."; \
	  $(GCP_IAC_DIR)/tunnel.sh start; \
	else \
	  echo "==> IAP tunnel already running"; \
	fi

## GCP Inventory
gcp-inventory-refresh:
	cd $(GCP_IAC_DIR) && terraform output -json host_ip_mapping | \
	  jq -r '"[gcp_poc]", (to_entries[] | .key + " ansible_host=localhost ansible_port=" + (if .key == "g-test-poc-1" then "12211" else "12212" end) + " ansible_hostname=" + .key)' \
	  >> ../../../$(INVENTORY)
	@echo "==> GCP section appended to $(INVENTORY)"

## Combined Inventory (vSphere overwrite → GCP append)
inventory-refresh-all: inventory-refresh gcp-inventory-refresh
	@echo "==> Final inventory:"
	@cat $(INVENTORY)

## TiDB
tidb-deploy: gcp-tunnel-ensure
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/tidb.yml \
	  -i inventory/hosts.ini \
	  -i inventory/tidb.ini
