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

function Get-InjectionStrategy([System.Collections.IDictionary]$Diagnostics) {
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

function Get-PackedExeCandidate([string]$ResolvedGameDir) {
    Get-ChildItem -Path $ResolvedGameDir -Filter "*.exe" -ErrorAction SilentlyContinue |
        Sort-Object Length -Descending |
        Select-Object -First 1
}

function Test-EnigmaPackedGame([string]$ResolvedGameDir) {
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

function Read-MenuChoice([string]$Prompt, [string[]]$AllowedValues, [string]$DefaultValue) {
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

function Get-InstallDiagnostics([string]$ResolvedGameDir) {
    $mkxpPath = Join-Path $ResolvedGameDir "mkxp.json"
    $dataDir = Join-Path $ResolvedGameDir "Data"
    $rxDataPath = Join-Path $ResolvedGameDir "Data\Scripts.rxdata"
    $archive = Get-ChildItem -Path $ResolvedGameDir -Filter "*.rgss*a*" -ErrorAction SilentlyContinue | Select-Object -First 1
    $pluginScripts = Join-Path $ResolvedGameDir "Data\PluginScripts.rxdata"
    $enigma = Test-EnigmaPackedGame $ResolvedGameDir
    $archiveName = ""
    if ($archive) {
        $archiveName = $archive.Name
    }
    [ordered]@{
        GameDir = $ResolvedGameDir
        HasMkxp = Test-Path $mkxpPath -PathType Leaf
        HasDataDir = Test-Path $dataDir -PathType Container
        HasScriptsRxdata = Test-Path $rxDataPath -PathType Leaf
        HasRgssArchive = $null -ne $archive
        ArchiveName = $archiveName
        HasPluginScripts = Test-Path $pluginScripts -PathType Leaf
        EnigmaPacked = $enigma.Packed
        EnigmaConfidence = $enigma.Confidence
        EnigmaEvidence = $enigma.Evidence
        PackedExePath = $enigma.ExePath
    }
}

function Show-InstallDiagnostics([System.Collections.IDictionary]$Diagnostics) {
    $archiveLabel = "OFF"
    $enigmaColor = "Gray"
    if ($Diagnostics.HasRgssArchive) {
        $archiveLabel = $Diagnostics.ArchiveName
    }
    if ($Diagnostics.EnigmaPacked) {
        $enigmaColor = "Yellow"
    }
    $strategy = Get-InjectionStrategy $Diagnostics
    Show-Section (Get-Msg "Game Detection" "Deteccao do Jogo" "Deteccion del Juego")
    Log ("Path: {0}" -f $Diagnostics.GameDir) "Gray"
    Log ("MKXP-Z: {0}" -f (Format-State $Diagnostics.HasMkxp)) "Gray"
    Log ("Data folder: {0}" -f (Format-State $Diagnostics.HasDataDir)) "Gray"
    Log ("Scripts.rxdata: {0}" -f (Format-State $Diagnostics.HasScriptsRxdata)) "Gray"
    Log ("RGSS archive: {0}" -f $archiveLabel) "Gray"
    Log ("PluginScripts.rxdata: {0}" -f (Format-State $Diagnostics.HasPluginScripts)) "Gray"
    Log ("Enigma packed guess: {0}" -f (Format-State $Diagnostics.EnigmaPacked)) $enigmaColor
    if ($Diagnostics.EnigmaPacked) {
      Log ("Enigma confidence: {0}" -f $Diagnostics.EnigmaConfidence) "Yellow"
      if ($Diagnostics.EnigmaEvidence -and $Diagnostics.EnigmaEvidence.Count -gt 0) {
        Log ("Enigma evidence: {0}" -f ($Diagnostics.EnigmaEvidence -join ", ")) "DarkGray"
      end
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

function Show-SettingsSummary([string]$ResolvedGameDir, [string]$MenuKey, [string]$WtwKey, [string]$HealKey, [bool]$EnableNativeDebugBootstrap, [bool]$DisableCompilerBootstrap, [bool]$DryRunMode, [System.Collections.IDictionary]$Diagnostics) {
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
    $iniPath = Join-Path $ResolvedGameDir "Game.ini"
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
    $iniPath = Join-Path $ResolvedGameDir "Game.ini"
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
        string inject = "begin\r\n  path = File.expand_path('Plugins/God Mode/god_mode.rb', Dir.pwd)\r\n  eval(File.binread(path), binding, path)\r\nrescue Exception => e\r\n  File.open('developer_menu_errors.log', 'a') {|f| f.puts e.message; f.puts e.backtrace.join(\"\\n\") }\r\nend\r\n";
        
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
            Log ((Get-Msg "[*] Detection confidence: {1}" "[*] Confianca da deteccao: {1}" "[*] Confianza de deteccion: {1}") -f $enigmaInfo.Confidence) "Yellow"
            if ($enigmaInfo.Evidence.Count -gt 0) {
                Log ((Get-Msg "[*] Evidence: {1}" "[*] Evidencias: {1}" "[*] Evidencias: {1}") -f ($enigmaInfo.Evidence -join ", ")) "DarkGray"
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



    $DestGodMode = Join-Path $PluginDir "god_mode.rb"
    $godModeContent = @'
# This file is generated by Generate-GodModeSource.ps1.
# Edit the files in Source Code\\ruby_modules instead of editing this file directly.

# --- BEGIN 00_header.rb ---
#===============================================================================
# PERSISTENT DEVELOPER MENU - Pokemon Essentials (v15-v21+)
# Universal Enterprise Architecture
#===============================================================================
module DeveloperMenu
  LANG = 'en'
  LANG_KEYS = {
    "en" => "English",
    "pt" => "Portugues",
    "es" => "Espanol"
  }
  MENU_HOTKEY = 'F6'
  WTW_HOTKEY = 'F5'
  HEAL_HOTKEY = 'F9'
  TR = {
    :dev_menu => {"English" => "DEVELOPER MENU", "Portugues" => "MENU DO DESENVOLVEDOR", "Espanol" => "MENU DE DESARROLLADOR"},
    :engine => {"English" => "Engine", "Portugues" => "Motor do Jogo", "Espanol" => "Motor"},
    :pokemon => {"English" => "Pokemon", "Portugues" => "Pokemon", "Espanol" => "Pokemon"},
    :items => {"English" => "Items", "Portugues" => "Itens", "Espanol" => "Objetos"},
    :Player => {"English" => "Player", "Portugues" => "Jogador", "Espanol" => "Jugador"},
    :party => {"English" => "Party", "Portugues" => "Equipe", "Espanol" => "Equipo"},
    :extras => {"English" => "Extras", "Portugues" => "Extras", "Espanol" => "Extras"},
    :back => {"English" => "Back/Cancel", "Portugues" => "Voltar/Cancelar", "Espanol" => "Volver/Cancelar"},
    
    :warp => {"English" => "Warp to Map", "Portugues" => "Teleporte de Mapa", "Espanol" => "Teletransporte"},
    :switches => {"English" => "Switches", "Portugues" => "Interruptores", "Espanol" => "Interruptores"},
    :vars => {"English" => "Variables", "Portugues" => "Variaveis", "Espanol" => "Variables"},
    :safari => {"English" => "Safari / Contest", "Portugues" => "Safari / Torneio", "Espanol" => "Safari / Torneo"},
    :Field => {"English" => "Field Effects", "Portugues" => "Efeitos de Campo", "Espanol" => "Efectos de Campo"},
    :refresh => {"English" => "Refresh Map", "Portugues" => "Atualizar Mapa", "Espanol" => "Actualizar Mapa"},
    :daycare => {"English" => "Day Care", "Portugues" => "Creche (Day Care)", "Espanol" => "Guarderia"},
    :Wallpapers => {"English" => "Toggle PC Wallpapers", "Portugues" => "Desbloquear Wallpapers do PC", "Espanol" => "Desbloquear Fondos de PC"},
    :Battle => {"English" => "Test Wild Battle", "Portugues" => "Testar Batalha", "Espanol" => "Probar Batalla"},
    :expall => {"English" => "Toggle Exp. All", "Portugues" => "Alternar Exp. All", "Espanol" => "Alternar Exp. All"},
    :wtw => {"English" => "Toggle Walk Through Walls", "Portugues" => "Atravessar Paredes", "Espanol" => "Atravesar Paredes"},
    :openpc => {"English" => "Open PC", "Portugues" => "Abrir PC", "Espanol" => "Abrir PC"},
    
    :FillPC => {"English" => "Fill PC Boxes", "Portugues" => "Encher Caixas do PC", "Espanol" => "Llenar Cajas del PC"},
    :ClearPC => {"English" => "Clear PC Boxes", "Portugues" => "Limpar Caixas do PC", "Espanol" => "Vaciar Cajas del PC"},
    :addboxes => {"English" => "Add PC Boxes", "Portugues" => "Adicionar Caixas", "Espanol" => "Anadir Cajas al PC"},
    :quickhatch => {"English" => "Quick Hatch Party Eggs", "Portugues" => "Chocar Ovos Rapido", "Espanol" => "Eclosionar Huevos"},
    :addpkmn => {"English" => "Add Pokemon", "Portugues" => "Adicionar Pokemon", "Espanol" => "Anadir Pokemon"},
    :Heal => {"English" => "Heal Party", "Portugues" => "Curar Equipe", "Espanol" => "Curar Equipo"},
    :exportids => {"English" => "Export Species IDs", "Portugues" => "Exportar IDs", "Espanol" => "Exportar IDs"},
    
    :additem => {"English" => "Add Item", "Portugues" => "Adicionar Item", "Espanol" => "Anadir Objeto"},
    :fillbag => {"English" => "Fill Bag (All)", "Portugues" => "Encher Mochila (Tudo)", "Espanol" => "Llenar Mochila (Todo)"},
    :fillbagnon => {"English" => "Fill Bag (Non-Key)", "Portugues" => "Encher Mochila (Sem Itens Chave)", "Espanol" => "Llenar Mochila (Sin Objetos Clave)"},
    :fillbagkey => {"English" => "Fill Bag (Key Items)", "Portugues" => "Encher Mochila (So Itens Chave)", "Espanol" => "Llenar Mochila (Solo Clave)"},
    :emptybag => {"English" => "Empty Bag", "Portugues" => "Esvaziar Mochila", "Espanol" => "Vaciar Mochila"},
    
    :money => {"English" => "Edit Money", "Portugues" => "Editar Dinheiro", "Espanol" => "Editar Dinero"},
    :coins => {"English" => "Edit Coins", "Portugues" => "Editar Moedas", "Espanol" => "Editar Monedas"},
    :bp => {"English" => "Edit Battle Points", "Portugues" => "Editar BP", "Espanol" => "Editar BP"},
    :badges => {"English" => "Toggle All Badges", "Portugues" => "Obter Todas as Insignias", "Espanol" => "Obtener Medallas"},
    :pokedex => {"English" => "Complete Pokedex", "Portugues" => "Completar Pokedex", "Espanol" => "Completar Pokedex"},
    :fly => {"English" => "Unlock Fly Destinations", "Portugues" => "Desbloquear Voo (Fly)", "Espanol" => "Desbloquear Vuelo"},
    :name => {"English" => "Rename Player", "Portugues" => "Renomear Jogador", "Espanol" => "Renombrar Jugador"},
    :gender => {"English" => "Change Gender", "Portugues" => "Mudar Genero", "Espanol" => "Cambiar Genero"},
    :outfit => {"English" => "Change Outfit", "Portugues" => "Mudar Roupa", "Espanol" => "Cambiar Ropa"},
    :character => {"English" => "Player Character", "Portugues" => "Mudar Personagem", "Espanol" => "Cambiar Personaje"},
    :trainerid => {"English" => "Change Trainer ID", "Portugues" => "Mudar ID de Treinador", "Espanol" => "Cambiar ID"},
    :playtime => {"English" => "Edit Play Time", "Portugues" => "Editar Tempo de Jogo", "Espanol" => "Editar Tiempo Jugado"},
    :pokedex_tog => {"English" => "Toggle Pokedex", "Portugues" => "Obter Pokedex", "Espanol" => "Obtener Pokedex"},
    :pokegear => {"English" => "Toggle Pokegear", "Portugues" => "Obter Pokegear", "Espanol" => "Obtener Pokegear"},
    :shoes => {"English" => "Toggle Running Shoes", "Portugues" => "Tenis de Corrida", "Espanol" => "Zapatillas"},
    :ash => {"English" => "Edit Ash Count", "Portugues" => "Editar Cinzas (Ash)", "Espanol" => "Editar Cenizas"},
    :region => {"English" => "Change Region", "Portugues" => "Mudar Regiao", "Espanol" => "Cambiar Region"},
    :partner => {"English" => "Edit Partner", "Portugues" => "Remover Parceiro (Partner)", "Espanol" => "Quitar Companero"},
    :nobattles => {"English" => "Toggle No Battles", "Portugues" => "Batalhas: Nenhuma", "Espanol" => "Sin Batallas"},
    :infmega => {"English" => "Toggle Inf. Mega", "Portugues" => "Mega Evolucao Infinita", "Espanol" => "Mega Evolucion Infinita"},
    :nativedebug => {"English" => "Open Native Debug Menu", "Portugues" => "Abrir Debug Nativo", "Espanol" => "Abrir Debug Nativo"}
  }

# --- END 00_header.rb ---

# --- BEGIN 10_core.rb ---
  class << self
    attr_accessor :walk_through_walls
    attr_accessor :no_battles
    attr_accessor :inf_mega

    def initialize_variables
      @walk_through_walls = false
      @no_battles = false
      @inf_mega = false
      @processing_hotkey = false
      @menu_open = false
      @mobile_combo_hold_frames = 0
      @quick_actions = [:heal_party, :engine_report, :native_debug, :none]
    end

    def t(hash_or_string, *args)
      language_key = LANG_KEYS[LANG] || LANG
      str = hash_or_string.is_a?(Hash) ? (hash_or_string[language_key] || hash_or_string.values.first || "") : hash_or_string.to_s
      args.each_with_index { |a, i| str = str.gsub("{#{i+1}}", a.to_s) }
      str
    end

    def log_error(context_name, error)
      File.open("developer_menu_errors.log", "a") do |f|
        f.puts("[#{Time.now}] Error in #{context_name}: #{error.message}")
        f.puts(error.backtrace.join("\n")) if error.backtrace
      end
    end

    def try_call(context_name = nil)
      yield
    rescue => e
      log_error(context_name || "Operation", e)
      nil
    end

    def safe_execute(context_name = "System")
      yield
    rescue => e
      log_error(context_name, e)
      Kernel.pbMessage(_INTL("API Failure: {1} (Check log)", context_name))
    end

    def trigger_hotkey?(symbol_name, constant_name)
      return false unless defined?(Input)
      return true if Input.trigger?(symbol_name)
      return false unless Input.const_defined?(constant_name)
      Input.trigger?(Input.const_get(constant_name))
    rescue => e
      log_error("Hotkey #{constant_name}", e)
      false
    end

    def input_button_value(symbol_name, constant_name = nil)
      return nil unless defined?(Input)
      return symbol_name if symbol_name.is_a?(Integer)
      return Input.const_get(constant_name) if constant_name && Input.const_defined?(constant_name)
      upper_name = symbol_name.to_s.upcase
      return Input.const_get(upper_name) if Input.const_defined?(upper_name)
      symbol_name
    rescue
      nil
    end

    def input_pressing?(symbol_name, constant_name = nil)
      value = input_button_value(symbol_name, constant_name)
      return false if value.nil?
      Input.press?(value)
    rescue
      false
    end

    def all_input_pressing?(*buttons)
      return false if buttons.empty?
      buttons.all? { |button| input_pressing?(button, button.to_s.upcase) }
    end

    def joiplay_combo_triggered?
      return false unless defined?(Input)

      # Extra overlay/gamepad buttons if the player mapped them in JoiPlay.
      return true if all_input_pressing?(:L, :R)
      return true if all_input_pressing?(:AUX1, :AUX2)
      return true if all_input_pressing?(:CTRL, :SHIFT)

      # Emergency mobile fallback: hold the 3 default RMXP buttons together.
      if all_input_pressing?(:A, :B, :C)
        @mobile_combo_hold_frames ||= 0
        @mobile_combo_hold_frames += 1
        return true if @mobile_combo_hold_frames >= 24
      else
        @mobile_combo_hold_frames = 0
      end
      false
    rescue => e
      log_error("JoiPlay Combo Trigger", e)
      false
    end

    def menu_triggered?
      trigger_hotkey?(MENU_HOTKEY.to_sym, MENU_HOTKEY) || joiplay_combo_triggered?
    end

    def player_party
      p = get_player
      return [] unless p && p.respond_to?(:party) && p.party
      p.party
    end

    def remove_party_member(pkmn)
      party = player_party
      return false if party.empty?
      if party.respond_to?(:index)
        idx = party.index(pkmn)
        return !!party.delete_at(idx) unless idx.nil?
      end
      return !!party.delete(pkmn) if party.respond_to?(:delete)
      return !!party.Delete(pkmn) if party.respond_to?(:Delete)
      false
    end

    def get_repel_steps
      return $PokemonGlobal.repel if $PokemonGlobal && $PokemonGlobal.respond_to?(:repel)
      return $PokemonGlobal.repelSteps if $PokemonGlobal && $PokemonGlobal.respond_to?(:repelSteps)
      return $PokemonGlobal.repea if $PokemonGlobal && $PokemonGlobal.respond_to?(:repea)
      0
    end

    def set_repel_steps(value)
      if $PokemonGlobal.respond_to?(:repel=)
        $PokemonGlobal.repel = value
      elsif $PokemonGlobal.respond_to?(:repelSteps=)
        $PokemonGlobal.repelSteps = value
      else
        $PokemonGlobal.repea = value if $PokemonGlobal.respond_to?(:repea=)
      end
    end

    def get_map_toggle(*names)
      names.each do |name|
        return $PokemonMap.send(name) if $PokemonMap && $PokemonMap.respond_to?(name)
      end
      nil
    end

    def set_map_toggle(value, *names)
      names.each do |name|
        writer = "#{name}="
        if $PokemonMap && $PokemonMap.respond_to?(writer)
          $PokemonMap.send(writer, value)
          return true
        end
      end
      false
    end

    def safe_const_get(owner, name)
      return nil unless owner && owner.respond_to?(:const_defined?) && owner.const_defined?(name)
      owner.const_get(name)
    rescue
      nil
    end

    def safe_respond_to?(object, method_name)
      object && object.respond_to?(method_name)
    rescue
      false
    end

    def recalc_pokemon_stats(pkmn)
      pkmn.calc_stats if safe_respond_to?(pkmn, :calc_stats)
      pkmn.calcStats if safe_respond_to?(pkmn, :calcStats)
    rescue => e
      log_error("Recalculate Pokemon Stats", e)
    end

    def make_alias(alias_name, target_name, owner)
      return false unless owner
      return false unless owner.method_defined?(target_name) || owner.private_method_defined?(target_name)
      return false if owner.method_defined?(alias_name) || owner.private_method_defined?(alias_name)
      owner.send(:alias_method, alias_name, target_name)
      true
    rescue => e
      log_error("Alias #{target_name}", e)
      false
    end

    def make_singleton_alias(object, alias_name, target_name)
      return false unless object
      eigenclass = class << object; self; end
      return false unless eigenclass.method_defined?(target_name) || eigenclass.private_method_defined?(target_name)
      return false if eigenclass.method_defined?(alias_name) || eigenclass.private_method_defined?(alias_name)
      eigenclass.send(:alias_method, alias_name, target_name)
      true
    rescue => e
      log_error("Singleton Alias #{target_name}", e)
      false
    end

    def cached_engine_profile
      @engine_profile = nil if !defined?(@engine_profile)
      @engine_profile ||= detect_engine_profile
    end

    def reset_engine_profile!
      @engine_profile = nil
    end

    def modern_engine?
      cached_engine_profile[:modern_engine]
    end

    def detect_engine_profile
      profile = {}
      profile[:has_game_data] = defined?(GameData) ? true : false
      profile[:has_modern_player] = defined?($Player) ? true : false
      profile[:has_legacy_player] = defined?($Trainer) ? true : false
      profile[:has_modern_battle_api] = defined?(WildBattle) && WildBattle.respond_to?(:start)
      profile[:has_legacy_battle_api] = defined?(pbWildBattle) ? true : false
      profile[:has_modern_storage] = defined?($PokemonStorage) && $PokemonStorage && $PokemonStorage.respond_to?(:boxes)
      profile[:has_modern_debug_menu] = defined?(DebugMenu) ? true : false
      profile[:has_legacy_debug_menu] = defined?(pbDebugMenu) ? true : false
      profile[:has_cache] = defined?($cache) && $cache ? true : false
      profile[:modern_engine] = profile[:has_game_data] || profile[:has_modern_battle_api] || profile[:has_modern_player]
      profile[:player_api] = profile[:has_modern_player] ? "$Player" : (profile[:has_legacy_player] ? "$Trainer" : "Unknown")
      profile[:battle_api] = profile[:has_modern_battle_api] ? "WildBattle.start" : (profile[:has_legacy_battle_api] ? "pbWildBattle" : "Unknown")
      profile[:debug_api] = profile[:has_legacy_debug_menu] ? "pbDebugMenu" : (profile[:has_modern_debug_menu] ? "DebugMenu" : "Unavailable")
      profile[:data_api] = profile[:has_game_data] ? "GameData" : (profile[:has_cache] ? "$cache" : "Legacy PB*")
      profile
    rescue => e
      log_error("Detect Engine Profile", e)
      {
        :has_game_data => false,
        :has_modern_player => false,
        :has_legacy_player => false,
        :has_modern_battle_api => false,
        :has_legacy_battle_api => false,
        :has_modern_storage => false,
        :has_modern_debug_menu => false,
        :has_legacy_debug_menu => false,
        :has_cache => false,
        :modern_engine => false,
        :player_api => "Unknown",
        :battle_api => "Unknown",
        :debug_api => "Unavailable",
        :data_api => "Unknown"
      }
    end

    def engine_profile_lines
      profile = cached_engine_profile
      lines = [
        "Engine family: #{profile[:modern_engine] ? 'Modern/Hybrid' : 'Legacy'}",
        "Player API: #{profile[:player_api]}",
        "Battle API: #{profile[:battle_api]}",
        "Debug API: #{profile[:debug_api]}",
        "Data API: #{profile[:data_api]}",
        "Storage boxes API: #{profile[:has_modern_storage] ? 'Modern' : 'Legacy/Unknown'}"
      ]
      caps = engine_capabilities.select { |_k, v| v }.keys.map { |k| k.to_s }
      lines << "Capabilities: #{caps.empty? ? 'None detected' : caps.join(', ')}"
      lines
    end

    def show_engine_report
      reset_engine_profile!
      lines = engine_profile_lines
      File.open("PokeDebug_Engine_Report.txt", "w") { |f| f.puts(lines.join("\n")) }
      Kernel.pbMessage(_INTL("{1}", lines.join("\n")))
    rescue => e
      log_error("Engine Report", e)
      Kernel.pbMessage(_INTL("Could not build engine report."))
    end

    def on_off_text(value)
      value ? "ON" : "OFF"
    end

    def player_name_value
      p = get_player
      return p.name if p && p.respond_to?(:name) && p.name
      "Unknown"
    rescue
      "Unknown"
    end

    def player_money_value
      p = get_player
      return p.money if p && p.respond_to?(:money)
      0
    rescue
      0
    end

    def player_badge_count
      p = get_player
      return 0 unless p && p.respond_to?(:badges) && p.badges
      p.badges.count { |badge| badge }
    rescue
      0
    end

    def player_pokedex_owned_count
      p = get_player
      if p && p.respond_to?(:pokedex) && p.pokedex
        return p.pokedex.owned_count if p.pokedex.respond_to?(:owned_count)
        return p.pokedex.caught_count if p.pokedex.respond_to?(:caught_count)
      end
      return $Trainer.owned.count { |owned| owned } if defined?($Trainer) && $Trainer.respond_to?(:owned) && $Trainer.owned
      0
    rescue
      0
    end

    def player_summary_lines
      p = get_player
      lines = []
      lines << _INTL("Name: {1}", player_name_value)
      lines << _INTL("Money: {1}", player_money_value)
      lines << _INTL("Badges: {1}", player_badge_count)
      lines << _INTL("Pokedex owned: {1}", player_pokedex_owned_count)
      if p && p.respond_to?(:gender)
        gender_text = case p.gender
        when 0 then "Male"
        when 1 then "Female"
        else p.gender.to_s
        end
        lines << _INTL("Gender: {1}", gender_text)
      end
      lines << _INTL("Running Shoes: {1}", on_off_text($PokemonGlobal.runningShoes)) if $PokemonGlobal && $PokemonGlobal.respond_to?(:runningShoes)
      lines << _INTL("Pokedex Flag: {1}", on_off_text(!!($PokemonGlobal && $PokemonGlobal.respond_to?(:pokedexUnlocked) && $PokemonGlobal.pokedexUnlocked)))
      lines
    rescue => e
      log_error("Player Summary Lines", e)
      [_INTL("Could not build player summary.")]
    end

    def show_player_summary
      Kernel.pbMessage(_INTL("{1}", player_summary_lines.join("\n")))
    rescue => e
      log_error("Show Player Summary", e)
      false
    end

    def engine_status_lines
      profile = cached_engine_profile
      lines = []
      lines << _INTL("Engine family: {1}", profile[:modern_engine] ? "Modern/Hybrid" : "Legacy")
      lines << _INTL("Debug menu: {1}", on_off_text(debug_menu_available?))
      lines << _INTL("Storage: {1}", on_off_text(storage_available?))
      lines << _INTL("Day care: {1}", on_off_text(!get_day_care_data.nil?))
      lines << _INTL("Walk Through Walls: {1}", on_off_text(@walk_through_walls))
      lines << _INTL("No Battles: {1}", on_off_text(@no_battles))
      lines << _INTL("Infinite Mega: {1}", on_off_text(@inf_mega))
      lines
    rescue => e
      log_error("Engine Status Lines", e)
      [_INTL("Could not build engine status.")]
    end

    def show_engine_status
      Kernel.pbMessage(_INTL("{1}", engine_status_lines.join("\n")))
    rescue => e
      log_error("Show Engine Status", e)
      false
    end

    def pokemon_menu_status_lines
      party = player_party
      eggs = party.count { |pkmn| pokemon_egg_state(pkmn) }
      lines = []
      lines << _INTL("Party size: {1}/6", party.length)
      lines << _INTL("Eggs in party: {1}", eggs)
      lines << _INTL("PC storage: {1}", storage_available? ? "AVAILABLE" : "UNAVAILABLE")
      lines << _INTL("Native editor: {1}", native_pokemon_editor_available? ? "AVAILABLE" : "UNAVAILABLE")
      lines
    rescue => e
      log_error("Pokemon Menu Status", e)
      [_INTL("Could not build Pokemon status.")]
    end

    def show_pokemon_menu_status
      Kernel.pbMessage(_INTL("{1}", pokemon_menu_status_lines.join("\n")))
    rescue => e
      log_error("Show Pokemon Menu Status", e)
      false
    end

    def current_map_summary_lines
      lines = []
      if defined?($game_map) && $game_map
        lines << _INTL("Map ID: {1}", $game_map.map_id) if $game_map.respond_to?(:map_id)
        lines << _INTL("Events on map: {1}", current_map_events.length)
      else
        lines << _INTL("Map not available.")
      end
      if defined?($game_player) && $game_player
        x = $game_player.respond_to?(:x) ? $game_player.x : "?"
        y = $game_player.respond_to?(:y) ? $game_player.y : "?"
        lines << _INTL("Player position: ({1}, {2})", x, y)
      end
      lines
    rescue => e
      log_error("Current Map Summary", e)
      [_INTL("Could not build map summary.")]
    end

    def show_current_map_summary
      Kernel.pbMessage(_INTL("{1}", current_map_summary_lines.join("\n")))
    rescue => e
      log_error("Show Current Map Summary", e)
      false
    end

    def quick_actions
      @quick_actions ||= [:heal_party, :engine_report, :native_debug, :none]
    end

    def quick_action_definitions
      [
        { :id => :none, :label => "Empty Slot", :action => proc { } },
        { :id => :heal_party, :label => "Heal Party", :action => proc { heal_party } },
        { :id => :toggle_no_battles, :label => "Toggle No Battles", :action => proc {
          @no_battles = !@no_battles
          Kernel.pbMessage(_INTL("No Battles: {1}", @no_battles ? "ON" : "OFF"))
        }},
        { :id => :toggle_wtw, :label => "Toggle Walk Through Walls", :action => proc { toggle_wtw } },
        { :id => :engine_report, :label => "Engine Compatibility Report", :action => proc { show_engine_report } },
        { :id => :native_debug, :label => "Open Native Debug Menu", :action => proc { open_native_debug_menu } },
        { :id => :native_pokemon_editor, :label => "Open Native Pokemon Editor", :action => proc { open_native_pokemon_editor_for_party } },
        { :id => :open_pc, :label => "Open PC", :action => proc { open_pc_menu } },
        { :id => :refresh_map, :label => "Refresh Map", :action => proc { engine_refresh_map if respond_to?(:engine_refresh_map) } }
      ]
    end

    def find_quick_action(action_id)
      quick_action_definitions.find { |entry| entry[:id] == action_id }
    end

    def configure_quick_actions
      loop do
        cmds = quick_actions.each_with_index.map do |action_id, idx|
          action = find_quick_action(action_id)
          "Slot #{idx + 1}: #{action ? action[:label] : 'Unknown'}"
        end
        cmds.push("Back")
        slot = Kernel.pbMessage(_INTL("Configure Quick Actions:"), cmds, -1)
        break if slot < 0 || slot >= quick_actions.length

        action_cmds = quick_action_definitions.map { |entry| entry[:label] }
        choice = Kernel.pbMessage(_INTL("Choose action for slot {1}:", slot + 1), action_cmds, -1)
        next if choice < 0
        quick_actions[slot] = quick_action_definitions[choice][:id]
      end
    end

    def run_quick_actions_menu
      menu = quick_actions.map do |action_id|
        action = find_quick_action(action_id)
        next nil if !action || action[:id] == :none
        { :label => action[:label], :action => action[:action] }
      end.compact
      if menu.empty?
        Kernel.pbMessage(_INTL("No quick actions configured."))
        return
      end
      render_dynamic_menu("Quick Actions", menu)
    end

    def debug_menu_available?
      cached_engine_profile[:has_legacy_debug_menu] || cached_engine_profile[:has_modern_debug_menu]
    end

    def native_pokemon_editor_available?
      return true if defined?(pbPokemonDebug)
      return true if defined?(pbDebugPokemon)
      return true if defined?(PokemonDebug_Scene)
      return true if defined?(PokemonDebugScene)
      false
    end

    def engine_capabilities
      {
        :debug_menu => debug_menu_available?,
        :day_care => !get_day_care_data.nil?,
        :storage => storage_available?,
        :map_factory => defined?($MapFactory) && !$MapFactory.nil?,
        :game_data => cached_engine_profile[:has_game_data],
        :cache_data => cached_engine_profile[:has_cache],
        :battle_modern => cached_engine_profile[:has_modern_battle_api],
        :battle_legacy => cached_engine_profile[:has_legacy_battle_api],
        :player_name_ui => defined?(pbEnterPlayerName) ? true : false,
        :pokemon_name_ui => defined?(pbEnterPokemonName) ? true : false,
        :presets => true
      }
    rescue => e
      log_error("Engine Capabilities", e)
      {}
    end

    def preset_file_path
      "PokeDebug_Pokemon_Preset.dat"
    end

    def data_record(type, id)
      klass = game_data_class(type)
      return nil unless klass && klass.respond_to?(:get)
      klass.get(id)
    rescue => e
      log_error("Data Record #{type}", e)
      nil
    end

    def species_forms(species_id)
      forms = [0]
      sp_data = data_record(:Species, species_id)
      if sp_data
        if sp_data.respond_to?(:forms)
          sp_data.forms.each { |f| forms.push(f) unless forms.include?(f) }
        elsif sp_data.respond_to?(:form)
          forms.push(sp_data.form) unless forms.include?(sp_data.form)
        end
      end
      forms
    rescue => e
      log_error("Species Forms", e)
      [0]
    end

    def storage_max_boxes
      return 0 unless storage_available?
      try_call("Storage Max Boxes") { $PokemonStorage.maxBoxes } || 0
    end

    def storage_max_pokemon(box)
      return 0 unless storage_available?
      try_call("Storage Max Pokemon #{box}") { $PokemonStorage.maxPokemon(box) } || 0
    end

    def storage_store_caught(pkmn)
      return false unless storage_available?
      return $PokemonStorage.pbStoreCaught(pkmn) if $PokemonStorage.respond_to?(:pbStoreCaught)

      each_storage_index do |box, slot|
        current_box = try_call("Storage Slot Auto-Store") { $PokemonStorage[box] }
        next unless current_box
        next if current_box[slot]
        current_box[slot] = pkmn
        return true
      end
      false
    rescue => e
      log_error("Storage Store Caught", e)
      false
    end

    def storage_add_box(name)
      return false unless storage_available?
      box_size = storage_max_pokemon(0)
      return false unless defined?(PokemonBox) && box_size > 0
      return false unless $PokemonStorage.respond_to?(:boxes) && $PokemonStorage.boxes.respond_to?(:push)
      $PokemonStorage.boxes.push(PokemonBox.new(name, box_size))
      true
    rescue => e
      log_error("Storage Add Box", e)
      false
    end

    def get_day_care_data
      return nil unless defined?($PokemonGlobal) && $PokemonGlobal
      dc = try_call("Day Care Legacy") { $PokemonGlobal.day_care }
      dc = $PokemonGlobal.daycare if dc.nil? && $PokemonGlobal.respond_to?(:daycare)
      dc
    end

    def day_care_first_slot(dc = nil)
      dc ||= get_day_care_data
      return nil unless dc
      return dc[0] if dc.respond_to?(:[])
      nil
    rescue => e
      log_error("Day Care First Slot", e)
      nil
    end

    def day_care_first_pokemon(dc = nil)
      slot = day_care_first_slot(dc)
      return nil unless slot
      return slot.pokemon if slot.respond_to?(:pokemon)
      nil
    rescue => e
      log_error("Day Care First Pokemon", e)
      nil
    end

    def day_care_deposit_first(pkmn, dc = nil)
      slot = day_care_first_slot(dc)
      return false unless slot
      slot.pokemon = pkmn if slot.respond_to?(:pokemon=)
      slot.level = pkmn.level if slot.respond_to?(:level=) && pkmn.respond_to?(:level)
      true
    rescue => e
      log_error("Day Care Deposit", e)
      false
    end

    def day_care_withdraw_first(dc = nil)
      slot = day_care_first_slot(dc)
      return nil unless slot
      pkmn = day_care_first_pokemon(dc)
      slot.pokemon = nil if slot.respond_to?(:pokemon=)
      pkmn
    rescue => e
      log_error("Day Care Withdraw", e)
      nil
    end

    def day_care_force_egg(dc = nil)
      dc ||= get_day_care_data
      return false unless dc
      dc.step_count = 255 if dc.respond_to?(:step_count=)
      dc.egg_generated = true if dc.respond_to?(:egg_generated=)
      true
    rescue => e
      log_error("Day Care Force Egg", e)
      false
    end

    def game_data_class(type)
      return nil unless cached_engine_profile[:has_game_data]
      safe_const_get(GameData, type)
    end

    def legacy_pb_module(type)
      names = ["PB#{type}", "PB#{type}s"]
      names << "PB#{type.to_s[0...-1]}ies" if type.to_s.end_with?("y")
      case type
      when :TrainerType
        names.concat(["PBTrainers", "PBTrainerTypes"])
      when :Ability
        names.concat(["PBAbilities"])
      when :Ribbon
        names.concat(["PBRibbons"])
      when :Nature
        names.concat(["PBNatures"])
      when :Status
        names.concat(["PBStatuses"])
      end
      names.each do |const_name|
        mod = safe_const_get(Object, const_name.to_sym)
        return mod if mod
      end
      nil
    end

    def cache_collection(type)
      return nil unless cached_engine_profile[:has_cache]
      mapping = {
        :Species => [:pkmn, :pokemon, :species],
        :Item => [:items, :item, :itemData],
        :Move => [:moves, :move, :moveData],
        :Nature => [:natures, :nature],
        :Type => [:types, :type],
        :Ability => [:abilities, :ability],
        :Ribbon => [:ribbons, :ribbon],
        :TrainerType => [:trainertypes, :trainer_types, :trainers, :trainerTypes],
        :Status => [:statuses, :status]
      }
      names = mapping[type] || []
      names.each do |name|
        return $cache.send(name) if $cache.respond_to?(name)
      end
      nil
    rescue => e
      log_error("Cache Collection #{type}", e)
      nil
    end

    def legacy_constant_display_name(type, const_name, value)
      return PBSpecies.getName(value) if type == :Species && defined?(PBSpecies) && PBSpecies.respond_to?(:getName)
      return PBAbilities.getName(value) if type == :Ability && defined?(PBAbilities) && PBAbilities.respond_to?(:getName)
      return PBItems.getName(value) if type == :Item && defined?(PBItems) && PBItems.respond_to?(:getName)
      return PBMoves.getName(value) if type == :Move && defined?(PBMoves) && PBMoves.respond_to?(:getName)
      return PBNatures.getName(value) if type == :Nature && defined?(PBNatures) && PBNatures.respond_to?(:getName)
      return PBTypes.getName(value) if type == :Type && defined?(PBTypes) && PBTypes.respond_to?(:getName)
      return PBTrainers.getName(value) if type == :TrainerType && defined?(PBTrainers) && PBTrainers.respond_to?(:getName)
      const_name.to_s.capitalize
    rescue => e
      log_error("Legacy Display Name #{type}", e)
      const_name.to_s.capitalize
    end

    def safe_display_name(record, fallback)
      return fallback.to_s.capitalize unless record
      return record.name if record.respond_to?(:name) && record.name
      fallback.to_s.capitalize
    rescue
      fallback.to_s.capitalize
    end

    def safe_load_data(path)
      load_data(path)
    rescue => e
      log_error("Load Data #{path}", e)
      nil
    end

    def frame_rate_value
      return Graphics.frame_rate if defined?(Graphics) && Graphics.respond_to?(:frame_rate)
      40
    rescue
      40
    end

    def choose_pokemon_with_callback(&block)
      return false unless defined?(pbChoosePokemon)
      attempts = [
        proc { pbChoosePokemon(1, 2, block) },
        proc { pbChoosePokemon(1, 2, &block) },
        proc { pbChoosePokemon(1, &block) },
        proc { pbChoosePokemon(&block) }
      ]
      attempts.each do |attempt|
        begin
          attempt.call
          return true
        rescue ArgumentError
          next
        end
      end
      false
    rescue => e
      log_error("Choose Pokemon", e)
      false
    end

    def open_native_debug_menu
      if cached_engine_profile[:has_legacy_debug_menu]
        pbDebugMenu
        return true
      end

      if cached_engine_profile[:has_modern_debug_menu] && DebugMenu.respond_to?(:new)
        DebugMenu.new.pbStartScreen
        return true
      end

      false
    rescue => e
      log_error("Native Debug Menu", e)
      false
    end

    def open_native_pokemon_editor(pkmn = nil)
      if defined?(pbPokemonDebug)
        begin
          return true if pbPokemonDebug(pkmn)
        rescue ArgumentError
          return true if pbPokemonDebug(pkmn, nil)
        end
      end

      if defined?(pbDebugPokemon)
        begin
          return true if pbDebugPokemon(pkmn)
        rescue ArgumentError
          return true if pbDebugPokemon(pkmn, nil)
        end
      end

      if defined?(pbEditPokemon)
        begin
          return true if pbEditPokemon(pkmn)
        rescue ArgumentError
          return true if pbEditPokemon(pkmn, nil)
        end
      end

      if defined?(pbPokemonEditor)
        begin
          return true if pbPokemonEditor(pkmn)
        rescue ArgumentError
          return true if pbPokemonEditor(pkmn, nil)
        end
      end

      if defined?(PokemonDebug_Scene) && defined?(PokemonDebugScreen)
        scene = PokemonDebug_Scene.new
        screen = PokemonDebugScreen.new(scene, pkmn)
        screen.pbStartScreen
        return true
      end

      if defined?(PokemonDebugScene) && defined?(PokemonDebugScreen)
        scene = PokemonDebugScene.new
        screen = PokemonDebugScreen.new(scene, pkmn)
        screen.pbStartScreen
        return true
      end

      false
    rescue => e
      log_error("Native Pokemon Editor", e)
      false
    end

    def open_native_pokemon_editor_for_party
      chosen = nil
      if choose_pokemon_with_callback { |pkmn| chosen = pkmn }
        if chosen
          return true if open_native_pokemon_editor(chosen)
        end
      else
        chosen = player_party.first
        return true if chosen && open_native_pokemon_editor(chosen)
      end
      Kernel.pbMessage(_INTL("Native Pokemon editor not available on this version."))
      false
    rescue => e
      log_error("Open Native Pokemon Editor For Party", e)
      false
    end

    def open_pc_menu
      return pbPokeCenterPC if defined?(pbPokeCenterPC)
      return pbPC if defined?(pbPC)
      Kernel.pbMessage(_INTL("PC not supported on this version."))
    rescue => e
      log_error("Open PC", e)
      Kernel.pbMessage(_INTL("PC could not be opened on this version."))
    end

    def cancel_vehicles_if_possible
      pbCancelVehicles if defined?(pbCancelVehicles)
    rescue => e
      log_error("Cancel Vehicles", e)
    end

    def safe_map_factory_map(map_id)
      return nil unless defined?($MapFactory) && $MapFactory
      $MapFactory.getMap(map_id)
    rescue => e
      log_error("Map Factory #{map_id}", e)
      nil
    end

    def safe_set_map_changed(map_id)
      return false unless defined?($MapFactory) && $MapFactory.respond_to?(:setMapChanged)
      $MapFactory.setMapChanged(map_id)
      true
    rescue => e
      log_error("Set Map Changed", e)
      false
    end

    def set_name_via_ui(default_name = "")
      return nil unless defined?(pbEnterPlayerName)
      pbEnterPlayerName("Your Name?", 0, 12, default_name)
    rescue => e
      log_error("Enter Player Name", e)
      nil
    end

    def set_pokemon_name_via_ui(pkmn)
      return nil unless defined?(pbEnterPokemonName)
      pbEnterPokemonName("Nickname?", 0, 12, "", pkmn)
    rescue => e
      log_error("Enter Pokemon Name", e)
      nil
    end

    def set_owner_name_via_ui(owner_name)
      return nil unless defined?(pbEnterPlayerName)
      pbEnterPlayerName("OT Name?", 0, 12, owner_name)
    rescue => e
      log_error("Enter OT Name", e)
      nil
    end

    def pokemon_legal_abilities(pkmn)
      return [] unless pkmn && pkmn.respond_to?(:getAbilityList)
      abils = try_call("Pokemon Ability List") { pkmn.getAbilityList }
      return [] unless abils.is_a?(Array)
      abils
    end

    def set_pokemon_legal_ability!(pkmn, choice_index = nil)
      abils = pokemon_legal_abilities(pkmn)
      return false if abils.empty?
      if choice_index.nil?
        cmds = abils.map { |a| a[0].to_s }
        choice_index = Kernel.pbMessage(_INTL("Choose ability:"), cmds, -1)
      end
      return false if choice_index.nil? || choice_index < 0 || choice_index >= abils.length
      pkmn.ability_index = abils[choice_index][1] if pkmn.respond_to?(:ability_index=)
      true
    rescue => e
      log_error("Set Legal Ability", e)
      false
    end

    def set_pokemon_ability!(pkmn, ability_symbol, force_index = nil)
      return false unless pkmn
      pkmn.ability = ability_symbol if pkmn.respond_to?(:ability=)
      pkmn.setAbility(ability_symbol) if pkmn.respond_to?(:setAbility)
      pkmn.ability_index = force_index if !force_index.nil? && pkmn.respond_to?(:ability_index=)
      true
    rescue => e
      log_error("Set Ability", e)
      false
    end

    def reset_pokemon_ability!(pkmn)
      return false unless pkmn
      pkmn.ability_index = nil if pkmn.respond_to?(:ability_index=)
      pkmn.ability = nil if pkmn.respond_to?(:ability=)
      true
    rescue => e
      log_error("Reset Ability", e)
      false
    end

    def set_pokemon_nature!(pkmn, nature_symbol)
      return false unless pkmn
      pkmn.nature = nature_symbol if pkmn.respond_to?(:nature=)
      pkmn.setNature(nature_symbol) if pkmn.respond_to?(:setNature)
      true
    rescue => e
      log_error("Set Nature", e)
      false
    end

    def set_pokemon_item!(pkmn, item_symbol)
      return false unless pkmn
      pkmn.item = item_symbol if pkmn.respond_to?(:item=)
      pkmn.setItem(item_symbol) if pkmn.respond_to?(:setItem)
      true
    rescue => e
      log_error("Set Held Item", e)
      false
    end

    def remove_pokemon_item!(pkmn)
      set_pokemon_item!(pkmn, nil)
    end

    def set_pokemon_nickname!(pkmn, nickname)
      return false unless pkmn
      return false if nickname.nil? || nickname == ""
      pkmn.name = nickname if pkmn.respond_to?(:name=)
      true
    rescue => e
      log_error("Set Nickname", e)
      false
    end

    def rename_pokemon_via_ui!(pkmn)
      return false unless pkmn
      nickname = set_pokemon_name_via_ui(pkmn)
      return false if nickname.nil? || nickname == ""
      set_pokemon_nickname!(pkmn, nickname)
    end

    def set_pokemon_ot_name!(pkmn, owner_name)
      return false unless pkmn
      return false if owner_name.nil? || owner_name == ""
      if pkmn.respond_to?(:owner) && pkmn.owner && pkmn.owner.respond_to?(:name=)
        pkmn.owner.name = owner_name
        return true
      end
      pkmn.ot = owner_name if pkmn.respond_to?(:ot=)
      return true if pkmn.respond_to?(:ot=)
      false
    rescue => e
      log_error("Set OT Name", e)
      false
    end

    def rename_pokemon_ot_via_ui!(pkmn)
      return false unless pkmn
      current_name = ""
      current_name = pkmn.owner.name if pkmn.respond_to?(:owner) && pkmn.owner && pkmn.owner.respond_to?(:name)
      current_name = pkmn.ot if current_name == "" && pkmn.respond_to?(:ot)
      new_name = set_owner_name_via_ui(current_name)
      return false if new_name.nil? || new_name == ""
      set_pokemon_ot_name!(pkmn, new_name)
    end

    def pokemon_ot_name(pkmn)
      return "" unless pkmn
      return pkmn.owner.name if pkmn.respond_to?(:owner) && pkmn.owner && pkmn.owner.respond_to?(:name)
      return pkmn.ot if pkmn.respond_to?(:ot)
      ""
    rescue => e
      log_error("Pokemon OT Name", e)
      ""
    end

    def pokemon_species_name(pkmn)
      return "Unknown" unless pkmn
      return pkmn.speciesName if pkmn.respond_to?(:speciesName) && pkmn.speciesName
      species_id = pkmn.species if pkmn.respond_to?(:species)
      record = data_record(:Species, species_id)
      return record.name if record && record.respond_to?(:name) && record.name
      return PBSpecies.getName(species_id) if defined?(PBSpecies) && PBSpecies.respond_to?(:getName)
      species_id ? species_id.to_s : "Unknown"
    rescue => e
      log_error("Pokemon Species Name", e)
      "Unknown"
    end

    def pokemon_level_value(pkmn)
      return pkmn.level if pkmn && pkmn.respond_to?(:level)
      0
    rescue
      0
    end

    def pokemon_current_hp(pkmn)
      return pkmn.hp if pkmn && pkmn.respond_to?(:hp)
      nil
    rescue
      nil
    end

    def pokemon_total_hp_value(pkmn)
      return pkmn.totalhp if pkmn && pkmn.respond_to?(:totalhp)
      return pkmn.total_hp if pkmn && pkmn.respond_to?(:total_hp)
      return pkmn.hp if pkmn && pkmn.respond_to?(:hp)
      nil
    rescue
      nil
    end

    def pokemon_status_label(pkmn)
      return "OK" unless pkmn
      status = nil
      status = pkmn.status if pkmn.respond_to?(:status)
      return "OK" if status.nil? || status == false || status == 0 || status == :NONE
      status = status.id if status.respond_to?(:id)
      status.to_s.upcase
    rescue => e
      log_error("Pokemon Status Label", e)
      "OK"
    end

    def pokemon_item_name(pkmn)
      return "None" unless pkmn
      item = pkmn.item if pkmn.respond_to?(:item)
      return "None" if item.nil? || item == 0
      return item_display_name(item)
    rescue => e
      log_error("Pokemon Item Name", e)
      "None"
    end

    def item_display_name(item_id)
      return "None" if item_id.nil? || item_id == 0
      record = data_record(:Item, item_id)
      return record.name if record && record.respond_to?(:name) && record.name
      return PBItems.getName(item_id) if defined?(PBItems) && PBItems.respond_to?(:getName)
      item_id.to_s
    rescue => e
      log_error("Item Display Name", e)
      "None"
    end

    def ability_display_name(ability_id)
      return "None" if ability_id.nil? || ability_id == 0
      record = data_record(:Ability, ability_id)
      return record.name if record && record.respond_to?(:name) && record.name
      return PBAbilities.getName(ability_id) if defined?(PBAbilities) && PBAbilities.respond_to?(:getName)
      ability_id.to_s
    rescue => e
      log_error("Ability Display Name", e)
      "None"
    end

    def pokemon_shiny_state(pkmn)
      return false unless pkmn
      return pkmn.shiny? if pkmn.respond_to?(:shiny?)
      return pkmn.shiny if pkmn.respond_to?(:shiny)
      false
    rescue => e
      log_error("Pokemon Shiny State", e)
      false
    end

    def pokemon_egg_state(pkmn)
      return false unless pkmn
      return pkmn.egg? if pkmn.respond_to?(:egg?)
      return pkmn.isEgg? if pkmn.respond_to?(:isEgg?)
      false
    rescue => e
      log_error("Pokemon Egg State", e)
      false
    end

    def pokemon_form_value(pkmn)
      return pkmn.form if pkmn && pkmn.respond_to?(:form)
      0
    rescue
      0
    end

    def pokemon_party_label(pkmn)
      return "Unknown Pokemon" unless pkmn
      name = pkmn.respond_to?(:name) ? pkmn.name.to_s : pokemon_species_name(pkmn)
      level = pokemon_level_value(pkmn)
      hp = pokemon_current_hp(pkmn)
      total_hp = pokemon_total_hp_value(pkmn)
      status = pokemon_status_label(pkmn)
      shiny_tag = pokemon_shiny_state(pkmn) ? " *Shiny*" : ""
      egg_tag = pokemon_egg_state(pkmn) ? " [Egg]" : ""
      hp_text = hp.nil? || total_hp.nil? ? "" : " HP #{hp}/#{total_hp}"
      "#{name} (Lv.#{level})#{egg_tag}#{shiny_tag}#{hp_text} #{status}"
    rescue => e
      log_error("Pokemon Party Label", e)
      "Unknown Pokemon"
    end

    def pokemon_summary_lines(pkmn)
      return [_INTL("Pokemon not available.")] unless pkmn
      lines = []
      lines << _INTL("Name: {1}", pkmn.respond_to?(:name) ? pkmn.name : pokemon_species_name(pkmn))
      lines << _INTL("Species: {1}", pokemon_species_name(pkmn))
      lines << _INTL("Level: {1}", pokemon_level_value(pkmn))
      hp = pokemon_current_hp(pkmn)
      total_hp = pokemon_total_hp_value(pkmn)
      lines << _INTL("HP: {1}/{2}", hp, total_hp) if !hp.nil? && !total_hp.nil?
      lines << _INTL("Status: {1}", pokemon_status_label(pkmn))
      lines << _INTL("Item: {1}", pokemon_item_name(pkmn))
      lines << _INTL("OT: {1}", pokemon_ot_name(pkmn))
      lines << _INTL("Nature: {1}", pkmn.nature) if pkmn.respond_to?(:nature) && pkmn.nature
      lines << _INTL("Form: {1}", pokemon_form_value(pkmn)) if pokemon_form_value(pkmn).to_i > 0
      lines << _INTL("Shiny: {1}", pokemon_shiny_state(pkmn) ? "YES" : "NO")
      lines << _INTL("Egg: {1}", pokemon_egg_state(pkmn) ? "YES" : "NO")
      lines
    rescue => e
      log_error("Pokemon Summary Lines", e)
      [_INTL("Could not build summary.")]
    end

    def pokemon_move_lines(pkmn)
      lines = []
      each_move_slot(pkmn) do |move, index|
        next unless move
        move_name = move.respond_to?(:name) ? move.name : move_display_name(move_identifier(move))
        pp = move.respond_to?(:pp) ? move.pp : "?"
        total_pp = move.respond_to?(:total_pp) ? move.total_pp : (move.respond_to?(:totalPP) ? move.totalPP : "?")
        lines << _INTL("{1}. {2} ({3}/{4} PP)", index + 1, move_name, pp, total_pp)
      end
      lines = [_INTL("No moves learned.")] if lines.empty?
      lines
    rescue => e
      log_error("Pokemon Move Lines", e)
      [_INTL("Could not read moveset.")]
    end

    def show_pokemon_summary(pkmn)
      Kernel.pbMessage(_INTL("{1}", pokemon_summary_lines(pkmn).join("\n")))
    rescue => e
      log_error("Show Pokemon Summary", e)
      false
    end

    def show_pokemon_moveset(pkmn)
      Kernel.pbMessage(_INTL("{1}", pokemon_move_lines(pkmn).join("\n")))
    rescue => e
      log_error("Show Pokemon Moveset", e)
      false
    end

    def genderless_pokemon?(pkmn)
      return true if pkmn.respond_to?(:gender_ratio) && pkmn.gender_ratio == :Genderless
      false
    rescue => e
      log_error("Genderless Check", e)
      false
    end

    def set_pokemon_gender!(pkmn, target)
      return false unless pkmn
      case target
      when :male
        pkmn.makeMale if pkmn.respond_to?(:makeMale)
        pkmn.gender = 0 if pkmn.respond_to?(:gender=)
      when :female
        pkmn.makeFemale if pkmn.respond_to?(:makeFemale)
        pkmn.gender = 1 if pkmn.respond_to?(:gender=)
      when :genderless
        pkmn.makeGenderless if pkmn.respond_to?(:makeGenderless)
        pkmn.gender = 2 if pkmn.respond_to?(:gender=)
      else
        return false
      end
      true
    rescue => e
      log_error("Set Gender", e)
      false
    end

    def prompt_pokemon_gender!(pkmn)
      return false if genderless_pokemon?(pkmn)
      ch = Kernel.pbMessage(_INTL("Set Gender?"), ["Male", "Female", "Cancel"], -1)
      return false if ch < 0 || ch == 2
      set_pokemon_gender!(pkmn, ch == 0 ? :male : :female)
    end

    def set_pokemon_status!(pkmn, status_symbol, sleep_turns = 3)
      return false unless pkmn
      return false unless pkmn.respond_to?(:status=)
      pkmn.status = status_symbol
      if status_symbol == :SLEEP && pkmn.respond_to?(:statusCount=)
        pkmn.statusCount = sleep_turns
      end
      true
    rescue => e
      log_error("Set Status", e)
      false
    end

    def clear_pokemon_status!(pkmn)
      return false unless pkmn
      if pkmn.respond_to?(:status=)
        pkmn.status = nil
      elsif pkmn.respond_to?(:status)
        pkmn.status = 0 rescue nil
      end
      pkmn.statusCount = 0 if pkmn.respond_to?(:statusCount=)
      true
    rescue => e
      log_error("Clear Status", e)
      false
    end

    def set_pokemon_shiny!(pkmn, shiny = true)
      return false unless pkmn
      if shiny
        pkmn.shiny = true if pkmn.respond_to?(:shiny=)
        pkmn.makeShiny if pkmn.respond_to?(:makeShiny)
      else
        pkmn.shiny = false if pkmn.respond_to?(:shiny=)
      end
      true
    rescue => e
      log_error("Set Shiny", e)
      false
    end

    def set_pokemon_species!(pkmn, species_symbol)
      return false unless pkmn
      pkmn.species = species_symbol if pkmn.respond_to?(:species=)
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Set Species", e)
      false
    end

    def set_pokemon_form!(pkmn, form)
      return false unless pkmn
      pkmn.form = form if pkmn.respond_to?(:form=)
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Set Form", e)
      false
    end

    def clear_pokemon_form_override!(pkmn)
      return false unless pkmn
      pkmn.forced_form = nil if pkmn.respond_to?(:forced_form=)
      true
    rescue => e
      log_error("Clear Form Override", e)
      false
    end

    def set_pokemon_ball!(pkmn, item_id)
      return false unless pkmn
      set_ball_data!(pkmn, item_id)
      true
    rescue => e
      log_error("Set Poke Ball", e)
      false
    end

    def add_pokemon_ribbon!(pkmn, ribbon_symbol)
      return false unless pkmn
      return false unless pkmn.respond_to?(:giveRibbon)
      pkmn.giveRibbon(ribbon_symbol)
      true
    rescue => e
      log_error("Add Ribbon", e)
      false
    end

    def clear_pokemon_ribbons!(pkmn)
      return false unless pkmn
      pkmn.clearAllRibbons if pkmn.respond_to?(:clearAllRibbons)
      if pkmn.respond_to?(:ribbons) && pkmn.ribbons.respond_to?(:Clear)
        pkmn.ribbons.Clear
      elsif pkmn.respond_to?(:ribbons) && pkmn.ribbons.respond_to?(:clear)
        pkmn.ribbons.clear
      end
      true
    rescue => e
      log_error("Clear Ribbons", e)
      false
    end

    def make_pokemon_egg!(pkmn)
      return false unless pkmn
      pkmn.name = "Egg" if pkmn.respond_to?(:name=)
      pkmn.egg_steps = 255 if pkmn.respond_to?(:egg_steps=)
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Make Egg", e)
      false
    end

    def hatch_pokemon_egg!(pkmn)
      return false unless pkmn
      pkmn.name = pkmn.speciesName if pkmn.respond_to?(:name=) && pkmn.respond_to?(:speciesName)
      pkmn.egg_steps = 0 if pkmn.respond_to?(:egg_steps=)
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Hatch Egg", e)
      false
    end

    def set_pokemon_hatch_steps!(pkmn, steps)
      return false unless pkmn
      return false unless pkmn.respond_to?(:egg_steps=)
      pkmn.egg_steps = steps
      true
    rescue => e
      log_error("Set Egg Steps", e)
      false
    end

    def heal_pokemon!(pkmn)
      return false unless pkmn
      healed = false
      if pkmn.respond_to?(:Heal)
        pkmn.Heal
        healed = true
      end
      if pkmn.respond_to?(:heal)
        pkmn.heal
        healed = true
      end
      max_hp = pokemon_total_hp_value(pkmn)
      if !max_hp.nil? && max_hp.to_i > 0 && pkmn.respond_to?(:hp=)
        pkmn.hp = max_hp.to_i
        healed = true
      end
      clear_pokemon_status!(pkmn)
      restore_pokemon_pp!(pkmn)
      recalc_pokemon_stats(pkmn)
      max_hp = pokemon_total_hp_value(pkmn)
      pkmn.hp = max_hp.to_i if !max_hp.nil? && max_hp.to_i > 0 && pkmn.respond_to?(:hp=)
      healed
    rescue => e
      log_error("Heal Pokemon", e)
      false
    end

    def set_pokemon_hp!(pkmn, value)
      return false unless pkmn && pkmn.respond_to?(:hp=)
      max_hp = nil
      max_hp = pkmn.totalhp if pkmn.respond_to?(:totalhp)
      max_hp = pkmn.total_hp if max_hp.nil? && pkmn.respond_to?(:total_hp)
      max_hp = pkmn.hp if max_hp.nil? && pkmn.respond_to?(:hp)
      min_value = 0
      final_value = value.to_i
      final_value = min_value if final_value < min_value
      final_value = [final_value, max_hp].min if max_hp && max_hp > 0
      pkmn.hp = final_value
      true
    rescue => e
      log_error("Set HP", e)
      false
    end

    def faint_pokemon!(pkmn)
      set_pokemon_hp!(pkmn, 0)
    end

    def set_pokemon_level!(pkmn, level)
      return false unless pkmn
      pkmn.level = level if pkmn.respond_to?(:level=)
      recalc_pokemon_stats(pkmn)
      if pkmn.respond_to?(:hp) && pkmn.respond_to?(:totalhp) && pkmn.hp > pkmn.totalhp
        pkmn.hp = pkmn.totalhp if pkmn.respond_to?(:hp=)
      end
      true
    rescue => e
      log_error("Set Level", e)
      false
    end

    def set_pokemon_exp!(pkmn, exp)
      return false unless pkmn
      pkmn.exp = exp if pkmn.respond_to?(:exp=)
      recalc_pokemon_stats(pkmn)
      if pkmn.respond_to?(:hp) && pkmn.respond_to?(:totalhp) && pkmn.hp > pkmn.totalhp
        pkmn.hp = pkmn.totalhp if pkmn.respond_to?(:hp=)
      end
      true
    rescue => e
      log_error("Set Experience", e)
      false
    end

    def set_pokemon_happiness!(pkmn, value)
      return false unless pkmn && pkmn.respond_to?(:happiness=)
      pkmn.happiness = value
      true
    rescue => e
      log_error("Set Happiness", e)
      false
    end

    def max_pokemon_ivs!(pkmn, value = 31)
      set_all_ivs!(pkmn, value)
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Max IVs", e)
      false
    end

    def max_pokemon_evs!(pkmn, value = 252)
      set_all_evs!(pkmn, value)
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Max EVs", e)
      false
    end

    def each_move_slot(pkmn)
      return enum_for(:each_move_slot, pkmn) unless block_given?
      return unless pkmn && pkmn.respond_to?(:moves) && pkmn.moves
      pkmn.moves.each_with_index { |move, index| yield move, index }
    end

    def move_identifier(move)
      return nil unless move
      return move.id if move.respond_to?(:id)
      return move.move if move.respond_to?(:move)
      return move.id_number if move.respond_to?(:id_number)
      nil
    rescue => e
      log_error("Move Identifier", e)
      nil
    end

    def move_display_name(move_id)
      return "" if move_id.nil?
      record = data_record(:Move, move_id)
      return record.name if record && record.respond_to?(:name) && record.name
      return PBMoves.getName(move_id) if defined?(PBMoves) && PBMoves.respond_to?(:getName)
      move_id.to_s
    rescue => e
      log_error("Move Display Name", e)
      move_id.to_s
    end

    def choose_move_replacement_index(pkmn, new_move_id)
      return nil unless pkmn && pkmn.respond_to?(:moves) && pkmn.moves
      cmds = pkmn.moves.map do |move|
        current_name = move ? (move.respond_to?(:name) ? move.name : move_display_name(move_identifier(move))) : "---"
        _INTL("Replace {1}", current_name)
      end
      cmds.push(_INTL("Cancel"))
      choice = Kernel.pbMessage(_INTL("Choose a move to forget for {1}:", move_display_name(new_move_id)), cmds, -1)
      return nil if choice < 0 || choice >= pkmn.moves.length
      choice
    rescue => e
      log_error("Choose Move Replacement", e)
      nil
    end

    def try_native_learn_move(pkmn, move_id)
      attempts = []
      if defined?(pbLearnMove)
        attempts.concat([
          proc { pbLearnMove(pkmn, move_id) },
          proc { pbLearnMove(pkmn, move_id, true) },
          proc { pbLearnMove(pkmn, move_id, false) },
          proc { pbLearnMove(pkmn, move_id, true, false) },
          proc { pbLearnMove(pkmn, move_id, false, true) }
        ])
      end
      if pkmn
        attempts.concat([
          proc { pkmn.learn_move(move_id) if pkmn.respond_to?(:learn_move) },
          proc { pkmn.learnMove(move_id) if pkmn.respond_to?(:learnMove) },
          proc { pkmn.pbLearnMove(move_id) if pkmn.respond_to?(:pbLearnMove) }
        ])
      end
      attempts.each do |attempt|
        begin
          result = attempt.call
          return true unless result.nil? || result == false
        rescue ArgumentError
          next
        rescue => e
          log_error("Native Learn Move", e)
        end
      end
      false
    end

    def teach_move_with_prompt!(pkmn, move_id)
      return false unless pkmn && move_id
      move_count = (pkmn.respond_to?(:moves) && pkmn.moves) ? pkmn.moves.length : 0
      if move_count < 4
        return :assigned if assign_move!(pkmn, move_count, move_id)
        return false
      end

      return :native if try_native_learn_move(pkmn, move_id)

      replace_index = choose_move_replacement_index(pkmn, move_id)
      return false if replace_index.nil?
      return :replaced if assign_move!(pkmn, replace_index, move_id)
      false
    rescue => e
      log_error("Teach Move With Prompt", e)
      false
    end

    def stat_editor_definitions
      [
        { :index => 0, :label => "HP",      :aliases => [:HP, :hp, :HITPOINTS, :hitpoints],             :readers => [:totalhp, :total_hp] },
        { :index => 1, :label => "Attack",  :aliases => [:ATTACK, :ATK, :attack, :atk],                 :readers => [:attack, :atk] },
        { :index => 2, :label => "Defense", :aliases => [:DEFENSE, :DEF, :defense, :def],               :readers => [:defense, :def] },
        { :index => 3, :label => "Sp. Atk", :aliases => [:SPECIAL_ATTACK, :SPATK, :SPAT, :spatk, :spat], :readers => [:spatk, :spatk, :sp_atk, :special_attack] },
        { :index => 4, :label => "Sp. Def", :aliases => [:SPECIAL_DEFENSE, :SPDEF, :SPDEFENSE, :spdef], :readers => [:spdef, :sp_def, :special_defense] },
        { :index => 5, :label => "Speed",   :aliases => [:SPEED, :SPD, :speed, :spd],                   :readers => [:speed, :spd] }
      ]
    end

    def pokemon_live_stat_value(pkmn, stat_def)
      return nil unless pkmn && stat_def
      stat_def[:readers].each do |reader|
        return pkmn.send(reader) if pkmn.respond_to?(reader)
      end
      nil
    rescue => e
      log_error("Pokemon Live Stat #{stat_def[:label]}", e)
      nil
    end

    def stat_collection_value(pkmn, collection_name)
      return nil unless pkmn && pkmn.respond_to?(collection_name)
      pkmn.send(collection_name)
    rescue => e
      log_error("Stat Collection #{collection_name}", e)
      nil
    end

    def resolve_stat_key(collection, stat_def)
      return nil if collection.nil? || stat_def.nil?
      return stat_def[:index] if collection.is_a?(Array)
      if collection.is_a?(Hash)
        preferred = stat_def[:aliases]
        preferred.each { |key| return key if collection.key?(key) }
        preferred_strings = preferred.map { |key| key.to_s.downcase }
        collection.keys.each do |key|
          return key if preferred_strings.include?(key.to_s.downcase)
        end
        return collection.keys[stat_def[:index]] if collection.keys.length > stat_def[:index]
      end
      nil
    rescue => e
      log_error("Resolve Stat Key #{stat_def[:label]}", e)
      nil
    end

    def get_individual_stat_value(pkmn, collection_name, stat_def)
      collection = stat_collection_value(pkmn, collection_name)
      return nil if collection.nil?
      key = resolve_stat_key(collection, stat_def)
      return nil if key.nil?
      collection[key]
    rescue => e
      log_error("Get Individual Stat #{collection_name} #{stat_def[:label]}", e)
      nil
    end

    def ensure_stat_collection!(pkmn, collection_name)
      collection = stat_collection_value(pkmn, collection_name)
      return collection unless collection.nil?
      writer = "#{collection_name}="
      return nil unless pkmn && pkmn.respond_to?(writer)
      pkmn.send(writer, [0, 0, 0, 0, 0, 0])
      stat_collection_value(pkmn, collection_name)
    rescue => e
      log_error("Ensure Stat Collection #{collection_name}", e)
      nil
    end

    def set_individual_stat_value!(pkmn, collection_name, stat_def, value)
      collection = ensure_stat_collection!(pkmn, collection_name)
      return false if collection.nil?
      key = resolve_stat_key(collection, stat_def)
      return false if key.nil?
      collection[key] = value.to_i
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Set Individual Stat #{collection_name} #{stat_def[:label]}", e)
      false
    end

    def pokemon_iv_value(pkmn, stat_def)
      get_individual_stat_value(pkmn, :iv, stat_def)
    end

    def pokemon_ev_value(pkmn, stat_def)
      get_individual_stat_value(pkmn, :ev, stat_def)
    end

    def set_pokemon_iv_value!(pkmn, stat_def, value)
      set_individual_stat_value!(pkmn, :iv, stat_def, value)
    end

    def set_pokemon_ev_value!(pkmn, stat_def, value)
      set_individual_stat_value!(pkmn, :ev, stat_def, value)
    end

    def advanced_stat_editor_lines(pkmn)
      stat_editor_definitions.map do |stat_def|
        iv = pokemon_iv_value(pkmn, stat_def)
        ev = pokemon_ev_value(pkmn, stat_def)
        live = pokemon_live_stat_value(pkmn, stat_def)
        _INTL("{1}: IV {2} | EV {3} | Stat {4}",
              stat_def[:label],
              iv.nil? ? "N/A" : iv,
              ev.nil? ? "N/A" : ev,
              live.nil? ? "N/A" : live)
      end
    rescue => e
      log_error("Advanced Stat Editor Lines", e)
      [_INTL("Could not read advanced stats.")]
    end

    def set_all_ivs!(pkmn, value)
      if pkmn.respond_to?(:iv) && pkmn.iv.is_a?(Hash)
        pkmn.iv.keys.each { |k| pkmn.iv[k] = value }
      elsif pkmn.respond_to?(:iv) && pkmn.iv.is_a?(Array)
        6.times { |i| pkmn.iv[i] = value }
      elsif pkmn.respond_to?(:iv=)
        pkmn.iv = [value, value, value, value, value, value]
      end
    rescue => e
      log_error("Set IVs", e)
    end

    def set_all_evs!(pkmn, value)
      if pkmn.respond_to?(:ev) && pkmn.ev.is_a?(Hash)
        pkmn.ev.keys.each { |k| pkmn.ev[k] = value }
      elsif pkmn.respond_to?(:ev) && pkmn.ev.is_a?(Array)
        6.times { |i| pkmn.ev[i] = value }
      elsif pkmn.respond_to?(:ev=)
        pkmn.ev = [value, value, value, value, value, value]
      end
    rescue => e
      log_error("Set EVs", e)
    end

    def bag_has_item?(item)
      return false unless defined?($PokemonBag) && $PokemonBag
      return $PokemonBag.pbHasItem?(item) if $PokemonBag.respond_to?(:pbHasItem?)
      false
    rescue => e
      log_error("Bag Has Item", e)
      false
    end

    def bag_store_item(item, qty = 1)
      return false unless defined?($PokemonBag) && $PokemonBag
      return $PokemonBag.pbStoreItem(item, qty) if $PokemonBag.respond_to?(:pbStoreItem)
      return $PokemonBag.pbStoreItem(item) if $PokemonBag.respond_to?(:pbStoreItem)
      return $PokemonBag.storeItem(item, qty) if $PokemonBag.respond_to?(:storeItem)
      return $PokemonBag.add(item, qty) if $PokemonBag.respond_to?(:add)
      false
    rescue => e
      log_error("Bag Store Item", e)
      false
    end

    def bag_delete_item(item, qty = 1)
      return false unless defined?($PokemonBag) && $PokemonBag
      return $PokemonBag.pbDeleteItem(item, qty) if $PokemonBag.respond_to?(:pbDeleteItem)
      return $PokemonBag.pbDeleteItem(item) if $PokemonBag.respond_to?(:pbDeleteItem)
      return $PokemonBag.deleteItem(item, qty) if $PokemonBag.respond_to?(:deleteItem)
      return $PokemonBag.remove(item, qty) if $PokemonBag.respond_to?(:remove)
      false
    rescue => e
      log_error("Bag Delete Item", e)
      false
    end

    def start_test_battle(pkmn, species_symbol, level)
      if cached_engine_profile[:has_modern_battle_api]
        begin
          return WildBattle.start(pkmn, level)
        rescue => e
          log_error("WildBattle.start object", e)
        end

        begin
          return WildBattle.start(species_symbol, level)
        rescue => e
          log_error("WildBattle.start species", e)
        end
      end

      if cached_engine_profile[:has_legacy_battle_api]
        begin
          return pbWildBattle(species_symbol, level)
        rescue => e
          log_error("pbWildBattle", e)
        end
      end

      nil
    end

    def clear_moves!(pkmn)
      if pkmn.respond_to?(:moves) && pkmn.moves
        if pkmn.moves.respond_to?(:clear)
          pkmn.moves.clear
        elsif pkmn.moves.respond_to?(:Clear)
          pkmn.moves.Clear
        else
          pkmn.moves = [] if pkmn.respond_to?(:moves=)
        end
      end
    end

    def forget_move!(pkmn, index)
      return false unless pkmn && pkmn.respond_to?(:moves) && pkmn.moves
      return false if index.nil? || index < 0
      if pkmn.moves.respond_to?(:delete_at)
        !!pkmn.moves.delete_at(index)
      elsif pkmn.moves.respond_to?(:DeleteAt)
        !!pkmn.moves.DeleteAt(index)
      else
        false
      end
    rescue => e
      log_error("Forget Move", e)
      false
    end

    def reset_pokemon_moves!(pkmn)
      return false unless pkmn
      pkmn.reset_moves if pkmn.respond_to?(:reset_moves)
      pkmn.resetMoves if pkmn.respond_to?(:resetMoves)
      true
    rescue => e
      log_error("Reset Moveset", e)
      false
    end

    def record_pokemon_initial_moves!(pkmn)
      return false unless pkmn
      pkmn.record_first_moves if pkmn.respond_to?(:record_first_moves)
      true
    rescue => e
      log_error("Record Initial Moves", e)
      false
    end

    def restore_pokemon_pp!(pkmn)
      return false unless pkmn
      pkmn.heal_PP if pkmn.respond_to?(:heal_PP)
      pkmn.healPP if pkmn.respond_to?(:healPP)
      true
    rescue => e
      log_error("Restore PP", e)
      false
    end

    def max_pokemon_ppups!(pkmn, value = 3)
      return false unless pkmn
      each_move_slot(pkmn) do |move, _index|
        move.ppup = value if move && move.respond_to?(:ppup=)
      end
      true
    rescue => e
      log_error("Max PP Ups", e)
      false
    end

    def duplicate_pokemon(pkmn)
      clone = try_call("Duplicate Pokemon Clone") { pkmn.clone }
      clone = try_call("Duplicate Pokemon Dup") { pkmn.dup } if clone.nil?
      clone
    rescue => e
      log_error("Duplicate Pokemon", e)
      nil
    end

    def extract_pokemon_preset(pkmn)
      return nil unless pkmn
      preset = {}
      preset[:species] = pkmn.species if pkmn.respond_to?(:species)
      preset[:level] = pkmn.level if pkmn.respond_to?(:level)
      preset[:form] = pkmn.form if pkmn.respond_to?(:form)
      preset[:nickname] = pkmn.name if pkmn.respond_to?(:name)
      preset[:item] = pkmn.item if pkmn.respond_to?(:item)
      preset[:nature] = pkmn.nature if pkmn.respond_to?(:nature)
      preset[:ability] = pkmn.ability if pkmn.respond_to?(:ability)
      preset[:ability_index] = pkmn.ability_index if pkmn.respond_to?(:ability_index)
      preset[:gender] = pkmn.gender if pkmn.respond_to?(:gender)
      preset[:shiny] = pkmn.respond_to?(:shiny?) ? pkmn.shiny? : (pkmn.respond_to?(:shiny) ? pkmn.shiny : false)
      preset[:ot_name] = pokemon_ot_name(pkmn)
      preset[:moves] = []
      each_move_slot(pkmn) do |move, _index|
        move_id = move_identifier(move)
        preset[:moves] << move_id if move_id
      end
      preset
    rescue => e
      log_error("Extract Pokemon Preset", e)
      nil
    end

    def export_pokemon_preset(pkmn, path = nil)
      path ||= preset_file_path
      preset = extract_pokemon_preset(pkmn)
      return false unless preset
      File.open(path, "wb") { |f| Marshal.dump(preset, f) }
      true
    rescue => e
      log_error("Export Pokemon Preset", e)
      false
    end

    def import_pokemon_preset(path = nil)
      path ||= preset_file_path
      return nil unless File.exist?(path)
      File.open(path, "rb") { |f| Marshal.load(f) }
    rescue => e
      log_error("Import Pokemon Preset", e)
      nil
    end

    def apply_pokemon_preset!(pkmn, preset)
      return false unless pkmn && preset.is_a?(Hash)
      set_pokemon_species!(pkmn, preset[:species]) if preset.key?(:species)
      set_pokemon_level!(pkmn, preset[:level]) if preset.key?(:level)
      set_pokemon_form!(pkmn, preset[:form]) if preset.key?(:form)
      set_pokemon_nickname!(pkmn, preset[:nickname]) if preset[:nickname] && preset[:nickname] != ""
      set_pokemon_item!(pkmn, preset[:item]) if preset.key?(:item)
      set_pokemon_nature!(pkmn, preset[:nature]) if preset[:nature]
      set_pokemon_ability!(pkmn, preset[:ability], preset[:ability_index]) if preset[:ability]
      if preset.key?(:gender)
        gender_target = case preset[:gender]
        when 0 then :male
        when 1 then :female
        when 2 then :genderless
        else nil
        end
        set_pokemon_gender!(pkmn, gender_target) if gender_target
      end
      set_pokemon_shiny!(pkmn, preset[:shiny]) if preset.key?(:shiny)
      set_pokemon_ot_name!(pkmn, preset[:ot_name]) if preset[:ot_name] && preset[:ot_name] != ""
      if preset[:moves].is_a?(Array) && !preset[:moves].empty?
        clear_moves!(pkmn)
        preset[:moves].first(4).each_with_index do |move_id, index|
          assign_move!(pkmn, index, move_id)
        end
      end
      recalc_pokemon_stats(pkmn)
      true
    rescue => e
      log_error("Apply Pokemon Preset", e)
      false
    end

    def create_pokemon_from_preset(preset)
      return nil unless preset.is_a?(Hash) && preset[:species]
      pkmn = create_pkmn(preset[:species], preset[:level] || 1)
      return nil unless pkmn
      apply_pokemon_preset!(pkmn, preset)
      pkmn
    rescue => e
      log_error("Create Pokemon From Preset", e)
      nil
    end

    def assign_move!(pkmn, index, move_symbol)
      return false unless pkmn.respond_to?(:moves) && pkmn.moves
      move_object = nil
      if defined?(PBMove)
        move_object = try_call("Create Legacy Move") { PBMove.new(move_symbol) }
      end
      if !move_object && defined?(Pokemon) && safe_const_get(Pokemon, :Move)
        move_object = try_call("Create Modern Move") { Pokemon::Move.new(move_symbol) }
      end
      return false unless move_object

      if pkmn.moves.respond_to?(:[]=)
        pkmn.moves[index] = move_object
      elsif pkmn.moves.respond_to?(:push)
        pkmn.moves.push(move_object)
      else
        return false
      end
      true
    end

    def storage_available?
      defined?($PokemonStorage) && $PokemonStorage
    end

    def storage_box_full?(box)
      return false unless storage_available?
      current_box = try_call("Storage Box Lookup") { $PokemonStorage[box] }
      return current_box.full? if current_box && current_box.respond_to?(:full?)
      max = storage_max_pokemon(box)
      max = 30 if max <= 0
      filled = 0
      max.times do |i|
        filled += 1 if current_box && current_box[i]
      end
      filled >= max
    end

    def set_storage_slot(box, index, pkmn)
      current_box = try_call("Storage Slot Lookup") { $PokemonStorage[box] }
      return false unless current_box
      if current_box.respond_to?(:[]=)
        current_box[index] = pkmn
        return true
      end
      if current_box.respond_to?(:set)
        current_box.set(index, pkmn)
        return true
      end
      false
    rescue => e
      log_error("Storage Write", e)
      false
    end

    def each_storage_index
      return enum_for(:each_storage_index) unless block_given?
      return unless storage_available?
      max_boxes = storage_max_boxes
      max_boxes.times do |box|
        max_slots = storage_max_pokemon(box)
        max_slots.times do |slot|
          yield box, slot
        end
      end
    end

    def set_ball_data!(pkmn, item_id)
      sym = get_symbol(:Item, item_id)
      pkmn.poke_ball = sym if pkmn.respond_to?(:poke_ball=)
      pkmn.ballused = item_id if pkmn.respond_to?(:ballused=)
      pkmn.ball_used = sym if pkmn.respond_to?(:ball_used=)
    end

    def choose_poke_ball_id
      hash = build_search_hash(:Item) do |item|
        item.is_poke_ball? rescue false
      end
      hash = build_search_hash(:Item) if hash.empty?
      search_list("Poke Balls", hash)
    end

    def search_direct_id(hash, term)
      normalized = term.to_s.strip.downcase
      match = normalized.match(/^(?:id:|#)?(\d+)$/)
      return nil unless match
      key = match[1].to_i
      hash[key] ? key : nil
    end

    def search_matches_entry?(key, value, term)
      return true if term == ""
      normalized = term.downcase
      exact = false
      if normalized.start_with?("=")
        exact = true
        normalized = normalized[1..-1].to_s.strip
      end
      haystack = "#{key} #{value}".downcase
      return value.downcase == normalized if exact
      normalized.split(/\s+/).all? { |token| haystack.include?(token) }
    end

    def current_map_events
      return [] unless defined?($game_map) && $game_map && $game_map.respond_to?(:events) && $game_map.events
      events = $game_map.events
      list = events.respond_to?(:values) ? events.values : events
      Array(list).compact.sort_by { |event| event.id rescue 0 }
    rescue => e
      log_error("Current Map Events", e)
      []
    end

    def event_display_name(event)
      return "Unknown Event" unless event
      event_name = event.respond_to?(:name) ? event.name.to_s : ""
      event_name = "Event #{event.id}" if event_name.strip == ""
      "#{event_name} [#{event.id}]"
    rescue => e
      log_error("Event Display Name", e)
      "Unknown Event"
    end

    def choose_current_map_event
      events = current_map_events
      return nil if events.empty?
      cmds = events.map { |event| event_display_name(event) }
      cmds.push("Cancel")
      choice = Kernel.pbMessage(_INTL("Choose event:"), cmds, -1)
      return nil if choice < 0 || choice >= events.length
      events[choice]
    end

    def teleport_to_event(event)
      return false unless event && defined?($game_player) && $game_player
      x = event.respond_to?(:x) ? event.x : nil
      y = event.respond_to?(:y) ? event.y : nil
      return false if x.nil? || y.nil?
      $game_player.moveto(x, y) if $game_player.respond_to?(:moveto)
      $game_player.center(x, y) if $game_player.respond_to?(:center)
      true
    rescue => e
      log_error("Teleport To Event", e)
      false
    end

    def refresh_event(event)
      return false unless event
      event.refresh if event.respond_to?(:refresh)
      true
    rescue => e
      log_error("Refresh Event", e)
      false
    end

    def export_current_map_events
      events = current_map_events
      return false if events.empty?
      File.open("PokeDebug_Current_Map_Events.txt", "w") do |f|
        events.each do |event|
          x = event.respond_to?(:x) ? event.x : "?"
          y = event.respond_to?(:y) ? event.y : "?"
          f.puts("#{event_display_name(event)} @ (#{x}, #{y})")
        end
      end
      true
    rescue => e
      log_error("Export Map Events", e)
      false
    end

    def start_test_trainer_battle(trainer_type, trainer_name, version = 0)
      if defined?(TrainerBattle) && TrainerBattle.respond_to?(:start)
        begin
          return TrainerBattle.start(trainer_type, trainer_name, version)
        rescue => e
          log_error("TrainerBattle.start v1", e)
        end

        begin
          return TrainerBattle.start(trainer_type, trainer_name)
        rescue => e
          log_error("TrainerBattle.start v2", e)
        end
      end

      if defined?(pbTrainerBattle)
        attempts = [
          [trainer_type, trainer_name, nil, false, version],
          [trainer_type, trainer_name, nil, false],
          [trainer_type, trainer_name],
          [trainer_type, trainer_name, nil, false, version, false],
          [trainer_type, trainer_name, version],
          [trainer_type, trainer_name, version, false]
        ]
        attempts.each_with_index do |args, idx|
          begin
            return pbTrainerBattle(*args)
          rescue => e
            log_error("pbTrainerBattle attempt #{idx + 1}", e)
          end
        end
      end
      nil
    end

    def on_input_update
      return if @processing_hotkey
      @processing_hotkey = true
      begin
        safe_execute("Input Update") do
          if menu_triggered?
            pbPlayDecisionSE if defined?(pbPlayDecisionSE)
            @mobile_combo_hold_frames = 0
            show_menu
          end
          if trigger_hotkey?(WTW_HOTKEY.to_sym, WTW_HOTKEY)
            toggle_wtw
          end
          if trigger_hotkey?(HEAL_HOTKEY.to_sym, HEAL_HOTKEY)
            heal_party
          end
        end
      ensure
        @processing_hotkey = false
      end
    end

    def on_map_update
      if @walk_through_walls && $game_player
        $game_player.through = true
      end
    end

    def toggle_wtw
      @walk_through_walls = !@walk_through_walls
      if $game_player
        $game_player.through = @walk_through_walls
      end
      state = @walk_through_walls ? "Walk Through Walls ENABLED" : "Walk Through Walls DISABLED"
      Kernel.pbMessage(_INTL("{1}", "#{state} (#{WTW_HOTKEY})"))
    end

    def get_player
      return $Player if defined?($Player)
      return $player if defined?($player)
      return $Trainer.player if defined?($Trainer) && $Trainer.respond_to?(:player)
      return $Trainer
    end

    def heal_party
      player_party.each do |pkmn|
        next if !pkmn || (pkmn.respond_to?(:egg?) && pkmn.egg?) || (pkmn.respond_to?(:isEgg?) && pkmn.isEgg?)
        heal_pokemon!(pkmn)
      end
      Kernel.pbMessage(_INTL("{1}", "Party fully healed!"))
    end

    def create_pkmn(sp_sym_or_id, level)
      if modern_engine? && defined?(Pokemon) && Pokemon.respond_to?(:new)
        begin
          return Pokemon.new(sp_sym_or_id, level)
        rescue ArgumentError
          return Pokemon.new(sp_sym_or_id, level, get_player)
        end
      elsif defined?(PokeBattle_Pokemon)
        begin
          return PokeBattle_Pokemon.new(sp_sym_or_id, level, get_player)
        rescue ArgumentError
          return PokeBattle_Pokemon.new(sp_sym_or_id, level)
        end
      end
      nil
    rescue => e
      log_error("Create Pokemon", e)
      nil
    end

    def add_pkmn_silently(pkmn)
      party = player_party
      if party.length < 6
        party.push(pkmn)
      else
        storage_store_caught(pkmn)
      end
    end

    def get_symbol(type, id_or_index)
      collection = cache_collection(type)
      if collection && collection.respond_to?(:keys)
        keys = collection.keys
        return keys[id_or_index - 1] if id_or_index > 0 && id_or_index <= keys.size
      end

      klass = game_data_class(type)
      if klass
        idx = 0
        klass.each do |data|
          idx += 1
          return data.id if idx == id_or_index
        end
      end
      return id_or_index 
    end

    def build_search_hash(type, filter_block = nil)
      hash = {}
      
      collection = cache_collection(type)
      if collection && collection.respond_to?(:each)
        idx = 0
        collection.each do |k, v|
          next if filter_block && !filter_block.call(v || k)
          idx += 1
          hash[idx] = safe_display_name(v, k)
        end
        return hash unless hash.empty?
      end

      klass = game_data_class(type)
      if klass
        idx = 0
        klass.each do |item|
          next if filter_block && !filter_block.call(item)
          idx += 1
          hash[idx] = item.name
        end
      else
        pb_mod = legacy_pb_module(type)
        if pb_mod
          pb_mod.constants.each do |c|
            next if c.to_s.empty? || c == :MAX_LEVEL
            val = pb_mod.const_get(c)
            next if val <= 0
            name = legacy_constant_display_name(type, c, val)
            next if filter_block && !filter_block.call(val)
            hash[val] = name
          end
        end
      end
      hash
    end

    def dump_ids(type, filename)
      hash = build_search_hash(type)
      File.open(filename, "w") do |f|
        hash.sort.each { |k, v| f.puts(sprintf("%03d: %s", k, v)) }
      end
      Kernel.pbMessage(_INTL("Exported {1} items to {2} in game root folder.", hash.size, filename))
    end

    def get_map_infos
      @map_infos ||= safe_load_data("Data/MapInfos.rxdata")
    end

    def get_system_data
      @system_data ||= safe_load_data("Data/System.rxdata")
    end

    def search_list(title, hash)
      if hash.empty?
        Kernel.pbMessage(_INTL("No {1} found in game data.", title))
        return nil
      end
      loop do
        term = Kernel.pbMessageFreeText(_INTL("Search {1} (blank/ID/=Exact):", title), "", false, 256)
        direct_id = search_direct_id(hash, term)
        return direct_id if direct_id

        matches = []; keys = []
        hash.each do |k, v|
          next unless search_matches_entry?(k, v, term.to_s.strip)
          matches.push(sprintf("%03d: %s", k, v))
          keys.push(k)
        end
        if matches.empty?
          if Kernel.pbConfirmMessage(_INTL("No results found. Search again?"))
            next
          else
            return nil
          end
        end
        matches.push("Cancel")
        ch = Kernel.pbMessage(_INTL("Select:"), matches, -1)
        return keys[ch] if ch >= 0 && ch < keys.length
        return nil if ch == keys.length 
      end
    end

    def render_dynamic_menu(title, menu_array)
      loop do
        options = menu_array.map { |item| item[:label] }
        options.push(t(TR[:back]))
        
        choice = Kernel.pbMessage(_INTL(title), options, -1)
        break if choice < 0 || choice == options.length - 1
        
        safe_execute(menu_array[choice][:label]) do
          menu_array[choice][:action].call
        end
      end
    end

    def show_menu
      return if @menu_open
      @menu_open = true
      
      main_menu = [
        { :label => t(TR[:engine]).upcase, :action => proc { menu_engine } },
        { :label => t(TR[:pokemon]).upcase, :action => proc { menu_pokemon } },
        { :label => t(TR[:items]).upcase, :action => proc { menu_item } },
        { :label => t(TR[:Player]).upcase, :action => proc { menu_player } },
        { :label => t(TR[:party]).upcase, :action => proc { menu_party } },
        { :label => t(TR[:extras]).upcase, :action => proc { menu_extras } }
      ]
      
      render_dynamic_menu(t(TR[:dev_menu]) + " (Kzuran)", main_menu)
      @menu_open = false
    end

    def open_menu_external
      pbPlayDecisionSE if defined?(pbPlayDecisionSE)
      show_menu
      true
    rescue => e
      log_error("External Menu Open", e)
      false
    end

    def menu_extras
      menu = [
        { :label => "Quick Actions", :action => proc {
          run_quick_actions_menu
        }},
        { :label => "Configure Quick Actions", :action => proc {
          configure_quick_actions
        }},
        { :label => t(TR[:nobattles]), :action => proc {
          @no_battles = !@no_battles
          Kernel.pbMessage(_INTL("No Battles: {1}", @no_battles ? "ON" : "OFF"))
        }},
        { :label => t(TR[:infmega]), :action => proc {
          @inf_mega = !@inf_mega
          Kernel.pbMessage(_INTL("Infinite Mega: {1}", @inf_mega ? "ON" : "OFF"))
        }},
        { :label => "Engine Compatibility Report", :action => proc {
          show_engine_report
        }},
        { :label => "Show JoiPlay/Mobile Open Help", :action => proc {
          show_joiplay_help
        }},
        { :label => "Open Native Pokemon Editor", :action => proc {
          open_native_pokemon_editor_for_party
        }},
        { :label => "Open Native Debug Menu", :action => proc {
          @menu_open = false
          unless open_native_debug_menu
            Kernel.pbMessage(_INTL("Native Debug Menu was removed by the game developer."))
          end
          @menu_open = true
        }}
      ]
      render_dynamic_menu(t(TR[:extras]).upcase, menu)
    end

    def show_joiplay_help
      Kernel.pbMessage(_INTL("{1}",
        "JoiPlay/mobile fallback:\n" \
        "- Hold A + B + C for a moment\n" \
        "- Or press L + R / AUX1 + AUX2 if mapped\n" \
        "- Event/script call: pbPokeDebugMenu"
      ))
    rescue => e
      log_error("JoiPlay Help", e)
    end
# --- END 10_core.rb ---

# --- BEGIN 20_engine.rb ---
    def menu_engine
      menu = [
        { :label => "Quick Status", :action => proc { show_engine_status } },
        { :label => t(TR[:warp]), :action => proc { engine_warp } },
        { :label => t(TR[:switches]), :action => proc { engine_switches } },
        { :label => t(TR[:vars]), :action => proc { engine_variables } }
      ]
      
      in_safari = false
      if defined?(pbInSafari?)
        in_safari = pbInSafari?
      elsif $PokemonGlobal && $PokemonGlobal.respond_to?(:safariState) && $PokemonGlobal.safariState
        begin
          in_safari = $PokemonGlobal.safariState.inProgress?
        rescue => e
          log_error("Safari State", e)
          in_safari = false
        end
      end
      
      in_bug = false
      if defined?(pbInBugContest?)
        in_bug = pbInBugContest?
      end
      
      if in_safari || in_bug
        menu.push({ :label => t(TR[:safari]), :action => proc { engine_safari } })
      end

      menu.concat([
        { :label => t(TR[:Field]), :action => proc { engine_field_effects } },
        { :label => "Map / Event Tools", :action => proc { engine_map_events } },
        { :label => t(TR[:refresh]), :action => proc { engine_refresh_map } },
        { :label => t(TR[:daycare]), :action => proc { engine_day_care } },
        { :label => t(TR[:Wallpapers]), :action => proc { engine_wallpapers } },
        { :label => t(TR[:Battle]), :action => proc { engine_test_battle } },
        { :label => "Test Trainer Battle", :action => proc { engine_test_trainer_battle } },
        { :label => t(TR[:expall]), :action => proc { engine_exp_all } },
        { :label => t(TR[:wtw]), :action => proc { toggle_wtw } },
        { :label => t(TR[:openpc]), :action => proc { open_pc_menu } }
      ])
      render_dynamic_menu(_INTL("{1} | {2}", t(TR[:engine]).upcase, cached_engine_profile[:modern_engine] ? "Modern/Hybrid" : "Legacy"), menu)
    end

    def engine_warp
      mapinfos = get_map_infos
      return Kernel.pbMessage(_INTL("MapInfos.rxdata not found!")) unless mapinfos
      
      hash = {}
      mapinfos.keys.sort.each { |id| hash[id] = mapinfos[id].name }
      map_id = search_list("Maps", hash)
      return if !map_id || map_id <= 0

      # Show Preview if modern
      preview = nil
      if defined?(GameData)
        begin
          path = sprintf("Graphics/Pictures/mapPreview_%03d", map_id)
          if pbResolveBitmap(path)
            preview = Sprite.new
            preview.bitmap = Bitmap.new(path)
            preview.z = 99999
            Kernel.pbMessage(_INTL("Previewing Map {1}. Proceed?", map_id))
            preview.dispose
          end
        rescue => e
          log_error("Map Preview", e)
          preview.dispose if preview
        end
      end

      map_data = safe_load_data(sprintf("Data/Map%03d.rxdata", map_id))
      x = 10; y = 10
      if map_data
        found = false
        if defined?($MapFactory)
          temp_map = safe_map_factory_map(map_id)
          if temp_map
            200.times do
              rx = rand(map_data.width)
              ry = rand(map_data.height)
              if temp_map.passable?(rx, ry, 2)
                x = rx; y = ry; found = true
                break
              end
            end
          end
        end
        if !found
          x = map_data.width / 2; y = map_data.height / 2 
        end
      end
      cancel_vehicles_if_possible
      pbFadeOutIn(99999) {
        $game_temp.player_new_map_id = map_id
        $game_temp.player_new_x = x
        $game_temp.player_new_y = y
        $game_temp.player_new_direction = 2
        $scene.transfer_player if $scene.respond_to?(:transfer_player)
      }
    end

    def engine_switches
      sys = get_system_data
      return unless sys
      hash = {}
      sys.switches.each_with_index { |name, i| hash[i] = name if name && name != "" }
      id = search_list("Switches", hash)
      return if !id || id <= 0
      current = $game_switches[id]
      ch = Kernel.pbMessage(_INTL("Switch {1} ({2}): {3}", id, hash[id], current ? "ON" : "OFF"), ["ON", "OFF", "Cancel"], -1)
      $game_switches[id] = (ch == 0) if ch >= 0 && ch < 2
      $game_map.need_refresh = true if $game_map
    end

    def engine_variables
      sys = get_system_data
      return unless sys
      hash = {}
      sys.variables.each_with_index { |name, i| hash[i] = name if name && name != "" }
      id = search_list("Variables", hash)
      return if !id || id <= 0
      current = $game_variables[id] || 0
      params = ChooseNumberParams.new
      params.setRange(-999999, 999999); params.setInitialValue(current)
      $game_variables[id] = Kernel.pbMessageChooseNumber(_INTL("Var {1} ({2}) = {3}. New:", id, hash[id], current), params)
      $game_map.need_refresh = true if $game_map
    end

    def engine_safari
      menu = [
        { :label => "Edit Steps", :action => proc { 
          params = ChooseNumberParams.new; params.setRange(0, 9999); params.setInitialValue($PokemonGlobal.safariSteps || 0)
          $PokemonGlobal.safariSteps = Kernel.pbMessageChooseNumber(_INTL("Steps:"), params) if $PokemonGlobal.respond_to?(:safariSteps=)
        }},
        { :label => "Edit Safari Balls", :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 99); params.setInitialValue($PokemonGlobal.safariBalls || 0)
          $PokemonGlobal.safariBalls = Kernel.pbMessageChooseNumber(_INTL("Safari Balls:"), params) if $PokemonGlobal.respond_to?(:safariBalls=)
        }},
        { :label => "Edit Contest Balls", :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 99); params.setInitialValue($PokemonGlobal.bugContestBalls || 0)
          $PokemonGlobal.bugContestBalls = Kernel.pbMessageChooseNumber(_INTL("Contest Balls:"), params) if $PokemonGlobal.respond_to?(:bugContestBalls=)
        }}
      ]
      render_dynamic_menu("Edit Safari/Contest", menu)
    end

    def engine_field_effects
      menu = [
        { :label => "Repel Steps", :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 99999); params.setInitialValue(get_repel_steps || 0)
          set_repel_steps(Kernel.pbMessageChooseNumber(_INTL("Repel Steps:"), params))
        }},
        { :label => "Toggle flash", :action => proc {
          $PokemonGlobal.flashUsed = !$PokemonGlobal.flashUsed if $PokemonGlobal.respond_to?(:flashUsed=)
          Kernel.pbMessage(_INTL("Flash: {1}", on_off_text($PokemonGlobal.flashUsed)))
        }},
        { :label => "Toggle Strength", :action => proc {
          if $PokemonMap.respond_to?(:strengthUsed=)
            $PokemonMap.strengthUsed = !$PokemonMap.strengthUsed
            Kernel.pbMessage(_INTL("Strength: {1}", $PokemonMap.strengthUsed ? "ON" : "OFF"))
          end
        }},
        { :label => "Toggle Black Flute", :action => proc {
          current = get_map_toggle(:blackFluteUsed, :blackFauteUsed)
          if !current.nil? && set_map_toggle(!current, :blackFluteUsed, :blackFauteUsed)
            Kernel.pbMessage(_INTL("Black Flute: {1}", get_map_toggle(:blackFluteUsed, :blackFauteUsed) ? "ON" : "OFF"))
          else
            Kernel.pbMessage(_INTL("Black Flute not supported on this version."))
          end
        }},
        { :label => "Toggle White Flute", :action => proc {
          current = get_map_toggle(:whiteFluteUsed, :whiteFauteUsed)
          if !current.nil? && set_map_toggle(!current, :whiteFluteUsed, :whiteFauteUsed)
            Kernel.pbMessage(_INTL("White Flute: {1}", get_map_toggle(:whiteFluteUsed, :whiteFauteUsed) ? "ON" : "OFF"))
          else
            Kernel.pbMessage(_INTL("White Flute not supported on this version."))
          end
        }}
      ]
      render_dynamic_menu("Field Effects", menu)
    end

    def engine_refresh_map
      $game_map.need_refresh = true
      if $game_map.events
        $game_map.events.values.each do |e|
          e.refresh if e.respond_to?(:refresh)
        end
      end
      safe_set_map_changed($game_map.map_id) if $game_map
      Kernel.pbMessage(_INTL("Map refreshed and events re-evaluated!"))
    end

    def engine_map_events
      menu = [
        { :label => "Map Summary", :action => proc {
          show_current_map_summary
        }},
        { :label => "List Current Map Events", :action => proc {
          if export_current_map_events
            Kernel.pbMessage(_INTL("Exported event list to PokeDebug_Current_Map_Events.txt"))
          else
            Kernel.pbMessage(_INTL("No events found on the current map."))
          end
        }},
        { :label => "Teleport To Event", :action => proc {
          event = choose_current_map_event
          if event && teleport_to_event(event)
            Kernel.pbMessage(_INTL("Teleported to {1}.", event_display_name(event)))
          elsif event
            Kernel.pbMessage(_INTL("Could not teleport to that event."))
          end
        }},
        { :label => "Refresh Event", :action => proc {
          event = choose_current_map_event
          if event && refresh_event(event)
            Kernel.pbMessage(_INTL("Event refreshed: {1}.", event_display_name(event)))
          elsif event
            Kernel.pbMessage(_INTL("Could not refresh that event."))
          end
        }}
      ]
      render_dynamic_menu("Map / Event Tools", menu)
    end

    def engine_day_care
      dc = get_day_care_data
      
      status = "Day Care: "
      if dc
        first_pokemon = day_care_first_pokemon(dc)
        if first_pokemon
          status += "#{pokemon_species_name(first_pokemon)} (Lv#{pokemon_level_value(first_pokemon)})"
        else
          status += "Empty"
        end
      else
        status = "Day Care (N/A)"
      end

      menu = [
        { :label => "Deposit Pokemon", :action => proc {
          choose_pokemon_with_callback do |pkmn|
            if day_care_deposit_first(pkmn, dc)
              remove_party_member(pkmn)
              Kernel.pbMessage(_INTL("Deposited {1}.", pkmn.name))
            else
              Kernel.pbMessage(_INTL("Day care data not found!"))
            end
          end
        }},
        { :label => "Force Egg", :action => proc {
          if day_care_force_egg(dc)
            Kernel.pbMessage(_INTL("Day care egg forced successfully."))
          else
            Kernel.pbMessage(_INTL("Day care data not found!"))
          end
        }},
        { :label => "Withdraw First Deposited", :action => proc {
          pkmn = day_care_withdraw_first(dc)
          if pkmn
            add_pkmn_silently(pkmn)
            Kernel.pbMessage(_INTL("Withdrew {1}.", pkmn.name))
          else
            Kernel.pbMessage(_INTL("No Pokemon in first slot."))
          end
        }}
      ]
      render_dynamic_menu(status, menu)
    end

    def engine_wallpapers
      menu = [
        { :label => "Unlock All", :action => proc {
          $PokemonStorage.allWallpapersUnlocked = true if $PokemonStorage && $PokemonStorage.respond_to?(:allWallpapersUnlocked=)
          Kernel.pbMessage(_INTL("All PC wallpapers unlocked."))
        }},
        { :label => "Lock All", :action => proc {
          $PokemonStorage.allWallpapersUnlocked = false if $PokemonStorage && $PokemonStorage.respond_to?(:allWallpapersUnlocked=)
          Kernel.pbMessage(_INTL("All PC wallpapers locked."))
        }}
      ]
      render_dynamic_menu("Wallpapers", menu)
    end

    def engine_test_battle
      hash = build_search_hash(:Species)
      species_id = search_list("Species", hash)
      return if !species_id || species_id <= 0
      sp_sym = get_symbol(:Species, species_id)
      
      params = ChooseNumberParams.new
      params.setRange(1, 100); params.setInitialValue(50)
      level = Kernel.pbMessageChooseNumber(_INTL("Level:"), params)
      
      params.setRange(0, 50); params.setInitialValue(0)
      form = Kernel.pbMessageChooseNumber(_INTL("Form ID:"), params)
      
      pkmn = create_pkmn(sp_sym, level)
      return Kernel.pbMessage(_INTL("Could not create Pokemon for this engine.")) unless pkmn
      pkmn.form = form if pkmn.respond_to?(:form=) && form > 0
      recalc_pokemon_stats(pkmn) if pkmn
      
      if Kernel.pbMessage("Make Shiny?", ["Yes", "No"], -1) == 0
        pkmn.shiny = true if pkmn.respond_to?(:shiny=)
        pkmn.makeShiny if pkmn.respond_to?(:makeShiny)
      end
      
      if Kernel.pbMessage("Custom Moveset?", ["Yes", "No"], -1) == 0
        clear_moves!(pkmn)
        4.times do |i|
          break if Kernel.pbMessage("Add a move for slot #{i+1}?", ["Yes", "No"], -1) != 0
          mhash = build_search_hash(:Move)
          mid = search_list("Moves", mhash)
          if mid
            msym = get_symbol(:Move, mid)
            assign_move!(pkmn, i, msym)
          end
        end
      end
      
      result = start_test_battle(pkmn, sp_sym, level)
      if result.nil?
        Kernel.pbMessage(_INTL("Battle failed. API mismatch."))
      else
        Kernel.pbMessage(_INTL("Battle started successfully."))
      end
    end

    def engine_test_trainer_battle
      hash = build_search_hash(:TrainerType)
      return Kernel.pbMessage(_INTL("Trainer battle API not supported on this version.")) if hash.empty?
      trainer_type_id = search_list("Trainer Types", hash)
      return if !trainer_type_id || trainer_type_id <= 0
      trainer_type = get_symbol(:TrainerType, trainer_type_id)
      trainer_name = Kernel.pbMessageFreeText(_INTL("Trainer name:"), "TRAINER", false, 32)
      return if trainer_name.nil? || trainer_name == ""

      params = ChooseNumberParams.new
      params.setRange(0, 99)
      params.setInitialValue(0)
      version = Kernel.pbMessageChooseNumber(_INTL("Trainer party/version ID:"), params)

      result = start_test_trainer_battle(trainer_type, trainer_name, version)
      if result.nil?
        Kernel.pbMessage(_INTL("Trainer battle failed. API mismatch."))
      else
        Kernel.pbMessage(_INTL("Trainer battle started successfully."))
      end
    end

    def engine_exp_all
      if $PokemonGlobal.respond_to?(:exp_all)
        $PokemonGlobal.exp_all = !$PokemonGlobal.exp_all
        Kernel.pbMessage(_INTL("Global Exp All flag: {1}", $PokemonGlobal.exp_all ? "ON" : "OFF"))
        return
      end
      
      has_item = bag_has_item?(:EXPALL)
      if has_item
        bag_delete_item(:EXPALL)
      else
        stored = bag_store_item(:EXPALL)
        unless stored
          expall_id = build_search_hash(:Item).key("EXPALL")
          bag_store_item(get_symbol(:Item, expall_id)) if expall_id
        end
      end
      Kernel.pbMessage(_INTL("Exp All Item: {1}", has_item ? "REMOVED" : "ADDED"))
    end
# --- END 20_engine.rb ---

# --- BEGIN 30_pokemon_items_player.rb ---
    def menu_pokemon
      menu = [
        { :label => "Quick Status", :action => proc { show_pokemon_menu_status } },
        { :label => t(TR[:FillPC]), :action => proc { pokemon_fill_storage } },
        { :label => t(TR[:ClearPC]), :action => proc { pokemon_clear_storage } },
        { :label => t(TR[:addboxes]), :action => proc { pokemon_expand_boxes } },
        { :label => t(TR[:quickhatch]), :action => proc { pokemon_quick_hatch } },
        { :label => t(TR[:addpkmn]), :action => proc { pokemon_add } },
        { :label => "Import Pokemon Preset", :action => proc { pokemon_import_preset } },
        { :label => "Open Native Pokemon Editor", :action => proc { open_native_pokemon_editor_for_party } },
        { :label => t(TR[:Heal]), :action => proc { heal_party } },
        { :label => t(TR[:exportids]), :action => proc { dump_ids(:Species, "Pokemon_ID_List.txt") } }
      ]
      render_dynamic_menu(_INTL("{1} | Party {2}/6", t(TR[:pokemon]).upcase, player_party.length), menu)
    end

    def pokemon_fill_storage
      return unless storage_available?
      return unless Kernel.pbConfirmMessage(_INTL("Fill ALL boxes with level 50 Pokemon (all detected forms)?"))
      box = 0; idx = 0
      hash = build_search_hash(:Species)
      
      Kernel.pbMessage(_INTL("Generating... This may take a while."))
      
      hash.each do |k, v|
        sp_sym = get_symbol(:Species, k)
        forms = species_forms(sp_sym)
        
        forms.each do |f|
          pkmn = create_pkmn(sp_sym, 50)
          next unless pkmn
          pkmn.form = f if pkmn.respond_to?(:form=)
          
          while storage_box_full?(box)
            box += 1
            break if box >= storage_max_boxes
          end
          break if box >= storage_max_boxes
          
          break unless set_storage_slot(box, idx, pkmn)
          idx += 1
          if idx >= storage_max_pokemon(box)
            idx = 0; box += 1
          end
        end
        break if box >= storage_max_boxes
      end
      Kernel.pbMessage(_INTL("Filled up to box {1}!", box))
    end

    def pokemon_clear_storage
      return unless Kernel.pbConfirmMessage(_INTL("Delete EVERYTHING in PC?"))
      each_storage_index { |box, slot| set_storage_slot(box, slot, nil) }
      Kernel.pbMessage(_INTL("PC Cleared!"))
    end

    def pokemon_expand_boxes
      params = ChooseNumberParams.new
      params.setRange(1, 100); params.setInitialValue(5)
      qty = Kernel.pbMessageChooseNumber(_INTL("Add how many boxes?"), params)
      
      return if qty <= 0
      begin
        old_max = storage_max_boxes
        if $PokemonStorage.respond_to?(:maxBoxes=)
          $PokemonStorage.maxBoxes += qty
          # In some modern versions, setting maxBoxes auto-creates the boxes. Let's check:
          if !$PokemonStorage[old_max]
            qty.times do |i|
              storage_add_box(_INTL("Box {1}", old_max + i + 1))
            end
          end
        else
          # Older versions (v15-v18)
          qty.times do |i|
            storage_add_box(_INTL("Box {1}", old_max + i + 1))
          end
        end
        Kernel.pbMessage(_INTL("Added {1} boxes!", qty))
      rescue => e
        log_error("Expand Boxes", e)
        Kernel.pbMessage(_INTL("API Error expanding boxes."))
      end
    end

    def pokemon_quick_hatch
      get_player.party.each do |p| 
        p.egg_steps = 1 if p && (p.respond_to?(:egg?) ? p.egg? : (p.respond_to?(:isEgg?) ? p.isEgg? : false))
      end
      Kernel.pbMessage(_INTL("Eggs will hatch in 1 step."))
    end

    def pokemon_add
      hash = build_search_hash(:Species)
      species_id = search_list("Species", hash)
      return if !species_id || species_id <= 0
      sp_sym = get_symbol(:Species, species_id)
      
      params = ChooseNumberParams.new
      params.setRange(1, 100); params.setInitialValue(50)
      level = Kernel.pbMessageChooseNumber(_INTL("Level:"), params)
      
      pkmn = create_pkmn(sp_sym, level)
      return unless pkmn
      
      params.setRange(0, 50); params.setInitialValue(0)
      form = Kernel.pbMessageChooseNumber(_INTL("Form ID:"), params)
      set_pokemon_form!(pkmn, form) if form > 0

      if Kernel.pbMessage(_INTL("Shiny?"), ["No", "Yes"], -1) == 1
        set_pokemon_shiny!(pkmn, true)
      end
      
      # Advanced options for modern (v19+)
      if !genderless_pokemon?(pkmn)
        prompt_pokemon_gender!(pkmn) if Kernel.pbConfirmMessage(_INTL("Set Gender?"))
      end
      
      if Kernel.pbConfirmMessage(_INTL("Edit Ability?"))
        set_pokemon_legal_ability!(pkmn)
      end

      if Kernel.pbConfirmMessage(_INTL("Set Held Item?"))
        ihash = build_search_hash(:Item)
        i_id = search_list("Items", ihash)
        if i_id
          held_item = get_symbol(:Item, i_id)
          set_pokemon_item!(pkmn, held_item)
        end
      end

      n_hash = build_search_hash(:Nature)
      if !n_hash.empty? && Kernel.pbConfirmMessage(_INTL("Edit Nature?"))
        nat_id = search_list("Natures", n_hash)
        if nat_id
          sym = get_symbol(:Nature, nat_id)
          set_pokemon_nature!(pkmn, sym)
        end
      end

      if Kernel.pbConfirmMessage(_INTL("Max IVs (31)?"))
        set_all_ivs!(pkmn, 31)
      end

      if Kernel.pbConfirmMessage(_INTL("Max EVs (252)?"))
        set_all_evs!(pkmn, 252)
      end

      if Kernel.pbConfirmMessage(_INTL("Set Nickname?"))
        nickname = pbMessageFreeText(_INTL("Nickname:"), "", false, 20)
        set_pokemon_nickname!(pkmn, nickname)
      end

      if Kernel.pbConfirmMessage(_INTL("Set Poke ball?"))
        bid = choose_poke_ball_id
        if bid
          set_pokemon_ball!(pkmn, bid)
        end
      end

      if Kernel.pbConfirmMessage(_INTL("Set Original Trainer?"))
        default_ot = get_player && get_player.respond_to?(:name) ? get_player.name : ""
        ot = pbMessageFreeText(_INTL("OT Name:"), default_ot, false, 20)
        set_pokemon_ot_name!(pkmn, ot)
      end

      recalc_pokemon_stats(pkmn)
      add_pkmn_silently(pkmn)
      Kernel.pbMessage(_INTL("Added {1} (Lv.{2})!", pkmn.name, pokemon_level_value(pkmn)))
    end

    def pokemon_import_preset
      preset = import_pokemon_preset
      return Kernel.pbMessage(_INTL("Preset file not found.")) unless preset
      pkmn = create_pokemon_from_preset(preset)
      return Kernel.pbMessage(_INTL("Could not create Pokemon from preset.")) unless pkmn
      add_pkmn_silently(pkmn)
      Kernel.pbMessage(_INTL("Pokemon imported from preset!"))
    end

    def menu_item
      menu = [
        { :label => t(TR[:additem]), :action => proc { item_add } },
        { :label => t(TR[:fillbag]), :action => proc { item_fill(0) } },
        { :label => t(TR[:fillbagnon]), :action => proc { item_fill(1) } },
        { :label => t(TR[:fillbagkey]), :action => proc { item_fill(2) } },
        { :label => t(TR[:emptybag]), :action => proc { item_empty } },
        { :label => t(TR[:exportids]), :action => proc { dump_ids(:Item, "Item_ID_List.txt") } }
      ]
      render_dynamic_menu(t(TR[:items]).upcase, menu)
    end

    def item_add
      hash = build_search_hash(:Item)
      item_id = search_list("Items", hash)
      return if !item_id || item_id <= 0
      itm_sym = get_symbol(:Item, item_id)
      params = ChooseNumberParams.new
      params.setRange(1, 999); params.setInitialValue(1)
      qty = Kernel.pbMessageChooseNumber(_INTL("Amount:"), params)
      bag_store_item(itm_sym, qty)
      Kernel.pbMessage(_INTL("Added {1} x{2}.", item_display_name(itm_sym), qty))
    end

    def item_fill(mode)
      params = ChooseNumberParams.new
      params.setRange(1, 999); params.setInitialValue(99)
      qty = Kernel.pbMessageChooseNumber(_INTL("Quantity to add:"), params)
      return if qty <= 0
      
      Kernel.pbMessage(_INTL("Adding... This may take a while."))
      hash = build_search_hash(:Item)
      hash.each do |k, v|
        sym = get_symbol(:Item, k)
        is_key = false
        itm = data_record(:Item, sym)
        if itm
          if itm
            is_key = itm.is_key_item? if itm.respond_to?(:is_key_item?)
            is_key = itm.is_important? if itm.respond_to?(:is_important?) && !is_key
          end
        else
          if defined?(pbIsKeyItem?)
            begin
              is_key = pbIsKeyItem?(k)
              is_key = pbIsKeyItem?(sym) if !is_key
            rescue => e
              log_error("Legacy Key Item Check", e)
            end
          end
          begin
            is_key = ($ItemData[k][3] == 8) if !is_key && defined?($ItemData) && $ItemData
          rescue => e
            log_error("Legacy ItemData Check", e)
          end
        end
        
        next if mode == 1 && is_key
        next if mode == 2 && !is_key
        bag_store_item(sym, qty)
      end
      Kernel.pbMessage(_INTL("Bag Filled!"))
    end

    def item_empty
      return unless Kernel.pbConfirmMessage(_INTL("Empty Bag?"))
      if $PokemonBag.respond_to?(:clear)
        $PokemonBag.clear
      elsif $PokemonBag.respond_to?(:Clear)
        $PokemonBag.Clear
      end
    end

    def menu_player
      menu = [
        { :label => "Quick Summary", :action => proc { show_player_summary } },
        { :label => "Edit Money", :action => proc { 
          p = get_player
          current_money = p.respond_to?(:money) ? p.money : 0
          params = ChooseNumberParams.new
          params.setRange(0, 9999999); params.setInitialValue(current_money)
          new_money = Kernel.pbMessageChooseNumber(_INTL("Money:"), params)
          p.money = new_money if p.respond_to?(:money=)
          Kernel.pbMessage(_INTL("Money set to {1}.", new_money))
        }},
        { :label => "Edit Coins", :action => proc { 
          p = get_player
          current_coins = p.respond_to?(:coins) ? p.coins : 0
          params = ChooseNumberParams.new
          params.setRange(0, 9999999); params.setInitialValue(current_coins)
          new_coins = Kernel.pbMessageChooseNumber(_INTL("Coins:"), params)
          p.coins = new_coins if p.respond_to?(:coins=)
          Kernel.pbMessage(_INTL("Coins set to {1}.", new_coins))
        }},
        { :label => "Edit Battle Points", :action => proc { 
          p = get_player
          if p.respond_to?(:battle_points)
            params = ChooseNumberParams.new; params.setRange(0, 9999999); params.setInitialValue(p.battle_points)
            new_bp = Kernel.pbMessageChooseNumber(_INTL("Battle Points:"), params)
            p.battle_points = new_bp
            Kernel.pbMessage(_INTL("Battle Points set to {1}.", new_bp))
          else
            Kernel.pbMessage(_INTL("BP not supported."))
          end
        }}
      ]

      if $PokemonGlobal && $PokemonGlobal.respond_to?(:soot)
        menu.push({ :label => t(TR[:ash]), :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 999999); params.setInitialValue($PokemonGlobal.soot || 0)
          new_soot = Kernel.pbMessageChooseNumber(_INTL("Ash (Soot):"), params)
          $PokemonGlobal.soot = new_soot
          Kernel.pbMessage(_INTL("Ash set to {1}.", new_soot))
        }})
      end

      menu.push({ :label => t(TR[:badges]), :action => proc { player_badges } })
      
      menu.push({ :label => t(TR[:character]), :action => proc { 
        p = get_player
        params = ChooseNumberParams.new
        params.setRange(0, 99); params.setInitialValue(p.character_ID || 0)
        new_id = Kernel.pbMessageChooseNumber(_INTL("Character ID:"), params)
        if p.respond_to?(:character_ID=)
          p.character_ID = new_id
          $game_player.refresh if $game_player
          Kernel.pbMessage(_INTL("Character changed!"))
        end
      }})

      menu.push({ :label => t(TR[:gender]), :action => proc {
        p = get_player
        p.gender = (p.gender == 0 ? 1 : 0) if p.respond_to?(:gender=)
        Kernel.pbMessage(_INTL("Gender changed!"))
      }})

      menu.push({ :label => t(TR[:outfit]), :action => proc { 
        p = get_player
        params = ChooseNumberParams.new
        params.setRange(0, 99); params.setInitialValue(p.outfit || 0)
        new_outfit = Kernel.pbMessageChooseNumber(_INTL("Outfit ID:"), params)
        if p.respond_to?(:outfit=)
          p.outfit = new_outfit
          $game_player.refresh if $game_player
          Kernel.pbMessage(_INTL("Outfit changed!"))
        end
      }})
      
      menu.push({ :label => t(TR[:name]), :action => proc { 
        p = get_player
        new_name = set_name_via_ui(p && p.respond_to?(:name) ? p.name : "")
        if new_name && new_name != "" && p && p.respond_to?(:name=)
          p.name = new_name
          Kernel.pbMessage(_INTL("Player name changed to {1}.", new_name))
        end
      }})

      menu.push({ :label => t(TR[:trainerid]), :action => proc { 
        params = ChooseNumberParams.new; params.setRange(0, 999999999); params.setInitialValue(get_player.id || 0)
        new_id = Kernel.pbMessageChooseNumber(_INTL("New ID:"), params)
        get_player.id = new_id
        Kernel.pbMessage(_INTL("Trainer ID set to {1}.", new_id))
      }})

      if $PokemonGlobal && $PokemonGlobal.respond_to?(:runningShoes)
        menu.push({ :label => t(TR[:shoes]), :action => proc {
          $PokemonGlobal.runningShoes = !$PokemonGlobal.runningShoes
          Kernel.pbMessage(_INTL("Running Shoes: {1}", on_off_text($PokemonGlobal.runningShoes)))
        }})
      end

      menu.push({ :label => t(TR[:pokedex_tog]), :action => proc {
        get_player.pokedex = true if get_player.respond_to?(:pokedex=)
        $PokemonGlobal.pokedexUnlocked = !$PokemonGlobal.pokedexUnlocked if $PokemonGlobal && $PokemonGlobal.respond_to?(:pokedexUnlocked)
        current = $PokemonGlobal && $PokemonGlobal.respond_to?(:pokedexUnlocked) ? $PokemonGlobal.pokedexUnlocked : true
        Kernel.pbMessage(_INTL("Pokedex: {1}", on_off_text(current)))
      }})

      menu.push({ :label => t(TR[:pokegear]), :action => proc {
        get_player.pokegear = true if get_player.respond_to?(:pokegear=)
        current = get_player.respond_to?(:pokegear) ? get_player.pokegear : true
        Kernel.pbMessage(_INTL("Pokegear: {1}", on_off_text(!!current)))
      }})

      menu.push({ :label => t(TR[:playtime]), :action => proc {
        params = ChooseNumberParams.new; params.setRange(0, 99999)
        current_hours = Graphics.frame_count / frame_rate_value / 60 / 60 rescue 0
        params.setInitialValue(current_hours)
        hours = Kernel.pbMessageChooseNumber(_INTL("Play Time (Hours):"), params)
        Graphics.frame_count = hours * 60 * 60 * frame_rate_value
        Kernel.pbMessage(_INTL("Play Time set to {1} hours.", hours))
      }})

      if $PokemonGlobal && $PokemonGlobal.respond_to?(:region)
        menu.push({ :label => t(TR[:region]), :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 99); params.setInitialValue($PokemonGlobal.region || 0)
          new_region = Kernel.pbMessageChooseNumber(_INTL("Region ID:"), params)
          $PokemonGlobal.region = new_region
          Kernel.pbMessage(_INTL("Region set to {1}.", new_region))
        }})
      end

      menu.push({ :label => t(TR[:pokedex]), :action => proc {
        player_complete_dex
      }})

      if $PokemonGlobal && $PokemonGlobal.respond_to?(:partner)
        menu.push({ :label => t(TR[:partner]), :action => proc {
          if $PokemonGlobal.partner
            $PokemonGlobal.partner = nil
            Kernel.pbMessage(_INTL("Partner cleared!"))
          else
            Kernel.pbMessage(_INTL("You don't have a partner right now."))
          end
        }})
      end

      render_dynamic_menu(_INTL("{1} | {2} | ${3}", t(TR[:Player]).upcase, player_name_value, player_money_value), menu)
    end

    def player_complete_dex
      return unless Kernel.pbConfirmMessage(_INTL("Mark every Pokemon as Caught and Seen?"))
      Kernel.pbMessage(_INTL("Working..."))
      hash = build_search_hash(:Species)
      p = get_player
      hash.each do |k, v|
        sym = get_symbol(:Species, k)
        if p.respond_to?(:pokedex) && p.pokedex.respond_to?(:register)
          begin
            p.pokedex.register(sym)
            p.pokedex.register_caught(sym) if p.pokedex.respond_to?(:register_caught)
          rescue => e
            log_error("Register Pokedex", e)
          end
        else
          begin
            $Trainer.seen[k] = true if $Trainer.respond_to?(:seen)
            $Trainer.owned[k] = true if $Trainer.respond_to?(:owned)
          rescue => e
            log_error("Legacy Pokedex", e)
          end
        end
      end
      Kernel.pbMessage(_INTL("Pokedex Completed!"))
    end

    def player_badges
      loop do
        cmds = []
        24.times do |i|
          cmds.push("Badge #{i+1}: #{get_player.badges[i] ? 'ON' : 'OFF'}")
        end
        cmds.push("Back")
        ch = Kernel.pbMessage(_INTL("Toggle Badges:"), cmds, -1)
        break if ch < 0 || ch == 24
        get_player.badges[ch] = !get_player.badges[ch]
      end
    end
