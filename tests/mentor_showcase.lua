-- Screenshot fixture for the opening conversation; no player files are touched.
V.atFrame(6,function()
    local Game=require "network.Standalone"
    Game.UseStore(require("game.SaveStore").new({now=function() return 1000 end,
        read=function() return nil end,write=function() return true end}),true)
    local _,_,hud=Game.Inspect()
    hud.root:FindById("loginGuest").props.onClick()
    local _,_,active=Game.Inspect()
    active.root:FindById("enterVillage").props.onClick()
    active.update()
end)
