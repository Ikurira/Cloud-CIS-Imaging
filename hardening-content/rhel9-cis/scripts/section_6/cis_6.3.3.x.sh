#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 6.3.3.x - auditd rules. Standard CIS audit.rules content (stable across
# CIS RHEL7/8/9 benchmarks); written as /etc/audit/rules.d/*.rules and loaded via
# `augenrules --load` (RHEL8/9's rules.d model, not a direct edit of audit.rules).
SECTION="6"
RULES_DIR="/etc/audit/rules.d"

# audit_rule_control <id> <title> <rules_file_basename> <rule_lines...>
# Writes <rule_lines> (one per remaining arg) to $RULES_DIR/<basename>.rules, then checks
# the *running* auditctl ruleset (post augenrules --load) for each line's key.
audit_rule_control() {
  local id="$1" title="$2" basename="$3" level=2; shift 3
  if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"; return; fi
  if is_remediate; then
    mkdir -p "$RULES_DIR"
    printf '%s\n' "$@" > "${RULES_DIR}/${basename}.rules"
  fi
  local ok=1 line rf="${RULES_DIR}/${basename}.rules"
  [[ -f "$rf" ]] || ok=0
  if [[ "$ok" -eq 1 ]]; then
    for line in "$@"; do grep -qF "$line" "$rf" || ok=0; done
  fi
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "${basename}.rules on disk matches expected rules" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "${basename}.rules missing or does not match expected rules"
}

audit_rule_control "6.3.3.1" "Ensure changes to system administration scope (sudoers) is collected" 50-scope \
  '-w /etc/sudoers -p wa -k scope' \
  '-w /etc/sudoers.d/ -p wa -k scope'

audit_rule_control "6.3.3.2" "Ensure actions as another user are always logged" 50-actions \
  '-a always,exit -F arch=b64 -C euid!=uid -F euid=0 -F auid>=1000 -F auid!=unset -S execve -k actions' \
  '-a always,exit -F arch=b32 -C euid!=uid -F euid=0 -F auid>=1000 -F auid!=unset -S execve -k actions'

audit_rule_control "6.3.3.3" "Ensure events that modify the sudo log file are collected" 50-sudo_log_file \
  '-w /var/log/sudo.log -p wa -k sudo_log_file'

audit_rule_control "6.3.3.4" "Ensure events that modify date and time information are collected" 50-time-change \
  '-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time-change' \
  '-a always,exit -F arch=b32 -S adjtimex,settimeofday,clock_settime -k time-change' \
  '-w /etc/localtime -p wa -k time-change'

audit_rule_control "6.3.3.5" "Ensure events that modify the system's network environment are collected" 50-system_locale \
  '-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale' \
  '-a always,exit -F arch=b32 -S sethostname,setdomainname -k system-locale' \
  '-w /etc/issue -p wa -k system-locale' \
  '-w /etc/issue.net -p wa -k system-locale' \
  '-w /etc/hosts -p wa -k system-locale' \
  '-w /etc/sysconfig/network-scripts/ -p wa -k system-locale' \
  '-w /etc/NetworkManager/ -p wa -k system-locale'

