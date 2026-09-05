#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 6.1.x - AIDE file integrity.
# Defaults ported from Images/defaults/main/main.yml and Images/vars/main.yml.
# 6.1.2/6.1.3 are skipped on EC2 upstream ("when: not system_is_ec2") — an immutable-AMI /
# ephemeral-fleet workload relies on the SSM State Manager association for continuous
# enforcement rather than AIDE's own cron-scheduled rebuild-against-golden-image model, and
# scheduling a periodic AIDE run against a database frozen at build time would just generate
# constant false-positive drift on any fleet instance. Respected here rather than overridden.
SECTION="6"
IS_EC2=1
AIDE_DB="/var/lib/aide/aide.db.gz"

id="6.1.1"; title="Ensure AIDE is installed"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && install_package aide
  if package_installed aide; then
    if is_remediate && [[ ! -f "$AIDE_DB" ]]; then
      /usr/sbin/aide --init >/dev/null 2>&1
      [[ -f /var/lib/aide/aide.db.new.gz ]] && cp /var/lib/aide/aide.db.new.gz "$AIDE_DB"
      chmod ug-wx,o-rwx "$AIDE_DB" 2>/dev/null
    fi
    [[ -f "$AIDE_DB" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "aide installed, database present" \
      || log_result "$id" "$title" "$SECTION" "$level" "fail" "aide installed but database not initialized"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "aide not installed"
  fi
fi

id="6.1.2"; title="Ensure filesystem integrity is regularly checked"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ "$IS_EC2" -eq 1 ]]; then
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "not applicable on EC2 fleet instances (see file header); rely on the SSM State Manager association for continuous enforcement instead"
else
  is_remediate && { echo "0 5 * * * root /usr/sbin/aide --check" > /etc/cron.d/aide; }
  [[ -f /etc/cron.d/aide ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "AIDE cron job present" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "AIDE cron job missing"
fi

id="6.1.3"; title="Ensure cryptographic mechanisms are used to protect the integrity of audit tools"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ "$IS_EC2" -eq 1 ]]; then
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "not applicable on EC2 fleet instances (see file header)"
else
  marker_begin="# BEGIN Audit tools - CIS benchmark - Ansible-lockdown"
  if is_remediate && ! grep -qF "$marker_begin" /etc/aide.conf 2>/dev/null; then
    {
      echo "$marker_begin"
      for t in auditctl auditd augenrules aureport ausearch autrace; do
        echo "/usr/sbin/${t} p+i+n+u+g+s+b+acl+xattrs+sha512"
      done
      echo "# END Audit tools - CIS benchmark - Ansible-lockdown"
    } >> /etc/aide.conf
  fi
  grep -qF "$marker_begin" /etc/aide.conf 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "audit tool integrity rules present in aide.conf" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "audit tool integrity rules missing from aide.conf"
fi
