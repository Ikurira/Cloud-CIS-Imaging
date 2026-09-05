#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 6.2.1.x - journald. Defaults ported from Images/defaults/main/main.yml
# (rhel9cis_syslog=journald) and Images/templates/etc/systemd/journald.conf.d/rotation.conf.j2.
SECTION="6"
SYSLOG_CHOICE="journald"

id="6.2.1.1"; title="Ensure journald service is enabled and active"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { systemctl unmask systemd-journald >/dev/null 2>&1; systemctl start systemd-journald >/dev/null 2>&1; }
  systemctl is-active systemd-journald >/dev/null 2>&1 && log_result "$id" "$title" "$SECTION" "$level" "pass" "systemd-journald active" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "systemd-journald not active"
fi

id="6.2.1.2"; title="Ensure journald log file access is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && [[ -f /usr/lib/tmpfiles.d/systemd.conf ]] && chmod g-wx,o-rwx /usr/lib/tmpfiles.d/systemd.conf
  if [[ -f /etc/tmpfiles.d/systemd.conf ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "skipped" "manual review: /etc/tmpfiles.d/systemd.conf overrides journald file permissions — confirm it matches site policy"
  elif [[ -f /usr/lib/tmpfiles.d/systemd.conf ]] && check_file_perms /usr/lib/tmpfiles.d/systemd.conf 640; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "default tmpfiles.d journald permissions in place"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "journald tmpfiles permissions not as expected"
  fi
fi

id="6.2.1.3"; title="Ensure journald log file rotation is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  rot_file="/etc/systemd/journald.conf.d/rotation.conf"
  if is_remediate; then
    mkdir -p /etc/systemd/journald.conf.d
    {
      echo "[Journal]"
      echo "SystemMaxUse=10M"
      echo "SystemKeepFree=100G"
      echo "RuntimeMaxUse=10M"
      echo "RuntimeKeepFree=100G"
      echo "MaxFileSec=1month"
    } > "$rot_file"
    chmod g-wx,o-rwx "$rot_file"
    sed -i -E 's/^(\s*(SystemMaxUse|SystemKeepFree|RuntimeMaxUse|RuntimeKeepFree|MaxFileSec)\s*=.*)/#\1/' /etc/systemd/journald.conf 2>/dev/null
    systemctl restart systemd-journald >/dev/null 2>&1 || true
  fi
  [[ -f "$rot_file" ]] && grep -q "SystemMaxUse=10M" "$rot_file" && log_result "$id" "$title" "$SECTION" "$level" "pass" "rotation.conf present" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "${rot_file} missing or misconfigured"
fi

id="6.2.1.4"; title="Ensure only one logging system is in use"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if [[ "$SYSLOG_CHOICE" == "journald" ]]; then
    if is_remediate && package_installed rsyslog; then mask_and_disable_service rsyslog; fi
    if ! package_installed rsyslog || service_inactive_and_masked rsyslog; then
      log_result "$id" "$title" "$SECTION" "$level" "pass" "journald in use, rsyslog absent/masked"
    else
      log_result "$id" "$title" "$SECTION" "$level" "fail" "rsyslog installed and not masked while journald is the chosen logger"
    fi
  else
    is_remediate && mask_and_disable_service systemd-journald
    service_inactive_and_masked systemd-journald && log_result "$id" "$title" "$SECTION" "$level" "pass" "rsyslog in use, systemd-journald masked" \
      || log_result "$id" "$title" "$SECTION" "$level" "fail" "systemd-journald not masked while rsyslog is the chosen logger"
  fi
fi
