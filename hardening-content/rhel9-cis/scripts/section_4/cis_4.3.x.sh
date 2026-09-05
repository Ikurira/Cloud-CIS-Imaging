#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 4.3.x - nftables rules. Only applicable when the configured firewall
# utility is nftables (see cis_4.1.x.sh); default is firewalld, so these are reported
# not-applicable out of the box, matching upstream's "when: rhel9cis_firewall == 'nftables'"
# gates on the sibling controls. Table name ported from Images/defaults/main/main.yml
# (rhel9cis_nft_tables_tablename=filter).
SECTION="4"
FIREWALL_UTIL="firewalld"
TABLE="filter"

nftables_applicable() { [[ "$FIREWALL_UTIL" == "nftables" ]] && command -v nft >/dev/null 2>&1; }

ensure_table_and_chains() {
  nft list table inet "$TABLE" >/dev/null 2>&1 || nft add table inet "$TABLE" >/dev/null 2>&1
  for hook in input forward output; do
    nft list chain inet "$TABLE" "$hook" >/dev/null 2>&1 || \
      nft add chain inet "$TABLE" "$hook" "{ type filter hook ${hook} priority 0 ; }" >/dev/null 2>&1
  done
}

id="4.3.1"; title="Ensure nftables base chains exist"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif ! nftables_applicable; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "not applicable: configured firewall utility is ${FIREWALL_UTIL}"
else
  is_remediate && ensure_table_and_chains
  ok=1
  for hook in input forward output; do nft list chain inet "$TABLE" "$hook" 2>/dev/null | grep -q "hook ${hook}" || ok=0; done
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "input/forward/output base chains present" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "one or more base chains missing"
fi

id="4.3.2"; title="Ensure nftables established connections are configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif ! nftables_applicable; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "not applicable: configured firewall utility is ${FIREWALL_UTIL}"
else
  ruleset=$(nft list ruleset 2>/dev/null)
  if is_remediate; then
    ensure_table_and_chains
    echo "$ruleset" | grep -q "ip protocol tcp ct state established accept" || nft add rule inet "$TABLE" input ip protocol tcp ct state established accept 2>/dev/null
    echo "$ruleset" | grep -q "ip protocol udp ct state established accept" || nft add rule inet "$TABLE" input ip protocol udp ct state established accept 2>/dev/null
    echo "$ruleset" | grep -q "ip protocol icmp ct state established accept" || nft add rule inet "$TABLE" input ip protocol icmp ct state established accept 2>/dev/null
    echo "$ruleset" | grep -q "ip protocol tcp ct state.*established.*accept" || nft add rule inet "$TABLE" output ip protocol tcp ct state new,related,established accept 2>/dev/null
    echo "$ruleset" | grep -q "ip protocol udp ct state.*established.*accept" || nft add rule inet "$TABLE" output ip protocol udp ct state new,related,established accept 2>/dev/null
    echo "$ruleset" | grep -q "ip protocol icmp ct state.*established.*accept" || nft add rule inet "$TABLE" output ip protocol icmp ct state new,related,established accept 2>/dev/null
    ruleset=$(nft list ruleset 2>/dev/null)
  fi
  ok=1
  for proto in tcp udp icmp; do echo "$ruleset" | grep -q "ip protocol ${proto} ct state established accept" || ok=0; done
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "established-connection accept rules present" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "one or more established-connection accept rules missing"
fi

id="4.3.3"; title="Ensure nftables default deny firewall policy"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif ! nftables_applicable; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "not applicable: configured firewall utility is ${FIREWALL_UTIL}"
else
  tbl=$(nft list table inet "$TABLE" 2>/dev/null)
  if is_remediate; then
    echo "$tbl" | grep -qE 'dport (22|ssh) accept' || nft add rule inet "$TABLE" input tcp dport ssh accept 2>/dev/null
    echo "$tbl" | grep -qE 'hook input priority (0|filter); policy drop;' || nft chain inet "$TABLE" input '{ policy drop ; }' 2>/dev/null
    echo "$tbl" | grep -qE 'hook forward priority (0|filter); policy drop;' || nft chain inet "$TABLE" forward '{ policy drop ; }' 2>/dev/null
    echo "$tbl" | grep -qE 'hook output priority (0|filter); policy drop;' || nft chain inet "$TABLE" output '{ policy drop ; }' 2>/dev/null
    tbl=$(nft list table inet "$TABLE" 2>/dev/null)
  fi
  ok=1
  echo "$tbl" | grep -qE 'dport (22|ssh) accept' || ok=0
  for hook in input forward output; do echo "$tbl" | grep -qE "hook ${hook} priority (0|filter); policy drop;" || ok=0; done
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "default-deny policy set on all base chains, SSH explicitly allowed" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "default-deny policy or SSH allow rule missing"
fi

id="4.3.4"; title="Ensure nftables loopback traffic is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif ! nftables_applicable; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "not applicable: configured firewall utility is ${FIREWALL_UTIL}"
else
  ruleset=$(nft list ruleset 2>/dev/null)
  if is_remediate; then
    echo "$ruleset" | grep -q 'iif "lo" accept' || nft add rule inet "$TABLE" input iif lo accept 2>/dev/null
    echo "$ruleset" | grep -q 'ip saddr 127.0.0.0/8' || nft add rule inet "$TABLE" input ip saddr 127.0.0.0/8 counter drop 2>/dev/null
    echo "$ruleset" | grep -q 'ip6 saddr ::1' || nft add rule inet "$TABLE" input ip6 saddr ::1 counter drop 2>/dev/null
    ruleset=$(nft list ruleset 2>/dev/null)
  fi
  ok=1
  echo "$ruleset" | grep -q 'iif "lo" accept' || ok=0
  echo "$ruleset" | grep -q 'ip saddr 127.0.0.0/8' || ok=0
  echo "$ruleset" | grep -q 'ip6 saddr ::1' || ok=0
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "loopback accept/spoof-drop rules present" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "one or more loopback rules missing"
fi
