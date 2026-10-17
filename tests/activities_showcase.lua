-- Deterministic visual fixture. It does not read or write a player's save.
V.atFrame(8,function()
    local Game=require "network.Standalone"
    Game.UseStore(require("game.SaveStore").new({now=function() return 1000 end,
        read=function() return nil end,write=function() return true end}),true)
    local sim,_,hud=Game.Inspect()
    hud.dismissIntro()
    sim,_,hud=Game.Inspect()
    hud.dismissIntro()
    sim.skipped=true
    sim:build("kitchen",8,8)
    for _=1,200 do sim:update(0.1) end
    local kitchen=sim:buildingAt(8,8)
    if kitchen and kitchen.complete then sim:staff(kitchen,-kitchen.workers) end
    sim.stock.food=16
    for _,carrier in ipairs(sim.carriers) do carrier.hunger=90 end
    sim:build("road",7,9)
    sim:build("road",6,9)
    for _=1,55 do
        sim:update(0.1)
        if sim.builders[1] and sim.builders[1].phase=="hammer" then break end
    end
    hud.update()
end)
