#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 3.2.x - Disable uncommon network protocol kernel modules.
SECTION="3"

# disable_net_module <id> <title> <module>
disable_net_module() {
  local id="$1" title="$2" module="$3" level=2
  if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"; return; fi

  local modprobe_conf="/etc/modprobe.d/${module}.conf"
  local blacklist_conf="/etc/modprobe.d/blacklist.conf"

  if is_remediate; then
    line_in_file "$modprobe_conf" "^(#)?install ${module}(\s|\$)" "install ${module} /bin/true" u-x,go-rwx
    line_in_file "$blacklist_conf" "^(#)?blacklist ${module}(\s|\$)" "blacklist ${module}" u-x,go-rwx
    lsmod | grep -q "^${module} " && modprobe -r "$module" 2>/dev/null || true
  fi

  local ok=1
  grep -qE "^install ${module} /bin/true" "$modprobe_conf" 2>/dev/null || ok=0
  grep -qE "^blacklist ${module}(\s|\$)" "$blacklist_conf" 2>/dev/null || ok=0
  lsmod | grep -q "^${module} " && ok=0

  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "module ${module} disabled and blacklisted" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "module ${module} not fully disabled"
}

disable_net_module "3.2.1" "Ensure dccp kernel module is not available" dccp
disable_net_module "3.2.2" "Ensure tipc kernel module is not available" tipc
disable_net_module "3.2.3" "Ensure rds kernel module is not available"  rds
disable_net_module "3.2.4" "Ensure sctp kernel module is not available" sctp