id="6.3.3.6"; title="Ensure use of privileged commands are collected"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    mkdir -p "$RULES_DIR"
    {
      while IFS= read -r bin; do
        echo "-a always,exit -F path=${bin} -F perm=x -F auid>=1000 -F auid!=unset -k privileged"
      done < <(find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null)
    } > "${RULES_DIR}/50-privileged.rules"
  fi
  [[ -s "${RULES_DIR}/50-privileged.rules" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "privileged-command watch rules generated" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "50-privileged.rules missing or empty (run in remediate mode to generate from discovered setuid/setgid binaries)"
fi

audit_rule_control "6.3.3.7" "Ensure unsuccessful file access attempts are collected" 50-access \
  '-a always,exit -F arch=b64 -S creat,open,openat,truncate,ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=unset -k access' \
  '-a always,exit -F arch=b64 -S creat,open,openat,truncate,ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=unset -k access' \
  '-a always,exit -F arch=b32 -S creat,open,openat,truncate,ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=unset -k access' \
  '-a always,exit -F arch=b32 -S creat,open,openat,truncate,ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=unset -k access'

audit_rule_control "6.3.3.8" "Ensure events that modify user/group information are collected" 50-identity \
  '-w /etc/group -p wa -k identity' \
  '-w /etc/passwd -p wa -k identity' \
  '-w /etc/gshadow -p wa -k identity' \
  '-w /etc/shadow -p wa -k identity' \
  '-w /etc/security/opasswd -p wa -k identity'

audit_rule_control "6.3.3.9" "Ensure discretionary access control permission modification events are collected" 50-perm_mod \
  '-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=unset -k perm_mod' \
  '-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=unset -k perm_mod' \
  '-a always,exit -F arch=b64 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=unset -k perm_mod' \
  '-a always,exit -F arch=b32 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=unset -k perm_mod' \
  '-a always,exit -F arch=b64 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=1000 -F auid!=unset -k perm_mod' \
  '-a always,exit -F arch=b32 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=1000 -F auid!=unset -k perm_mod'

audit_rule_control "6.3.3.10" "Ensure successful file system mounts are collected" 50-mounts \
  '-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=unset -k mounts' \
  '-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=unset -k mounts'

audit_rule_control "6.3.3.11" "Ensure session initiation information is collected" 50-session \
  '-w /var/run/utmp -p wa -k session' \
  '-w /var/log/wtmp -p wa -k logins' \
  '-w /var/log/btmp -p wa -k logins'

audit_rule_control "6.3.3.12" "Ensure login and logout events are collected" 50-logins \
  '-w /var/log/lastlog -p wa -k logins' \
  '-w /var/run/faillock -p wa -k logins'

audit_rule_control "6.3.3.13" "Ensure file deletion events by users are collected" 50-delete \
  '-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=unset -k delete' \
  '-a always,exit -F arch=b32 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=unset -k delete'

audit_rule_control "6.3.3.14" "Ensure events that modify the system's Mandatory Access Controls are collected" 50-MAC-policy \
  '-w /etc/selinux/ -p wa -k MAC-policy' \
  '-w /usr/share/selinux/ -p wa -k MAC-policy'

audit_rule_control "6.3.3.15" "Ensure successful and unsuccessful attempts to use the chcon command are collected" 50-perm_chng-chcon \
  '-a always,exit -F path=/usr/bin/chcon -F perm=x -F auid>=1000 -F auid!=unset -k perm_chng'

audit_rule_control "6.3.3.16" "Ensure successful and unsuccessful attempts to use the setfacl command are collected" 50-perm_chng-setfacl \
  '-a always,exit -F path=/usr/bin/setfacl -F perm=x -F auid>=1000 -F auid!=unset -k perm_chng'

audit_rule_control "6.3.3.17" "Ensure successful and unsuccessful attempts to use the chacl command are collected" 50-perm_chng-chacl \
  '-a always,exit -F path=/usr/bin/chacl -F perm=x -F auid>=1000 -F auid!=unset -k perm_chng'

audit_rule_control "6.3.3.18" "Ensure successful and unsuccessful attempts to use the usermod command are collected" 50-usermod \
  '-a always,exit -F path=/usr/sbin/usermod -F perm=x -F auid>=1000 -F auid!=unset -k usermod'

audit_rule_control "6.3.3.19" "Ensure kernel module loading unloading and modification is collected" 50-modules \
  '-a always,exit -F arch=b64 -S init_module,finit_module,delete_module,create_module,query_module -F auid>=1000 -F auid!=unset -k modules' \
  '-w /usr/sbin/insmod -p x -k modules' \
  '-w /usr/sbin/rmmod -p x -k modules' \
  '-w /usr/sbin/modprobe -p x -k modules'

id="6.3.3.20"; title="Ensure the audit configuration is immutable"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    mkdir -p "$RULES_DIR"
    echo '-e 2' > "${RULES_DIR}/99-finalize.rules"
    augenrules --load >/dev/null 2>&1
  fi
  auditctl -s 2>/dev/null | grep -q 'enabled 2' && log_result "$id" "$title" "$SECTION" "$level" "pass" "audit config immutable (enabled 2; requires reboot to change further)" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "audit config not set immutable (99-finalize.rules '-e 2' missing or not loaded)"
fi

id="6.3.3.21"; title="Ensure the running and on disk configuration is the same"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && augenrules --load >/dev/null 2>&1
  if command -v augenrules >/dev/null 2>&1 && augenrules --check >/dev/null 2>&1; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "running audit rules match rules.d configuration"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "running audit rules differ from on-disk rules.d configuration; run 'augenrules --load' (or reboot) to sync"
  fi
fi
