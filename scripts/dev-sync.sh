#!/usr/bin/env bash
# DEV loop: copy src/ as LOOSE folders into the game's Data dir (no pak), then type !reset in the SE console.
# Works while the game is running. Removes uissoca.pak from Documents\Mods to avoid a duplicate mod entry.
set -e
cd "$(dirname "$0")/.."
GAME="/mnt/c/Program Files (x86)/Steam/steamapps/common/Divinity Original Sin 2/DefEd/Data"
MODS="$(wslpath "$(powershell.exe -NoProfile -Command '[Environment]::GetFolderPath("MyDocuments")' | tr -d '\r')")/Larian Studios/Divinity Original Sin 2 Definitive Edition/Mods"
rm -f "$MODS/uissoca.pak"
for d in Mods Public; do
  for m in src/$d/*/; do
    n=$(basename "$m"); rm -rf "$GAME/$d/$n"; mkdir -p "$GAME/$d"; cp -r "$m" "$GAME/$d/$n"
  done
done
echo "Synced loose mod to $GAME  → type !reset in the SE console"
