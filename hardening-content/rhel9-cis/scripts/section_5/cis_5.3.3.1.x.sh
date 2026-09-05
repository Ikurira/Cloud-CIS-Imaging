#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 5.3.3.1.x - pam_faillock (/etc/security/faillock.conf).
# Defaults ported from Images/defaults/main/main.yml: deny=5, unlock_time=900,
# root lockout option=even_deny_root.
SECTION="5"
FAILLOCK_CONF="/etc/security/faillock.conf"
DENY=5
UNLOCK_TIME=900

id="5.3.3.1.1"; title="Ensure password failed attempts lockout is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && line_in_file "$FAILLOCK_CONF" '^\s*#?\s*deny\s*=' "deny = ${DENY}"
  v=$(grep -E '^\s*deny\s*=' "$FAILLOCK_CONF" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d ' ')
  [[ -n "$v" && "$v" -le "$DENY" && "$v" -ge 1 ]] 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "deny=${v}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "deny=${v:-unset} (expected 1-${DENY})"
fi

id="5.3.3.1.2"; title="Ensure password unlock time is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && line_in_file "$FAILLOCK_CONF" '^\s*#?\s*unlock_time\s*=' "unlock_time = ${UNLOCK_TIME}"
  v=$(grep -E '^\s*unlock_time\s*=' "$FAILLOCK_CONF" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d ' ')
  [[ "$v" == "0" || ( -n "$v" && "$v" -ge "$UNLOCK_TIME" ) ]] 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "unlock_time=${v}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "unlock_time=${v:-unset} (expected 0 or >=${UNLOCK_TIME})"
fi

id="5.3.3.1.3"; title="Ensure password failed attempts lockout includes root account"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && line_in_file "$FAILLOCK_CONF" '^\s*#?\s*even_deny_root\b.*' 'even_deny_root'
  grep -qE '^\s*even_deny_root\b' "$FAILLOCK_CONF" 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "even_deny_root set" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "even_deny_root not set in ${FAILLOCK_CONF}"
fi
