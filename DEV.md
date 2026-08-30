# Developing uissoca

DOS2's UI is **Flash (.swf)** rendered by Scaleform. Restyling/scaling = editing `.swf`
files; new behaviour = **Script Extender (SE) Lua** driving those files. Both ship in the
same `uissoca.pak`. Divinity Engine 2 is only used for `meta.lsx` and Workshop upload.

All game tooling is Windows-side. Edit/git from WSL; run the tools from Windows
(PowerShell) or via `cmd.exe /c` from WSL.

## 1. Toolchain (Windows)
A mod is a `.pak` archive dropped in the Mods folder. Files inside either *replace* vanilla
files (same relative path wins) or *add* new ones. Workflow: **look at vanilla files →
change/add files → pack → test → upload.** Each tool covers one arrow.

### LSLib (`ConverterApp.exe` GUI / `divine.exe` CLI) — unpack & pack
- Vanilla UI lives inside `Shared.pak`, `Game.pak`, `Patch*.pak`; LSLib extracts them and
  packs `src/` back into `uissoca.pak`.
- Install: https://github.com/Norbyte/lslib/releases → extract zip to `C:\Tools\lslib\`.
- GUI: `ConverterApp.exe` → *PAK / LSV Tools* → *Extract Package* (source `DefEd\Data\Shared.pak`,
  dest `vanilla\Shared`). CLI: used by `scripts\build.ps1` (set `$env:DIVINE` to `divine.exe`).

### Divinity Engine 2 — mod identity & Workshop upload
- Larian's official editor (Steam → Library → Tools). Used for exactly two things:
  generating `meta.lsx` (mod UUID/name/version/deps — required for the game to list the
  mod) and the *Publish to Workshop* button. Not used for editing UI.
- Use: *Project → New Project*, name `uissoca`, type **Add-on**, deps Shared + Origins.
  Copy `DefEd\Data\Mods\uissoca_<uuid>\meta.lsx` → `src\Mods\uissoca\meta.lsx`; check its
  `Folder` attribute equals `uissoca`.

### Script Extender (SE) — Lua inside the game
- Norbyte's DLL that hooks the game and exposes UI/stats/characters to Lua. Needed for
  anything dynamic (overlays, runtime scaling, event reactions).
- Install: https://github.com/Norbyte/ositools/releases → copy `DXGI.dll` to `DefEd\bin\`.
- Create `DefEd\bin\ScriptExtenderSettings.json`:
  ```json
  { "CreateConsole": true, "DeveloperMode": true, "EnableLogging": true }
  ```
  `CreateConsole` = a console window showing `Ext.Utils.Print` output and Lua errors;
  `DeveloperMode` = `!reset` hot-reloads Lua without repacking.
- Nothing to click: `src/Mods/uissoca/ScriptExtender/Config.json` tells SE to load Lua for
  this mod and `BootstrapClient.lua` runs on session load.

### JPEXS Free Flash Decompiler — edit .swf UI files
- Only for *restyling* existing panels (colors, layout, fonts baked into the swf).
- Install: https://github.com/jindrapetrik/jpexs-decompiler/releases (build "with Java").
- Use: copy the vanilla swf into `src/Public/uissoca/Game/GUI/`, open the copy. Tree:
  *shapes* (vector art/colors), *images*, *fonts*, *sprites* (layout), *scripts* (AS3 logic).
  Edit → Save → log the change in `CHANGES.md`.

### First-run order
1. SE (`DXGI.dll` + settings) → launch game once, confirm the console window appears.
2. Engine 2 → create project → copy `meta.lsx`.
3. LSLib → `scripts/build.sh` → enable mod in game → console prints `[uissoca] client loaded`.
4. JPEXS only when you start restyling.

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
