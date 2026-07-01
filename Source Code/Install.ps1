<#
.SYNOPSIS
    PokeDebug Installer for Pokemon Essentials
#>
[CmdletBinding()]
param(
    [string]$GameDir = ".",
    [string]$Language = "",
    [switch]$DryRun,
    [switch]$Uninstall,
    [switch]$RestoreBackups
)

$ErrorActionPreference = "Stop"

function Print-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ____       _          ____       _                 " -ForegroundColor Cyan
    Write-Host " |  _ \ ___ | | _____  |  _ \  ___| |__  _   _  __ _ " -ForegroundColor Cyan
    Write-Host " | |_) / _ \| |/ / _ \ | | | |/ _ \ '_ \| | | |/ _` |" -ForegroundColor Cyan
    Write-Host " |  __/ (_) |   <  __/ | |_| |  __/ |_) | |_| | (_| |" -ForegroundColor Cyan
    Write-Host " |_|   \___/|_|\_\___| |____/ \___|_.__/ \__,_|\__, |" -ForegroundColor Cyan
    Write-Host "                                               |___/ " -ForegroundColor Cyan
    Write-Host "             ~ Developed by Kzuran ~                 " -ForegroundColor DarkCyan
    Write-Host ""
}

Print-Header

$lang = $Language.ToLower()
if ($lang -ne "en" -and $lang -ne "pt" -and $lang -ne "es") {
    Write-Host "Select Language / Selecione o Idioma / Seleccione el Idioma:"
    Write-Host "[1] English"
    Write-Host "[2] Portugues"
    Write-Host "[3] Espanol"
    $langInput = Read-Host "> "
    if ($langInput -eq "2") { 
        $lang = "pt" 
    } elseif ($langInput -eq "3") { 
        $lang = "es" 
    } else { 
        $lang = "en" 
    }
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Log([string]$msg, [ConsoleColor]$color = "White") {
    Write-Host $msg -ForegroundColor $color
}

function Get-Msg([string]$en, [string]$pt, [string]$es) {
    if ($lang -eq "pt") { return $pt } elseif ($lang -eq "es") { return $es } else { return $en }
}

function Show-Section([string]$Title) {
    Log ""
    Log ("=== {0} ===" -f $Title) "DarkCyan"
}

function Format-State([bool]$Value) {
    if ($Value) { return "ON" }
    return "OFF"
}

function Get-InjectionStrategy {
    param($Diagnostics)
    $strategy = [ordered]@{
        Name = "Unknown"
        Confidence = "Low"
        Summary = "Manual review recommended."
        Color = "Yellow"
    }

    if ($Diagnostics.HasMkxp -and $Diagnostics.HasScriptsRxdata) {
        $strategy.Name = "Hybrid MKXP + RGSS"
        $strategy.Confidence = "High"
        $strategy.Summary = "Preload bootstrap plus direct RGSS script patch."
        $strategy.Color = "Green"
    } elseif ($Diagnostics.HasMkxp -and ($Diagnostics.HasPluginsDir -or $Diagnostics.HasPreloadFile)) {
        $strategy.Name = "MKXP Plugin Layout"
        $strategy.Confidence = "High"
        $strategy.Summary = "Project already looks plugin-ready; preload bootstrap should fit cleanly."
        $strategy.Color = "Green"
    } elseif ($Diagnostics.HasMkxp) {
        $strategy.Name = "MKXP Preload"
        $strategy.Confidence = "High"
        $strategy.Summary = "Plugin will load through mkxp.json and preload_gm.rb."
        $strategy.Color = "Green"
    } elseif ($Diagnostics.HasScriptsRxdata -or $Diagnostics.HasRgssArchive) {
        $strategy.Name = "RGSS Patch"
        $strategy.Confidence = "Medium"
        $strategy.Summary = "Main script payload will be injected into the game data."
        $strategy.Color = "Cyan"
    } elseif ($Diagnostics.HasPluginScripts) {
        $strategy.Name = "PluginScripts-Like Layout"
        $strategy.Confidence = "Low"
        $strategy.Summary = "Project looks custom; fallback compatibility path may be needed."
        $strategy.Color = "Yellow"
    }

    return $strategy
}

function Get-PackedExeCandidate {
    param([string]$ResolvedGameDir)
    Get-ChildItem -Path $ResolvedGameDir -Filter "*.exe" -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending |
        Select-Object -First 1
}

function Get-GameIniPath {
    param([string]$ResolvedGameDir)
    $defaultIni = Join-Path $ResolvedGameDir "Game.ini"
    if (Test-Path $defaultIni -PathType Leaf) {
        return $defaultIni
    }

    $exe = Get-PackedExeCandidate $ResolvedGameDir
    if ($exe) {
        $candidate = Join-Path $ResolvedGameDir (($exe.BaseName) + ".ini")
        if (Test-Path $candidate -PathType Leaf) {
            return $candidate
        }
    }

    $fallback = Get-ChildItem -Path $ResolvedGameDir -Filter "*.ini" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($fallback) {
        return $fallback.FullName
    }

    return $defaultIni
}

function Test-EnigmaPackedGame {
    param([string]$ResolvedGameDir)
    $result = [ordered]@{
        Packed = $false
        Confidence = "Low"
        Evidence = @()
        ExePath = ""
    }

    $packedExe = Get-PackedExeCandidate $ResolvedGameDir
    if ($null -eq $packedExe) {
        return $result
    }

    $result.ExePath = $packedExe.FullName
    if ($packedExe.Length -gt 40MB) {
        $result.Evidence += "large_exe"
    }

    $bytes = New-Object byte[] 262144
    $fs = [System.IO.File]::OpenRead($packedExe.FullName)
    try {
        $bytesRead = $fs.Read($bytes, 0, $bytes.Length)
    } finally {
        $fs.Close()
    }

    $header = [System.Text.Encoding]::ASCII.GetString($bytes, 0, $bytesRead)
    if ($header -match "\.enigma") { $result.Evidence += "signature:.enigma" }
    if ($header -match "Enigma Virtual Box") { $result.Evidence += "signature:enigma_virtual_box" }
    if ($header -match "EVB") { $result.Evidence += "signature:evb" }

    $result.Packed = $result.Evidence.Count -gt 0 -and ($result.Evidence -contains "large_exe" -or $result.Evidence.Count -ge 2)
    if ($result.Packed) {
        if (($result.Evidence -contains "signature:.enigma") -or ($result.Evidence -contains "signature:enigma_virtual_box")) {
            $result.Confidence = "High"
        } else {
            $result.Confidence = "Medium"
        }
    }
    $result
}

function Read-MenuChoice {
    param(
        [string]$Prompt,
        [string[]]$AllowedValues,
        [string]$DefaultValue
    )
    $allowedLookup = @{}
    foreach ($item in $AllowedValues) {
        $allowedLookup[$item.ToLowerInvariant()] = $true
    }

    while ($true) {
        $value = (Read-Host $Prompt).Trim()
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $DefaultValue
        }
        if ($allowedLookup.ContainsKey($value.ToLowerInvariant())) {
            return $value
        }
        Log (Get-Msg "[!] Invalid option. Try again." "[!] Opcao invalida. Tente novamente." "[!] Opcion invalida. Intenta otra vez.") "Yellow"
    }
}

