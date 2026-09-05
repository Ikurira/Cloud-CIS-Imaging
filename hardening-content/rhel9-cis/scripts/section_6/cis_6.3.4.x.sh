#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 6.3.4.x - auditd file/tool permissions. Binary list ported from
# Images/vars/main.yml (audit_bins); log file path discovered from auditd.conf like upstream.
SECTION="6"
AUDIT_BINS=(/sbin/auditctl /sbin/aureport /sbin/ausearch /sbin/autrace /sbin/auditd /sbin/augenrules)

audit_log_file() {
  grep -E '^log_file\s*=' /etc/audit/auditd.conf 2>/dev/null | cut -d= -f2 | tr -d ' '
}

id="6.3.4.1"; title="Ensure the audit log file directory mode is configured"; level=2
log_dir=$(dirname "$(audit_log_file)" 2>/dev/null)
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ -z "$log_dir" || ! -d "$log_dir" ]]; then
  log_result "$id" "$title" "$SECTION" "$level" "fail" "could not determine audit log directory from auditd.conf"
else
  is_remediate && chmod g-w,o-rwx "$log_dir" 2>/dev/null
  check_file_perms "$log_dir" 750 && log_result "$id" "$title" "$SECTION" "$level" "pass" "${log_dir} is mode 750" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "${log_dir} is not mode 750"
fi

id="6.3.4.2-4"; title="Ensure audit log files mode/owner/group are configured"; level=2
log_file=$(audit_log_file)
if ! level_applies "$level"; then log_result "6.3.4.2" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ -z "$log_file" || ! -e "$log_file" ]]; then
  log_result "6.3.4.2" "$title" "$SECTION" "$level" "fail" "could not determine audit log file from auditd.conf"
else
  if is_remediate; then
    chmod g-x,o-rwx "$log_file" 2>/dev/null
    chown root:root "$log_file" 2>/dev/null
  fi
  if check_file_perms "$log_file" 600 || check_file_perms "$log_file" 640; then
    log_result "6.3.4.2" "Ensure audit log files mode is configured" "$SECTION" "$level" "pass" "${log_file} mode ok"
  else
    log_result "6.3.4.2" "Ensure audit log files mode is configured" "$SECTION" "$level" "fail" "${log_file} mode not restricted"
  fi
  [[ "$(stat -c '%U' "$log_file" 2>/dev/null)" == "root" ]] \
    && log_result "6.3.4.3" "Ensure audit log files owner is configured" "$SECTION" "$level" "pass" "owner=root" \
    || log_result "6.3.4.3" "Ensure audit log files owner is configured" "$SECTION" "$level" "fail" "owner not root"
  [[ "$(stat -c '%G' "$log_file" 2>/dev/null)" == "root" ]] \
    && log_result "6.3.4.4" "Ensure only authorized groups are assigned ownership of audit log files" "$SECTION" "$level" "pass" "group=root" \
    || log_result "6.3.4.4" "Ensure only authorized groups are assigned ownership of audit log files" "$SECTION" "$level" "fail" "group not root"
fi

conf_files=(/etc/audit/auditd.conf)
[[ -d /etc/audit/rules.d ]] && while IFS= read -r -d '' f; do conf_files+=("$f"); done < <(find /etc/audit/rules.d -type f -print0 2>/dev/null)
[[ -f /etc/audit/audit.rules ]] && conf_files+=(/etc/audit/audit.rules)

id="6.3.4.5"; title="Ensure audit configuration files mode is configured"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  ok=1
  for f in "${conf_files[@]}"; do
    [[ -f "$f" ]] || continue
    is_remediate && chmod u-x,g-wx,o-rwx "$f" 2>/dev/null
    check_file_perms "$f" 640 || ok=0
  done
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "audit config files mode 640" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "one or more audit config files not mode 640"
fi

id="6.3.4.6"; title="Ensure audit configuration files owner is configured"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  ok=1
  for f in "${conf_files[@]}"; do
    [[ -f "$f" ]] || continue
    is_remediate && chown root "$f" 2>/dev/null
    [[ "$(stat -c '%U' "$f" 2>/dev/null)" == "root" ]] || ok=0
  done
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "audit config files owned by root" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "one or more audit config files not owned by root"
fi

id="6.3.4.7"; title="Ensure audit configuration files group owner is configured"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  ok=1
  for f in "${conf_files[@]}"; do
    [[ -f "$f" ]] || continue
    is_remediate && chgrp root "$f" 2>/dev/null
    [[ "$(stat -c '%G' "$f" 2>/dev/null)" == "root" ]] || ok=0
  done
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "audit config files group-owned by root" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "one or more audit config files not group-owned by root"
fi

id="6.3.4.8"; title="Ensure audit tools mode is configured"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  ok=1
  for b in "${AUDIT_BINS[@]}"; do
    [[ -e "$b" ]] || continue
    is_remediate && chmod go-w "$b" 2>/dev/null
    mode=$(stat -c '%a' "$b" 2>/dev/null)
    [[ "${mode: -2:1}" =~ [2367] || "${mode: -1}" =~ [2367] ]] && ok=0
  done
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "audit tools not group/other writable" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "one or more audit tools are group/other writable"
fi

id="6.3.4.9"; title="Ensure audit tools owner is configured"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  ok=1
  for b in "${AUDIT_BINS[@]}"; do
    [[ -e "$b" ]] || continue
    is_remediate && chown root:root "$b" 2>/dev/null
    [[ "$(stat -c '%U' "$b" 2>/dev/null)" == "root" ]] || ok=0
  done
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "audit tools owned by root" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "one or more audit tools not owned by root"
fi

id="6.3.4.10"; title="Ensure audit tools group owner is configured"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  ok=1
  for b in "${AUDIT_BINS[@]}"; do
    [[ -e "$b" ]] || continue
    is_remediate && chgrp root "$b" 2>/dev/null
    [[ "$(stat -c '%G' "$b" 2>/dev/null)" == "root" ]] || ok=0
  done
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "audit tools group-owned by root" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "one or more audit tools not group-owned by root"
fi
