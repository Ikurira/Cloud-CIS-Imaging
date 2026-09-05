#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 5.3.3.4.x - pam_unix options.
# Hashing algorithm ported from Images/defaults/main/main.yml (rhel9cis_passwd_hash_algo=sha512).
SECTION="5"
HASH_ALGO="sha512"

id="5.3.3.4.1"; title="Ensure pam_unix does not include nullok"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    ensure_authselect_custom_profile
    for f in system-auth password-auth; do
      [[ -f "${CIS_AUTHSELECT_DIR}/$f" ]] && sed -i -E 's/(pam_unix\.so[^\n]*)\s+nullok\b/\1/' "${CIS_AUTHSELECT_DIR}/$f"
    done
    authselect_apply
  fi
  grep -E 'pam_unix\.so' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null | grep -qw nullok \
    && log_result "$id" "$title" "$SECTION" "$level" "fail" "nullok still present on pam_unix.so line" \
    || log_result "$id" "$title" "$SECTION" "$level" "pass" "nullok not present"
fi

id="5.3.3.4.2"; title="Ensure pam_unix does not include remember"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    ensure_authselect_custom_profile
    for f in system-auth password-auth; do
      [[ -f "${CIS_AUTHSELECT_DIR}/$f" ]] && sed -i -E "/pam_unix\.so/ s/\s+remember=[0-9]+//" "${CIS_AUTHSELECT_DIR}/$f"
    done
    authselect_apply
  fi
  grep -E 'pam_unix\.so' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null | grep -q 'remember=' \
    && log_result "$id" "$title" "$SECTION" "$level" "fail" "remember= still present on pam_unix.so line (belongs on pam_pwhistory.so)" \
    || log_result "$id" "$title" "$SECTION" "$level" "pass" "remember= not present on pam_unix.so"
fi

id="5.3.3.4.3"; title="Ensure pam_unix includes a strong password hashing algorithm"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    ensure_authselect_custom_profile
    for f in system-auth password-auth; do
      set_pam_module_option "$f" pam_unix.so "${HASH_ALGO}" "$HASH_ALGO"
    done
    authselect_apply
  fi
  grep -qE "pam_unix\.so.*${HASH_ALGO}" /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null \
    && log_result "$id" "$title" "$SECTION" "$level" "pass" "${HASH_ALGO} present on pam_unix.so line" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "${HASH_ALGO} missing from pam_unix.so line"
fi

id="5.3.3.4.4"; title="Ensure pam_unix includes use_authtok"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    ensure_authselect_custom_profile
    for f in system-auth password-auth; do
      set_pam_module_option "$f" pam_unix.so use_authtok use_authtok
    done
    authselect_apply
  fi
  grep -qE 'pam_unix\.so.*use_authtok' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null \
    && log_result "$id" "$title" "$SECTION" "$level" "pass" "use_authtok present on pam_unix.so line" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "use_authtok missing from pam_unix.so line"
fi