# --- END 30_pokemon_items_player.rb ---

# --- BEGIN 40_party.rb ---
    def menu_party
      p = get_player
      return Kernel.pbMessage(_INTL("Party is empty!")) unless p && p.respond_to?(:party) && p.party && !p.party.empty?
      
      loop do
        cmds = p.party.map { |pkmn| pokemon_party_label(pkmn) }
        cmds.push("Back")
        choice = Kernel.pbMessage(_INTL("Select Pokemon:"), cmds, -1)
        break if choice < 0 || choice == cmds.length - 1
        party_pokemon_menu(p.party[choice], choice)
      end
    end

    def party_pokemon_menu(pkmn, index)
      loop do
        menu = [
          { :label => "Quick Summary", :action => proc { show_pokemon_summary(pkmn) } },
          { :label => "HP / Status", :action => proc { party_hp(pkmn) } },
          { :label => "Level / Stats", :action => proc { party_stats(pkmn) } },
          { :label => "Moves", :action => proc { party_moves(pkmn) } },
          { :label => "Held Item", :action => proc { party_item(pkmn) } },
          { :label => "Ability", :action => proc { party_ability(pkmn) } },
          { :label => "Nature & Gender", :action => proc { party_nature_gender(pkmn) } },
          { :label => "Species & Form", :action => proc { party_species_form(pkmn) } },
          { :label => "Cosmetics & Ribbons", :action => proc { party_cosmetics(pkmn) } },
          { :label => "Discardable Flags", :action => proc { party_flags(pkmn) } },
          { :label => "Egg Options", :action => proc { party_egg(pkmn) } },
          { :label => "Export Preset", :action => proc { party_export_preset(pkmn) } },
          { :label => "Apply Preset", :action => proc { party_apply_preset(pkmn) } },
          { :label => "Duplicate", :action => proc { party_duplicate(pkmn) } },
          { :label => "Delete", :action => proc { party_delete(index); return :deleted } }
        ]
        
        options = menu.map { |item| item[:label] }
        options.push("Back")
        
        title = _INTL("{1} | Lv.{2} | {3}", pkmn.name, pokemon_level_value(pkmn), pokemon_status_label(pkmn))
        choice = Kernel.pbMessage(title, options, -1)
        break if choice < 0 || choice == options.length - 1
        
        res = nil
        safe_execute(menu[choice][:label]) do
          res = menu[choice][:action].call
        end
        break if res == :deleted
      end
    end

    def party_hp(pkmn)
      menu = [
        { :label => "Heal", :action => proc { heal_pokemon!(pkmn); Kernel.pbMessage(_INTL("{1} was healed.", pkmn.name)) } },
        { :label => "Edit HP", :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 999999); params.setInitialValue(pkmn.hp)
          set_pokemon_hp!(pkmn, Kernel.pbMessageChooseNumber(_INTL("HP:"), params))
        }},
        { :label => "Faint", :action => proc { faint_pokemon!(pkmn) } },
        { :label => "Status Problem", :action => proc {
          status_hash = build_search_hash(:Status)
          status_id = search_list("Status", status_hash)
          if status_id
            sym = get_symbol(:Status, status_id)
            set_pokemon_status!(pkmn, sym)
          end
        }},
        { :label => "Clear Status", :action => proc {
          clear_pokemon_status!(pkmn)
          Kernel.pbMessage(_INTL("Status cleared for {1}.", pkmn.name))
        }},
        { :label => "Give Pokerus", :action => proc { pkmn.givePokerus if pkmn.respond_to?(:givePokerus); Kernel.pbMessage(_INTL("Infected with Pokerus!")) } },
        { :label => "Cure Pokerus", :action => proc { pkmn.pokerus = 0 if pkmn.respond_to?(:pokerus=); Kernel.pbMessage(_INTL("Pokerus cured for {1}.", pkmn.name)) } }
      ]
      render_dynamic_menu("HP / Status", menu)
    end

    def party_stats(pkmn)
      menu = [
        { :label => "Edit Level", :action => proc { 
          params = ChooseNumberParams.new; params.setRange(1, 100); params.setInitialValue(pkmn.level)
          set_pokemon_level!(pkmn, Kernel.pbMessageChooseNumber(_INTL("Level:"), params))
        }},
        { :label => "Edit Experience", :action => proc { 
          params = ChooseNumberParams.new; params.setRange(0, 9999999); params.setInitialValue(pkmn.exp)
          set_pokemon_exp!(pkmn, Kernel.pbMessageChooseNumber(_INTL("Exp:"), params))
        }},
        { :label => "Advanced Stat Editor", :action => proc {
          party_advanced_stat_editor(pkmn)
        }},
        { :label => "Max IVs", :action => proc { 
          max_pokemon_ivs!(pkmn, 31)
          Kernel.pbMessage(_INTL("IVs Maxed!"))
        }},
        { :label => "Max EVs", :action => proc { 
          max_pokemon_evs!(pkmn, 252)
          Kernel.pbMessage(_INTL("EVs Maxed!"))
        }},
        { :label => "Edit Happiness", :action => proc { 
          params = ChooseNumberParams.new; params.setRange(0, 255); params.setInitialValue(pkmn.happiness)
          set_pokemon_happiness!(pkmn, Kernel.pbMessageChooseNumber(_INTL("Happiness:"), params))
        }},
        { :label => "Max Contest Stats", :action => proc {
          %w[beauty cool cute smart tough sheen].each { |s| pkmn.send("#{s}=", 255) if pkmn.respond_to?("#{s}=") }
          Kernel.pbMessage(_INTL("Contest stats maxed!"))
        }},
        { :label => "Randomize Personal ID", :action => proc {
          pkmn.personalID = rand(256) | (rand(256) << 8) | (rand(256) << 16) | (rand(256) << 24) if pkmn.respond_to?(:personalID=)
          Kernel.pbMessage(_INTL("New Personal ID generated!"))
        }}
      ]
      render_dynamic_menu("Level / Stats", menu)
    end

    def party_advanced_stat_editor(pkmn)
      loop do
        stat_defs = stat_editor_definitions
        cmds = advanced_stat_editor_lines(pkmn)
        cmds.push("Back")
        choice = Kernel.pbMessage(_INTL("Advanced Stat Editor"), cmds, -1)
        break if choice < 0 || choice >= stat_defs.length

        stat_def = stat_defs[choice]
        action = Kernel.pbMessage(_INTL("Edit {1}:", stat_def[:label]), ["IV", "EV", "Cancel"], -1)
        next if action < 0 || action >= 2

        current_value = (action == 0) ? pokemon_iv_value(pkmn, stat_def) : pokemon_ev_value(pkmn, stat_def)
        params = ChooseNumberParams.new
        params.setRange(0, 9999)
        params.setInitialValue(current_value || 0)
        new_value = Kernel.pbMessageChooseNumber(_INTL("{1} {2}:", stat_def[:label], action == 0 ? "IV" : "EV"), params)

        ok = if action == 0
          set_pokemon_iv_value!(pkmn, stat_def, new_value)
        else
          set_pokemon_ev_value!(pkmn, stat_def, new_value)
        end

        if ok
          Kernel.pbMessage(_INTL("{1} {2} set to {3}.", stat_def[:label], action == 0 ? "IV" : "EV", new_value))
        else
          Kernel.pbMessage(_INTL("Could not edit {1} {2} on this engine.", stat_def[:label], action == 0 ? "IV" : "EV"))
        end
      end
    end

    def party_moves(pkmn)
      menu = [
        { :label => "View Moveset", :action => proc {
          show_pokemon_moveset(pkmn)
        }},
        { :label => "Learn Move", :action => proc {
          hash = build_search_hash(:Move)
          move_id = search_list("Moves", hash)
          if move_id
            sym = get_symbol(:Move, move_id)
            result = teach_move_with_prompt!(pkmn, sym)
            if result && result != :native
              Kernel.pbMessage(_INTL("{1} learned {2}!", pkmn.name, move_display_name(sym)))
            end
          end
        }},
        { :label => "Forget Move", :action => proc {
          if !pkmn.respond_to?(:moves) || !pkmn.moves || pkmn.moves.empty?
            Kernel.pbMessage(_INTL("This Pokemon has no moves to forget."))
          else
            cmds = pkmn.moves.map { |m| m.name }
            cmds.push("Cancel")
            ch = Kernel.pbMessage(_INTL("Forget which move?"), cmds, -1)
            if ch >= 0 && ch < pkmn.moves.length
              forgotten_name = pkmn.moves[ch].name rescue _INTL("that move")
              if forget_move!(pkmn, ch)
                Kernel.pbMessage(_INTL("{1} forgot {2}!", pkmn.name, forgotten_name))
              end
            end
          end
        }},
        { :label => "Reset Moveset", :action => proc {
          reset_pokemon_moves!(pkmn)
          Kernel.pbMessage(_INTL("Moveset reset!"))
        }},
        { :label => "Save Current as Initial Moveset", :action => proc {
          record_pokemon_initial_moves!(pkmn)
          Kernel.pbMessage(_INTL("Moveset recorded as Initial!"))
        }},
        { :label => "Restore PP", :action => proc {
          restore_pokemon_pp!(pkmn)
          Kernel.pbMessage(_INTL("PP Restored!"))
        }},
        { :label => "Max PP Ups", :action => proc {
          max_pokemon_ppups!(pkmn, 3)
          Kernel.pbMessage(_INTL("PP Ups maxed!"))
        }}
      ]
      render_dynamic_menu("Moves", menu)
    end

    def party_item(pkmn)
      menu = [
        { :label => "View Current Item", :action => proc {
          Kernel.pbMessage(_INTL("Current held item: {1}", pokemon_item_name(pkmn)))
        }},
        { :label => "Set Held Item", :action => proc {
          hash = build_search_hash(:Item)
          item_id = search_list("Items", hash)
          if item_id
            sym = get_symbol(:Item, item_id)
            set_pokemon_item!(pkmn, sym)
          end
        }},
        { :label => "Remove Held Item", :action => proc {
          remove_pokemon_item!(pkmn)
        }}
      ]
      render_dynamic_menu("Held Item", menu)
    end

    def party_ability(pkmn)
      menu = [
        { :label => "View Current Ability", :action => proc {
          current_ability = pkmn.respond_to?(:ability) ? pkmn.ability : nil
          Kernel.pbMessage(_INTL("Current ability: {1}", ability_display_name(current_ability)))
        }},
        { :label => "Set Legal Ability", :action => proc {
          if set_pokemon_legal_ability!(pkmn)
            Kernel.pbMessage(_INTL("Ability set!"))
          else
            Kernel.pbMessage(_INTL("No legal abilities found."))
          end
        }},
        { :label => "Search Any Ability", :action => proc {
          hash = build_search_hash(:Ability)
          id = search_list("Abilities", hash)
          if id
            sym = get_symbol(:Ability, id)
            set_pokemon_ability!(pkmn, sym, 2)
          end
        }},
        { :label => "Reset Ability", :action => proc {
          reset_pokemon_ability!(pkmn)
          Kernel.pbMessage(_INTL("Ability reset!"))
        }},
        { :label => "Export Ability IDs", :action => proc {
          dump_ids(:Ability, "Ability_ID_List.txt")
        }}
      ]
      render_dynamic_menu("Ability", menu)
    end

    def party_nature_gender(pkmn)
      menu = [
        { :label => "Set Nature", :action => proc {
          hash = build_search_hash(:Nature)
          id = search_list("Natures", hash)
          if id
            sym = get_symbol(:Nature, id)
            set_pokemon_nature!(pkmn, sym)
          end
        }},
        { :label => "Set Legal Gender", :action => proc {
          if !genderless_pokemon?(pkmn)
            prompt_pokemon_gender!(pkmn)
          else
            Kernel.pbMessage(_INTL("Pokemon is genderless or not supported."))
          end
        }},
        { :label => "Force Gender (Male)", :action => proc { set_pokemon_gender!(pkmn, :male) } },
        { :label => "Force Gender (Female)", :action => proc { set_pokemon_gender!(pkmn, :female) } },
        { :label => "Force Gender (Genderless)", :action => proc { set_pokemon_gender!(pkmn, :genderless) } }
      ]
      render_dynamic_menu("Nature & Gender", menu)
    end

    def party_species_form(pkmn)
      menu = [
        { :label => "Change Species", :action => proc {
          hash = build_search_hash(:Species)
          id = search_list("Species", hash)
          if id
            sym = get_symbol(:Species, id)
            set_pokemon_species!(pkmn, sym)
          end
        }},
        { :label => "Change Form", :action => proc {
          params = ChooseNumberParams.new; params.setRange(0, 50); params.setInitialValue(pkmn.form || 0)
          new_form = Kernel.pbMessageChooseNumber(_INTL("Form ID:"), params)
          set_pokemon_form!(pkmn, new_form)
        }},
        { :label => "Remove Form Override", :action => proc {
          clear_pokemon_form_override!(pkmn)
          Kernel.pbMessage(_INTL("Override removed!"))
        }}
      ]
      render_dynamic_menu("Species & Form", menu)
    end

    def party_cosmetics(pkmn)
      menu = [
        { :label => "Set Nickname", :action => proc {
          rename_pokemon_via_ui!(pkmn)
        }},
        { :label => "Toggle Shiny", :action => proc {
          current = pkmn.respond_to?(:shiny?) ? pkmn.shiny? : (pkmn.respond_to?(:shiny) ? pkmn.shiny : false)
          set_pokemon_shiny!(pkmn, !current)
          Kernel.pbMessage(_INTL("Shiny: {1}", !current ? "ON" : "OFF"))
        }},
        { :label => "Set Poke ball", :action => proc {
          id = choose_poke_ball_id
          if id
            set_pokemon_ball!(pkmn, id)
          end
        }},
        { :label => "Add Ribbon", :action => proc {
          hash = build_search_hash(:Ribbon)
          id = search_list("Ribbons", hash)
          if id
            sym = get_symbol(:Ribbon, id)
            add_pokemon_ribbon!(pkmn, sym)
          end
        }},
        { :label => "Clear All Ribbons", :action => proc {
          clear_pokemon_ribbons!(pkmn)
          Kernel.pbMessage(_INTL("Ribbons cleared!"))
        }},
        { :label => "Change OT Name", :action => proc {
          rename_pokemon_ot_via_ui!(pkmn)
        }}
      ]
      render_dynamic_menu("Cosmetics & Ribbons", menu)
    end

    def party_flags(pkmn)
      menu = [
        { :label => "Toggle Cannot Store", :action => proc { pkmn.cannot_store = !pkmn.cannot_store if pkmn.respond_to?(:cannot_store=); Kernel.pbMessage(_INTL("Cannot Store: {1}", pkmn.respond_to?(:cannot_store) ? on_off_text(!!pkmn.cannot_store) : "N/A")) } },
        { :label => "Toggle Cannot Release", :action => proc { pkmn.cannot_release = !pkmn.cannot_release if pkmn.respond_to?(:cannot_release=); Kernel.pbMessage(_INTL("Cannot Release: {1}", pkmn.respond_to?(:cannot_release) ? on_off_text(!!pkmn.cannot_release) : "N/A")) } },
        { :label => "Toggle Cannot Trade", :action => proc { pkmn.cannot_trade = !pkmn.cannot_trade if pkmn.respond_to?(:cannot_trade=); Kernel.pbMessage(_INTL("Cannot Trade: {1}", pkmn.respond_to?(:cannot_trade) ? on_off_text(!!pkmn.cannot_trade) : "N/A")) } }
      ]
      render_dynamic_menu("Discardable Flags", menu)
    end

    def party_egg(pkmn)
      menu = [
        { :label => "Make Egg", :action => proc { 
          make_pokemon_egg!(pkmn)
          Kernel.pbMessage(_INTL("{1} was turned into an Egg.", pkmn.name))
        }},
        { :label => "Hatch Egg", :action => proc { 
          hatch_pokemon_egg!(pkmn)
          Kernel.pbMessage(_INTL("{1} hatched successfully.", pkmn.name))
        }},
        { :label => "1 Step to Hatch", :action => proc { 
          set_pokemon_hatch_steps!(pkmn, 1)
          Kernel.pbMessage(_INTL("{1} will hatch in 1 step.", pkmn.name))
        }}
      ]
      render_dynamic_menu("Egg Options", menu)
    end

    def party_duplicate(pkmn)
      return unless Kernel.pbConfirmMessage(_INTL("Duplicate {1}?", pkmn.name))
      clone = duplicate_pokemon(pkmn)
      return Kernel.pbMessage(_INTL("Could not duplicate this Pokemon.")) unless clone
      add_pkmn_silently(clone)
      Kernel.pbMessage(_INTL("Duplicated!"))
    end

    def party_export_preset(pkmn)
      if export_pokemon_preset(pkmn)
        Kernel.pbMessage(_INTL("Preset exported to {1}.", preset_file_path))
      else
        Kernel.pbMessage(_INTL("Could not export preset."))
      end
    end

    def party_apply_preset(pkmn)
      preset = import_pokemon_preset
      return Kernel.pbMessage(_INTL("Preset file not found.")) unless preset
      if apply_pokemon_preset!(pkmn, preset)
        Kernel.pbMessage(_INTL("Preset applied!"))
      else
        Kernel.pbMessage(_INTL("Could not apply preset."))
      end
    end

    def party_delete(index)
      return unless Kernel.pbConfirmMessage(_INTL("Permanently delete this Pokemon?"))
      get_player.party.delete_at(index)
      Kernel.pbMessage(_INTL("Pokemon deleted from party."))
    end
  end
