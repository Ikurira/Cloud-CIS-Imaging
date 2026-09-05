#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 5.3.1.x - PAM/authselect/pwquality package versions.
SECTION="5"

# ensure_latest <id> <title> <pkg>
ensure_latest() {
  local id="$1" title="$2" pkg="$3" level=1
  if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"; return; fi
  is_remediate && dnf update -y "$pkg" >/dev/null 2>&1
  if package_installed "$pkg"; then
    pending=$(dnf check-update --quiet "$pkg" 2>/dev/null | grep -cvE '^\s*$')
    [[ "$pending" -eq 0 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "${pkg} up to date" \
      || log_result "$id" "$title" "$SECTION" "$level" "fail" "${pkg} has pending update"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "${pkg} not installed"
  fi
}

ensure_latest "5.3.1.1" "Ensure latest version of pam is installed" pam
ensure_latest "5.3.1.2" "Ensure latest version of authselect is installed" authselect
ensure_latest "5.3.1.3" "Ensure latest version of libpwquality is installed" libpwquality