function Get-InstallDiagnostics {
    param([string]$ResolvedGameDir)

    $mkxpPath = Join-Path $ResolvedGameDir "mkxp.json"
    $dataDir = Join-Path $ResolvedGameDir "Data"
    $rxDataPath = Join-Path $ResolvedGameDir "Data\Scripts.rxdata"
    $pluginScripts = Join-Path $ResolvedGameDir "Data\PluginScripts.rxdata"
    $pluginsDir = Join-Path $ResolvedGameDir "Plugins"
    $preloadPath = Join-Path $ResolvedGameDir "preload_gm.rb"
    $iniPath = Get-GameIniPath $ResolvedGameDir
    $archive = Get-ChildItem -Path $ResolvedGameDir -Filter "*.rgss*a*" -ErrorAction SilentlyContinue | Select-Object -First 1
    $enigma = Test-EnigmaPackedGame $ResolvedGameDir

    $archiveName = ""
    $hasRgssArchive = $false
    if ($archive) {
        $archiveName = $archive.Name
        $hasRgssArchive = $true
    }

    $diagnostics = New-Object System.Collections.Hashtable
    $diagnostics["GameDir"] = $ResolvedGameDir
    $diagnostics["HasMkxp"] = (Test-Path $mkxpPath -PathType Leaf)
    $diagnostics["HasDataDir"] = (Test-Path $dataDir -PathType Container)
    $diagnostics["HasScriptsRxdata"] = (Test-Path $rxDataPath -PathType Leaf)
    $diagnostics["HasRgssArchive"] = $hasRgssArchive
    $diagnostics["ArchiveName"] = $archiveName
    $diagnostics["HasPluginScripts"] = (Test-Path $pluginScripts -PathType Leaf)
    $diagnostics["HasPluginsDir"] = (Test-Path $pluginsDir -PathType Container)
    $diagnostics["HasPreloadFile"] = (Test-Path $preloadPath -PathType Leaf)
    $diagnostics["IniPath"] = $iniPath
    $diagnostics["HasIni"] = (Test-Path $iniPath -PathType Leaf)
    $diagnostics["EnigmaPacked"] = $enigma.Packed
    $diagnostics["EnigmaConfidence"] = $enigma.Confidence
    $diagnostics["EnigmaEvidence"] = $enigma.Evidence
    $diagnostics["PackedExePath"] = $enigma.ExePath
    return $diagnostics
}

function Show-InstallDiagnostics {
    param($Diagnostics)

    $archiveLabel = "OFF"
    if ($Diagnostics["HasRgssArchive"]) {
        $archiveLabel = $Diagnostics["ArchiveName"]
    }

    $enigmaColor = "Gray"
    if ($Diagnostics["EnigmaPacked"]) {
        $enigmaColor = "Yellow"
    }

    $strategy = Get-InjectionStrategy $Diagnostics
    Show-Section (Get-Msg "Game Detection" "Deteccao do Jogo" "Deteccion del Juego")
    Log ("Path: {0}" -f $Diagnostics["GameDir"]) "Gray"
    Log ("MKXP-Z: {0}" -f (Format-State $Diagnostics["HasMkxp"])) "Gray"
    Log ("Data folder: {0}" -f (Format-State $Diagnostics["HasDataDir"])) "Gray"
    Log ("Scripts.rxdata: {0}" -f (Format-State $Diagnostics["HasScriptsRxdata"])) "Gray"
    Log ("RGSS archive: {0}" -f $archiveLabel) "Gray"
    Log ("PluginScripts.rxdata: {0}" -f (Format-State $Diagnostics["HasPluginScripts"])) "Gray"
    Log ("Plugins folder: {0}" -f (Format-State $Diagnostics["HasPluginsDir"])) "Gray"
    Log ("preload_gm.rb: {0}" -f (Format-State $Diagnostics["HasPreloadFile"])) "Gray"
    Log ("Game INI: {0}" -f (Format-State $Diagnostics["HasIni"])) "Gray"
    if ($Diagnostics["HasIni"]) {
        Log ("INI path: {0}" -f $Diagnostics["IniPath"]) "DarkGray"
    }
    Log ("Enigma packed guess: {0}" -f (Format-State $Diagnostics["EnigmaPacked"])) $enigmaColor
    if ($Diagnostics["EnigmaPacked"]) {
        Log ("Enigma confidence: {0}" -f $Diagnostics["EnigmaConfidence"]) "Yellow"
        if ($Diagnostics["EnigmaEvidence"] -and $Diagnostics["EnigmaEvidence"].Count -gt 0) {
            Log ("Enigma evidence: {0}" -f ($Diagnostics["EnigmaEvidence"] -join ", ")) "DarkGray"
        }
    }
    Log ("Injection method: {0}" -f $strategy.Name) $strategy.Color
    Log ("Detection confidence: {0}" -f $strategy.Confidence) $strategy.Color
    Log ("Method notes: {0}" -f $strategy.Summary) "DarkGray"
}

function Show-InstallProfileMenu {
    Show-Section (Get-Msg "Injection Profile" "Perfil de Injecao" "Perfil de Inyeccion")
    Log "[1] Safe: only inject menu files" "White"
    Log "    Minimal changes. Best when the target game is unstable or heavily modded." "DarkGray"
    Log "[2] Native Debug Assist: also try to enable the game's original debug" "White"
    Log "    Recommended default. Keeps compatibility high while unlocking more native tools." "DarkGray"
    Log "[3] Aggressive Compatibility: debug assist + try disabling compile routines" "White"
    Log "    Stronger boot patching for projects that block debug or force compilation." "DarkGray"
    return (Read-MenuChoice (Get-Msg "> Choose profile (Default: 2)" "> Escolha o perfil (Padrao: 2)" "> Elige el perfil (Por defecto: 2)") @("1","2","3") "2")
}

