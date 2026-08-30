-- Stacked hotbar rows: show all 5 bars. Requires our patched Public/.../GUI/hotBar.swf
-- (tools/as3-patches/hotBar.py): slotHolder builds 5*29 slots laid out in rows above the bar,
-- each with an "iggy_uissoca_slot_<i>" child the engine paints icons into (ui:SetCustomIcon),
-- and getSlotOnXY resolves hover/click for every row.
--
-- Row 0 (y=0) stays engine-driven = the current bar. Rows 1..4 above show the other bars in
-- ascending order and are filled here from char.PlayerData.SkillBarItems (145 = 5 bars * 29).

local HOTBAR = 40
local SLOTS_PER_BAR = 29
local BARS = 5
local ICON_PX = 48
local M = { rows = BARS, rowBar = {} }   -- rowBar[row] = bar shown in that row

local function ui() return Ext.UI.GetByType(HOTBAR) end
local function holder(root) return root.hotbar_mc.slotholder_mc end
local function slotAt(h, i) return h.slot_array[i] end   -- Flash arrays are 0-based from Lua

local function playerChar()
    local pm = Ext.Entity.GetPlayerManager()
    local data = pm and pm.ClientPlayerData and pm.ClientPlayerData[1]
    return data and Ext.Entity.GetCharacter(data.CharacterNetId) or nil
end

local function currentBar(root)
    return tonumber(root.hotbar_mc.cycleHotBar_mc.currentHotBarIndex) or 1
end

local function iconFor(char, data)
    local t = data.Type
    if t == "Skill" or t == "Action" then
        local stat = Ext.Stats.Get(data.SkillOrStatId)
        return stat and stat.Icon or nil
    elseif t == "Item" then
        local item = Ext.Entity.GetItem(data.ItemHandle)
        if not item then return nil end
        local ok, icon = pcall(function() return item.Icon or (item.RootTemplate and item.RootTemplate.Icon) end)
        return ok and icon or nil
    end
    return nil
end

-- Lua port of slotHolder.clearSlotMC (can't pass a Flash object as an AS3 argument from Lua).
local function clearSlot(u, i, slot)
    slot.inUse = false; slot.tooltip = ""; slot.handle = 0; slot.type = 0; slot.amount = 0
    slot.isEnabled = false
    slot.amount_mc.visible = false; slot.disable_mc.visible = false
    slot.unavailable_mc.visible = false; slot.refreshSlot_mc.visible = false
    pcall(function() u:ClearCustomIcon("uissoca_slot_" .. i) end)
end

local function renderRow(u, root, char, row, bar)
    local h = holder(root)
    local items = char.PlayerData.SkillBarItems
    for col = 0, SLOTS_PER_BAR - 1 do
        local idx = row * SLOTS_PER_BAR + col
        local data = items[(bar - 1) * SLOTS_PER_BAR + col + 1]
        local slot = slotAt(h, idx)
        if slot then
            local icon = data and iconFor(char, data)
            if icon then
                local isItem = data.Type == "Item"
                local amount = 0
                if isItem then
                    local item = Ext.Entity.GetItem(data.ItemHandle)
                    amount = item and item.Amount or 0
                end
                h.setSlot(idx, isItem and "" or data.SkillOrStatId, true, 0, isItem and 2 or 1, amount)
                u:SetCustomIcon("uissoca_slot_" .. idx, icon, ICON_PX, ICON_PX)
            else
                clearSlot(u, idx, slot)
            end
        end
    end
end

function M.Render()
    local u = ui(); if not u then return end
    local root = u:GetRoot()
    local h = root.hotbar_mc and root.hotbar_mc.slotholder_mc
    if not h then return end
    if h.slot_array.length < BARS * SLOTS_PER_BAR then
        Ext.Utils.PrintWarning("[uissoca] patched hotBar.swf not loaded (slots=" .. tostring(h.slot_array.length) .. ") - restart the game after dev-sync")
        return
    end
    local char = playerChar(); if not char then return end
    local cur = currentBar(root)
    M.rowBar = { [0] = cur }
    local row = 1
    for bar = 1, BARS do
        if bar ~= cur then
            local visible = row < M.rows
            for col = 0, SLOTS_PER_BAR - 1 do
                local s = slotAt(h, row * SLOTS_PER_BAR + col); if s then s.visible = visible end
            end
            if visible then M.rowBar[row] = bar; renderRow(u, root, char, row, bar) end
            row = row + 1
        end
    end
end

local function safeRender()
    local ok, err = pcall(M.Render)
    if not ok then Ext.Utils.PrintError("[uissoca] HotbarRows: " .. tostring(err)) end
end

function M.SetRows(n)
    M.rows = math.max(1, math.min(BARS, math.floor(tonumber(n) or BARS)))
    safeRender()
    Ext.Utils.Print("[uissoca] hotbar rows: " .. M.rows)
end

-- Experimental: a press on a slot in row >= 1 -> switch the engine to that bar, press the
-- matching slot there, switch back. The engine ignores SlotPressed for ids it doesn't know (>= 29).
local function cycleTo(u, root, bar)
    local guard = 0
    while currentBar(root) ~= bar and guard < BARS do
        u:ExternalInterfaceCall("nextHotbar"); guard = guard + 1
    end
end
Ext.RegisterUITypeCall(HOTBAR, "SlotPressed", function(u, _, id, enabled)
    id = tonumber(id) or -1
    if id < SLOTS_PER_BAR then return end
    local row, col = math.floor(id / SLOTS_PER_BAR), id % SLOTS_PER_BAR
    local bar = M.rowBar[row]; if not bar then return end
    local root = u:GetRoot()
    local before = currentBar(root)
    cycleTo(u, root, bar)
    u:ExternalInterfaceCall("SlotPressed", col, true)
    cycleTo(u, root, before)
    Ext.Utils.Print(string.format("[uissoca] pressed bar %d slot %d", bar, col + 1))
end)

Ext.RegisterUITypeInvokeListener(HOTBAR, "updateSlots", safeRender)
Ext.RegisterUITypeInvokeListener(HOTBAR, "setCurrentHotbar", safeRender)
Ext.Events.SessionLoaded:Subscribe(safeRender)
Ext.RegisterConsoleCommand("hotbarrows", function(_, n) M.SetRows(n) end)
pcall(function() if Ext.Client.GetGameState() == "Running" then safeRender() end end)
return M
