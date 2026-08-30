# Developing uissoca

DOS2's UI is **Flash (.swf)** rendered by Scaleform. Restyling/scaling = editing `.swf`
files; new behaviour = **Script Extender (SE) Lua** driving those files. Both ship in the
same `uissoca.pak`. Divinity Engine 2 is only used for `meta.lsx` and Workshop upload.

All game tooling is Windows-side. Edit/git from WSL; run the tools from Windows
(PowerShell) or via `cmd.exe /c` from WSL.

## 1. Toolchain (Windows)
| Tool | Purpose | Get it |
|---|---|---|
| Divinity Engine 2 | generate `meta.lsx`, publish to Workshop | Steam → Library → Tools |
| Script Extender | Lua runtime + UI API | https://github.com/Norbyte/ositools/releases — copy `DXGI.dll` to `<game>\DefEd\bin\` |
| LSLib / ConverterApp (`divine.exe`) | unpack game `.pak`s, pack the mod | https://github.com/Norbyte/lslib/releases |
| JPEXS Free Flash Decompiler | edit `.swf` | https://github.com/jindrapetrik/jpexs-decompiler |

Paths used below:
- `GAME` = `C:\Program Files (x86)\Steam\steamapps\common\Divinity Original Sin 2`
  (WSL: `/mnt/c/Program Files (x86)/Steam/steamapps/common/Divinity Original Sin 2`)
- `MODS` = `%LOCALAPPDATA%\Larian Studios\Divinity Original Sin 2 Definitive Edition\Mods`

Enable the SE console: edit `GAME\DefEd\bin\ScriptExtenderSettings.json`:
```json
{ "CreateConsole": true, "DeveloperMode": true, "EnableLogging": true }
```

## 2. Repo layout
```
src/                       → contents of uissoca.pak
  Mods/uissoca/
    meta.lsx               ← generate with Engine 2 (step 3), contains the mod UUID
    ScriptExtender/
      Config.json          ← enables Lua for this mod
      Lua/
        BootstrapClient.lua  ← UI work lives client-side
        BootstrapServer.lua
        Client/*.lua
  Public/uissoca/
    Game/GUI/*.swf         ← overrides: same relative path as vanilla wins
vanilla/                   ← unpacked vanilla assets for reference (git-ignored)
scripts/                   ← build / deploy helpers
```

## 3. First-time setup
1. In Divinity Engine 2: **Project → New**, name `uissoca`, type *Add-on*, dependencies
   Shared + Origins. Save. Copy the generated `Mods\uissoca_<uuid>\meta.lsx` into
   `src/Mods/uissoca/meta.lsx` (keep the folder name `uissoca` — meta.lsx's `Folder`
   attribute must match; edit it if the Engine appended a UUID).
2. Unpack vanilla UI for reference (PowerShell):
   ```powershell
   $d = "path\to\divine.exe"
   foreach ($p in "Shared","Game","Patch1") {   # also Patch2..PatchN if present
     & $d -g dos2de -a extract-package -s "$env:GAME\DefEd\Data\$p.pak" -d "vanilla\$p"
   }
   ```
   UI swfs are under `vanilla/<pak>/Public/Game/GUI/`. Never commit `vanilla/`.

## 4. Build & deploy
```powershell
scripts\build.ps1        # packs src/ → build/uissoca.pak and copies it to $MODS
```
Then launch the game → Mods → enable *uissoca* → load a save. The SE console should print
`[uissoca] client loaded`.

Iteration tip: with `DeveloperMode` on, SE reloads Lua when you type `!reset` in the console,
so Lua edits don't need a repack — just re-run `build.ps1` (it's fast) or copy the file
straight into `MODS\uissoca\` as a loose folder (loose folders are loaded too).

## 5. Where each feature lives
### New panels / overlays / behaviour → Lua
- Entry: `src/Mods/uissoca/ScriptExtender/Lua/BootstrapClient.lua`.
- Hook `Ext.Events.SessionLoaded` (UI exists from then on).
- Existing panels: `Ext.UI.GetByType(id)` / `Ext.UI.GetByName("hotBar")`, then
  `ui:GetRoot()` gives the Flash object tree (`root.hotbar_mc.x = ...`).
- New panels: `Ext.UI.Create("uissoca_Panel", "Public/uissoca/GUI/panel.swf", layer)`;
  Flash→Lua with `Ext.RegisterUICall(ui, "event", fn)`, Lua→Flash with `ui:Invoke("fn", ...)`.
- API docs: https://github.com/Norbyte/ositools/blob/master/Docs/API.md — UI type ids and
  function names change between SE versions; check the docs for the installed version.

### Restyle existing menus → .swf overrides
1. Copy the vanilla swf (e.g. `hotBar.swf`, `characterSheet.swf`,
   `inventorySkillPanel.swf`) from `vanilla/` to `src/Public/uissoca/Game/GUI/`.
2. Open in JPEXS: shapes/colors under *shapes*, layout in *sprites*, logic in *scripts*
   (ActionScript 3). Save as swf (uncompressed is fine).
3. Log what you changed in `src/Public/uissoca/Game/GUI/CHANGES.md` — swf edits aren't
   diffable, and you'll need to redo them after a game patch replaces the base file.

### Bigger UI / fonts
- Prefer Lua: scale from `SessionLoaded` (`root.scaleX = root.scaleY = 1.25`) and read the
  factor from a mod setting so users can tune it. Cheap and patch-resistant.
- Fonts: replace font definitions inside the swf in JPEXS (*fonts* node → import TTF),
  or swap the shared font assets. Only do this when Lua scaling isn't enough.

## 6. Publish
- **Workshop**: Divinity Engine 2 → Project → Publish. The Engine expects the project in its
  own Data dir, so point it at (or copy in) `src/`. Re-publishing updates the same item.
- **Nexus**: zip `build/uissoca.pak` + `README.md`.

## 7. Testing checklist
- [ ] SE console shows `[uissoca] client loaded`, no Lua errors
- [ ] Each overridden panel opens and is usable (hotbar, sheet, inventory, dialog)
- [ ] 1080p, 1440p, 4K — nothing clipped
- [ ] Controller mode (it uses different swfs — `*_c.swf`; leave or handle separately)
- [ ] Fresh Workshop subscribe on a clean profile actually installs the pak