function Show-MainActionMenu {
    Show-Section (Get-Msg "Main Menu" "Menu Principal" "Menu Principal")
    Log "[1] Install" "White"
    Log "    Inject the current PokeDebug build into this game." "DarkGray"
    Log "[2] Dry Run" "White"
    Log "    Scan files and show what would happen without changing anything." "DarkGray"
    Log "[3] Uninstall" "White"
    Log "    Remove God Mode files and try to roll back changed game files." "DarkGray"
    Log "[4] Restore Backups" "White"
    Log "    Restore .pokedebug.bak backups only, keeping other files untouched." "DarkGray"
    Log "[5] Exit" "White"
    Log "    Close the installer without doing anything." "DarkGray"
    return (Read-MenuChoice (Get-Msg "> Choose action (Default: 1)" "> Escolha a acao (Padrao: 1)" "> Elige la accion (Por defecto: 1)") @("1","2","3","4","5") "1")
}

function Show-SettingsSummary {
    param(
        [string]$ResolvedGameDir,
        [string]$MenuKey,
        [string]$WtwKey,
        [string]$HealKey,
        [bool]$EnableNativeDebugBootstrap,
        [bool]$DisableCompilerBootstrap,
        [bool]$DryRunMode,
        $Diagnostics
    )
    $strategy = Get-InjectionStrategy $Diagnostics
    Show-Section (Get-Msg "Injection Summary" "Resumo da Injecao" "Resumen de Inyeccion")
    Log ("GameDir: {0}" -f $ResolvedGameDir) "Gray"
    Log ("Injection Method: {0}" -f $strategy.Name) $strategy.Color
    Log ("Confidence: {0}" -f $strategy.Confidence) $strategy.Color
    Log ("Menu Hotkey: {0}" -f $MenuKey) "Gray"
    Log ("Walk Through Walls Hotkey: {0}" -f $WtwKey) "Gray"
    Log ("Heal Hotkey: {0}" -f $HealKey) "Gray"
    Log ("Original Debug Boost: {0}" -f (Format-State $EnableNativeDebugBootstrap)) "Gray"
    Log ("Compile Bypass Attempt: {0}" -f (Format-State $DisableCompilerBootstrap)) "Gray"
    Log ("Dry Run: {0}" -f (Format-State $DryRunMode)) "Gray"
}

$InstallReport = [ordered]@{
    GameDir        = ""
    DryRun         = $DryRun.IsPresent
    Uninstall      = $Uninstall.IsPresent
    RestoreBackups = $RestoreBackups.IsPresent
    GodModeCopied  = $false
    PreloadCopied  = $false
    NativeDebugBootstrap = $false
    CompilerBypassBootstrap = $false
    MkxpInjected   = $false
    RgssInjected   = $false
    IniUpdated     = $false
    RollbackApplied = $false
    Warnings       = New-Object System.Collections.Generic.List[string]
}

function Add-Warning([string]$Message) {
    $InstallReport.Warnings.Add($Message) | Out-Null
    Log $Message "Yellow"
}

function Normalize-Hotkey([string]$Value, [string]$Default) {
    $allowed = @(
        "F1","F2","F3","F4","F5","F6","F7","F8","F9","F10","F11","F12",
        "SHIFT","CTRL","ALT",
        "A","B","C","D","E","F","G","H","I","J","K","L","M",
        "N","O","P","Q","R","S","T","U","V","W","X","Y","Z"
    )

    $normalized = if ([string]::IsNullOrWhiteSpace($Value)) { $Default } else { $Value.Trim().ToUpperInvariant() }
    if ($allowed -contains $normalized) {
        return $normalized
    }

    Add-Warning (Get-Msg "[!] Invalid hotkey '$Value'. Falling back to $Default." "[!] Tecla invalida '$Value'. Voltando para $Default." "[!] Tecla invalida '$Value'. Volviendo a $Default.")
    return $Default
}

function Read-YesNo([string]$Prompt, [bool]$DefaultValue = $false) {
    $suffix = if ($DefaultValue) { " [Y]" } else { " [N]" }
    $value = (Read-Host ($Prompt + $suffix)).Trim()
    if ([string]::IsNullOrWhiteSpace($value)) { return $DefaultValue }
    return $value -match "^(y|yes|s|sim)$"
}

function Backup-File([string]$Path) {
    if (-not (Test-Path $Path -PathType Leaf)) { return $null }
    $backupPath = "$Path.pokedebug.bak"
    Copy-Item -Path $Path -Destination $backupPath -Force
    return $backupPath
}

function Restore-BackupFile([string]$Path) {
    $backupPath = "$Path.pokedebug.bak"
    if (-not (Test-Path $backupPath -PathType Leaf)) { return $false }
    Copy-Item -Path $backupPath -Destination $Path -Force
    return $true
}

function Remove-MkxpPreload([string]$Path) {
    if (-not (Test-Path $Path -PathType Leaf)) { return $false }

    $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $updated = $content
    $updated = [regex]::Replace($updated, ',\s*"preload_gm\.rb"', '', 1)
    $updated = [regex]::Replace($updated, '"preload_gm\.rb"\s*,\s*', '', 1)
    $updated = [regex]::Replace($updated, '"preloadScript"\s*:\s*\[\s*"preload_gm\.rb"\s*\]\s*,?', '', 1)

    if ($updated -ne $content) {
        [System.IO.File]::WriteAllText($Path, $updated, (New-Object System.Text.UTF8Encoding $false))
        return $true
    }

    return $false
}

function Remove-IfExists([string]$Path) {
    if (Test-Path $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
        return $true
    }
    return $false
}

