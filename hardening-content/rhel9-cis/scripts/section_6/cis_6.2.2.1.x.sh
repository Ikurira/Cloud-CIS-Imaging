#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 6.2.2.1.x - Remote journal (systemd-journal-remote/-upload).
# rhel9cis_system_is_log_server default is false (this is a client sending logs out, not
# a collector), matching a typical fleet instance.
SECTION="6"
IS_LOG_SERVER=0

id="6.2.2.1.1"; title="Ensure systemd-journal-remote is installed"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ "$IS_LOG_SERVER" -eq 1 ]]; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "not applicable: this host is a log server"
else
  is_remediate && install_package systemd-journal-remote
  package_installed systemd-journal-remote && log_result "$id" "$title" "$SECTION" "$level" "pass" "systemd-journal-remote installed" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "systemd-journal-remote not installed"
fi

log_result "6.2.2.1.2" "Ensure systemd-journal-upload authentication is configured" "$SECTION" 1 "skipped" "site-specific control: requires a real central-log-server URL and TLS cert paths; set them in /etc/systemd/journal-upload.conf before enabling"
log_result "6.2.2.1.3" "Ensure systemd-journal-upload is enabled and active" "$SECTION" 1 "skipped" "depends on 6.2.2.1.2 being configured with a real log server first"

id="6.2.2.1.4"; title="Ensure systemd-journal-remote service is not in use"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ "$IS_LOG_SERVER" -eq 1 ]]; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "not applicable: this host is a log server"
else
  if is_remediate; then
    mask_and_disable_service systemd-journal-remote.socket
    mask_and_disable_service systemd-journal-remote.service
  fi
  if service_inactive_and_masked systemd-journal-remote.socket && service_inactive_and_masked systemd-journal-remote.service; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "systemd-journal-remote socket/service masked"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "systemd-journal-remote socket/service not masked"
  fi
fi
