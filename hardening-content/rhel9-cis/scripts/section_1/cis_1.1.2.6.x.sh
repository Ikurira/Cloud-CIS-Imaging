#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 1.1.2.6.x - /var/log partition options.
SECTION="1"

check_separate_partition_control "1.1.2.6.1" "Ensure separate partition exists for /var/log" 2 /var/log
check_mount_option_control "1.1.2.6.2" "Ensure nodev option set on /var/log partition"  1 /var/log nodev
check_mount_option_control "1.1.2.6.3" "Ensure nosuid option set on /var/log partition" 1 /var/log nosuid
check_mount_option_control "1.1.2.6.4" "Ensure noexec option set on /var/log partition" 1 /var/log noexec
