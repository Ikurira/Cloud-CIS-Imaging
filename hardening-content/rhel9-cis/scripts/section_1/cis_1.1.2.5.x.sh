#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 1.1.2.5.x - /var/tmp partition options.
SECTION="1"

check_separate_partition_control "1.1.2.5.1" "Ensure separate partition exists for /var/tmp" 2 /var/tmp
check_mount_option_control "1.1.2.5.2" "Ensure nodev option set on /var/tmp partition"  1 /var/tmp nodev
check_mount_option_control "1.1.2.5.3" "Ensure nosuid option set on /var/tmp partition" 1 /var/tmp nosuid
check_mount_option_control "1.1.2.5.4" "Ensure noexec option set on /var/tmp partition" 1 /var/tmp noexec
