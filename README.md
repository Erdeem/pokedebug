# PokeDebug Improved

PokeDebug Improved is a compatibility-focused developer/debug menu for Pokemon fangames built on older and newer Essentials-based engines.

This version is organized for easier maintenance, broader runtime compatibility, safer injection, and better support for unusual targets such as custom loaders, MKXP-Z builds, RGSS archives, and JoiPlay/mobile setups.

## Highlights

- Modular Ruby source split into focused compatibility layers
- Generated monolithic build for distribution and injection
- PowerShell installer with:
  - install
  - dry run
  - uninstall
  - backup restore
- Detection of common injection paths:
  - MKXP-Z preload
  - raw `Scripts.rxdata`
  - RGSS archive patching
  - Enigma-packed game detection and unpack assist
- Runtime compatibility helpers for older and newer Essentials APIs
- JoiPlay/mobile fallback ways to open the menu

## Project Structure

- `Source Code/ruby_modules/`
  Main modular Ruby source.
- `Source Code/god_mode_source.rb`
  Generated monolithic Ruby file built from the modules.
- `Source Code/Install.ps1`
  Main installer source.
- `Install_Monolithic.ps1`
  Generated standalone installer script.
- `Build-Exe.ps1`
  Builds `PokeDebug_Installer.exe`.
- `Generate-GodModeSource.ps1`
  Regenerates the monolithic Ruby source from modules.
- `GUIDE_HOTKEYS.md`
  End-user quick guide for hotkeys, opening methods, and mobile/JoiPlay usage.

## Recommended Workflow

1. Edit files inside `Source Code/ruby_modules`.
2. Regenerate the monolithic script:

```powershell
powershell -ExecutionPolicy Bypass -File .\Generate-GodModeSource.ps1
```

3. Build the installer:

```powershell
powershell -ExecutionPolicy Bypass -File .\Build-Exe.ps1
```

4. Distribute `PokeDebug_Installer.exe` or `Install_Monolithic.ps1`.

## Installer Features

The installer can automatically adapt to multiple game layouts.

Supported/common paths:

- `mkxp.json` preload injection
- `Data\Scripts.rxdata` patching
- `*.rgssad` / `*.rgss2a` / `*.rgss3a` patching
- Enigma Virtual Box packed executable detection

The installer also shows:

- detected injection method
- detection confidence
- profile selection
- backup/rollback options

## JoiPlay / Mobile Support

Because hotkeys can fail on mobile or in JoiPlay, this build includes fallback access methods:

- Hold `A + B + C` for a moment
- Or use `L + R`
- Or use `AUX1 + AUX2`
- Or call one of these script functions:
  - `pbPokeDebugMenu`
  - `pbDeveloperMenu`
  - `pbGodModeMenu`

More details are in [GUIDE_HOTKEYS.md](./GUIDE_HOTKEYS.md).

## Default Hotkeys

- Open menu: `F6`
- Walk Through Walls: `F5`
- Heal party: `F9`

These can be changed during installation.

## Compatibility Goal

This project aims to work across:

- older Essentials-style fangame engines
- modern Essentials versions
- hybrid/customized projects with mixed APIs

That is why many features use fallback calls, safe wrappers, and runtime detection instead of assuming one exact engine version.

## Notes

- Edit the modular source, not just the generated monolithic file.
- Some heavily customized projects may still require project-specific adjustments.
- Overcap stat editing is intentionally permissive, but some third-party plugins may still react badly if they assume vanilla limits.

## Credits

- Original project direction and ongoing testing by Kzuran
- Built to support wide Essentials fangame compatibility rather than a single game branch
