.PHONY: default
default: help


# 說明:
# 這個 Makefile 提供一組命令，用於管理不同階段的部署過程。
# make & make help 目標提供每個命令的使用說明和解釋。

# 命令詳情:
# - 'pull': 從儲存庫中獲取最新的變更。
# - 'init': 初始化環境並準備使用給定的主機名前綴。
# - 'plan': 生成基礎設施變更的執行計劃。
# - 'apply': 應用計劃中的基礎設施變更。
# - 'destroy': 摧毀基礎設施。
# - 'commit': 將變更提交到儲存庫中。
# - 'tf_sync': 對齊 vSphere 資源狀態。

# 注意:
# - 環境變數 'ENV' 應設置為 'dev'、'staging'、'prod' 或 'drsite' 中的一個。
# - 'hostname_prefix' 參數指定環境設置期間的主機名前綴。

# 範例用法:
# - 初始化開發環境:           'make init ; export ENV=dev; make prepare hostname_prefix=dbhvm'
# - 生成開發環境的執行計劃:   'export ENV=dev; make plan hostname_prefix=dbhvm'
# - 應用開發環境中的變更:     'export ENV=dev; make apply hostname_prefix=dbhvm'
# - 摧毀開發環境:             'export ENV=dev; make destroy hostname_prefix=dbhvm'
# - 交付目前 TF 狀態:         'make commit'

help:
	@echo "用法: ENV=(dev/staging/prod/drsite)"
	@echo ""
	@echo "  make pull"
	@echo "      更新現有 Repo & TF State"
	@echo ""
	@echo "  make init"
	@echo "      初始化 Terraform 環境設定"
	@echo ""
	@echo "  export ENV=dev; make prepare hostname_prefix=<dbhvm>"
	@echo "      建立 Terraform 資源設定。"
	@echo ""
	@echo "  export ENV=dev; make plan hostname_prefix=<dbhvm>"
	@echo "      設定環境變數 'ENV' 為 'dev'，生成基於指定主機名前綴的基礎設施變更執行計劃。"
	@echo ""
	@echo "  export ENV=dev; make apply hostname_prefix=<dbhvm>"
	@echo "      設定環境變數 'ENV' 為 'dev'，應用計劃中的基礎設施變更，使用指定的主機名前綴。"
	@echo ""
	@echo "  export ENV=dev; make destroy hostname_prefix=<dbhvm>"
	@echo "      設定環境變數 'ENV' 為 'dev'，移除 Resource ，使用指定的主機名前綴。"
	@echo ""
	@echo "  make commit"
	@echo "      交付所有變更"
	@echo ""
	@echo "  == 同步差異區塊 (DSL configuration: 永遠不會被更新 ; 但差異可以被偵測) =="
	@echo ""
	@echo "  export ENV=dev; make tf_sync hostname_prefix=<dbhvm>"
	@echo "      將 vSphere Resource state 同步回 Local TF State"

pull:
	@git pull -v

