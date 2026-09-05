#!/usr/bin/env bash
# CIS RHEL9 v3.0.0 2.1.x - Unused server services.
# Package/service name lists and server/mask defaults ported from Images/vars/main.yml and
# Images/defaults/main/main.yml. Where a "keep" default is true (nfs, rpcbind — this role's
# default assumes they're needed, e.g. for EFS/NFS-backed EC2 workloads), the control is
# reported skipped/not-applicable rather than forced off, matching upstream behavior.
SECTION="2"

# manage_service_group <id> <title> <level> <keep:0|1> <mask:0|1> <pkgs_csv> <svcs_csv>
manage_service_group() {
  local id="$1" title="$2" level="$3" keep="$4" mask="$5" pkgs_csv="$6" svcs_csv="$7"
  local -a pkgs svcs
  IFS=',' read -r -a pkgs <<< "$pkgs_csv"
  IFS=',' read -r -a svcs <<< "$svcs_csv"

  if ! level_applies "$level"; then
    log_result "$id" "$title" "$SECTION" "$level" "skipped" "level ${level} not in scope"
    return
  fi
  if [[ "$keep" -eq 1 ]]; then
    log_result "$id" "$title" "$SECTION" "$level" "skipped" "not applicable: service declared required by site default (server role needs it)"
    return
  fi

  if is_remediate; then
    if [[ "$mask" -eq 1 ]]; then
      for s in "${svcs[@]}"; do mask_and_disable_service "${s%.service}"; mask_and_disable_service "$s"; done
    else
      for p in "${pkgs[@]}"; do remove_package "$p"; done
    fi
  fi

  if [[ "$mask" -eq 1 ]]; then
    local all_masked=1
    for s in "${svcs[@]}"; do service_inactive_and_masked "${s%.socket}" || all_masked=0; done
    [[ "$all_masked" -eq 1 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "services masked: ${svcs_csv}" \
      || log_result "$id" "$title" "$SECTION" "$level" "fail" "one or more services not masked: ${svcs_csv}"
  else
    local any_installed=0
    for p in "${pkgs[@]}"; do package_installed "$p" && any_installed=1; done
    [[ "$any_installed" -eq 0 ]] && log_result "$id" "$title" "$SECTION" "$level" "pass" "packages not installed: ${pkgs_csv}" \
      || log_result "$id" "$title" "$SECTION" "$level" "fail" "one or more packages still installed: ${pkgs_csv}"
  fi
}

manage_service_group "2.1.1"  "Ensure autofs services are not in use"                 1 0 0 "autofs" "autofs.service"
manage_service_group "2.1.2"  "Ensure avahi daemon services are not in use"           1 0 0 "avahi-autoipd,avahi" "avahi-daemon.socket,avahi-daemon.service"
manage_service_group "2.1.3"  "Ensure dhcp server services are not in use"            1 0 0 "dhcp-server" "dhcpd.service,dhcpd6.service"
manage_service_group "2.1.4"  "Ensure dns server services are not in use"             1 0 0 "bind" "named.service"
manage_service_group "2.1.5"  "Ensure dnsmasq services are not in use"                1 0 0 "dnsmasq" "dnsmasq.service"
manage_service_group "2.1.6"  "Ensure samba file server services are not in use"      1 0 0 "samba" "smb.service"
manage_service_group "2.1.7"  "Ensure ftp server services are not in use"             1 0 0 "vsftpd" "vsftpd.service"
manage_service_group "2.1.8"  "Ensure message access server services are not in use"  1 0 0 "dovecot,cyrus-imapd" "dovecot.socket,dovecot.service,cyrus-imapd.service"
manage_service_group "2.1.9"  "Ensure network file system services are not in use"    1 1 0 "nfs-utils" "nfs-server.service"
manage_service_group "2.1.10" "Ensure nis server services are not in use"             1 0 0 "ypserv" "ypserv.service"
manage_service_group "2.1.11" "Ensure print server services are not in use"           1 0 0 "cups" "cups.service,cups.socket"
manage_service_group "2.1.12" "Ensure rpcbind services are not in use"                1 1 0 "rpcbind" "rpcbind.service,rpcbind.socket"
manage_service_group "2.1.13" "Ensure rsync services are not in use"                  1 0 0 "rsync-daemon" "rsyncd.service,rsyncd.socket"
manage_service_group "2.1.14" "Ensure snmp services are not in use"                   1 0 0 "net-snmp" "net-snmp.service"
manage_service_group "2.1.15" "Ensure telnet server services are not in use"          1 0 0 "telnet-server" "telnet.socket"
manage_service_group "2.1.16" "Ensure tftp server services are not in use"            1 0 0 "tftp-server" "tftp.service,tftp.socket"
manage_service_group "2.1.17" "Ensure web proxy server services are not in use"       1 0 0 "squid" "squid.service"
manage_service_group "2.1.18" "Ensure web server services are not in use (httpd)"    1 0 0 "httpd" "httpd.service"
manage_service_group "2.1.18" "Ensure web server services are not in use (nginx)"    1 0 0 "nginx" "nginx.service"
manage_service_group "2.1.19" "Ensure xinetd services are not in use"                 1 0 0 "xinetd" "xinetd.service"

id="2.1.20"; title="Ensure X window server services are not in use"; level=2
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
else
  is_remediate && remove_package xorg-x11-server-common
  if ! package_installed xorg-x11-server-common; then log_result "$id" "$title" "$SECTION" "$level" "pass" "xorg-x11-server-common not installed"
  else log_result "$id" "$title" "$SECTION" "$level" "fail" "xorg-x11-server-common is installed"; fi
fi

id="2.1.21"; title="Ensure mail transfer agents are configured for local-only mode"; level=1
if ! level_applies "$level"; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "level not in scope"
elif ! package_installed postfix; then log_result "$id" "$title" "$SECTION" "$level" "skipped" "postfix not installed"
else
  is_remediate && line_in_file /etc/postfix/main.cf '^(#)?inet_interfaces' 'inet_interfaces = loopback-only'
  if grep -qE '^inet_interfaces\s*=\s*loopback-only' /etc/postfix/main.cf 2>/dev/null; then
    log_result "$id" "$title" "$SECTION" "$level" "pass" "postfix inet_interfaces=loopback-only"
  else
    log_result "$id" "$title" "$SECTION" "$level" "fail" "postfix inet_interfaces not set to loopback-only"
  fi
fi

log_result "2.1.22" "Ensure only approved services are listening on a network interface" "$SECTION" 1 "skipped" "manual review control: run 'systemctl list-units --type=service' and 'ss -tulpn', confirm every listener matches site policy"