# --- END 40_party.rb ---

# --- BEGIN 50_runtime_patches.rb ---

DeveloperMenu.initialize_variables if DeveloperMenu.walk_through_walls.nil?

if !$_gm_input_patched
  if defined?(Graphics) && Graphics.respond_to?(:update)
    if DeveloperMenu.make_singleton_alias(Graphics, :_gm_original_graphics_update, :update)
      class << Graphics
        def update
          _gm_original_graphics_update
          DeveloperMenu.try_call("Graphics.update input hook") { DeveloperMenu.on_input_update }
          DeveloperMenu.try_call("Graphics.update map hook") { DeveloperMenu.on_map_update }
        end
      end
    end
    $_gm_input_patched = true
  end
end

# ===============================================================================
# ENGINE MONKEY PATCHES (For Extras Category)
# ===============================================================================

# No Battles (v15-v19)
if defined?(pbWildBattle)
  unless defined?(_gm_orig_pbWildBattle_dev)
    alias _gm_orig_pbWildBattle_dev pbWildBattle
    def pbWildBattle(*args)
      return true if DeveloperMenu.no_battles
      _gm_orig_pbWildBattle_dev(*args)
    end
  end
end

if defined?(pbTrainerBattle)
  unless defined?(_gm_orig_pbTrainerBattle_dev)
    alias _gm_orig_pbTrainerBattle_dev pbTrainerBattle
    def pbTrainerBattle(*args)
      return true if DeveloperMenu.no_battles
      _gm_orig_pbTrainerBattle_dev(*args)
    end
  end
