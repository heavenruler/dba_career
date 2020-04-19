#!/bin/bash

# you need clean or minimal install OS env.

# get rhel7 first.
yum clean all ; yum update ; yum upgrade -y
yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# get mariadb repo config 
# Source Ref: https://downloads.mariadb.com/MariaDB/
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash

