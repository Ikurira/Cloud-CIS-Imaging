#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 5.3.2.x - authselect profile and PAM module enablement.
# Uses a dedicated custom authselect profile (see ensure_authselect_custom_profile in
# lib/common.sh) rather than editing generated /etc/pam.d files directly, since RHEL8/9
# regenerate those from the selected authselect profile on every 'authselect apply-changes'.
SECTION="5"

id="5.3.2.1"; title="Ensure active authselect profile includes pam modules"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif ! command -v authselect >/dev/null 2>&1; then
  log_result "$id" "$title" "$SECTION" "$level" "fail" "authselect not installed"
else
  is_remediate && ensure_authselect_custom_profile
  authselect_current_profile_is_ours && log_result "$id" "$title" "$SECTION" "$level" "pass" "custom/${CIS_AUTHSELECT_PROFILE} profile selected" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "custom hardening authselect profile not active"
fi

id="5.3.2.2"; title="Ensure pam_faillock module is enabled"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && ensure_authselect_custom_profile
  authselect current 2>/dev/null | grep -q with-faillock && log_result "$id" "$title" "$SECTION" "$level" "pass" "with-faillock feature enabled" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "with-faillock feature not enabled"
fi

id="5.3.2.3"; title="Ensure pam_pwquality module is enabled"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if grep -rq 'pam_pwquality\.so' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "pam_pwquality.so present in PAM stack"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "pam_pwquality.so not found in PAM stack (base authselect profile should include it by default)"
  fi
fi

id="5.3.2.4"; title="Ensure pam_pwhistory module is enabled"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && ensure_authselect_custom_profile
  if grep -rq 'pam_pwhistory\.so' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "pam_pwhistory.so present in PAM stack"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "pam_pwhistory.so not found in PAM stack"
  fi
fi

id="5.3.2.5"; title="Ensure pam_unix module is enabled"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if grep -rq 'pam_unix\.so' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "pam_unix.so present in PAM stack"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "pam_unix.so not found in PAM stack"
  fi
fi