end

# No Battles (v20+)
if defined?(WildBattle) && WildBattle.respond_to?(:start)
  if DeveloperMenu.make_singleton_alias(WildBattle, :_gm_orig_start_dev, :start)
    class << WildBattle
      def start(*args, **kwargs)
        return 1 if DeveloperMenu.no_battles
        _gm_orig_start_dev(*args, **kwargs)
      end
    end
  end
end

if defined?(TrainerBattle) && TrainerBattle.respond_to?(:start)
  if DeveloperMenu.make_singleton_alias(TrainerBattle, :_gm_orig_start_dev, :start)
    class << TrainerBattle
      def start(*args, **kwargs)
        return 1 if DeveloperMenu.no_battles
        _gm_orig_start_dev(*args, **kwargs)
      end
    end
  end
end

# Overcap IV/EV compatibility:
# Some Essentials v21 builds/plugins assume EVs never exceed the classic cap and
# raise ArgumentError in post-battle EV gain. If the player intentionally set
# overcap values with God Mode, just skip that EV gain instead of breaking flow.
if defined?(Battle)
  DeveloperMenu.make_alias(:_gm_orig_pbGainEVsOne_dev, :pbGainEVsOne, Battle)
  Battle.class_eval do
    def pbGainEVsOne(*args, **kwargs)
      return _gm_orig_pbGainEVsOne_dev(*args, **kwargs) if defined?(_gm_orig_pbGainEVsOne_dev)
      nil
    rescue ArgumentError => e
      DeveloperMenu.log_error("Battle EV Gain Compatibility", e)
      nil
    end
  end
