$ErrorActionPreference = "Stop"

function Test-PowershellParse([string]$Path) {
    [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $Path), [ref]$null, [ref]$null)
    Write-Host "[OK] Parsed $Path" -ForegroundColor Green
}

Write-Host "Validating PokeDebug_Improved..." -ForegroundColor Cyan

Write-Host "[*] Regenerating god_mode_source.rb..." -ForegroundColor Yellow
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Generate-GodModeSource.ps1"

Test-PowershellParse ".\Source Code\Install.ps1"
Test-PowershellParse ".\Source Code\Uninstall.ps1"
Test-PowershellParse ".\Build-Exe.ps1"

Write-Host "[*] Rebuilding monolithic installer..." -ForegroundColor Yellow
powershell -NoProfile -ExecutionPolicy Bypass -File ".\Build-Exe.ps1"

Test-PowershellParse ".\Install_Monolithic.ps1"

if (Get-Command ruby -ErrorAction SilentlyContinue) {
    ruby -c ".\Source Code\god_mode_source.rb"
    ruby -c ".\Source Code\preload_gm.rb"
} else {
    Write-Host "[WARN] Ruby not found. Skipping Ruby syntax validation." -ForegroundColor Yellow
}

Write-Host "Validation finished." -ForegroundColor Green
