-- A real four-person building site paused halfway through construction.
V.atFrame(8,function()
    local Game=require "network.Standalone"
    Game.UseStore(require("game.SaveStore").new({now=function() return 1000 end,
        read=function() return nil end,write=function() return true end}),true)
    local sim,_,hud=Game.Inspect()
    hud.dismissIntro()
    sim,_,hud=Game.Inspect()
    hud.dismissIntro()
    sim.skipped=true
    V.assert(sim:build("house",8,8),"House construction begins")
    local site=sim:buildingAt(8,8)
    for _=1,200 do
        sim:update(0.1)
        if site.progress>=0.57 then break end
    end
    local hammering=0
    for _,a in ipairs(sim.builders) do if a.phase=="hammer" then hammering=hammering+1 end end
    V.assert(not site.complete and site.progress>=0.5 and site.progress<0.7 and hammering>=2,
        "Mid-stage house shows walls and multiple hammering villagers")
    sim.paused=true
    hud.update()
end)
V.atFrame(50,function() V.finish() end)
