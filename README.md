# PokeDebug

PokeDebug is a cheat menu for Pokemon fangames built with Pokemon Essentials and related custom engines.

The project combines a modular Ruby runtime with a single-file Windows only installer. It detects the target game's layout, chooses an appropriate injection strategy and keeps fallbacks for older Essentials APIs, modern `GameData` engines, MKXP-Z, classic RGSS.

> PokeDebug modifies game files. Keep a separate copy of the game and its save files before installing or using destructive debug actions.

## Functions

- Engine, map, switch, variable, event and battle tools.
- Pokemon creation, storage management and searchable species selection.
- Item management with searchable, alphabetized lists and item IDs.
- Player, party, stats, moves, abilities, forms, ribbons and utilities.
- Runtime engine profiling and feature availability checks.
- Compatibility adapters instead of assuming one exact Essentials version.
- Transactional installation with validation and rollback.
- English, Portuguese and Spanish interface.
- JoiPlay support through a custom made key item "PokeDebug Device".

Some commands are hidden automatically when the required engine API is unavailable.

## Quick installation

1. Download `PokeDebug_Installer.cmd`.
2. Close the game completely.
3. Run the `.cmd` in the game folder and choose your desired language.
4. Use **Auto/1**.
6. Choose the **hotkeys**.
7. Confirm the installation.
8. Start the game and open PokeDebug using one of the methods below.

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

On supported engines, PokeDebug registers a Key Item named **PokeDebug Device** and adds it to the player's Bag once. Using it closes the Bag first and then opens the menu, which makes it a reliable additional entry point for JoiPlay.

The item system currently adapts to:

- Modern engines using `GameData::Item`.
- Older symbolic caches using `$cache.items` and `ItemData`.
- Classic numeric item databases using `PBItems`.

The device does not replace the existing hotkeys or script calls.

### JoiPlay and mobile fallbacks

- Hold `L + R`.
- Hold `AUX1 + AUX2` or `X + Y`.
- Extra combinations: `L + A`, `R + B` or `A + B + C`.
- Open the Bag and use **PokeDebug Device**.

Controller mappings vary between JoiPlay profiles. The Key Item is recommended when keyboard events are not forwarded correctly.

### Event and script calls

```ruby
pbPokeDebugMenu
pbPokeDebugMobileMenu
pbOpenPokeDebugMenu
pbDeveloperMenu
```

## Installer modes

| Mode | Purpose |
| --- | --- |
| Auto | Detects the game layout and chooses the preferred strategy. |
| MKXP | Forces MKXP-Z-style preload installation. |
| RGSS | Forces classic RGSS script patching. |
| Both | Applies both paths when a hybrid game needs them. |
| Uninstall | Removes installed PokeDebug components. |
| Restore Backup | Restores backups created by the installer. |
| Sherlock | Collects detection and diagnostic information. |

Auto mode prefers MKXP preload when MKXP-Z is detected. RGSS remains available as an explicit fallback for hybrid projects.

## Supported layouts

The installer detects and handles common layouts including:

- `mkxp.json` preload injection.
- Existing `Plugins` and preload-based projects.
- `Data/Scripts.rxdata` patching.
- `.rgssad`, `.rgss2a` and `.rgss3a` archives.
- Hybrid MKXP/RGSS projects.
- Enigma Virtual Box indicators and unpack guidance.

Compatibility is capability-based. A game using a familiar Essentials version may still behave differently because fangames often replace core systems.

### Tested targets

The in-installer list currently includes Essentials v19-v21 and tests involving Pokemon Nova, Uranium, Insurgence, Anil, Z, Mauve, Infinite Fusion 2, Unbreakable Ties, Burning Scale, Vanguard and Echo. Rejuvenation is marked as partial support.

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

If a game stops booting:

1. Close the game.
2. Run `PokeDebug_Installer.cmd` again.
3. Choose **Restore Backup** or **Uninstall**.
4. Use **Sherlock** if the failure remains.
5. Include `developer_menu_errors.log`, the install report and the Sherlock archive when reporting a problem.

## Project structure

```text
PokeDebug/
|-- License
|-- PokeDebug_Installer.cmd        # generated release
|-- README.md
`-- Source Code/
    |-- Install.ps1                  # installer source
    |-- god_mode_source.rb           # generated Ruby payload
    |-- preload_gm.rb                # MKXP/preload bootstrap
    `-- ruby_modules/                 # editable runtime modules
```

The Ruby module order is defined in `Generate-GodModeSource.ps1`. New runtime components must be added there before rebuilding.

## Known limitations

- Heavily customized engines may need a project-specific adapter.
- Packed executables can require unpacking before script injection is possible.
- Some debug actions depend on APIs removed by the game's developer.
- Mobile controller mappings depend on the JoiPlay profile and Android device.
- No support on psdk games.

## Credits

- **Kzuran/Erdeem**.
