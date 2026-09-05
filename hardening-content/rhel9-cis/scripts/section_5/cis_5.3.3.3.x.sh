#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 5.3.3.3.x - pam_pwhistory (/etc/security/pwhistory.conf).
# remember value ported from Images/defaults/main/main.yml (rhel9cis_pamd_pwhistory_remember=24).
SECTION="5"
PWHISTORY_CONF="/etc/security/pwhistory.conf"
REMEMBER=24

id="5.3.3.3.1"; title="Ensure password history remember is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && line_in_file "$PWHISTORY_CONF" '^\s*#?\s*remember\s*=' "remember = ${REMEMBER}"
  v=$(grep -E '^\s*remember\s*=' "$PWHISTORY_CONF" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d ' ')
  [[ -n "$v" && "$v" -ge "$REMEMBER" ]] 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "remember=${v}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "remember=${v:-unset} (expected >=${REMEMBER})"
fi

id="5.3.3.3.2"; title="Ensure password history is enforced for the root user"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && line_in_file "$PWHISTORY_CONF" '^\s*#?\s*enforce_for_root\b.*' 'enforce_for_root'
  grep -qE '^\s*enforce_for_root\b' "$PWHISTORY_CONF" 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "enforce_for_root set" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "enforce_for_root not set in ${PWHISTORY_CONF}"
fi

id="5.3.3.3.3"; title="Ensure pam_pwhistory includes use_authtok"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    ensure_authselect_custom_profile
    for f in system-auth password-auth; do
      set_pam_module_option "$f" pam_pwhistory.so use_authtok use_authtok
    done
    authselect_apply
  fi
  grep -qE 'pam_pwhistory\.so.*use_authtok' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null \
    && log_result "$id" "$title" "$SECTION" "$level" "pass" "use_authtok present on pam_pwhistory.so line" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "use_authtok missing from pam_pwhistory.so line"
fi
