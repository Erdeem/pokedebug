# PokeDebug 3.5.0

PokeDebug is a universal cheat menu and quality-of-life developer toolkit engineered for Pokemon fangames built with Pokemon Essentials, MKXP, MKXP-Z, PSDK, TRuby, Kurisu VM, classic RGSS, and JoiPlay (Android).

The project combines a modular Ruby runtime with a self-contained, single-file Windows installer. It automatically detects the target game's engine layout, chooses the optimal injection strategy, and enforces strict compatibility fallbacks across Ruby 1.8.1 through 3.3+.

> **Notice:** PokeDebug modifies game scripts and variables. Always keep a separate backup of your game folder and save files before installing or using destructive debug actions.

---

## What's New in v3.5.0

- **Universal Dual-Rail Fast Forward**:
  - Accelerates gameplay smoothly using dual-rail scaling: Frame-Rate scaling for classic RGSS/MKXP and a Continuous Virtual Accumulator Clock (C0 continuous) for delta-time engines (Essentials v20/v21+), eliminating animation out-of-bounds crashes. Default hotkey: `F8`.
- **Form Override (Lock Form)**:
  - Forces Pokemon to remain in a specific form permanently across battles. Ideal for Mega Evolutions, Primal Reversions, and regional variants that would normally revert after battle.
- **Generation 9 & 8 Modern Attributes**:
  - Full support for **Tera Type** (view and set any Tera Type via search) and **Gigantamax Factor** (`gmax_factor`) toggling.
- **Shadow Pokemon & Heart Gauge Controls**:
  - Transform Pokemon into Shadow state, purify instantly, or adjust Heart Gauge (0 to 30,000) for Colosseum/XD mechanics and fangames.
- **Overworld Weather & Lighting Simulator**:
  - Change overworld map weather on the fly (Clear, Rain, Storm, Snow, Blizzard, Sandstorm, Harsh Sun, Fog, Heavy Rain) and test Day/Night lighting tones.
- **Emergency & Recovery Tools**:
  - **Force / Emergency Save**: Save your game anywhere, even during cutscenes or on maps where saving is disabled (`save_disabled = true`).
  - **Emergency Unstuck**: Freezes, collision blocks, and stuck event loops can be cleared with 1 click.
  - **Manual Coordinate Warp**: Teleport to any Map ID, X, and Y even in 100% encrypted games without `MapInfos.rxdata`.
- **Foolproof Smart Installer**:
  - **WinRAR/7-Zip Safety**: Detects and warns if run inside temporary unextracted archive folders.
  - **Automatic GUI File Picker**: Opens a native Windows dialog to choose `Game.exe` if the installer is run outside the game folder.
  - **Drag-and-Drop**: Drag `Game.exe` directly onto `PokeDebug_Installer.cmd`.
  - **Auto-Close Running Games**: Detects open game processes and offers to close them smoothly before file injection.
  - **UAC Auto-Elevation**: Automatically requests Administrator privileges if the game is located in protected folders (like `Program Files`).
  - **GitHub Auto-Update**: Queries `https://github.com/Erdeem/pokedebug` on startup and offers 1-click self-updating when new versions are released.
  - **Infinite Fusion Memory Guard**: Protects against RAM exhaustion in games with over 170,000 fusion combinations.

---

## Opening PokeDebug

### Default Hotkeys

| Action | Default Key | Description |
| :--- | :---: | :--- |
| **Open PokeDebug Menu** | `F6` | Opens the main developer and cheat menu |
| **Walk Through Walls (WTW)** | `F5` | Toggles collision pass-through / noclip |
| **Fast Forward Speed** | `F8` | Cycles game speed: 1.0x -> 1.5x -> 2.0x -> 3.0x |
| **Heal Party** | `F9` | Restores HP, PP, and cures status conditions instantly |

*All hotkeys can be customized during installation or via `PokeDebug_Hotkeys.cfg`.*

### PokeDebug Device (JoiPlay / Mobile)

On supported engines, PokeDebug registers a Key Item named **PokeDebug Device**.
- Open the Bag -> Key Items -> **PokeDebug Device**.
- To remove the item before transferring saves to clean games, choose **Extras > Remove Device From Save**.

### Mobile / Controller Shortcuts (JoiPlay)

- Hold `L + R`
- Hold `AUX1 + AUX2` or `X + Y`
- Extra fallbacks: `L + A`, `R + B`, or `A + B + C`

### Script / Event Calls

If you want to trigger PokeDebug from an in-game NPC or script event:
```ruby
pbPokeDebugMenu
pbPokeDebugMobileMenu
pbOpenPokeDebugMenu
pbDeveloperMenu
```

---

## Key Features

- **Engine & World**: Map warps (list & manual coordinates), switch/variable editor, map event inspector, field effects (Reborn/Rejuv), weather and time controls, PBS editors, wild encounter version picker, and roaming Pokemon editor.
- **Battle Tools**: Instant Win, Escape Battle, 100% Catch Wild Pokemon, Full Revive & PP Restore in battle, Field Effect switcher.
- **Pokemon Generator & Storage**: Add any species, custom Infinite Fusion generator, preset export/import, quick hatch party eggs, 1-click fill/clear PC boxes (with Infinite Fusion memory guard).
- **Party & Stat Editor**: Form Override (form lock), Level & EXP, IVs (31) & EVs (252), Nature & Gender forcing, Ability Slot selector (1, 2, Hidden Ability), Tera Type, Gigantamax Factor, Shadow & Heart Gauge, 100% Obedience (OT Matcher), Move relearner / teaching, Nickname and Poke Ball changer.
- **Player Tools**: Money, Game Corner Coins, Battle Points (BP), Badges, Outfits, Running Shoes, Pokedex completion, play time adjustment.
- **Multilingual Support**: Fully localized in **English**, **Portugues**, and **Espanol**.

