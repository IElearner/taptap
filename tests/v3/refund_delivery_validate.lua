-- Controlled cancelled-order fixture, with actual courier pickup and return.
local Sim=require 'game.Simulation'
local E=require 'game.Economy'
local s,b,ticks
V.atFrame(8,function()
 s=Sim.new('finite',23);s.started=true;s.skipped=true;s.lesson=8
 s.roads['13:9']=true;s.roads['14:9']=true;s.roadCount=2
 b=s:addBuilding('woodweapons',14,8,true);b.workers=0
 s:setRecipe(b,1)
 -- These two inputs were previously paid from the original warehouse.
 s.stock.wood=s.stock.wood-2;b.inputGoods.wood=2;b.inputs=2
 V.assert(s:setRecipe(b,0),'Cancelling a cold woodcraft order creates real return cargo')
 V.assert(E.outputAmount(b,'wood')==2 and b.inputs==0,'Unused paid wood is on the actual output shelf')
 V.assert((s.produced.wood or 0)==0 and not s:nextLesson(),'Unfinished sawmill goal cannot complete before the refund trip')
 ticks=0
end)
for frame=9,45 do V.atFrame(frame,function()
 if not s then return end
 for _=1,100 do s:update(.1);ticks=ticks+1 end
end)end
V.atFrame(46,function()
 V.assert(s.stock.wood==72 and b.buffer==0,'Real courier returns exactly the originally paid two wood to stock')
 V.assert((s.produced.wood or 0)==0,'Returned unused wood is not newly produced sawmill output')
 V.assert(not s:nextLesson() and s.lesson==8,'Cancelling another workshop cannot bypass the actual sawmill tutorial objective')
 print('REFUND_DIAGNOSTIC',cjson.encode({stock=s.stock.wood,produced=s.produced.wood,lesson=s.lesson,buffer=b.buffer}))
 V.finish()
end)
