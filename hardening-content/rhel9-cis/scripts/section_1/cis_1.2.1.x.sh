#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 1.2.1.x - Package repository / GPG key configuration.
SECTION="1"

# 1.2.1.1 - upstream role tags this "manual": verifying installed GPG pubkey fingerprints
# against the OS vendor's published key content is a manual trust decision, not something
# a script should silently accept/reject.
log_result "1.2.1.1" "Ensure GPG keys are configured" "$SECTION" 1 "skipped" "manual review control: verify 'rpm -qa gpg-pubkey*' fingerprints against the vendor's published keys"

id="1.2.1.2"; title="Ensure gpgcheck is globally activated"; level=1
if ! level_applies "$level"; then
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    for repo in /etc/yum.repos.d/*.repo; do
      [[ -f "$repo" ]] || continue
      grep -qE '^gpgcheck\s*=\s*0' "$repo" && sed -i 's/^gpgcheck\s*=\s*0/gpgcheck=1/' "$repo"
    done
  fi
  if grep -rlE '^gpgcheck\s*=\s*0' /etc/yum.repos.d/*.repo >/dev/null 2>&1; then
    log_result "$id" "$title" "$SECTION" "$level" "fail" "one or more repo files still set gpgcheck=0"
  else
    log_result "$id" "$title" "$SECTION" "$level" "pass" "no repo files disable gpgcheck"
  fi
fi

# 1.2.1.3 - upstream role tags this "manual"/audit-only (site-specific: only applies when
# rhel9cis_enable_repogpg is set and not using the default RHEL repos), but the remediation
# itself (repo_gpgcheck=1) is deterministic and safe, so it's implemented here rather than
# skipped outright.
id="1.2.1.3"; title="Ensure repo_gpgcheck is globally activated"; level=1
if ! level_applies "$level"; then
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    line_in_file /etc/dnf/dnf.conf '^repo_gpgcheck' 'repo_gpgcheck=1'
    for repo in /etc/yum.repos.d/*.repo; do
      [[ -f "$repo" ]] || continue
      grep -qE '^repo_gpgcheck\s*=\s*0' "$repo" && sed -i 's/^repo_gpgcheck\s*=\s*0/repo_gpgcheck=1/' "$repo"
    done
  fi
  if grep -qE '^repo_gpgcheck\s*=\s*1' /etc/dnf/dnf.conf 2>/dev/null; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "repo_gpgcheck=1 in dnf.conf"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "repo_gpgcheck not set to 1 in /etc/dnf/dnf.conf"
  fi
fi

# 1.2.1.4 - upstream role tags this "manual": reviewing the configured repo list against
# site policy is an organizational decision, not a deterministic pass/fail.
log_result "1.2.1.4" "Ensure package manager repositories are configured" "$SECTION" 1 "skipped" "manual review control: run 'dnf repolist' and confirm every repo matches site policy"
