-- Focused actual Meals state-machine boundaries; pantry stocks and hunger are
-- explicit fixtures. No production, routing function or meal API is mocked.
local Sim=require 'game.Simulation'
local Meals=require 'game.Meals'
local Data=require 'game.SaveData'
local function setup()
 local s=Sim.new('finite',23);s.started=true;s.skipped=true;s.stock.food=0
 for x=7,16 do s.roads[x..':9']=true end;s.roadCount=5
 local near=s:addBuilding('kitchen',7,8,true);local far=s:addBuilding('kitchen',13,8,true);far.mealStock=8
 local b=s:addBuilding('woodweapons',16,8,true);b.workers=1;s:update(.1)
 local a=s.workers[b.id..':1'];a.x,a.y,a.hunger=7,9,100
 return s,near,far,b,a
end
V.atFrame(8,function()
 local s,n,f,b,a=setup()
 for _=1,1500 do Meals.tick(s,a,.1,false,false)end
 V.assert(s.mealsServed>0 and f.mealStock<8,'New hungry worker can reach and consume farther stocked food instead of choosing a nearer empty hall')
 s,n,f,b,a=setup();a.meal={target=n.id,phase='queue',timer=0,waitTime=0,paid=false,resumeX=16,resumeY=9}
 local switched,resumePreserved=false,true
 for _=1,1500 do
  Meals.tick(s,a,.1,false,false)
  if a.meal and a.meal.target==f.id then switched=true;resumePreserved=resumePreserved and a.meal.resumeX==16 and a.meal.resumeY==9 end
 end
 V.assert(switched and s.mealsServed>0,'An unpaid worker stranded in an empty hall can reroute to an actually stocked hall and eat')
 V.assert(switched and resumePreserved,'Unpaid rerouting preserves the original real workplace return coordinates')
 s,n,f,b,a=setup();n.mealStock=1;a.meal={target=n.id,phase='queue',timer=0,waitTime=0,paid=false,resumeX=16,resumeY=9}
 Meals.tick(s,a,.1,false,false)
 V.assert(a.meal and a.meal.paid and a.meal.phase=='enter' and n.mealStock==0,'Actual queue acceptance charges one near-hall meal exactly once')
 local restored,why=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite')
 V.assert(restored~=nil,'Paid entering meal restores with its original hall: '..tostring(why))
 if restored then s=restored;n=s.buildings[n.id];f=s.buildings[f.id];a=s.workers[b.id..':1']end
 local kept=true
 for _=1,200 do Meals.tick(s,a,.1,false,false);if a.meal and a.meal.target~=n.id then kept=false end end
 V.assert(kept and s.mealsServed==1 and n.mealStock==0 and f.mealStock==8,'Paid enter/eat/exit never switches halls or pays twice, including reload')
 V.finish()
end)
