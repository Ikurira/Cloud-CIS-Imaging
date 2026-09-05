#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 4.2.x - firewalld configuration. Default zone ported from
# Images/defaults/main/main.yml (rhel9cis_default_zone=public).
SECTION="4"
FIREWALL_UTIL="firewalld"
DEFAULT_ZONE="public"

log_result "4.2.1" "Ensure firewalld drops unnecessary services and ports" "$SECTION" 1 "skipped" "manual review control: run 'firewall-cmd --list-all --zone=<zone>' for each active zone and confirm every accepted service/port matches site policy"

id="4.2.2"; title="Ensure firewalld loopback traffic is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ "$FIREWALL_UTIL" != "firewalld" ]]; then
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "not applicable: configured firewall utility is ${FIREWALL_UTIL}"
elif ! command -v firewall-cmd >/dev/null 2>&1; then
  log_result "$id" "$title" "$SECTION" "$level" "fail" "firewalld not installed"
else
  rule_v4='rule family="ipv4" source address="127.0.0.1" destination not address="127.0.0.1" drop'
  rule_v6='rule family="ipv6" source address="::1" destination not address="::1" drop'
  if is_remediate; then
    firewall-cmd --permanent --zone="$DEFAULT_ZONE" --add-rich-rule="$rule_v4" >/dev/null 2>&1
    firewall-cmd --permanent --zone="$DEFAULT_ZONE" --add-rich-rule="$rule_v6" >/dev/null 2>&1
    firewall-cmd --reload >/dev/null 2>&1
  fi
  cur=$(firewall-cmd --zone="$DEFAULT_ZONE" --list-rich-rules 2>/dev/null)
  if [[ "$cur" == *"$rule_v4"* && "$cur" == *"$rule_v6"* ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "loopback drop rich rules present in zone ${DEFAULT_ZONE}"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "loopback drop rich rules missing in zone ${DEFAULT_ZONE}"
  fi
fi
