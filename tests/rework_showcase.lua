-- Stable visual comparison for the reference-inspired top-down village.
V.atFrame(8,function()
    local Game=require "network.Standalone"
    Game.UseStore(require("game.SaveStore").new({now=function() return 1000 end,
        read=function() return nil end,write=function() return true end}),true)
    local sim,_,hud=Game.Inspect()
    hud.dismissIntro()
    sim,_,hud=Game.Inspect()
    hud.dismissIntro()
    sim.skipped=true
    for x=7,4,-1 do V.assert(sim:build("road",x,9),"Left path connects") end
    for x=13,17 do V.assert(sim:build("road",x,9),"Right path connects") end
    for _,entry in ipairs({{"house",7},{"farm",5},{"mill",8},{"kitchen",12},{"woodcutter",14},{"barracks",15},{"house",17}}) do
        V.assert(sim:build(entry[1],entry[2],8),"Village building placed")
    end
    for _=1,900 do sim:update(0.1) end
    sim.paused=true
    hud.update()
end)
V.atFrame(50,function() V.finish() end)
