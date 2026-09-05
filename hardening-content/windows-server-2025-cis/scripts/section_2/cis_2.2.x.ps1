# CIS Windows Server 2025 v2.1.0 2.2.x - User Rights Assignment
# Implements the Member-Server (MS-only) variant of each control where the CIS
# benchmark lists separate DC/MS recommendations — this pipeline targets EC2
# instances, never domain controllers. DC-only controls are not applicable and
# are not scripted (see manifest.yml).

$Section = "2"

function Test-UserRight {
    param($Id, $Title, $Level, $Right, [string[]]$Principals)

    if (-not (Test-CisLevelApplies $Level)) { Write-CisResult $Id $Title $Section $Level "skipped" "level not in scope"; return }

    if (Test-CisRemediate) { Set-CisUserRight -Right $Right -Principals $Principals }

    if (Test-CisUserRightMatches -Right $Right -ExpectedPrincipals $Principals) {
        Write-CisResult $Id $Title $Section $Level "pass" "$Right = $($Principals -join ', ')"
    } else {
        $actual = (Get-CisUserRightPrincipals -Right $Right) -join ', '
        Write-CisResult $Id $Title $Section $Level "fail" "$Right actual=[$actual] expected=[$($Principals -join ', ')]"
    }
}

Test-UserRight "2.2.1"  "Ensure 'Access Credential Manager as a trusted caller' is set to 'No One'" 1 "SeTrustedCredManAccessPrivilege" @()
Test-UserRight "2.2.3"  "Ensure 'Access this computer from the network' is set to 'Administrators, Authenticated Users' (MS only)" 1 "SeNetworkLogonRight" @("Administrators", "Authenticated Users")
Test-UserRight "2.2.4"  "Ensure 'Act as part of the operating system' is set to 'No One'" 1 "SeTcbPrivilege" @()
Test-UserRight "2.2.6"  "Ensure 'Adjust memory quotas for a process' is set to 'Administrators, LOCAL SERVICE, NETWORK SERVICE'" 1 "SeIncreaseQuotaPrivilege" @("Administrators", "LOCAL SERVICE", "NETWORK SERVICE")
Test-UserRight "2.2.8"  "Ensure 'Allow log on locally' is set to 'Administrators' (MS only)" 1 "SeInteractiveLogonRight" @("Administrators")
Test-UserRight "2.2.10" "Ensure 'Allow log on through Remote Desktop Services' is set to 'Administrators, Remote Desktop Users' (MS only)" 1 "SeRemoteInteractiveLogonRight" @("Administrators", "Remote Desktop Users")
Test-UserRight "2.2.11" "Ensure 'Back up files and directories' is set to 'Administrators'" 1 "SeBackupPrivilege" @("Administrators")
Test-UserRight "2.2.12" "Ensure 'Change the system time' is set to 'Administrators, LOCAL SERVICE'" 1 "SeSystemtimePrivilege" @("Administrators", "LOCAL SERVICE")
Test-UserRight "2.2.13" "Ensure 'Create a pagefile' is set to 'Administrators'" 1 "SeCreatePagefilePrivilege" @("Administrators")
Test-UserRight "2.2.14" "Ensure 'Create a token object' is set to 'No One'" 1 "SeCreateTokenPrivilege" @()
Test-UserRight "2.2.15" "Ensure 'Create global objects' is set to 'Administrators, LOCAL SERVICE, NETWORK SERVICE, SERVICE'" 1 "SeCreateGlobalPrivilege" @("Administrators", "LOCAL SERVICE", "NETWORK SERVICE", "SERVICE")
Test-UserRight "2.2.16" "Ensure 'Create permanent shared objects' is set to 'No One'" 1 "SeCreatePermanentPrivilege" @()
Test-UserRight "2.2.19" "Ensure 'Debug programs' is set to 'Administrators'" 1 "SeDebugPrivilege" @("Administrators")
Test-UserRight "2.2.21" "Ensure 'Deny access to this computer from the network' to include 'Guests, Local account' (MS only)" 1 "SeDenyNetworkLogonRight" @("Guests", "Local account")
Test-UserRight "2.2.22" "Ensure 'Deny log on as a batch job' to include 'Guests'" 1 "SeDenyBatchLogonRight" @("Guests")
Test-UserRight "2.2.23" "Ensure 'Deny log on as a service' to include 'Guests'" 1 "SeDenyServiceLogonRight" @("Guests")
Test-UserRight "2.2.24" "Ensure 'Deny log on locally' to include 'Guests'" 1 "SeDenyInteractiveLogonRight" @("Guests")
Test-UserRight "2.2.26" "Ensure 'Deny log on through Remote Desktop Services' is set to 'Guests, Local account' (MS only)" 1 "SeDenyRemoteInteractiveLogonRight" @("Guests", "Local account")
Test-UserRight "2.2.29" "Ensure 'Force shutdown from a remote system' is set to 'Administrators'" 1 "SeRemoteShutdownPrivilege" @("Administrators")
Test-UserRight "2.2.30" "Ensure 'Generate security audits' is set to 'LOCAL SERVICE, NETWORK SERVICE'" 1 "SeAuditPrivilege" @("LOCAL SERVICE", "NETWORK SERVICE")
Test-UserRight "2.2.34" "Ensure 'Load and unload device drivers' is set to 'Administrators'" 1 "SeLoadDriverPrivilege" @("Administrators")
Test-UserRight "2.2.35" "Ensure 'Lock pages in memory' is set to 'No One'" 1 "SeLockMemoryPrivilege" @()
Test-UserRight "2.2.38" "Ensure 'Manage auditing and security log' is set to 'Administrators' (MS only)" 1 "SeSecurityPrivilege" @("Administrators")
Test-UserRight "2.2.39" "Ensure 'Modify an object label' is set to 'No One'" 1 "SeRelabelPrivilege" @()
Test-UserRight "2.2.40" "Ensure 'Modify firmware environment values' is set to 'Administrators'" 1 "SeSystemEnvironmentPrivilege" @("Administrators")
Test-UserRight "2.2.41" "Ensure 'Perform volume maintenance tasks' is set to 'Administrators'" 1 "SeManageVolumePrivilege" @("Administrators")
Test-UserRight "2.2.42" "Ensure 'Profile single process' is set to 'Administrators'" 1 "SeProfileSingleProcessPrivilege" @("Administrators")
Test-UserRight "2.2.44" "Ensure 'Replace a process level token' is set to 'LOCAL SERVICE, NETWORK SERVICE'" 1 "SeAssignPrimaryTokenPrivilege" @("LOCAL SERVICE", "NETWORK SERVICE")
Test-UserRight "2.2.45" "Ensure 'Restore files and directories' is set to 'Administrators'" 1 "SeRestorePrivilege" @("Administrators")
Test-UserRight "2.2.46" "Ensure 'Shut down the system' is set to 'Administrators'" 1 "SeShutdownPrivilege" @("Administrators")
Test-UserRight "2.2.48" "Ensure 'Take ownership of files or other objects' is set to 'Administrators'" 1 "SeTakeOwnershipPrivilege" @("Administrators")

# Controls not scripted here (see manifest.yml, status: planned):
#   2.2.2, 2.2.5, 2.2.7, 2.2.9, 2.2.17, 2.2.25, 2.2.27, 2.2.28, 2.2.31, 2.2.32,
#   2.2.33, 2.2.36, 2.2.37, 2.2.43, 2.2.47 — DC-only variants (not applicable to
#   EC2 member-server instances) or environment-dependent principals (Hyper-V
#   host role, delegation scenarios) that need site-specific judgment.