end

if defined?(PokeBattle_Battle)
  DeveloperMenu.make_alias(:_gm_orig_pbGainEVsOne_dev, :pbGainEVsOne, PokeBattle_Battle)
  PokeBattle_Battle.class_eval do
    def pbGainEVsOne(*args)
      return _gm_orig_pbGainEVsOne_dev(*args) if defined?(_gm_orig_pbGainEVsOne_dev)
      nil
    rescue ArgumentError => e
      DeveloperMenu.log_error("Legacy Battle EV Gain Compatibility", e)
      nil
    end
  end
end

# Infinite Mega
if defined?(PokeBattle_Battle)
  DeveloperMenu.make_alias(:_gm_orig_pbHasMegaRing_dev, :pbHasMegaRing?, PokeBattle_Battle)
  DeveloperMenu.make_alias(:_gm_orig_pbCanMegaEvolve_dev, :pbCanMegaEvolve?, PokeBattle_Battle)
  PokeBattle_Battle.class_eval do
    def pbHasMegaRing?(*args)
      return true if DeveloperMenu.inf_mega
      return _gm_orig_pbHasMegaRing_dev(*args) if defined?(_gm_orig_pbHasMegaRing_dev)
      false
    end

    def pbCanMegaEvolve?(*args)
      if DeveloperMenu.inf_mega
        DeveloperMenu.try_call("Legacy Infinite Mega") do
          @megaEvolution[args[0]][args[1]] = -1 if @megaEvolution && @megaEvolution[args[0]].is_a?(Array)
        end
      end
      return _gm_orig_pbCanMegaEvolve_dev(*args) if defined?(_gm_orig_pbCanMegaEvolve_dev)
      false
    end
  end
