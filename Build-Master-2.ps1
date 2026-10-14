#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputName = "PokeDebug_Installer_Release.cmd",
    [string]$ManifestName = "PokeDebug_Release_Public.json",
    [switch]$SkipMenuGeneration,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
$master = Join-Path $PSScriptRoot "Build-Master.ps1"
if (-not (Test-Path -LiteralPath $master -PathType Leaf)) {
    throw "Build-Master.ps1 was not found."
}

Write-Host "Building public PokeDebug release (no log submission, no animated sprites, no fallen compat)..." -ForegroundColor Cyan
& $master -OutputName $OutputName -ManifestName $ManifestName -SkipMenuGeneration:$SkipMenuGeneration -SkipTests:$SkipTests -WithoutLogSubmission -WithoutAnimatedSprites -WithoutFallenCompat
