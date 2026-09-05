#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 2.2.x - Unused client packages.
SECTION="2"

# remove_client_pkg <id> <title> <level> <pkg>
remove_client_pkg() {
  local id="$1" title="$2" level="$3" pkg="$4"
  if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"; return; fi
  is_remediate && remove_package "$pkg"
  if ! package_installed "$pkg"; then log_result "$id" "$title" "$SECTION" "$level" "pass" "${pkg} not installed"
  else log_result "$id" "$title" "$SECTION" "$level" "fail" "${pkg} is installed"; fi
}

remove_client_pkg "2.2.1" "Ensure ftp client is not installed"    1 ftp
remove_client_pkg "2.2.2" "Ensure ldap client is not installed"   2 openldap-clients
remove_client_pkg "2.2.3" "Ensure nis client is not installed"    1 ypbind
remove_client_pkg "2.2.4" "Ensure telnet client is not installed" 1 telnet
remove_client_pkg "2.2.5" "Ensure tftp client is not installed"   1 tftp
