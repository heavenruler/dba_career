# Calculate hugepage reasonable setting on sysctl.conf

_Applicable to OS: centos / ubuntu_

* hugepage 需要設定的系統參數

```
$ cat /etc/sysctl.conf
vm.nr_hugepages = XXXXX
vm.hugetlb_shm_group = 3306 
kernel.shmmax = XXXXX
kernel.shmall = XXXXX
```

* use script: hugepages_counting.sh for calculate

```
#!/bin/bash

# innodb_use_sys_malloc and innodb_additional_mem_pool_size were deprecated in MySQL 5.6 and removed in MySQL 5.7.

if [ `cat /proc/meminfo|grep -i huge|wc -l` -eq 0 ]; then
    echo "/proc/meminfo fail ; check it."
    exit 1;
fi

# Reserve 70% of OS Mem for the innodb_buffer_pool_size.
percent=0.7
systemmem=`free|grep Mem|awk '{print$2}'`
innodb_available_size=$(echo "$percent*$systemmem" | bc) # ref my.cnf innodb_buffer_pool_size
totmem=$(echo "${innodb_available_size%.*}*1024"|bc)
huge=$(grep Hugepagesize /proc/meminfo|awk '{print $2}')

# Set the number of pages to be used.
# Each page is normally 2MB, so a value of 20 = 40MB.
# This command actually allocates memory, so this much
# memory must be available.

all=$(echo "$totmem/$huge"|bc)
hugepages=$(echo "$innodb_available_size/$huge"|bc)

echo "vm.nr_hugepages = $hugepages"
echo "vm.hugetlb_shm_group = `id -g mysql`"
echo "kernel.shmmax = $totmem"
echo "kernel.shmall = $all"
```

* Executing for count

```
$ bash hugepages_counting.sh | tee -a /etc/sysctl.conf
vm.nr_hugepages = XXX
vm.hugetlb_shm_group = 3306
kernel.shmmax = XXX
kernel.shmall = XXX
```

* Make sure my.cnf enabled large-pages 

```
$ cat my.cnf | grep large
large-pages
```

* Restart mysqld & check mysqld.log
