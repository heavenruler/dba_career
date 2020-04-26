#!/bin/bash

# you need clean or minimal install OS env.

# get rhel7 first.
yum clean all ; yum update ; yum upgrade -y
yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# get mariadb repo config 
# Source Ref: https://downloads.mariadb.com/MariaDB/
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash

# The last supported version of centos7 is mariadb 5.5
sed -i 's/10.4/10.1/' /etc/yum.repos.d/mariadb.repo

# Installing
yum clean all ; yum -y install MariaDB-server MariaDB-shared MariaDB-common

# Checking systemd identify name
systemctl status mariadb

# Disable mariadb running after rebooted
systemctl disable mariadb

# MariaDB Started.
systemctl start mariadb

# Check mariadb status.
systemctl status mariadb