-- Built-in panels are fetched by type id (Ext.UI.GetByType); GetByName only sees mod-created UIs.
-- Full id list: SE Docs/API.md "Built-in UI types".
local UITYPE = { hotBar = 40, characterSheet = 119, partyInventory = 116, statusConsole = 117, playerInfo = 118 }

local state = { scale = 1.0, base = nil }   -- base = original hotbar geometry, captured once

local function getUI(name)
    return Ext.UI.GetByType(UITYPE[name]) or Ext.UI.GetByPath("Public/Game/GUI/" .. name .. ".swf")
end

local function geom(root)
    return string.format("x=%.1f y=%.1f w=%.1f h=%.1f scale=%.2f", root.x, root.y, root.width, root.height, root.scaleX)
end

-- Scale hotbar_mc (the bar itself; the root is the full-screen stage) around its bottom-centre.
local function applyHotbarScale(s)
    local ui = getUI("hotBar")
    if not ui then Ext.Utils.Print("[uissoca] hotBar UI not found"); return end
    local root = ui:GetRoot()
    local bar = root.hotbar_mc
    if not bar then Ext.Utils.Print("[uissoca] root.hotbar_mc not found"); return end
    if not state.base then
        state.base = { x = bar.x, y = bar.y, w = bar.width, h = bar.height }
        Ext.Utils.Print("[uissoca] hotbar base: " .. geom(bar))
    end
    local b = state.base
    bar.scaleX, bar.scaleY = s, s
    bar.x = b.x - (b.w * (s - 1)) / 2     -- keep horizontal centre
    bar.y = b.y - (b.h * (s - 1))         -- keep bottom edge
    state.scale = s
    Ext.Utils.Print("[uissoca] hotbar now: " .. geom(bar))
end

local function apply()
    local ok, err = pcall(applyHotbarScale, state.scale)
    if not ok then Ext.Utils.PrintError("[uissoca] " .. tostring(err)) end
end

Ext.Events.SessionLoaded:Subscribe(apply)

-- Console: `!uiscale 1.3`  (also `!uiscale` to print current geometry)
Ext.RegisterConsoleCommand("uiscale", function(_, val)
    local s = tonumber(val)
    if s then state.scale = s end
    apply()
end)

-- After `!reset` SessionLoaded doesn't re-fire; re-apply on the next tick if we're already in-game.
pcall(function()
    if Ext.Client.GetGameState() == "Running" then apply() end
end)
