#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 6.3.1.x - auditd service and boot-time auditing.
# Backlog limit ported from Images/defaults/main/main.yml (rhel9cis_audit_back_log_limit=8192).
SECTION="6"
BACKLOG_LIMIT=8192

id="6.3.1.1"; title="Ensure auditd packages are installed"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { install_package audit; install_package audit-libs; }
  package_installed audit && package_installed audit-libs && log_result "$id" "$title" "$SECTION" "$level" "pass" "audit and audit-libs installed" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "audit and/or audit-libs not installed"
fi

id="6.3.1.2"; title="Ensure auditing for processes that start prior to auditd is enabled"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif ! command -v grubby >/dev/null 2>&1; then
  log_result "$id" "$title" "$SECTION" "$level" "fail" "grubby not available"
else
  cur=$(grubby --info=ALL 2>/dev/null | grep args | sed -n 's/.*audit=\([[:alnum:]]\+\).*/\1/p' | head -1)
  if [[ -z "$cur" || "$cur" == "0" || "${cur,,}" == "off" ]]; then
    is_remediate && grubby --update-kernel=ALL --args="audit=1" >/dev/null 2>&1
    cur=$(grubby --info=ALL 2>/dev/null | grep args | sed -n 's/.*audit=\([[:alnum:]]\+\).*/\1/p' | head -1)
  fi
  [[ "$cur" == "1" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "audit=1 on kernel cmdline" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "audit=${cur:-unset} on kernel cmdline (requires reboot to take effect after remediation)"
fi

id="6.3.1.3"; title="Ensure audit_backlog_limit is sufficient"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif ! command -v grubby >/dev/null 2>&1; then
  log_result "$id" "$title" "$SECTION" "$level" "fail" "grubby not available"
else
  cur=$(grubby --info=ALL 2>/dev/null | grep args | grep -oE "audit_backlog_limit=[[:digit:]]+" | grep -oE '[[:digit:]]+' | sort -n | head -1)
  if [[ -z "$cur" || "$cur" -lt "$BACKLOG_LIMIT" ]] 2>/dev/null; then
    is_remediate && grubby --update-kernel=ALL --args="audit_backlog_limit=${BACKLOG_LIMIT}" >/dev/null 2>&1
    cur=$(grubby --info=ALL 2>/dev/null | grep args | grep -oE "audit_backlog_limit=[[:digit:]]+" | grep -oE '[[:digit:]]+' | sort -n | head -1)
  fi
  [[ -n "$cur" && "$cur" -ge "$BACKLOG_LIMIT" ]] 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "audit_backlog_limit=${cur}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "audit_backlog_limit=${cur:-unset} (requires reboot to take effect after remediation)"
fi

id="6.3.1.4"; title="Ensure auditd service is enabled and active"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && enable_service auditd
  service_active_and_enabled auditd && log_result "$id" "$title" "$SECTION" "$level" "pass" "auditd enabled and active" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "auditd not enabled/active"
fi
