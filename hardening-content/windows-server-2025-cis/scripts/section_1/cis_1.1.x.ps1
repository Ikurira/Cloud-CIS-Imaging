# CIS Windows Server 2025 v2.1.0 1.1.x - Password Policy
# Reference implementation for the control-group script pattern (see ../../../CONTRACT.md).
# Values sourced from CIS_Microsoft_Windows_Server_2025_Benchmark_v2.1.0.pdf section 1.1.

$Section = "1"

function Test-PasswordHistory {
    $id = "1.1.1"; $title = "Ensure 'Enforce password history' is set to '24 or more password(s)'"; $level = 1
    if (-not (Test-CisLevelApplies $level)) { Write-CisResult $id $title $Section $level "skipped" "level not in scope"; return }

    if (Test-CisRemediate) { Set-CisSeceditValue -KeyName "PasswordHistorySize" -Value "24" }
    $val = [int](Get-CisSeceditValue -KeyName "PasswordHistorySize")
    if ($val -ge 24) { Write-CisResult $id $title $Section $level "pass" "PasswordHistorySize=$val" }
    else { Write-CisResult $id $title $Section $level "fail" "PasswordHistorySize=$val (expected >= 24)" }
}

function Test-MaxPasswordAge {
    $id = "1.1.2"; $title = "Ensure 'Maximum password age' is set to '365 or fewer days, but not 0'"; $level = 1
    if (-not (Test-CisLevelApplies $level)) { Write-CisResult $id $title $Section $level "skipped" "level not in scope"; return }

    if (Test-CisRemediate) { Set-CisSeceditValue -KeyName "MaximumPasswordAge" -Value "60" }
    $val = [int](Get-CisSeceditValue -KeyName "MaximumPasswordAge")
    if ($val -gt 0 -and $val -le 365) { Write-CisResult $id $title $Section $level "pass" "MaximumPasswordAge=$val" }
    else { Write-CisResult $id $title $Section $level "fail" "MaximumPasswordAge=$val (expected 1-365)" }
}

function Test-MinPasswordAge {
    $id = "1.1.3"; $title = "Ensure 'Minimum password age' is set to '1 or more day(s)'"; $level = 1
    if (-not (Test-CisLevelApplies $level)) { Write-CisResult $id $title $Section $level "skipped" "level not in scope"; return }

    if (Test-CisRemediate) { Set-CisSeceditValue -KeyName "MinimumPasswordAge" -Value "1" }
    $val = [int](Get-CisSeceditValue -KeyName "MinimumPasswordAge")
    if ($val -ge 1) { Write-CisResult $id $title $Section $level "pass" "MinimumPasswordAge=$val" }
    else { Write-CisResult $id $title $Section $level "fail" "MinimumPasswordAge=$val (expected >= 1)" }
}

function Test-MinPasswordLength {
    $id = "1.1.4"; $title = "Ensure 'Minimum password length' is set to '14 or more character(s)'"; $level = 1
    if (-not (Test-CisLevelApplies $level)) { Write-CisResult $id $title $Section $level "skipped" "level not in scope"; return }

    if (Test-CisRemediate) { Set-CisSeceditValue -KeyName "MinimumPasswordLength" -Value "14" }
    $val = [int](Get-CisSeceditValue -KeyName "MinimumPasswordLength")
    if ($val -ge 14) { Write-CisResult $id $title $Section $level "pass" "MinimumPasswordLength=$val" }
    else { Write-CisResult $id $title $Section $level "fail" "MinimumPasswordLength=$val (expected >= 14)" }
}

function Test-RelaxMinPasswordLengthLimits {
    $id = "1.1.6"; $title = "Ensure 'Relax minimum password length limits' is set to 'Enabled'"; $level = 1
    if (-not (Test-CisLevelApplies $level)) { Write-CisResult $id $title $Section $level "skipped" "level not in scope"; return }

    $path = "HKLM:\SYSTEM\CurrentControlSet\Control\SAM"
    if (Test-CisRemediate) { Set-CisRegistryValue -Path $path -Name "RelaxMinimumPasswordLengthLimits" -Value 1 -Type DWord }
    $val = Get-CisRegistryValue -Path $path -Name "RelaxMinimumPasswordLengthLimits"
    if ($val -eq 1) { Write-CisResult $id $title $Section $level "pass" "RelaxMinimumPasswordLengthLimits=1" }
    else { Write-CisResult $id $title $Section $level "fail" "RelaxMinimumPasswordLengthLimits=$val (expected 1)" }
}

function Test-PasswordComplexity {
    $id = "1.1.5"; $title = "Ensure 'Password must meet complexity requirements' is set to 'Enabled'"; $level = 1
    if (-not (Test-CisLevelApplies $level)) { Write-CisResult $id $title $Section $level "skipped" "level not in scope"; return }

    if (Test-CisRemediate) { Set-CisSeceditValue -KeyName "PasswordComplexity" -Value "1" }
    $val = [int](Get-CisSeceditValue -KeyName "PasswordComplexity")
    if ($val -eq 1) { Write-CisResult $id $title $Section $level "pass" "PasswordComplexity=1" }
    else { Write-CisResult $id $title $Section $level "fail" "PasswordComplexity=$val (expected 1)" }
}

function Test-ReversibleEncryption {
    $id = "1.1.7"; $title = "Ensure 'Store passwords using reversible encryption' is set to 'Disabled'"; $level = 1
    if (-not (Test-CisLevelApplies $level)) { Write-CisResult $id $title $Section $level "skipped" "level not in scope"; return }

    if (Test-CisRemediate) { Set-CisSeceditValue -KeyName "ClearTextPassword" -Value "0" }
    $val = [int](Get-CisSeceditValue -KeyName "ClearTextPassword")
    if ($val -eq 0) { Write-CisResult $id $title $Section $level "pass" "ClearTextPassword=0" }
    else { Write-CisResult $id $title $Section $level "fail" "ClearTextPassword=$val (expected 0)" }
}

Test-PasswordHistory
Test-MaxPasswordAge
Test-MinPasswordAge
Test-MinPasswordLength
Test-RelaxMinPasswordLengthLimits
Test-PasswordComplexity
Test-ReversibleEncryption
