#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 4.1.x - Single firewall utility. Default rhel9cis_firewall=firewalld
# (Images/defaults/main/main.yml), matching stock RHEL9.
SECTION="4"
FIREWALL_UTIL="firewalld"

id="4.1.1"; title="Ensure nftables is installed"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ "$FIREWALL_UTIL" != "nftables" ]]; then
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "not applicable: configured firewall utility is ${FIREWALL_UTIL}"
else
  is_remediate && install_package nftables
  package_installed nftables && log_result "$id" "$title" "$SECTION" "$level" "pass" "nftables installed" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "nftables not installed"
fi

id="4.1.2"; title="Ensure a single firewall configuration utility is in use"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  other="nftables"; [[ "$FIREWALL_UTIL" == "nftables" ]] && other="firewalld"
  if is_remediate; then
    package_installed "$other" && mask_and_disable_service "$other"
    install_package "$FIREWALL_UTIL"
    enable_service "$FIREWALL_UTIL"
  fi
  active_ok=1
  package_installed "$other" && ! service_inactive_and_masked "$other" && active_ok=0
  service_active_and_enabled "$FIREWALL_UTIL" || active_ok=0
  [[ "$active_ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "${FIREWALL_UTIL} active, ${other} masked/absent" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "${FIREWALL_UTIL} not exclusively active"
fi
