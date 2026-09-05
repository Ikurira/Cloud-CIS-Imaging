#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 3.1.x - Network device configuration.
# Defaults ported from Images/defaults/main/main.yml:
# rhel9cis_ipv6_required=true (disable is opt-in, off by default), method=sysctl;
# rhel9cis_bluetooth_service=false, rhel9cis_bluetooth_mask=false (default: remove package).
SECTION="3"
IPV6_REQUIRED=1
BLUETOOTH_MASK=0

id="3.1.1"; title="Ensure IPv6 status is identified"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ "$IPV6_REQUIRED" -eq 1 ]]; then
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "not applicable: IPv6 declared required by site default (rhel9cis_ipv6_required=true)"
else
  is_remediate && set_sysctl net.ipv6.conf.all.disable_ipv6 1 /etc/sysctl.d/60-disable_ipv6.conf \
                && set_sysctl net.ipv6.conf.default.disable_ipv6 1 /etc/sysctl.d/60-disable_ipv6.conf
  v1=$(get_sysctl net.ipv6.conf.all.disable_ipv6); v2=$(get_sysctl net.ipv6.conf.default.disable_ipv6)
  if [[ "$v1" == "1" && "$v2" == "1" ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "IPv6 disabled via sysctl"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "IPv6 not disabled (all=${v1} default=${v2})"
  fi
fi

id="3.1.2"; title="Ensure wireless interfaces are disabled"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif ! command -v nmcli >/dev/null 2>&1; then
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "not applicable: NetworkManager not installed (typical for EC2 instances with no wireless hardware)"
else
  radio_state=$(nmcli radio wifi 2>/dev/null)
  if [[ "$radio_state" == "enabled" ]]; then
    is_remediate && nmcli radio all off >/dev/null 2>&1
  fi
  radio_state=$(nmcli radio wifi 2>/dev/null)
  if [[ "$radio_state" != "enabled" ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "wifi radio state: ${radio_state:-no wireless hardware}"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "wifi radio is enabled"
  fi
fi

id="3.1.3"; title="Ensure bluetooth services are not in use"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    if [[ "$BLUETOOTH_MASK" -eq 1 ]]; then mask_and_disable_service bluetooth; else remove_package bluez; fi
  fi
  if [[ "$BLUETOOTH_MASK" -eq 1 ]]; then
    service_inactive_and_masked bluetooth && log_result "$id" "$title" "$SECTION" "$level" "pass" "bluetooth.service masked" \
      || log_result "$id" "$title" "$SECTION" "$level" "fail" "bluetooth.service not masked"
  else
    ! package_installed bluez && log_result "$id" "$title" "$SECTION" "$level" "pass" "bluez not installed" \
      || log_result "$id" "$title" "$SECTION" "$level" "fail" "bluez is installed"
  fi
fi
