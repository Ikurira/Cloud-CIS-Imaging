#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 1.1.2.1.x - /tmp partition options.
SECTION="1"

check_separate_partition_control "1.1.2.1.1" "Ensure /tmp is a separate partition" 1 /tmp
check_mount_option_control "1.1.2.1.2" "Ensure nodev option set on /tmp partition"  1 /tmp nodev
check_mount_option_control "1.1.2.1.3" "Ensure nosuid option set on /tmp partition" 1 /tmp nosuid
check_mount_option_control "1.1.2.1.4" "Ensure noexec option set on /tmp partition" 1 /tmp noexec
