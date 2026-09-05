#!/usr/bin/env bash
# Shared helpers for CIS RHEL9 hardening scripts. Sourced by every scripts/section_*/cis_*.sh file.
# Implements the result-stream contract in hardening-content/CONTRACT.md.

set -uo pipefail

RESULTS_DIR="/var/log/cis-hardening"
RESULTS_FILE="${RESULTS_DIR}/results.jsonl"
MODE="${CIS_MODE:-audit}"          # audit|remediate, set by run.sh
LEVEL="${CIS_LEVEL:-1}"            # 1|2, set by run.sh
NON_COMPLIANT_COUNT=0

mkdir -p "${RESULTS_DIR}"
touch "${RESULTS_FILE}"

# log_result <control_id> <title> <section> <level> <status: pass|fail|error|skipped> <message>
log_result() {
  local control_id="$1" title="$2" section="$3" level="$4" status="$5" message="$6"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local escaped_title escaped_message
  escaped_title=$(printf '%s' "$title" | sed 's/\\/\\\\/g; s/"/\\"/g')
  escaped_message=$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g')

  local line
  line=$(printf '{"control_id":"%s","title":"%s","section":"%s","level":%s,"status":"%s","mode":"%s","message":"%s","timestamp":"%s"}' \
    "$control_id" "$escaped_title" "$section" "$level" "$status" "$MODE" "$escaped_message" "$ts")

  echo "$line"
  echo "$line" >> "$RESULTS_FILE"

  if [[ "$status" == "fail" || "$status" == "error" ]]; then
    NON_COMPLIANT_COUNT=$((NON_COMPLIANT_COUNT + 1))
  fi
}

# is_remediate — true if running in remediate mode
is_remediate() { [[ "$MODE" == "remediate" ]]; }

# level_applies <control_level> — true if control_level <= configured LEVEL
level_applies() { [[ "$1" -le "$LEVEL" ]]; }

# backup_file <path> — idempotent single backup before first modification
backup_file() {
  local f="$1"
  [[ -f "$f" && ! -f "${f}.cis-orig" ]] && cp -p "$f" "${f}.cis-orig"
  return 0
}

# set_sysctl <key> <value> <conf_file>
set_sysctl() {
  local key="$1" value="$2" conf_file="${3:-/etc/sysctl.d/60-cis-hardening.conf}"
  backup_file "$conf_file"
  if grep -qE "^\s*${key}\s*=" "$conf_file" 2>/dev/null; then
    sed -i "s|^\s*${key}\s*=.*|${key} = ${value}|" "$conf_file"
  else
    echo "${key} = ${value}" >> "$conf_file"
  fi
  sysctl -w "${key}=${value}" >/dev/null 2>&1 || true
}

get_sysctl() {
  sysctl -n "$1" 2>/dev/null || echo ""
}

# line_in_file <path> <ere_regexp_matching_existing_line> <desired_line> [mode] [create=1]
# Idempotent equivalent of ansible.builtin.lineinfile: replaces the first line matching
# <ere_regexp_matching_existing_line>, or appends <desired_line> if no match. Creates the
# file (and parent dir) first if it does not exist and create!=0.
line_in_file() {
  local path="$1" regexp="$2" desired="$3" mode="${4:-}" create="${5:-1}"

  if [[ ! -f "$path" ]]; then
    [[ "$create" -eq 0 ]] && return 1
    mkdir -p "$(dirname "$path")"
    touch "$path"
    [[ -n "$mode" ]] && chmod "$mode" "$path"
  fi
  backup_file "$path"

  if grep -qE "$regexp" "$path" 2>/dev/null; then
    # escape & and | for the sed replacement side
    local escaped
    escaped=$(printf '%s' "$desired" | sed 's/[&|\\]/\\&/g')
    sed -i "0,/${regexp}/{s|${regexp}|${escaped}|}" "$path"
  else
    echo "$desired" >> "$path"
  fi
  [[ -n "$mode" ]] && chmod "$mode" "$path"
}

