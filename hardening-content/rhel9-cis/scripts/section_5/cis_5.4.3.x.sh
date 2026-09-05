#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 5.4.3.x - Shell defaults. Defaults ported from Images/defaults/main/main.yml:
# shell_session_timeout=900, shell_session_file=/etc/profile.d/tmout.sh, bash_umask=0027.
SECTION="5"
TMOUT_VALUE=900
TMOUT_FILE="/etc/profile.d/tmout.sh"
BASH_UMASK="0027"

id="5.4.3.1"; title="Ensure nologin is not listed in /etc/shells"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && [[ -f /etc/shells ]] && sed -i '/nologin/d' /etc/shells
  grep -q nologin /etc/shells 2>/dev/null && log_result "$id" "$title" "$SECTION" "$level" "fail" "nologin present in /etc/shells" \
    || log_result "$id" "$title" "$SECTION" "$level" "pass" "nologin not present in /etc/shells"
fi

id="5.4.3.2"; title="Ensure default user shell timeout is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    mkdir -p "$(dirname "$TMOUT_FILE")"
    {
      echo "# CIS benchmark - hardening-content/rhel9-cis"
      echo "TMOUT=${TMOUT_VALUE}"
      echo "readonly TMOUT"
      echo "export TMOUT"
    } > "$TMOUT_FILE"
    chmod go-wx "$TMOUT_FILE"
  fi
  if grep -q "^TMOUT=${TMOUT_VALUE}" "$TMOUT_FILE" 2>/dev/null || grep -qE "^\s*TMOUT=[1-9][0-9]{0,3}\s*$" /etc/profile 2>/dev/null; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "TMOUT configured (<=${TMOUT_VALUE}s)"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "TMOUT not configured in ${TMOUT_FILE} or /etc/profile"
  fi
fi

id="5.4.3.3"; title="Ensure default user umask is configured"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    grep -qE '(?i)umask\s+[0-9]+' /etc/profile 2>/dev/null && sed -i -E "s/umask\s+[0-9]+/umask ${BASH_UMASK}/I" /etc/profile \
      || echo "umask ${BASH_UMASK}" >> /etc/profile
    line_in_file /etc/login.defs '^\s*UMASK\s+' "UMASK           ${BASH_UMASK}"
  fi
  ok=1
  grep -qE "umask\s+${BASH_UMASK}" /etc/profile 2>/dev/null || ok=0
  grep -qE "^UMASK\s+${BASH_UMASK}" /etc/login.defs 2>/dev/null || ok=0
  [[ "$ok" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "umask ${BASH_UMASK} set in /etc/profile and /etc/login.defs" \
    || log_result "$id" "$title" "$SECTION" "$level" "fail" "umask ${BASH_UMASK} not set in both /etc/profile and /etc/login.defs"
fi
