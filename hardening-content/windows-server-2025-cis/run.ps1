# CIS Windows Server 2025 hardening runner. See ../CONTRACT.md for the calling contract.
#
# Usage: run.ps1 -Mode audit|remediate [-Level 1|2] [-Profile server|workstation] [-Section N]

param(
    [Parameter(Mandatory)][ValidateSet("audit","remediate")][string]$Mode,
    [ValidateSet(1,2)][int]$Level = 1,
    [ValidateSet("server","workstation")][string]$Profile = "server",
    [string]$Section = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$env:CIS_MODE  = $Mode
$env:CIS_LEVEL = "$Level"
$env:CIS_PROFILE = $Profile

Import-Module (Join-Path $ScriptDir "lib\Common.psm1") -Force

Write-Host "== CIS Windows Server 2025 hardening runner: mode=$Mode level=$Level profile=$Profile =="

$sectionDirs = Get-ChildItem -Path (Join-Path $ScriptDir "scripts") -Directory -Filter "section_*"
foreach ($dir in $sectionDirs) {
    $sectionNum = $dir.Name -replace "section_", ""
    if ($Section -and $sectionNum -ne $Section) { continue }

    $controlScripts = Get-ChildItem -Path $dir.FullName -Filter "cis_*.ps1"
    foreach ($cs in $controlScripts) {
        & $cs.FullName
    }
}

$nonCompliant = Get-CisNonCompliantCount
Write-Host "== Complete: $nonCompliant non-compliant/error control(s) =="
exit $nonCompliant
