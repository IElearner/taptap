local Sim=require 'game.Simulation'
local Actors=require 'game.PixelActors'
local A=require 'game.PixelAssets'
local function find(list,key) for _,p in ipairs(list) do if p.key==key then return p end end end
V.atFrame(8,function()
    A.loadCatalog()
    local s=Sim.new('finite')
    local farm=s:addBuilding('farm',8,12,true);farm.workers=1
    local camp=s:addBuilding('woodcutter',6,4,true);camp.workers=1
    local hall=s:addBuilding('kitchen',8,8,true)
    local farmer={building=farm.id,slot=1,x=8,y=13,farmPresence=0,workerLook=1}
    local logger={building=camp.id,slot=1,x=6,y=5,woodPhase='chop',workerLook=2}
    s.workers={farmer=farmer,logger=logger}
    local p=find(Actors.collect(s,{}),'workerfarmer')
    V.assert(p and not p.action,'An assigned farmer approaching the field does not already swing a tool')
    farmer.farmPresence=1
    p=find(Actors.collect(s,{}),'workerfarmer')
    V.assert(p.action=='plow','An arrived farmer performs the actual current field task')
    for _,phase in ipairs({'walk','queue','return'}) do
        farmer.meal={phase=phase,target=hall.id};logger.meal={phase=phase,target=hall.id}
        local list=Actors.collect(s,{})
        V.assert(not find(list,'workerfarmer').action and not find(list,'workerlogger').action,
            'Meal '..phase..' clears farming and logging actions')
    end
    farmer.meal={phase='eat',target=hall.id,seat=1,timer=5}
    p=find(Actors.collect(s,{}),'workerfarmer')
    V.assert(p.action=='eat' and p.layerBuilding==hall,'A seated farmer eats in the dining layer, retaining identity')
end)
V.atFrame(25,function() V.finish() end)
