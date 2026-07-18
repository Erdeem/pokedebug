<#
.SYNOPSIS
    PokeDebug Installer for Pokemon Essentials
#>
#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$GameDir = ".",
    [string]$Language = "",
    [string]$InstallProfile = "",
    [string]$MenuHotkey = "",
    [string]$WalkThroughWallsHotkey = "",
    [string]$HealHotkey = "",
    [string]$RuntimeDebugOnBoot = "",
    [string]$CompileBypassOnBoot = "",
    [switch]$DryRun,
    [switch]$Uninstall,
    [switch]$RestoreBackups,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"
$PokeDebugInstallerVersion = "3.1"

# Supported hosts:
# - Windows PowerShell 5.1 or newer Desktop edition
# - PowerShell 7 or newer Core edition on Windows
$currentPowerShellVersion = $PSVersionTable.PSVersion
$currentPowerShellEdition = [string]$PSVersionTable.PSEdition
$isWindowsPowerShellHost = if (Get-Variable IsWindows -ErrorAction SilentlyContinue) {
    [bool]$IsWindows
} else {
    $env:OS -eq "Windows_NT"
}
$isSupportedPowerShellHost = $isWindowsPowerShellHost -and (
    ($currentPowerShellEdition -eq "Desktop" -and $currentPowerShellVersion -ge [version]"5.1") -or
    ($currentPowerShellEdition -eq "Core" -and $currentPowerShellVersion -ge [version]"7.0")
)
if (-not $isSupportedPowerShellHost) {
    throw ("PokeDebug requires Windows PowerShell 5.1 or PowerShell 7+ on Windows. Current host: PowerShell {0} ({1}), OS={2}." -f $currentPowerShellVersion, $currentPowerShellEdition, $env:OS)
}

$DefaultIndigoPokemonZipUrl = $env:POKEDEBUG_INDIGO_ZIP_URL
$IndigoPokemonPackFolders = @(
    "Back",
    "Back shiny",
    "Eggs",
    "Footprints",
    "Front",
    "Front shiny",
    "Icons",
    "Icons shiny",
    "Shadow"
)

function Log([string]$msg, [ConsoleColor]$color = "White") {
    Write-Host $msg -ForegroundColor $color
}

function Set-ConsoleTheme {
    try {
        $host.UI.RawUI.WindowTitle = "PokeDebug Installer $PokeDebugInstallerVersion"
    } catch {}
    try {
        $raw = $host.UI.RawUI
        $raw.BackgroundColor = "Black"
        $raw.ForegroundColor = "Gray"
        $buffer = $raw.BufferSize
        $window = $raw.WindowSize
        $newWidth = 76
        $newHeight = 34
        if ($buffer.Width -lt $newWidth) { $buffer.Width = $newWidth }
        if ($buffer.Height -lt $newHeight) { $buffer.Height = $newHeight }
        $raw.BufferSize = $buffer
        if ($window.Width -ne $newWidth -or $window.Height -ne $newHeight) {
            $window.Width = $newWidth
            $window.Height = $newHeight
            $raw.WindowSize = $window
        }
        Clear-Host
    } catch {}
}

function Show-Separator {
    param([ConsoleColor]$Color = "Gray")
    Write-Host "       ______________________________________________________________" -ForegroundColor $Color
}

function Show-CompactSeparator {
    param([ConsoleColor]$Color = "Gray")
    Write-Host "       ______________________________________________________________" -ForegroundColor $Color
}

function Print-Header {
    Set-ConsoleTheme
}

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Get-Msg([string]$en, [string]$pt, [string]$es) {
    if ($lang -eq "pt") { return $pt } elseif ($lang -eq "es") { return $es } else { return $en }
}

function Show-Section([string]$Title) {
    Write-Host ""
    Write-Host ""
    Write-Host ""
    Write-Host "       ______________________________________________________________" -ForegroundColor Gray
    Write-Host ""
    Write-Host ("                 {0}" -f $Title) -ForegroundColor White
    Write-Host ""
}

function Get-ShortenedPath([string]$Path, [int]$MaxLength = 32) {
    if ([string]::IsNullOrEmpty($Path) -or $Path.Length -le $MaxLength) {
        return $Path
    }
    if ($Path -like "*\*") {
        $parts = $Path -split '\\'
        if ($parts.Count -gt 2) {
            $drive = $parts[0]
            $last = $parts[-1]
            $prefix = "$drive\..."
            $combinedLength = $prefix.Length + $last.Length + 1
            if ($combinedLength -le $MaxLength) {
                return "$prefix\$last"
            }
            $avail = $MaxLength - $prefix.Length - 1
            if ($avail -gt 5) {
                return "$prefix\$($last.Substring(0, $avail - 3))..."
            }
        }
    }
    $half = [Math]::Floor(($MaxLength - 3) / 2)
    return $Path.Substring(0, $half) + "..." + $Path.Substring($Path.Length - $half)
}

function Show-CardLine([string]$Label, [string]$Value, [ConsoleColor]$ValueColor = "White") {
    $displayValue = $Value
    if ($Value -like "*:\*" -or $Value -like "*\*") {
        $displayValue = Get-ShortenedPath $Value 32
    }
    Write-Host "             " -NoNewline
    Write-Host ("{0,-25} : " -f $Label) -NoNewline -ForegroundColor White
    Write-Host $displayValue -ForegroundColor $ValueColor
}

function Show-MenuItem([string]$Key, [string]$Label, [string]$Description) {
    Write-Host "             " -NoNewline
    Write-Host ("[{0}] " -f $Key) -NoNewline -ForegroundColor White
    if ([string]::IsNullOrWhiteSpace($Description)) {
        Write-Host $Label -ForegroundColor Green
    } else {
        Write-Host ("{0,-20}" -f $Label) -NoNewline -ForegroundColor Green
        Write-Host (" - {0}" -f $Description) -ForegroundColor White
    }
    if (-not $NonInteractive -and $Host.Name -eq "ConsoleHost") { Start-Sleep -Milliseconds 22 }
}

function Show-KeyboardPrompt([string]$AllowedText, [string]$PromptText = "") {
    Write-Host ""
    Write-Host "       ______________________________________________________________" -ForegroundColor Gray
    Write-Host ""
    Write-Host "         " -NoNewline
    if ([string]::IsNullOrWhiteSpace($PromptText)) {
        Write-Host ("Choose a menu option using your keyboard [{0}] :" -f $AllowedText) -NoNewline -ForegroundColor Green
    } else {
        Write-Host ("{0} [{1}] :" -f $PromptText, $AllowedText) -NoNewline -ForegroundColor Green
    }
}

Print-Header

