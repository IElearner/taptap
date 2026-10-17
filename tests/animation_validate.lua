-- Verify that the renderer requests actual action frames while a real road crew works.
dofile("tests/activities_showcase.lua")
local Art=require "game.Art"
local original=Art.draw
local seen={}
V.atFrame(9,function()
    local sim=require("network.Standalone").Inspect()
    local working=false
    for _,builder in ipairs(sim.builders) do if builder.phase=="hammer" then working=true end end
    V.assert(working,"The road crew reaches a real construction site")
    local carrier=sim.carriers[1]
    carrier.x,carrier.y,carrier.index=10,9,1
    carrier.path={{x=11,y=9},{x=12,y=9}}
    carrier.job={resource="wood",amount=1,b=sim.buildings[1]}
    carrier.carrying,carrier.hunger,carrier.meal=false,0,nil
    Art.draw=function(vg,name,...)
        if name:find("%-hammer%-up$") then seen.up=true end
        if name:find("%-hammer%-down$") then seen.down=true end
        if name:find("%-stride$") then seen.walk=true end
        return original(vg,name,...)
    end
end)
V.atFrame(65,function()
    Art.draw=original
    V.assert(seen.up and seen.down,"A builder visibly alternates raised and striking hammer sprites")
    V.assert(seen.walk,"A moving villager renders its walking stride sprite")
    V.finish()
end)
