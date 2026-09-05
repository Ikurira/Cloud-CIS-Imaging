#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 3.3.x - Network kernel parameters (sysctl).
# Values ported from Images/templates/etc/sysctl.d/60-netipv4_sysctl.conf.j2 and
# 60-netipv6_sysctl.conf.j2. rhel9cis_is_router default is false (not a router) so all
# controls apply; rhel9cis_ipv6_required default is true so IPv6 variants are included.
SECTION="3"
IPV4_CONF="/etc/sysctl.d/60-cis-netipv4.conf"
IPV6_CONF="/etc/sysctl.d/60-cis-netipv6.conf"
IPV6_REQUIRED=1

# net_control <id> <title> <key1=val1> [key2=val2 ...]
net_control() {
  local id="$1" title="$2" level=1; shift 2
  if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"; return; fi

  local conf ok=1 detail=""
  for kv in "$@"; do
    key="${kv%%=*}"; val="${kv#*=}"
    conf="$IPV4_CONF"; [[ "$key" == net.ipv6.* ]] && conf="$IPV6_CONF"
    if [[ "$key" == net.ipv6.* && "$IPV6_REQUIRED" -ne 1 ]]; then
      continue  # IPv6 disabled entirely (see 3.1.1); its sysctl posture is moot
    fi
    is_remediate && set_sysctl "$key" "$val" "$conf"
    cur=$(get_sysctl "$key")
    detail="${detail}${key}=${cur} "
    [[ "$cur" == "$val" ]] || ok=0
  done
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "${detail}" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "${detail}"
}

net_control "3.3.1"  "Ensure ip forwarding is disabled" net.ipv4.ip_forward=0 net.ipv6.conf.all.forwarding=0
net_control "3.3.2"  "Ensure packet redirect sending is disabled" net.ipv4.conf.all.send_redirects=0 net.ipv4.conf.default.send_redirects=0
net_control "3.3.3"  "Ensure bogus icmp responses are ignored" net.ipv4.icmp_ignore_bogus_error_responses=1
net_control "3.3.4"  "Ensure broadcast icmp requests are ignored" net.ipv4.icmp_echo_ignore_broadcasts=1
net_control "3.3.5"  "Ensure icmp redirects are not accepted" net.ipv4.conf.all.accept_redirects=0 net.ipv4.conf.default.accept_redirects=0 net.ipv6.conf.all.accept_redirects=0 net.ipv6.conf.default.accept_redirects=0
net_control "3.3.6"  "Ensure secure icmp redirects are not accepted" net.ipv4.conf.all.secure_redirects=0 net.ipv4.conf.default.secure_redirects=0
net_control "3.3.7"  "Ensure reverse path filtering is enabled" net.ipv4.conf.all.rp_filter=1 net.ipv4.conf.default.rp_filter=1
net_control "3.3.8"  "Ensure source routed packets are not accepted" net.ipv4.conf.all.accept_source_route=0 net.ipv4.conf.default.accept_source_route=0 net.ipv6.conf.all.accept_source_route=0 net.ipv6.conf.default.accept_source_route=0
net_control "3.3.9"  "Ensure suspicious packets are logged" net.ipv4.conf.all.log_martians=1 net.ipv4.conf.default.log_martians=1
net_control "3.3.10" "Ensure tcp syn cookies is enabled" net.ipv4.tcp_syncookies=1

id="3.3.11"; title="Ensure ipv6 router advertisements are not accepted"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif [[ "$IPV6_REQUIRED" -ne 1 ]]; then
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "not applicable: IPv6 not in use"
else
  is_remediate && { set_sysctl net.ipv6.conf.all.accept_ra 0 "$IPV6_CONF"; set_sysctl net.ipv6.conf.default.accept_ra 0 "$IPV6_CONF"; }
  v1=$(get_sysctl net.ipv6.conf.all.accept_ra); v2=$(get_sysctl net.ipv6.conf.default.accept_ra)
  [[ "$v1" == "0" && "$v2" == "0" ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "accept_ra disabled" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "accept_ra all=${v1} default=${v2}"
fi