function Run-Uninstall([string]$ResolvedGameDir) {
    Log (Get-Msg "[*] Starting uninstall / rollback..." "[*] Iniciando desinstalacao / rollback..." "[*] Iniciando desinstalacion / rollback...") "Cyan"

    $pluginDir = Join-Path $ResolvedGameDir "Plugins\God Mode"
    $preloadPath = Join-Path $ResolvedGameDir "preload_gm.rb"
    $mkxpPath = Join-Path $ResolvedGameDir "mkxp.json"
    $rxDataPath = Join-Path $ResolvedGameDir "Data\Scripts.rxdata"
    $iniPath = Get-GameIniPath $ResolvedGameDir
    $archive = Get-ChildItem -Path $ResolvedGameDir -Filter "*.rgss*a*" -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $DryRun) {
        if (-not (Restore-BackupFile $mkxpPath)) {
            [void](Remove-MkxpPreload $mkxpPath)
        } else {
            $InstallReport.RollbackApplied = $true
        }

        if (Restore-BackupFile $rxDataPath) { $InstallReport.RollbackApplied = $true }
        if ($archive -and (Restore-BackupFile $archive.FullName)) { $InstallReport.RollbackApplied = $true }
        if (Restore-BackupFile $iniPath) { $InstallReport.RollbackApplied = $true }

        [void](Remove-IfExists $preloadPath)
        if (Test-Path $pluginDir) {
            [void](Remove-IfExists $pluginDir)
            $pluginsRoot = Split-Path $pluginDir -Parent
            if ((Test-Path $pluginsRoot) -and -not (Get-ChildItem -Path $pluginsRoot -Force | Select-Object -First 1)) {
                Remove-Item -LiteralPath $pluginsRoot -Force
            }
        }
    }

    Log (Get-Msg "[+] Uninstall finished." "[+] Desinstalacao concluida." "[+] Desinstalacion completada.") "Green"
}

function Run-RestoreBackups([string]$ResolvedGameDir) {
    Log (Get-Msg "[*] Restoring backup files only..." "[*] Restaurando apenas os arquivos de backup..." "[*] Restaurando solo los archivos de respaldo...") "Cyan"

    $mkxpPath = Join-Path $ResolvedGameDir "mkxp.json"
    $rxDataPath = Join-Path $ResolvedGameDir "Data\Scripts.rxdata"
    $iniPath = Get-GameIniPath $ResolvedGameDir
    $archive = Get-ChildItem -Path $ResolvedGameDir -Filter "*.rgss*a*" -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $DryRun) {
        if (Restore-BackupFile $mkxpPath) { $InstallReport.RollbackApplied = $true }
        if (Restore-BackupFile $rxDataPath) { $InstallReport.RollbackApplied = $true }
        if ($archive -and (Restore-BackupFile $archive.FullName)) { $InstallReport.RollbackApplied = $true }
        if (Restore-BackupFile $iniPath) { $InstallReport.RollbackApplied = $true }
    }

    if (-not $InstallReport.RollbackApplied) {
        Add-Warning (Get-Msg "[!] No backup files were found to restore." "[!] Nenhum arquivo de backup foi encontrado para restaurar." "[!] No se encontraron archivos de respaldo para restaurar.")
    } else {
        Log (Get-Msg "[+] Backup restore finished." "[+] Restauracao dos backups concluida." "[+] Restauracion de respaldos completada.") "Green"
    }
}

function Update-MkxpPreload([string]$Path) {
    $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    if ($content -match '"preloadScript"\s*:\s*\[(?s).*?"preload_gm\.rb".*?\]') {
        return @{ Changed = $false; Reason = "already_present" }
    }

    $updated = $content
    if ($content -match '"preloadScript"\s*:\s*\[(?s)(.*?)\]') {
        $updated = [regex]::Replace(
            $content,
            '"preloadScript"\s*:\s*\[(?s)(.*?)\]',
            {
                param($m)
                $inner = $m.Groups[1].Value.Trim()
                if ([string]::IsNullOrWhiteSpace($inner)) {
                    '"preloadScript": ["preload_gm.rb"]'
                } else {
                    '"preloadScript": [' + $inner + ', "preload_gm.rb"]'
                }
            },
            1
        )
    } elseif ($content -match '"preloadScript"\s*:\s*"(.*?)"') {
        $updated = [regex]::Replace($content, '"preloadScript"\s*:\s*"(.*?)"', '"preloadScript": ["$1", "preload_gm.rb"]', 1)
    } else {
        $match = [regex]::Match($content, '\}(?![\s\S]*\})')
        if (-not $match.Success) {
            return @{ Changed = $false; Reason = "closing_brace_missing" }
        }

        $before = $content.Substring(0, $match.Index)
        $beforeTrimmed = $before.TrimEnd()
        if ($beforeTrimmed.Length -gt 0 -and -not $beforeTrimmed.EndsWith("{") -and -not $beforeTrimmed.EndsWith(",")) {
            $before = $beforeTrimmed + "," + $before.Substring($beforeTrimmed.Length)
        }
        $updated = $before + [Environment]::NewLine + '  "preloadScript": ["preload_gm.rb"]' + $content.Substring($match.Index)
    }

    if ($updated -eq $content) {
        return @{ Changed = $false; Reason = "no_changes" }
    }

    [System.IO.File]::WriteAllText($Path, $updated, (New-Object System.Text.UTF8Encoding $false))
    return @{ Changed = $true; Reason = "updated" }
}

$csharpPatcher = @'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.IO.Compression;

public class RgssPatcher {
    public static void ApplyPatch(string gameDir) {
        string[] archives = Directory.GetFiles(gameDir, "*.rgss*a*");
        string archivePath = archives.Length > 0 ? archives[0] : null;
        string rawRxdata = Path.Combine(gameDir, "Data", "Scripts.rxdata");
        
        if (archivePath != null) {
            PatchArchive(archivePath);
        } else if (File.Exists(rawRxdata)) {
            PatchRawFile(rawRxdata);
        } else {
            throw new Exception("Game.rgssad / Scripts.rxdata not found!");
        }
    }

    private static void PatchRawFile(string path) {
        byte[] data = File.ReadAllBytes(path);
        byte[] newScripts = InjectPayload(data);
        File.Copy(path, path + ".bak", true);
        File.WriteAllBytes(path, newScripts);
    }

