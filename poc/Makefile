IAC_DIR     := iac
ANSIBLE_DIR := ansible
INVENTORY   := $(ANSIBLE_DIR)/inventory/hosts.ini

.PHONY: help vm-create vm-destroy inventory-refresh ansible-ping ansible-setup

help:
	@echo "Usage:"
	@echo "  make vm-create        - Terraform apply (建立 VM)"
	@echo "  make vm-destroy       - Terraform destroy (刪除 VM)"
	@echo "  make inventory-refresh - 從 Terraform output 重建 hosts.ini"
	@echo "  make ansible-ping     - 重建清單後 ping 所有 VM"
	@echo "  make ansible-setup    - Ansible 執行 site.yml (base 設定)"

## Terraform
vm-create:
	cd $(IAC_DIR) && terraform init -upgrade && terraform apply -auto-approve

vm-destroy:
	cd $(IAC_DIR) && terraform destroy -auto-approve

## Inventory
inventory-refresh:
	cd $(IAC_DIR) && terraform output -json vm_ips | \
	  jq -r '"[poc_db]\n" + (to_entries[] | .value + " ansible_hostname=" + .key)' \
	  > ../$(INVENTORY)
	@echo "==> $(INVENTORY) updated"
	@cat $(INVENTORY)

## Ansible
ansible-ping: inventory-refresh
	cd $(ANSIBLE_DIR) && ansible poc_db -m ping

ansible-setup:
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml
