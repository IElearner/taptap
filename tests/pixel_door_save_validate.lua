local Sim=require 'game.Simulation'
local Store=require 'game.PixelSaveStore'
local Data=require 'game.SaveData'
local Cargo=require 'game.Cargo'
V.atFrame(8,function()
    local s=Sim.new('finite')
    local hall=s:addBuilding('kitchen',8,8,true)
    hall.mealStock,hall.mealIncoming=0,true
    s.stock.food=s.stock.food-2
    local a=s.carriers[1]
    a.x,a.y,a.path,a.index,a.phase,a.carrying=8,9,{},1,'travel',true
    a.job={b=hall,inbound=true,service=true,resource='food',amount=2}
    s:updateCarrier(a,.05,false)
    V.assert(a.phase=='unload' and a.doorDuration==6.5 and a.timer==6.5,'New kitchen deliveries use a physically sufficient courtyard excursion')
    s:updateCarrier(a,2,false)
    V.assert(hall.mealStock==0 and a.carrying,'Food is not handed off before the longer excursion midpoint')
    local files={}
    local backend={now=function() return 1000 end,read=function(k) return files[k] end,write=function(k,v) files[k]=v;return true end}
    local writer=Store.new(backend);V.assert(writer:save(s,true),'An in-progress long excursion saves through the actual pixel store')
    local restored
    Store.new(backend):load('finite',function(value) restored=Data.restore(value,'finite') end)
    V.assert(restored and restored.carriers[1].doorDuration==6.5 and restored.carriers[1].timer==4.5,'JSON restore preserves duration and remaining time without restarting the trip')
    if not restored then return end
    local c=restored.carriers[1];local pantry=restored.buildings[hall.id]
    restored:updateCarrier(c,1.3,false)
    V.assert(pantry.mealStock==2 and c.handedOff and not c.carrying,'The restored delivery transfers exactly at its own midpoint')
    restored:updateCarrier(c,.1,false)
    V.assert(pantry.mealStock==2 and restored.stock.food+pantry.mealStock==28,'Continuing unload cannot duplicate reserved food')
    local legacy=cjson.decode(files['shanheli_pixel_v1_finite.json'])
    legacy.world.carriers[1].doorDuration=nil;legacy.world.carriers[1].timer=1.5
    local old=Data.restore(legacy,'finite')
    V.assert(old and old.carriers[1].doorDuration==nil,'A pre-duration in-flight save keeps its original two-second excursion')
    if old then old:updateCarrier(old.carriers[1],.6,false);V.assert(old.buildings[hall.id].mealStock==2,'The legacy midpoint still transfers once when resumed') end
    local invalid=cjson.decode(files['shanheli_pixel_v1_finite.json']);invalid.world.carriers[1].doorDuration=100
    V.assert(not Data.restore(invalid,'finite'),'Unbounded excursion durations are rejected')
    local producer=s:addBuilding('butcher',5,11,true)
    V.assert(Cargo.phaseBuilding(s,{job={b=producer,destination=hall,inbound=false}},'unload')==hall,'Direct producer deliveries enter their true destination rather than teleport to the warehouse')
end)
V.atFrame(25,function() V.finish() end)
