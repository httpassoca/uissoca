# uissoca

UI improvements for **Divinity: Original Sin 2 – Definitive Edition**.

## What it does (planned)
- **Restyled menus** — cleaner hotbar, character sheet and inventory panels.
- **Bigger, readable UI** — configurable scaling for text and icons, especially at 1440p/4K.
- **New overlays & QoL** — extra info panels and hotkeys powered by the Script Extender.

## Requirements
- Divinity: Original Sin 2 – Definitive Edition
- [Norbyte's Script Extender](https://github.com/Norbyte/ositools) installed (`DXGI.dll` in `DefEd/bin/`)

## Install
1. Drop `uissoca.pak` into
   `%LOCALAPPDATA%\Larian Studios\Divinity Original Sin 2 Definitive Edition\Mods`
   (or subscribe on the Steam Workshop).
2. Launch the game → **Mods** → enable *uissoca* → load a save.

## Compatibility
uissoca overrides vanilla UI `.swf` files. Other mods that replace the same panels will
conflict — load uissoca **last** to give it priority, or disable the overlapping mod.

## Development
See [DEV.md](DEV.md).

## License
Lua/scripts in this repo: MIT. Vanilla game assets are Larian Studios' property and are
not included; only modified derivatives required by the mod are distributed.
