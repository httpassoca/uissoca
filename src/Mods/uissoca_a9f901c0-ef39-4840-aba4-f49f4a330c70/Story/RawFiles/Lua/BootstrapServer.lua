Ext.Utils.Print("[uissoca] server loaded")

-- UI commands live on the client; make the server prompt say so instead of "Unregistered".
Ext.RegisterConsoleCommand("uiscale", function()
    Ext.Utils.Print("[uissoca] uiscale is a client command: type  client  first (prompt becomes C >>), then !uiscale 1.3")
end)
