#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 6.2.2.x - journald forwarding/compression/storage.
SECTION="6"
FWD_CONF="/etc/systemd/journald.conf.d/forwardtosyslog.conf"
STORAGE_CONF="/etc/systemd/journald.conf.d/storage.conf"

id="6.2.2.2"; title="Ensure journald ForwardToSyslog is disabled"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    mkdir -p /etc/systemd/journald.conf.d
    printf '[Journal]\nForwardToSyslog=no\n' > "$FWD_CONF"
    chmod g-wx,o-rwx "$FWD_CONF"
    sed -i -E 's/^(\s*ForwardToSyslog\s*=.*)/#\1/' /etc/systemd/journald.conf 2>/dev/null
    systemctl restart systemd-journald >/dev/null 2>&1 || true
  fi
  grep -q '^ForwardToSyslog=no' "$FWD_CONF" 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "ForwardToSyslog=no" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "ForwardToSyslog not disabled"
fi

id="6.2.2.3"; title="Ensure journald Compress is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    mkdir -p /etc/systemd/journald.conf.d
    line_in_file "$STORAGE_CONF" '^\s*Compress\s*=' 'Compress=yes'
    grep -q '^\[Journal\]' "$STORAGE_CONF" 2>/dev/null || sed -i '1i [Journal]' "$STORAGE_CONF"
    chmod g-wx,o-rwx "$STORAGE_CONF"
    sed -i -E 's/^(\s*Compress\s*=.*)/#\1/' /etc/systemd/journald.conf 2>/dev/null
    systemctl restart systemd-journald >/dev/null 2>&1 || true
  fi
  grep -q '^Compress=yes' "$STORAGE_CONF" 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "Compress=yes" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "Compress not configured"
fi

id="6.2.2.4"; title="Ensure journald Storage is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    mkdir -p /etc/systemd/journald.conf.d
    line_in_file "$STORAGE_CONF" '^\s*Storage\s*=' 'Storage=persistent'
    grep -q '^\[Journal\]' "$STORAGE_CONF" 2>/dev/null || sed -i '1i [Journal]' "$STORAGE_CONF"
    chmod g-wx,o-rwx "$STORAGE_CONF"
    sed -i -E 's/^(\s*Storage\s*=.*)/#\1/' /etc/systemd/journald.conf 2>/dev/null
    systemctl restart systemd-journald >/dev/null 2>&1 || true
  fi
  grep -q '^Storage=persistent' "$STORAGE_CONF" 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "Storage=persistent" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "Storage not set to persistent"
fi
