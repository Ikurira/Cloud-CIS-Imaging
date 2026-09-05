#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 5.1.x - sshd configuration.
# Defaults ported from Images/defaults/main/main.yml: loglevel=INFO, maxauthtries=4,
# maxstartups=10:30:60, maxsessions=4, clientaliveinterval=15, clientalivecountmax=3,
# logingracetime=60, x11forwarding=no. apply_crypto_submodule is a shared lib/common.sh
# helper (also used by section_1's cis_1.6.x.sh).
SECTION="5"
SSHD_CONFIG="/etc/ssh/sshd_config"
REDHAT_OVERRIDE="/etc/ssh/sshd_config.d/50-redhat.conf"

id="5.1.1"; title="Ensure permissions on /etc/ssh/sshd_config are configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && set_file_perms "$SSHD_CONFIG" 600 root root
  check_file_perms "$SSHD_CONFIG" 600 && log_result "$id" "$title" "$SECTION" "$level" "pass" "sshd_config is mode 600" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "sshd_config is not mode 600"
fi

id="5.1.2"; title="Ensure permissions on SSH private host key files are configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  ok=1
  while IFS= read -r -d '' key; do
    grp="root"; mode=600
    getent group ssh_keys >/dev/null 2>&1 && stat -c '%G' "$key" 2>/dev/null | grep -qx ssh_keys && { grp="ssh_keys"; mode=640; }
    is_remediate && set_file_perms "$key" "$mode" root "$grp"
    check_file_perms "$key" "$mode" || ok=0
  done < <(find /etc/ssh -name 'ssh_host_*_key' -print0 2>/dev/null)
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "private host keys correctly permissioned" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "one or more private host keys misconfigured"
fi

id="5.1.3"; title="Ensure permissions on SSH public host key files are configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  ok=1
  while IFS= read -r -d '' key; do
    is_remediate && set_file_perms "$key" 644 root root
    check_file_perms "$key" 644 || ok=0
  done < <(find /etc/ssh -name 'ssh_host_*_key.pub' -print0 2>/dev/null)
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "public host keys mode 644" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "one or more public host keys not mode 644"
fi

apply_crypto_submodule "5.1.4" "Ensure sshd Ciphers are configured" "$SECTION" 1 \
  NO-SSHWEAKCIPHERS $'cipher@SSH = -CHACHA20-POLY1305 -3DES-CBC -AES-128-CBC -AES-192-CBC -AES-256-CBC'

apply_crypto_submodule "5.1.5" "Ensure sshd KexAlgorithms is configured" "$SECTION" 1 \
  NO-SHA1 $'hash = -SHA1\nsign = -*-SHA1\nsha1_in_certs = 0'

apply_crypto_submodule "5.1.6" "Ensure sshd MACs are configured" "$SECTION" 1 \
  NO-SSHWEAKMACS $'mac@SSH = -HMAC-MD5* -UMAC-64* -UMAC-128*'

id="5.1.7"; title="Ensure sshd access is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "site-specific control: no default AllowUsers/AllowGroups/DenyUsers/DenyGroups list configured; set via set_sshd_config in a site override before enabling"
fi

