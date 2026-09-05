#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 5.4.1.x - Shadow password suite parameters (/etc/login.defs + existing accounts).
# Defaults ported from Images/defaults/main/main.yml: max=365, min=7, warn=7, inactive lock=30 days,
# hash algo=sha512.
SECTION="5"
PASS_MAX_DAYS=365
PASS_MIN_DAYS=7
PASS_WARN_AGE=7
INACTIVE_LOCK_DAYS=30
HASH_ALGO="sha512"

id="5.4.1.1"; title="Ensure password expiration is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && line_in_file /etc/login.defs '^\s*PASS_MAX_DAYS\s+' "PASS_MAX_DAYS   ${PASS_MAX_DAYS}"
  v=$(awk '/^PASS_MAX_DAYS/{print $2}' /etc/login.defs 2>/dev/null)
  [[ -n "$v" && "$v" -le "$PASS_MAX_DAYS" && "$v" -gt 0 ]] 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "PASS_MAX_DAYS=${v}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "PASS_MAX_DAYS=${v:-unset}"
fi

id="5.4.1.2"; title="Ensure minimum password days is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && line_in_file /etc/login.defs '^\s*PASS_MIN_DAYS\s+' "PASS_MIN_DAYS   ${PASS_MIN_DAYS}"
  v=$(awk '/^PASS_MIN_DAYS/{print $2}' /etc/login.defs 2>/dev/null)
  [[ -n "$v" && "$v" -ge "$PASS_MIN_DAYS" ]] 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "PASS_MIN_DAYS=${v}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "PASS_MIN_DAYS=${v:-unset}"
fi

id="5.4.1.3"; title="Ensure password expiration warning days is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && line_in_file /etc/login.defs '^\s*PASS_WARN_AGE\s+' "PASS_WARN_AGE   ${PASS_WARN_AGE}"
  v=$(awk '/^PASS_WARN_AGE/{print $2}' /etc/login.defs 2>/dev/null)
  [[ -n "$v" && "$v" -ge "$PASS_WARN_AGE" ]] 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "PASS_WARN_AGE=${v}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "PASS_WARN_AGE=${v:-unset}"
fi

id="5.4.1.4"; title="Ensure strong password hashing algorithm is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { ensure_authselect_custom_profile; for f in system-auth password-auth; do set_pam_module_option "$f" pam_unix.so "$HASH_ALGO" "$HASH_ALGO"; done; authselect_apply; }
  grep -qE "pam_unix\.so.*${HASH_ALGO}" /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null \
    && log_result "$id" "$title" "$SECTION" "$level" "pass" "${HASH_ALGO} configured on pam_unix.so" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "${HASH_ALGO} not configured on pam_unix.so"
fi

id="5.4.1.5"; title="Ensure inactive password lock is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && useradd -D -f "$INACTIVE_LOCK_DAYS" >/dev/null 2>&1
  v=$(useradd -D 2>/dev/null | awk -F= '/^INACTIVE/{print $2}')
  [[ -n "$v" && "$v" != "-1" && "$v" -le "$INACTIVE_LOCK_DAYS" && "$v" -ge 0 ]] 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "INACTIVE=${v}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "INACTIVE=${v:-unset} (expected 0-${INACTIVE_LOCK_DAYS})"
fi

id="5.4.1.6"; title="Ensure all users last password change date is in the past"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  today_epoch_days=$(( $(date +%s) / 86400 ))
  future_users=""
  while IFS=: read -r user _ _ lastchg _; do
    [[ -n "$lastchg" && "$lastchg" =~ ^[0-9]+$ ]] || continue
    if [[ "$lastchg" -gt "$today_epoch_days" ]]; then
      future_users="${future_users}${user} "
      if is_remediate; then
        chage -d "$(date +%Y-%m-%d)" "$user" >/dev/null 2>&1
      fi
    fi
  done < <(getent shadow 2>/dev/null || cat /etc/shadow 2>/dev/null)
  if [[ -z "$future_users" ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "no accounts with a future last-changed date"
  elif is_remediate; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "expired future-dated password for: ${future_users}"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "accounts with future last-changed date: ${future_users}"
  fi
fi
