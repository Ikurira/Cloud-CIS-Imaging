#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 1.6.x - System wide crypto policy.
# Base policy and .pmod module content ported from Images/defaults/main/main.yml
# (rhel9cis_crypto_policy=DEFAULT) and Images/templates/etc/crypto-policies/policies/modules/*.pmod.j2.
# apply_crypto_submodule/write_crypto_pmod/current_crypto_policy are shared helpers in lib/common.sh
# (also used by section_5's cis_5.1.x.sh for the sshd-specific submodules 5.1.4-5.1.6).
SECTION="1"
BASE_POLICY="DEFAULT"

# 1.6.1 - base policy must not be LEGACY (or any *:LEGACY submodule).
id="1.6.1"; title="Ensure system-wide crypto policy is not legacy"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  cur=$(current_crypto_policy)
  if [[ "$cur" == *LEGACY* ]] && is_remediate; then
    update-crypto-policies --set "$BASE_POLICY" >/dev/null 2>&1
    cur=$(current_crypto_policy)
  fi
  if [[ "$cur" != *LEGACY* && -n "$cur" ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "active policy: ${cur}"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "active policy: ${cur:-unknown}"
  fi
fi

id="1.6.2"; title="Ensure system wide crypto policy is not set in sshd configuration"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate && [[ -f /etc/sysconfig/sshd ]]; then
    backup_file /etc/sysconfig/sshd
    sed -i '/^CRYPTO_POLICY\s*=/d' /etc/sysconfig/sshd
  fi
  if grep -qE '^CRYPTO_POLICY\s*=' /etc/sysconfig/sshd 2>/dev/null; then
    log_result "$id" "$title" "$SECTION" "$level" "fail" "CRYPTO_POLICY override still present in /etc/sysconfig/sshd"
  else
    log_result "$id" "$title" "$SECTION" "$level" "pass" "no CRYPTO_POLICY override in /etc/sysconfig/sshd"
  fi
fi

# 1.6.3-1.6.7: each adds a named submodule exclusion to the active crypto policy.
apply_crypto_submodule "1.6.3" "Ensure system wide crypto policy disables sha1 hash and signature support" "$SECTION" 1 \
  NO-SHA1 $'hash = -SHA1\nsign = -*-SHA1\nsha1_in_certs = 0'

apply_crypto_submodule "1.6.4" "Ensure system wide crypto policy disables macs less than 128 bits" "$SECTION" 1 \
  NO-WEAKMAC $'mac = -*-64'

apply_crypto_submodule "1.6.5" "Ensure system wide crypto policy disables cbc for ssh" "$SECTION" 1 \
  NO-SSHCBC $'cipher@SSH = -*-CBC'

apply_crypto_submodule "1.6.6" "Ensure system wide crypto policy disables chacha20-poly1305 for ssh" "$SECTION" 1 \
  NO-SSHWEAKCIPHERS $'cipher@SSH = -CHACHA20-POLY1305'

apply_crypto_submodule "1.6.7" "Ensure system wide crypto policy disables EtM for ssh" "$SECTION" 1 \
  NO-SSHETM $'etm@SSH = DISABLE_ETM'
