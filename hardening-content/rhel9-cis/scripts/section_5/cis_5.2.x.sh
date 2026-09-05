#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 5.2.x - sudo.
# Defaults ported from Images/defaults/main/main.yml: sudolog=/var/log/sudo.log,
# timestamp_timeout=15, sugroup=sugroup.
SECTION="5"
SUDO_LOG="/var/log/sudo.log"
SUDO_TIMEOUT=15
SUGROUP="sugroup"

id="5.2.1"; title="Ensure sudo is installed"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && install_package sudo
  package_installed sudo && log_result "$id" "$title" "$SECTION" "$level" "pass" "sudo installed" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "sudo not installed"
fi

id="5.2.2"; title="Ensure sudo commands use pty"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && line_in_file /etc/sudoers '^Defaults\s+use_pty' 'Defaults    use_pty'
  grep -qE '^Defaults\s+use_pty' /etc/sudoers 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "use_pty set" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "use_pty not set"
fi

id="5.2.3"; title="Ensure sudo log file exists"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && line_in_file /etc/sudoers '^Defaults\s+logfile=' "Defaults    logfile=\"${SUDO_LOG}\""
  grep -qE "^Defaults\s+logfile=\"${SUDO_LOG}\"" /etc/sudoers 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "logfile=${SUDO_LOG}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "sudo logfile not configured"
fi

id="5.2.4"; title="Ensure users must provide password for escalation"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    for f in /etc/sudoers /etc/sudoers.d/*; do
      [[ -f "$f" ]] || continue
      grep -qiE 'nopasswd' "$f" && sed -i -E 's/^([^#].*)NOPASSWD(.*)/\1PASSWD\2/I' "$f"
    done
    visudo -cf /etc/sudoers >/dev/null 2>&1
  fi
  if grep -riE 'nopasswd' /etc/sudoers /etc/sudoers.d/* 2>/dev/null | grep -qv '^\s*#'; then
    log_result "$id" "$title" "$SECTION" "$level" "fail" "NOPASSWD entries remain in sudoers"
  else
    log_result "$id" "$title" "$SECTION" "$level" "pass" "no NOPASSWD entries in sudoers"
  fi
fi

id="5.2.5"; title="Ensure re-authentication for privilege escalation is not disabled globally"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    for f in /etc/sudoers /etc/sudoers.d/*; do
      [[ -f "$f" ]] || continue
      grep -qE '!authenticate' "$f" && sed -i -E 's/^([^#].*)!authenticate(.*)/\1authenticate\2/' "$f"
    done
    visudo -cf /etc/sudoers >/dev/null 2>&1
  fi
  if grep -rE '!authenticate' /etc/sudoers /etc/sudoers.d/* 2>/dev/null | grep -qv '^\s*#'; then
    log_result "$id" "$title" "$SECTION" "$level" "fail" "!authenticate entries remain in sudoers"
  else
    log_result "$id" "$title" "$SECTION" "$level" "pass" "no !authenticate entries in sudoers"
  fi
fi

id="5.2.6"; title="Ensure sudo authentication timeout is configured correctly"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    if grep -rqis 'timestamp_timeout' /etc/sudoers /etc/sudoers.d/* 2>/dev/null; then
      for f in /etc/sudoers /etc/sudoers.d/*; do
        [[ -f "$f" ]] || continue
        grep -qi 'timestamp_timeout' "$f" && sed -i -E "s/timestamp_timeout=[0-9]+/timestamp_timeout=${SUDO_TIMEOUT}/" "$f"
      done
    else
      line_in_file /etc/sudoers 'Defaults timestamp_timeout=' "Defaults timestamp_timeout=${SUDO_TIMEOUT}"
    fi
    visudo -cf /etc/sudoers >/dev/null 2>&1
  fi
  cur=$(grep -rhoiE 'timestamp_timeout=[0-9]+' /etc/sudoers /etc/sudoers.d/* 2>/dev/null | head -n1 | cut -d= -f2)
  if [[ -n "$cur" && "$cur" -le "$SUDO_TIMEOUT" && "$cur" -ge 0 ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "timestamp_timeout=${cur}"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "timestamp_timeout=${cur:-unset}"
  fi
fi

id="5.2.7"; title="Ensure access to the su command is restricted"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    getent group "$SUGROUP" >/dev/null 2>&1 || groupadd "$SUGROUP"
    line_in_file /etc/pam.d/su '^(#)?auth\s+required\s+pam_wheel\.so' "auth           required        pam_wheel.so use_uid group=${SUGROUP}"
  fi
  ok=1
  getent group "$SUGROUP" >/dev/null 2>&1 || ok=0
  grep -qE "^auth\s+required\s+pam_wheel\.so\s+use_uid\s+group=${SUGROUP}" /etc/pam.d/su 2>/dev/null || ok=0
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "su restricted to group ${SUGROUP} via pam_wheel" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "su not restricted via pam_wheel/${SUGROUP}"
fi
