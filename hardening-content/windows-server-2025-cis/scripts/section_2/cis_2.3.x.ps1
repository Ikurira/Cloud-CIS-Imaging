# CIS Windows Server 2025 v2.1.0 2.3.x - Security Options
# Covers a high-confidence subset of the ~90 Security Options controls: Accounts,
# Audit, Devices, Domain member, Interactive logon, Microsoft network
# client/server, Network access/security (subset), Shutdown, System objects,
# and User Account Control. See manifest.yml for what is not yet scripted.

$Section = "2"

function Test-RegControl {
    param($Id, $Title, $Level, $Path, $Name, $ExpectedValue, [string]$Type = "DWord")

    if (-not (Test-CisLevelApplies $Level)) { Write-CisResult $Id $Title $Section $Level "skipped" "level not in scope"; return }

    if (Test-CisRemediate) { Set-CisRegistryValue -Path $Path -Name $Name -Value $ExpectedValue -Type $Type }

    $actual = Get-CisRegistryValue -Path $Path -Name $Name
    if ("$actual" -eq "$ExpectedValue") {
        Write-CisResult $Id $Title $Section $Level "pass" "$Name=$actual"
    } else {
        Write-CisResult $Id $Title $Section $Level "fail" "$Name=$actual (expected $ExpectedValue)"
    }
}

function Test-SeceditControl {
    param($Id, $Title, $Level, $KeyName, $ExpectedValue)

    if (-not (Test-CisLevelApplies $Level)) { Write-CisResult $Id $Title $Section $Level "skipped" "level not in scope"; return }

    if (Test-CisRemediate) { Set-CisSeceditValue -KeyName $KeyName -Value "$ExpectedValue" }

    $actual = Get-CisSeceditValue -KeyName $KeyName
    if ("$actual" -eq "$ExpectedValue") {
        Write-CisResult $Id $Title $Section $Level "pass" "$KeyName=$actual"
    } else {
        Write-CisResult $Id $Title $Section $Level "fail" "$KeyName=$actual (expected $ExpectedValue)"
    }
}

$Lsa           = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$Msv1_0        = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0"
$Netlogon      = "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters"
$PoliciesSys   = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
$Winlogon      = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$LanmanWks     = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
$LanmanSrv     = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
$Kernel        = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel"

# 2.3.1 Accounts
Test-SeceditControl "2.3.1.1" "Ensure 'Accounts: Guest account status' is set to 'Disabled' (MS only)" 1 "EnableGuestAccount" 0
Test-RegControl     "2.3.1.2" "Ensure 'Accounts: Limit local account use of blank passwords to console logon only' is set to 'Enabled'" 1 $Lsa "LimitBlankPasswordUse" 1

# 2.3.2 Audit
Test-RegControl "2.3.2.1" "Ensure 'Audit: Force audit policy subcategory settings to override audit policy category settings' is set to 'Enabled'" 1 $Lsa "SCENoApplyLegacyAuditPolicy" 1
Test-RegControl "2.3.2.2" "Ensure 'Audit: Shut down system immediately if unable to log security audits' is set to 'Disabled'" 1 $Lsa "CrashOnAuditFail" 0

# 2.3.4 Devices
Test-RegControl "2.3.4.1" "Ensure 'Devices: Prevent users from installing printer drivers' is set to 'Enabled'" 1 "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Providers\LanMan Print Services\Servers" "AddPrinterDrivers" 1

# 2.3.6 Domain member
Test-RegControl "2.3.6.1" "Ensure 'Domain member: Digitally encrypt or sign secure channel data (always)' is set to 'Enabled'" 1 $Netlogon "RequireSignOrSeal" 1
Test-RegControl "2.3.6.2" "Ensure 'Domain member: Digitally encrypt secure channel data (when possible)' is set to 'Enabled'" 1 $Netlogon "SealSecureChannel" 1
Test-RegControl "2.3.6.3" "Ensure 'Domain member: Digitally sign secure channel data (when possible)' is set to 'Enabled'" 1 $Netlogon "SignSecureChannel" 1
Test-RegControl "2.3.6.4" "Ensure 'Domain member: Disable machine account password changes' is set to 'Disabled'" 1 $Netlogon "DisablePasswordChange" 0
Test-RegControl "2.3.6.5" "Ensure 'Domain member: Maximum machine account password age' is set to '30 or fewer days, but not 0'" 1 $Netlogon "MaximumPasswordAge" 30
Test-RegControl "2.3.6.6" "Ensure 'Domain member: Require strong (Windows 2000 or later) session key' is set to 'Enabled'" 1 $Netlogon "RequireStrongKey" 1

