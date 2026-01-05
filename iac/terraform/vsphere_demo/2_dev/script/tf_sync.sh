#!/usr/bin/env bash

hostname_prefix="$1"

vm_list_path="../1_globalConfig/1_vmList_$ENV"
tfstate_path="terraform.tfstate.d"
tfplan_path="terraform.plan.d"
EXEC="$ENV-$hostname_prefix"

mkdir -p $tfplan_path

# Check if parameters are empty
if [ -z "$hostname_prefix" ] || [ -z "$ENV" ]; then
    echo "ENV or hostname_prefix parameters are missing. Please check ececute command."
    exit 1
fi

# 檢查 $vm_list_path 内容是否存在設定
if ! grep -q "$hostname_prefix" "$vm_list_path"; then
    echo "No data found for hostname prefix: $hostname_prefix in $vm_list_path."
    exit 1
fi

resources=$(cat $EXEC.tf | grep '^resource ' | awk -F'"' '{print $2"."$4}' | grep -vi 'anti-affinity')

for resource in $resources; do

    # Execute terraform plan -refresh-only
    echo "Executing plan for resource: $resource"
    terraform plan -refresh-only -compact-warnings -target="$resource" -state="$tfstate_path/$EXEC.tfstate" -state-out="$tfstate_path/$EXEC.tfstate" -out "$tfplan_path/$EXEC.tfplan" -var-file="terraform.tfvars"

    while true; do
        # Confirm whether to execute terraform apply
        echo "You are about to apply the above plan. Type 'yes' to proceed. Any other input will cancel the operation."
        read confirmation

        if [ "$confirmation" = "yes" ]; then
            terraform apply -compact-warnings -refresh-only -state="$tfstate_path/$EXEC.tfstate" -state-out="$tfstate_path/$EXEC.tfstate" "$tfplan_path/$EXEC.tfplan"
            break # Exit the loop after successful execution
        else
            echo "Invalid input. Please type 'yes' to proceed or any other input to skip this resource."
            continue # Re-ask for the same resource
        fi
    done

done

echo "========================================================="
echo "重新執行 make tf_sync 確保已無異動需同步"
echo "對齊 TF State Synced; 務必更新 DSL configuration 內容設定"
echo "========================================================="