end

# Modern Infinite Mega (v20+)
if defined?(Battle)
  DeveloperMenu.make_alias(:_gm_orig_pbHasMegaRing_dev, :pbHasMegaRing?, Battle)
  Battle.class_eval do
    def pbHasMegaRing?(*args)
      return true if DeveloperMenu.inf_mega
      return _gm_orig_pbHasMegaRing_dev(*args) if defined?(_gm_orig_pbHasMegaRing_dev)
      false
    end
  end

  if defined?(Battle::Battler)
    DeveloperMenu.make_alias(:_gm_orig_has_mega_dev, :has_mega?, Battle::Battler)
    Battle::Battler.class_eval do
      def has_mega?(*args)
        if DeveloperMenu.inf_mega
          DeveloperMenu.try_call("Modern Infinite Mega") do
            @Battle.megaEvolution[0] = [-1] * 6 if @Battle && @Battle.respond_to?(:megaEvolution) && @Battle.megaEvolution
            @Battle.megaEvolution[1] = [-1] * 6 if @Battle && @Battle.respond_to?(:megaEvolution) && @Battle.megaEvolution
          end
        end
        return _gm_orig_has_mega_dev(*args) if defined?(_gm_orig_has_mega_dev)
        false
      end
    end
  end
end

end

def pbPokeDebugMenu
  DeveloperMenu.open_menu_external
