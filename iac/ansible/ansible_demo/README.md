# DBA Ansible Semaphore Intro

## Reference

[Semaphore UI Official](https://www.ansible-semaphore.com/)
[Semaphore Github](https://github.com/semaphore-protocol/semaphore)

## 環境資訊 (使用 root policy 登入)

[Semaphore](http://localhost/project/)

## 目標

- Automation
- Infrastructure as code (IaC)
- Version Control & Review
- Enhance Workflow & Approval
- Get started with Ansible

## 架構
                             +--------------------------------------+
                             |                 Users                |
                             |             （DBA Users）             |
                             +--------------------------------------+
                                        |
                                        | HTTP/HTTPS
                                        |
                             +--------------------------------------+
                             |            Semaphore Web UI          |
                             | （DBA Ansible Semaphore Endpoint）    |
                             +--------------------------------------+
                                        |
                                        | API Calls
                                        |
                             +--------------------------------------+
                             |      Semaphore Backend Server        |
                             | （執行 playbook 的 Control Machine）   |
                             |                                      |
                             | +------------------+                 |
                             | |    Task Queue    |                 |
                             | |                  |                 |
                             | | - 單次執行         |                 |
                             | | - cron 定期執行    |                 |
                             | +------------------+                 |
                             +--------------------------------------+
                                        |
                                        | DB Calls
                                        |
                             +--------------------------------------+
                             |                Database              |
                             | （存放相關資料的儲存載體，Data 與         |
                             |              Execute 抽離）           |
                             +--------------------------------------+
                                        |
                                        |
                             +----------------------------------------+
                             |            Ansible Playbooks           |
                             |              （執行腳本）                |
                             |            滿足版本控制                  |
                             |       Github Repo: ansible              |
                             +----------------------------------------+
                                        |
                                        | SSH Calls
                                        |
                             +----------------------------------------+
                             |             Target Hosts               |
                             |             （被控制節點）               |
                             +----------------------------------------+

### 各環境目前資源資訊

| Semaphore Backend Server | IP Address       |
| ------------------------ | ---------------- |
| Lab                      | 192.168.1.1:80 |


| Semaphore Database | IP Address          |
| ------------------ |:------------------- |
| Lab                | 192.168.1.1:3306 |

## Ansible Semaphore 功能架構
- Dashboard
- Task Templates
    - Maintenance
    - Health Check
    - Installation
        - Service Type
    - Configuration
        - OS Basic Environment
    - Modify & Deployment
    - Backup
    - DBOP Maintenance Execution
- Inventory
    - Auto Update Host List & Host Group
- Environment (Snigle Environment Only)
- Key Store
    - Github
    - SSH login
- Repositories
- Team

## Database: semaphore

- Schema
```
+----------------------+
| Tables_in_semaphore  |
+----------------------+
| access_key           |
|:-------------------- |
| event                |
| event_backup_5784568 |
| migrations           |
| project              |
| project__environment |
| project__inventory   |
| project__repository  |
| project__schedule    |
| project__template    |
| project__user        |
| project__view        |
| session              |
| task                 |
| task__output         |
| user                 |
| user__token          |
+----------------------+
```

- access_key
```
MariaDB [semaphore]> select * from access_key;
+----+-----------+----------------+------------+----------------------------------------------------------------------------------------------------------------------------------------------+
| id | name      | type           | project_id | secret                                                                                                                                       |
+----+-----------+----------------+------------+----------------------------------------------------------------------------------------------------------------------------------------------+
|  1 | ssh login | login_password |          1 | {FIXME}|
|  2 | github    | login_password |          1 | {FIXME}|
+----+-----------+----------------+------------+----------------------------------------------------------------------------------------------------------------------------------------------+
2 rows in set (0.000 sec)
```

- project__inventory # 可由外部更新清單實作更新 inventory 需求
```
MariaDB [semaphore]> select * from project__inventory;
+----+------------+--------+---------------------------------------------------------+------------+------+---------------+
| id | project_id | type   | inventory                                               | ssh_key_id | name | become_key_id |
+----+------------+--------+---------------------------------------------------------+------------+------+---------------+
|  1 |          1 | static | 192.168.1.1                                             |          1 | Dev  |             1 |
+----+------------+--------+---------------------------------------------------------+------------+------+---------------+
1 row in set (0.000 sec)
```

## Github Repo: ansible 架構

### for now
```
.
├── Makefile
├── README.md
└── env
    ├── 0_dev
        └── playbooks
            ├── 0_general
            ├── 1_testing
            └── 2_roles
```

### for future
```
.
├── Makefile
├── README.md
└── env
    ├── 0_dev
    │   └── playbooks
    │       ├── 0_general -> playbooks.yml
    │       └── 1_testing -> playbooks.yml
    └── roles
    │   ├── global/role1/tasks/main.yml
    │   ├── lab/role2/tasks/main.yml
    │   ├── staging/role2/tasks/main.yml
    │   └── ...
    └── service_install_for_ansible_semaphore (playbook for rebuild or extend Ansible Controller)
        ├── files
        │   ├── ansible.cfg
        │   └── config.json
        └── service_install_for_ansible_semaphore.yml
```

## 開發規範 (Ansible-lint)

Ansible Playbooks 和 Roles 變得越來越複雜時，維持開發品質和一致性變得尤為重要。

### 已知開發規範

- 使用 global vars / files / roles 進行開發，因為各環境呼叫 roles 執行一致性
- 機敏檔案及資訊使用 ansible-vault 封裝後 commit ; 避免在 playbook 及任何 config 留下機敏資訊
- Binany files 超過 50MB 無法 commit 進 github ; 故 Binary 大檔案放置 S3 進行下載取用
- 相關設定檔案由 files 統一控管及部署
- 系統初始化部署可於 playbook (EX: role: basic_config_for_os) 建立 reboot task / 但 Service 層級嚴禁執行 reboot task ; 避免不必要的 reboot 操作在線上設備發生

### 理想 Devleper Rules
- Coding Style
- 使用標籤
- 使用一致的空格縮進
- 任務、角色、變量和角色的語義化命名
- 目錄結構
- 執行的風格
- pre-check 語法 # ansible lint
- 列出執行主機
- 列出 Tasks 任務
- Tasks Execute
- 一個很好的 [openshift-ansible 風格](https://github.com/openshift/openshift-ansible/blob/master/docs/style_guide.adoc)
- Commit to Github
- Inventory from *.localhost

### 目的
- 設定開發品質:
    Ansible lint 會檢查代碼中的問題和不一致性，這有助於提高 Playbooks 和 Roles 的質量。
    
- 確保一致性:
    在多人協作的項目中，保持一致的編碼標準是很重要的。Ansible lint 可以幫助開發者遵循給定的編碼規範。
    
- 提高可讀性:
    良好的編碼慣例可以提高代碼的可讀性，使其他開發者更容易理解和維護。
    
- 自動化:
    Ansible lint 可以集成到 CI/CD 流程中，自動檢查每次提交的 Playbooks 和 Roles，確保它們符合項目的標準。
    
- 發現潛在問題:
    有時候，某些寫法可能會導致運行時的問題或不可預見的行為。linting 工具可以提前發現這些問題，避免它們出現在生產環境中。

## 目前待處理問題

- role for global
    - 統一通用的 roles 在不同 env 的 playbook.yml 上套用的執行方式
- role for env
    - 獨立不同 env 的 roles 目錄結構
- var for env
    - 寫在 playbook.yml
    - 寫在外部參數
- dyn static config
    - my.cnf 的動態/靜態設定拆解
- ececute notifycation
    - 可調整的 Ansible 執行紀錄通知
        - notify by role
        - notify by semaphore.event or semaphore.task

## 開發進度項目
- (-) Collector DB Subnet Info ; Update to Github & semaphore.inventory
- (-) test import global role
- (V) variables include test
- (V) Notifycation

# Backlog

## 機敏資訊能 Commit 進 Github 嗎？ # Ansible-Vault

Encrypt
```
ansible-vault create secure.out
ansible-vault edit secure.out
```
Decrypt
```
ansible-vault decrypt secure.out
```

在 Playbooks 內取用機敏資訊
```
  tasks:
    - name: Include encrypted vars
      ansible.builtin.include_vars: secure.out

    - name: Print decrypted content
      ansible.builtin.debug:
        var: decrypted_content
```

需要在 Ansible Semaphore 解密檔案如何設定
![](https://hackmd.io/_uploads/HJBg9E4a3.png)

## Semaphore Upgrade in-place
```
$ wget https://github.com/ansible-semaphore/semaphore/releases/download/v2.8.92/semaphore_2.8.92_linux_amd64.rpm
$ yum install semaphore_2.8.92_linux_amd64.rpm
$ semaphore version
$ semaphore server --config /root/config.json &
```

## 開發常用指令

- upgrade ansible-lint
```
pip install --upgrade ansible-lint
```