# line_present <path> <exact_or_regexp_line> — true if a matching line exists (post-check helper)
line_present() {
  grep -qE "$2" "$1" 2>/dev/null
}

# set_file_perms <path> <mode> [owner] [group]
set_file_perms() {
  local path="$1" mode="$2" owner="${3:-}" group="${4:-}"
  [[ -e "$path" ]] || return 1
  chmod "$mode" "$path"
  [[ -n "$owner" ]] && chown "$owner" "$path"
  [[ -n "$group" ]] && chgrp "$group" "$path"
}

# check_file_perms <path> <expected_octal_mode> — true if actual perms <= expected (no extra bits)
check_file_perms() {
  local path="$1" expected="$2"
  [[ -e "$path" ]] || return 1
  local actual
  actual=$(stat -c '%a' "$path" 2>/dev/null)
  [[ "$actual" == "$expected" ]]
}

# package_installed <pkg> — true if rpm package is installed
package_installed() {
  rpm -q "$1" >/dev/null 2>&1
}

# remove_package <pkg> — idempotent removal, ignores errors on packages that don't exist
# or can't be removed due to dependencies (logged by the caller via the return code).
remove_package() {
  local pkg="$1"
  package_installed "$pkg" || return 0
  dnf remove -y "$pkg" >/dev/null 2>&1
}

# install_package <pkg> — idempotent install
install_package() {
  local pkg="$1"
  package_installed "$pkg" && return 0
  dnf install -y "$pkg" >/dev/null 2>&1
}

# mask_and_disable_service <svc> — stop, disable, and mask a systemd unit; ignores units
# that don't exist on this system (containers/minimal installs).
mask_and_disable_service() {
  local svc="$1"
  systemctl list-unit-files "${svc}.service" >/dev/null 2>&1 || return 0
  systemctl --now disable "$svc" >/dev/null 2>&1 || true
  systemctl mask "$svc" >/dev/null 2>&1 || true
}

# service_inactive_and_masked <svc> — true if the unit is masked (or absent) and not running
service_inactive_and_masked() {
  local svc="$1"
  systemctl list-unit-files "${svc}.service" >/dev/null 2>&1 || return 0
  local enabled
  enabled=$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")
  local active
  active=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
  [[ "$enabled" == "masked" && "$active" != "active" ]]
}

# enable_service <svc> — enable and start a systemd unit
enable_service() {
  local svc="$1"
  systemctl list-unit-files "${svc}.service" >/dev/null 2>&1 || return 0
  systemctl unmask "$svc" >/dev/null 2>&1 || true
  systemctl --now enable "$svc" >/dev/null 2>&1 || true
}

# service_active_and_enabled <svc> — true if unit is enabled and running
service_active_and_enabled() {
  local svc="$1"
  systemctl list-unit-files "${svc}.service" >/dev/null 2>&1 || return 1
  local enabled active
  enabled=$(systemctl is-enabled "$svc" 2>/dev/null || echo "unknown")
  active=$(systemctl is-active "$svc" 2>/dev/null || echo "inactive")
  [[ "$enabled" == "enabled" && "$active" == "active" ]]
}

# set_sshd_config <directive> <value> — idempotently set a directive in the main sshd_config.
# Restart of sshd is left to the caller/runner (batched) to avoid dropping the build/SSM session
# mid-script; callers should validate with `sshd -t` before any reload.
set_sshd_config() {
  local directive="$1" value="$2" file="${3:-/etc/ssh/sshd_config}"
  line_in_file "$file" "^[#[:space:]]*${directive}[[:space:]]" "${directive} ${value}"
}

get_sshd_config() {
  local directive="$1" file="${2:-/etc/ssh/sshd_config}"
  sshd -T 2>/dev/null | grep -i "^${directive,,} " | awk '{print $2}'
}

# set_pam_line <pam_file> <regexp> <desired_line> — idempotent line management inside a
# /etc/pam.d/* file (authselect custom profile files), mirrors line_in_file semantics.
set_pam_line() {
  line_in_file "$@"
}

