-- Hello-world: proves the Lua → Flash pipeline works.
-- Built-in panels are fetched by type id (Ext.UI.GetByType); GetByName only sees mod-created UIs.
-- Full id list: SE Docs/API.md "Built-in UI types". Path fallback: Ext.UI.GetByPath("Public/Game/GUI/<name>.swf").
local UITYPE = {
    hotBar = 40,
    characterSheet = 119,
    partyInventory = 116,
    statusConsole = 117,
    playerInfo = 118,
}
local SCALE = 1.0  -- TODO: make configurable

local function getUI(name)
    return Ext.UI.GetByType(UITYPE[name]) or Ext.UI.GetByPath("Public/Game/GUI/" .. name .. ".swf")
end

Ext.Events.SessionLoaded:Subscribe(function()
    local ok, err = pcall(function()
        local hotbar = getUI("hotBar")
        if hotbar then
            local root = hotbar:GetRoot()
            root.scaleX, root.scaleY = SCALE, SCALE
            Ext.Utils.Print("[uissoca] hotbar scaled to " .. SCALE)
        else
            Ext.Utils.Print("[uissoca] hotBar UI not found")
        end
    end)
    if not ok then Ext.Utils.PrintError("[uissoca] " .. tostring(err)) end
end)
