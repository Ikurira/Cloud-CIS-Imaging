#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 1.1.1.x - Disable unused filesystem kernel modules.
# Reference implementation for the control-group script pattern (see ../../../CONTRACT.md).
# Ported from the vendored ansible-lockdown RHEL9-CIS role (Images/tasks/section_1/cis_1.1.1.x.yml)
# for correctness of module names/paths only — no ansible is installed or invoked here.

SECTION="1"

# disable_fs_module <control_id> <title> <level> <module>
disable_fs_module() {
  local control_id="$1" title="$2" level="$3" module="$4"

  if ! level_applies "$level"; then
    log_result "$control_id" "$title" "$SECTION" "$level" "skipped" "level ${level} not in scope (running level ${LEVEL})"
    return
  fi

  local modprobe_conf="/etc/modprobe.d/CIS.conf"
  local blacklist_conf="/etc/modprobe.d/blacklist.conf"

  local install_ok=0 blacklist_ok=0
  grep -qE "^install ${module}( |\$)/bin/true" "$modprobe_conf" 2>/dev/null && install_ok=1
  grep -qE "^install ${module}\s+/bin/true" "$modprobe_conf" 2>/dev/null && install_ok=1
  grep -qE "^blacklist ${module}(\s|\$)" "$blacklist_conf" 2>/dev/null && blacklist_ok=1
  local loaded=0
  lsmod | grep -q "^${module} " && loaded=1

  if is_remediate; then
    backup_file "$modprobe_conf"
    backup_file "$blacklist_conf"
    touch "$modprobe_conf" "$blacklist_conf"
    chmod go-rwx "$modprobe_conf" "$blacklist_conf"

    if [[ "$install_ok" -eq 0 ]]; then
      grep -qE "^(#)?install ${module}(\s|\$)" "$modprobe_conf" 2>/dev/null \
        && sed -i "s|^(#)\?install ${module}\(\s\|\$\).*|install ${module} /bin/true|" "$modprobe_conf" \
        || echo "install ${module} /bin/true" >> "$modprobe_conf"
    fi
    if [[ "$blacklist_ok" -eq 0 ]]; then
      grep -qE "^(#)?blacklist ${module}(\s|\$)" "$blacklist_conf" 2>/dev/null \
        && sed -i "s|^(#)\?blacklist ${module}\(\s\|\$\).*|blacklist ${module}|" "$blacklist_conf" \
        || echo "blacklist ${module}" >> "$blacklist_conf"
    fi
    if [[ "$loaded" -eq 1 ]] && [[ ! -f /run/.containerenv && ! -f /.dockerenv ]]; then
      modprobe -r "$module" 2>/dev/null || true
    fi

    install_ok=1; blacklist_ok=1
    lsmod | grep -q "^${module} " && loaded=1 || loaded=0
  fi

  if [[ "$install_ok" -eq 1 && "$blacklist_ok" -eq 1 && "$loaded" -eq 0 ]]; then
    log_result "$control_id" "$title" "$SECTION" "$level" "pass" "module ${module} disabled and blacklisted"
  else
    log_result "$control_id" "$title" "$SECTION" "$level" "fail" "module ${module} not fully disabled (install=${install_ok} blacklist=${blacklist_ok} loaded=${loaded})"
  fi
}

disable_fs_module "1.1.1.1" "Ensure cramfs kernel module is not available"      1 cramfs
disable_fs_module "1.1.1.2" "Ensure freevxfs kernel module is not available"    1 freevxfs
disable_fs_module "1.1.1.3" "Ensure hfs kernel module is not available"        1 hfs
disable_fs_module "1.1.1.4" "Ensure hfsplus kernel module is not available"    1 hfsplus
disable_fs_module "1.1.1.5" "Ensure jffs2 kernel module is not available"      1 jffs2
disable_fs_module "1.1.1.6" "Ensure squashfs kernel module is not available"   2 squashfs
disable_fs_module "1.1.1.7" "Ensure udf kernel module is not available"        2 udf
disable_fs_module "1.1.1.8" "Ensure usb-storage kernel module is not available" 1 usb-storage

# 1.1.1.9 is a manual/discovery-only control upstream (scans for other loaded FS modules
# with known CVEs) — no deterministic remediation. Reported as skipped, not silently omitted.
log_result "1.1.1.9" "Ensure unused filesystems kernel modules are not available" "$SECTION" 1 "skipped" "manual review control: run 'lsmod' and cross-check against unused filesystem drivers"
