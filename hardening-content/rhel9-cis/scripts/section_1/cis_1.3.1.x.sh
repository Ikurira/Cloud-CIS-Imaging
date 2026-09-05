#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 1.3.1.x - SELinux. Defaults ported from Images/defaults/main/main.yml:
# rhel9cis_selinux_pol=targeted, rhel9cis_selinux_enforce=enforcing.
SECTION="1"
SELINUX_POLICY="targeted"
SELINUX_ENFORCE="enforcing"

id="1.3.1.1"; title="Ensure SELinux is installed"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && install_package libselinux
  if package_installed libselinux; then log_result "$id" "$title" "$SECTION" "$level" "pass" "libselinux installed"
  else log_result "$id" "$title" "$SECTION" "$level" "fail" "libselinux not installed"; fi
fi

id="1.3.1.2"; title="Ensure SELinux is not disabled in bootloader configuration"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate && [[ -f /etc/default/grub ]]; then
    backup_file /etc/default/grub
    sed -i -E 's/\bselinux=0\b//g; s/\benforcing=0\b//g' /etc/default/grub
    if [[ -d /sys/firmware/efi ]]; then
      grub_cfg=$(find /boot/efi/EFI -maxdepth 2 -name grub.cfg 2>/dev/null | head -n1)
    else
      grub_cfg="/boot/grub2/grub.cfg"
    fi
    [[ -n "${grub_cfg:-}" ]] && grub2-mkconfig -o "$grub_cfg" >/dev/null 2>&1 || true
  fi
  if grep -qE '\b(selinux|enforcing)=0\b' /etc/default/grub 2>/dev/null; then
    log_result "$id" "$title" "$SECTION" "$level" "fail" "grub config still disables selinux/enforcing"
  else
    log_result "$id" "$title" "$SECTION" "$level" "pass" "no selinux=0/enforcing=0 in grub config"
  fi
fi

# 1.3.1.3 and 1.3.1.4 both converge on the same config state upstream; implemented once.
for cid_title in "1.3.1.3|Ensure SELinux policy is configured" "1.3.1.4|Ensure the SELinux mode is not disabled"; do
  id="${cid_title%%|*}"; title="${cid_title#*|}"; level=1
  if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"; continue; fi
  if is_remediate; then
    line_in_file /etc/selinux/config '^SELINUXTYPE=' "SELINUXTYPE=${SELINUX_POLICY}"
    line_in_file /etc/selinux/config '^SELINUX=' "SELINUX=${SELINUX_ENFORCE}"
  fi
  cur_type=$(grep -E '^SELINUXTYPE=' /etc/selinux/config 2>/dev/null | cut -d= -f2)
  cur_mode=$(grep -E '^SELINUX=' /etc/selinux/config 2>/dev/null | cut -d= -f2)
  if [[ "$cur_type" == "$SELINUX_POLICY" && "$cur_mode" != "disabled" ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "SELINUXTYPE=${cur_type} SELINUX=${cur_mode}"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "SELINUXTYPE=${cur_type} SELINUX=${cur_mode}"
  fi
done

id="1.3.1.5"; title="Ensure the SELinux mode is enforcing"; level=2
if [[ "$SELINUX_ENFORCE" != "enforcing" ]]; then
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "not applicable: configured policy is not 'enforcing'"
elif ! level_applies "$level"; then
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { line_in_file /etc/selinux/config '^SELINUX=' 'SELINUX=enforcing'; setenforce 1 >/dev/null 2>&1 || true; }
  runtime_mode=$(getenforce 2>/dev/null || echo "Unknown")
  if [[ "$runtime_mode" == "Enforcing" ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "getenforce=Enforcing"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "getenforce=${runtime_mode} (expected Enforcing)"
  fi
fi

log_result "1.3.1.6" "Ensure no unconfined services exist" "$SECTION" 1 "skipped" "manual review control: run 'ps -eZ | grep unconfined_service_t' and investigate any findings"

id="1.3.1.7"; title="Ensure the MCS Translation Service (mcstrans) is not installed"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && remove_package mcstrans
  if ! package_installed mcstrans; then log_result "$id" "$title" "$SECTION" "$level" "pass" "mcstrans not installed"
  else log_result "$id" "$title" "$SECTION" "$level" "fail" "mcstrans is installed"; fi
fi

id="1.3.1.8"; title="Ensure SETroubleshoot is not installed"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && remove_package setroubleshoot
  if ! package_installed setroubleshoot; then log_result "$id" "$title" "$SECTION" "$level" "pass" "setroubleshoot not installed"
  else log_result "$id" "$title" "$SECTION" "$level" "fail" "setroubleshoot is installed"; fi
fi