reload_sshd_if_valid() {
  sshd -t >/dev/null 2>&1 && systemctl reload sshd >/dev/null 2>&1
}

# --- authselect custom profile helpers (RHEL8/9 generate /etc/pam.d/system-auth and
# password-auth from an authselect profile; direct edits to those files are overwritten
# on the next `authselect apply-changes`, so section_5's PAM controls edit a dedicated
# custom profile's templates instead, matching CIS's own RHEL8/9 remediation guidance). ---

CIS_AUTHSELECT_PROFILE="cis-hardening"
CIS_AUTHSELECT_DIR="/etc/authselect/custom/${CIS_AUTHSELECT_PROFILE}"

ensure_authselect_custom_profile() {
  command -v authselect >/dev/null 2>&1 || return 1
  if [[ ! -d "$CIS_AUTHSELECT_DIR" ]]; then
    local base
    base=$(authselect current 2>/dev/null | awk '/Profile ID/{print $NF}')
    [[ -z "$base" ]] && base="sssd"
    base="${base#custom/}"
    authselect create-profile "$CIS_AUTHSELECT_PROFILE" -b "$base" --symlink-meta >/dev/null 2>&1
  fi
  local features="with-faillock"
  authselect list-features "custom/${CIS_AUTHSELECT_PROFILE}" 2>/dev/null | grep -q with-pwhistory && features="${features} with-pwhistory"
  authselect select "custom/${CIS_AUTHSELECT_PROFILE}" $features --force >/dev/null 2>&1
}

authselect_current_profile_is_ours() {
  authselect current 2>/dev/null | grep -q "custom/${CIS_AUTHSELECT_PROFILE}"
}

authselect_apply() {
  authselect apply-changes >/dev/null 2>&1
}

# set_pam_module_option <pam_template_file> <module_so> <option_regex> <desired_line_suffix>
# Idempotently ensures a pam_*.so line in a given authselect custom-profile template
# contains <desired_line_suffix>, removing any conflicting prior value matched by
# <option_regex> first. Operates on $CIS_AUTHSELECT_DIR/<pam_template_file>.
set_pam_module_option() {
  local file="${CIS_AUTHSELECT_DIR}/$1" module="$2"
  [[ -f "$file" ]] || return 1
  backup_file "$file"
  sed -i -E "/${module}/ s/\s+${3}[^ ]*//g" "$file"
  sed -i -E "s#(^[^#].*${module}[^ ]*)#\1 ${4}#" "$file"
}

# --- crypto-policies submodule helpers (shared by section_1 1.6.x and section_5 5.1.4-5.1.6) ---

CIS_CRYPTO_MODULES_DIR="/etc/crypto-policies/policies/modules"

write_crypto_pmod() {
  local name="$1" content="$2"
  mkdir -p "$CIS_CRYPTO_MODULES_DIR"
  printf '# Managed by CIS RHEL9 hardening (hardening-content/rhel9-cis)\n%s\n' "$content" > "${CIS_CRYPTO_MODULES_DIR}/${name}.pmod"
}

current_crypto_policy() {
  update-crypto-policies --show 2>/dev/null
}

# apply_crypto_submodule <id> <title> <section> <level> <module_name> <pmod_content>
apply_crypto_submodule() {
  local id="$1" title="$2" section="$3" level="$4" module="$5" content="$6"

  if ! level_applies "$level"; then
    log_result "$id" "$title" "$section" "$level" "skipped" "level not in scope"
    return
  fi

  if is_remediate; then
    write_crypto_pmod "$module" "$content"
    local cur
    cur=$(current_crypto_policy)
    [[ -z "$cur" ]] && cur="DEFAULT"
    if [[ ":${cur}:" != *":${module}:"* ]]; then
      update-crypto-policies --set "${cur}:${module}" >/dev/null 2>&1
    fi
  fi

  local cur
  cur=$(current_crypto_policy)
  if [[ -f "${CIS_CRYPTO_MODULES_DIR}/${module}.pmod" && "$cur" == *"${module}"* ]]; then
    log_result "$id" "$title" "$section" "$level" "pass" "policy module ${module} present and active (${cur})"
  else
    log_result "$id" "$title" "$section" "$level" "fail" "policy module ${module} missing or inactive (active=${cur:-unknown})"
  fi
}