commit:
	@cd ../2_dev ; grep -Ev '^\s*vsphere_user\s*=' terraform.tfvars > terraform.tfvars.tmp; \
	grep -Ev '^\s*vsphere_password\s*=' terraform.tfvars.tmp > terraform.tfvars; \
	rm -f terraform.tfvars.tmp; \
	echo 'vsphere_password = "XXXvsphere_passXXX"' | cat - terraform.tfvars > temp && mv temp terraform.tfvars; \
	echo 'vsphere_user = "XXXvsphere_userXXX"' | cat - terraform.tfvars > temp && mv temp terraform.tfvars; \
	echo "Default parameters restored in 2_devterraform.tfvars";
	@cd ../3_staging ; grep -Ev '^\s*vsphere_user\s*=' terraform.tfvars > terraform.tfvars.tmp; \
	grep -Ev '^\s*vsphere_password\s*=' terraform.tfvars.tmp > terraform.tfvars; \
	rm -f terraform.tfvars.tmp; \
	echo 'vsphere_password = "XXXvsphere_passXXX"' | cat - terraform.tfvars > temp && mv temp terraform.tfvars; \
	echo 'vsphere_user = "XXXvsphere_userXXX"' | cat - terraform.tfvars > temp && mv temp terraform.tfvars; \
	echo "Default parameters restored in 3_staging/terraform.tfvars";
	@cd ../4_prod ; grep -Ev '^\s*vsphere_user\s*=' terraform.tfvars > terraform.tfvars.tmp; \
	grep -Ev '^\s*vsphere_password\s*=' terraform.tfvars.tmp > terraform.tfvars; \
	rm -f terraform.tfvars.tmp; \
	echo 'vsphere_password = "XXXvsphere_passXXX"' | cat - terraform.tfvars > temp && mv temp terraform.tfvars; \
	echo 'vsphere_user = "XXXvsphere_userXXX"' | cat - terraform.tfvars > temp && mv temp terraform.tfvars; \
	echo "Default parameters restored in 4_prod/terraform.tfvars";
	@cd ../5_drsite ; grep -Ev '^\s*vsphere_user\s*=' terraform.tfvars > terraform.tfvars.tmp; \
	grep -Ev '^\s*vsphere_password\s*=' terraform.tfvars.tmp > terraform.tfvars; \
	rm -f terraform.tfvars.tmp; \
	echo 'vsphere_password = "XXXvsphere_passXXX"' | cat - terraform.tfvars > temp && mv temp terraform.tfvars; \
	echo 'vsphere_user = "XXXvsphere_userXXX"' | cat - terraform.tfvars > temp && mv temp terraform.tfvars; \
	echo "Default parameters restored in 5_drsite/terraform.tfvars";
	cd .. ; git add . ; git commit -m "commit update" ; git push

init:
	@if [ ! -L ../.git/hooks/pre-commit ]; then \
		ln -s `pwd`/../a_githook/pre-commit `pwd`/../.git/hooks; \
	fi
	@rm -fr terraform.plan.d/*
	@terraform init
	make pull
	make check_repoSync
	make check_credentials

check_repoSync:
	@LOCAL=$$(git rev-parse main); \
	REMOTE=$$(git rev-parse origin/main); \
	if [ "$$LOCAL" = "$$REMOTE" ]; then \
		echo "Local Repo fresh checked."; \
	else \
		echo "Local Repo 狀態已過時，請確保 local commit pushed 及 Pull Repo 至最新狀態"; \
	fi

check_credentials:
	@if [ -f ~/.credential ]; then \
		grep -Ev '^\s*vsphere_user\s*=' terraform.tfvars > terraform.tfvars.tmp; \
		grep -Ev '^\s*vsphere_password\s*=' terraform.tfvars.tmp > terraform.tfvars; \
		rm -f terraform.tfvars.tmp; \
		echo "Credentials check complete."; \
		cat ~/.credential | cat - terraform.tfvars > temp && mv temp terraform.tfvars; \
	else \
		echo "~/.credential not found. Try to fill Content."; \
		echo "-----------------------------------------------"; \
		echo "echo 'vsphere_user = \"username\"' > ~/.credential"; \
		echo "echo 'vsphere_password = \"password\"' >> ~/.credential"; \
	fi

prepare:
	@if [ $$(uname) == "Darwin" ]; then \
		./script/prepareTFConfig.sh $(hostname_prefix); \
	else \
		./script/prepareTFConfig.linux.sh $(hostname_prefix); \
	fi

plan:
	@./script/planTFConfig.sh $(hostname_prefix)

destroy:
	@./script/destroyTFConfig.sh $(hostname_prefix)

apply:
	@./script/applyTFConfig.sh $(hostname_prefix)

tf_sync:
	@./script/tf_sync.sh $(hostname_prefix)