end

def pbDeveloperMenu
  DeveloperMenu.open_menu_external
end

def pbGodModeMenu
  DeveloperMenu.open_menu_external
end
# --- END 50_runtime_patches.rb ---


'@
    $godModeContent = [regex]::Replace($godModeContent, "LANG = '.*?'", "LANG = '$($lang.ToLower())'", 1)
    $godModeContent = [regex]::Replace($godModeContent, "MENU_HOTKEY = '.*?'", "MENU_HOTKEY = '$($MenuKey.Trim().ToUpper())'", 1)
    $godModeContent = [regex]::Replace($godModeContent, "WTW_HOTKEY = '.*?'", "WTW_HOTKEY = '$($WtwKey.Trim().ToUpper())'", 1)
    $godModeContent = [regex]::Replace($godModeContent, "HEAL_HOTKEY = '.*?'", "HEAL_HOTKEY = '$($HealKey.Trim().ToUpper())'", 1)
    
    if (-not $DryRun) {
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($DestGodMode, $godModeContent, $utf8NoBom)
    }
    $InstallReport.GodModeCopied = $true

    $DestPreload = Join-Path $GameDir "preload_gm.rb"
    $preloadContent = @'
GM_TRY_ENABLE_NATIVE_DEBUG = false unless defined?(GM_TRY_ENABLE_NATIVE_DEBUG)
GM_TRY_DISABLE_COMPILER = false unless defined?(GM_TRY_DISABLE_COMPILER)

