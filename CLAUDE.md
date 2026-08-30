# uissoca — Claude working notes

UI mod for Divinity: Original Sin 2 Definitive Edition. Lua via Norbyte's Script Extender (SE)
+ `.swf` overrides. Human-facing docs: `README.md` (users), `DEV.md` (full dev guide).
This file = the non-obvious facts that cost time to discover. Keep it current.

## Environment
- Repo lives in WSL (`~/dev/uissoca`); the game, LSLib and the Engine are on Windows.
- Game: `C:\Program Files (x86)\Steam\steamapps\common\Divinity Original Sin 2\DefEd\`
  (WSL: `/mnt/c/Program Files (x86)/Steam/steamapps/common/Divinity Original Sin 2/DefEd`)
- Mods folder: `C:\Users\privr\Documents\Larian Studios\Divinity Original Sin 2 Definitive Edition\Mods`
  (**Documents**, not LocalAppData). Profiles/modsettings.lsx live next to it under `PlayerProfiles\`.
- LSLib: `C:\Tools\lslib\Tools\Divine.exe`. Run Windows tools from WSL with `powershell.exe -NoProfile -Command "& '...'"`.
- SE updater = `DefEd\bin\dxgi.dll`; real extender is downloaded to `%LOCALAPPDATA%\DOS2ScriptExtender\ScriptExtender\<ver>\OsiExtenderEoCApp.dll` (v60 installed).
- SE settings file is **`DefEd\bin\OsirisExtenderSettings.json`** (`ScriptExtenderSettings.json` is BG3's name and is ignored):
  `{ "CreateConsole": true, "DeveloperMode": true, "EnableLogging": true }`
- Game logs: `DefEd\bin\gold.log` / `network.log`. Last line `Client Thread start: LoadMenu` with no "ended" = hung on menu load.
- Engine project (for Workshop publish only) is parked at `C:\Users\privr\Documents\uissoca_engine_project\`.
  It must NOT sit in `DefEd\Data\{Mods,Public,Projects}` while testing — the game loads loose folders there
  and lists the mod twice / loads the empty Engine copy instead of ours.

## Mod identity
- UUID `a9f901c0-ef39-4840-aba4-f49f4a330c70`; `Folder` = `uissoca_a9f901c0-ef39-4840-aba4-f49f4a330c70`.
  Folder names under `src/Mods` and `src/Public` MUST equal meta.lsx `Folder`.
- Mods are identified by `meta.lsx`, not folder name — renaming a folder does not hide it.

## DOS2 Script Extender layout (NOT BG3's)
```
src/Mods/<Folder>/OsiToolsConfig.json                 {"RequiredExtensionVersion":56,"ModTable":"uissoca","FeatureFlags":["Lua"]}
src/Mods/<Folder>/Story/RawFiles/Lua/BootstrapClient.lua   ← UI work (client side)
src/Mods/<Folder>/Story/RawFiles/Lua/BootstrapServer.lua
src/Mods/<Folder>/Story/RawFiles/Lua/Client/*.lua          loaded via Ext.Require("Client/X.lua")
src/Public/<Folder>/Game/GUI/*.swf                         vanilla overrides (same relative path wins)
```
BG3's `ScriptExtender/Config.json` + `ScriptExtender/Lua/` silently does nothing here.
SE API reference: https://github.com/Norbyte/ositools/blob/master/Docs/API.md — verify names
against the installed version; `strings` on `OsiExtenderEoCApp.dll` is a reliable ground truth.

## Dev loop (real-time, game stays open)
```
scripts/dev-sync.sh   # src/ → DefEd\Data\{Mods,Public}\<Folder> as LOOSE folders; deletes uissoca.pak
                      # then in the SE console:  client  →  reset
scripts/dev-clean.sh  # remove the loose copy
scripts/build.sh      # RELEASE only: pack → Documents\...\Mods\uissoca.pak (game must be CLOSED; pak is locked while running)
```
- Never have loose copy + pak at once (duplicate mod entry).
- Lua/console changes = instant. `.swf`, textures, meta.lsx, OsiToolsConfig.json = full game restart
  (quit-to-menu does NOT reload swfs).
- `Ext.Events.SessionLoaded` does not re-fire after `reset`; `Client/UI.lua` re-applies via
  `Ext.Client.GetGameState() == "Running"` at load.

## SE console (the black window)
- Any key enters console mode. Prompt `S >>` = server context, `C >>` = client. **UI code is client-side:
  type `client` first.** Built-in commands have no `!` inside the console (`client`, `server`, `reset`,
  `reset client`, `exit`); mod commands registered with `Ext.RegisterConsoleCommand` keep the `!`.
- Plain lines are evaluated as Lua in the current context — use it to prototype:
  `Ext.UI.GetByType(40):GetRoot().hotbar_mc.alpha = 0.5`
- Current mod commands: `!uiscale <n>` (client) scales the hotbar live; `!uiscale` prints geometry.
- Noise to ignore: `Ext.GameVersion is deprecated` (SE's own libs), `Event handle not mapped`,
  `Iggy Error: onEventTerminate`.

## UI facts learned
- Built-in panels: `Ext.UI.GetByType(id)` (fallback `Ext.UI.GetByPath("Public/Game/GUI/<name>.swf")`).
  `Ext.UI.GetByName` only finds mod-created UIs. Known ids: hotBar=40, examine=104, partyInventory=116,
  statusConsole=117, playerInfo=118, characterSheet=119. Full list in SE API.md "Built-in UI types".
- `ui:GetRoot()` is the full-screen stage (≈1948×1192 at the user's res). Scaling the root scales the
  whole canvas and pushes bottom-anchored bars off-screen. Scale the inner clip instead.
- Hotbar internals + stacked-rows design: `docs/hotbar-rows.md`. Console: `!hotbarrows N`.
- `hotBar.swf` clip names (from `vanilla/Game/Public/Game/GUI/hotBar.swf`): `hotbar_mc` (the bar),
  inside it `slotholder_mc`, `basebar_mc`, `basebarFrame_mc`, `hotkeys_mc`, `key1_mc..key12_mc`,
  `cycleHotBar_mc`, `lockButton_mc`, `actionsButton_mc`, `expBar_mc`, `chatBtn_mc`, `showLog_mc`,
  `sourceHolder_mc`, `actionSkillHolder_mc`, `btnContainer_mc`. AS3 fns present: `setHotbar`,
  `updateSlots`, `setSlotAmount`. The game may reposition `hotbar_mc` on slot-count/resize events.
- Get clip names for any panel without JPEXS: zlib-inflate the swf (CWS) and grep `[A-Za-z_]+_mc`.
- Vanilla GUI extracted to `vanilla/Game/Public/Game/GUI/` (132 swfs, git-ignored). `Shared.pak` has no UI.
  Re-extract: `Divine.exe -g dos2de -a extract-package -s <Game.pak> -d vanilla/Game -x '*/GUI/*'`.

## Tooling from WSL
- JPEXS CLI: `powershell.exe -NoProfile -Command "& 'C:\Program Files (x86)\FFDec\ffdec-cli.exe' -export script <outdir> <swf>"`
  (also `-importScript` to compile edited AS3 back). Vanilla hotBar AS3 already exported to
  `vanilla/as3/hotBar/scripts/` (git-ignored) — read `hotBar_fla/slotHolder_14.as`, `MainTimeline.as`, `bottombar_1.as`.
- Feature notes live in `docs/<feature>.md` (see `docs/hotbar-rows.md`).

## Conventions
- Prefix all console output with `[uissoca]`. Wrap UI mutations in `pcall` and `PrintError` failures.
- Prefer Lua (patch-resistant, live) over swf edits; log every JPEXS edit in `src/Public/<Folder>/Game/GUI/CHANGES.md`.
- Don't commit `vanilla/` or `build/` (Larian assets / artifacts).
- Commit with `git commit`; push to `github.com/httpassoca/uissoca` (master). User works in auto mode.
- When something "does nothing": check prompt context (S vs C), loose-vs-pak duplication, and the DOS2-vs-BG3 layout — in that order.
