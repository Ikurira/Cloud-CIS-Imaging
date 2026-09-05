# CIS Windows Server 2025 v2.1.0 17.x - Advanced Audit Policy Configuration
# DC-only subcategories (17.1.2, 17.1.3, 17.2.2, 17.2.3, 17.2.4, 17.4.1, 17.4.2) are
# not applicable to EC2 member-server instances and are not scripted here.

$Section = "17"

function Test-AuditSubcategory {
    param($Id, $Title, $Level, $Subcategory, [bool]$Success, [bool]$Failure)

    if (-not (Test-CisLevelApplies $Level)) { Write-CisResult $Id $Title $Section $Level "skipped" "level not in scope"; return }

    if (Test-CisRemediate) { Set-CisAuditPolicy -Subcategory $Subcategory -Success $Success -Failure $Failure }

    $actual = Get-CisAuditPolicy -Subcategory $Subcategory
    if ($null -eq $actual) {
        Write-CisResult $Id $Title $Section $Level "error" "could not read auditpol state for '$Subcategory'"
        return
    }
    if ($actual.Success -eq $Success -and $actual.Failure -eq $Failure) {
        Write-CisResult $Id $Title $Section $Level "pass" "$Subcategory success=$($actual.Success) failure=$($actual.Failure)"
    } else {
        Write-CisResult $Id $Title $Section $Level "fail" "$Subcategory success=$($actual.Success) failure=$($actual.Failure) (expected success=$Success failure=$Failure)"
    }
}

# 17.1 Account Logon
Test-AuditSubcategory "17.1.1" "Ensure 'Audit Credential Validation' is set to 'Success and Failure'" 1 "Credential Validation" $true $true

# 17.2 Account Management
Test-AuditSubcategory "17.2.1" "Ensure 'Audit Application Group Management' is set to 'Success and Failure'" 1 "Application Group Management" $true $true
Test-AuditSubcategory "17.2.5" "Ensure 'Audit Security Group Management' is set to include 'Success'" 1 "Security Group Management" $true $false
Test-AuditSubcategory "17.2.6" "Ensure 'Audit User Account Management' is set to 'Success and Failure'" 1 "User Account Management" $true $true

# 17.3 Detailed Tracking
Test-AuditSubcategory "17.3.1" "Ensure 'Audit PNP Activity' is set to include 'Success'" 1 "Plug and Play Events" $true $false
Test-AuditSubcategory "17.3.2" "Ensure 'Audit Process Creation' is set to include 'Success'" 1 "Process Creation" $true $false

# 17.5 Logon/Logoff
Test-AuditSubcategory "17.5.1" "Ensure 'Audit Account Lockout' is set to include 'Failure'" 1 "Account Lockout" $false $true
Test-AuditSubcategory "17.5.2" "Ensure 'Audit Group Membership' is set to include 'Success'" 1 "Group Membership" $true $false
Test-AuditSubcategory "17.5.3" "Ensure 'Audit Logoff' is set to include 'Success'" 1 "Logoff" $true $false
Test-AuditSubcategory "17.5.4" "Ensure 'Audit Logon' is set to 'Success and Failure'" 1 "Logon" $true $true
Test-AuditSubcategory "17.5.5" "Ensure 'Audit Other Logon/Logoff Events' is set to 'Success and Failure'" 1 "Other Logon/Logoff Events" $true $true
Test-AuditSubcategory "17.5.6" "Ensure 'Audit Special Logon' is set to include 'Success'" 1 "Special Logon" $true $false

# 17.6 Object Access
Test-AuditSubcategory "17.6.1" "Ensure 'Audit Detailed File Share' is set to include 'Failure'" 1 "Detailed File Share" $false $true
Test-AuditSubcategory "17.6.2" "Ensure 'Audit File Share' is set to 'Success and Failure'" 1 "File Share" $true $true
Test-AuditSubcategory "17.6.3" "Ensure 'Audit Other Object Access Events' is set to 'Success and Failure'" 1 "Other Object Access Events" $true $true
Test-AuditSubcategory "17.6.4" "Ensure 'Audit Removable Storage' is set to 'Success and Failure'" 1 "Removable Storage" $true $true

# 17.7 Policy Change
Test-AuditSubcategory "17.7.1" "Ensure 'Audit Audit Policy Change' is set to include 'Success'" 1 "Audit Policy Change" $true $false
Test-AuditSubcategory "17.7.2" "Ensure 'Audit Authentication Policy Change' is set to include 'Success'" 1 "Authentication Policy Change" $true $false
Test-AuditSubcategory "17.7.3" "Ensure 'Audit Authorization Policy Change' is set to include 'Success'" 1 "Authorization Policy Change" $true $false
Test-AuditSubcategory "17.7.4" "Ensure 'Audit MPSSVC Rule-Level Policy Change' is set to 'Success and Failure'" 1 "MPSSVC Rule-Level Policy Change" $true $true
Test-AuditSubcategory "17.7.5" "Ensure 'Audit Other Policy Change Events' is set to include 'Failure'" 1 "Other Policy Change Events" $false $true

# 17.8 Privilege Use
Test-AuditSubcategory "17.8.1" "Ensure 'Audit Sensitive Privilege Use' is set to 'Success'" 1 "Sensitive Privilege Use" $true $false

# 17.9 System
Test-AuditSubcategory "17.9.1" "Ensure 'Audit IPsec Driver' is set to 'Success and Failure'" 1 "IPsec Driver" $true $true
Test-AuditSubcategory "17.9.2" "Ensure 'Audit Other System Events' is set to 'Success and Failure'" 1 "Other System Events" $true $true
Test-AuditSubcategory "17.9.3" "Ensure 'Audit Security State Change' is set to include 'Success'" 1 "Security State Change" $true $false
Test-AuditSubcategory "17.9.4" "Ensure 'Audit Security System Extension' is set to include 'Success'" 1 "Security System Extension" $true $false
Test-AuditSubcategory "17.9.5" "Ensure 'Audit System Integrity' is set to 'Success and Failure'" 1 "System Integrity" $true $true

# Not scripted (DC only, not applicable to EC2 member servers): 17.1.2, 17.1.3,
# 17.2.2, 17.2.3, 17.2.4, 17.4.1, 17.4.2 — see manifest.yml.
