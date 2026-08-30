-- Show all 5 hotbar rows stacked. Phase 1 = display only (pure Lua, no swf edit).
--
-- How it works: vanilla slotHolder.initSlot() builds root.maxSlots (29) Slot clips in ONE row.
-- It is a public AS3 function, so we call it again until slot_array holds 5*29 slots, move the
-- extra ones into rows above the bar, and fill them from char.PlayerData.SkillBarItems (145
-- entries, bar b = indices (b-1)*29+1 .. b*29). Row 0 (y=0) stays engine-driven = current bar;
-- rows 1..4 above it show the other bars in ascending order.
-- Hover/click on the extra rows needs an AS3 patch (getSlotOnXY is X-only) — phase 2.

local HOTBAR = 40
local SLOTS_PER_BAR = 29
local BARS = 5
local M = { rows = BARS, ready = false }   -- rows = how many bars to show (1 = vanilla)

local function ui() return Ext.UI.GetByType(HOTBAR) end

local function holder(root) return root.hotbar_mc.slotholder_mc end

-- Make sure slot_array has rows*29 slots and the extra ones are laid out above the bar.
local function ensureSlots(root)
    local h = holder(root)
    local want = M.rows * SLOTS_PER_BAR
    local guard = 0
    while h.slot_array.length < want and guard < BARS do h.initSlot(); guard = guard + 1 end
    local cw, ch, sp = h.cellWidth, h.cellHeight, h.cellSpacing
    for i = SLOTS_PER_BAR, h.slot_array.length - 1 do
        local s = h.getSlot(i)
        if s then
            local row, col = math.floor(i / SLOTS_PER_BAR), i % SLOTS_PER_BAR
            s.id = i                      -- initSlot restarts ids at 0; make them unique
            s.name = "slot" .. i
            s.x = col * (cw + sp)
            s.y = -row * (ch + sp)
            s.visible = row < M.rows
        end
    end
end

local function currentBar(root)
    return tonumber(root.hotbar_mc.cycleHotBar_mc.currentHotBarIndex) or 1
end

-- Fill one displayed row (1..4) from bar `bar` (1..5) of the character's skill bar.
local function renderRow(root, char, row, bar)
    local h = holder(root)
    local items = char.PlayerData.SkillBarItems
    for col = 0, SLOTS_PER_BAR - 1 do
        local idx = row * SLOTS_PER_BAR + col           -- slot index in slot_array
        local data = items[(bar - 1) * SLOTS_PER_BAR + col + 1]
        local slot = h.getSlot(idx)
        if slot and data then
            local t = data.Type
            if t == "Skill" or t == "Action" then
                local skill = char.SkillManager and char.SkillManager.Skills[data.SkillOrStatId]
                local owner = skill and skill.OwnerHandle or char.Handle
                h.setSlot(idx, data.SkillOrStatId, true, Ext.UI.HandleToDouble(owner), 1, 0)
            elseif t == "Item" then
                local item = Ext.Entity.GetItem(data.ItemHandle)
                if item then
                    h.setSlot(idx, "", true, Ext.UI.HandleToDouble(item.Handle), 2, item.Amount or 0)
                else
                    h.clearSlotMC(slot)
                end
            else
                h.clearSlotMC(slot)
            end
        end
    end
end

function M.Render()
    local u = ui(); if not u then return end
    local root = u:GetRoot()
    if not root.hotbar_mc or not root.hotbar_mc.slotholder_mc then return end
    ensureSlots(root)
    local char = Ext.Entity.GetCharacter(u:GetPlayerHandle())
    if not char then return end
    local cur = currentBar(root)
    local row = 1
    for bar = 1, BARS do
        if bar ~= cur and row < M.rows then
            renderRow(root, char, row, bar)
            row = row + 1
        end
    end
    M.ready = true
end

local function safeRender()
    local ok, err = pcall(M.Render)
    if not ok then Ext.Utils.PrintError("[uissoca] HotbarRows: " .. tostring(err)) end
end

function M.SetRows(n)
    n = math.max(1, math.min(BARS, math.floor(tonumber(n) or BARS)))
    M.rows = n
    safeRender()
    Ext.Utils.Print("[uissoca] hotbar rows: " .. n)
end

-- Re-render whenever the engine pushes slot changes to the bar (bar cycled, skill learned, item used...).
Ext.RegisterUITypeInvokeListener(HOTBAR, "updateSlots", function() safeRender() end)
Ext.RegisterUITypeInvokeListener(HOTBAR, "setCurrentHotbar", function() safeRender() end)

Ext.Events.SessionLoaded:Subscribe(safeRender)
Ext.RegisterConsoleCommand("hotbarrows", function(_, n) M.SetRows(n) end)

pcall(function() if Ext.Client.GetGameState() == "Running" then safeRender() end end)
return M