# 2.3.7 Interactive logon
Test-RegControl "2.3.7.1" "Ensure 'Interactive logon: Do not require CTRL+ALT+DEL' is set to 'Disabled'" 1 $PoliciesSys "DisableCAD" 0
Test-RegControl "2.3.7.2" "Ensure 'Interactive logon: Don't display last signed-in' is set to 'Enabled'" 1 $PoliciesSys "DontDisplayLastUserName" 1
Test-RegControl "2.3.7.3" "Ensure 'Interactive logon: Machine inactivity limit' is set to '900 or fewer second(s), but not 0'" 1 $PoliciesSys "InactivityTimeoutSecs" 900
Test-RegControl "2.3.7.6" "Ensure 'Interactive logon: Number of previous logons to cache (in case domain controller is not available)' is set to '4 or fewer'" 1 $Winlogon "CachedLogonsCount" "4" "String"
Test-RegControl "2.3.7.7" "Ensure 'Interactive logon: Prompt user to change password before expiration' is set to 'between 5 and 14 days'" 1 $Winlogon "PasswordExpiryWarning" 14
Test-RegControl "2.3.7.9" "Ensure 'Interactive logon: Smart card removal behavior' is set to 'Lock Workstation'" 1 $Winlogon "ScRemoveOption" "1" "String"

# 2.3.8 Microsoft network client
Test-RegControl "2.3.8.1" "Ensure 'Microsoft network client: Digitally sign communications (always)' is set to 'Enabled'" 1 $LanmanWks "RequireSecuritySignature" 1
Test-RegControl "2.3.8.2" "Ensure 'Microsoft network client: Send unencrypted password to third-party SMB servers' is set to 'Disabled'" 1 $LanmanWks "EnablePlainTextPassword" 0

# 2.3.9 Microsoft network server
Test-RegControl "2.3.9.1" "Ensure 'Microsoft network server: Amount of idle time required before suspending session' is set to '15 or fewer minute(s)'" 1 $LanmanSrv "AutoDisconnect" 15
Test-RegControl "2.3.9.2" "Ensure 'Microsoft network server: Digitally sign communications (always)' is set to 'Enabled'" 1 $LanmanSrv "RequireSecuritySignature" 1
Test-RegControl "2.3.9.3" "Ensure 'Microsoft network server: Disconnect clients when logon hours expire' is set to 'Enabled'" 1 $LanmanSrv "EnableForcedLogOff" 1
Test-RegControl "2.3.9.4" "Ensure 'Microsoft network server: Server SPN target name validation level' is set to 'Accept if provided by client' or higher" 1 $LanmanSrv "SmbServerNameHardeningLevel" 1

# 2.3.10 Network access
Test-SeceditControl "2.3.10.1" "Ensure 'Network access: Allow anonymous SID/Name translation' is set to 'Disabled'" 1 "LSAAnonymousNameLookup" 0
Test-RegControl "2.3.10.2" "Ensure 'Network access: Do not allow anonymous enumeration of SAM accounts' is set to 'Enabled'" 1 $Lsa "RestrictAnonymousSAM" 1
Test-RegControl "2.3.10.3" "Ensure 'Network access: Do not allow anonymous enumeration of SAM accounts and shares' is set to 'Enabled'" 1 $Lsa "RestrictAnonymous" 1
Test-RegControl "2.3.10.4" "Ensure 'Network access: Do not allow storage of passwords and credentials for network authentication' is set to 'Enabled'" 1 $Lsa "DisableDomainCreds" 1
Test-RegControl "2.3.10.5" "Ensure 'Network access: Let Everyone permissions apply to anonymous users' is set to 'Disabled'" 1 $Lsa "EveryoneIncludesAnonymous" 0
Test-RegControl "2.3.10.11" "Ensure 'Network access: Restrict clients allowed to make remote calls to SAM' is set to 'Administrators: Remote Access: Allow'" 1 $Lsa "RestrictRemoteSAM" "O:BAG:BAD:(A;;RC;;;BA)" "String"
Test-RegControl "2.3.10.13" "Ensure 'Network access: Sharing and security model for local accounts' is set to 'Classic'" 1 $Lsa "ForceGuest" 0

