#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 1.1.2.3.x - /home partition options.
SECTION="1"

check_separate_partition_control "1.1.2.3.1" "Ensure separate partition exists for /home" 2 /home
check_mount_option_control "1.1.2.3.2" "Ensure nodev option set on /home partition"  1 /home nodev
check_mount_option_control "1.1.2.3.3" "Ensure nosuid option set on /home partition" 1 /home nosuid
