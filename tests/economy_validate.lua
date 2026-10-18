local Sim=require "game.Simulation"
local Meals=require "game.Meals"
local Data=require "game.SaveData"
local function advance(s,seconds)
    for _=1,seconds*10 do s:update(0.1) end
end
V.atFrame(8,function()
    local s=Sim.new();s.started,s.skipped=true,true;s.stock.food=200
    local ok,message=s:build("road",7,9);V.assert(ok,"Road connects the new canteen: " .. tostring(message))
    ok,message=s:build("kitchen",8,8);V.assert(ok,"Canteen foundation can be placed: " .. tostring(message))
    ok,message=s:build("road",6,9);V.assert(ok,"Road reaches meat processing")
    ok,message=s:build("butcher",6,8);V.assert(ok,"Butcher shop foundation can be placed: " .. tostring(message))
    ok,message=s:build("ranch",12,8);V.assert(ok,"Two-tile ranch can be placed: " .. tostring(message))
    advance(s,130)
    V.assert(s:count("ranch")==1 and s:count("butcher")==1 and s:count("kitchen")==1,"Workers complete the new food chain")
    V.assert((s.produced.livestock or 0)>0 and (s.produced.meat or 0)>0,"Ranch livestock is delivered and butchered into meat")
    V.assert(s.produced.food>0,"Canteen cooks meat into rations without requiring a mill")
    local hall=s:buildingAt(8,8)
    V.assert(hall.mealStock>=0 and hall.mealStock<=Meals.pantryCapacity,"Dining pantry has a strict capacity")
    local save=Data.capture(s,1000,1,true)
    local restored=Data.restore(cjson.decode(cjson.encode(save)),"finite")
    V.assert(restored and restored.stock.meat==s.stock.meat and restored.stock.livestock==s.stock.livestock,"Meat and livestock survive save/load")
    s.carriers[2].energy=37
    local energySave=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,2,true))),"finite")
    V.assert(energySave and energySave.carriers[2].energy==37,"Individual stamina survives save/load")
    local old=cjson.decode(cjson.encode(save));old.world.stock.meat=nil;old.world.stock.livestock=nil;old.world.guards=nil
    V.assert(Data.restore(old,"finite")~=nil,"Existing saves load with empty new resource slots")
    local c=s.carriers[1]
    c.job={b=hall,inbound=true,resource="food",amount=1}
    c.x,c.y,c.path,c.index,c.meal,c.hunger,c.energy=11,9,{{x=10,y=9}},1,false,0,100
    s:updateCarrier(c,0.1,true)
    V.assert(c.facing=="nw","A carrier faces west on the return walk instead of walking backwards")
    local tired=Sim.new();tired.started,tired.skipped=true,true
    local diner=tired:addBuilding("kitchen",8,8,true);diner.mealStock=2
    local visitor=tired.carriers[1];visitor.energy=20;visitor.hunger=0
    advance(tired,12)
    V.assert(visitor.energy>90 and visitor.hunger<30 and tired.mealsServed>0,"Low stamina sends a villager to eat and recover at the canteen")
end)
V.atFrame(25,function() V.finish() end)
V.atFrame(9,function()
    local wood=Sim.new();wood.started,wood.skipped=true,true;wood.stock.food=200
    local camp=wood:addBuilding("woodcutter",8,8,true);camp.workers=1
    local first=wood:nearestTree(camp,6)
    V.assert(first~=nil and wood:standingTree(first.x,first.y),"Woodcutters require a standing nearby tree")
    advance(wood,4)
    local inProgress=Data.restore(cjson.decode(cjson.encode(Data.capture(wood,1000,1,true))),"finite")
    V.assert(inProgress and inProgress.workers[camp.id .. ":1"].woodPhase,"Woodcutting trip survives save/load")
    advance(wood,38)
    local felled=0;for _ in pairs(wood.felledTrees) do felled=felled+1 end
    V.assert(felled>0 and wood.timber<320 and wood.stock.wood>72,"A visible tree is felled before its log reaches the store")
    local restored=Data.restore(cjson.decode(cjson.encode(Data.capture(wood,1001,2,true))),"finite")
    V.assert(restored and not restored:standingTree(first.x,first.y),"Felled trees remain gone after loading")

    local supply=Sim.new();supply.started,supply.skipped=true,true;supply.stock.food=200
    local field=supply:addBuilding("farm",8,8,true)
    local mill=supply:addBuilding("mill",12,8,true)
    field.buffer=3
    supply:update(0.1)
    V.assert(supply.carriers[1].job and supply.carriers[1].job.destination==mill,"Grain is assigned directly to the mill")
    local carrying=Data.restore(cjson.decode(cjson.encode(Data.capture(supply,1000,1,true))),"finite")
    V.assert(carrying and carrying.carriers[1].job.destination==carrying.buildings[mill.id],"A direct delivery keeps its destination in the save")
    advance(supply,15)
    V.assert(mill.inputs==3 and supply.stock.grain==0,"Carrier delivers grain to the mill before the store")
    mill.inputs=4;field.buffer=3;supply:update(0.1)
    advance(supply,15)
    V.assert(supply.stock.grain==3,"Full mill sends surplus harvest to the store")
end)
