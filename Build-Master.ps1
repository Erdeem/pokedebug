#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputName = "PokeDebug_Installer.cmd",
    [string]$ManifestName = "PokeDebug_Release.json",
    [string]$PublicDownloadUrl = "",
    [switch]$SkipMenuGeneration,
    [switch]$SkipTests,
    [switch]$WithoutLogSubmission,
    [switch]$WithoutAnimatedSprites,
    [switch]$WithoutFallenCompat
)

$ErrorActionPreference = "Stop"
$MinimumPayloadChars = 1024
$MaximumPayloadChars = 50MB

function Get-Sha256Bytes([byte[]]$Bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return (-join ($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString("x2") })) }
    finally { $sha.Dispose() }
}

function Compress-GzipBytes([byte[]]$Bytes) {
    $output = New-Object System.IO.MemoryStream
    try {
        $gzip = New-Object System.IO.Compression.GZipStream($output, [System.IO.Compression.CompressionMode]::Compress, $true)
        try { $gzip.Write($Bytes, 0, $Bytes.Length) } finally { $gzip.Dispose() }
        return $output.ToArray()
    } finally { $output.Dispose() }
}

function Expand-GzipBytes([byte[]]$Bytes) {
    $input = New-Object System.IO.MemoryStream(,$Bytes)
    $output = New-Object System.IO.MemoryStream
    try {
        $gzip = New-Object System.IO.Compression.GZipStream($input, [System.IO.Compression.CompressionMode]::Decompress)
        try { $gzip.CopyTo($output) } finally { $gzip.Dispose() }
        return $output.ToArray()
    } finally {
        $input.Dispose()
        $output.Dispose()
    }
}

function Split-FixedWidth([string]$Text, [int]$Width = 120) {
    $result = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $Text.Length; $i += $Width) {
        $result.Add($Text.Substring($i, [Math]::Min($Width, $Text.Length - $i)))
    }
    return $result.ToArray()
}

function Test-RubySyntaxIfAvailable([string]$Path) {
    $ruby = Get-Command ruby -ErrorAction SilentlyContinue
    if (-not $ruby) {
        Write-Host ("[!] Ruby not found; skipped syntax check for {0}." -f $Path) -ForegroundColor Yellow
        return
    }
    $result = & $ruby.Source -c $Path 2>&1
    if ($LASTEXITCODE -ne 0) {
        $result | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        throw ("Ruby syntax check failed for {0}" -f $Path)
    }
    Write-Host ("[+] Ruby syntax OK: {0}" -f $Path) -ForegroundColor Green
}

