#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 1.1.2.2.x - /dev/shm partition options.
SECTION="1"

check_separate_partition_control "1.1.2.2.1" "Ensure /dev/shm is a separate partition" 1 /dev/shm
check_mount_option_control "1.1.2.2.2" "Ensure nodev option set on /dev/shm partition"  1 /dev/shm nodev
check_mount_option_control "1.1.2.2.3" "Ensure nosuid option set on /dev/shm partition" 1 /dev/shm nosuid
check_mount_option_control "1.1.2.2.4" "Ensure noexec option set on /dev/shm partition" 1 /dev/shm noexec