    private static void PatchArchive(string archivePath) {
        string bakPath = archivePath + ".bak";
        if (!File.Exists(bakPath)) File.Copy(archivePath, bakPath);
        
        byte[] originalScripts = null;
        using (FileStream fs = new FileStream(bakPath, FileMode.Open, FileAccess.Read))
        using (BinaryReader br = new BinaryReader(fs)) {
            byte[] magic = br.ReadBytes(8);
            uint key = 0xDEADCAFE;
            if (magic[0] == 'R' && magic[1] == 'G' && magic[2] == 'S' && magic[3] == 'S' && magic[4] == 'A' && magic[5] == 'D') {
                while (fs.Position < fs.Length) {
                    uint lenRaw = br.ReadUInt32();
                    uint len = lenRaw ^ key;
                    key = key * 7 + 3;
                    
                    byte[] nameBytes = new byte[len];
                    for(int i = 0; i < len; i++) {
                        nameBytes[i] = (byte)(br.ReadByte() ^ (key & 0xFF));
                        key = key * 7 + 3;
                    }
                    string fname = Encoding.UTF8.GetString(nameBytes).Replace("\\", "/").ToLower();
                    
                    uint sizeRaw = br.ReadUInt32();
                    uint size = sizeRaw ^ key;
                    key = key * 7 + 3;
                    
                    if (fname == "data/scripts.rxdata") {
                        originalScripts = br.ReadBytes((int)size);
                        for (int i = 0; i < size; i += 4) {
                            uint d = 0;
                            int rem = Math.Min(4, (int)size - i);
                            if (rem == 4) d = BitConverter.ToUInt32(originalScripts, i);
                            else {
                                for(int j=0; j<rem; j++) d |= ((uint)originalScripts[i+j] << (8*j));
                            }
                            d ^= key;
                            byte[] dec = BitConverter.GetBytes(d);
                            Array.Copy(dec, 0, originalScripts, i, rem);
                            key = key * 7 + 3;
                        }
                        break;
                    } else {
                        fs.Seek(size, SeekOrigin.Current);
                    }
                }
            } else {
                throw new Exception("Unsupported encryption version. Only RGSSAD v1 is supported.");
            }
        }
        
        if (originalScripts == null) throw new Exception("Scripts.rxdata missing from archive.");
        
        byte[] newScripts = InjectPayload(originalScripts);
        
        using (FileStream fs = new FileStream(bakPath, FileMode.Open, FileAccess.Read))
        using (BinaryReader br = new BinaryReader(fs))
        using (FileStream outFs = new FileStream(archivePath, FileMode.Create, FileAccess.Write))
        using (BinaryWriter bw = new BinaryWriter(outFs)) {
            byte[] magic = br.ReadBytes(8);
            bw.Write(magic);
            uint inKey = 0xDEADCAFE;
            uint outKey = 0xDEADCAFE;
            while(fs.Position < fs.Length) {
                uint lenRaw = br.ReadUInt32();
                uint len = lenRaw ^ inKey;
                inKey = inKey * 7 + 3;
                byte[] nameBytes = new byte[len];
                for(int i=0; i<len; i++){
                    nameBytes[i] = (byte)(br.ReadByte() ^ (inKey & 0xFF));
                    inKey = inKey * 7 + 3;
                }
                string fname = Encoding.UTF8.GetString(nameBytes).Replace("\\", "/").ToLower();
                uint sizeRaw = br.ReadUInt32();
                uint size = sizeRaw ^ inKey;
                inKey = inKey * 7 + 3;
                bw.Write(lenRaw);
                outKey = outKey * 7 + 3;
                byte[] encName = new byte[len];
                uint tempKey = outKey;
                for(int i=0; i<len; i++){
                    encName[i] = (byte)(nameBytes[i] ^ (tempKey & 0xFF));
                    tempKey = tempKey * 7 + 3;
                }
                bw.Write(encName);
                outKey = tempKey;
                
                if (fname == "data/scripts.rxdata") {
                    uint newSize = (uint)newScripts.Length;
                    uint encSize = newSize ^ outKey;
                    outKey = outKey * 7 + 3;
                    bw.Write(encSize);
                    
                    byte[] encData = new byte[newSize];
                    uint dataKey = outKey;
                    for(int i=0; i<newSize; i+=4) {
                        uint d = 0;
                        int rem = Math.Min(4, (int)newSize - i);
                        if (rem == 4) d = BitConverter.ToUInt32(newScripts, i);
                        else {
                            for(int j=0; j<rem; j++) d |= ((uint)newScripts[i+j] << (8*j));
                        }
                        d ^= dataKey;
                        byte[] encDec = BitConverter.GetBytes(d);
                        Array.Copy(encDec, 0, encData, i, rem);
                        dataKey = dataKey * 7 + 3;
                    }
                    bw.Write(encData);
                    fs.Seek(size, SeekOrigin.Current);
                } else {
                    bw.Write(sizeRaw);
                    outKey = outKey * 7 + 3;
                    byte[] rawData = br.ReadBytes((int)size);
                    bw.Write(rawData);
                }
            }
        }
    }

    private static byte[] InjectPayload(byte[] original) {
        byte[] search = Encoding.ASCII.GetBytes("Main");
        int zlibStart = -1;
        int scriptEnd = -1;
        
        int startOffset = Math.Max(0, original.Length - 150000); 
        for (int i = startOffset; i < original.Length - 10; i++) {
            bool match = true;
            for (int j = 0; j < search.Length; j++) {
                if (original[i+j] != search[j]) { match = false; break; }
            }
            if (match) {
                for (int k = i + search.Length; k < original.Length - 5; k++) {
                    if (original[k] == 0x22) { 
                        for (int l = 1; l <= 5; l++) {
                            if (original[k+l] == 0x78 && original[k+l+1] == 0x9C) {
                                zlibStart = k; break;
                            }
                        }
                        if (zlibStart != -1) break;
                    }
                }
                if (zlibStart != -1) break;
            }
        }
        
        if (zlibStart == -1) throw new Exception("Failed to locate Main script block.");

        int ptr = zlibStart + 1;
        int len = ReadInt(original, ref ptr);
        
        byte[] zlibData = new byte[len];
        Array.Copy(original, ptr, zlibData, 0, len);
        scriptEnd = ptr + len;

        string rubyCode = Decompress(zlibData);
        string inject = "begin\r\n  path = File.expand_path('Plugins/God Mode/god_mode.rb', Dir.pwd)\r\n  code = File.open(path, 'rb') { |f| f.read }\r\n  eval(code, binding, path) if code\r\nrescue Exception => e\r\n  File.open('developer_menu_errors.log', 'a') {|f| f.puts e.message; f.puts e.backtrace.join(\"\\n\") }\r\nend\r\n";
        
        if (!rubyCode.Contains("god_mode.rb")) {
            rubyCode = inject + rubyCode;
        }

        byte[] newZlib = Compress(rubyCode);

        byte[] newScripts;
        using (MemoryStream ms = new MemoryStream())
        using (BinaryWriter bw = new BinaryWriter(ms)) {
            bw.Write(original, 0, zlibStart);
            bw.Write((byte)'"');
            WriteInt(bw, newZlib.Length);
            bw.Write(newZlib);
            bw.Write(original, scriptEnd, original.Length - scriptEnd);
            newScripts = ms.ToArray();
        }
        
        return newScripts;
    }
    
