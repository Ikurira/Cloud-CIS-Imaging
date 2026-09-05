#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 2.4.x - cron and at.
SECTION="2"

id="2.4.1.1"; title="Ensure cron daemon is enabled and active"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && enable_service crond
  service_active_and_enabled crond && log_result "$id" "$title" "$SECTION" "$level" "pass" "crond enabled and active" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "crond not enabled/active"
fi

# cron_dir_perms <id> <title> <path>
cron_dir_perms() {
  local id="$1" title="$2" path="$3" level=1
  if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"; return; fi
  [[ -e "$path" ]] || { log_result "$id" "$title" "$SECTION" "$level" "skipped" "${path} does not exist"; return; }
  is_remediate && set_file_perms "$path" 700 root root
  if check_file_perms "$path" 700; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "${path} is mode 700 owned root:root"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "${path} is not mode 700"
  fi
}

cron_dir_perms "2.4.1.2" "Ensure permissions on /etc/crontab are configured"    /etc/crontab
cron_dir_perms "2.4.1.3" "Ensure permissions on /etc/cron.hourly are configured"  /etc/cron.hourly
cron_dir_perms "2.4.1.4" "Ensure permissions on /etc/cron.daily are configured"   /etc/cron.daily
cron_dir_perms "2.4.1.5" "Ensure permissions on /etc/cron.weekly are configured"  /etc/cron.weekly
cron_dir_perms "2.4.1.6" "Ensure permissions on /etc/cron.monthly are configured" /etc/cron.monthly
cron_dir_perms "2.4.1.7" "Ensure permissions on /etc/cron.d are configured"       /etc/cron.d

# restrict_to_allow_list <id> <title> <deny_path> <allow_path>
restrict_to_allow_list() {
  local id="$1" title="$2" deny="$3" allow="$4" level=1
  if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"; return; fi
  if is_remediate; then
    [[ -f "$deny" ]] && rm -f "$deny"
    [[ -f "$allow" ]] || touch "$allow"
    set_file_perms "$allow" 600 root root
  fi
  if [[ ! -f "$deny" ]] && [[ -f "$allow" ]] && check_file_perms "$allow" 600; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "${deny} absent, ${allow} present mode 600"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "${deny} present or ${allow} missing/misconfigured"
  fi
}

restrict_to_allow_list "2.4.1.8" "Ensure crontab is restricted to authorized users" /etc/cron.deny /etc/cron.allow
restrict_to_allow_list "2.4.2.1" "Ensure at is restricted to authorized users"      /etc/at.deny   /etc/at.allow
