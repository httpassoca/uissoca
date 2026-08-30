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
  Copy `DefEd\Data\Mods\uissoca_<uuid>\meta.lsx` → `src\Mods\uissoca_<uuid>\meta.lsx`. The folder
  names under `src/Mods` and `src/Public` must equal meta.lsx's `Folder` attribute
  (`uissoca_<uuid>`) — already done in this repo.

### Script Extender (SE) — Lua inside the game
- Norbyte's DLL that hooks the game and exposes UI/stats/characters to Lua. Needed for
  anything dynamic (overlays, runtime scaling, event reactions).
- Install: https://github.com/Norbyte/ositools/releases → copy `DXGI.dll` to `DefEd\bin\`.
- Create `DefEd\bin\OsirisExtenderSettings.json`:
  ```json
  { "CreateConsole": true, "DeveloperMode": true, "EnableLogging": true }
  ```
  `CreateConsole` = a console window showing `Ext.Utils.Print` output and Lua errors;
  `DeveloperMode` = `!reset` hot-reloads Lua without repacking.
- Nothing to click: `src/Mods/uissoca_<uuid>/OsiToolsConfig.json` tells SE to load Lua for
  this mod and `Story/RawFiles/Lua/BootstrapClient.lua` runs on session load.
  (BG3 uses `ScriptExtender/Config.json` + `ScriptExtender/Lua/` — that layout does NOT work in DOS2.)

### JPEXS Free Flash Decompiler — edit .swf UI files
- Only for *restyling* existing panels (colors, layout, fonts baked into the swf).
- Install: https://github.com/jindrapetrik/jpexs-decompiler/releases (build "with Java").
- Use: copy the vanilla swf into `src/Public/uissoca_<uuid>/Game/GUI/`, open the copy. Tree:
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
- `MODS` = `%USERPROFILE%\Documents\Larian Studios\Divinity Original Sin 2 Definitive Edition\Mods`

Enable the SE console: edit `GAME\DefEd\bin\OsirisExtenderSettings.json`:
```json
{ "CreateConsole": true, "DeveloperMode": true, "EnableLogging": true }
```

## 2. Repo layout
```
src/                       → contents of uissoca.pak
  Mods/uissoca_<uuid>/   (folder name must equal meta.lsx Folder attr)
    meta.lsx               ← generate with Engine 2 (step 3), contains the mod UUID
    Story/RawFiles/Lua/
      Config.json          ← enables Lua for this mod
      Lua/
        BootstrapClient.lua  ← UI work lives client-side
        BootstrapServer.lua
        Client/*.lua
  Public/uissoca_<uuid>/
    Game/GUI/*.swf         ← overrides: same relative path as vanilla wins
vanilla/                   ← unpacked vanilla assets for reference (git-ignored)
scripts/                   ← build / deploy helpers
```

## 3. First-time setup
1. In Divinity Engine 2: **Project → New**, name `uissoca`, type *Add-on*, dependencies
   Shared + Origins. Save. Copy the generated `Mods\uissoca_<uuid>\meta.lsx` into
   `src/Mods/uissoca_<uuid>/meta.lsx` (already done).
2. Unpack vanilla UI for reference (PowerShell):
   ```powershell
   $d = "path\to\divine.exe"
   foreach ($p in "Shared","Game","Patch1") {   # also Patch2..PatchN if present
     & $d -g dos2de -a extract-package -s "$env:GAME\DefEd\Data\$p.pak" -d "vanilla\$p"
   }
   ```
   UI swfs are under `vanilla/<pak>/Public/Game/GUI/`. Never commit `vanilla/`.

## 4. Dev loop vs. release build
The game locks `uissoca.pak` while running, so packing is for releases only. For day-to-day
work use **loose folders** in the game's `Data\` dir — SE reads Lua straight from disk and
`!reset` in the console reloads it without restarting.

