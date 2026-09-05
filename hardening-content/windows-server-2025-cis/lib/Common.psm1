# Shared helpers for CIS Windows Server 2025 hardening scripts. Imported by every
# scripts/section_*/cis_*.ps1 file. Implements the result-stream contract in
# hardening-content/CONTRACT.md.

$Script:ResultsDir  = "C:\ProgramData\CISHardening"
$Script:ResultsFile = Join-Path $Script:ResultsDir "results.jsonl"
$Script:CisMode     = if ($env:CIS_MODE) { $env:CIS_MODE } else { "audit" }   # audit|remediate
$Script:CisLevel    = if ($env:CIS_LEVEL) { [int]$env:CIS_LEVEL } else { 1 }  # 1|2
$Script:NonCompliantCount = 0

if (-not (Test-Path $Script:ResultsDir)) {
    New-Item -ItemType Directory -Path $Script:ResultsDir -Force | Out-Null
}
if (-not (Test-Path $Script:ResultsFile)) {
    New-Item -ItemType File -Path $Script:ResultsFile -Force | Out-Null
}

function Write-CisResult {
    param(
        [Parameter(Mandatory)][string]$ControlId,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][int]$Level,
        [Parameter(Mandatory)][ValidateSet("pass","fail","error","skipped")][string]$Status,
        [string]$Message = ""
    )

    $obj = [ordered]@{
        control_id = $ControlId
        title      = $Title
        section    = $Section
        level      = $Level
        status     = $Status
        mode       = $Script:CisMode
        message    = $Message
        timestamp  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    $line = $obj | ConvertTo-Json -Compress
    Write-Output $line
    Add-Content -Path $Script:ResultsFile -Value $line

    if ($Status -eq "fail" -or $Status -eq "error") {
        $Script:NonCompliantCount++
    }
}

function Test-CisRemediate {
    return $Script:CisMode -eq "remediate"
}

function Test-CisLevelApplies {
    param([int]$ControlLevel)
    return $ControlLevel -le $Script:CisLevel
}

function Set-CisRegistryValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [ValidateSet("DWord","String","MultiString","Binary","QWord")][string]$Type = "DWord"
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Get-CisRegistryValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )
    try {
        return (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop).$Name
    } catch {
        return $null
    }
}

function Get-CisNonCompliantCount {
    return $Script:NonCompliantCount
}

# Account Policy / local security policy settings (password policy, lockout policy) are not
# registry values — they live in the secedit "System Access" security database. These helpers
# round-trip through `secedit /export` and `secedit /configure` against a scratch .inf.

function Get-CisSeceditValue {
    param([Parameter(Mandatory)][string]$KeyName)

    $tmp = Join-Path $env:TEMP "cis-secedit-export.inf"
    secedit /export /cfg $tmp /quiet | Out-Null
    $line = Select-String -Path $tmp -Pattern "^$KeyName\s*=" -ErrorAction SilentlyContinue
    Remove-Item $tmp -ErrorAction SilentlyContinue
    if (-not $line) { return $null }
    return ($line.Line -split "=")[1].Trim()
}

function Set-CisSeceditValue {
    param(
        [Parameter(Mandatory)][string]$KeyName,
        [Parameter(Mandatory)][string]$Value,
        # Section to insert under when $KeyName does not already exist in a fresh
        # export (almost never needed for System Access / Privilege Rights keys,
        # since a default export already lists every one of them).
        [string]$Section = "System Access"
    )

    $exportPath = Join-Path $env:TEMP "cis-secedit-export.inf"
    $dbPath     = Join-Path $env:TEMP "cis-secedit.sdb"
    secedit /export /cfg $exportPath /quiet | Out-Null

    $content = Get-Content $exportPath
    if ($content -match "^$KeyName\s*=") {
        $content = $content -replace "^$KeyName\s*=.*", "$KeyName = $Value"
    } else {
        $insertAt = ($content | Select-String "^\[$Section\]").LineNumber
        $content = $content[0..($insertAt - 1)] + "$KeyName = $Value" + $content[$insertAt..($content.Length - 1)]
    }
    Set-Content -Path $exportPath -Value $content

    secedit /configure /db $dbPath /cfg $exportPath /quiet | Out-Null
    Remove-Item $exportPath, $dbPath -ErrorAction SilentlyContinue
}