    private static int ReadInt(byte[] data, ref int ptr) {
        int b = (sbyte)data[ptr++];
        if (b == 0) return 0;
        if (b > 0) {
            if (b > 4 && b < 128) return b - 5;
            int val = 0;
            for (int i = 0; i < b; i++) val |= (data[ptr++] << (8 * i));
            return val;
        } else {
            if (b < -4 && b > -129) return b + 5;
            int val = -1;
            for (int i = 0; i < -b; i++) val &= ~(255 << (8 * i));
            for (int i = 0; i < -b; i++) val |= (data[ptr++] << (8 * i));
            return val;
        }
    }

    private static void WriteInt(BinaryWriter bw, int val) {
        if (val == 0) bw.Write((byte)0);
        else if (val > 0 && val < 123) bw.Write((byte)(val + 5));
        else {
            byte[] bytes = BitConverter.GetBytes(val);
            int len = 4;
            while(len > 0 && bytes[len-1] == 0) len--;
            bw.Write((byte)len);
            for(int i=0; i<len; i++) bw.Write(bytes[i]);
        }
    }

    private static string Decompress(byte[] data) {
        using (MemoryStream ms = new MemoryStream(data, 2, data.Length - 2))
        using (DeflateStream ds = new DeflateStream(ms, CompressionMode.Decompress))
        using (StreamReader sr = new StreamReader(ds, Encoding.UTF8)) {
            return sr.ReadToEnd();
        }
    }

    private static byte[] Compress(string text) {
        byte[] data = Encoding.UTF8.GetBytes(text);
        byte[] compressed;
        using (MemoryStream ms = new MemoryStream()) {
            using (DeflateStream ds = new DeflateStream(ms, CompressionMode.Compress, true)) {
                ds.Write(data, 0, data.Length);
            }
            compressed = ms.ToArray();
        }
        
        uint a = 1, b = 0;
        foreach (byte c in data) {
            a = (a + c) % 65521;
            b = (b + a) % 65521;
        }
        uint adler = (b << 16) | a;

        byte[] zlib = new byte[compressed.Length + 6];
        zlib[0] = 0x78;
        zlib[1] = 0x9C; 
        Array.Copy(compressed, 0, zlib, 2, compressed.Length);
        
        zlib[zlib.Length - 4] = (byte)((adler >> 24) & 0xFF);
        zlib[zlib.Length - 3] = (byte)((adler >> 16) & 0xFF);
        zlib[zlib.Length - 2] = (byte)((adler >> 8) & 0xFF);
        zlib[zlib.Length - 1] = (byte)(adler & 0xFF);
        
        return zlib;
    }
}
'@

Add-Type -TypeDefinition $csharpPatcher -Language CSharp

