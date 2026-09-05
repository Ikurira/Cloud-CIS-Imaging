#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 1.8.x - GNOME Desktop Manager (GDM).
# All controls in this group only apply when a GUI/GDM is present, matching the upstream
# role's "when: rhel9cis_gui" gate; on headless server images (the common EC2 case) they
# are correctly reported as not-applicable, not silently skipped-without-explanation.
# dconf content ported from Images/templates/etc/dconf/db/*.j2 and Images/defaults/main/main.yml.
SECTION="1"
DCONF_DB="local"
WARNING_BANNER="Authorized users only. All activity may be monitored and reported."
SCREENSAVER_IDLE_DELAY=900
SCREENSAVER_LOCK_DELAY=5

gui_present() { package_installed gdm; }

not_applicable() {
  local id="$1" title="$2" level="$3"
  log_result "$id" "$title" "$SECTION" "$level" "skipped" "not applicable: no GUI/GDM installed on this system"
}

id="1.8.1"; title="Ensure GNOME Display Manager is removed"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && package_installed gdm && remove_package gdm
  if ! package_installed gdm; then log_result "$id" "$title" "$SECTION" "$level" "pass" "gdm not installed"
  else log_result "$id" "$title" "$SECTION" "$level" "fail" "gdm is installed"; fi
fi

write_dconf_profile_gdm() {
  line_in_file /etc/dconf/profile/gdm 'user-db' 'user-db:user' go-wx
  line_in_file /etc/dconf/profile/gdm 'system-db' 'system-db:gdm' go-wx
  line_in_file /etc/dconf/profile/gdm 'file-db' 'file-db:/usr/share/gdm/greeter-dconf-defaults' go-wx
}

id="1.8.2"; title="Ensure GDM login banner is configured"; level=1
if ! gui_present; then not_applicable "$id" "$title" "$level"
elif ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    write_dconf_profile_gdm
    mkdir -p /etc/dconf/db/gdm.d
    escaped_banner=$(printf '%s' "$WARNING_BANNER" | sed 's/"/\\"/g')
    printf '[org/gnome/login-screen]\nbanner-message-enable=true\nbanner-message-text="%s"\n' "$escaped_banner" > /etc/dconf/db/gdm.d/01-banner-message
    dconf update >/dev/null 2>&1 || true
  fi
  if grep -q "banner-message-enable=true" /etc/dconf/db/gdm.d/01-banner-message 2>/dev/null; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "GDM banner configured"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "GDM banner not configured"
  fi
fi

id="1.8.3"; title="Ensure GDM disable-user-list option is enabled"; level=1
if ! gui_present; then not_applicable "$id" "$title" "$level"
elif ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    write_dconf_profile_gdm
    mkdir -p /etc/dconf/db/gdm.d
    line_in_file /etc/dconf/db/gdm.d/00-login-screen '\[org/gnome/login-screen\]' '[org/gnome/login-screen]' go-wx
    line_in_file /etc/dconf/db/gdm.d/00-login-screen '^disable-user-list=' 'disable-user-list=true'
    dconf update >/dev/null 2>&1 || true
  fi
  if grep -q "^disable-user-list=true" /etc/dconf/db/gdm.d/00-login-screen 2>/dev/null; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "disable-user-list=true"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "disable-user-list not enabled"
  fi
fi

id="1.8.4"; title="Ensure GDM screen locks when the user is idle"; level=1
if ! gui_present; then not_applicable "$id" "$title" "$level"
elif ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    line_in_file /etc/dconf/profile/user '^user-db' 'user-db:user' go-wx
    line_in_file /etc/dconf/profile/user '^system-db' 'system-db:local' go-wx
    mkdir -p "/etc/dconf/db/${DCONF_DB}.d"
    printf '[org/gnome/desktop/session]\nidle-delay=uint32 %s\n\n[org/gnome/desktop/screensaver]\nlock-delay=uint32 %s\n' \
      "$SCREENSAVER_IDLE_DELAY" "$SCREENSAVER_LOCK_DELAY" > "/etc/dconf/db/${DCONF_DB}.d/00-screensaver"
    dconf update >/dev/null 2>&1 || true
  fi
  if grep -q "idle-delay=uint32 ${SCREENSAVER_IDLE_DELAY}" "/etc/dconf/db/${DCONF_DB}.d/00-screensaver" 2>/dev/null; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "idle-delay=${SCREENSAVER_IDLE_DELAY}s lock-delay=${SCREENSAVER_LOCK_DELAY}s"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "screensaver idle/lock delay not configured"
  fi
