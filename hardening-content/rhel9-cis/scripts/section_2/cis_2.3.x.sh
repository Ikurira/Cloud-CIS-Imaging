#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 2.3.x - Time synchronization (chrony).
# Defaults ported from Images/defaults/main/main.yml and Images/templates/etc/chrony.conf.j2.
SECTION="2"
NTP_SERVERS=(0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org)
NTP_SERVER_OPTIONS="minpoll 8"
CHRONY_MAKESTEP="1.0 3"

id="2.3.1"; title="Ensure time synchronization is in use"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && install_package chrony
  if package_installed chrony; then log_result "$id" "$title" "$SECTION" "$level" "pass" "chrony installed"
  else log_result "$id" "$title" "$SECTION" "$level" "fail" "chrony not installed"; fi
fi

id="2.3.2"; title="Ensure chrony is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif ! package_installed chrony; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "chrony not installed"
else
  if is_remediate; then
    backup_file /etc/chrony.conf
    {
      echo "# Managed by CIS RHEL9 hardening (hardening-content/rhel9-cis)"
      for s in "${NTP_SERVERS[@]}"; do echo "server ${s} ${NTP_SERVER_OPTIONS}"; done
      echo "driftfile /var/lib/chrony/drift"
      echo "makestep ${CHRONY_MAKESTEP}"
    } > /etc/chrony.conf
    chmod go-wx /etc/chrony.conf
  fi
  ok=1
  for s in "${NTP_SERVERS[@]}"; do grep -qF "server ${s}" /etc/chrony.conf 2>/dev/null || ok=0; done
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "chrony.conf configured with expected servers" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "chrony.conf missing one or more expected NTP servers"
fi

id="2.3.3"; title="Ensure chrony is not run as the root user"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif ! package_installed chrony; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "chrony not installed"
else
  if is_remediate; then
    if grep -qE '^OPTIONS="' /etc/sysconfig/chronyd 2>/dev/null; then
      grep -qE '\-u chrony' /etc/sysconfig/chronyd || sed -i 's/^OPTIONS="\(.*\)"/OPTIONS="\1 -u chrony"/' /etc/sysconfig/chronyd
    else
      echo 'OPTIONS="-u chrony"' >> /etc/sysconfig/chronyd
    fi
    chmod go-wx /etc/sysconfig/chronyd
  fi
  if grep -qE '^OPTIONS="[^"]*-u chrony' /etc/sysconfig/chronyd 2>/dev/null; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "chronyd OPTIONS includes -u chrony"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "chronyd OPTIONS missing -u chrony"
  fi
fi
