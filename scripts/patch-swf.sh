#!/usr/bin/env bash
# Rebuild patched swfs: vanilla swf + tools/as3-patches/<name>.py → src/Public/<Folder>/Game/GUI/<name>.swf
# Requires JPEXS on Windows and vanilla/as3/<name>/scripts (export with: ffdec-cli -export script ...).
set -e
cd "$(dirname "$0")/.."
FFDEC='C:\Program Files (x86)\FFDec\ffdec-cli.exe'
FOLDER=$(basename src/Mods/*/)
for py in tools/as3-patches/*.py; do
  name=$(basename "$py" .py)
  van="vanilla/Game/Public/Game/GUI/$name.swf"
  exp="vanilla/as3/$name"
  [ -d "$exp/scripts" ] || { mkdir -p "$exp"; powershell.exe -NoProfile -Command "& '$FFDEC' -export script '$(wslpath -w "$exp")' '$(wslpath -w "$van")'" | tail -1; }
  rm -rf "build/as3/$name"; mkdir -p "build/as3/$name/scripts"
  python3 "$py" "$exp/scripts" "build/as3/$name/scripts"
  out="src/Public/$FOLDER/Game/GUI/$name.swf"; mkdir -p "$(dirname "$out")"
  powershell.exe -NoProfile -Command "& '$FFDEC' -importScript '$(wslpath -w "$van")' '$(wslpath -w "$out")' '$(wslpath -w "build/as3/$name/scripts")'" | tail -4
  ls -l "$out"
done
