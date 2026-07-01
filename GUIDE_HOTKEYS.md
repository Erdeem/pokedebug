# PokeDebug Improved Guide

This file is a quick guide for players, testers, and anyone using the injected menu.

## Default Hotkeys

- Open developer menu: `F6`
- Toggle Walk Through Walls: `F5`
- Heal party: `F9`

These defaults may be changed during installation.

## How To Open The Menu On PC

Use the configured menu hotkey.

Default:

- Press `F6`

## How To Open The Menu On JoiPlay / Mobile

Some mobile setups do not forward function keys correctly. This build includes fallback methods.

Try these in order:

1. Hold `A + B + C` for about a moment.
2. If your overlay/gamepad has extra mapped buttons, press `L + R`.
3. If available, press `AUX1 + AUX2`.

## Script Call Fallback

If hotkeys do not work at all, the menu can still be opened through an event or script call:

```ruby
pbPokeDebugMenu
```

Alternative aliases:

```ruby
pbDeveloperMenu
pbGodModeMenu
```

This is the most reliable fallback for custom engines and mobile ports.

## Installer Modes

The installer currently supports:

- `Install`
  Injects PokeDebug into the target game.
- `Dry Run`
  Scans and reports what would happen without changing files.
- `Uninstall`
  Removes injected files and tries to roll back backups.
- `Restore Backups`
  Restores `.pokedebug.bak` files only.

## Injection Detection

The installer can detect and choose between common methods:

- `MKXP Preload`
- `RGSS Patch`
- `Hybrid MKXP + RGSS`

It also tries to detect Enigma-packed games and can offer unpack assistance before injection.

## Tips For Testers

- If the menu does not open on mobile, test the script call fallback first.
- If the game is heavily customized, use `Dry Run` before a real install.
- If the game was packed, let the installer inspect it before copying files around manually.
- If a build acts strangely after stat overcap edits, test battle flow with a backup save first.

## Known Good Opening Methods

- PC keyboard: `F6`
- JoiPlay default overlay fallback: hold `A + B + C`
- Custom mapped mobile overlay: `L + R` or `AUX1 + AUX2`
- Event/script call: `pbPokeDebugMenu`
