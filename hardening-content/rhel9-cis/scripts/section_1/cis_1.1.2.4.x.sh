#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 1.1.2.4.x - /var partition options.
SECTION="1"

check_separate_partition_control "1.1.2.4.1" "Ensure separate partition exists for /var" 2 /var
check_mount_option_control "1.1.2.4.2" "Ensure nodev option set on /var partition"  1 /var nodev
check_mount_option_control "1.1.2.4.3" "Ensure nosuid option set on /var partition" 1 /var nosuid