id="5.1.8"; title="Ensure sshd Banner is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { set_sshd_config Banner /etc/issue.net; reload_sshd_if_valid; }
  [[ "$(get_sshd_config banner)" == "/etc/issue.net" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "Banner /etc/issue.net" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "Banner not set to /etc/issue.net"
fi

id="5.1.9"; title="Ensure sshd ClientAliveInterval and ClientAliveCountMax are configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { set_sshd_config ClientAliveInterval 15; set_sshd_config ClientAliveCountMax 3; reload_sshd_if_valid; }
  v1=$(get_sshd_config clientaliveinterval); v2=$(get_sshd_config clientalivecountmax)
  [[ "$v1" -ge 1 && "$v2" -le 3 ]] 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "ClientAliveInterval=${v1} ClientAliveCountMax=${v2}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "ClientAliveInterval=${v1} ClientAliveCountMax=${v2}"
fi

id="5.1.10"; title="Ensure sshd DisableForwarding is enabled"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    set_sshd_config DisableForwarding yes
    [[ -f "$REDHAT_OVERRIDE" ]] && line_in_file "$REDHAT_OVERRIDE" '(?i)^(#|)\s*X11Forwarding' 'X11Forwarding no'
    reload_sshd_if_valid
  fi
  [[ "$(get_sshd_config disableforwarding)" == "yes" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "DisableForwarding yes" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "DisableForwarding not yes"
fi

id="5.1.11"; title="Ensure sshd GSSAPIAuthentication is disabled"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    [[ -f "$REDHAT_OVERRIDE" ]] && line_in_file "$REDHAT_OVERRIDE" '(?i)^(#|)\s*GSSAPIAuthentication' 'GSSAPIAuthentication no'
    set_sshd_config GSSAPIAuthentication no
    reload_sshd_if_valid
  fi
  [[ "$(get_sshd_config gssapiauthentication)" == "no" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "GSSAPIAuthentication no" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "GSSAPIAuthentication not no"
fi

id="5.1.12"; title="Ensure sshd HostbasedAuthentication is disabled"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { set_sshd_config HostbasedAuthentication no; reload_sshd_if_valid; }
  [[ "$(get_sshd_config hostbasedauthentication)" == "no" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "HostbasedAuthentication no" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "HostbasedAuthentication not no"
fi

id="5.1.13"; title="Ensure sshd IgnoreRhosts is enabled"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { set_sshd_config IgnoreRhosts yes; reload_sshd_if_valid; }
  [[ "$(get_sshd_config ignorerhosts)" == "yes" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "IgnoreRhosts yes" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "IgnoreRhosts not yes"
fi

id="5.1.14"; title="Ensure sshd LoginGraceTime is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { set_sshd_config LoginGraceTime 60; reload_sshd_if_valid; }
  v=$(get_sshd_config logingracetime)
  [[ -n "$v" && "$v" != "0" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "LoginGraceTime=${v}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "LoginGraceTime=${v} (must be >0)"
fi

id="5.1.15"; title="Ensure sshd LogLevel is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { set_sshd_config LogLevel INFO; reload_sshd_if_valid; }
  v=$(get_sshd_config loglevel)
  [[ "$v" == "INFO" || "$v" == "VERBOSE" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "LogLevel=${v}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "LogLevel=${v} (expected INFO or VERBOSE)"
fi

id="5.1.16"; title="Ensure sshd MaxAuthTries is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { set_sshd_config MaxAuthTries 4; reload_sshd_if_valid; }
  v=$(get_sshd_config maxauthtries)
  [[ "$v" -le 4 && "$v" -ge 1 ]] 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "MaxAuthTries=${v}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "MaxAuthTries=${v} (expected <=4)"
fi

id="5.1.17"; title="Ensure sshd MaxStartups is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { set_sshd_config MaxStartups 10:30:60; reload_sshd_if_valid; }
  v=$(get_sshd_config maxstartups)
  [[ -n "$v" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "MaxStartups=${v}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "MaxStartups not set"
fi

id="5.1.18"; title="Ensure sshd MaxSessions is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { set_sshd_config MaxSessions 4; reload_sshd_if_valid; }
  v=$(get_sshd_config maxsessions)
  [[ "$v" -le 10 ]] 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "pass" "MaxSessions=${v}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "MaxSessions=${v} (expected <=10)"
fi

id="5.1.19"; title="Ensure sshd PermitEmptyPasswords is disabled"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { set_sshd_config PermitEmptyPasswords no; reload_sshd_if_valid; }
  [[ "$(get_sshd_config permitemptypasswords)" == "no" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "PermitEmptyPasswords no" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "PermitEmptyPasswords not no"
fi

id="5.1.20"; title="Ensure sshd PermitRootLogin is disabled"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    set_sshd_config PermitRootLogin no
    rm -f /etc/ssh/sshd_config.d/01-permitrootlogin.conf
    reload_sshd_if_valid
  fi
  [[ "$(get_sshd_config permitrootlogin)" == "no" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "PermitRootLogin no" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "PermitRootLogin not no"
fi

id="5.1.21"; title="Ensure sshd PermitUserEnvironment is disabled"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { set_sshd_config PermitUserEnvironment no; reload_sshd_if_valid; }
  [[ "$(get_sshd_config permituserenvironment)" == "no" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "PermitUserEnvironment no" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "PermitUserEnvironment not no"
fi

id="5.1.22"; title="Ensure sshd UsePAM is enabled"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && { set_sshd_config UsePAM yes; reload_sshd_if_valid; }
  [[ "$(get_sshd_config usepam)" == "yes" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "UsePAM yes" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "UsePAM not yes"
fi
