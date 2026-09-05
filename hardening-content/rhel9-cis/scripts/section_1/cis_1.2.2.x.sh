#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 1.2.2.x - Software updates.
# Note: the upstream ansible role skips this on EC2 instances; since this entire pipeline
# only ever runs on EC2 (Image Builder build instances / launched instances), that exclusion
# is dropped here — patching to latest is exactly the point of the Image Builder build phase.
SECTION="1"

id="1.2.2.1"; title="Ensure updates, patches, and additional security software are installed"; level=1
if ! level_applies "$level"; then
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    dnf update -y >/dev/null 2>&1
  fi
  pending=$(dnf check-update --quiet 2>/dev/null | grep -cvE '^\s*$')
  if [[ "$pending" -eq 0 ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "no pending package updates"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "${pending} package(s) have pending updates"
  fi
fi
