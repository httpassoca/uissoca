# Feature: stacked hotbar rows (show all 5 bars)

## Vanilla mechanics (from `vanilla/as3/hotBar/scripts/`, exported with JPEXS CLI)
- `hotBar_fla/slotHolder_14.initSlot()` creates `root.maxSlots` (29) `Slot` clips in a single row:
  `x = i*(cellWidth+cellSpacing)` (50+8), `y = 0`, `id = i`, `name = "slot"+i`, pushed to `slot_array`.
- The engine only ever feeds the **current** bar: it fills `root.slotUpdateList` (7 values per slot:
  index, amount, tooltip/skillId, enabled, handle, type, hasSource) and invokes `updateSlots()`,
  which calls `setSlot(index, tooltip, enabled, handle, type, amount)`. Types: 1 skill, 2 item.
- Icons are drawn by the engine (iggy) from each Slot's `handle` + `type` + `tooltip`.
- Bar switching: `cycleHotBar_mc.currentHotBarIndex` (1..5); swf calls `prevHotbar`/`nextHotbar`;
  engine answers with `setCurrentHotbar(n)` + a new `updateSlots`.
- Click: `Slot.onClick` → `ExternalInterface.call("SlotPressed", id, isEnabled)`; hover/press are found
  via `slotHolder.getSlotOnXY(x, y)` which only uses **x** (one row assumed) — extra rows are not
  hoverable/clickable without an AS3 patch.
- Data source for all bars: `char.PlayerData.SkillBarItems[1..145]` (`Type` = None/Skill/Item/Action,
  `SkillOrStatId`, `ItemHandle`). Bar b = entries (b-1)*29+1 .. b*29.

## Phase 1 — display (DONE, pure Lua: `Client/HotbarRows.lua`)
- Call `initSlot()` until `slot_array.length == rows*29`, move extra slots to `y = -row*(58)`,
  fix `id`/`name` (initSlot restarts at 0).
- Row 0 stays engine-driven (current bar). Rows 1..4 = the other bars ascending, filled via
  `setSlot` from `SkillBarItems`. Re-render on `updateSlots` / `setCurrentHotbar` invokes.
- Console: `!hotbarrows N` (1..5).
- Open questions to verify in-game: does the engine draw icons for slots with index ≥ 29?
  (Epip proves it does with its own swf; unknown for re-used vanilla `Slot` instances.)

## Phase 2 — interaction (AS3 patch, via `ffdec-cli -importScript`)
- `getSlotOnXY`: derive row from `y` (`row = floor(-y/(cellHeight+cellSpacing))`), return
  `row*29 + col`. Mask/`scrollRect` on `hotbar_mc` must grow upward to include the rows.
- Press on slot ≥ 29 → Lua (`Ext.RegisterUITypeCall(40, "SlotPressed")`): map to (bar, col),
  cycle engine to that bar with `ui:ExternalInterfaceCall("nextHotbar")` until
  `currentHotBarIndex == bar`, send `ExternalInterfaceCall("SlotPressed", col, true)`, cycle back.
- Cooldowns/enabled state for extra rows: mirror from `char.SkillManager.Skills[id].ActiveCooldown`
  and `setSlotCoolDown` / `setSlotEnabled`; refresh on a ~0.5 s tick.
- Background: stretch `basebar_mc` / add a frame per row; drag-drop between rows via
  `startDragging`/`stopDragging` with remapped indices.

## Prior art
- Epip (github.com/pinewoodpip/epipencounters, **no license → study only, never copy**) ships a
  custom `hotBar.swf` + `UI/Hotbar/Main.lua`; uses exactly this data path (`SkillBarItems`,
  custom `pipSetSlot`, temporarily remapping the engine's current bar).
- "Improved Hotbar" (Workshop 2759281297) is obsolete, folded into Epip.
