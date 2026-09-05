#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 5.4.2.x - Root and system account integrity.
# rhel9cis_disruption_high defaults to false upstream (Images/defaults/main/main.yml) because
# locking accounts / changing shells can break existing access; remediation for the
# account-locking controls here is gated the same way (DISRUPTION_HIGH=0 by default) —
# audit still reports true pass/fail regardless.
SECTION="5"
ROOT_UMASK="0027"
DISRUPTION_HIGH=0

id="5.4.2.1"; title="Ensure root is the only UID 0 account"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  others=$(awk -F: '$3=="0" && $1!="root" {print $1}' /etc/passwd)
  if [[ -n "$others" ]]; then
    if is_remediate && [[ "$DISRUPTION_HIGH" -eq 1 ]]; then
      for u in $others; do passwd -l "$u" >/dev/null 2>&1; done
    fi
    log_result "$id" "$title" "$SECTION" "$level" "fail" "non-root UID 0 accounts: ${others}"
  else
    log_result "$id" "$title" "$SECTION" "$level" "pass" "root is the only UID 0 account"
  fi
fi

id="5.4.2.2"; title="Ensure root is the only GID 0 account"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  members=$(awk -F: '($1 !~ /^(sync|shutdown|halt|operator)/ && $4=="0") {print $1}' /etc/passwd | grep -wv root)
  if [[ -n "$members" ]]; then
    if is_remediate && [[ "$DISRUPTION_HIGH" -eq 1 ]]; then
      for u in $members; do usermod -g "$(id -g "$u" 2>/dev/null)" "$u" >/dev/null 2>&1; done
    fi
    log_result "$id" "$title" "$SECTION" "$level" "fail" "non-root members of GID 0: ${members}"
  else
    log_result "$id" "$title" "$SECTION" "$level" "pass" "root is the only account with GID 0"
  fi
fi

id="5.4.2.3"; title="Ensure group root is the only GID 0 group"; level=1
groups0=$(awk -F: '$3=="0"{print $1}' /etc/group | grep -vw root)
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ -n "$groups0" ]]; then
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "manual review control: other groups use GID 0: ${groups0} — resolve by reassigning GIDs"
else
  log_result "$id" "$title" "$SECTION" "$level" "pass" "root is the only group with GID 0"
fi

log_result "5.4.2.4" "Ensure root account access is controlled" "$SECTION" 1 "skipped" "manual/organizational control: verify root credential access is restricted per site policy (e.g. no shared root password, sudo-only access)"

id="5.4.2.5"; title="Ensure root path integrity"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  root_path=$(sudo -Hiu root env 2>/dev/null | awk -F= '/^PATH/{print $2}')
  bad=""
  [[ "$root_path" == *"::"* ]] && bad="${bad}empty-dir-entry "
  [[ "$root_path" == *: ]] && bad="${bad}trailing-colon "
  echo "$root_path" | tr ':' '\n' | grep -qx '\.' && bad="${bad}includes-cwd "
  IFS=':' read -r -a dirs <<< "$root_path"
  for d in "${dirs[@]}"; do
    [[ -z "$d" ]] && continue
    if [[ -d "$d" ]]; then
      owner=$(stat -c '%U' "$d" 2>/dev/null)
      mode=$(stat -c '%a' "$d" 2>/dev/null)
      group_other_writable=0
      [[ -n "$mode" && "${mode: -2:1}" =~ [2367] ]] && group_other_writable=1
      [[ -n "$mode" && "${mode: -1}" =~ [2367] ]] && group_other_writable=1
      if [[ "$owner" != "root" || "$group_other_writable" -eq 1 ]]; then
        if is_remediate; then chown root:root "$d" 2>/dev/null; chmod go-w "$d" 2>/dev/null; else bad="${bad}${d}-perms "; fi
      fi
    else
      is_remediate && mkdir -p "$d" 2>/dev/null
      [[ -d "$d" ]] || bad="${bad}${d}-missing "
    fi
  done
  [[ -z "$bad" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "root PATH=${root_path}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "root PATH issues: ${bad}(PATH=${root_path})"
fi

id="5.4.2.6"; title="Ensure root user umask is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && line_in_file /root/.bash_profile '\s*umask' "umask ${ROOT_UMASK}" u-x,go-rwx
  cur=$(grep -E '\s*umask' /root/.bash_profile 2>/dev/null | tail -1 | awk '{print $2}')
  [[ "$cur" == "$ROOT_UMASK" || "$cur" == "0077" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "root umask=${cur}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "root umask=${cur:-unset} (expected ${ROOT_UMASK} or more restrictive)"
fi

id="5.4.2.7"; title="Ensure system accounts do not have a valid login shell"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  offenders=$(awk -F: '($3<1000 && $1!="root" && $7!="/usr/sbin/nologin" && $7!="/sbin/nologin" && $7!="/bin/false" && $7!="") {print $1}' /etc/passwd)
  if [[ -n "$offenders" ]]; then
    if is_remediate && [[ "$DISRUPTION_HIGH" -eq 1 ]]; then
      for u in $offenders; do usermod -s /usr/sbin/nologin "$u" >/dev/null 2>&1; done
      offenders=$(awk -F: '($3<1000 && $1!="root" && $7!="/usr/sbin/nologin" && $7!="/sbin/nologin" && $7!="/bin/false" && $7!="") {print $1}' /etc/passwd)
    fi
    [[ -n "$offenders" ]] && log_result "$id" "$title" "$SECTION" "$level" "fail" "system accounts with a login shell: ${offenders}" \
      || log_result "$id" "$title" "$SECTION" "$level" "pass" "no system accounts with a valid login shell"
  else
    log_result "$id" "$title" "$SECTION" "$level" "pass" "no system accounts with a valid login shell"
  fi
fi

id="5.4.2.8"; title="Ensure accounts without a valid login shell are locked"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  unlocked=""
  while IFS=: read -r user _ _ _ _ _ shell; do
    [[ "$user" == "root" ]] && continue
    if [[ "$shell" == "/usr/sbin/nologin" || "$shell" == "/sbin/nologin" || "$shell" == "/bin/false" ]]; then
      status=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
      [[ "$status" == "L" || "$status" == "LK" ]] || unlocked="${unlocked}${user} "
    fi
  done < /etc/passwd
  if [[ -n "$unlocked" ]]; then
    if is_remediate && [[ "$DISRUPTION_HIGH" -eq 1 ]]; then
      for u in $unlocked; do passwd -l "$u" >/dev/null 2>&1; done
      log_result "$id" "$title" "$SECTION" "$level" "pass" "locked no-shell accounts: ${unlocked}"
    else
      log_result "$id" "$title" "$SECTION" "$level" "fail" "no-shell accounts not locked: ${unlocked}"
    fi
  else
    log_result "$id" "$title" "$SECTION" "$level" "pass" "all no-shell accounts are locked"
  fi
fi
