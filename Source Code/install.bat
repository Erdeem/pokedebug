@echo off
setlocal EnableDelayedExpansion
title PokeDebug - Installer
color 0B

set MODE=install
set EXTRA_ARGS=
set TARGET_DIR=%~dp0
if /I "%~1"=="/uninstall" set MODE=uninstall
if /I "%~1"=="-uninstall" set MODE=uninstall
if /I "%~1"=="/restore" set MODE=restore
if /I "%~1"=="-restore" set MODE=restore
if /I "%~1"=="/dryrun" set EXTRA_ARGS=-DryRun
if /I "%~2"=="/dryrun" set EXTRA_ARGS=-DryRun
if not "%~1"=="" (
    if exist "%~1" (
        if /I not "%~1"=="/uninstall" if /I not "%~1"=="-uninstall" if /I not "%~1"=="/restore" if /I not "%~1"=="-restore" if /I not "%~1"=="/dryrun" if /I not "%~1"=="-dryrun" (
            set TARGET_DIR=%~1
        )
    )
)
if not "%~2"=="" (
    if exist "%~2" (
        if /I not "%~2"=="/uninstall" if /I not "%~2"=="-uninstall" if /I not "%~2"=="/restore" if /I not "%~2"=="-restore" if /I not "%~2"=="/dryrun" if /I not "%~2"=="-dryrun" (
            set TARGET_DIR=%~2
        )
    )
)

echo ===============================================================
if /I "%MODE%"=="uninstall" (
    echo                     POKEDEBUG UNINSTALLER
) else (
    if /I "%MODE%"=="restore" (
        echo                  POKEDEBUG BACKUP RESTORER
    ) else (
        echo                      POKEDEBUG INSTALLER
    )
)
echo                  Smart Setup Launcher for PokeDebug
echo                      Developed by Kzuran
echo ===============================================================
echo.
echo [ Language / Idioma / Lenguaje ]
echo.
echo   [1] English   ^(EN^)
echo   [2] Portugues ^(PT^)
echo   [3] Espanol   ^(ES^)
echo.
set /p lang="> Enter choice (1/2/3): "

if "%lang%"=="1" (
    set LANG_CODE=en
) else if "%lang%"=="2" (
    set LANG_CODE=pt
) else if "%lang%"=="3" (
    set LANG_CODE=es
) else (
    echo Invalid choice. Defaulting to English.
    set LANG_CODE=en
)

echo.
echo ===============================================================
set ACTION_TEXT=
if "%LANG_CODE%"=="en" (
    if /I "%MODE%"=="uninstall" (
        set ACTION_TEXT=Executing PowerShell Uninstaller...
    ) else (
        if /I "%MODE%"=="restore" (
            set ACTION_TEXT=Executing PowerShell Backup Restore...
        ) else (
            set ACTION_TEXT=Executing PowerShell Installer...
        )
    )
) else if "%LANG_CODE%"=="pt" (
    if /I "%MODE%"=="uninstall" (
        set ACTION_TEXT=Executando o Desinstalador PowerShell...
    ) else (
        if /I "%MODE%"=="restore" (
            set ACTION_TEXT=Executando a Restauracao de Backups PowerShell...
        ) else (
            set ACTION_TEXT=Executando o Instalador PowerShell...
        )
    )
) else (
    if /I "%MODE%"=="uninstall" (
        set ACTION_TEXT=Ejecutando el Desinstalador PowerShell...
    ) else (
        if /I "%MODE%"=="restore" (
            set ACTION_TEXT=Ejecutando la Restauracion de Respaldos PowerShell...
        ) else (
            set ACTION_TEXT=Ejecutando el Instalador PowerShell...
        )
    )
)
echo !ACTION_TEXT!
echo Target folder: %TARGET_DIR%
echo ===============================================================
echo.

if /I "%MODE%"=="uninstall" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" -GameDir "%TARGET_DIR%" -Language "%LANG_CODE%" -Uninstall %EXTRA_ARGS%
) else (
    if /I "%MODE%"=="restore" (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" -GameDir "%TARGET_DIR%" -Language "%LANG_CODE%" -RestoreBackups %EXTRA_ARGS%
    ) else (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" -GameDir "%TARGET_DIR%" -Language "%LANG_CODE%" %EXTRA_ARGS%
    )
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    color 0C
    if "%LANG_CODE%"=="en" (
        echo [ERROR] Installation failed or was interrupted.
    ) else if "%LANG_CODE%"=="pt" (
        echo [ERRO] A instalacao falhou ou foi interrompida.
    ) else (
        echo [ERROR] La instalacion fallo o fue interrumpida.
    )
    pause
    exit /b 1
)

pause
