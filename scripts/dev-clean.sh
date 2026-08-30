#!/usr/bin/env bash
# Remove the loose dev copy from the game's Data dir (run before build.sh / publishing).
GAME="/mnt/c/Program Files (x86)/Steam/steamapps/common/Divinity Original Sin 2/DefEd/Data"
for m in "$(dirname "$0")"/../src/Mods/*/; do n=$(basename "$m"); rm -rf "$GAME/Mods/$n" "$GAME/Public/$n"; done
echo "Removed loose copy from $GAME"