module PokeDebugBootstrap
  module_function

  def log_message(label, message)
    File.open("developer_menu_errors.log", "a") do |f|
      f.puts("[#{Time.now}] #{label}: #{message}")
    end
  rescue Exception
  end

  def debug_boot_enabled?
    GM_TRY_ENABLE_NATIVE_DEBUG == true
  rescue Exception
    false
  end

  def compiler_patch_enabled?
    GM_TRY_DISABLE_COMPILER == true
  rescue Exception
    false
  end

  def activate_native_debug!
    return unless debug_boot_enabled?
    begin
      $DEBUG = true
    rescue Exception
    end
    begin
      $TEST = true
    rescue Exception
    end
    begin
      ENV["DEBUG"] = "1"
      ENV["TEST"] = "1"
    rescue Exception
    end
    begin
      Object.const_set(:DEBUG, true) unless Object.const_defined?(:DEBUG)
    rescue Exception
    end
    begin
      Object.const_set(:TEST, true) unless Object.const_defined?(:TEST)
    rescue Exception
    end
    [
      [:System, [[:set_debug_mode, true], [:"debug_mode=", true], [:"debug=", true], [:"test_mode=", true]]],
      [:Essentials, [[:"debug_mode=", true], [:"debug=", true], [:"test_mode=", true]]],
      [:Settings, [[:"debug_mode=", true], [:"debug=", true]]]
    ].each do |receiver_name, attempts|
      begin
        next unless Object.const_defined?(receiver_name)
        receiver = Object.const_get(receiver_name)
        attempts.each do |method_name, value|
          receiver.send(method_name, value) if receiver.respond_to?(method_name)
        end
      rescue Exception
      end
    end
    log_message("Bootstrap", "Native debug activation attempt applied.")
  end

  def patch_compiler_method!(receiver, method_name)
    return unless receiver.respond_to?(method_name)
    aliased_name = :"_gm_original_#{method_name}"
    return if receiver.respond_to?(aliased_name)
    receiver.singleton_class.send(:alias_method, aliased_name, method_name)
    receiver.singleton_class.send(:define_method, method_name) do |*args, &block|
      PokeDebugBootstrap.log_message("Compiler Patch", "Skipped #{receiver}.#{method_name}")
      false
    end
  rescue Exception => e
    log_message("Compiler Patch", "#{receiver}.#{method_name} failed: #{e.message}")
  end

  def patch_object_compile_methods!
    methods = [:pbCompileAllData, :pbCompileAllDataIfNecessary, :mainFunctionDebug]
    methods.each do |method_name|
      next unless Object.private_method_defined?(method_name) || Object.method_defined?(method_name)
      aliased_name = :"_gm_original_#{method_name}"
      next if Object.private_method_defined?(aliased_name) || Object.method_defined?(aliased_name)
      Object.class_eval do
        alias_method aliased_name, method_name
        define_method(method_name) do |*args, &block|
          PokeDebugBootstrap.log_message("Compiler Patch", "Skipped Object##{method_name}")
          false
        end
        private method_name if private_method_defined?(aliased_name)
      end
    end
  rescue Exception => e
    log_message("Compiler Patch", "Object patch failed: #{e.message}")
  end

  def patch_compiler_module!
    return unless compiler_patch_enabled?
    patch_object_compile_methods!
    return unless Object.const_defined?(:Compiler)
    compiler = Object.const_get(:Compiler)
    [
      :main, :compile_all, :compile_pbs_files, :compile_pbs_file,
      :compile_pbs, :compile_all_data, :compile_all_files,
      :compile_trainer_lists, :compile_trainer_events
    ].each do |method_name|
      patch_compiler_method!(compiler, method_name)
    end
    log_message("Bootstrap", "Compiler disable patch applied.")
  rescue Exception => e
    log_message("Compiler Patch", "Compiler patch failed: #{e.message}")
  end

  def defer_compiler_patch!
    return unless compiler_patch_enabled?
    if Object.const_defined?(:Compiler)
      patch_compiler_module!
      return
    end
    return unless defined?(TracePoint)
    trace = TracePoint.new(:end) do
      next unless Object.const_defined?(:Compiler)
      patch_compiler_module!
      trace.disable
    end
    trace.enable
  rescue Exception => e
    log_message("Compiler Patch", "TracePoint setup failed: #{e.message}")
  end
end

begin
  PokeDebugBootstrap.activate_native_debug!
  PokeDebugBootstrap.defer_compiler_patch!
  plugin_path = File.expand_path("Plugins/God Mode/god_mode.rb", Dir.pwd)
  eval(File.binread(plugin_path), binding, plugin_path)
rescue Exception => e
  File.open("developer_menu_errors.log", "a") do |f|
    f.puts("[#{Time.now}] Startup Error:")
    f.puts(e.message)
    f.puts(e.backtrace.join("\n"))
  end
end

'@
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($DestPreload, $preloadContent, $utf8NoBom)

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
                
                $iniPath = Join-Path $GameDir "Game.ini"
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

