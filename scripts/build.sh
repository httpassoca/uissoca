#!/usr/bin/env bash
# WSL wrapper: runs build.ps1 on the Windows side.
cd "$(dirname "$0")/.." && powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w scripts/build.ps1)"
