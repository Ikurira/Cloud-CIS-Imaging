#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 1.7.x - Warning banners.
# Banner text default ported from Images/defaults/main/main.yml (rhel9cis_warning_banner).
SECTION="1"
BANNER_TEXT="Authorized users only. All activity may be monitored and reported."

# set_banner <id> <title> <path>
set_banner() {
  local id="$1" title="$2" path="$3" level=1
  if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"; return; fi
  if is_remediate; then
    printf '%s\n' "$BANNER_TEXT" > "$path"
    set_file_perms "$path" 644 root root
  fi
  if [[ -f "$path" ]] && grep -qF "$BANNER_TEXT" "$path"; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "${path} contains configured warning banner"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "${path} missing or does not match configured banner text"
  fi
}

# set_banner_perms <id> <title> <path>
set_banner_perms() {
  local id="$1" title="$2" path="$3" level=1
  if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"; return; fi
  [[ -f "$path" ]] || { log_result "$id" "$title" "$SECTION" "$level" "skipped" "${path} does not exist"; return; }
  is_remediate && set_file_perms "$path" 644 root root
  if check_file_perms "$path" 644; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "${path} is mode 644 owned root:root"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "${path} is not mode 644"
  fi
}

set_banner "1.7.1" "Ensure message of the day is configured properly" /etc/motd
set_banner "1.7.2" "Ensure local login warning banner is configured properly" /etc/issue
set_banner "1.7.3" "Ensure remote login warning banner is configured properly" /etc/issue.net
set_banner_perms "1.7.4" "Ensure access to /etc/motd is configured" /etc/motd
set_banner_perms "1.7.5" "Ensure access to /etc/issue is configured" /etc/issue
set_banner_perms "1.7.6" "Ensure access to /etc/issue.net is configured" /etc/issue.net
