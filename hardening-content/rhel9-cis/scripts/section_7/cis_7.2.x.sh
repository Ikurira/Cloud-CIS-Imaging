#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 7.2.x - Local user and group settings.
SECTION="7"
UID_MIN=$(awk '/^UID_MIN/{print $2}' /etc/login.defs 2>/dev/null); UID_MIN="${UID_MIN:-1000}"

id="7.2.1"; title="Ensure accounts in /etc/passwd use shadowed passwords"; level=1
offenders=$(awk -F: '($2 != "x") {print $1}' /etc/passwd)
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ -n "$offenders" ]]; then
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "manual review control: accounts without shadowed passwords in /etc/passwd: ${offenders} — requires operator to run pwconv"
else
  log_result "$id" "$title" "$SECTION" "$level" "pass" "all accounts use shadowed passwords"
fi

id="7.2.2"; title="Ensure /etc/shadow password fields are not empty"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  empty_accounts=$(awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null)
  if [[ -n "$empty_accounts" ]]; then
    is_remediate && for u in $empty_accounts; do passwd -l "$u" >/dev/null 2>&1; done
    if is_remediate; then
      log_result "$id" "$title" "$SECTION" "$level" "pass" "locked accounts with empty password fields: ${empty_accounts}"
    else
      log_result "$id" "$title" "$SECTION" "$level" "fail" "accounts with empty password fields: ${empty_accounts}"
    fi
  else
    log_result "$id" "$title" "$SECTION" "$level" "pass" "no accounts with empty password fields"
  fi
fi

id="7.2.3"; title="Ensure all groups in /etc/passwd exist in /etc/group"; level=1
missing=""
for gid in $(awk -F: '{print $4}' /etc/passwd | sort -u); do
  grep -qE "^[^:]*:[^:]*:${gid}:" /etc/group || missing="${missing}${gid} "
done
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ -n "$missing" ]]; then
  log_result "$id" "$title" "$SECTION" "$level" "fail" "GIDs referenced in /etc/passwd but missing from /etc/group: ${missing}"
else
  log_result "$id" "$title" "$SECTION" "$level" "pass" "all passwd GIDs exist in /etc/group"
fi

id="7.2.4"; title="Ensure no duplicate UIDs exist"; level=1
dupes=$(awk -F: '{print $3}' /etc/passwd | sort | uniq -d | tr '\n' ' ')
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ -n "$dupes" ]]; then log_result "$id" "$title" "$SECTION" "$level" "fail" "duplicate UIDs: ${dupes}"
else log_result "$id" "$title" "$SECTION" "$level" "pass" "no duplicate UIDs"; fi

id="7.2.5"; title="Ensure no duplicate GIDs exist"; level=1
dupes=$(awk -F: '{print $3}' /etc/group | sort | uniq -d | tr '\n' ' ')
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ -n "$dupes" ]]; then log_result "$id" "$title" "$SECTION" "$level" "fail" "duplicate GIDs: ${dupes}"
else log_result "$id" "$title" "$SECTION" "$level" "pass" "no duplicate GIDs"; fi

id="7.2.6"; title="Ensure no duplicate user names exist"; level=1
dupes=$(awk -F: '{print $1}' /etc/passwd | sort | uniq -d | tr '\n' ' ')
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ -n "$dupes" ]]; then log_result "$id" "$title" "$SECTION" "$level" "fail" "duplicate user names: ${dupes}"
else log_result "$id" "$title" "$SECTION" "$level" "pass" "no duplicate user names"; fi

id="7.2.7"; title="Ensure no duplicate group names exist"; level=1
dupes=$(awk -F: '{print $1}' /etc/group | sort | uniq -d | tr '\n' ' ')
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ -n "$dupes" ]]; then log_result "$id" "$title" "$SECTION" "$level" "fail" "duplicate group names: ${dupes}"
else log_result "$id" "$title" "$SECTION" "$level" "pass" "no duplicate group names"; fi

id="7.2.8"; title="Ensure local interactive user home directories are configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  bad=""
  while IFS=: read -r user _ uid _ _ home shell; do
    [[ "$uid" -lt "$UID_MIN" || "$shell" =~ nologin|false$ ]] 2>/dev/null && continue
    if [[ ! -d "$home" ]]; then
      bad="${bad}${user}:no-home-dir "
      is_remediate && mkdir -p "$home" && chown "$user" "$home"
      continue
    fi
    mode=$(stat -c '%a' "$home" 2>/dev/null)
    if [[ "${mode: -2:1}" =~ [2367] || "${mode: -1}" =~ [2367] ]]; then
      is_remediate && chmod g-w,o-rwx "$home" 2>/dev/null || bad="${bad}${user}:perms "
    fi
    owner=$(stat -c '%U' "$home" 2>/dev/null)
    [[ "$owner" != "$user" ]] && { is_remediate && chown "$user" "$home" 2>/dev/null; }
  done < /etc/passwd
  [[ -z "$bad" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "interactive user home directories correctly configured" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "issues: ${bad}"
fi

id="7.2.9"; title="Ensure local interactive user dot files access is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  bad=""
  while IFS=: read -r user _ uid _ _ home shell; do
    [[ "$uid" -lt "$UID_MIN" || "$shell" =~ nologin|false$ ]] 2>/dev/null && continue
    [[ -d "$home" ]] || continue
    for f in "$home"/.[a-zA-Z0-9]*; do
      [[ -f "$f" ]] || continue
      mode=$(stat -c '%a' "$f" 2>/dev/null)
      if [[ "${mode: -2:1}" =~ [2367] || "${mode: -1}" =~ [2367] ]]; then
        bad="${bad}${f} "
        is_remediate && chmod go-w "$f" 2>/dev/null
      fi
    done
  done < /etc/passwd
  if is_remediate; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "removed group/other write from dot files: ${bad:-none found}"
  else
    [[ -z "$bad" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "no group/other-writable dot files found" \
      || log_result "$id" "$title" "$SECTION" "$level" "fail" "group/other-writable dot files: ${bad}"
  fi
fi
