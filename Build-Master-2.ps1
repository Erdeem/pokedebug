#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputName = "PokeDebug_Installer_2.cmd",
    [switch]$SkipGodModeGeneration
)

$ErrorActionPreference = "Stop"
$master = Join-Path $PSScriptRoot "Build-Master.ps1"
if (-not (Test-Path -LiteralPath $master -PathType Leaf)) {
    throw "Build-Master.ps1 was not found."
}

Write-Host "Building reduced PokeDebug CMD (no log submission, no animated sprites)..." -ForegroundColor Cyan
& $master -OutputName $OutputName -SkipGodModeGeneration:$SkipGodModeGeneration -WithoutLogSubmission -WithoutAnimatedSprites
