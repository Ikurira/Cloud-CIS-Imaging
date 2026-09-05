#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 6.2.3.x - rsyslog. Upstream only applies this whole section when
# rhel9cis_syslog=='rsyslog' (Images/tasks/section_6/main.yml); the pipeline default is
# journald (see cis_6.2.1.x.sh / cis_6.2.2.x.sh), so all of 6.2.3.x is not-applicable here.
# If a deployment switches SYSLOG_CHOICE to "rsyslog" in cis_6.2.1.x.sh, populate this file
# with the equivalent rsyslog.conf edits (file creation mode 0640, mail/news/local/auth/cron
# facility routing, remote log host forwarding, imtcp module disabled) before relying on it.
SECTION="6"
SYSLOG_CHOICE="journald"

for id_title in \
  "6.2.3.1|Ensure rsyslog is installed" \
  "6.2.3.2|Ensure rsyslog service is enabled and active" \
  "6.2.3.3|Ensure journald is configured to send logs to rsyslog" \
  "6.2.3.4|Ensure rsyslog log file creation mode is configured" \
  "6.2.3.5|Ensure rsyslog logging is configured" \
  "6.2.3.6|Ensure rsyslog is configured to send logs to a remote log host" \
  "6.2.3.7|Ensure rsyslog is not configured to receive logs from a remote client" \
  "6.2.3.8|Ensure rsyslog logrotate is configured"
do
  id="${id_title%%|*}"; title="${id_title#*|}"
  log_result "$id" "$title" "$SECTION" 1 "skipped" "not applicable: configured syslog choice is ${SYSLOG_CHOICE}, not rsyslog"
done
