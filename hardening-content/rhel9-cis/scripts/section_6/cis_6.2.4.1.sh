#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 6.2.4.1 - /var/log file permissions.
SECTION="6"

id="6.2.4.1"; title="Ensure access to all logfiles has been configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  bad=""
  while IFS= read -r -d '' f; do
    mode=$(stat -c '%a' "$f" 2>/dev/null)
    [[ -z "$mode" ]] && continue
    if [[ "$f" =~ /var/log/(gdm|sssd) ]]; then
      is_remediate && chmod ug-x,o-rwx "$f" 2>/dev/null
      check_file_perms "$f" 660 || bad="${bad}${f} "
    elif [[ "$f" =~ /var/log/((u|b|w)tmp|lastlog) ]]; then
      is_remediate && chmod ug-x,o-wx "$f" 2>/dev/null
      new_mode=$(stat -c '%a' "$f" 2>/dev/null)
      [[ "${new_mode: -1}" =~ [2367] ]] && bad="${bad}${f} "
    else
      is_remediate && chmod u-x,g-wx,o-rwx "$f" 2>/dev/null
      check_file_perms "$f" 640 || bad="${bad}${f} "
    fi
  done < <(find /var/log -type f -print0 2>/dev/null)
  [[ -z "$bad" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "log file permissions correctly scoped" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "misconfigured log files: ${bad}"
fi
