#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 1.5.x - Additional process hardening.
# sysctl values ported from Images/templates/etc/sysctl.d/60-kernel_sysctl.conf.j2.
SECTION="1"
SYSCTL_CONF="/etc/sysctl.d/60-cis-hardening.conf"

id="1.5.1"; title="Ensure address space layout randomization is enabled"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && set_sysctl kernel.randomize_va_space 2 "$SYSCTL_CONF"
  val=$(get_sysctl kernel.randomize_va_space)
  [[ "$val" == "2" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "kernel.randomize_va_space=2" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "kernel.randomize_va_space=${val} (expected 2)"
fi

id="1.5.2"; title="Ensure ptrace_scope is restricted"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && set_sysctl kernel.yama.ptrace_scope 1 "$SYSCTL_CONF"
  val=$(get_sysctl kernel.yama.ptrace_scope)
  [[ "$val" =~ ^[1-3]$ ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "kernel.yama.ptrace_scope=${val}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "kernel.yama.ptrace_scope=${val} (expected 1-3)"
fi

id="1.5.3"; title="Ensure core dump backtraces are disabled"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && line_in_file /etc/systemd/coredump.conf '^ProcessSizeMax\s*=' 'ProcessSizeMax=0'
  grep -qE '^ProcessSizeMax\s*=\s*0\s*$' /etc/systemd/coredump.conf 2>/dev/null \
    && log_result "$id" "$title" "$SECTION" "$level" "pass" "ProcessSizeMax=0" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "ProcessSizeMax not set to 0 in /etc/systemd/coredump.conf"
fi

id="1.5.4"; title="Ensure core dump storage is disabled"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ ! -f /etc/systemd/coredump.conf ]]; then
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "/etc/systemd/coredump.conf absent (systemd-coredump not installed)"
else
  is_remediate && { line_in_file /etc/systemd/coredump.conf '^Storage\s*=' 'Storage=none'; systemctl daemon-reload >/dev/null 2>&1 || true; }
  grep -qE '^Storage\s*=\s*none\s*$' /etc/systemd/coredump.conf 2>/dev/null \
    && log_result "$id" "$title" "$SECTION" "$level" "pass" "Storage=none" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "Storage not set to none in /etc/systemd/coredump.conf"
fi