fi

id="1.8.5"; title="Ensure GDM screen locks cannot be overridden"; level=1
if ! gui_present; then not_applicable "$id" "$title" "$level"
elif ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    mkdir -p "/etc/dconf/db/${DCONF_DB}.d/locks"
    printf '/org/gnome/desktop/session/idle-delay\n/org/gnome/desktop/screensaver/lock-delay\n' > "/etc/dconf/db/${DCONF_DB}.d/locks/00-screensaver_lock"
    dconf update >/dev/null 2>&1 || true
  fi
  if [[ -f "/etc/dconf/db/${DCONF_DB}.d/locks/00-screensaver_lock" ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "screensaver settings locked"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "screensaver lock file missing"
  fi
fi

id="1.8.6"; title="Ensure GDM automatic mounting of removable media is disabled"; level=1
if ! gui_present; then not_applicable "$id" "$title" "$level"
elif ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    mkdir -p "/etc/dconf/db/${DCONF_DB}.d"
    printf '[org/gnome/desktop/media-handling]\nautomount=false\nautomount-open=false\n' > "/etc/dconf/db/${DCONF_DB}.d/00-media-automount"
    dconf update >/dev/null 2>&1 || true
  fi
  if grep -q "automount=false" "/etc/dconf/db/${DCONF_DB}.d/00-media-automount" 2>/dev/null; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "automount disabled"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "automount not disabled"
  fi
fi

id="1.8.7"; title="Ensure GDM disabling automatic mounting of removable media is not overridden"; level=1
if ! gui_present; then not_applicable "$id" "$title" "$level"
elif ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    mkdir -p "/etc/dconf/db/${DCONF_DB}.d/locks"
    printf '/org/gnome/desktop/media-handling/automount\n/org/gnome/desktop/media-handling/automount-open\n' > "/etc/dconf/db/${DCONF_DB}.d/locks/00-automount_lock"
    dconf update >/dev/null 2>&1 || true
  fi
  if [[ -f "/etc/dconf/db/${DCONF_DB}.d/locks/00-automount_lock" ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "automount settings locked"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "automount lock file missing"
  fi
fi

id="1.8.8"; title="Ensure GDM autorun-never is enabled"; level=1
if ! gui_present; then not_applicable "$id" "$title" "$level"
elif ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    mkdir -p "/etc/dconf/db/${DCONF_DB}.d"
    printf '[org/gnome/desktop/media-handling]\nautorun-never=true\n' > "/etc/dconf/db/${DCONF_DB}.d/00-media-autorun"
    dconf update >/dev/null 2>&1 || true
  fi
  if grep -q "autorun-never=true" "/etc/dconf/db/${DCONF_DB}.d/00-media-autorun" 2>/dev/null; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "autorun-never=true"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "autorun-never not enabled"
  fi
fi

id="1.8.9"; title="Ensure GDM autorun-never is not overridden"; level=1
if ! gui_present; then not_applicable "$id" "$title" "$level"
elif ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate; then
    mkdir -p "/etc/dconf/db/${DCONF_DB}.d/locks"
    printf '/org/gnome/desktop/media-handling/autorun-never\n' > "/etc/dconf/db/${DCONF_DB}.d/locks/00-autorun_lock"
    dconf update >/dev/null 2>&1 || true
  fi
  if [[ -f "/etc/dconf/db/${DCONF_DB}.d/locks/00-autorun_lock" ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "autorun-never locked"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "autorun lock file missing"
  fi
fi

id="1.8.10"; title="Ensure XDMCP is not enabled"; level=1
if ! gui_present; then not_applicable "$id" "$title" "$level"
elif ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  if is_remediate && [[ -f /etc/gdm/custom.conf ]]; then
    backup_file /etc/gdm/custom.conf
    sed -i '/Enable=true/d' /etc/gdm/custom.conf
  fi
  if grep -q 'Enable=true' /etc/gdm/custom.conf 2>/dev/null; then
    log_result "$id" "$title" "$SECTION" "$level" "fail" "XDMCP Enable=true still present in /etc/gdm/custom.conf"
  else
    log_result "$id" "$title" "$SECTION" "$level" "pass" "XDMCP not enabled"
  fi
fi
