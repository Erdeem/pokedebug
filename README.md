# PokeDebug 3.2.0

PokeDebug is a cheat menu for Pokemon fangames built with Pokemon Essentials and related custom frameworks.

The project combines a modular Ruby runtime with a single-file Windows installer. It detects the target game's layout, chooses an appropriate injection strategy, and keeps fallbacks for older Essentials APIs, modern `GameData` engines, MKXP-Z, classic RGSS, and JoiPlay.

> PokeDebug modifies game files. Keep a separate copy of the game and its save files before installing or using some functions.

## Functions

- Engine, map, switch, variable, event, and battle tools.
- Pokemon creation, storage management, and searchable species selection.
- Item management with searchable, alphabetized lists and item IDs.
- Player, party, stats, moves, abilities, forms, ribbons, and utilities.
- Runtime engine profiling and feature availability checks.
- Compatibility adapters.
- Transactional installation with validation and rollback.
- English, Portuguese, and Spanish interface.
- JoiPlay support through a custom-made key item: "PokeDebug Device".

Some commands are hidden automatically when the required engine API is unavailable.

## Quick installation

1. Download or build `PokeDebug_Installer.cmd`.
2. Close the game completely.
3. Run the `.cmd` in the game folder and choose your desired language.
4. Use **Auto/1** unless a specific compatibility test requires another method.
5. Choose the **hotkeys**.
6. Confirm the installation.
7. Start the game and open PokeDebug.

Only `PokeDebug_Installer.cmd` is required for redistribution. The PowerShell installer and Ruby payload are compressed inside it and validated before extraction.

## Opening PokeDebug

### Keyboard defaults

| Action | Key |
| --- | --- |
| Open PokeDebug | `F6` |
| Walk Through Walls | `F5` |
| Heal party | `F9` |

The hotkeys can be changed during installation.

### PokeDebug Device

On supported engines, PokeDebug registers a Key Item named **PokeDebug Device**. PokeDebug 3.1.4+ solves previous issues with the PokeDebug Device.

Older PokeDebug versions may already have written `:pokedebug_device` into an Essentials save. Load that save with 3.1.4 or newer, choose **Extras > Remove Device From Save**, and save the game once before uninstalling or moving the save to a clean game folder. **Engine > Enable Native Debug Only** performs the same cleanup, keeps the game's native `$DEBUG` options enabled, and disables future Device injection for that installation.

The item system currently adapts to:

- Modern engines using `GameData::Item`.
- Older symbolic caches using `$cache.items` and `ItemData`.
- Classic numeric item databases using `PBItems`.

The device does not replace the existing hotkeys or script calls.

### JoiPlay and mobile fallbacks

- Hold `L + R`.
- Hold `AUX1 + AUX2` or `X + Y`.
- Extra combinations: `L + A`, `R + B`, or `A + B + C`.
- Open the Bag and use **PokeDebug Device**.

Controller mappings vary between JoiPlay profiles. The Key Item is recommended when keyboard events are not forwarded correctly.

### Event and script calls

```ruby
pbPokeDebugMenu
pbPokeDebugMobileMenu
pbOpenPokeDebugMenu
pbDeveloperMenu
```

## Supported layouts

The installer detects and handles common layouts including:

- `mkxp.json` preload injection.
- Existing `Plugins` and preload-based projects.
- `Data/Scripts.rxdata` patching.
- `.rgssad`, `.rgss2a`, and `.rgss3a` archives.
- Hybrid MKXP/RGSS projects.
- Enigma Virtual Box indicators and unpack guidance.

Compatibility is capability-based. A game using a familiar Essentials version may still behave differently because fangames often replace core systems.

### Tested targets

The in-installer list currently includes Essentials v19-v21 and tests involving Pokemon Nova, Uranium, Insurgence, Anil, Z, Mauve, Infinite Fusion 2, Unbreakable Ties, Burning Scale, Phoenix Rising, Vanguard, and Echo. Rejuvenation is marked as partial support.

Being listed means that an installation or compatibility path has been exercised; it does not guarantee that every debug command works in every release of that game.

## Safety and recovery

The installer:

- Checks that the selected directory resembles a supported game.
- Detects running game processes before modifying files.
- Creates backups of files that will be changed.
- Uses an installation transaction and rolls changes back after a failure.
- Validates the installed payload.
- Writes `PokeDebug_Install_Manifest.json`.
- Writes `PokeDebug_Install_Report.txt`.

## Building from source

Requirements:

- Windows PowerShell 5.1 or newer.
- Ruby is optional, but recommended for automatic syntax validation.

Edit the numbered Ruby modules inside `Source Code/`. Do not edit `Source Code/pokedebug_menu.rb` directly because it is generated.

Regenerate the combined Ruby source:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Generate-PokeDebugMenu.ps1
```

Build the redistributable installer:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-Master.ps1
```

Build the public GitHub release:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-Master-2.ps1
```

The regular build creates the complete personal `PokeDebug_Installer.cmd`. The public build creates `PokeDebug_Installer_Release.cmd`.

The build validates the PowerShell payload, checks Ruby syntax when Ruby is available, compresses the bundle, embeds it in the CMD, and performs a SHA-256 extraction self-test.

### Automated tests

Run the complete local validation suite with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\Invoke-PokeDebugTests.ps1 -RequireRuby
```

The suite checks every Ruby module independently, verifies that the generated monolithic menu is current, parses every PowerShell entry point, runs runtime smoke tests, enforces legacy-Ruby syntax guardrails, and prevents the exception policy from regressing. Regular personal and public builds run this suite automatically; `-SkipTests` is available only for troubleshooting.

## Project structure

```text
PokeDebug/
|-- Build-Master.ps1
|-- Build-Master-2.ps1               # public GitHub release build
|-- Generate-PokeDebugMenu.ps1
|-- PokeDebug_Installer.cmd          # generated redistribution file
|-- PokeDebug_Installer_Release.cmd  # generated public redistribution file
|-- README.md
`-- Source Code/
    |-- Install.ps1                  # installer source
    |-- 00_header.rb                 # first editable runtime module
    |-- 10_core_*.rb                 # core compatibility modules
    |-- 11_*.rb ... 50_*.rb          # feature/runtime modules
    |-- pokedebug_menu.rb            # generated Ruby payload
    |-- preload_menu.rb              # MKXP/preload bootstrap
    |-- pokedebug_psdk_bootstrap.rb  # Pokemon SDK delayed bootstrap
    |-- yuri_bootstrap.rb            # Yuri/RGSS bridge
    `-- animated_sprites_compat.rb   # personal-build sprite layer
```

The Ruby module order is defined in `Generate-PokeDebugMenu.ps1`. New runtime components must be added there before rebuilding.

## Known limitations

- Heavily customized engines may need a project-specific adapter.
- Packed executables can require unpacking before script injection is possible.
- Some debug actions depend on APIs removed by the game's developer.
- Mobile controller mappings depend on the JoiPlay profile and Android device.

## Beta/Dev functions

- Custom animated sprites (Needs patch to work)
- PokeFallen Patch (Not working)

## Credits

- **Kzuran** — Creator and lead developer.

## Project Status / Mensagem

**EN:** I no longer plan to actively maintain this project and am leaving it in the hands of the community. Feel free to fork the repository or submit pull requests.

**PT-BR:** Atualmente não planejo mais manter este projeto ativamente e vou deixá-lo nas mãos da comunidade. Sinta-se livre para fazer um fork ou enviar um pull request.

— **Kzuran**

