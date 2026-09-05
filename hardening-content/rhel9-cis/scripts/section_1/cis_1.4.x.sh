#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 1.4.x - Bootloader configuration.
SECTION="1"

# 1.4.1 - default rhel9cis_set_boot_pass=false upstream (see Images/Changelog.md "Aug2026").
# Generating/rotating a grub2 password is a credential-issuance action, not something to
# script blindly; left as a manual/opt-in control.
log_result "1.4.1" "Ensure bootloader password is set" "$SECTION" 1 "skipped" "manual control: run 'grub2-setpassword' (or 'grub2-mkpasswd-pbkdf2' + /boot/grub2/user.cfg) with an org-issued credential; not auto-generated"

id="1.4.2"; title="Ensure access to bootloader config is configured"; level=1
if ! level_applies "$level"; then
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ -d /sys/firmware/efi ]]; then
  # EFI system: harden the /boot/efi mount options rather than file perms.
  if is_remediate; then
    for opt in umask=0077 fmask=0077 uid=0 gid=0; do
      key="${opt%%=*}"
      grep -qE "^\S+\s+/boot/efi\s.*\b${key}=" /etc/fstab 2>/dev/null || fstab_add_option /boot/efi "$opt" >/dev/null 2>&1
    done
  fi
  missing=""
  for opt in umask=0077 fmask=0077 uid=0 gid=0; do
    key="${opt%%=*}"
    grep -qE "^\S+\s+/boot/efi\s.*\b${key}=" /etc/fstab 2>/dev/null || missing="${missing}${key} "
  done
  if [[ -z "$missing" ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "/boot/efi fstab entry sets umask/fmask/uid/gid"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "/boot/efi fstab entry missing: ${missing}(effective on next mount/reboot after fstab edit)"
  fi
else
  # Legacy BIOS system: file permissions on the grub2 config files.
  if is_remediate; then
    for f in grub.cfg grubenv user.cfg; do
      [[ -f "/boot/grub2/$f" ]] && set_file_perms "/boot/grub2/$f" 600 root root
    done
  fi
  ok=1
  for f in grub.cfg grubenv user.cfg; do
    [[ -f "/boot/grub2/$f" ]] || continue
    check_file_perms "/boot/grub2/$f" 600 || ok=0
  done
  if [[ "$ok" -eq 1 ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "grub2 config files are mode 600"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "one or more grub2 config files are not mode 600"
  fi
fi
