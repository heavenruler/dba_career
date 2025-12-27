#!/usr/bin/env bash

hostname_prefix="$1"

vm_list_path="../1_globalConfig/1_vmList_$ENV"
tfstate_path="terraform.tfstate.d"
tfplan_path="terraform.plan.d"
EXEC="$ENV-$hostname_prefix"

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

#echo "Executing destroy plan for resource"
#terraform plan -destroy -state="$tfstate_path/$EXEC.tfstate" -state-out="$tfstate_path/$EXEC.tfstate" -out "$tfplan_path/$EXEC.tfplan" -var-file="terraform.tfvars"
#echo "Executing apply for resource"
#terraform apply -state="$tfstate_path/$EXEC.tfstate" -state-out="$tfstate_path/$EXEC.tfstate" "$tfplan_path/$EXEC.tfplan"

resources=$(cat $EXEC.tf | grep '^resource ' | awk -F'"' '{print $2"."$4}')

for resource in $resources; do
    echo "Executing destroy plan for resource: $resource"
    terraform plan -compact-warnings -destroy -target="$resource" -state="$tfstate_path/$EXEC.tfstate" -state-out="$tfstate_path/$EXEC.tfstate" -out "$tfplan_path/$EXEC.tfplan" -var-file="terraform.tfvars"
    echo "Executing apply for resource: $resource"
    terraform apply -compact-warnings -state="$tfstate_path/$EXEC.tfstate" -state-out="$tfstate_path/$EXEC.tfstate" "$tfplan_path/$EXEC.tfplan"
done