try {
    $explicitModeSelected = $Uninstall.IsPresent -or $DryRun.IsPresent -or $RestoreBackups.IsPresent
    if (-not $explicitModeSelected) {
        $mainAction = Show-MainActionMenu
        switch ($mainAction) {
            "2" { $DryRun = $true }
            "3" { $Uninstall = $true }
            "4" { $RestoreBackups = $true }
            "5" {
                Log (Get-Msg "Installer closed." "Instalador fechado." "Instalador cerrado.") "Yellow"
                exit 0
            }
        }
    }

    $GameDir = (Resolve-Path $GameDir -ErrorAction SilentlyContinue).Path
    if ([string]::IsNullOrEmpty($GameDir)) { $GameDir = (Get-Location).Path }
    $InstallReport.GameDir = $GameDir
    $InstallReport.DryRun = $DryRun.IsPresent
    $InstallReport.Uninstall = $Uninstall.IsPresent
    $InstallReport.RestoreBackups = $RestoreBackups.IsPresent
    $Diagnostics = Get-InstallDiagnostics $GameDir
    Show-InstallDiagnostics $Diagnostics

    if ($Uninstall) {
        Run-Uninstall $GameDir
        Log "" "White"
        Log "--- Install Report ---" "DarkGray"
        Log ("GameDir: {0}" -f $InstallReport.GameDir) "Gray"
        Log ("DryRun: {0}" -f $InstallReport.DryRun) "Gray"
        Log ("Uninstall: {0}" -f $InstallReport.Uninstall) "Gray"
        Log ("RollbackApplied: {0}" -f $InstallReport.RollbackApplied) "Gray"
        Log (Get-Msg "Press ENTER to exit..." "Pressione ENTER para fechar..." "Presione ENTER para salir...") "Gray"
        Read-Host
        exit 0
    }

    if ($RestoreBackups) {
        Run-RestoreBackups $GameDir
        Log "" "White"
        Log "--- Install Report ---" "DarkGray"
        Log ("GameDir: {0}" -f $InstallReport.GameDir) "Gray"
        Log ("DryRun: {0}" -f $InstallReport.DryRun) "Gray"
        Log ("Uninstall: {0}" -f $InstallReport.Uninstall) "Gray"
        Log ("RestoreBackups: {0}" -f $InstallReport.RestoreBackups) "Gray"
        Log ("RollbackApplied: {0}" -f $InstallReport.RollbackApplied) "Gray"
        if ($InstallReport.Warnings.Count -gt 0) {
            Log ("Warnings: {0}" -f $InstallReport.Warnings.Count) "Yellow"
        }
        Log (Get-Msg "Press ENTER to exit..." "Pressione ENTER para fechar..." "Presione ENTER para salir...") "Gray"
        Read-Host
        exit 0
    }

    $DataDir = Join-Path $GameDir "Data"
    $rgssFiles = Get-ChildItem -Path $GameDir -Filter "*.rgss*a*" -ErrorAction SilentlyContinue
    if (-not (Test-Path $DataDir -PathType Container) -and $rgssFiles.Count -eq 0) {
        $enigmaInfo = Test-EnigmaPackedGame $GameDir
        $packedExe = $null
        if (-not [string]::IsNullOrWhiteSpace($enigmaInfo.ExePath)) {
            $packedExe = Get-Item -LiteralPath $enigmaInfo.ExePath -ErrorAction SilentlyContinue
        }

        if ($enigmaInfo.Packed -and $null -ne $packedExe) {
            Log (Get-Msg "`n[!] Enigma Virtual Box packed game detected!" "`n[!] Jogo empacotado com Enigma Virtual Box detectado!" "`n[!] Juego empaquetado con Enigma Virtual Box detectado!") "Yellow"
            Log ((Get-Msg "[*] Detection confidence: {0}" "[*] Confianca da deteccao: {0}" "[*] Confianza de deteccion: {0}") -f $enigmaInfo.Confidence) "Yellow"
            if ($enigmaInfo.Evidence.Count -gt 0) {
                Log ((Get-Msg "[*] Evidence: {0}" "[*] Evidencias: {0}" "[*] Evidencias: {0}") -f ($enigmaInfo.Evidence -join ", ")) "DarkGray"
            }
            Log (Get-Msg "Would you like to automatically unpack it to inject the mod? (Y/N)" "Deseja descompactar automaticamente para injetar o mod? (S/N)" "Deseas descomprimir automaticamente para inyectar el mod? (S/N)") "Yellow"
            $ans = Read-Host "> "
            if ($ans -match "^[yYsS]") {
                $evbExe = Join-Path $env:TEMP "evbunpack.exe"
                if (-not (Test-Path $evbExe)) {
                    Log (Get-Msg "Downloading evbunpack..." "Baixando evbunpack..." "Descargando evbunpack...") "Cyan"
                    Invoke-WebRequest -Uri "https://github.com/mos9527/evbunpack/releases/download/0.2.6/evbunpack.exe" -OutFile $evbExe
                }
                $unpackedDir = Join-Path $GameDir "Unpacked_Game"
                if (-not (Test-Path $unpackedDir)) { New-Item -ItemType Directory -Path $unpackedDir | Out-Null }
                Log (Get-Msg "Unpacking... (This may take a minute)" "Descompactando... (Isso pode demorar um minuto)" "Descomprimiendo... (Esto puede tomar un minuto)") "Cyan"
                
                Start-Process -FilePath $evbExe -ArgumentList "`"$($packedExe.FullName)`" `"$unpackedDir`"" -Wait -NoNewWindow
                
                Get-ChildItem -Path $GameDir -Directory | Where-Object { $_.Name -ne "Unpacked_Game" } | ForEach-Object {
                    Copy-Item -Path $_.FullName -Destination (Join-Path $unpackedDir $_.Name) -Recurse -Force
                }
                
                Log (Get-Msg "Extraction successful! Restarting installer in the unpacked folder..." "Extracao concluida! Reiniciando instalador na pasta descompactada..." "Extraccion completada! Reiniciando instalador en la carpeta...") "Green"
                Set-Location $unpackedDir
                $GameDir = $unpackedDir
            } else {
                Log (Get-Msg "Extraction aborted." "Extracao cancelada." "Extraccion abortada.") "Red"
                exit 1
            }
        } else {
            Log (Get-Msg "Game files not found! Please place the installer in the game root folder." "Arquivos do jogo nao encontrados! Coloque este instalador na pasta raiz do jogo." "Archivos del juego no encontrados! Pon el instalador en la raiz del juego.") "Red"
            exit 1
        }
    }

    Show-Section (Get-Msg "Settings" "Configuracoes" "Ajustes")
    $profileChoice = Show-InstallProfileMenu
    switch ($profileChoice) {
        "1" {
            $EnableNativeDebugBootstrap = $false
            $DisableCompilerBootstrap = $false
        }
        "3" {
            $EnableNativeDebugBootstrap = $true
            $DisableCompilerBootstrap = $true
        }
        default {
            $EnableNativeDebugBootstrap = $true
            $DisableCompilerBootstrap = $false
        }
    }

    Show-Section (Get-Msg "Hotkeys" "Teclas" "Teclas")
    $MenuKey = Normalize-Hotkey (Read-Host (Get-Msg "> Menu Hotkey (Default: F6)" "> Tecla do Menu (Padrao: F6)" "> Tecla del Menu (Por defecto: F6)")) "F6"
    $WtwKey = Normalize-Hotkey (Read-Host (Get-Msg "> Walk Through Walls Hotkey (Default: F5)" "> Tecla para atravessar paredes (Padrao: F5)" "> Tecla para atravesar paredes (Por defecto: F5)")) "F5"
    $HealKey = Normalize-Hotkey (Read-Host (Get-Msg "> Heal Party Hotkey (Default: F9)" "> Tecla de curar (Padrao: F9)" "> Tecla para curar (Por defecto: F9)")) "F9"

    Show-Section (Get-Msg "Advanced Boot Options" "Opcoes Avancadas de Boot" "Opciones Avanzadas de Inicio")
    Log ("Current defaults from profile: Debug={0} | CompileBypass={1}" -f (Format-State $EnableNativeDebugBootstrap), (Format-State $DisableCompilerBootstrap)) "Gray"
    $EnableNativeDebugBootstrap = Read-YesNo (Get-Msg "> Try to force the original/native debug mode on boot?" "> Tentar forcar o debug original/nativo ao iniciar?" "> Intentar forzar el debug original/nativo al iniciar?") $EnableNativeDebugBootstrap
    $DisableCompilerBootstrap = Read-YesNo (Get-Msg "> Try to disable compile routines on boot?" "> Tentar desativar as rotinas de compilacao ao iniciar?" "> Intentar desactivar las rutinas de compilacion al iniciar?") $DisableCompilerBootstrap

    Show-SettingsSummary $GameDir $MenuKey $WtwKey $HealKey $EnableNativeDebugBootstrap $DisableCompilerBootstrap $DryRun.IsPresent $Diagnostics
    if (-not (Read-YesNo (Get-Msg "> Proceed with injection now?" "> Prosseguir com a injecao agora?" "> Proceder con la inyeccion ahora?") $true)) {
        Log (Get-Msg "Installation cancelled by user." "Instalacao cancelada pelo usuario." "Instalacion cancelada por el usuario.") "Yellow"
        exit 0
    }

    if ($DryRun) {
        Log (Get-Msg "[*] Dry-run mode enabled. Files will be validated but not changed." "[*] Modo dry-run ativado. Os arquivos serao validados, mas nao alterados." "[*] Modo dry-run activado. Los archivos seran validados, pero no alterados.") "Yellow"
    }
    
    Show-Section (Get-Msg "Injection" "Injecao" "Inyeccion")
    Log "[*] Copying scripts..." "Cyan"
    
    $PluginDir = Join-Path $GameDir "Plugins\God Mode"
    if (-not (Test-Path $PluginDir)) { New-Item -ItemType Directory -Path $PluginDir -Force | Out-Null }

    $SourceGodMode = Join-Path $PSScriptRoot "god_mode_source.rb"
    $DestGodMode   = Join-Path $PluginDir "god_mode.rb"

    if (-not (Test-Path $SourceGodMode -PathType Leaf)) {
        Log (Get-Msg "Could not find god_mode_source.rb!" "Arquivo god_mode_source.rb nao encontrado!" "No se encontro god_mode_source.rb!") "Red"
        exit 1
    }

    $godModeContent = [System.IO.File]::ReadAllText($SourceGodMode, [System.Text.Encoding]::UTF8)
    $godModeContent = [regex]::Replace($godModeContent, "LANG = '.*?'", "LANG = '$($lang.ToLower())'", 1)
    $godModeContent = [regex]::Replace($godModeContent, "MENU_HOTKEY = '.*?'", "MENU_HOTKEY = '$($MenuKey.Trim().ToUpper())'", 1)
    $godModeContent = [regex]::Replace($godModeContent, "WTW_HOTKEY = '.*?'", "WTW_HOTKEY = '$($WtwKey.Trim().ToUpper())'", 1)
    $godModeContent = [regex]::Replace($godModeContent, "HEAL_HOTKEY = '.*?'", "HEAL_HOTKEY = '$($HealKey.Trim().ToUpper())'", 1)
    
    if (-not $DryRun) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($DestGodMode, $godModeContent, $utf8NoBom)
    }
    $InstallReport.GodModeCopied = $true

    $SourcePreload = Join-Path $PSScriptRoot "preload_gm.rb"
    $DestPreload   = Join-Path $GameDir "preload_gm.rb"
    if (Test-Path $SourcePreload -PathType Leaf) {
        if (-not $DryRun) {
            $preloadContent = [System.IO.File]::ReadAllText($SourcePreload, [System.Text.Encoding]::UTF8)
            $preloadContent = [regex]::Replace($preloadContent, "GM_TRY_ENABLE_NATIVE_DEBUG = (true|false)", ("GM_TRY_ENABLE_NATIVE_DEBUG = " + $EnableNativeDebugBootstrap.ToString().ToLowerInvariant()), 1)
            $preloadContent = [regex]::Replace($preloadContent, "GM_TRY_DISABLE_COMPILER = (true|false)", ("GM_TRY_DISABLE_COMPILER = " + $DisableCompilerBootstrap.ToString().ToLowerInvariant()), 1)
            $utf8NoBom = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($DestPreload, $preloadContent, $utf8NoBom)
        }
        $InstallReport.PreloadCopied = $true
        $InstallReport.NativeDebugBootstrap = $EnableNativeDebugBootstrap
        $InstallReport.CompilerBypassBootstrap = $DisableCompilerBootstrap
    }

    $JsonPath = Join-Path $GameDir "mkxp.json"
    if (Test-Path $JsonPath -PathType Leaf) {
        Log "[*] Found mkxp.json. Injecting plugin via MKXP-Z loader..." "Cyan"
        if ($DryRun) {
            Log "[*] mkxp.json detected and validated for preload injection." "Green"
        } else {
            [void](Backup-File $JsonPath)
            $mkxpResult = Update-MkxpPreload $JsonPath
            if ($mkxpResult.Changed) {
                $InstallReport.MkxpInjected = $true
                Log "[+] MKXP injection successful!" "Green"
            } elseif ($mkxpResult.Reason -eq "already_present") {
                Log "[-] Plugin already loaded in mkxp.json." "Yellow"
            } else {
                Add-Warning "[!] mkxp.json was found, but preload injection could not be confirmed automatically."
            }
        }
    }

    $rgssFiles = Get-ChildItem -Path $GameDir -Filter "*.rgss*a*" -ErrorAction SilentlyContinue
    $rxData = Join-Path $GameDir "Data\Scripts.rxdata"
    
    if ($rgssFiles.Count -gt 0 -or (Test-Path $rxData)) {
        Log "[*] Found RGSS Game Data. Attempting RGSS injection..." "Magenta"
        if ($DryRun) {
            Log "[*] RGSS data detected and ready for patching." "Green"
        } else {
            try {
                [RgssPatcher]::ApplyPatch($GameDir)
                $InstallReport.RgssInjected = $true
                
                $iniPath = Get-GameIniPath $GameDir
                if (Test-Path $iniPath) {
                    (Get-Content $iniPath) -replace "^Scripts=.*", "Scripts=Data\Scripts.rxdata" | Set-Content $iniPath -Encoding ASCII
                    $InstallReport.IniUpdated = $true
                }
                
                Log "[+] RGSS injection successful!" "Green"
            } catch {
                Add-Warning "[-] RGSS injection failed (or not needed). Error: $_"
            }
        }
    }

    Log "" "White"
    Log "--- Install Report ---" "DarkGray"
    Log ("GameDir: {0}" -f $InstallReport.GameDir) "Gray"
    Log ("DryRun: {0}" -f $InstallReport.DryRun) "Gray"
    Log ("Uninstall: {0}" -f $InstallReport.Uninstall) "Gray"
    Log ("RestoreBackups: {0}" -f $InstallReport.RestoreBackups) "Gray"
    Log ("GodModeCopied: {0}" -f $InstallReport.GodModeCopied) "Gray"
    Log ("PreloadCopied: {0}" -f $InstallReport.PreloadCopied) "Gray"
    Log ("NativeDebugBootstrap: {0}" -f $InstallReport.NativeDebugBootstrap) "Gray"
    Log ("CompilerBypassBootstrap: {0}" -f $InstallReport.CompilerBypassBootstrap) "Gray"
    Log ("MkxpInjected: {0}" -f $InstallReport.MkxpInjected) "Gray"
    Log ("RgssInjected: {0}" -f $InstallReport.RgssInjected) "Gray"
    Log ("IniUpdated: {0}" -f $InstallReport.IniUpdated) "Gray"
    if ($InstallReport.Warnings.Count -gt 0) {
        Log ("Warnings: {0}" -f $InstallReport.Warnings.Count) "Yellow"
    }

    Log "`n===============================================" "DarkCyan"
    Log (Get-Msg "   ALL DONE! You can now start the game!" "   TUDO PRONTO! Agora e so abrir o jogo!" "   LISTO! Ahora puedes abrir el juego!") "Green"
    Log "===============================================`n" "DarkCyan"
    
    Log (Get-Msg "Press ENTER to exit..." "Pressione ENTER para fechar..." "Presione ENTER para salir...") "Gray"
    Read-Host
    exit 0

} catch {
    Log "`n[ERROR] $_" "Red"
    Log $($_.InvocationInfo.PositionMessage) "DarkGray"
    
    Log "`n"
    Log (Get-Msg "Press ENTER to exit..." "Pressione ENTER para fechar..." "Presione ENTER para salir...") "Gray"
    Read-Host
    exit 1
}