```bash
scripts/dev-sync.sh   # copies src/ → DefEd\Data\{Mods,Public}\uissoca_<uuid> (loose), deletes the pak
# ...edit Lua...  → scripts/dev-sync.sh → type !reset in the SE console
scripts/dev-clean.sh  # remove the loose copy
scripts/build.sh      # pack src/ → build/uissoca.pak → Documents\...\Mods  (game must be closed)
```
Never have both the loose copy and the pak at the same time — the game lists the mod twice.
swf changes need a full restart even in loose mode (Flash files are loaded once).

Verify: with the mod enabled, load a save; the SE console should print
`[uissoca] client loaded` and `[uissoca] hotbar scaled to 1`.

**SE console:** press any key to enter input mode. Plain lines are evaluated as Lua
(`Ext.Utils.Print(Ext.UI.GetByType(40))`), `!reset` reloads all mod Lua, `!help` lists commands.

## 5. Where each feature lives
### New panels / overlays / behaviour → Lua
- Entry: `src/Mods/uissoca_<uuid>/Story/RawFiles/Lua/BootstrapClient.lua`.
- Hook `Ext.Events.SessionLoaded` (UI exists from then on).
- Existing panels: `Ext.UI.GetByType(id)` / `Ext.UI.GetByName("hotBar")`, then
  `ui:GetRoot()` gives the Flash object tree (`root.hotbar_mc.x = ...`).
- New panels: `Ext.UI.Create("uissoca_Panel", "Public/uissoca/GUI/panel.swf", layer)`;
  Flash→Lua with `Ext.RegisterUICall(ui, "event", fn)`, Lua→Flash with `ui:Invoke("fn", ...)`.
- API docs: https://github.com/Norbyte/ositools/blob/master/Docs/API.md — UI type ids and
  function names change between SE versions; check the docs for the installed version.

### Restyle existing menus → .swf overrides
1. Copy the vanilla swf (e.g. `hotBar.swf`, `characterSheet.swf`,
   `inventorySkillPanel.swf`) from `vanilla/` to `src/Public/uissoca_<uuid>/Game/GUI/`.
2. Open in JPEXS: shapes/colors under *shapes*, layout in *sprites*, logic in *scripts*
   (ActionScript 3). Save as swf (uncompressed is fine).
3. Log what you changed in `src/Public/uissoca_<uuid>/Game/GUI/CHANGES.md` — swf edits aren't
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

## 8. Troubleshooting
**Game stuck on loading / never reaches main menu.** Check `DefEd\bin\gold.log`: if the last
line is `Client Thread start: LoadMenu`, it hung loading the menu. Bisect in this order:
1. `OsirisExtenderSettings.json` → `"CreateConsole": false`. In fullscreen the console window
   steals focus and the game can look frozen/black. Use borderless window when developing.
2. Rename `DefEd\bin\dxgi.dll` → `dxgi.dll.off` and relaunch. Loads? Then SE is the issue —
   check `%LOCALAPPDATA%\DOS2ScriptExtender\` (updater cache; it must contain
   `ScriptExtender\<ver>\OsiExtenderEoCApp.dll`) and the SE console for errors.
3. Move the Engine's loose project out of the game dir: `DefEd\Data\Mods\uissoca_<uuid>`,
   `DefEd\Data\Public\uissoca_<uuid>`, `DefEd\Data\Projects\uissoca_<uuid>`. The game scans
   loose folders in `Data\Mods`; a half-built project there can break module loading. Keep
   Engine projects only while the Engine is open, or work from the pak in the Mods folder.

**Mod not in the Mods menu.** `uissoca.pak` must be in `Documents\Larian Studios\Divinity
Original Sin 2 Definitive Edition\Mods` (not LocalAppData), and the folder names inside the
pak must match meta.lsx `Folder`.

**No `[uissoca]` line in the console.** SE didn't load Lua for the mod: check
`OsiToolsConfig.json` exists at `Mods/uissoca_<uuid>/OsiToolsConfig.json`
and the mod is *enabled* (modsettings.lsx lists it) — SE only loads Lua for active mods.
