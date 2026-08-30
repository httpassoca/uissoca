# Packs src/ into build/uissoca.pak and deploys it to the DOS2 DE Mods folder.
# Requires divine.exe from LSLib: set $env:DIVINE or edit the path below.
$ErrorActionPreference = "Stop"
$root   = Split-Path -Parent $PSScriptRoot
$divine = if ($env:DIVINE) { $env:DIVINE } else { "C:\Tools\lslib\divine.exe" }
$mods   = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Larian Studios\Divinity Original Sin 2 Definitive Edition\Mods"
New-Item -ItemType Directory -Force "$root\build" | Out-Null
& $divine -g dos2de -a create-package -s "$root\src" -d "$root\build\uissoca.pak" -c lz4
Copy-Item "$root\build\uissoca.pak" $mods -Force
Write-Host "Deployed uissoca.pak to $mods"
