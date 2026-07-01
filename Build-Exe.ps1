$ErrorActionPreference = "Stop"

Write-Host "Building PokeDebug_Installer.exe..." -ForegroundColor Cyan

function Assert-Contains([string]$Text, [string]$Pattern, [string]$Message) {
    if ($Text.IndexOf($Pattern, [System.StringComparison]::Ordinal) -lt 0) {
        throw $Message
    }
}

# Paths
$SourceDir = Join-Path $PSScriptRoot "Source Code"
$GodModeRb = Join-Path $SourceDir "god_mode_source.rb"
$PreloadRb = Join-Path $SourceDir "preload_gm.rb"
$InstallPs = Join-Path $SourceDir "Install.ps1"
$MonolithicPs = Join-Path $PSScriptRoot "Install_Monolithic.ps1"
$GeneratorPs = Join-Path $PSScriptRoot "Generate-GodModeSource.ps1"

if (Test-Path $GeneratorPs -PathType Leaf) {
    & $GeneratorPs
}

# 1. Read files
$godMode = Get-Content $GodModeRb -Raw
$preload = Get-Content $PreloadRb -Raw
$ps1 = Get-Content $InstallPs -Raw

# --- NO OBFUSCATION (Plaintext Injection) ---
$obfuscatedGodMode = $godMode
$godModeBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($obfuscatedGodMode))
$preloadBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($preload))
# -------------------------------------------

# 2. Build Monolithic PS1
Assert-Contains $ps1 "    `$godModeContent = [System.IO.File]::ReadAllText(`$SourceGodMode, [System.Text.Encoding]::UTF8)" "Could not find god_mode_source.rb load marker in Install.ps1."
$ps1 = $ps1.Replace(
    "    `$godModeContent = [System.IO.File]::ReadAllText(`$SourceGodMode, [System.Text.Encoding]::UTF8)",
    "    `$godModeBase64 = '$godModeBase64'`n    `$godModeContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(`$godModeBase64))"
)
$ps1 = $ps1 -replace '(?s)    \$SourceGodMode = Join-Path \$PSScriptRoot "god_mode_source\.rb".*?exit 1\r?\n    \}', ""
$godModeInsertMarker = $ps1.IndexOf("    `$godModeBase64 = '")
if ($godModeInsertMarker -lt 0) {
    throw "Could not find generated god mode base64 marker in Install.ps1."
}
$ps1 = $ps1.Insert($godModeInsertMarker, "    `$DestGodMode = Join-Path `$PluginDir `"god_mode.rb`"`n")

$patternPreload = '(?ms)\s+\$SourcePreload = Join-Path \$PSScriptRoot "preload_gm\.rb".*?\r?\n\s+\$JsonPath = Join-Path \$GameDir "mkxp\.json"'
$replacementPreload = "`n`n    `$DestPreload = Join-Path `$GameDir `"preload_gm.rb`"`n    `$preloadBase64 = '$preloadBase64'`n    `$preloadContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(`$preloadBase64))`n    `$utf8NoBom = New-Object System.Text.UTF8Encoding `$false`n    [System.IO.File]::WriteAllText(`$DestPreload, `$preloadContent, `$utf8NoBom)`n`n    `$JsonPath = Join-Path `$GameDir `"mkxp.json`"`n"
$ps1 = $ps1 -replace $patternPreload, $replacementPreload

Assert-Contains $ps1 '$DestPreload = Join-Path $GameDir "preload_gm.rb"' "Monolithic preload injection failed."

Set-Content $MonolithicPs -Value $ps1 -Encoding UTF8
Write-Host "[+] Install_Monolithic.ps1 generated." -ForegroundColor Green

# 3. Create C# Wrapper
$bytes = [System.Text.Encoding]::UTF8.GetBytes($ps1)
$base64 = [System.Convert]::ToBase64String($bytes)

# Keep -NoExit so the installer console remains visible after crashes in end-user machines.
$cs = "using System;`nusing System.Diagnostics;`nusing System.IO;`nclass Program {`nstatic void Main() {`nstring b64 = `"" + $base64 + "`";`nbyte[] bytes = Convert.FromBase64String(b64);`nstring tempPath = Path.Combine(Path.GetTempPath(), `"PokeDebug_`" + Guid.NewGuid().ToString() + `".ps1`");`nFile.WriteAllBytes(tempPath, bytes);`nProcess p = new Process();`np.StartInfo.FileName = `"powershell.exe`";`np.StartInfo.Arguments = `"-NoProfile -NoExit -ExecutionPolicy Bypass -File \`"`" + tempPath + `"\`"`";`np.StartInfo.UseShellExecute = false;`np.Start();`np.WaitForExit();`ntry { File.Delete(tempPath); } catch {}`n}`n}"
$wrapperCs = Join-Path $PSScriptRoot "wrapper.cs"
Set-Content $wrapperCs $cs -Encoding UTF8

# 4. Compile C#
$cscCandidates = @(
    "$env:windir\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:windir\Microsoft.NET\Framework\v4.0.30319\csc.exe"
)
$csc = $cscCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $csc) {
    throw "Could not find csc.exe in Framework64 or Framework."
}
$outExe = Join-Path $PSScriptRoot "PokeDebug_Installer.exe"
& $csc /target:winexe /out:"$outExe" "$wrapperCs"

if ($LASTEXITCODE -eq 0) {
    Remove-Item $wrapperCs -Force -ErrorAction SilentlyContinue
    Write-Host "[+] PokeDebug_Installer.exe compiled successfully!" -ForegroundColor Green
} else {
    Write-Host "[-] Compilation failed." -ForegroundColor Red
}
