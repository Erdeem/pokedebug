[CmdletBinding()]
param(
    [string]$GameDir = ".",
    [string]$Language = "",
    [switch]$DryRun
)

$installScript = Join-Path $PSScriptRoot "Install.ps1"
if (-not (Test-Path $installScript -PathType Leaf)) {
    throw "Install.ps1 not found next to Uninstall.ps1."
}

& $installScript -GameDir $GameDir -Language $Language -DryRun:$DryRun -Uninstall
