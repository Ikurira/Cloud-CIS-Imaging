# CIS Windows Server 2025 v2.1.0 1.2.x - Account Lockout Policy

$Section = "1"

function Test-LockoutDuration {
    $id = "1.2.1"; $title = "Ensure 'Account lockout duration' is set to '15 or more minute(s)'"; $level = 1
    if (-not (Test-CisLevelApplies $level)) { Write-CisResult $id $title $Section $level "skipped" "level not in scope"; return }

    if (Test-CisRemediate) { Set-CisSeceditValue -KeyName "LockoutDuration" -Value "15" }
    $val = [int](Get-CisSeceditValue -KeyName "LockoutDuration")
    if ($val -ge 15) { Write-CisResult $id $title $Section $level "pass" "LockoutDuration=$val" }
    else { Write-CisResult $id $title $Section $level "fail" "LockoutDuration=$val (expected >= 15)" }
}

function Test-LockoutThreshold {
    $id = "1.2.2"; $title = "Ensure 'Account lockout threshold' is set to '5 or fewer invalid logon attempt(s), but not 0'"; $level = 1
    if (-not (Test-CisLevelApplies $level)) { Write-CisResult $id $title $Section $level "skipped" "level not in scope"; return }

    if (Test-CisRemediate) { Set-CisSeceditValue -KeyName "LockoutBadCount" -Value "5" }
    $val = [int](Get-CisSeceditValue -KeyName "LockoutBadCount")
    if ($val -ge 1 -and $val -le 5) { Write-CisResult $id $title $Section $level "pass" "LockoutBadCount=$val" }
    else { Write-CisResult $id $title $Section $level "fail" "LockoutBadCount=$val (expected 1-5)" }
}

function Test-AdminLockout {
    # 1.2.3 is documented by CIS as Manual, MS-only — no deterministic secedit/registry
    # key controls this on Windows Server (member server); it's a DC-only GPO toggle in
    # practice, so treat as a manual-review item like the RHEL side's discovery-only controls.
    $id = "1.2.3"; $title = "Ensure 'Allow Administrator account lockout' is set to 'Enabled' (MS only)"; $level = 1
    Write-CisResult $id $title $Section $level "skipped" "manual/MS-only control: verify via Local Security Policy on the target OS release"
}

function Test-ResetLockoutCounter {
    $id = "1.2.4"; $title = "Ensure 'Reset account lockout counter after' is set to '15 or more minute(s)'"; $level = 1
    if (-not (Test-CisLevelApplies $level)) { Write-CisResult $id $title $Section $level "skipped" "level not in scope"; return }

    if (Test-CisRemediate) { Set-CisSeceditValue -KeyName "ResetLockoutCount" -Value "15" }
    $val = [int](Get-CisSeceditValue -KeyName "ResetLockoutCount")
    if ($val -ge 15) { Write-CisResult $id $title $Section $level "pass" "ResetLockoutCount=$val" }
    else { Write-CisResult $id $title $Section $level "fail" "ResetLockoutCount=$val (expected >= 15)" }
}

Test-LockoutDuration
Test-LockoutThreshold
Test-AdminLockout
Test-ResetLockoutCounter
