#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 6.3.2.x - auditd data retention (/etc/audit/auditd.conf).
# Defaults ported from Images/defaults/main/main.yml.
SECTION="6"
AUDITD_CONF="/etc/audit/auditd.conf"
MAX_LOG_FILE_SIZE=10
MAX_LOG_FILE_ACTION="keep_logs"
DISK_FULL_ACTION="halt"
DISK_ERROR_ACTION="syslog"
SPACE_LEFT_ACTION="email"
ADMIN_SPACE_LEFT_ACTION="halt"

# auditd_kv <id> <title> <key> <value> [ge_numeric:0|1]
auditd_kv() {
  local id="$1" title="$2" key="$3" value="$4" numeric="${5:-0}" level=2
  if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"; return; fi
  is_remediate && line_in_file "$AUDITD_CONF" "^${key}\s*(=|\s)" "${key} = ${value}"
  cur=$(grep -E "^${key}\s*=" "$AUDITD_CONF" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d ' ')
  if [[ "$numeric" -eq 1 ]]; then
    [[ -n "$cur" && "$cur" -ge "$value" ]] 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "${key}=${cur}" \
      || log_result "$id" "$title" "$SECTION" "$level" "fail" "${key}=${cur:-unset} (expected >=${value})"
  else
    [[ "$cur" == "$value" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "${key}=${cur}" \
      || log_result "$id" "$title" "$SECTION" "$level" "fail" "${key}=${cur:-unset} (expected ${value})"
  fi
}

auditd_kv "6.3.2.1" "Ensure audit log storage size is configured" max_log_file "$MAX_LOG_FILE_SIZE" 1
auditd_kv "6.3.2.2" "Ensure audit logs are not automatically deleted" max_log_file_action "$MAX_LOG_FILE_ACTION"

id="6.3.2.3"; title="Ensure system is disabled when audit logs are full"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { line_in_file "$AUDITD_CONF" '^disk_full_action' "disk_full_action = ${DISK_FULL_ACTION}"; line_in_file "$AUDITD_CONF" '^disk_error_action' "disk_error_action = ${DISK_ERROR_ACTION}"; }
  v1=$(grep -E '^disk_full_action\s*=' "$AUDITD_CONF" 2>/dev/null | cut -d= -f2 | tr -d ' ')
  v2=$(grep -E '^disk_error_action\s*=' "$AUDITD_CONF" 2>/dev/null | cut -d= -f2 | tr -d ' ')
  [[ "$v1" =~ ^(halt|single)$ && "$v2" =~ ^(syslog|single|halt)$ ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "disk_full_action=${v1} disk_error_action=${v2}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "disk_full_action=${v1:-unset} disk_error_action=${v2:-unset}"
fi

id="6.3.2.4"; title="Ensure system warns when audit logs are low on space"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { line_in_file "$AUDITD_CONF" '^space_left_action' "space_left_action = ${SPACE_LEFT_ACTION}"; line_in_file "$AUDITD_CONF" '^admin_space_left_action' "admin_space_left_action = ${ADMIN_SPACE_LEFT_ACTION}"; }
  v1=$(grep -E '^space_left_action\s*=' "$AUDITD_CONF" 2>/dev/null | cut -d= -f2 | tr -d ' ')
  v2=$(grep -E '^admin_space_left_action\s*=' "$AUDITD_CONF" 2>/dev/null | cut -d= -f2 | tr -d ' ')
  [[ -n "$v1" && "$v2" =~ ^(halt|single)$ ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "space_left_action=${v1} admin_space_left_action=${v2}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "space_left_action=${v1:-unset} admin_space_left_action=${v2:-unset}"
fi
