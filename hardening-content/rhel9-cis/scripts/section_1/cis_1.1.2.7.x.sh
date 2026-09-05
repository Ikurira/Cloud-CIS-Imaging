#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 1.1.2.7.x - /var/log/audit partition options.
SECTION="1"

check_separate_partition_control "1.1.2.7.1" "Ensure separate partition exists for /var/log/audit" 2 /var/log/audit
check_mount_option_control "1.1.2.7.2" "Ensure nodev option set on /var/log/audit partition"  1 /var/log/audit nodev
check_mount_option_control "1.1.2.7.3" "Ensure nosuid option set on /var/log/audit partition" 1 /var/log/audit nosuid
check_mount_option_control "1.1.2.7.4" "Ensure noexec option set on /var/log/audit partition" 1 /var/log/audit noexec