# --- User Rights Assignment (secedit "Privilege Rights" section) ------------
# Privilege Rights values are comma-separated SIDs, e.g. "*S-1-5-32-544,*S-1-5-19".
# These helpers translate between human-readable principal names and SIDs so
# control scripts can express the CIS-recommended principal list by name.

function Resolve-CisSid {
    param([Parameter(Mandatory)][string]$AccountName)

    # A few CIS-recommended principals are well-known SIDs with no resolvable
    # NTAccount name on a standalone/member server (they only ever show up as
    # raw SIDs in a secedit export).
    $wellKnown = @{
        "Local account"                                   = "S-1-5-113"
        "Local account and member of Administrators group" = "S-1-5-114"
    }
    if ($wellKnown.ContainsKey($AccountName)) { return $wellKnown[$AccountName] }

    try {
        return (New-Object System.Security.Principal.NTAccount($AccountName)).
            Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {
        return $null
    }
}

function Set-CisUserRight {
    param(
        [Parameter(Mandatory)][string]$Right,          # e.g. SeDenyNetworkLogonRight
        [Parameter(Mandatory)][string[]]$Principals     # e.g. @("Guests")
    )
    $sids = $Principals | ForEach-Object { Resolve-CisSid $_ } | Where-Object { $_ }
    $value = ($sids | ForEach-Object { "*$_" }) -join ","
    Set-CisSeceditValue -KeyName $Right -Value $value -Section "Privilege Rights"
}

function Get-CisUserRightPrincipals {
    param([Parameter(Mandatory)][string]$Right)

    $tmp = Join-Path $env:TEMP "cis-secedit-export.inf"
    secedit /export /cfg $tmp /areas USER_RIGHTS /quiet | Out-Null
    $line = Select-String -Path $tmp -Pattern "^$Right\s*=" -ErrorAction SilentlyContinue
    Remove-Item $tmp -ErrorAction SilentlyContinue
    if (-not $line) { return @() }

    $rawValue = ($line.Line -split "=", 2)[1].Trim()
    if ([string]::IsNullOrWhiteSpace($rawValue)) { return @() }

    return ($rawValue -split ",") | ForEach-Object {
        $sid = $_.Trim().TrimStart("*")
        try {
            (New-Object System.Security.Principal.SecurityIdentifier($sid)).
                Translate([System.Security.Principal.NTAccount]).Value
        } catch {
            $sid
        }
    }
}

# Returns $true if the right's current principal set is exactly the expected
# set (by SID, order-independent) — the shape every Test-<Right> function needs.
function Test-CisUserRightMatches {
    param(
        [Parameter(Mandatory)][string]$Right,
        [Parameter(Mandatory)][string[]]$ExpectedPrincipals
    )
    $expectedSids = $ExpectedPrincipals | ForEach-Object { Resolve-CisSid $_ } | Where-Object { $_ } | Sort-Object
    $actualSids   = Get-CisUserRightPrincipals -Right $Right | ForEach-Object { Resolve-CisSid $_ } | Where-Object { $_ } | Sort-Object
    return (@($expectedSids) -join ",") -eq (@($actualSids) -join ",")
}

# --- Advanced Audit Policy (auditpol) ---------------------------------------

function Set-CisAuditPolicy {
    param(
        [Parameter(Mandatory)][string]$Subcategory,
        [bool]$Success = $true,
        [bool]$Failure = $true
    )
    $successFlag = if ($Success) { "enable" } else { "disable" }
    $failureFlag = if ($Failure) { "enable" } else { "disable" }
    auditpol /set /subcategory:"$Subcategory" /success:$successFlag /failure:$failureFlag | Out-Null
}

function Get-CisAuditPolicy {
    param([Parameter(Mandatory)][string]$Subcategory)
    $raw = auditpol /get /subcategory:"$Subcategory" /r 2>$null | ConvertFrom-Csv
    if (-not $raw) { return $null }
    return [pscustomobject]@{
        Success = $raw."Inclusion Setting" -match "Success"
        Failure = $raw."Inclusion Setting" -match "Failure"
    }
}

Export-ModuleMember -Function Write-CisResult, Test-CisRemediate, Test-CisLevelApplies, `
    Set-CisRegistryValue, Get-CisRegistryValue, Get-CisNonCompliantCount, `
    Get-CisSeceditValue, Set-CisSeceditValue, `
    Resolve-CisSid, Set-CisUserRight, Get-CisUserRightPrincipals, Test-CisUserRightMatches, `
    Set-CisAuditPolicy, Get-CisAuditPolicy
