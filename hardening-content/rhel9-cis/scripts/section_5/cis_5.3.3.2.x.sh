#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 5.3.3.2.x - pwquality drop-in files under /etc/security/pwquality.conf.d/.
# File names and values ported verbatim from Images/defaults/main/main.yml.
SECTION="5"
PWQ_DIR="/etc/security/pwquality.conf.d"

# pwq_setting <id> <title> <file> <key> <value>
pwq_setting() {
  local id="$1" title="$2" file="${PWQ_DIR}/$3" key="$4" value="$5" level=1
  if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"; return; fi
  if is_remediate; then
    mkdir -p "$PWQ_DIR"
    line_in_file "$file" "^\s*#?\s*${key}\s*=" "${key} = ${value}"
  fi
  local cur
  cur=$(grep -E "^\s*${key}\s*=" "$file" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d ' ')
  if [[ "$value" -lt 0 ]]; then
    [[ -n "$cur" && "$cur" -le "$value" ]] 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "${key}=${cur}" \
      || log_result "$id" "$title" "$SECTION" "$level" "fail" "${key}=${cur:-unset} (expected <=${value})"
  else
    [[ -n "$cur" && "$cur" -ge "$value" ]] 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "${key}=${cur}" \
      || log_result "$id" "$title" "$SECTION" "$level" "fail" "${key}=${cur:-unset} (expected >=${value})"
  fi
}

pwq_setting "5.3.3.2.1" "Ensure password number of changed characters is configured" 50-pwdifok.conf       difok  2
pwq_setting "5.3.3.2.2" "Ensure password length is configured"                        50-pwlength.conf      minlen 14

id="5.3.3.2.3"; title="Ensure password complexity is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  file="${PWQ_DIR}/50-pwcomplexity.conf"
  if is_remediate; then
    mkdir -p "$PWQ_DIR"
    line_in_file "$file" '^\s*#?\s*minclass\s*=' 'minclass = 4'
  fi
  cur=$(grep -E '^\s*minclass\s*=' "$file" 2>/dev/null | tail -1 | cut -d= -f2 | tr -d ' ')
  [[ -n "$cur" && "$cur" -ge 4 ]] 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "minclass=${cur}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "minclass=${cur:-unset} (expected >=4)"
fi

pwq_setting "5.3.3.2.4" "Ensure password same consecutive characters is configured" 50-pwrepeat.conf     maxrepeat 3
pwq_setting "5.3.3.2.5" "Ensure password maximum sequential characters is configured" 50-pwmaxsequence.conf maxsequence 3
pwq_setting "5.3.3.2.6" "Ensure password dictionary check is enabled"               50-pwdictcheck.conf  dictcheck 1

id="5.3.3.2.7"; title="Ensure password quality is enforced for the root user"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  file="${PWQ_DIR}/50-pwquality_enforce.conf"
  if is_remediate; then
    mkdir -p "$PWQ_DIR"
    grep -qxF 'enforce_for_root' "$file" 2>/dev/null || echo 'enforce_for_root' >> "$file"
  fi
  grep -qxF 'enforce_for_root' "$file" 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "enforce_for_root set" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "enforce_for_root not set in ${file}"
fi