---

## Installation

1. Download **`PokeDebug_Installer.cmd`** (or **`PokeDebug_Installer_Release.cmd`** for the public release).
2. Place it in your game's root folder (where `Game.exe` is located).
   *(If opened elsewhere, the installer will automatically open a window asking you to select `Game.exe`).*
3. Close the game completely.
4. Run `PokeDebug_Installer.cmd` and select your language (**EN / PT / ES**).
5. Choose **[1] Auto Mode** (recommended) or specify your target engine.
6. Configure your hotkeys and confirm.
7. Launch your game and press **F6** (or use the **PokeDebug Device** in your Bag).

---

## Supported Engines & Layouts

- **Pokemon Essentials**: v15, v16, v17, v18, v19, v20, v20.1, v21, v21.1+ (includes native `meta.txt` plugin support for v20/v21).
- **MKXP & MKXP-Z**: Preload script chaining via `mkxp.json` and `patches.json`.
- **Pokemon SDK (PSDK / LiteRGSS2)**: Delayed runtime bootstrap via `Game.rb`.
- **Yuri RGSS Runtime**: Native runtime evaluation bridge for encrypted `Scripts.pkg`.
- **Root Script Runners**: Automatic hook injection for `main.rb` and `start.rb` (TRuby, Kurisu VM, custom bootstraps).
- **Classic RGSS**: Encrypted `.rgssad`, `.rgss2a`, `.rgss3a`, and `Data/Scripts.rxdata`.
- **Notable Tested Games**: Pokemon Essentials, Infinite Fusion, Uranium, Reborn, Rejuvenation, Desolation, Insurgence, Phoenix Rising, Vanguard, Nova, Anil, Mauve, Echo, and more.

---

## Building from Source

### Prerequisites
- Windows PowerShell 5.1 or PowerShell 7+.
- Ruby is optional (used for automated syntax verification).

### Build Commands

1. **Regenerate the monolithic menu from modules**:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Generate-PokeDebugMenu.ps1
   ```

2. **Run all 8 automated validation test suites**:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\Invoke-PokeDebugTests.ps1 -RequireRuby
   ```

3. **Build the master redistributable installer (`PokeDebug_Installer.cmd`)**:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-Master.ps1
   ```

4. **Build the public GitHub release (`PokeDebug_Installer_Release.cmd`)**:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-Master-2.ps1
   ```

---

## Project Structure

```text
PokeDebug/
|-- Build-Master.ps1                 # Master build script (full redistribution)
|-- Build-Master-2.ps1               # Public release build script
|-- Generate-PokeDebugMenu.ps1       # Concatenates Source Code modules into pokedebug_menu.rb
|-- PokeDebug_Installer.cmd          # Generated master installer bundle
|-- PokeDebug_Installer_Release.cmd  # Generated public installer bundle
|-- PokeDebug_Release.json           # Master release manifest
|-- PokeDebug_Release_Public.json    # Public release manifest
|-- README.md                        # Project documentation
|-- Tests/                           # Comprehensive test suite
|   `-- Invoke-PokeDebugTests.ps1
`-- Source Code/                     # Modular Ruby & PowerShell sources
    |-- 00_header.rb                 # Version, translations (TR), hotkeys
    |-- 10_core_*.rb                 # Engine adapters, runtime patches, search & UI
    |-- 11_input_and_mobile.rb       # Keyboard listeners & JoiPlay mobile gestures
    |-- 20_engine.rb                 # Engine menu, weather, time, warp, force save
    |-- 30_pokemon_items_player.rb   # PC storage, items, player stats & currencies
    |-- 40_party.rb                  # Party editor, form lock, Tera, G-Max, moves
    |-- 45_battle_tools.rb           # In-battle instant actions
    |-- 50_runtime_patches.rb        # Defensive engine & graphics patches
    |-- Install.ps1                  # Foolproof PowerShell installer core
    |-- pokedebug_menu.rb            # Generated monolithic runtime payload
    |-- preload_menu.rb              # MKXP/MKXP-Z preload loader
    |-- pokedebug_psdk_bootstrap.rb  # PSDK delayed evaluation bridge
    `-- yuri_bootstrap.rb            # Yuri RGSS native evaluation bridge
```

---

## Credits

- **Kzuran** - Creator & Lead Developer
- **Erdeem** - Co-maintainer & GitHub Release Host

---

## Project Status / Mensagem

**EN:** PokeDebug 3.5.0 represents the definitive, universal release supporting both classic and modern Pokemon fangames. Feel free to fork the repository or submit pull requests.

**PT-BR:** O PokeDebug 3.5.0 representa o lancamento definitivo e universal com suporte tanto a fangames classicos quanto modernos. Sinta-se livre para fazer um fork ou enviar um pull request.
