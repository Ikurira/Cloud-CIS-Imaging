#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 7.1.x - System file permissions.
SECTION="7"

# system_file_perms <id> <title> <path> <mode> <owner> <group>
system_file_perms() {
  local id="$1" title="$2" path="$3" mode="$4" owner="$5" group="$6" level=1
  if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"; return; fi
  [[ -e "$path" ]] || { log_result "$id" "$title" "$SECTION" "$level" "skipped" "${path} does not exist"; return; }
  is_remediate && set_file_perms "$path" "$mode" "$owner" "$group"
  if check_file_perms "$path" "$mode" && [[ "$(stat -c '%U:%G' "$path" 2>/dev/null)" == "${owner}:${group}" ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "${path} is ${mode} ${owner}:${group}"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "${path} is $(stat -c '%a %U:%G' "$path" 2>/dev/null) (expected ${mode} ${owner}:${group})"
  fi
}

system_file_perms "7.1.1"  "Ensure permissions on /etc/passwd are configured"    /etc/passwd            644 root root
system_file_perms "7.1.2"  "Ensure permissions on /etc/passwd- are configured"   /etc/passwd-           644 root root
system_file_perms "7.1.3"  "Ensure permissions on /etc/group are configured"     /etc/group             644 root root
system_file_perms "7.1.4"  "Ensure permissions on /etc/group- are configured"    /etc/group-            644 root root
system_file_perms "7.1.5"  "Ensure permissions on /etc/shadow are configured"    /etc/shadow            0 root root
system_file_perms "7.1.6"  "Ensure permissions on /etc/shadow- are configured"   /etc/shadow-           0 root root
system_file_perms "7.1.7"  "Ensure permissions on /etc/gshadow are configured"   /etc/gshadow           0 root root
system_file_perms "7.1.8"  "Ensure permissions on /etc/gshadow- are configured"  /etc/gshadow-          0 root root
system_file_perms "7.1.9"  "Ensure permissions on /etc/shells are configured"    /etc/shells            644 root root
system_file_perms "7.1.10" "Ensure permissions on /etc/security/opasswd are configured" /etc/security/opasswd 0 root root

id="7.1.11"; title="Ensure world writable files and directories are secured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  found=""
  while IFS= read -r -d '' f; do
    found="${found}${f} "
    if is_remediate; then
      if [[ -d "$f" ]]; then chmod o-w,+t "$f" 2>/dev/null; else chmod o-w "$f" 2>/dev/null; fi
    fi
  done < <(find / -xdev \( -type f -o -type d \) -perm -0002 -print0 2>/dev/null)
  if is_remediate; then
    still=""
    while IFS= read -r -d '' f; do still="${still}${f} "; done < <(find / -xdev \( -type f -o -type d \) -perm -0002 -print0 2>/dev/null)
    [[ -z "$still" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "no world-writable files/dirs remain" \
      || log_result "$id" "$title" "$SECTION" "$level" "fail" "still world-writable: ${still}"
  else
    [[ -z "$found" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "no world-writable files/dirs found" \
      || log_result "$id" "$title" "$SECTION" "$level" "fail" "world-writable: ${found}"
  fi
fi

id="7.1.12"; title="Ensure no files or directories without an owner and a group exist"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  orphans=""
  while IFS= read -r -d '' f; do
    orphans="${orphans}${f} "
    is_remediate && chown root:root "$f" 2>/dev/null
  done < <(find / -xdev \( -nouser -o -nogroup \) -print0 2>/dev/null)
  if is_remediate; then
    still=$(find / -xdev \( -nouser -o -nogroup \) 2>/dev/null | tr '\n' ' ')
    [[ -z "$still" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "no orphaned files remain" \
      || log_result "$id" "$title" "$SECTION" "$level" "fail" "still orphaned: ${still}"
  else
    [[ -z "$orphans" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "no orphaned files/directories found" \
      || log_result "$id" "$title" "$SECTION" "$level" "fail" "orphaned: ${orphans}"
  fi
fi

id="7.1.13"; title="Ensure SUID and SGID files are reviewed"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  found=$(find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | tr '\n' ' ')
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "manual review control: discovered setuid/setgid binaries: ${found:-none} — confirm each is expected and covered by 6.3.3.6's privileged-command audit rules"
fi
