# CIS Windows Server 2025 v2.1.0 18.x - Administrative Templates (Computer)
# This section alone has 400+ leaf settings in the benchmark; this file covers a
# high-value subset (SMBv1, NetBIOS, Credential Guard/LSASS protection, AutoPlay,
# RDP NLA, WinRM, Automatic Updates). See manifest.yml for the full catalogue and
# what remains planned.

$Section = "18"
$Lsa     = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"

function Test-RegControl18 {
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

# 18.4 MS Security Guide
Test-RegControl18 "18.4.2" "Ensure 'Configure SMB v1 client driver' is set to 'Enabled: Disable driver (recommended)'" 1 "HKLM:\SYSTEM\CurrentControlSet\Services\mrxsmb10" "Start" 4
Test-RegControl18 "18.4.3" "Ensure 'Configure SMB v1 server' is set to 'Disabled'" 1 "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" "SMB1" 0

# 18.6 Network
Test-RegControl18 "18.6.4.2" "Ensure 'Configure NetBIOS settings' is set to 'Enabled: Disable NetBIOS name resolution'" 1 "HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters" "DisableNetBiosNameResolution" 1

# 18.9.5 Device Guard / Credential Guard
Test-RegControl18 "18.9.5.5" "Ensure 'Turn On Virtualization Based Security: Credential Guard Configuration' is set to 'Enabled with UEFI lock' (MS Only)" 1 $Lsa "LsaCfgFlags" 1

# 18.9.27 Local Security Authority
Test-RegControl18 "18.9.27.1" "Ensure 'Allow Custom SSPs and APs to be loaded into LSASS' is set to 'Disabled'" 1 $Lsa "AllowCustomSSPsAPs" 0
Test-RegControl18 "18.9.27.2" "Ensure 'Configures LSASS to run as a protected process' is set to 'Enabled with UEFI Lock'" 1 $Lsa "RunAsPPL" 1

# 18.10.8 AutoPlay Policies
Test-RegControl18 "18.10.8.1" "Ensure 'Disallow Autoplay for non-volume devices' is set to 'Enabled'" 1 "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoAutoplayfornonVolume" 1
Test-RegControl18 "18.10.8.2" "Ensure 'Set the default behavior for AutoRun' is set to 'Enabled: Do not execute any autorun commands'" 1 "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoAutorun" 1
Test-RegControl18 "18.10.8.3" "Ensure 'Turn off Autoplay' is set to 'Enabled: All drives'" 1 "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoDriveTypeAutoRun" 255

# 18.10.57.3.9 Remote Desktop Services Security
Test-RegControl18 "18.10.57.3.9.4" "Ensure 'Require user authentication for remote connections by using Network Level Authentication' is set to 'Enabled'" 1 "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" "UserAuthentication" 1

# 18.10.90 Windows Remote Management (WinRM)
Test-RegControl18 "18.10.90.1.1" "Ensure WinRM Client 'Allow Basic authentication' is set to 'Disabled'" 1 "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Client" "AllowBasic" 0
Test-RegControl18 "18.10.90.2.1" "Ensure WinRM Service 'Allow Basic authentication' is set to 'Disabled'" 1 "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" "AllowBasic" 0
Test-RegControl18 "18.10.90.2.4" "Ensure 'Disallow WinRM from storing RunAs credentials' is set to 'Enabled'" 1 "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WinRM\Service" "DisableRunAs" 1

# 18.10.94 Windows Update
Test-RegControl18 "18.10.94.2.1" "Ensure 'Configure Automatic Updates' is set to 'Enabled'" 1 "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" "NoAutoUpdate" 0

# Controls not scripted here (see manifest.yml, status: planned): 18.9.5.6 (DC-only,
# mutually exclusive with 18.9.5.5), and the remaining ~400 Administrative Templates
# leaves catalogued in the manifest under section 18.
