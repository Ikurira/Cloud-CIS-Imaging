#!/usr/bin/env bash
# CIS RHEL 9 hardening runner. See ../CONTRACT.md for the calling contract.
#
# Usage: run.sh --mode audit|remediate [--level 1|2] [--profile server|workstation] [--section N]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE=""
LEVEL="1"
PROFILE="server"
ONLY_SECTION=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --level) LEVEL="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --section) ONLY_SECTION="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ "$MODE" != "audit" && "$MODE" != "remediate" ]]; then
  echo "ERROR: --mode must be 'audit' or 'remediate'" >&2
  exit 2
fi

export CIS_MODE="$MODE"
export CIS_LEVEL="$LEVEL"
export CIS_PROFILE="$PROFILE"

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

echo "== CIS RHEL9 hardening runner: mode=${MODE} level=${LEVEL} profile=${PROFILE} ==" >&2

shopt -s nullglob
for section_dir in "${SCRIPT_DIR}"/scripts/section_*; do
  section_num="$(basename "$section_dir" | sed 's/section_//')"
  if [[ -n "$ONLY_SECTION" && "$section_num" != "$ONLY_SECTION" ]]; then
    continue
  fi
  for control_script in "$section_dir"/cis_*.sh; do
    # shellcheck disable=SC1090
    source "$control_script"
  done
done

echo "== Complete: ${NON_COMPLIANT_COUNT} non-compliant/error control(s) ==" >&2
exit "${NON_COMPLIANT_COUNT}"
