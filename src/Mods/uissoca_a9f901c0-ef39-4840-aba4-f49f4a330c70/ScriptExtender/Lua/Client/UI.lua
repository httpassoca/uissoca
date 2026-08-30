-- Hello-world: proves the Lua → Flash pipeline works.
-- Verify function names against the SE docs for your installed version.
local SCALE = 1.0  -- TODO: make configurable

Ext.Events.SessionLoaded:Subscribe(function()
    local ok, err = pcall(function()
        local hotbar = Ext.UI.GetByName("hotBar")
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