$lang = $Language.ToLower()
if ($lang -ne "en" -and $lang -ne "pt" -and $lang -ne "es") {
    if ($NonInteractive) {
        $lang = "en"
    } else {
        Show-Section "PokeDebug Installer $PokeDebugInstallerVersion"
        Write-Host "                 Select Language:" -ForegroundColor White
        Write-Host ""
        Show-MenuItem "1" "English" ""
        Show-MenuItem "2" "Portugues" ""
        Show-MenuItem "3" "Espanol" ""
        Show-KeyboardPrompt "1,2,3" "Choose a language / Escolha um idioma"
        $langInput = ""
        try {
            while ($langInput -notin @("1","2","3")) {
                $langInput = [Console]::ReadKey($true).KeyChar.ToString()
                if ($langInput -notin @("1","2","3")) { [Console]::Beep() }
            }
            Write-Host " $langInput"
        } catch {
            $langInput = (Read-Host " ").Trim()
            if ($langInput -notin @("1","2","3")) { $langInput = "1" }
        }
        if ($langInput -eq "2") {
            $lang = "pt"
        } elseif ($langInput -eq "3") {
            $lang = "es"
        } else {
            $lang = "en"
        }
    }
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
        $strategy.Name = "Hybrid runtime (MKXP preferred)"
        $strategy.Confidence = "High"
        $strategy.Summary = "Automatic mode uses MKXP preload only; RGSS remains available as an explicit fallback."
        $strategy.Color = "Green"
    } elseif ($Diagnostics.HasScriptsRxdata -and $Diagnostics.HasRgssArchive) {
        $strategy.Name = "Hybrid Dual RGSS"
        $strategy.Confidence = "High"
        $strategy.Summary = "Echo-style mixed RGSS layout detected. Installer should patch both Scripts.rxdata and the RGSS archive."
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

    # Print the prompt to the screen first
    if (-not [string]::IsNullOrEmpty($Prompt)) {
        Write-Host $Prompt -NoNewline
    }

    # If interactive ConsoleHost is available, read key by key (choice /N style)
    if ($Host.Name -eq "ConsoleHost") {
        while ($true) {
            try {
                if ([Console]::KeyAvailable) {
                    while ([Console]::KeyAvailable) { [void][Console]::ReadKey($true) }
                }
                $key = [Console]::ReadKey($true)
                if ($key.Key -eq "Enter" -or $key.Key -eq "Spacebar") {
                    if (-not [string]::IsNullOrEmpty($DefaultValue)) {
                        Write-Host $DefaultValue
                        return $DefaultValue
                    }
                }
                $value = $key.KeyChar.ToString()
                if ($allowedLookup.ContainsKey($value.ToLowerInvariant())) {
                    Write-Host $value
                    return $value
                }
                [Console]::Beep()
            } catch {
                # Fallback to Read-Host on readkey failure
                break
            }
        }
    }

    # Fallback / Non-ConsoleHost:
    while ($true) {
        $value = (Read-Host).Trim()
        if ([string]::IsNullOrWhiteSpace($value)) {
            return $DefaultValue
        }
        if ($allowedLookup.ContainsKey($value.ToLowerInvariant())) {
            return $value
        }
        Log (Get-Msg "[!] Invalid option. Try again." "[!] Opcao invalida. Tente novamente." "[!] Opcion invalida. Intenta otra vez.") "Yellow"
        if (-not [string]::IsNullOrEmpty($Prompt)) {
            Write-Host $Prompt -NoNewline
        }
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
    Show-CardLine "Path" $Diagnostics["GameDir"] "Gray"
    Show-CardLine "MKXP-Z" (Format-State $Diagnostics["HasMkxp"]) "Gray"
    Show-CardLine "Data folder" (Format-State $Diagnostics["HasDataDir"]) "Gray"
    Show-CardLine "Scripts.rxdata" (Format-State $Diagnostics["HasScriptsRxdata"]) "Gray"
    Show-CardLine "RGSS archive" $archiveLabel "Gray"
    Show-CardLine "PluginScripts.rxdata" (Format-State $Diagnostics["HasPluginScripts"]) "Gray"
    Show-CardLine "Plugins folder" (Format-State $Diagnostics["HasPluginsDir"]) "Gray"
    Show-CardLine "preload_gm.rb" (Format-State $Diagnostics["HasPreloadFile"]) "Gray"
    Show-CardLine "Game INI" (Format-State $Diagnostics["HasIni"]) "Gray"
    if ($Diagnostics["HasIni"]) {
        Show-CardLine "INI path" $Diagnostics["IniPath"] "DarkGray"
    }
    Show-CardLine "Enigma packed guess" (Format-State $Diagnostics["EnigmaPacked"]) $enigmaColor
    if ($Diagnostics["EnigmaPacked"]) {
        Show-CardLine "Enigma confidence" $Diagnostics["EnigmaConfidence"] "Yellow"
        if ($Diagnostics["EnigmaEvidence"] -and $Diagnostics["EnigmaEvidence"].Count -gt 0) {
            Show-CardLine "Enigma evidence" ($Diagnostics["EnigmaEvidence"] -join ", ") "DarkGray"
        }
    }
    Show-CardLine "Injection method" $strategy.Name $strategy.Color
    Show-CardLine "Detection confidence" $strategy.Confidence $strategy.Color
    Show-CardLine "Method notes" $strategy.Summary "DarkGray"
}

function Show-InstallProfileMenu {
    Print-Header
    Show-Section (Get-Msg "Injection Profile" "Perfil de Injecao" "Perfil de Inyeccion")
    Show-MenuItem "1" "Safe" (Get-Msg "Only inject menu files. Best for unstable or modded targets." "Apenas injeta arquivos de menu. Melhor para alvos instaveis ou modificados." "Solo inyecta archivos de menu. Mejor para objetivos inestables o modificados.")
    Show-MenuItem "2" "Recommended" (Get-Msg "Installs the menu with stable defaults." "Instala o menu com padroes estaveis." "Instala el menu con valores predeterminados estables.")
    Show-MenuItem "3" "Aggressive" (Get-Msg "Adds compile-bypass attempts for tougher games." "Adiciona tentativas de bypass de compilacao para jogos dificeis." "Agrega intentos de bypass de compilacion para juegos dificiles.")
    Show-KeyboardPrompt "1,2,3"
    return (Read-MenuChoice " > " @("1","2","3") "2")
}

function Show-MainActionMenu {
    Print-Header
    Write-Host ""
    Write-Host ""
    Write-Host ""
    Write-Host "       " -NoNewline
    Write-Host (Get-Msg "Tip:" "Dica:" "Consejo:") -NoNewline -ForegroundColor Green
    Write-Host (Get-Msg " Auto mode is recommended for most games." " O modo Auto e recomendado para a maioria dos jogos." " El modo Auto es recomendado para la mayoria de juegos.") -ForegroundColor White
    Write-Host ""
    Write-Host ""
    Write-Host ""
    Write-Host "       ______________________________________________________________" -ForegroundColor Gray
    Write-Host ""
    Write-Host ("                 {0}:" -f (Get-Msg "Installation Methods" "Metodos de Instalacao" "Metodos de Instalacion")) -ForegroundColor White
    Write-Host ""
    Show-MenuItem "1" "Auto" (Get-Msg "Default" "Padrao" "Predeterminado")
    Show-MenuItem "2" "MKXP" (Get-Msg "MKXP-Z Games" "Jogos MKXP-Z" "Juegos MKXP-Z")
    Show-MenuItem "3" "RGSS" (Get-Msg "Old Games" "Jogos Antigos" "Juegos Antiguos")
    Show-MenuItem "4" "Both" (Get-Msg "Both Patch Methods" "Ambos Metodos de Patch" "Ambos Metodos de Parche")
    
    Write-Host ""
    Write-Host "             __________________________________________________" -ForegroundColor Gray
    Write-Host ""
    
    Show-MenuItem "5" (Get-Msg "Uninstall" "Desinstalar" "Desinstalar") ""
    Show-MenuItem "6" (Get-Msg "Restore Backup" "Restaurar Backup" "Restaurar Copia de Seguridad") ""
    Show-MenuItem "7" "Sherlock" ""
    
    Write-Host ""
    Write-Host "             __________________________________________________" -ForegroundColor Gray
    Write-Host ""
    
    Show-MenuItem "T" (Get-Msg "Tested Games" "Jogos Testados" "Juegos Probados") ""
    Show-MenuItem "H" (Get-Msg "Help" "Ajuda" "Ayuda") ""
    Show-MenuItem "0" (Get-Msg "Exit" "Sair" "Salir") ""
    
    Show-KeyboardPrompt "1,2,3...T,H,0" (Get-Msg "Choose a menu option using your keyboard" "Escolha uma opcao usando o teclado" "Elija una opcion usando el teclado")
    return (Read-MenuChoice " > " @("1","2","3","4","5","6","7","T","H","S","0") "1").ToUpperInvariant()
}

function Wait-GoBack([string]$Prompt = "") {
    $promptMsg = if ([string]::IsNullOrEmpty($Prompt)) {
        Get-Msg "[0] Go back" "[0] Voltar" "[0] Volver"
    } else {
        $Prompt
    }
    Write-Host ""
    Write-Host "             " -NoNewline
    [void](Read-MenuChoice $promptMsg @("0") "0")
}

function Show-TestedGamesScreen {
    Print-Header
    Show-Section (Get-Msg "Tested Games" "Jogos Testados" "Juegos Probados")
    
    $games = @(
        "Pokemon Essentials v19/v20/v21",
        "Pokemon Nova",
        "Pokemon Uranium",
        "Pokemon Insurgence",
        "Pokemon Anil",
        "Pokemon Z",
        "Pokemon Mauve",
        "Pokemon Infinite Fusion 2",
        "Pokemon Rejuvenation (partial support)",
        "Pokemon Unbreakable Ties",
        "Pokemon Burning Scale",
        "Pokemon Vanguard",
        "Pokemon Echo"
    )
    
    foreach ($game in $games) {
        Write-Host "             - $game" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "       ______________________________________________________________" -ForegroundColor Gray
    Wait-GoBack
}

function Show-HelpScreen {
    Print-Header
    Show-Section (Get-Msg "Help & Instructions" "Ajuda & Instrucoes" "Ayuda & Instrucciones")
    
    Write-Host "             1." -NoNewline -ForegroundColor White
    Write-Host (" {0,-10} : {1}" -f "Auto", (Get-Msg "Detects and uses the best patch method." "Detecta e usa o melhor metodo de patch." "Detecta y usa el mejor metodo de parche.")) -ForegroundColor Gray
    Write-Host "             2." -NoNewline -ForegroundColor White
    Write-Host (" {0,-10} : {1}" -f "MKXP", (Get-Msg "Forces MKXP-Z style injection only." "Forca apenas injecao estilo MKXP-Z." "Fuerza solo inyeccion estilo MKXP-Z.")) -ForegroundColor Gray
    Write-Host "             3." -NoNewline -ForegroundColor White
    Write-Host (" {0,-10} : {1}" -f "RGSS", (Get-Msg "Forces classic RGSS script patching." "Forca apenas patch de script RGSS classico." "Fuerza solo parche de script RGSS clasico.")) -ForegroundColor Gray
    Write-Host "             4." -NoNewline -ForegroundColor White
    Write-Host (" {0,-10} : {1}" -f "Both", (Get-Msg "Tries both MKXP and RGSS patch methods." "Tenta ambos os metodos de patch (MKXP e RGSS)." "Intenta ambos metodos de parche (MKXP y RGSS).")) -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "             " -NoNewline -ForegroundColor White
    Write-Host (Get-Msg "Default hotkeys:" "Atalhos padrao:" "Atajos predeterminados:") -ForegroundColor White
    Write-Host "             - F5 : " -NoNewline -ForegroundColor White
    Write-Host (Get-Msg "Walk Through Walls" "Atravessar Paredes" "Atravesar Paredes") -ForegroundColor Gray
    Write-Host "             - F6 : " -NoNewline -ForegroundColor White
    Write-Host (Get-Msg "Open PokeDebug Menu" "Abrir Menu PokeDebug" "Abrir Menu PokeDebug") -ForegroundColor Gray
    Write-Host "             - F9 : " -NoNewline -ForegroundColor White
    Write-Host (Get-Msg "Quick Heal" "Cura Rapida" "Curacion Rapida") -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "       ______________________________________________________________" -ForegroundColor Gray
    Wait-GoBack
}

function Show-FramedMessage([string[]]$Lines) {
    Write-Host ""
    Write-Host "       ______________________________________________________________" -ForegroundColor Gray
    foreach ($line in $Lines) {
        Write-Host ""
        Write-Host ("             {0}" -f $line) -ForegroundColor White
    }
    Write-Host "       ______________________________________________________________" -ForegroundColor Gray
    Write-Host ""
}

function Read-FramedChoice([string]$Prompt, [string[]]$Allowed, [string]$Default = "") {
    Write-Host "             " -NoNewline
    return (Read-MenuChoice $Prompt $Allowed $Default)
}

function Show-HotkeysMenu {
    param(
        [string]$CurrentMenuKey,
        [string]$CurrentWtwKey,
        [string]$CurrentHealKey
    )

    $menuKey = $CurrentMenuKey
    $wtwKey = $CurrentWtwKey
    $healKey = $CurrentHealKey
    while ($true) {
        Print-Header
        Show-Section (Get-Msg "Hotkeys Options" "Opcoes de Atalho" "Opciones de Atajos")
        Show-MenuItem "1" (Get-Msg "Use default keys" "Usar teclas padrao" "Usar teclas predeterminadas") "F5, F6, F9"
        
        Write-Host ""
        Write-Host "             __________________________________________________" -ForegroundColor Gray
        Write-Host ""
        
        Show-MenuItem "2" (Get-Msg "Walk Through Walls" "Atravessar Paredes" "Atravesar Paredes") $wtwKey
        Show-MenuItem "3" (Get-Msg "Open PokeDebug Menu" "Abrir Menu PokeDebug" "Abrir Menu PokeDebug") $menuKey
        Show-MenuItem "4" (Get-Msg "Quick Heal" "Cura Rapida" "Curacion Rapida") $healKey
        
        Write-Host ""
        Write-Host "             __________________________________________________" -ForegroundColor Gray
        Write-Host ""
        
        Show-MenuItem "5" (Get-Msg "Save and Continue" "Salvar e Continuar" "Guardar y Continuar") ""
        Show-MenuItem "0" (Get-Msg "Abort" "Abortar" "Abortar") ""
        
        Show-KeyboardPrompt "1,2,3,4,5,0"
        $choice = (Read-MenuChoice " > " @("1","2","3","4","5","0") "5").Trim().ToUpperInvariant()
        switch ($choice) {
            "1" { $wtwKey = "F5"; $menuKey = "F6"; $healKey = "F9"; return @{ Menu = $menuKey; Wtw = $wtwKey; Heal = $healKey; Abort = $false } }
            "2" { 
                Write-Host ""
                Write-Host "             " -NoNewline
                $wtwKey = Normalize-Hotkey (Read-Host (Get-Msg "New Walk Through Walls key" "Nova tecla de Atravessar Paredes" "Nueva tecla de Atravesar Paredes")) $wtwKey 
            }
            "3" { 
                Write-Host ""
                Write-Host "             " -NoNewline
                $menuKey = Normalize-Hotkey (Read-Host (Get-Msg "New Open Menu key" "Nova tecla de Abrir Menu" "Nueva tecla de Abrir Menu")) $menuKey 
            }
            "4" { 
                Write-Host ""
                Write-Host "             " -NoNewline
                $healKey = Normalize-Hotkey (Read-Host (Get-Msg "New Quick Heal key" "Nova tecla de Cura Rapida" "Nueva tecla de Curacion Rapida")) $healKey 
            }
            "5" { return @{ Menu = $menuKey; Wtw = $wtwKey; Heal = $healKey; Abort = $false } }
            "0" { return @{ Menu = $menuKey; Wtw = $wtwKey; Heal = $healKey; Abort = $true } }
        }
    }
}

function Show-AlreadyInstalledPrompt {
    Show-FramedMessage @((Get-Msg "PokeDebug is already installed." "PokeDebug ja esta instalado." "PokeDebug ya esta instalado."))
    return (Read-FramedChoice (Get-Msg "[1] Patch anyway [0] Go back : " "[1] Aplicar patch assim mesmo [0] Voltar : " "[1] Aplicar parche de todos modos [0] Volver : ") @("1","0") "0")
}

function Show-EnigmaPrompt {
    Show-FramedMessage @(
        (Get-Msg "Enigma encryption was detected." "Criptografia Enigma detectada." "Criptografia Enigma detectada."),
        (Get-Msg "Do you want to unpack it?" "Deseja descompacta-la?" "Desea descomprimirlo?")
    )
    return (Read-FramedChoice (Get-Msg "[1] Yes, download Enigma unpacker [0] Abort : " "[1] Sim, baixar o descompactador Enigma [0] Abortar : " "[1] Si, descargar el desempaquetador Enigma [0] Abortar : ") @("1","0") "0")
}

function Show-ProceedPrompt {
    Write-Host ""
    Write-Host "       ______________________________________________________________" -ForegroundColor Gray
    Write-Host ""
    return (Read-FramedChoice (Get-Msg "[1] Proceed with injection now? [0] Abort : " "[1] Prosseguir com a injecao agora? [0] Abortar : " "[1] Proceder con la inyeccion ahora? [0] Abortar : ") @("1","0") "1")
}

function Show-UninstallPrompt {
    Show-FramedMessage @((Get-Msg "PokeDebug has been uninstalled." "PokeDebug foi desinstalado." "PokeDebug ha sido desinstalado."))
    return (Read-FramedChoice (Get-Msg "[1] Restore backups [0] Go back : " "[1] Restaurar backups [0] Voltar : " "[1] Restaurar copias de seguridad [0] Volver : ") @("1","0") "0")
}

function Show-RestorePrompt {
    Show-FramedMessage @((Get-Msg "Backup restored." "Backup restaurado." "Copia de seguridad restaurada."))
    Wait-GoBack
}

function New-SherlockZip {
    param([string]$ResolvedGameDir, $Diagnostics)
    $reportPath = Write-InstallReportFile $ResolvedGameDir
    $zipPath = Join-Path $ResolvedGameDir ("PokeDebug_Sherlock_{0}.zip" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("PokeDebug_Sherlock_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    try {
        if (Test-Path $reportPath -PathType Leaf) { Copy-Item $reportPath (Join-Path $tempDir "PokeDebug_Install_Report.txt") -Force }
        $diagPath = Join-Path $tempDir "Sherlock_Diagnostics.txt"
        $diagLines = @()
        foreach ($key in $Diagnostics.Keys) {
            $value = $Diagnostics[$key]
            if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
                $value = ($value | ForEach-Object { $_.ToString() }) -join ", "
            }
            $diagLines += ("{0}: {1}" -f $key, $value)
        }
        [System.IO.File]::WriteAllLines($diagPath, $diagLines, [System.Text.Encoding]::UTF8)
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        Compress-Archive -Path (Join-Path $tempDir "*") -DestinationPath $zipPath -Force
        return $zipPath
    } finally {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Send-SherlockWebhook {
    param([string]$ResolvedGameDir, $Diagnostics)
    $defaultWebhook = ""
    Write-Host "             " -NoNewline
    $inputUrl = (Read-Host (Get-Msg "Webhook URL (Press ENTER for default)" "URL do Webhook (Pressione ENTER para o padrao)" "URL del Webhook (Presione ENTER para el predeterminado)")).Trim()
    $url = if ([string]::IsNullOrWhiteSpace($inputUrl)) { $defaultWebhook } else { $inputUrl }
    
    $diagText = ""
    foreach ($key in $Diagnostics.Keys) {
        $value = $Diagnostics[$key]
        if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
            $value = ($value | ForEach-Object { $_.ToString() }) -join ", "
        }
        $diagText += "{0,-24}: {1}`n" -f $key, $value
    }
    
    $reportText = ""
    $reportPath = Get-InstallReportPath $ResolvedGameDir
    if (Test-Path $reportPath) {
        try {
            $reportText = [System.IO.File]::ReadAllText($reportPath)
        } catch {}
    }
    
    if ([string]::IsNullOrWhiteSpace($reportText)) {
        try {
            $tempReportPath = Write-InstallReportFile $ResolvedGameDir
            if (Test-Path $tempReportPath) {
                $reportText = [System.IO.File]::ReadAllText($tempReportPath)
                Remove-Item $tempReportPath -ErrorAction SilentlyContinue
            }
        } catch {}
    }
    
    $reportBlock = ""
    if (-not [string]::IsNullOrWhiteSpace($reportText)) {
        $reportBlock = "`n**Install Report:**`n" + '```yaml' + "`n" + $reportText + '```'
    }

    $descriptionText = "**Game Directory:** " + $ResolvedGameDir + "`n`n**Diagnostics:**`n" + '```yaml' + "`n" + $diagText + '```' + $reportBlock

    $payload = @{
        content = "[Sherlock] **PokeDebug Diagnostics Report**"
        embeds = @(@{
            title = "Sherlock Results & Diagnostics"
            description = $descriptionText
            color = 3066993
            footer = @{
                text = "PokeDebug Sherlock Reporter | " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
        })
    } | ConvertTo-Json -Depth 6
    Invoke-WebRequest -Uri $url -Method Post -ContentType "application/json" -Body $payload | Out-Null
    Log "`n             [+] Sherlock report sent." "Green"
}

function Show-SherlockMenu {
    param([string]$ResolvedGameDir, $Diagnostics)
    while ($true) {
        Print-Header
        $strategy = Get-InjectionStrategy $Diagnostics
        Show-Section "Sherlock Results"
        Show-CardLine "Path" $ResolvedGameDir "Gray"
        Show-CardLine "MKXP-Z" (Format-State $Diagnostics["HasMkxp"]) "Gray"
        Show-CardLine "Data folder" (Format-State $Diagnostics["HasDataDir"]) "Gray"
        Show-CardLine "Scripts.rxdata" (Format-State $Diagnostics["HasScriptsRxdata"]) "Gray"
        Show-CardLine "RGSS archive" $(if ($Diagnostics["HasRgssArchive"]) { $Diagnostics["ArchiveName"] } else { "OFF" }) "Gray"
        Show-CardLine "PluginScripts.rxdata" (Format-State $Diagnostics["HasPluginScripts"]) "Gray"
        Show-CardLine "Plugins folder" (Format-State $Diagnostics["HasPluginsDir"]) "Gray"
        Show-CardLine "Preload_gm.rb" (Format-State $Diagnostics["HasPreloadFile"]) "Gray"
        Show-CardLine "Game INI" (Format-State $Diagnostics["HasIni"]) "Gray"
        if ($Diagnostics["HasIni"]) {
            Show-CardLine "INI path" $Diagnostics["IniPath"] "DarkGray"
        }
        Show-CardLine "Enigma packed guess" (Format-State $Diagnostics["EnigmaPacked"]) "Gray"
        Show-CardLine "Injection method" $strategy.Name $strategy.Color
        Show-CardLine "Detection confidence" $strategy.Confidence $strategy.Color
        
        Write-Host ""
        Write-Host "             __________________________________________________" -ForegroundColor Gray
        Write-Host ""
        
        Show-MenuItem "1" (Get-Msg "Pack logs as .zip" "Compactar logs em .zip" "Comprimir logs en .zip") ""
        Show-MenuItem "2" (Get-Msg "Send logs to developer" "Enviar logs ao desenvolvedor" "Enviar logs al desarrollador") ""
        Show-MenuItem "3" (Get-Msg "Go back" "Voltar" "Volver") ""
        
        Show-KeyboardPrompt "1,2,3"
        $sherlockChoice = (Read-MenuChoice " > " @("1","2","3") "3").Trim()
        switch ($sherlockChoice) {
            "1" {
                try {
                    $zipPath = New-SherlockZip $ResolvedGameDir $Diagnostics
                    Log ("`n             [+] Sherlock zip created: {0}" -f $zipPath) "Green"
                } catch {
                    Add-Warning ("`n             [!] Could not create Sherlock zip: {0}" -f $_.Exception.Message)
                }
                Wait-GoBack
            }
            "2" {
                try {
                    Send-SherlockWebhook $ResolvedGameDir $Diagnostics
                } catch {
                    Add-Warning ("`n             [!] Webhook send failed: {0}" -f $_.Exception.Message)
                }
                Wait-GoBack
            }
            "3" { return }
            default { return }
        }
    }
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
    Show-FramedMessage @((Get-Msg "Injection Summary :" "Resumo da Injecao :" "Resumen de Inyeccion :"))
    Show-CardLine (Get-Msg "Game Directory" "Diretorio do Jogo" "Directorio del Juego") $ResolvedGameDir "Gray"
    Show-CardLine (Get-Msg "Injection Method" "Metodo de Injecao" "Metodo de Inyeccion") $strategy.Name $strategy.Color
    Show-CardLine (Get-Msg "Confidence" "Confianca" "Confianza") $strategy.Confidence $strategy.Color
    Show-CardLine (Get-Msg "Menu Hotkey" "Atalho do Menu" "Atajo de Menu") $MenuKey "Gray"
    Show-CardLine (Get-Msg "Walk Through Walls Hotkey" "Atalho de Atravesar Paredes" "Atajo de Atravesar Paredes") $WtwKey "Gray"
    Show-CardLine (Get-Msg "Heal Hotkey" "Atalho de Cura" "Atajo de Curacion") $HealKey "Gray"
    Show-CardLine (Get-Msg "Debug On Boot" "Debug no Boot" "Debug al Iniciar") (Format-State $EnableNativeDebugBootstrap) "Gray"
    Show-CardLine (Get-Msg "Compile Bypass" "Bypass de Compilacao" "Bypass de Compilacion") (Format-State $DisableCompilerBootstrap) "Gray"
    Show-CardLine (Get-Msg "Dry Run" "Simular Apenas" "Simular Solo") (Format-State $DryRunMode) "Gray"
    Write-Host "       ______________________________________________________________" -ForegroundColor Gray
}

$InstallReport = [ordered]@{
    GameDir        = ""
    StrategyName   = ""
    StrategyConfidence = ""
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
    Notes          = New-Object System.Collections.Generic.List[string]
    RgssPatchMode  = ""
    PatchMode      = "AUTO"
    IndigoPackInstalled = $false
    IndigoPackUrl = ""
    IndigoFilesCopied = 0
    IndigoBackupPath = ""
    AnimatedSpritesCompatInstalled = $false
}

function Show-ConsoleAnimation {
    param(
        [string]$Message,
        [int]$Cycles = 1,
        [ConsoleColor]$Color = "Green"
    )
    if ($NonInteractive -or $Host.Name -ne "ConsoleHost") { return }
    $frames = @("[=     ]", "[==    ]", "[ ===  ]", "[  === ]", "[    ==]", "[     =]")
    $width = 44
    try {
        for ($cycle = 0; $cycle -lt $Cycles; $cycle++) {
            foreach ($frame in $frames) {
                Write-Host "`r             " -NoNewline
                Write-Host (("{0,-$width}" -f $Message)) -NoNewline -ForegroundColor White
                Write-Host $frame -NoNewline -ForegroundColor $Color
                Start-Sleep -Milliseconds 45
            }
        }
        Write-Host ("`r" + (" " * 75) + "`r") -NoNewline
    } catch {}
}

function Show-StartupAnimation {
    if ($NonInteractive -or $Host.Name -ne "ConsoleHost") { return }
    try {
        Clear-Host
        Write-Host ""
        Write-Host ""
        Write-Host ""
        Write-Host "       ______________________________________________________________" -ForegroundColor Gray
        Write-Host ""
        Write-Host ("                       PokeDebug Installer {0}" -f $PokeDebugInstallerVersion) -ForegroundColor Green
        Write-Host ""
        Show-ConsoleAnimation (Get-Msg "Initializing" "Inicializando" "Inicializando") 2 Green
        Start-Sleep -Milliseconds 90
        Clear-Host
    } catch {}
}

function Show-MasStatus {
    param([string]$Label, [string]$Status, [ConsoleColor]$StatusColor = "Green")
    Write-Host "             " -NoNewline
    Write-Host ("{0,-40}" -f $Label) -NoNewline -ForegroundColor White
    $background = switch ($StatusColor) {
        "Red" { "DarkRed" }
        "Yellow" { "DarkYellow" }
        "Cyan" { "DarkCyan" }
        "Gray" { "DarkGray" }
        default { "DarkGreen" }
    }
    Write-Host (" {0} " -f $Status) -ForegroundColor White -BackgroundColor $background
}

function Show-MasDiagnosticsAnimation {
    param($Diagnostics)
    if ($NonInteractive) { return }
    Show-Section (Get-Msg "System Checks" "Verificacoes do Sistema" "Comprobaciones del Sistema")
    Show-ConsoleAnimation (Get-Msg "Initiating diagnostic tests" "Iniciando testes de diagnostico" "Iniciando pruebas de diagnostico") 1 Green
    Show-MasStatus "Windows PowerShell" $PSVersionTable.PSVersion.ToString() Green
    Start-Sleep -Milliseconds 80
    Show-MasStatus (Get-Msg "Checking game directory" "Verificando diretorio do jogo" "Verificando directorio del juego") (Get-Msg "Found" "Encontrado" "Encontrado") Green
    Start-Sleep -Milliseconds 80
    if ($Diagnostics.HasMkxp) {
        Show-MasStatus (Get-Msg "Checking MKXP-Z runtime" "Verificando runtime MKXP-Z" "Verificando runtime MKXP-Z") (Get-Msg "Found" "Encontrado" "Encontrado") Green
    } else {
        Show-MasStatus (Get-Msg "Checking MKXP-Z runtime" "Verificando runtime MKXP-Z" "Verificando runtime MKXP-Z") (Get-Msg "Not Found" "Nao Encontrado" "No Encontrado") Gray
    }
    Start-Sleep -Milliseconds 80
    if ($Diagnostics.HasScriptsRxdata -or $Diagnostics.HasRgssArchive) {
        Show-MasStatus (Get-Msg "Checking RGSS game data" "Verificando dados RGSS" "Verificando datos RGSS") (Get-Msg "Found" "Encontrado" "Encontrado") Green
    } else {
        Show-MasStatus (Get-Msg "Checking RGSS game data" "Verificando dados RGSS" "Verificando datos RGSS") (Get-Msg "Not Required" "Nao Necessario" "No Necesario") Gray
    }
    Start-Sleep -Milliseconds 120
}

function Resolve-InjectionPlan {
    param($Diagnostics, [string]$PatchMode = "AUTO")
    $mode = $PatchMode.Trim().ToUpperInvariant()
    $hasRgssData = $Diagnostics.HasScriptsRxdata -or $Diagnostics.HasRgssArchive
    if ($mode -eq "MKXP") { return [pscustomobject]@{ UseMkxp = $true; UseRgss = $false; Reason = "Explicit MKXP mode" } }
    if ($mode -eq "RGSS") { return [pscustomobject]@{ UseMkxp = $false; UseRgss = $true; Reason = "Explicit RGSS mode" } }
    if ($mode -eq "BOTH") { return [pscustomobject]@{ UseMkxp = $Diagnostics.HasMkxp; UseRgss = $hasRgssData; Reason = "Explicit dual mode" } }
    if ($Diagnostics.HasMkxp) { return [pscustomobject]@{ UseMkxp = $true; UseRgss = $false; Reason = "MKXP detected and preferred" } }
    return [pscustomobject]@{ UseMkxp = $false; UseRgss = $hasRgssData; Reason = "RGSS data detected without MKXP" }
}

$InstallTransaction = $null

function Start-InstallTransaction {
    param([string[]]$Paths)
    if ($DryRun) { return $null }
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("PokeDebug_Transaction_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $entries = New-Object System.Collections.ArrayList
    $index = 0
    foreach ($candidate in @($Paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
        $fullPath = [System.IO.Path]::GetFullPath($candidate)
        $exists = Test-Path -LiteralPath $fullPath
        $isDirectory = $exists -and (Test-Path -LiteralPath $fullPath -PathType Container)
        $snapshot = Join-Path $root ("entry_{0}" -f $index)
        if ($exists) {
            if ($isDirectory) {
                New-Item -ItemType Directory -Path $snapshot -Force | Out-Null
                Get-ChildItem -LiteralPath $fullPath -Force | Copy-Item -Destination $snapshot -Recurse -Force -ErrorAction Stop
            } else {
                Copy-Item -LiteralPath $fullPath -Destination $snapshot -Force -ErrorAction Stop
            }
        }
        [void]$entries.Add([pscustomobject]@{ Path=$fullPath; Existed=[bool]$exists; IsDirectory=[bool]$isDirectory; Snapshot=$snapshot })
        $index++
    }
    [pscustomobject]@{ Root=$root; Entries=$entries; Active=$true }
}

function Complete-InstallTransaction {
    if ($null -eq $script:InstallTransaction -or -not $script:InstallTransaction.Active) { return }
    $script:InstallTransaction.Active = $false
    Remove-Item -LiteralPath $script:InstallTransaction.Root -Recurse -Force -ErrorAction SilentlyContinue
    $script:InstallTransaction = $null
}

function Undo-InstallTransaction {
    if ($null -eq $script:InstallTransaction -or -not $script:InstallTransaction.Active) { return $false }
    $rollbackErrors = New-Object System.Collections.Generic.List[string]
    $entries = @($script:InstallTransaction.Entries)
    for ($entryIndex = $entries.Count - 1; $entryIndex -ge 0; $entryIndex--) {
        $entry = $entries[$entryIndex]
        try {
            if (Test-Path -LiteralPath $entry.Path) { Remove-Item -LiteralPath $entry.Path -Recurse -Force -ErrorAction Stop }
            if ($entry.Existed) {
                $parent = Split-Path -Parent $entry.Path
                if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
                if ($entry.IsDirectory) {
                    New-Item -ItemType Directory -Path $entry.Path -Force | Out-Null
                    Get-ChildItem -LiteralPath $entry.Snapshot -Force | Copy-Item -Destination $entry.Path -Recurse -Force -ErrorAction Stop
                } else {
                    Copy-Item -LiteralPath $entry.Snapshot -Destination $entry.Path -Force -ErrorAction Stop
                }
            }
        } catch {
            $rollbackErrors.Add(("{0}: {1}" -f $entry.Path, $_.Exception.Message)) | Out-Null
        }
    }
    Remove-Item -LiteralPath $script:InstallTransaction.Root -Recurse -Force -ErrorAction SilentlyContinue
    $script:InstallTransaction.Active = $false
    $script:InstallTransaction = $null
    $InstallReport.RollbackApplied = $true
    if ($rollbackErrors.Count -gt 0) { throw ("Installation rollback was incomplete: " + ($rollbackErrors -join "; ")) }
    return $true
}

function Add-Warning([string]$Message) {
    $InstallReport.Warnings.Add($Message) | Out-Null
    Log $Message "Yellow"
}

function Add-Note([string]$Message) {
    $InstallReport.Notes.Add($Message) | Out-Null
    Log $Message "DarkGray"
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

function Parse-BoolPreference {
    param(
        [string]$Value,
        [Nullable[bool]]$DefaultValue = $null
    )
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $DefaultValue
    }
    switch ($Value.Trim().ToLowerInvariant()) {
        "1" { return $true }
        "true" { return $true }
        "yes" { return $true }
        "y" { return $true }
        "on" { return $true }
        "sim" { return $true }
        "s" { return $true }
        "0" { return $false }
        "false" { return $false }
        "no" { return $false }
        "n" { return $false }
        "off" { return $false }
        "nao" { return $false }
        "não" { return $false }
        default { return $DefaultValue }
    }
}

function Backup-File([string]$Path) {
    if (-not (Test-Path $Path -PathType Leaf)) { return $null }
    $backupPath = "$Path.pokedebug.bak"
    if (-not (Test-Path $backupPath -PathType Leaf)) {
        Copy-Item -Path $Path -Destination $backupPath -Force
    }
    return $backupPath
}

function Restore-BackupFile([string]$Path) {
    $backupCandidates = @(
        "$Path.pokedebug.bak",
        "$Path.bak"
    ) | Select-Object -Unique
    foreach ($backupPath in $backupCandidates) {
        if (-not (Test-Path $backupPath -PathType Leaf)) { continue }
        Copy-Item -Path $backupPath -Destination $Path -Force
        return $true
    }
    return $false
}

function Remove-MkxpPreloadScript([string]$Path, [string]$ScriptName) {
    if (-not (Test-Path $Path -PathType Leaf)) { return $false }

    $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    try {
        $json = $content | ConvertFrom-Json -ErrorAction Stop
        $current = @()
        if ($null -ne $json.preloadScript) {
            if ($json.preloadScript -is [System.Array]) {
                $current = @($json.preloadScript)
            } else {
                $current = @($json.preloadScript)
            }
        }
        if ($current.Count -eq 0) { return $false }
        $filtered = @($current | Where-Object { $_.ToString() -ne $ScriptName })
        if ($filtered.Count -eq $current.Count) { return $false }
        if ($filtered.Count -eq 0) {
            $json.PSObject.Properties.Remove("preloadScript")
        } else {
            $json.preloadScript = $filtered
        }
        $updatedJson = $json | ConvertTo-Json -Depth 32
        [System.IO.File]::WriteAllText($Path, $updatedJson, (New-Object System.Text.UTF8Encoding $false))
        return $true
    } catch {
    }

    $escapedScript = [regex]::Escape($ScriptName)
    $updated = $content
    $updated = [regex]::Replace($updated, ',\s*"' + $escapedScript + '"', '', 1)
    $updated = [regex]::Replace($updated, '"' + $escapedScript + '"\s*,\s*', '', 1)
    $updated = [regex]::Replace($updated, '"preloadScript"\s*:\s*\[\s*"' + $escapedScript + '"\s*\]\s*,?', '', 1)

    if ($updated -ne $content) {
        [System.IO.File]::WriteAllText($Path, $updated, (New-Object System.Text.UTF8Encoding $false))
        return $true
    }

    return $false
}

function Remove-MkxpPreload([string]$Path) {
    Remove-MkxpPreloadScript $Path "preload_gm.rb"
}

function Remove-IfExists([string]$Path) {
    if (Test-Path $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
        return $true
    }
    return $false
}

function Remove-IfExistsSafe([string]$Path) {
    if (-not (Test-Path $Path)) { return $false }
    try {
        Remove-Item -LiteralPath $Path -Recurse -Force
        return $true
    } catch {
        Add-Warning ((Get-Msg "[!] Could not remove: {0}" "[!] Nao foi possivel remover: {0}" "[!] No se pudo eliminar: {0}") -f $Path)
        return $false
    }
}

function Remove-DirectoryIfEmpty([string]$Path) {
    if (-not (Test-Path $Path -PathType Container)) { return $false }
    $hasEntries = Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hasEntries) { return $false }
    try {
        Remove-Item -LiteralPath $Path -Force
        return $true
    } catch {
        return $false
    }
}

function Test-DirectoryWritable([string]$Path) {
    try {
        $probe = Join-Path $Path ".pokedebug_write_test.tmp"
        [System.IO.File]::WriteAllText($probe, "ok", (New-Object System.Text.UTF8Encoding $false))
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

function Write-Utf8FileAtomic {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $temporaryPath = "$Path.pokedebug.tmp"
    $replaceBackupPath = "$Path.pokedebug.replace.bak"
    try {
        [System.IO.File]::WriteAllText($temporaryPath, $Content, (New-Object System.Text.UTF8Encoding $false))
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            Remove-Item -LiteralPath $replaceBackupPath -Force -ErrorAction SilentlyContinue
            [System.IO.File]::Replace($temporaryPath, $Path, $replaceBackupPath, $true)
            Remove-Item -LiteralPath $replaceBackupPath -Force -ErrorAction SilentlyContinue
        } else {
            Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
        }
    } finally {
        Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $replaceBackupPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-Sha256Hex([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return "" }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
}

function Write-PokeDebugManifest {
    param([string]$ResolvedGameDir, [string]$PluginPath, [string]$PreloadPath, [string]$Strategy)
    $manifestPath = Join-Path $ResolvedGameDir "PokeDebug_Install_Manifest.json"
    $pluginText = [System.IO.File]::ReadAllText($PluginPath, [System.Text.Encoding]::UTF8)
    $versionMatch = [regex]::Match($pluginText, 'VERSION\s*=\s*[''"]([^''"]+)[''"]')
    $manifest = [ordered]@{
        schema = 1
        installed_at = (Get-Date).ToUniversalTime().ToString("o")
        strategy = $Strategy
        plugin_version = $(if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "unknown" })
        files = @(
            [ordered]@{ path = "Plugins/God Mode/god_mode.rb"; sha256 = Get-Sha256Hex $PluginPath },
            [ordered]@{ path = "preload_gm.rb"; sha256 = Get-Sha256Hex $PreloadPath }
        )
    }
    Write-Utf8FileAtomic $manifestPath ($manifest | ConvertTo-Json -Depth 8)
    return $manifestPath
}

function Test-PokeDebugInstallation {
    param([string]$PluginPath, [string]$PreloadPath, [string]$MkxpPath, [bool]$ExpectMkxp)
    if (-not (Test-Path -LiteralPath $PluginPath -PathType Leaf)) { throw "Installed god_mode.rb was not found." }
    if ((Get-Item -LiteralPath $PluginPath).Length -lt 64) { throw "Installed god_mode.rb is unexpectedly small." }
    $pluginText = [System.IO.File]::ReadAllText($PluginPath, [System.Text.Encoding]::UTF8)
    if ($pluginText -notmatch 'module\s+DeveloperMenu' -or $pluginText -notmatch 'VERSION\s*=\s*[''"]') {
        throw "Installed god_mode.rb does not contain the required DeveloperMenu version marker."
    }
    if ($ExpectMkxp) {
        if (-not (Test-Path -LiteralPath $PreloadPath -PathType Leaf)) { throw "Installed preload_gm.rb was not found." }
        $preloadText = [System.IO.File]::ReadAllText($PreloadPath, [System.Text.Encoding]::UTF8)
        if ($preloadText -notmatch 'EXPECTED_PLUGIN_SHA256\s*=\s*[''"][0-9a-f]{64}[''"]') { throw "Preload SHA-256 marker is missing." }
        $mkxpText = [System.IO.File]::ReadAllText($MkxpPath, [System.Text.Encoding]::UTF8)
        try {
            $json = ($mkxpText | ConvertFrom-Json -ErrorAction Stop)
            $preloads = @($json.preloadScript)
            if (-not ($preloads | Where-Object { $_.ToString() -eq "preload_gm.rb" })) { throw "mkxp.json does not load preload_gm.rb." }
        } catch {
            # Several MKXP-Z games use JSON5-style comments/trailing commas.
            # Preserve that native format and validate the preload entry in place.
            $activeMkxpText = Get-MkxpActiveText $mkxpText
            if ($activeMkxpText -notmatch '"preloadScript"\s*:\s*\[(?s).*?"preload_gm\.rb".*?\]') {
                throw "mkxp.json could not be parsed and its preload_gm.rb entry was not confirmed."
            }
        }
    }
    return $true
}

function Test-IndigoPokemonRoot([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path -PathType Container)) { return $false }
    $front = Join-Path $Path "Front"
    $back = Join-Path $Path "Back"
    return (Test-Path $front -PathType Container) -and (Test-Path $back -PathType Container)
}

function Find-IndigoPokemonRoot([string]$ExtractedRoot) {
    if (Test-IndigoPokemonRoot $ExtractedRoot) { return $ExtractedRoot }

    $graphicsPokemon = Get-ChildItem -LiteralPath $ExtractedRoot -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\Graphics\\Pokemon$' -and (Test-IndigoPokemonRoot $_.FullName) } |
        Select-Object -First 1
    if ($graphicsPokemon) { return $graphicsPokemon.FullName }

    $firstMatch = Get-ChildItem -LiteralPath $ExtractedRoot -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { Test-IndigoPokemonRoot $_.FullName } |
        Select-Object -First 1
    if ($firstMatch) { return $firstMatch.FullName }

    return $null
}

function Find-IndigoPokemonPackageRoot([string]$ExtractedRoot) {
    if (Test-IndigoPokemonRoot $ExtractedRoot) { return $ExtractedRoot }

    $expectedEntries = @($IndigoPokemonPackFolders + @("substitute.png", "substitute_back.png"))
    foreach ($entry in $expectedEntries) {
        if (Test-Path (Join-Path $ExtractedRoot $entry)) { return $ExtractedRoot }
    }

    $graphicsPokemon = Get-ChildItem -LiteralPath $ExtractedRoot -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\Graphics\\Pokemon$' } |
        Where-Object {
            $candidate = $_.FullName
            $expectedEntries | Where-Object { Test-Path (Join-Path $candidate $_) } | Select-Object -First 1
        } |
        Select-Object -First 1
    if ($graphicsPokemon) { return $graphicsPokemon.FullName }

    $firstMatch = Get-ChildItem -LiteralPath $ExtractedRoot -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            $candidate = $_.FullName
            $expectedEntries | Where-Object { Test-Path (Join-Path $candidate $_) } | Select-Object -First 1
        } |
        Select-Object -First 1
    if ($firstMatch) { return $firstMatch.FullName }

    return $null
}

function Split-IndigoPackageReferences([string]$PackageRefs) {
    if ([string]::IsNullOrWhiteSpace($PackageRefs)) { return @() }
    return @($PackageRefs -split '[;\r\n]+' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Get-GoogleDriveFileId([string]$Url) {
    if ([string]::IsNullOrWhiteSpace($Url)) { return $null }
    if ($Url -match '/file/d/([^/?#]+)') { return $matches[1] }
    if ($Url -match '[?&]id=([^&#]+)') { return [System.Uri]::UnescapeDataString($matches[1]) }
    return $null
}

function Test-ZipFileMagic([string]$Path) {
    if (-not (Test-Path $Path -PathType Leaf)) { return $false }
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        if ($stream.Length -lt 4) { return $false }
        $bytes = New-Object byte[] 4
        [void]$stream.Read($bytes, 0, 4)
        return ($bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B)
    } finally {
        $stream.Dispose()
    }
}

function Get-IndigoPackageCachePath([string]$PackageRef) {
    $cacheRoot = Join-Path $env:LOCALAPPDATA "PokeDebug\IndigoCache"
    if (-not (Test-Path $cacheRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($PackageRef)
        $hash = $sha.ComputeHash($bytes)
        $hashText = -join ($hash | ForEach-Object { $_.ToString("x2") })
    } finally {
        $sha.Dispose()
    }
    return (Join-Path $cacheRoot ("{0}.zip" -f $hashText.Substring(0, 24)))
}

function Invoke-FastWebRequest {
    param(
        [string]$Uri,
        [string]$OutFile = $null,
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession = $null
    )

    $oldProgressPreference = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"
    try {
        $params = @{
            Uri = $Uri
            UseBasicParsing = $true
        }
        if (-not [string]::IsNullOrWhiteSpace($OutFile)) { $params.OutFile = $OutFile }
        if ($WebSession) { $params.WebSession = $WebSession }
        return Invoke-WebRequest @params
    } finally {
        $ProgressPreference = $oldProgressPreference
    }
}

function Save-GoogleDriveFile {
    param(
        [string]$Url,
        [string]$OutFile
    )

    $fileId = Get-GoogleDriveFileId $Url
    if ([string]::IsNullOrWhiteSpace($fileId)) {
        throw (Get-Msg "Could not extract Google Drive file id." "Nao consegui extrair o ID do arquivo do Google Drive." "No pude extraer el ID del archivo de Google Drive.")
    }

    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $baseUrl = "https://drive.google.com/uc?export=download&id=$fileId"
    $response = Invoke-FastWebRequest -Uri $baseUrl -WebSession $session
    $downloadUrl = $baseUrl

    $confirm = $null
    $hiddenParams = @{}
    $formAction = $null
    if ($response.Content -match '<form[^>]+id=["'']download-form["''][^>]+action=["'']([^"'']+)["'']') {
        $formAction = [System.Net.WebUtility]::HtmlDecode($matches[1])
    } elseif ($response.Content -match '<form[^>]+action=["'']([^"'']+)["''][^>]+id=["'']download-form["'']') {
        $formAction = [System.Net.WebUtility]::HtmlDecode($matches[1])
    }
    foreach ($match in [regex]::Matches($response.Content, '<input[^>]+type=["'']hidden["''][^>]*>')) {
        $input = $match.Value
        $inputName = $null
        $inputValue = $null
        if ($input -match 'name=["'']([^"'']+)["'']') { $inputName = [System.Net.WebUtility]::HtmlDecode($matches[1]) }
        if ($input -match 'value=["'']([^"'']*)["'']') { $inputValue = [System.Net.WebUtility]::HtmlDecode($matches[1]) }
        if (-not [string]::IsNullOrWhiteSpace($inputName)) {
            $hiddenParams[$inputName] = $inputValue
        }
    }

    if ($hiddenParams.Count -gt 0) {
        if ([string]::IsNullOrWhiteSpace($formAction)) {
            $formAction = "https://drive.usercontent.google.com/download"
        }
        $queryParts = @()
        foreach ($key in $hiddenParams.Keys) {
            $queryParts += ("{0}={1}" -f [System.Uri]::EscapeDataString($key), [System.Uri]::EscapeDataString([string]$hiddenParams[$key]))
        }
        $downloadUrl = $formAction + "?" + ($queryParts -join "&")
    }

    $warningCookie = $session.Cookies.GetCookies([uri]"https://drive.google.com/") |
        Where-Object { $_.Name -like "download_warning*" } |
        Select-Object -First 1
    if ($warningCookie) { $confirm = $warningCookie.Value }

    $driveLink = $null
    if ($response.Links) {
        $driveLink = $response.Links |
            Where-Object { $_.href -and $_.href -match 'confirm=' } |
            Select-Object -First 1
    }
    if ($hiddenParams.Count -gt 0) {
        # Newer Google Drive warning pages use a hidden form instead of a plain confirm link.
    } elseif ($driveLink) {
        $href = ($driveLink.href -replace '&amp;', '&')
        if ($href -match '^https?://') {
            $downloadUrl = $href
        } else {
            $downloadUrl = "https://drive.google.com$href"
        }
    } else {
        if ([string]::IsNullOrWhiteSpace($confirm) -and $response.Content -match 'confirm=([0-9A-Za-z_\-]+)') {
            $confirm = $matches[1]
        }
        if (-not [string]::IsNullOrWhiteSpace($confirm)) {
            $downloadUrl = "https://drive.google.com/uc?export=download&confirm=$confirm&id=$fileId"
        }
    }

    Invoke-FastWebRequest -Uri $downloadUrl -WebSession $session -OutFile $OutFile | Out-Null
    if (-not (Test-ZipFileMagic $OutFile)) {
        throw (Get-Msg "Downloaded Google Drive file is not a zip. Make sure the link is public/shared and points directly to the zip." "O arquivo baixado do Google Drive nao e um zip. Confirme que o link esta publico/compartilhado e aponta direto para o zip." "El archivo descargado de Google Drive no es un zip. Confirma que el enlace sea publico/compartido y apunte directo al zip.")
    }
}

function Save-IndigoPackageReference {
    param(
        [string]$PackageRef,
        [string]$OutFile
    )

    if ($PackageRef -match '^https?://') {
        $cachePath = Get-IndigoPackageCachePath $PackageRef
        if (Test-ZipFileMagic $cachePath) {
            Log (Get-Msg "[*] Using cached Indigo zip..." "[*] Usando zip Indigo em cache..." "[*] Usando zip Indigo en cache...") "DarkGray"
            Copy-Item -LiteralPath $cachePath -Destination $OutFile -Force
            return
        }

        $partialCachePath = "$cachePath.download"
        if (Test-Path $partialCachePath -PathType Leaf) {
            Remove-Item -LiteralPath $partialCachePath -Force -ErrorAction SilentlyContinue
        }

        try {
            if ($PackageRef -match '(^https?://)?([^/]+\.)?drive\.google\.com/') {
                Save-GoogleDriveFile $PackageRef $partialCachePath
            } else {
                Invoke-FastWebRequest -Uri $PackageRef -OutFile $partialCachePath | Out-Null
                if (-not (Test-ZipFileMagic $partialCachePath)) {
                    throw (Get-Msg "Downloaded file is not a zip." "O arquivo baixado nao e um zip." "El archivo descargado no es un zip.")
                }
            }
            Move-Item -LiteralPath $partialCachePath -Destination $cachePath -Force
            Copy-Item -LiteralPath $cachePath -Destination $OutFile -Force
        } finally {
            Remove-Item -LiteralPath $partialCachePath -Force -ErrorAction SilentlyContinue
        }
    } elseif (Test-Path $PackageRef -PathType Leaf) {
        Copy-Item -LiteralPath $PackageRef -Destination $OutFile -Force
        if (-not (Test-ZipFileMagic $OutFile)) {
            throw (Get-Msg "Selected file is not a zip." "O arquivo selecionado nao e um zip." "El archivo seleccionado no es un zip.")
        }
    } else {
        throw ((Get-Msg "Invalid Indigo zip URL or file path: {0}" "URL ou caminho do zip Indigo invalido: {0}" "URL o ruta del zip Indigo invalida: {0}") -f $PackageRef)
    }
}

function Copy-IndigoPokemonPack {
    param(
        [string]$SourcePokemonRoot,
        [string]$TargetPokemonRoot
    )

    if (-not (Test-Path $TargetPokemonRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $TargetPokemonRoot -Force | Out-Null
    }

    $copied = 0
    foreach ($folder in $IndigoPokemonPackFolders) {
        $sourceFolder = Join-Path $SourcePokemonRoot $folder
        if (-not (Test-Path $sourceFolder -PathType Container)) { continue }

        $targetFolder = Join-Path $TargetPokemonRoot $folder
        New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
        Copy-Item -Path (Join-Path $sourceFolder "*") -Destination $targetFolder -Recurse -Force
        $copied += (Get-ChildItem -LiteralPath $sourceFolder -File -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
    }

    foreach ($fileName in @("substitute.png", "substitute_back.png")) {
        $sourceFile = Join-Path $SourcePokemonRoot $fileName
        if (-not (Test-Path $sourceFile -PathType Leaf)) { continue }
        Copy-Item -LiteralPath $sourceFile -Destination (Join-Path $TargetPokemonRoot $fileName) -Force
        $copied++
    }

    return $copied
}

function Get-AnimatedSpritesCompatContent {
    $SourceAnimatedSprites = Join-Path $PSScriptRoot "animated_sprites_compat.rb"
    if (Get-Variable animatedSpritesCompatBase64 -ErrorAction SilentlyContinue) {
        return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($animatedSpritesCompatBase64))
    }
    if (Test-Path $SourceAnimatedSprites -PathType Leaf) {
        return [System.IO.File]::ReadAllText($SourceAnimatedSprites, [System.Text.Encoding]::UTF8)
    }
    return $null
}

function Install-AnimatedSpritesCompat {
    param([string]$ResolvedGameDir)

    $content = Get-AnimatedSpritesCompatContent
    if ([string]::IsNullOrWhiteSpace($content)) {
        throw (Get-Msg "animated_sprites.rb source was not found." "Fonte animated_sprites.rb nao encontrada." "Fuente animated_sprites.rb no encontrada.")
    }

    $destRoot = Join-Path $ResolvedGameDir "animated_sprites.rb"
    $pluginDir = Join-Path $ResolvedGameDir "Plugins\Animated Sprites"
    $destPlugin = Join-Path $pluginDir "animated_sprites_compat.rb"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false

    [System.IO.File]::WriteAllText($destRoot, $content, $utf8NoBom)
    Remove-Item -LiteralPath $destPlugin -Force -ErrorAction SilentlyContinue
    $InstallReport.AnimatedSpritesCompatInstalled = $true
}

function Enable-AnimatedSpritesCompatLoaders {
    param([string]$ResolvedGameDir)

    $enabled = $false
    $jsonPath = Join-Path $ResolvedGameDir "mkxp.json"
    if (Test-Path $jsonPath -PathType Leaf) {
        [void](Backup-File $jsonPath)
        if (Test-Path (Join-Path $ResolvedGameDir "preload_gm.rb") -PathType Leaf) {
            [void](Remove-MkxpPreloadScript $jsonPath "animated_sprites_compat.rb")
            $result = Add-MkxpPreloadScript $jsonPath "animated_sprites.rb"
            if ($result.Changed -or $result.Reason -eq "already_present") {
                $enabled = $true
                Add-Note (Get-Msg "[+] MKXP loader enabled for animated sprites." "[+] Loader MKXP ativado para sprites animados." "[+] Loader MKXP activado para sprites animados.")
            } else {
                Add-Warning ((Get-Msg "[!] Could not update mkxp.json for animated sprites: {0}" "[!] Nao foi possivel atualizar mkxp.json para sprites animados: {0}" "[!] No se pudo actualizar mkxp.json para sprites animados: {0}") -f $result.Reason)
            }
        } else {
            $result = Add-MkxpPreloadScript $jsonPath "animated_sprites.rb"
            if ($result.Changed -or $result.Reason -eq "already_present") {
                [void](Remove-MkxpPreloadScript $jsonPath "animated_sprites_compat.rb")
                $enabled = $true
                Add-Note (Get-Msg "[+] MKXP loader enabled for animated sprites." "[+] Loader MKXP ativado para sprites animados." "[+] Loader MKXP activado para sprites animados.")
            } else {
                Add-Warning ((Get-Msg "[!] Could not update mkxp.json for animated sprites: {0}" "[!] Nao foi possivel atualizar mkxp.json para sprites animados: {0}" "[!] No se pudo actualizar mkxp.json para sprites animados: {0}") -f $result.Reason)
            }
        }
    }

    $rxData = Join-Path $ResolvedGameDir "Data\Scripts.rxdata"
    $rgssFiles = Get-ChildItem -Path $ResolvedGameDir -Filter "*.rgss*a*" -ErrorAction SilentlyContinue
    if (($rgssFiles.Count -gt 0 -or (Test-Path $rxData -PathType Leaf)) -and (-not (Test-Path $jsonPath -PathType Leaf))) {
        try {
            $rgssPatchMode = [RgssPatcher]::ApplyPatch($ResolvedGameDir)
            $InstallReport.RgssPatchMode = $rgssPatchMode
            $InstallReport.RgssInjected = $true
            $enabled = $true

            $iniPath = Get-GameIniPath $ResolvedGameDir
            if (($rgssPatchMode -eq "raw" -or $rgssPatchMode -eq "archive_to_raw" -or $rgssPatchMode -eq "raw_and_archive") -and (Test-Path $iniPath)) {
                [void](Backup-File $iniPath)
                (Get-Content $iniPath) -replace "^Scripts=.*", "Scripts=Data\Scripts.rxdata" | Set-Content $iniPath -Encoding ASCII
                $InstallReport.IniUpdated = $true
            }
            Add-Note (Get-Msg "[+] RGSS loader enabled for animated sprites." "[+] Loader RGSS ativado para sprites animados." "[+] Loader RGSS activado para sprites animados.")
        } catch {
            Add-Warning ((Get-Msg "[!] Could not patch RGSS loader for animated sprites: {0}" "[!] Nao foi possivel aplicar loader RGSS para sprites animados: {0}" "[!] No se pudo aplicar loader RGSS para sprites animados: {0}") -f $_.Exception.Message)
        }
    }

    if (-not $enabled) {
        Add-Warning (Get-Msg "[!] Animated sprites patch was copied, but no automatic loader was enabled." "[!] Patch de sprites animados copiado, mas nenhum loader automatico foi ativado." "[!] Parche de sprites animados copiado, pero ningun loader automatico fue activado.")
    }
}

function Install-IndigoPokemonPack {
    param(
        [string]$ResolvedGameDir,
        [string]$ZipUrl,
        [bool]$SkipBackup = $false
    )

    $url = $ZipUrl
    if ([string]::IsNullOrWhiteSpace($url)) { $url = $DefaultIndigoPokemonZipUrl }
    $packageRefs = @(Split-IndigoPackageReferences $url)
    if ($packageRefs.Count -eq 0) {
        throw (Get-Msg "No Indigo zip URL was provided." "Nenhuma URL do zip Indigo foi informada." "No se informo ninguna URL del zip Indigo.")
    }

    $targetPokemonRoot = Join-Path $ResolvedGameDir "Graphics\AnimatedBattlers"
    if (-not (Test-Path (Join-Path $ResolvedGameDir "Graphics") -PathType Container)) {
        throw (Get-Msg "Target game does not have a Graphics folder." "O jogo alvo nao tem pasta Graphics." "El juego destino no tiene carpeta Graphics.")
    }

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("PokeDebug_Indigo_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    try {
        if ($DryRun.IsPresent) {
            Add-Note (Get-Msg "[DryRun] Indigo pack was validated but not copied." "[DryRun] Pacote Indigo validado, mas nao copiado." "[DryRun] Paquete Indigo validado, pero no copiado.")
            return 0
        }

        if ((Test-Path $targetPokemonRoot -PathType Container) -and (-not $SkipBackup)) {
            $backupDir = Join-Path $ResolvedGameDir "PokeDebug_Backups"
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            $backupZip = Join-Path $backupDir ("AnimatedBattlers_Before_Indigo_{0}.zip" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
            Log (Get-Msg "[*] Backing up current Graphics\\AnimatedBattlers..." "[*] Fazendo backup do Graphics\\AnimatedBattlers atual..." "[*] Respaldando Graphics\\AnimatedBattlers actual...") "Cyan"
            Compress-Archive -Path (Join-Path $targetPokemonRoot "*") -DestinationPath $backupZip -Force
            $InstallReport.IndigoBackupPath = $backupZip
        } elseif ((Test-Path $targetPokemonRoot -PathType Container) -and $SkipBackup) {
            Add-Note (Get-Msg "[*] Indigo Graphics\\AnimatedBattlers backup skipped by user." "[*] Backup do Graphics\\AnimatedBattlers do Indigo pulado pelo usuario." "[*] Copia de seguridad de Graphics\\AnimatedBattlers de Indigo omitida por el usuario.")
        }

        Log (Get-Msg "[*] Installing Indigo Pokemon pack..." "[*] Instalando pacote Pokemon do Indigo..." "[*] Instalando paquete Pokemon de Indigo...") "Cyan"
        $copied = 0
        for ($i = 0; $i -lt $packageRefs.Count; $i++) {
            $packageRef = $packageRefs[$i]
            $zipPath = Join-Path $tempDir ("indigo_pokemon_pack_{0}.zip" -f ($i + 1))
            $extractDir = Join-Path $tempDir ("extract_{0}" -f ($i + 1))
            New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

            Log ((Get-Msg "[*] Downloading Indigo pack part {0}/{1}..." "[*] Baixando parte {0}/{1} do pack Indigo..." "[*] Descargando parte {0}/{1} del pack Indigo...") -f ($i + 1), $packageRefs.Count) "Cyan"
            Save-IndigoPackageReference $packageRef $zipPath

            Log ((Get-Msg "[*] Extracting Indigo pack part {0}/{1}..." "[*] Extraindo parte {0}/{1} do pack Indigo..." "[*] Extrayendo parte {0}/{1} del pack Indigo...") -f ($i + 1), $packageRefs.Count) "Cyan"
            Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force

            $sourcePokemonRoot = Find-IndigoPokemonPackageRoot $extractDir
            if ([string]::IsNullOrWhiteSpace($sourcePokemonRoot)) {
                throw ((Get-Msg "Could not find Pokemon folders inside zip part: {0}" "Nao encontrei pastas Pokemon dentro da parte zip: {0}" "No encontre carpetas Pokemon dentro de la parte zip: {0}") -f $packageRef)
            }
            $copied += Copy-IndigoPokemonPack $sourcePokemonRoot $targetPokemonRoot
        }
        Install-AnimatedSpritesCompat $ResolvedGameDir
        Enable-AnimatedSpritesCompatLoaders $ResolvedGameDir

        $InstallReport.IndigoPackInstalled = $true
        $InstallReport.IndigoPackUrl = ($packageRefs -join ";")
        $InstallReport.IndigoFilesCopied = $copied

        Add-Note (Get-Msg "[+] Animated sprites compatibility patch installed." "[+] Patch de compatibilidade de sprites animados instalado." "[+] Parche de compatibilidad de sprites animados instalado.")
        Add-Note ((Get-Msg "[+] Indigo Pokemon pack installed. Files copied: {0}" "[+] Pacote Pokemon do Indigo instalado. Arquivos copiados: {0}" "[+] Paquete Pokemon de Indigo instalado. Archivos copiados: {0}") -f $copied)
        return $copied
    } finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-RunningGameProcesses([string]$ResolvedGameDir) {
    $matches = New-Object System.Collections.Generic.List[object]
    $normalizedDir = [System.IO.Path]::GetFullPath($ResolvedGameDir)
    $currentPid = $PID
    Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $processId = $_.Id
            $processName = ""
            try { $processName = [string]$_.ProcessName } catch { $processName = "" }
            if ($processId -eq $currentPid) { return }
            if ($processName -match '^powershell(|_ise)$') { return }
            if ($processName -eq "PokeDebug_Installer") { return }
            $processPath = $_.MainModule.FileName
            if (-not [string]::IsNullOrWhiteSpace($processPath)) {
                $fullProcessPath = [System.IO.Path]::GetFullPath($processPath)
                if ($fullProcessPath.StartsWith($normalizedDir, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $matches.Add([pscustomobject]@{
                        Id = $processId
                        ProcessName = $(if ([string]::IsNullOrWhiteSpace($processName)) { [System.IO.Path]::GetFileNameWithoutExtension($fullProcessPath) } else { $processName })
                        Path = $fullProcessPath
                    }) | Out-Null
                }
            }
        } catch {
        }
    }
    $matches
}

function Get-InstallReportPath([string]$ResolvedGameDir) {
    Join-Path $ResolvedGameDir "PokeDebug_Install_Report.txt"
}

function Get-SpritesReportPath([string]$ResolvedGameDir) {
    Join-Path $ResolvedGameDir "PokeDebug_Sprites_Report.txt"
}

function Write-SpritesReportFile([string]$ResolvedGameDir) {
    $lines = @()
    $lines += "=== PokeDebug Animated Sprites Report ==="
    $lines += ("Timestamp: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
    $lines += ("GameDir: {0}" -f $ResolvedGameDir)
    $lines += ("IndigoPackInstalled: {0}" -f $InstallReport.IndigoPackInstalled)
    $lines += ("IndigoPackUrl: {0}" -f $InstallReport.IndigoPackUrl)
    $lines += ("IndigoFilesCopied: {0}" -f $InstallReport.IndigoFilesCopied)
    $lines += ("IndigoBackupPath: {0}" -f $InstallReport.IndigoBackupPath)
    $lines += ("AnimatedSpritesCompatInstalled: {0}" -f $InstallReport.AnimatedSpritesCompatInstalled)
    $lines += ("MkxpInjected: {0}" -f $InstallReport.MkxpInjected)
    $lines += ("RgssInjected: {0}" -f $InstallReport.RgssInjected)
    $lines += ("RgssPatchMode: {0}" -f $InstallReport.RgssPatchMode)
    $lines += ("IniUpdated: {0}" -f $InstallReport.IniUpdated)
    $lines += ""
    $lines += "Notes:"
    if ($InstallReport.Notes.Count -gt 0) {
        $InstallReport.Notes | ForEach-Object { $lines += ("- {0}" -f $_) }
    } else {
        $lines += "- None"
    }
    $lines += ""
    $lines += "Warnings:"
    if ($InstallReport.Warnings.Count -gt 0) {
        $InstallReport.Warnings | ForEach-Object { $lines += ("- {0}" -f $_) }
    } else {
        $lines += "- None"
    }
    $reportPath = Get-SpritesReportPath $ResolvedGameDir
    [System.IO.File]::WriteAllLines($reportPath, $lines, (New-Object System.Text.UTF8Encoding $false))
    return $reportPath
}

function Write-InstallReportFile([string]$ResolvedGameDir) {
    $lines = @()
    $lines += "=== PokeDebug Install Report ==="
    $lines += ("Timestamp: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
    $lines += ("GameDir: {0}" -f $InstallReport.GameDir)
    $lines += ("Strategy: {0}" -f $InstallReport.StrategyName)
    $lines += ("StrategyConfidence: {0}" -f $InstallReport.StrategyConfidence)
    $lines += ("DryRun: {0}" -f $InstallReport.DryRun)
    $lines += ("Uninstall: {0}" -f $InstallReport.Uninstall)
    $lines += ("RestoreBackups: {0}" -f $InstallReport.RestoreBackups)
    $lines += ("GodModeCopied: {0}" -f $InstallReport.GodModeCopied)
    $lines += ("PreloadCopied: {0}" -f $InstallReport.PreloadCopied)
    $lines += ("NativeDebugBootstrap: {0}" -f $InstallReport.NativeDebugBootstrap)
    $lines += ("CompilerBypassBootstrap: {0}" -f $InstallReport.CompilerBypassBootstrap)
    $lines += ("MkxpInjected: {0}" -f $InstallReport.MkxpInjected)
    $lines += ("RgssInjected: {0}" -f $InstallReport.RgssInjected)
    $lines += ("IniUpdated: {0}" -f $InstallReport.IniUpdated)
    $lines += ("RollbackApplied: {0}" -f $InstallReport.RollbackApplied)
    $lines += ("IndigoPackInstalled: {0}" -f $InstallReport.IndigoPackInstalled)
    $lines += ("IndigoPackUrl: {0}" -f $InstallReport.IndigoPackUrl)
    $lines += ("IndigoFilesCopied: {0}" -f $InstallReport.IndigoFilesCopied)
    $lines += ("IndigoBackupPath: {0}" -f $InstallReport.IndigoBackupPath)
    $lines += ("AnimatedSpritesCompatInstalled: {0}" -f $InstallReport.AnimatedSpritesCompatInstalled)
    $lines += ""
    $lines += "Warnings:"
    if ($InstallReport.Warnings.Count -gt 0) {
        $InstallReport.Warnings | ForEach-Object { $lines += ("- {0}" -f $_) }
    } else {
        $lines += "- None"
    }
    $lines += ""
    $lines += "Notes:"
    if ($InstallReport.Notes.Count -gt 0) {
        $InstallReport.Notes | ForEach-Object { $lines += ("- {0}" -f $_) }
    } else {
        $lines += "- None"
    }
    $reportPath = Get-InstallReportPath $ResolvedGameDir
    [System.IO.File]::WriteAllLines($reportPath, $lines, (New-Object System.Text.UTF8Encoding $false))
    return $reportPath
}

function Run-Uninstall([string]$ResolvedGameDir) {
    Log (Get-Msg "[*] Starting uninstall / rollback..." "[*] Iniciando desinstalacao / rollback..." "[*] Iniciando desinstalacion / rollback...") "Cyan"

    $pluginDir = Join-Path $ResolvedGameDir "Plugins\God Mode"
    $animatedSpritesPluginDir = Join-Path $ResolvedGameDir "Plugins\Animated Sprites"
    $pluginsRoot = Split-Path $pluginDir -Parent
    $preloadPath = Join-Path $ResolvedGameDir "preload_gm.rb"
    $animatedSpritesRootPath = Join-Path $ResolvedGameDir "animated_sprites.rb"
    $mkxpPath = Join-Path $ResolvedGameDir "mkxp.json"
    $rxDataPath = Join-Path $ResolvedGameDir "Data\Scripts.rxdata"
    $iniPath = Get-GameIniPath $ResolvedGameDir
    $reportPath = Get-InstallReportPath $ResolvedGameDir
    $manifestPath = Join-Path $ResolvedGameDir "PokeDebug_Install_Manifest.json"
    $spritesReportPath = Get-SpritesReportPath $ResolvedGameDir
    $menuErrorLogPath = Join-Path $ResolvedGameDir "developer_menu_errors.log"
    $archive = Get-ChildItem -Path $ResolvedGameDir -Filter "*.rgss*a*" -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $DryRun) {
        if (-not (Restore-BackupFile $mkxpPath)) {
            if (Remove-MkxpPreload $mkxpPath) { $InstallReport.RollbackApplied = $true }
            if (Remove-MkxpPreloadScript $mkxpPath "animated_sprites_compat.rb") { $InstallReport.RollbackApplied = $true }
            if (Remove-MkxpPreloadScript $mkxpPath "animated_sprites.rb") { $InstallReport.RollbackApplied = $true }
        } else {
            $InstallReport.RollbackApplied = $true
        }

        if (Restore-BackupFile $rxDataPath) { $InstallReport.RollbackApplied = $true }
        if ($archive -and (Restore-BackupFile $archive.FullName)) { $InstallReport.RollbackApplied = $true }
        if (Restore-BackupFile $iniPath) { $InstallReport.RollbackApplied = $true }

        if (Remove-IfExistsSafe $preloadPath) { $InstallReport.RollbackApplied = $true }
        if (Remove-IfExistsSafe $animatedSpritesRootPath) { $InstallReport.RollbackApplied = $true }
        if (Remove-IfExistsSafe $animatedSpritesPluginDir) { $InstallReport.RollbackApplied = $true }
        if (Remove-IfExistsSafe $pluginDir) { $InstallReport.RollbackApplied = $true }
        [void](Remove-DirectoryIfEmpty $pluginsRoot)
        [void](Remove-IfExistsSafe $menuErrorLogPath)
        [void](Remove-IfExistsSafe $reportPath)
        [void](Remove-IfExistsSafe $manifestPath)
        [void](Remove-IfExistsSafe $spritesReportPath)
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

function Get-MkxpActiveText([string]$Content) {
    # MKXP commonly ships JSON5-style templates whose example properties are
    # commented out. Ignore full-line comments so they can never be mistaken
    # for an active preloadScript configuration.
    return (($Content -split "`r?`n") | Where-Object { $_ -notmatch '^\s*//' }) -join [Environment]::NewLine
}

function Update-MkxpPreload([string]$Path) {
    $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    try {
        $json = $content | ConvertFrom-Json -ErrorAction Stop
        $current = @()
        if ($null -ne $json.preloadScript) {
            if ($json.preloadScript -is [System.Array]) {
                $current = @($json.preloadScript)
            } else {
                $current = @($json.preloadScript)
            }
        }
        if ($current | Where-Object { $_.ToString() -eq "preload_gm.rb" }) {
            return @{ Changed = $false; Reason = "already_present" }
        }
        $json | Add-Member -NotePropertyName preloadScript -NotePropertyValue @() -Force
        $json.preloadScript = @($current + "preload_gm.rb")
        $updatedJson = $json | ConvertTo-Json -Depth 32
        if ($updatedJson -eq $content) {
            return @{ Changed = $false; Reason = "no_changes" }
        }
        Write-Utf8FileAtomic $Path $updatedJson
        return @{ Changed = $true; Reason = "updated" }
    } catch {
    }

    $activeContent = Get-MkxpActiveText $content
    if ($activeContent -match '"preloadScript"\s*:\s*\[(?s).*?"preload_gm\.rb".*?\]') {
        return @{ Changed = $false; Reason = "already_present" }
    }

    $updated = $content
    $activeArrayPattern = '(?ms)^(?![ \t]*//)[ \t]*"preloadScript"\s*:\s*\[(.*?)\]'
    $activeStringPattern = '(?m)^(?![ \t]*//)[ \t]*"preloadScript"\s*:\s*"(.*?)"'
    if ($content -match $activeArrayPattern) {
        $updated = [regex]::Replace(
            $content,
            $activeArrayPattern,
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
    } elseif ($content -match $activeStringPattern) {
        $updated = [regex]::Replace($content, $activeStringPattern, '"preloadScript": ["$1", "preload_gm.rb"]', 1)
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

function Add-MkxpPreloadScript([string]$Path, [string]$ScriptName) {
    $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $escapedScript = [regex]::Escape($ScriptName)
    $quotedScript = '"' + ($ScriptName -replace '\\', '\\' -replace '"', '\"') + '"'
    try {
        $json = $content | ConvertFrom-Json -ErrorAction Stop
        $current = @()
        if ($null -ne $json.preloadScript) {
            if ($json.preloadScript -is [System.Array]) {
                $current = @($json.preloadScript)
            } else {
                $current = @($json.preloadScript)
            }
        }
        if ($current | Where-Object { $_.ToString() -eq $ScriptName }) {
            return @{ Changed = $false; Reason = "already_present" }
        }
        $json | Add-Member -NotePropertyName preloadScript -NotePropertyValue @() -Force
        $json.preloadScript = @($current + $ScriptName)
        $updatedJson = $json | ConvertTo-Json -Depth 32
        [System.IO.File]::WriteAllText($Path, $updatedJson, (New-Object System.Text.UTF8Encoding $false))
        return @{ Changed = $true; Reason = "updated" }
    } catch {
        $jsonError = $_.Exception.Message
    }

    if ($content -match ('"preloadScript"\s*:\s*\[(?s).*?"' + $escapedScript + '".*?\]')) {
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
                    '"preloadScript": [' + $quotedScript + ']'
                } else {
                    '"preloadScript": [' + $inner.TrimEnd() + ', ' + $quotedScript + ']'
                }
            },
            1
        )
    } elseif ($content -match '"preloadScript"\s*:\s*"(.*?)"') {
        $updated = [regex]::Replace($content, '"preloadScript"\s*:\s*"(.*?)"', ('"preloadScript": ["$1", ' + $quotedScript + ']'), 1)
    } else {
        $match = [regex]::Match($content, '\}(?![\s\S]*\})')
        if (-not $match.Success) {
            return @{ Changed = $false; Reason = $jsonError }
        }

        $before = $content.Substring(0, $match.Index)
        $beforeTrimmed = $before.TrimEnd()
        if ($beforeTrimmed.Length -gt 0 -and -not $beforeTrimmed.EndsWith("{") -and -not $beforeTrimmed.EndsWith(",")) {
            $before = $beforeTrimmed + "," + $before.Substring($beforeTrimmed.Length)
        }
        $updated = $before + [Environment]::NewLine + '  "preloadScript": [' + $quotedScript + ']' + $content.Substring($match.Index)
    }

    if ($updated -eq $content) {
        return @{ Changed = $false; Reason = "no_changes" }
    }

    [System.IO.File]::WriteAllText($Path, $updated, (New-Object System.Text.UTF8Encoding $false))
    return @{ Changed = $true; Reason = "updated" }
}

function Set-MkxpPreloadScriptBefore([string]$Path, [string]$ScriptName, [string]$BeforeScriptName) {
    if (-not (Test-Path $Path -PathType Leaf)) { return @{ Changed = $false; Reason = "missing" } }
    $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $scripts = New-Object System.Collections.Generic.List[string]
    if ($content -match '"preloadScript"\s*:\s*\[(?s)(.*?)\]') {
        $inner = $matches[1]
        foreach ($match in [regex]::Matches($inner, '"([^"]+)"')) {
            $value = $match.Groups[1].Value
            if ($value -ne $ScriptName) { [void]$scripts.Add($value) }
        }
        if (-not ($scripts | Where-Object { $_ -eq $BeforeScriptName })) {
            return @{ Changed = $false; Reason = "before_script_missing" }
        }
        $ordered = New-Object System.Collections.Generic.List[string]
        foreach ($item in $scripts) {
            if ($item -eq $BeforeScriptName) { [void]$ordered.Add($ScriptName) }
            [void]$ordered.Add($item)
        }
        $lines = @('"preloadScript": [')
        for ($i = 0; $i -lt $ordered.Count; $i++) {
            $comma = if ($i -lt ($ordered.Count - 1)) { "," } else { "" }
            $escaped = $ordered[$i] -replace '\\', '\\' -replace '"', '\"'
            $lines += ('        "{0}"{1}' -f $escaped, $comma)
        }
        $lines += '    ]'
        $replacement = $lines -join [Environment]::NewLine
        $updated = [regex]::Replace($content, '"preloadScript"\s*:\s*\[(?s)(.*?)\]', $replacement, 1)
        if ($updated -eq $content) { return @{ Changed = $false; Reason = "no_changes" } }
        [System.IO.File]::WriteAllText($Path, $updated, (New-Object System.Text.UTF8Encoding $false))
        return @{ Changed = $true; Reason = "updated" }
    }
    return @{ Changed = $false; Reason = "preloadScript_missing" }
}

function Set-MkxpPreloadScriptAfter([string]$Path, [string]$ScriptName, [string]$AfterScriptName) {
    if (-not (Test-Path $Path -PathType Leaf)) { return @{ Changed = $false; Reason = "missing" } }
    $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $scripts = New-Object System.Collections.Generic.List[string]
    if ($content -match '"preloadScript"\s*:\s*\[(?s)(.*?)\]') {
        $inner = $matches[1]
        foreach ($match in [regex]::Matches($inner, '"([^"]+)"')) {
            $value = $match.Groups[1].Value
            if ($value -ne $ScriptName) { [void]$scripts.Add($value) }
        }
        if (-not ($scripts | Where-Object { $_ -eq $AfterScriptName })) {
            return @{ Changed = $false; Reason = "after_script_missing" }
        }
        $ordered = New-Object System.Collections.Generic.List[string]
        foreach ($item in $scripts) {
            [void]$ordered.Add($item)
            if ($item -eq $AfterScriptName) { [void]$ordered.Add($ScriptName) }
        }
        $lines = @('"preloadScript": [')
        for ($i = 0; $i -lt $ordered.Count; $i++) {
            $comma = if ($i -lt ($ordered.Count - 1)) { "," } else { "" }
            $escaped = $ordered[$i] -replace '\\', '\\' -replace '"', '\"'
            $lines += ('        "{0}"{1}' -f $escaped, $comma)
        }
        $lines += '    ]'
        $replacement = $lines -join [Environment]::NewLine
        $updated = [regex]::Replace($content, '"preloadScript"\s*:\s*\[(?s)(.*?)\]', $replacement, 1)
        if ($updated -eq $content) { return @{ Changed = $false; Reason = "no_changes" } }
        [System.IO.File]::WriteAllText($Path, $updated, (New-Object System.Text.UTF8Encoding $false))
        return @{ Changed = $true; Reason = "updated" }
    }
    return @{ Changed = $false; Reason = "preloadScript_missing" }
}

$csharpPatcher = @'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;
using System.IO.Compression;

public class RgssPatcher {
    public static string ApplyPatch(string gameDir) {
        string[] archives = Directory.GetFiles(gameDir, "*.rgss*a*");
        string archivePath = archives.Length > 0 ? archives[0] : null;
        string rawRxdata = Path.Combine(gameDir, "Data", "Scripts.rxdata");
        
        if (File.Exists(rawRxdata) && archivePath != null) {
            PatchRawFile(rawRxdata);
            try {
                PatchArchiveInPlace(archivePath, gameDir);
                return "raw_and_archive";
            } catch {
                return "raw";
            }
        } else if (File.Exists(rawRxdata)) {
            PatchRawFile(rawRxdata);
            return "raw";
        } else if (archivePath != null) {
            ExportPatchedRawFromArchive(archivePath, rawRxdata);
            return "archive_to_raw";
        } else {
            throw new Exception("Game.rgssad / Scripts.rxdata not found!");
        }
    }

    private static string BackupPathFor(string path) {
        return path + ".pokedebug.bak";
    }

    private static void PatchRawFile(string path) {
        byte[] data = File.ReadAllBytes(path);
        byte[] newScripts = InjectPayload(data, Path.GetDirectoryName(Path.GetDirectoryName(path)));
        string backupPath = BackupPathFor(path);
        if (!File.Exists(backupPath)) File.Copy(path, backupPath, true);
        File.WriteAllBytes(path, newScripts);
    }

    private static void ExportPatchedRawFromArchive(string archivePath, string rawRxdata) {
        string dataDir = Path.GetDirectoryName(rawRxdata);
        if (!Directory.Exists(dataDir)) Directory.CreateDirectory(dataDir);
        string backupPath = BackupPathFor(rawRxdata);
        if (File.Exists(rawRxdata) && !File.Exists(backupPath)) File.Copy(rawRxdata, backupPath, true);
        byte[] newScripts = InjectPayload(ExtractScriptsFromArchive(archivePath), Path.GetDirectoryName(archivePath));
        File.WriteAllBytes(rawRxdata, newScripts);
    }

    private static void PatchArchiveInPlace(string archivePath, string gameDir) {
        string bakPath = BackupPathFor(archivePath);
        if (!File.Exists(bakPath)) File.Copy(archivePath, bakPath);
        byte[] originalScripts = ExtractScriptsFromArchive(archivePath);
        byte[] newScripts = InjectPayload(originalScripts, gameDir);

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

    private static byte[] ExtractScriptsFromArchive(string archivePath) {
        string bakPath = BackupPathFor(archivePath);
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
                throw new Exception("Unsupported archive encryption version. Only RGSSAD v1 is currently patchable by this installer.");
            }
        }
        
        if (originalScripts == null) throw new Exception("Scripts.rxdata missing from archive.");
        return originalScripts;
    }

    private static byte[] InjectPayload(byte[] original, string gameDir) {
        List<ScriptBlockCandidate> candidates = FindInjectableScriptBlocks(original);
        if (candidates.Count == 0) throw new Exception("Failed to locate a valid startup script block.");

        string inject = BuildBootstrapScript(gameDir);

        using (MemoryStream ms = new MemoryStream())
        using (BinaryWriter bw = new BinaryWriter(ms)) {
            int cursor = 0;
            foreach (ScriptBlockCandidate candidate in candidates) {
                int zlibStart = candidate.StartOffset;
                int scriptEnd = candidate.EndOffset;
                string rubyCode = candidate.Code;
                string patchedCode = rubyCode.Contains("animated_sprites.rb") || rubyCode.Contains("animated_sprites_compat.rb") ? rubyCode : inject + rubyCode;
                byte[] newZlib = Compress(patchedCode);

                bw.Write(original, cursor, zlibStart - cursor);
                bw.Write((byte)'"');
                WriteInt(bw, newZlib.Length);
                bw.Write(newZlib);
                cursor = scriptEnd;
            }
            bw.Write(original, cursor, original.Length - cursor);
            return ms.ToArray();
        }
    }

    private static string EscapeRubySingleQuotedPath(string path) {
        if (string.IsNullOrEmpty(path)) return "";
        return path.Replace("\\", "/").Replace("'", "\\\\'");
    }

    private static string BuildBootstrapScript(string gameDir) {
        string pluginPath = EscapeRubySingleQuotedPath(Path.Combine(gameDir, "Plugins", "God Mode", "god_mode.rb"));
        string animatedRootPath = EscapeRubySingleQuotedPath(Path.Combine(gameDir, "animated_sprites.rb"));
        string logPath = EscapeRubySingleQuotedPath(Path.Combine(gameDir, "developer_menu_errors.log"));
        return "begin\r\n" +
               "  unless defined?(POKEDEBUG_RUNTIME_LOADED) && POKEDEBUG_RUNTIME_LOADED\r\n" +
               "    POKEDEBUG_RUNTIME_LOADED = true\r\n" +
               "    log_path = '" + logPath + "'\r\n" +
               "    begin\r\n" +
               "      File.open(log_path, 'a') {|f| f.puts '[PokeDebug/Sprites RGSS bootstrap reached]' }\r\n" +
               "    rescue\r\n" +
               "    end\r\n" +
               "    candidates = []\r\n" +
               "    candidates << '" + pluginPath + "'\r\n" +
               "    candidates << File.expand_path('Plugins/God Mode/god_mode.rb', Dir.pwd)\r\n" +
               "    begin\r\n" +
               "      candidates << File.expand_path('Plugins/God Mode/god_mode.rb', File.dirname($0)) if $0\r\n" +
               "    rescue\r\n" +
               "    end\r\n" +
               "    begin\r\n" +
               "      candidates << File.expand_path('Game/Plugins/God Mode/god_mode.rb', File.dirname($0)) if $0\r\n" +
               "    rescue\r\n" +
               "    end\r\n" +
               "    begin\r\n" +
               "      candidates << File.expand_path('../Plugins/God Mode/god_mode.rb', Dir.pwd)\r\n" +
               "    rescue\r\n" +
               "    end\r\n" +
               "    animated_candidates = []\r\n" +
               "    animated_candidates << '" + animatedRootPath + "'\r\n" +
               "    animated_candidates << File.expand_path('animated_sprites.rb', Dir.pwd)\r\n" +
               "    animated_path = animated_candidates.compact.find { |entry| entry && File.file?(entry) }\r\n" +
               "    if animated_path && !animated_path.empty?\r\n" +
               "      animated_code = File.open(animated_path, 'rb') { |f| f.read }\r\n" +
               "      eval(animated_code, binding, animated_path) if animated_code\r\n" +
               "    end\r\n" +
               "    path = candidates.compact.find { |entry| entry && File.file?(entry) }\r\n" +
               "    if path && !path.empty?\r\n" +
               "      code = File.open(path, 'rb') { |f| f.read }\r\n" +
               "      eval(code, binding, path) if code\r\n" +
               "    end\r\n" +
               "  end\r\n" +
               "rescue Exception => e\r\n" +
               "  begin\r\n" +
               "    File.open('" + logPath + "', 'a') {|f| f.puts e.message; f.puts e.backtrace.join(\"\\n\") }\r\n" +
               "  rescue\r\n" +
               "  end\r\n" +
               "end\r\n";
    }

    private sealed class ScriptBlockCandidate {
        public int StartOffset;
        public int EndOffset;
        public string Code;
        public int Score;
    }

    private static List<ScriptBlockCandidate> FindInjectableScriptBlocks(byte[] original) {
        List<ScriptBlockCandidate> candidates = new List<ScriptBlockCandidate>();
        for (int i = 0; i < original.Length - 8; i++) {
            if (original[i] != 0x22) continue;
            ScriptBlockCandidate candidate = TryReadScriptBlock(original, i);
            if (candidate != null) candidates.Add(candidate);
        }
        candidates.Sort((a, b) => b.Score.CompareTo(a.Score));
        List<ScriptBlockCandidate> selected = new List<ScriptBlockCandidate>();
        HashSet<int> usedOffsets = new HashSet<int>();
        foreach (ScriptBlockCandidate candidate in candidates) {
            if (candidate.Score < 140) continue;
            if (usedOffsets.Contains(candidate.StartOffset)) continue;
            selected.Add(candidate);
            usedOffsets.Add(candidate.StartOffset);
            // A single highest-scoring startup block is enough. Injecting into
            // several blocks can load before a legacy game finishes redefining
            // Input, after which the runtime guard prevents the final Main
            // block from reinstalling the hotkey hook.
            if (selected.Count >= 1) break;
        }
        if (selected.Count == 0 && candidates.Count > 0) selected.Add(candidates[0]);
        selected.Sort((a, b) => a.StartOffset.CompareTo(b.StartOffset));
        return selected;
    }

    private static ScriptBlockCandidate TryReadScriptBlock(byte[] original, int startOffset) {
        try {
            int ptr = startOffset + 1;
            int len = ReadInt(original, ref ptr);
            if (len <= 8) return null;
            if (ptr < 0 || ptr + len > original.Length) return null;
            byte headerA = original[ptr];
            byte headerB = original[ptr + 1];
            bool zlibHeader = headerA == 0x78 && (headerB == 0x9C || headerB == 0xDA || headerB == 0x01 || headerB == 0x5E || headerB == 0x7C);
            if (!zlibHeader) return null;
            byte[] zlibData = new byte[len];
            Array.Copy(original, ptr, zlibData, 0, len);
            string rubyCode = Decompress(zlibData);
            if (string.IsNullOrEmpty(rubyCode)) return null;
            int score = ScoreScriptBlock(original, startOffset, rubyCode);
            if (score < 1) return null;
            return new ScriptBlockCandidate {
                StartOffset = startOffset,
                EndOffset = ptr + len,
                Code = rubyCode,
                Score = score
            };
        } catch {
            return null;
        }
    }

    private static int ScoreScriptBlock(byte[] original, int startOffset, string rubyCode) {
        int score = 0;
        string lower = rubyCode.ToLowerInvariant();
        if (lower.Contains("mainfunction")) score += 300;
        if (lower.Contains("mainfunctiondebug")) score += 300;
        if (lower.Contains("pbcriticalcode")) score += 200;
        if (lower.Contains("pluginmanager.runplugins")) score += 150;
        if (lower.Contains("scene_map")) score += 120;
        if (lower.Contains("pbcalltitle")) score += 120;
        if (lower.Contains("$debug")) score += 90;
        if (lower.Contains("graphics.transition")) score += 80;
        if (lower.Contains("def main")) score += 60;
        if (lower.Contains("class scene_")) score += 20;
        if (lower.Contains("module ")) score += 10;
        if (lower.Contains("def ")) score += 10;
        if (lower.Contains("god_mode.rb")) score -= 500;

        int previewStart = Math.Max(0, startOffset - 96);
        int previewLength = Math.Min(128, startOffset - previewStart);
        string preview = previewLength > 0 ? Encoding.ASCII.GetString(original, previewStart, previewLength).ToLowerInvariant() : "";
        if (preview.Contains("main")) score += 120;
        if (preview.Contains("start")) score += 80;
        if (preview.Contains("debug")) score += 40;

        score += Math.Max(0, startOffset / 50000);
        return score;
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
    Show-StartupAnimation
    $explicitModeSelected = $Uninstall.IsPresent -or $DryRun.IsPresent -or $RestoreBackups.IsPresent
    
    $MenuKey = Normalize-Hotkey $MenuHotkey "F6"
    $WtwKey = Normalize-Hotkey $WalkThroughWallsHotkey "F5"
    $HealKey = Normalize-Hotkey $HealHotkey "F9"
    $EnableNativeDebugBootstrap = $false
    $DisableCompilerBootstrap = $false

    if (-not $explicitModeSelected -and -not $NonInteractive) {
        $menuLoop = $true
        while ($menuLoop) {
            $mainAction = Show-MainActionMenu
            switch ($mainAction) {
                "1" { $InstallReport.PatchMode = "AUTO" }
                "2" { $InstallReport.PatchMode = "MKXP" }
                "3" { $InstallReport.PatchMode = "RGSS" }
                "4" { $InstallReport.PatchMode = "BOTH" }
                "5" { $Uninstall = $true; $menuLoop = $false; break }
                "6" { $RestoreBackups = $true; $menuLoop = $false; break }
                "7" {
                    $ResolvedProbeDir = (Resolve-Path $GameDir -ErrorAction SilentlyContinue).Path
                    if ([string]::IsNullOrEmpty($ResolvedProbeDir)) { $ResolvedProbeDir = (Get-Location).Path }
                    $ProbeDiagnostics = Get-InstallDiagnostics $ResolvedProbeDir
                    Show-SherlockMenu $ResolvedProbeDir $ProbeDiagnostics
                    continue
                }
                "S" {
                    $ResolvedProbeDir = (Resolve-Path $GameDir -ErrorAction SilentlyContinue).Path
                    if ([string]::IsNullOrEmpty($ResolvedProbeDir)) { $ResolvedProbeDir = (Get-Location).Path }
                    try {
                        Print-Header
                        Show-Section "Indigo Pokemon Pack"
                        Show-CardLine (Get-Msg "Game Directory" "Diretorio do Jogo" "Directorio del Juego") $ResolvedProbeDir "Gray"
                        if (-not [string]::IsNullOrWhiteSpace($DefaultIndigoPokemonZipUrl)) {
                            Show-CardLine "Default URL" $DefaultIndigoPokemonZipUrl "DarkGray"
                        }
                        Write-Host ""
                        Write-Host "             " -NoNewline
                        Write-Host (Get-Msg "Tip: paste GitHub/Drive zip URLs separated by ;" "Dica: cole URLs zip do GitHub/Drive separadas por ;" "Consejo: pega URLs zip de GitHub/Drive separadas por ;") -ForegroundColor DarkGray
                        Write-Host ""
                        Write-Host "             " -NoNewline
                        $inputUrl = (Read-Host (Get-Msg "Zip URL(s) or file path(s) (ENTER uses default)" "URL(s) zip ou caminho(s) de arquivo (ENTER usa padrao)" "URL(s) zip o ruta(s) de archivo (ENTER usa predeterminado)")).Trim()
                        $zipUrl = if ([string]::IsNullOrWhiteSpace($inputUrl)) { $DefaultIndigoPokemonZipUrl } else { $inputUrl }
                        Write-Host ""
                        Show-MenuItem "1" (Get-Msg "Backup first" "Fazer backup antes" "Hacer copia primero") (Get-Msg "Recommended" "Recomendado" "Recomendado")
                        Show-MenuItem "2" (Get-Msg "Skip backup" "Pular backup" "Omitir copia") (Get-Msg "Install faster, overwrite directly" "Instala mais rapido, sobrescreve direto" "Instala mas rapido, sobrescribe directo")
                        Show-KeyboardPrompt "1,2" (Get-Msg "Backup current Graphics\\AnimatedBattlers?" "Fazer backup do Graphics\\AnimatedBattlers atual?" "Hacer copia de Graphics\\AnimatedBattlers actual?")
                        $backupChoice = (Read-MenuChoice " > " @("1","2") "1").Trim()
                        $skipIndigoBackup = ($backupChoice -eq "2")
                        [void](Install-IndigoPokemonPack -ResolvedGameDir $ResolvedProbeDir -ZipUrl $zipUrl -SkipBackup $skipIndigoBackup)
                        [void](Write-SpritesReportFile $ResolvedProbeDir)
                    } catch {
                        Add-Warning ((Get-Msg "[!] Indigo pack install failed: {0}" "[!] Falha ao instalar pack Indigo: {0}" "[!] Error al instalar pack Indigo: {0}") -f $_.Exception.Message)
                    }
                    Wait-GoBack
                    continue
                }
                "T" {
                    Show-TestedGamesScreen
                    continue
                }
                "H" {
                    Show-HelpScreen
                    continue
                }
                "0" {
                    Log (Get-Msg "Installer closed." "Instalador fechado." "Instalador cerrado.") "Yellow"
                    exit 0
                }
                default {
                    continue
                }
            }

            # If patch options (1-4) were selected, proceed with configuration wizard.
            # Choosing to "Abort" or "Go back" in any sub-stage loops back to the main menu.
            if ($mainAction -in @("1", "2", "3", "4")) {
                Show-ConsoleAnimation (Get-Msg "Loading selected method" "Carregando metodo selecionado" "Cargando metodo seleccionado") 1 Green
                $hotkeysResult = Show-HotkeysMenu $MenuKey $WtwKey $HealKey
                if ($hotkeysResult.Abort) {
                    continue
                }
                $MenuKey = $hotkeysResult.Menu
                $WtwKey = $hotkeysResult.Wtw
                $HealKey = $hotkeysResult.Heal

                # Detect diagnostics
                $ResolvedProbeDir = (Resolve-Path $GameDir -ErrorAction SilentlyContinue).Path
                if ([string]::IsNullOrEmpty($ResolvedProbeDir)) { $ResolvedProbeDir = (Get-Location).Path }
                $Diagnostics = Get-InstallDiagnostics $ResolvedProbeDir
                Show-MasDiagnosticsAnimation $Diagnostics

                # Check if already installed
                $alreadyInstalled = (Test-Path (Join-Path $ResolvedProbeDir "Plugins\God Mode\god_mode.rb") -PathType Leaf) -or
                    (Test-Path (Join-Path $ResolvedProbeDir "preload_gm.rb") -PathType Leaf)
                if ($alreadyInstalled) {
                    $patchAnyway = Show-AlreadyInstalledPrompt
                    if ($patchAnyway -ne "1") {
                        continue
                    }
                }

                # Show Summary & Proceed confirmation
                Show-SettingsSummary $ResolvedProbeDir $MenuKey $WtwKey $HealKey $EnableNativeDebugBootstrap $DisableCompilerBootstrap $DryRun.IsPresent $Diagnostics
                $proceed = Show-ProceedPrompt
                if ($proceed -ne "1") {
                    continue
                }

                # Everything is confirmed! Exit loop to run the installer
                $menuLoop = $false
            }
        }
    } else {
        if (-not $explicitModeSelected) {
            $InstallReport.PatchMode = "AUTO"
        }
    }

    $GameDir = (Resolve-Path $GameDir -ErrorAction SilentlyContinue).Path
    if ([string]::IsNullOrEmpty($GameDir)) { $GameDir = (Get-Location).Path }
    $InstallReport.GameDir = $GameDir
    $InstallReport.DryRun = $DryRun.IsPresent
    $InstallReport.Uninstall = $Uninstall.IsPresent
    $InstallReport.RestoreBackups = $RestoreBackups.IsPresent
    $Diagnostics = Get-InstallDiagnostics $GameDir
    $strategy = Get-InjectionStrategy $Diagnostics
    $InstallReport.StrategyName = $strategy.Name
    $InstallReport.StrategyConfidence = $strategy.Confidence

    if (-not (Test-Path $GameDir -PathType Container)) {
        throw (Get-Msg "Game directory does not exist." "A pasta do jogo nao existe." "La carpeta del juego no existe.")
    }

    if (-not (Test-DirectoryWritable $GameDir)) {
        throw (Get-Msg "Game directory is not writable. Try moving the installer or running with proper permissions." "A pasta do jogo nao permite gravacao. Tente mover o instalador ou executar com permissoes adequadas." "La carpeta do jogo nao permite escrita. Intenta mover o instalador ou executarlo con permisos adecuados.")
    }

    if ($Uninstall) {
        Run-Uninstall $GameDir
        $reportPath = Write-InstallReportFile $GameDir
        if (-not $NonInteractive) {
            $restoreChoice = Show-UninstallPrompt
            if ($restoreChoice -eq "1") {
                Run-RestoreBackups $GameDir
                $reportPath = Write-InstallReportFile $GameDir
                Show-RestorePrompt
            }
        }
        exit 0
    }

    if ($RestoreBackups) {
        Run-RestoreBackups $GameDir
        $reportPath = Write-InstallReportFile $GameDir
        if (-not $NonInteractive) {
            Show-RestorePrompt
        }
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
            $ans = if ($NonInteractive) { "1" } else { Show-EnigmaPrompt }
            if ($ans -eq "1") {
                $evbExe = Join-Path $env:TEMP "evbunpack.exe"
                if (-not (Test-Path $evbExe)) {
                    Log (Get-Msg "Downloading Enigma unpacker..." "Baixando o desempacotador do Enigma..." "Descargando el desempaquetador de Enigma...") "Cyan"
                    Invoke-WebRequest -Uri "https://github.com/mos9527/evbunpack/releases/download/0.2.6/evbunpack.exe" -OutFile $evbExe
                }
                $unpackedDir = Join-Path $GameDir "Unpacked_Game"
                if (-not (Test-Path $unpackedDir)) { New-Item -ItemType Directory -Path $unpackedDir | Out-Null }
                Log (Get-Msg "Unpacking... This may take a minute." "Descompactando... Isso pode levar um minuto." "Descomprimiendo... Esto puede tardar un minuto.") "Cyan"
                
                Start-Process -FilePath $evbExe -ArgumentList "`"$($packedExe.FullName)`" `"$unpackedDir`"" -Wait -NoNewWindow
                
                Get-ChildItem -Path $GameDir -Directory | Where-Object { $_.Name -ne "Unpacked_Game" } | ForEach-Object {
                    Copy-Item -Path $_.FullName -Destination (Join-Path $unpackedDir $_.Name) -Recurse -Force
                }
                
                Log (Get-Msg "Extraction completed. Restarting in the unpacked folder..." "Extracao concluida. Reiniciando na pasta descompactada..." "Extraccion completada. Reiniciando en la carpeta desempaquetada...") "Green"
                Set-Location $unpackedDir
                $GameDir = $unpackedDir
            } else {
                Log (Get-Msg "Extraction aborted." "Extracao cancelada." "Extraccion cancelada.") "Red"
                exit 1
            }
        } else {
            Log (Get-Msg "Game files not found! Please place the installer in the game root folder." "Arquivos do jogo nao encontrados! Coloque este instalador na pasta raiz do jogo." "Archivos del juego no encontrados! Pon el instalador en la raiz del juego.") "Red"
            exit 1
        }
    }

    if ($NonInteractive) {
        $debugPref = Parse-BoolPreference $RuntimeDebugOnBoot $EnableNativeDebugBootstrap
        $compilePref = Parse-BoolPreference $CompileBypassOnBoot $DisableCompilerBootstrap
        if ($debugPref -ne $null) { $EnableNativeDebugBootstrap = [bool]$debugPref }
        if ($compilePref -ne $null) { $DisableCompilerBootstrap = [bool]$compilePref }
    }
    if ($EnableNativeDebugBootstrap) {
        Add-Warning (Get-Msg "[!] Boot-time runtime debug has been disabled for compatibility because some release builds jump into mainFunctionDebug and crash on missing dev files." "[!] O debug runtime no boot foi desativado por compatibilidade porque algumas builds finais entram em mainFunctionDebug e quebram por falta de arquivos de desenvolvimento." "[!] El debug runtime al iniciar se desactivo por compatibilidad porque algunas builds finales entran en mainFunctionDebug y fallan por falta de arquivos de desarrollo.")
        Add-Note (Get-Msg "[*] Use Engine > Turn Debug ON/OFF after the game loads instead." "[*] Use Engine > Ligar/Desligar Debug depois que o jogo abrir." "[*] Usa Engine > Activar/Desactivar Debug despues de que el juego cargue.")
        $EnableNativeDebugBootstrap = $false
    }

    if ($DryRun) {
        Log (Get-Msg "[*] Dry-run mode enabled. Files will be validated but not changed." "[*] Modo dry-run ativado. Os arquivos serao validados, mas nao alterados." "[*] Modo dry-run activado. Los archivos seran validados, pero no alterados.") "Yellow"
    }
    
    Show-Section (Get-Msg "Injection" "Injecao" "Inyeccion")
    Show-ConsoleAnimation (Get-Msg "Preparing installation" "Preparando instalacao" "Preparando instalacion") 1 Green
    Show-MasStatus (Get-Msg "Checking installation strategy" "Verificando estrategia" "Verificando estrategia") $InstallReport.PatchMode Green
    Log "[*] Copying scripts..." "Cyan"
    $forceMkxpOnly = $InstallReport.PatchMode -eq "MKXP"
    $forceRgssOnly = $InstallReport.PatchMode -eq "RGSS"
    $forceBothPatch = $InstallReport.PatchMode -eq "BOTH"
    
    $PluginDir = Join-Path $GameDir "Plugins\God Mode"
    $SourceGodMode = Join-Path $PSScriptRoot "god_mode_source.rb"
    $DestGodMode   = Join-Path $PluginDir "god_mode.rb"
    $DestPreload   = Join-Path $GameDir "preload_gm.rb"
    $JsonPath = Join-Path $GameDir "mkxp.json"
    $rxData = Join-Path $GameDir "Data\Scripts.rxdata"
    $iniPath = Get-GameIniPath $GameDir
    $manifestPath = Join-Path $GameDir "PokeDebug_Install_Manifest.json"
    $rgssFiles = @(Get-ChildItem -Path $GameDir -Filter "*.rgss*a*" -ErrorAction SilentlyContinue)
    $transactionPaths = @($PluginDir, $DestPreload, $JsonPath, $rxData, $iniPath, $manifestPath, (Get-InstallReportPath $GameDir))
    $transactionPaths += @($rgssFiles | ForEach-Object { $_.FullName })
    $script:InstallTransaction = Start-InstallTransaction $transactionPaths
    if (-not $DryRun -and -not (Test-Path $PluginDir)) { New-Item -ItemType Directory -Path $PluginDir -Force | Out-Null }

    if (-not (Test-Path $SourceGodMode -PathType Leaf)) {
        throw (Get-Msg "Could not find god_mode_source.rb!" "Arquivo god_mode_source.rb nao encontrado!" "No se encontro god_mode_source.rb!")
    }

    $godModeContent = [System.IO.File]::ReadAllText($SourceGodMode, [System.Text.Encoding]::UTF8)
    $godModeContent = [regex]::Replace($godModeContent, "LANG = '.*?'", "LANG = '$($lang.ToLower())'", 1)
    $godModeContent = [regex]::Replace($godModeContent, "MENU_HOTKEY = '.*?'", "MENU_HOTKEY = '$($MenuKey.Trim().ToUpper())'", 1)
    $godModeContent = [regex]::Replace($godModeContent, "WTW_HOTKEY = '.*?'", "WTW_HOTKEY = '$($WtwKey.Trim().ToUpper())'", 1)
    $godModeContent = [regex]::Replace($godModeContent, "HEAL_HOTKEY = '.*?'", "HEAL_HOTKEY = '$($HealKey.Trim().ToUpper())'", 1)
    $pluginVersionMatch = [regex]::Match($godModeContent, 'VERSION\s*=\s*[''"]([^''"]+)[''"]')
    if (-not $pluginVersionMatch.Success) { throw "Could not determine DeveloperMenu version." }
    $pluginVersion = $pluginVersionMatch.Groups[1].Value
    
    if (-not $DryRun) {
        Write-Utf8FileAtomic $DestGodMode $godModeContent
    }
    $InstallReport.GodModeCopied = $true

    $SourcePreload = Join-Path $PSScriptRoot "preload_gm.rb"
    $preloadContent = $null
    if (Get-Variable preloadBase64 -ErrorAction SilentlyContinue) {
        $preloadContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($preloadBase64))
    } elseif (Test-Path $SourcePreload -PathType Leaf) {
        $preloadContent = [System.IO.File]::ReadAllText($SourcePreload, [System.Text.Encoding]::UTF8)
    }
    if (-not [string]::IsNullOrWhiteSpace($preloadContent)) {
        $pluginSha256 = ""
        if (-not $DryRun) { $pluginSha256 = Get-Sha256Hex $DestGodMode }
        if ([string]::IsNullOrWhiteSpace($pluginSha256)) {
            $sha = [System.Security.Cryptography.SHA256]::Create()
            try {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($godModeContent)
                $pluginSha256 = -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") })
            } finally { $sha.Dispose() }
        }
        $preloadContent = [regex]::Replace($preloadContent, "GM_TRY_ENABLE_NATIVE_DEBUG = (true|false)", ("GM_TRY_ENABLE_NATIVE_DEBUG = " + $EnableNativeDebugBootstrap.ToString().ToLowerInvariant()), 1)
        $preloadContent = [regex]::Replace($preloadContent, "GM_TRY_DISABLE_COMPILER = (true|false)", ("GM_TRY_DISABLE_COMPILER = " + $DisableCompilerBootstrap.ToString().ToLowerInvariant()), 1)
        $preloadContent = [regex]::Replace($preloadContent, 'EXPECTED_PLUGIN_SHA256 = "[^"]*"', ('EXPECTED_PLUGIN_SHA256 = "' + $pluginSha256 + '"'), 1)
        $preloadContent = [regex]::Replace($preloadContent, 'EXPECTED_PLUGIN_VERSION = "[^"]*"', ('EXPECTED_PLUGIN_VERSION = "' + $pluginVersion + '"'), 1)
        if (-not $DryRun) {
            Write-Utf8FileAtomic $DestPreload $preloadContent
        }
        $InstallReport.PreloadCopied = $true
        $InstallReport.NativeDebugBootstrap = $EnableNativeDebugBootstrap
        $InstallReport.CompilerBypassBootstrap = $DisableCompilerBootstrap
    }

    $injectionPlan = Resolve-InjectionPlan $Diagnostics $InstallReport.PatchMode
    Add-Note ("[*] Injection plan: MKXP={0}; RGSS={1}; {2}." -f $injectionPlan.UseMkxp, $injectionPlan.UseRgss, $injectionPlan.Reason)
    if ($injectionPlan.UseMkxp -and (Test-Path $JsonPath -PathType Leaf)) {
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
                throw "mkxp.json was found, but preload injection could not be confirmed automatically."
            }
        }
    }

    if ($injectionPlan.UseRgss -and ($rgssFiles.Count -gt 0 -or (Test-Path $rxData))) {
        Log "[*] Found RGSS Game Data. Attempting RGSS injection..." "Magenta"
        if ($rgssFiles.Count -gt 0 -and -not (Test-Path $rxData)) {
            Add-Warning (Get-Msg "[!] Archive-based RGSS patching is best-effort and currently safest on RGSSAD v1 layouts." "[!] O patch RGSS por arquivo empacotado e best-effort e hoje e mais seguro em layouts RGSSAD v1." "[!] El parche RGSS por archivo empaquetado es best-effort y hoy es mas seguro en layouts RGSSAD v1.")
        }
        if ($DryRun) {
            Log "[*] RGSS data detected and ready for patching." "Green"
        } else {
            try {
                $rgssPatchMode = [RgssPatcher]::ApplyPatch($GameDir)
                $InstallReport.RgssPatchMode = $rgssPatchMode
                $InstallReport.RgssInjected = $true
                
                $iniPath = Get-GameIniPath $GameDir
                if (($rgssPatchMode -eq "raw" -or $rgssPatchMode -eq "archive_to_raw" -or $rgssPatchMode -eq "raw_and_archive") -and (Test-Path $iniPath)) {
                    [void](Backup-File $iniPath)
                    (Get-Content $iniPath) -replace "^Scripts=.*", "Scripts=Data\Scripts.rxdata" | Set-Content $iniPath -Encoding ASCII
                    $InstallReport.IniUpdated = $true
                }
                
                Log "[+] RGSS injection successful!" "Green"
            } catch {
                throw ((Get-Msg "RGSS injection failed or is not supported by this archive layout yet. Error: {0}" "A injecao RGSS falhou ou ainda nao e suportada por este layout de arquivo. Erro: {0}" "La inyeccion RGSS fallo o aun no es compatible con este formato de archivo. Error: {0}") -f $_)
            }
        }
    } elseif ($injectionPlan.UseRgss) {
        Add-Warning "[!] RGSS patch mode was selected, but no RGSS game data was found."
    }

    Show-Section "Install Report"
    Show-CardLine "GameDir" $InstallReport.GameDir "Gray"
    Show-CardLine "DryRun" $InstallReport.DryRun "Gray"
    Show-CardLine "Uninstall" $InstallReport.Uninstall "Gray"
    Show-CardLine "RestoreBackups" $InstallReport.RestoreBackups "Gray"
    Show-CardLine "GodModeCopied" $InstallReport.GodModeCopied "Gray"
    Show-CardLine "PreloadCopied" $InstallReport.PreloadCopied "Gray"
    Show-CardLine "NativeDebugBootstrap" $InstallReport.NativeDebugBootstrap "Gray"
    Show-CardLine "CompilerBypassBootstrap" $InstallReport.CompilerBypassBootstrap "Gray"
    Show-CardLine "MkxpInjected" $InstallReport.MkxpInjected "Gray"
    Show-CardLine "RgssInjected" $InstallReport.RgssInjected "Gray"
    if (-not [string]::IsNullOrWhiteSpace($InstallReport.RgssPatchMode)) {
        Show-CardLine "RgssPatchMode" $InstallReport.RgssPatchMode "Gray"
    }
    Show-CardLine "IniUpdated" $InstallReport.IniUpdated "Gray"
    if ($InstallReport.Warnings.Count -gt 0) {
        Show-CardLine "Warnings" $InstallReport.Warnings.Count "Yellow"
    }
    $manifestPath = $null
    if (-not $DryRun) {
        [void](Test-PokeDebugInstallation $DestGodMode $DestPreload $JsonPath ([bool]$injectionPlan.UseMkxp))
        Show-MasStatus (Get-Msg "Checking installed payload" "Verificando arquivos instalados" "Verificando archivos instalados") (Get-Msg "Successful" "Sucesso" "Correcto") Green
        $manifestPath = Write-PokeDebugManifest $GameDir $DestGodMode $DestPreload $InstallReport.StrategyName
        Show-MasStatus (Get-Msg "Checking installation manifest" "Verificando manifesto" "Verificando manifiesto") (Get-Msg "Successful" "Sucesso" "Correcto") Green
        [void]$InstallReport.Notes.Add("[+] Installation manifest validated.")
    }
    $reportPath = Write-InstallReportFile $GameDir
    Complete-InstallTransaction
    if (-not [string]::IsNullOrWhiteSpace($manifestPath)) {
        Show-CardLine "ManifestFile" $manifestPath "Gray"
    }
    Show-CardLine "ReportFile" $reportPath "Gray"
    Write-Host ""
    Write-Host "       ______________________________________________________________" -ForegroundColor Gray
    Write-Host ""
    Write-Host "             " -NoNewline
    Write-Host (Get-Msg " INSTALLATION COMPLETE " " INSTALACAO CONCLUIDA " " INSTALACION COMPLETA ") -ForegroundColor White -BackgroundColor DarkGreen
    Write-Host ""
    Write-Host (Get-Msg "             You can start the game now." "             Agora voce pode abrir o jogo." "             Ahora puedes abrir el juego.") -ForegroundColor White
    Write-Host "       ______________________________________________________________" -ForegroundColor Gray
    
    if (-not $NonInteractive) {
        Wait-GoBack (Get-Msg "Press 0 to exit... " "Pressione 0 para sair... " "Presione 0 para salir... ")
    }
    exit 0

} catch {
    $installError = $_
    try {
        if (Undo-InstallTransaction) {
            Log (Get-Msg "[*] Installation changes were rolled back." "[*] As alteracoes da instalacao foram revertidas." "[*] Los cambios de instalacion fueron revertidos.") "Yellow"
        }
    } catch {
        Log ("[ROLLBACK ERROR] {0}" -f $_.Exception.Message) "Red"
        Log $_.InvocationInfo.PositionMessage "DarkGray"
    }
    Write-Host ""
    Write-Host "             " -NoNewline
    Write-Host " ERROR " -ForegroundColor White -BackgroundColor DarkRed
    Log "             $installError" "Red"
    Log $($installError.InvocationInfo.PositionMessage) "DarkGray"
    
    Write-Host ""
    if (-not $NonInteractive) {
        Wait-GoBack (Get-Msg "Press 0 to exit... " "Pressione 0 para sair... " "Presione 0 para salir... ")
    }
    exit 1
}