function Test-GeneratedBundle {
    param([string]$CmdPath, [string]$ExpectedHash, [string[]]$RequiredAssets)
    $lines = [System.IO.File]::ReadAllLines($CmdPath, [System.Text.Encoding]::ASCII)
    $marker = "__POKEDEBUG_PAYLOAD_BELOW__"
    $indexes = @()
    for ($i = 0; $i -lt $lines.Length; $i++) { if ($lines[$i] -eq $marker) { $indexes += $i } }
    if ($indexes.Count -ne 1) { throw "Generated CMD must contain exactly one payload marker." }
    $payload = ($lines[($indexes[0] + 1)..($lines.Length - 1)] -join "")
    if ($payload.Length -lt $MinimumPayloadChars -or $payload.Length -gt $MaximumPayloadChars) { throw "Generated payload size is outside allowed limits." }
    $zipBytes = Expand-GzipBytes ([Convert]::FromBase64String($payload))
    if ((Get-Sha256Bytes $zipBytes) -ne $ExpectedHash) { throw "Generated payload SHA-256 self-test failed." }

    $testRoot = Join-Path ([IO.Path]::GetTempPath()) ("PokeDebug_BuildTest_" + [guid]::NewGuid().ToString("N"))
    try {
        New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
        $zipPath = Join-Path $testRoot "bundle.zip"
        [IO.File]::WriteAllBytes($zipPath, $zipBytes)
        Expand-Archive -LiteralPath $zipPath -DestinationPath (Join-Path $testRoot "bundle") -Force
        $installPath = Join-Path $testRoot "bundle\Install.ps1"
        $parseErrors = $null
        [Management.Automation.Language.Parser]::ParseFile($installPath, [ref]$null, [ref]$parseErrors) | Out-Null
        if ($parseErrors.Count -gt 0) { throw ("Embedded Install.ps1 parser error: " + $parseErrors[0].Message) }
        foreach ($name in $RequiredAssets) {
            if (-not (Test-Path -LiteralPath (Join-Path $testRoot "bundle\$name") -PathType Leaf)) { throw "Embedded asset missing: $name" }
        }
    } finally {
        Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Write-ReleaseManifest {
    param(
        [string]$InstallerPath,
        [string]$ManifestPath,
        [string]$PayloadHash,
        [string]$DownloadUrl
    )
    $headerPath = Join-Path $PSScriptRoot "Source Code\00_header.rb"
    $headerText = [IO.File]::ReadAllText($headerPath, [Text.Encoding]::UTF8)
    $versionMatch = [regex]::Match($headerText, 'VERSION\s*=\s*[''"]([^''"]+)[''"]')
    if (-not $versionMatch.Success) { throw "Could not read the PokeDebug version for the release manifest." }
    $installer = Get-Item -LiteralPath $InstallerPath
    $manifest = [ordered]@{
        schema = 1
        product = "PokeDebug"
        version = $versionMatch.Groups[1].Value
        filename = $installer.Name
        sha256 = (Get-FileHash -LiteralPath $installer.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        payload_sha256 = $PayloadHash.ToLowerInvariant()
        size = $installer.Length
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        download_url = $DownloadUrl
    }
    [IO.File]::WriteAllText($ManifestPath, ($manifest | ConvertTo-Json -Depth 3), (New-Object Text.UTF8Encoding $false))
}

function Replace-PowerShellFunction {
    param([string]$Content, [string]$FunctionName, [string]$Replacement = "")
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseInput($Content, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) { throw ("Cannot transform Install.ps1: " + $errors[0].Message) }
    $function = $ast.Find({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $FunctionName
    }, $true)
    if (-not $function) { throw "Expected installer function was not found: $FunctionName" }
    $start = $function.Extent.StartOffset
    $length = $function.Extent.EndOffset - $start
    return $Content.Remove($start, $length).Insert($start, $Replacement)
}

function New-ReducedInstallScript {
    param([string]$SourcePath, [string]$DestinationPath, [bool]$RemoveLogSubmission, [bool]$RemoveAnimatedSprites, [bool]$RemoveFallenCompat)
    $content = [IO.File]::ReadAllText($SourcePath, [Text.Encoding]::UTF8)

    if ($RemoveLogSubmission) {
        $content = Replace-PowerShellFunction $content "Send-SherlockWebhook"
        $sherlockMenu = @'
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
        Show-CardLine "Enigma packed guess" (Format-State $Diagnostics["EnigmaPacked"]) "Gray"
        Show-CardLine "Injection method" $strategy.Name $strategy.Color
        Show-CardLine "Detection confidence" $strategy.Confidence $strategy.Color
        Write-Host ""
        Write-Host "             __________________________________________________" -ForegroundColor Gray
        Write-Host ""
        Show-MenuItem "1" (Get-Msg "Pack logs as .zip" "Compactar logs em .zip" "Comprimir logs en .zip") ""
        Show-MenuItem "2" (Get-Msg "Go back" "Voltar" "Volver") ""
        Show-KeyboardPrompt "1,2"
        $sherlockChoice = (Read-MenuChoice " > " @("1","2") "2").Trim()
        if ($sherlockChoice -eq "2") { return }
        try {
            $zipPath = New-SherlockZip $ResolvedGameDir $Diagnostics
            Log ("`n             [+] Sherlock zip created: {0}" -f $zipPath) "Green"
        } catch {
            Add-Warning ("`n             [!] Could not create Sherlock zip: {0}" -f $_.Exception.Message)
        }
        Wait-GoBack
    }
}
'@
        $content = Replace-PowerShellFunction $content "Show-SherlockMenu" $sherlockMenu
        if ($content -match 'discord\.com/api/webhooks|Send-SherlockWebhook|Send logs to developer') {
            throw "Log-submission code remained in the reduced installer."
        }
    }

    if ($RemoveAnimatedSprites) {
        $spriteFunctions = @(
            "Test-IndigoPokemonRoot", "Find-IndigoPokemonRoot", "Find-IndigoPokemonPackageRoot",
            "Split-IndigoPackageReferences", "Get-GoogleDriveFileId", "Test-ZipFileMagic",
            "Get-IndigoPackageCachePath", "Invoke-FastWebRequest", "Save-GoogleDriveFile",
            "Save-IndigoPackageReference", "Copy-IndigoPokemonPack", "Get-AnimatedSpritesCompatContent",
            "Install-AnimatedSpritesCompat", "Enable-AnimatedSpritesCompatLoaders", "Install-IndigoPokemonPack",
            "Get-SpritesReportPath", "Write-SpritesReportFile"
        )
        foreach ($functionName in $spriteFunctions) {
            $content = Replace-PowerShellFunction $content $functionName
        }
        $spriteSwitchPattern = '(?ms)^                "S"\s*\{.*?^                "T"\s*\{'
        if ($content -notmatch $spriteSwitchPattern) { throw "Could not locate the installer sprite-pack menu branch." }
        $content = [regex]::Replace($content, $spriteSwitchPattern, '                "T" {', 1)
        $content = $content.Replace(',"T","H","S","0"', ',"T","H","0"')
        $content = $content.Replace('string patchedCode = rubyCode.Contains("animated_sprites.rb") || rubyCode.Contains("animated_sprites_compat.rb") ? rubyCode : inject + rubyCode;', 'string patchedCode = inject + rubyCode;')
        $content = [regex]::Replace($content, '(?m)^\s*string animatedRootPath = EscapeRubySingleQuotedPath\(Path\.Combine\(gameDir, "animated_sprites\.rb"\)\);\r?\n', '')
        $animatedBootstrapPattern = '(?ms)^\s*"    animated_candidates = \[\]\\r\\n" \+.*?^\s*"    end\\r\\n" \+\r?\n'
        $content = [regex]::Replace($content, $animatedBootstrapPattern, '')
        $content = $content.Replace('[PokeDebug/Sprites RGSS bootstrap reached]', '[PokeDebug RGSS bootstrap reached]')
        if ($content -match 'Install-IndigoPokemonPack|Install-AnimatedSpritesCompat|animated_candidates') {
            throw "Animated-sprite installation code remained in the reduced installer."
        }
    }

    if ($RemoveFallenCompat) {
        $content = [regex]::Replace($content, '(?m)^\s*\$fallenCompatPath\s*=\s*Join-Path\s+\$ResolvedGameDir\s+"pokefallen_compat\.rb"\r?\n', '')
        $content = [regex]::Replace($content, '(?ms)^\s*if\s*\(\s*Test-Path\s+-LiteralPath\s+\$fallenCompatPath\s+-PathType\s+Leaf\s*\)\s*\{.*?\r?\n\s*\}\r?\n', '')
        $content = [regex]::Replace($content, '(?m)^\s*\$pokeFallenCompatPath\s*=\s*Join-Path\s+\$ResolvedGameDir\s+"pokefallen_compat\.rb"\r?\n', '')
        $content = [regex]::Replace($content, '(?m)^\s*if\s*\(\s*Remove-IfExistsSafe\s+\$pokeFallenCompatPath\s*\)\s*\{.*?\r?\n', '')
        $content = [regex]::Replace($content, '(?m)^\s*\$SourcePokeFallenCompat\s*=\s*Join-Path\s+\$PSScriptRoot\s+"pokefallen_compat\.rb"\r?\n', '')
        $content = [regex]::Replace($content, '(?m)^\s*\$DestPokeFallenCompat\s*=\s*Join-Path\s+\$GameDir\s+"pokefallen_compat\.rb"\r?\n', '')
        $content = [regex]::Replace($content, '(?ms)^\s*if\s*\(\s*Test-Path\s+-LiteralPath\s+\$SourcePokeFallenCompat\s+-PathType\s+Leaf\s*\)\s*\{\s*\$transactionPaths\s*\+=\s*\$DestPokeFallenCompat\s*\}\r?\n', '')
        $content = [regex]::Replace($content, '(?ms)^\s*if\s*\(\s*Test-Path\s+-LiteralPath\s+\$SourcePokeFallenCompat\s+-PathType\s+Leaf\s*\)\s*\{\s*Copy-Item\s+-LiteralPath\s+\$SourcePokeFallenCompat\s+-Destination\s+\$DestPokeFallenCompat\s+-Force\s*\}\r?\n', '')
        if ($content -match 'pokefallen|FallenCompat') {
            throw "PokeFallen compatibility code remained in the reduced installer."
        }
    }

    $parseTokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseInput($content, [ref]$parseTokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) { throw ("Reduced Install.ps1 parser error: " + $parseErrors[0].Message) }
    [IO.File]::WriteAllText($DestinationPath, $content, (New-Object Text.UTF8Encoding $false))
}

Write-Host "Building single-file PokeDebug CMD bundle..." -ForegroundColor Cyan
$sourceDir = Join-Path $PSScriptRoot "Source Code"
$generator = Join-Path $PSScriptRoot "Generate-PokeDebugMenu.ps1"
if (-not $SkipMenuGeneration -and (Test-Path -LiteralPath $generator -PathType Leaf)) { & $generator }
$testRunner = Join-Path $PSScriptRoot "Tests\Invoke-PokeDebugTests.ps1"
if (-not $SkipTests -and (Test-Path -LiteralPath $testRunner -PathType Leaf)) {
    & $testRunner
}

$assets = @(
    (Join-Path $sourceDir "Install.ps1"),
    (Join-Path $sourceDir "pokedebug_menu.rb"),
    (Join-Path $sourceDir "preload_menu.rb"),
    (Join-Path $sourceDir "pokedebug_psdk_bootstrap.rb"),
    (Join-Path $sourceDir "yuri_bootstrap.rb")
)
if (-not $WithoutFallenCompat) { $assets += (Join-Path $sourceDir "pokefallen_compat.rb") }
if (-not $WithoutAnimatedSprites) { $assets += (Join-Path $sourceDir "animated_sprites_compat.rb") }
foreach ($asset in $assets) { if (-not (Test-Path -LiteralPath $asset -PathType Leaf)) { throw "Required build asset not found: $asset" } }
foreach ($asset in $assets) {
    if ([IO.Path]::GetExtension($asset) -eq ".rb") { Test-RubySyntaxIfAvailable $asset }
}

$workRoot = Join-Path ([IO.Path]::GetTempPath()) ("PokeDebug_Build_" + [guid]::NewGuid().ToString("N"))
try {
    $stage = Join-Path $workRoot "bundle"
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    foreach ($asset in $assets) { Copy-Item -LiteralPath $asset -Destination (Join-Path $stage ([IO.Path]::GetFileName($asset))) -Force }
    if ($WithoutLogSubmission -or $WithoutAnimatedSprites -or $WithoutFallenCompat) {
        New-ReducedInstallScript -SourcePath (Join-Path $sourceDir "Install.ps1") -DestinationPath (Join-Path $stage "Install.ps1") -RemoveLogSubmission $WithoutLogSubmission.IsPresent -RemoveAnimatedSprites $WithoutAnimatedSprites.IsPresent -RemoveFallenCompat $WithoutFallenCompat.IsPresent
    }
    if ($WithoutAnimatedSprites) {
        $stagedPreload = Join-Path $stage "preload_menu.rb"
        $preloadContent = [IO.File]::ReadAllText($stagedPreload, [Text.Encoding]::UTF8)
        $preloadContent = $preloadContent.Replace('        load_auxiliary_script("animated_sprites_compat.rb")' + "`r`n", '')
        $preloadContent = $preloadContent.Replace('        load_auxiliary_script("animated_sprites_compat.rb")' + "`n", '')
        $preloadContent = $preloadContent.Replace('including the animated sprites compatibility layer.', 'without optional animated-sprite loading.')
        if ($preloadContent -match 'load_auxiliary_script\("animated_sprites_compat\.rb"\)') { throw "Animated-sprite preload hook remained in reduced preload_menu.rb." }
        [IO.File]::WriteAllText($stagedPreload, $preloadContent, (New-Object Text.UTF8Encoding $false))
        Test-RubySyntaxIfAvailable $stagedPreload
    }
    if ($WithoutFallenCompat) {
        $stagedPreload = Join-Path $stage "preload_menu.rb"
        $preloadContent = [IO.File]::ReadAllText($stagedPreload, [Text.Encoding]::UTF8)
        $preloadContent = $preloadContent.Replace('    load_auxiliary_script("pokefallen_compat.rb")' + "`r`n", '')
        $preloadContent = $preloadContent.Replace('    load_auxiliary_script("pokefallen_compat.rb")' + "`n", '')
        if ($preloadContent -match 'pokefallen_compat\.rb') { throw "PokeFallen compat preload hook remained in reduced preload_menu.rb." }
        [IO.File]::WriteAllText($stagedPreload, $preloadContent, (New-Object Text.UTF8Encoding $false))
        Test-RubySyntaxIfAvailable $stagedPreload
    }
    $zipPath = Join-Path $workRoot "PokeDebug.bundle.zip"
    Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zipPath -CompressionLevel Optimal -Force
    $zipBytes = [IO.File]::ReadAllBytes($zipPath)
    $zipHash = Get-Sha256Bytes $zipBytes
    $compressedBytes = Compress-GzipBytes $zipBytes
    $payload = [Convert]::ToBase64String($compressedBytes)
    if ($payload.Length -lt $MinimumPayloadChars -or $payload.Length -gt $MaximumPayloadChars) { throw "Payload size is outside allowed limits." }
    $payloadLines = Split-FixedWidth $payload 120

    $outputPath = Join-Path $PSScriptRoot $OutputName
    if ([IO.Path]::GetExtension($outputPath) -ne ".cmd") { throw "The redistribution output must be a .cmd file." }
    [string]$decoder = '$ErrorActionPreference=''Stop'';$root=$env:POKEDEBUG_WORK;$self=$env:POKEDEBUG_SELF;$expected=''' + $zipHash + ''';$min=' + $MinimumPayloadChars + ';$max=' + $MaximumPayloadChars + ';try{$lines=[IO.File]::ReadAllLines($self,[Text.Encoding]::ASCII);$marker=''__POKEDEBUG_PAYLOAD_BELOW__'';$hits=@();for($i=0;$i-lt$lines.Length;$i++){if($lines[$i]-eq$marker){$hits+=$i}};if($hits.Count-ne 1){throw ''Invalid payload marker count.''};$payload=($lines[($hits[0]+1)..($lines.Length-1)]-join'''');if($payload.Length-lt$min-or$payload.Length-gt$max){throw ''Invalid payload size.''};$packed=[Convert]::FromBase64String($payload);$input=New-Object IO.MemoryStream(,$packed);$output=New-Object IO.MemoryStream;$gzip=New-Object IO.Compression.GZipStream($input,[IO.Compression.CompressionMode]::Decompress);$gzip.CopyTo($output);$gzip.Dispose();$input.Dispose();$zip=$output.ToArray();$output.Dispose();$sha=[Security.Cryptography.SHA256]::Create();$actual=[BitConverter]::ToString($sha.ComputeHash($zip)).Replace(''-'','''').ToLowerInvariant();$sha.Dispose();if($actual-ne$expected){throw ''Payload SHA-256 mismatch.''};[IO.Directory]::CreateDirectory($root)|Out-Null;$acl=New-Object Security.AccessControl.DirectorySecurity;$acl.SetAccessRuleProtection($true,$false);$id=[Security.Principal.WindowsIdentity]::GetCurrent().Name;$rule=New-Object Security.AccessControl.FileSystemAccessRule($id,''FullControl'',''ContainerInherit,ObjectInherit'',''None'',''Allow'');$acl.AddAccessRule($rule);[IO.Directory]::SetAccessControl($root,$acl);$zipPath=Join-Path $root ''bundle.zip'';[IO.File]::WriteAllBytes($zipPath,$zip);Expand-Archive -LiteralPath $zipPath -DestinationPath (Join-Path $root ''bundle'') -Force}catch{Write-Host (''[ERROR] ''+$_.Exception.Message) -ForegroundColor Red;exit 1}'
    $cmdLines = @(
        '@echo off',
        'setlocal EnableExtensions DisableDelayedExpansion',
        'set "POKEDEBUG_SELF=%~f0"',
        'if not defined POKEDEBUG_CONHOST (',
        '  set "POKEDEBUG_CONHOST=1"',
        '  start "" "%SystemRoot%\System32\conhost.exe" "%SystemRoot%\System32\cmd.exe" /c call "%~f0" %*',
        '  exit /b',
        ')',
        'set "POKEDEBUG_WORK=%TEMP%\PokeDebug_%RANDOM%_%RANDOM%_%RANDOM%"',
        'set "POKEDEBUG_LAUNCH_DIR=%~dp0"',
        'color 07',
        'title  PokeDebug Installer 3.5.0',
        'mode con: cols=76 lines=34',
        'cd /d "%~dp0"',
        ('powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "' + $decoder + '"'),
        'if errorlevel 1 goto :failed',
        'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%POKEDEBUG_WORK%\bundle\Install.ps1" %*',
        'set "POKEDEBUG_EXIT=%ERRORLEVEL%"',
        'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Remove-Item -LiteralPath $env:POKEDEBUG_WORK -Recurse -Force -ErrorAction SilentlyContinue"',
        'exit /b %POKEDEBUG_EXIT%',
        ':failed',
        'set "POKEDEBUG_EXIT=%ERRORLEVEL%"',
        'powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Remove-Item -LiteralPath $env:POKEDEBUG_WORK -Recurse -Force -ErrorAction SilentlyContinue"',
        'pause',
        'exit /b %POKEDEBUG_EXIT%',
        '__POKEDEBUG_PAYLOAD_BELOW__'
    ) + $payloadLines
    [IO.File]::WriteAllLines($outputPath, $cmdLines, [Text.Encoding]::ASCII)
    $requiredBundleAssets = @("pokedebug_menu.rb", "preload_menu.rb", "pokedebug_psdk_bootstrap.rb", "yuri_bootstrap.rb")
    if (-not $WithoutFallenCompat) { $requiredBundleAssets += "pokefallen_compat.rb" }
    if (-not $WithoutAnimatedSprites) { $requiredBundleAssets += "animated_sprites_compat.rb" }
    Test-GeneratedBundle $outputPath $zipHash $requiredBundleAssets

    $manifestPath = Join-Path $PSScriptRoot $ManifestName
    Write-ReleaseManifest -InstallerPath $outputPath -ManifestPath $manifestPath -PayloadHash $zipHash -DownloadUrl $PublicDownloadUrl

    foreach ($legacy in @("Install_Monolithic.ps1", "PokeDebug_Installer.ps1", "Run-PokeDebug-Installer.cmd")) {
        $legacyPath = Join-Path $PSScriptRoot $legacy
        if ($legacyPath -ne $outputPath) { Remove-Item -LiteralPath $legacyPath -Force -ErrorAction SilentlyContinue }
    }
    Write-Host ("[+] Single redistribution file generated: {0}" -f $outputPath) -ForegroundColor Green
    Write-Host ("[+] Bot release manifest generated: {0}" -f $manifestPath) -ForegroundColor Green
    Write-Host ("[+] Bundle SHA-256: {0}" -f $zipHash) -ForegroundColor DarkGray
    Write-Host ("[+] Compressed payload: {0:N0} bytes (Base64: {1:N0} chars)" -f $compressedBytes.Length, $payload.Length) -ForegroundColor DarkGray
} finally {
    Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
}
