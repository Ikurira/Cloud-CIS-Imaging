# CIS Windows Server 2025 v2.1.0 9.x - Windows Defender Firewall with Advanced Security
# Covers all three profiles (Domain, Private, Public) x 7 controls each = 21 controls.
# All settings are GPO-backed registry values under
# HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\<Profile>Profile — stable across
# every Windows Server release since these ADMX definitions have not changed.

$Section = "9"

function Test-FirewallReg {
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

function Test-FirewallProfile {
    param([string]$Num, [string]$ProfileName, [string]$LogFile)

    $base    = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsFirewall\${ProfileName}Profile"
    $logging = "$base\Logging"
    $p       = $ProfileName

    Test-FirewallReg "9.$Num.1" "Ensure 'Windows Firewall: ${p}: Firewall state' is set to 'On (recommended)'" 1 $base "EnableFirewall" 1
    Test-FirewallReg "9.$Num.2" "Ensure 'Windows Firewall: ${p}: Inbound connections' is set to 'Block (default)'" 1 $base "DefaultInboundAction" 1
    Test-FirewallReg "9.$Num.3" "Ensure 'Windows Firewall: ${p}: Settings: Display a notification' is set to 'No'" 1 $base "DisableNotifications" 1
    Test-FirewallReg "9.$Num.4" "Ensure 'Windows Firewall: ${p}: Logging: Name' is configured" 1 $logging "LogFilePath" "%systemroot%\system32\logfiles\firewall\$LogFile" "String"
    Test-FirewallReg "9.$Num.5" "Ensure 'Windows Firewall: ${p}: Logging: Size limit (KB)' is set to '16,384 KB or greater'" 1 $logging "LogFileSize" 16384
    Test-FirewallReg "9.$Num.6" "Ensure 'Windows Firewall: ${p}: Logging: Log dropped packets' is set to 'Yes'" 1 $logging "LogDroppedPackets" 1
    Test-FirewallReg "9.$Num.7" "Ensure 'Windows Firewall: ${p}: Logging: Log successful connections' is set to 'Yes'" 1 $logging "LogSuccessfulConnections" 1
}

Test-FirewallProfile -Num "1" -ProfileName "Domain"  -LogFile "domainfw.log"
Test-FirewallProfile -Num "2" -ProfileName "Private" -LogFile "privatefw.log"
Test-FirewallProfile -Num "3" -ProfileName "Public"  -LogFile "publicfw.log"