# mount_is_separate <mount_point> — true if <mount_point> is its own mount (not part of /)
mount_is_separate() {
  findmnt -kn "$1" >/dev/null 2>&1
}

# mount_has_option <mount_point> <option> — true if currently mounted with <option>
mount_has_option() {
  local mp="$1" opt="$2"
  findmnt -kn -o OPTIONS "$mp" 2>/dev/null | tr ',' '\n' | grep -qx "$opt"
}

# fstab_add_option <mount_point> <option> — idempotently add a mount option to the fstab
# entry for <mount_point>. Only edits /etc/fstab; does not remount live (CIS's own guidance
# is fstab edit + reboot/remount by an operator or the next maintenance window — an
# unattended live remount of e.g. /var mid-session can hang the calling SSM/Image Builder
# session and is deliberately avoided here). Returns 1 if no fstab entry exists to edit.
fstab_add_option() {
  local mp="$1" opt="$2"
  grep -qE "^\S+\s+${mp}\s" /etc/fstab || return 1
  mount_has_option "$mp" "$opt" && return 0
  backup_file /etc/fstab
  awk -v mp="$mp" -v opt="$opt" '
    $0 !~ /^#/ && $2 == mp {
      if ($4 !~ "(^|,)" opt "(,|$)") { $4 = $4 "," opt }
    }
    { print }
  ' OFS='\t' /etc/fstab > /etc/fstab.cis-tmp && mv /etc/fstab.cis-tmp /etc/fstab
}

# check_mount_option_control <id> <title> <level> <mount_point> <option>
# Shared audit+remediate pattern for the 1.1.2.x "nodev/nosuid/noexec on <mount>" controls.
check_mount_option_control() {
  local id="$1" title="$2" level="$3" mp="$4" opt="$5"

  if ! level_applies "$level"; then
    log_result "$id" "$title" "$SECTION" "$level" "skipped" "level ${level} not in scope"
    return
  fi
  if ! mount_is_separate "$mp"; then
    log_result "$id" "$title" "$SECTION" "$level" "skipped" "${mp} is not a separate partition on this system; provisioning a dedicated partition is a manual, image-layout decision (see CIS remediation guidance)"
    return
  fi

  if is_remediate; then
    fstab_add_option "$mp" "$opt"
  fi

  if mount_has_option "$mp" "$opt"; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "${mp} currently mounted with ${opt}"
  else
    fstab_add_option "$mp" "$opt" >/dev/null 2>&1
    if grep -qE "^\S+\s+${mp}\s" /etc/fstab; then
      log_result "$id" "$title" "$SECTION" "$level" "fail" "${mp} missing ${opt}; /etc/fstab updated, takes effect on next mount/reboot"
    else
      log_result "$id" "$title" "$SECTION" "$level" "fail" "${mp} missing ${opt} and has no /etc/fstab entry to edit (e.g. mounted via systemd unit) — needs manual remediation"
    fi
  fi
}

# check_separate_partition_control <id> <title> <level> <mount_point>
# Shared audit-only pattern for the 1.1.2.x.1 "separate partition exists for <mount>" controls.
# Creating/resizing partitions is an imaging/storage-layout decision outside a hardening
# script's safe blast radius, so this is always audit-only, never fabricated as remediated.
check_separate_partition_control() {
  local id="$1" title="$2" level="$3" mp="$4"

  if ! level_applies "$level"; then
    log_result "$id" "$title" "$SECTION" "$level" "skipped" "level ${level} not in scope"
    return
  fi
  if mount_is_separate "$mp"; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "${mp} is a separate partition"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "${mp} is not a separate partition; requires re-imaging with a dedicated partition/logical volume for ${mp} (manual, no safe automated remediation)"
  fi
}