# 2.3.11 Network security
Test-RegControl "2.3.11.1" "Ensure 'Network security: Allow Local System to use computer identity for NTLM' is set to 'Enabled'" 1 $Lsa "UseMachineId" 1
Test-RegControl "2.3.11.2" "Ensure 'Network security: Allow LocalSystem NULL session fallback' is set to 'Disabled'" 1 $Msv1_0 "allownullsessionfallback" 0
Test-RegControl "2.3.11.3" "Ensure 'Network Security: Allow PKU2U authentication requests to this computer to use online identities' is set to 'Disabled'" 1 "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\pku2u" "AllowOnlineID" 0
Test-RegControl "2.3.11.4" "Ensure 'Network security: Configure encryption types allowed for Kerberos' is set to 'AES128_HMAC_SHA1, AES256_HMAC_SHA1, Future encryption types'" 1 "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters" "SupportedEncryptionTypes" 2147483640
Test-SeceditControl "2.3.11.5" "Ensure 'Network security: Force logoff when logon hours expire' is set to 'Enabled'" 1 "ForceLogoffWhenHourExpire" 1
Test-RegControl "2.3.11.6" "Ensure 'Network security: LAN Manager authentication level' is set to 'Send NTLMv2 response only. Refuse LM & NTLM'" 1 $Lsa "LmCompatibilityLevel" 5
Test-RegControl "2.3.11.9" "Ensure 'Network security: Minimum session security for NTLM SSP based (including secure RPC) clients' is set to 'Require NTLMv2 session security, Require 128-bit encryption'" 1 $Msv1_0 "NTLMMinClientSec" 537395200
Test-RegControl "2.3.11.10" "Ensure 'Network security: Minimum session security for NTLM SSP based (including secure RPC) servers' is set to 'Require NTLMv2 session security, Require 128-bit encryption'" 1 $Msv1_0 "NTLMMinServerSec" 537395200

# 2.3.13 Shutdown
Test-RegControl "2.3.13.1" "Ensure 'Shutdown: Allow system to be shut down without having to log on' is set to 'Disabled'" 1 $PoliciesSys "ShutdownWithoutLogon" 0

# 2.3.15 System objects
Test-RegControl "2.3.15.1" "Ensure 'System objects: Require case insensitivity for non-Windows subsystems' is set to 'Enabled'" 1 $Kernel "ObCaseInsensitive" 1
Test-RegControl "2.3.15.2" "Ensure 'System objects: Strengthen default permissions of internal system objects' is set to 'Enabled'" 1 $Kernel "ProtectionMode" 1

# 2.3.17 User Account Control
Test-RegControl "2.3.17.1" "Ensure 'User Account Control: Admin Approval Mode for the Built-in Administrator account' is set to 'Enabled'" 1 $PoliciesSys "FilterAdministratorToken" 1
Test-RegControl "2.3.17.2" "Ensure 'User Account Control: Behavior of the elevation prompt for administrators in Admin Approval Mode' is set to 'Prompt for consent on the secure desktop'" 1 $PoliciesSys "ConsentPromptBehaviorAdmin" 2
Test-RegControl "2.3.17.3" "Ensure 'User Account Control: Behavior of the elevation prompt for standard users' is set to 'Automatically deny elevation requests'" 1 $PoliciesSys "ConsentPromptBehaviorUser" 0
Test-RegControl "2.3.17.4" "Ensure 'User Account Control: Detect application installations and prompt for elevation' is set to 'Enabled'" 1 $PoliciesSys "EnableInstallerDetection" 1
Test-RegControl "2.3.17.5" "Ensure 'User Account Control: Only elevate UIAccess applications that are installed in secure locations' is set to 'Enabled'" 1 $PoliciesSys "EnableSecureUIAPaths" 1
Test-RegControl "2.3.17.6" "Ensure 'User Account Control: Run all administrators in Admin Approval Mode' is set to 'Enabled'" 1 $PoliciesSys "EnableLUA" 1
Test-RegControl "2.3.17.7" "Ensure 'User Account Control: Switch to the secure desktop when prompting for elevation' is set to 'Enabled'" 1 $PoliciesSys "PromptOnSecureDesktop" 1
Test-RegControl "2.3.17.8" "Ensure 'User Account Control: Virtualize file and registry write failures to per-user locations' is set to 'Enabled'" 1 $PoliciesSys "EnableVirtualization" 1

# Controls not scripted here (see manifest.yml, status: planned):
#   2.3.1.3, 2.3.1.4 (site-specific admin/guest account renames), 2.3.3 DCOM,
#   2.3.5 Domain controller (all — not applicable to member servers), 2.3.7.4,
#   2.3.7.5 (site-specific logon banner text), 2.3.7.8, 2.3.10.6-2.3.10.10,
#   2.3.10.12, 2.3.11.7, 2.3.11.8, 2.3.11.11, 2.3.11.12, 2.3.11.13, 2.3.12,
#   2.3.14, 2.3.16.
