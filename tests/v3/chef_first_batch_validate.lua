-- Controlled two-hall food state isolates the working cook's meal decision.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local Move=require 'game.Movement'
local Meals=require 'game.Meals'
local E=require 'game.Economy'
local function setup()
 local s=Sim.new('finite',23);s.started=true;s.skipped=true;s.stock.food=0
 for x=7,13 do s.roads[x..':9']=true end;s.roadCount=6
 local far=s:addBuilding('kitchen',7,8,true);far.mealStock=8;far.workers=0
 local own=s:addBuilding('kitchen',13,8,true);own.workers=1;s:update(.1)
 local chef=s.workers[own.id..':1'];chef.hunger=100;chef.energy=100
 return s,own,far,chef
end
V.atFrame(8,function()
 local s=Sim.new('finite',23);s.started=true;s.skipped=true;s.stock.food=0
 for x=7,13 do s.roads[x..':9']=true end;s.roadCount=6
 local far=s:addBuilding('kitchen',7,8,true);far.mealStock=8;far.workers=0
 local own=s:addBuilding('kitchen',13,8,true);own.workers=1
 s:update(.1)
 own.inputs=1;own.inputGoods={bread=1}
 local chef=s.workers[own.id..':1'];chef.hunger=100;chef.energy=100
 local firstTarget
 for _=1,100 do s:update(.1);if chef.meal then firstTarget=firstTarget or chef.meal.target end end
 print('V3_CHEF_READY_BATCH',cjson.encode({input=own.inputs,pantry=own.mealStock,firstTarget=firstTarget,own=own.id,far=far.id,produced=s.produced.food,chef=chef}))
 V.assert(s.produced.food>=4 and own.inputs==0,'A hungry cook with a ready local ingredient completes one ordinary six-second batch before abandoning the empty kitchen for distant food')
 V.assert(firstTarget~=far.id,'The newly cooked own-hall meal avoids an unnecessary distant meal journey')
 for _,kind in ipairs({'no-input','stopped','disconnected'})do
  s,own,far,chef=setup();own.inputs=1;own.inputGoods={bread=1}
  if kind=='no-input'then own.inputs=0;own.inputGoods={}elseif kind=='stopped'then s:setWorking(own,false)
  else s.roads['13:9']=nil;s.roadCount=s.roadCount+1;chef.x,chef.y=12,9 end
  s:update(.1)
  V.assert(chef.meal and chef.meal.target==far.id,'Invalid local cooking eligibility immediately allows ordinary dining: '..kind)
 end
 s,own,far,chef=setup();own.mealStock=1
 s:update(.1)
 V.assert(chef.meal and chef.meal.target==own.id,'An assigned hungry chef chooses its own existing meal before a distant stocked hall')
 s,own,far,chef=setup();own.inputs=1;own.inputGoods={bread=1}
 for _=1,10 do s:update(.1)end
 local worked=not chef.meal and own.timer>0
 own.inputs=0;own.inputGoods={};s:update(.1)
 V.assert(worked and chef.meal and chef.meal.target==far.id,'A cook holding its ready stove immediately resumes normal dining when its actual ingredient disappears')
 s,own,far,chef=setup();own.inputs=1;own.inputGoods={bread=1};E.add(own,'food',6);own.outgoing=true
 s.jobs={{b=own,inbound=false,resource='food',amount=6}}
 s:update(.1)
 V.assert(chef.meal and chef.meal.target==far.id and own.timer==0,'A completely reserved full output shelf prevents guarding an unproducible batch and allows normal dining')
 s,own,far,chef=setup();own.inputs=2;own.inputGoods={bread=2}
 local stolen=false;local external=false
 for _=1,240 do
  s:update(.1)
  if chef.meal and chef.meal.target==far.id then external=true end
  if not stolen and own.mealStock==4 then
   local guests={s.carriers[1],s.carriers[2],s.carriers[3],s.builders[1]}
   for _,guest in ipairs(guests)do
    guest.x,guest.y=own.x,own.y+1
    guest.meal={target=own.id,phase='queue',timer=0,paid=false,resumeX=10,resumeY=9}
    Meals.tick(s,guest,.1,false,false)
   end
   stolen=own.mealStock==0 and s.mealsServed==4
  end
 end
 V.assert(stolen and s.produced.food==8 and own.inputs==0 and not external,'After four real diners consume its first batch, the still-ready chef cooks the next real batch without abandoning the stove')
 s,own,far,chef=setup();own.inputs=1;own.inputGoods={bread=1};chef.x,chef.y=10,9
 chef.meal={target=far.id,phase='walk',paid=false,timer=0,resumeX=13,resumeY=9};Move.route(s,chef,7,9)
 local maxStep,previousX,previousY=0,chef.x,chef.y
 local delivered=false
 for step=1,500 do
  s:update(.1);maxStep=math.max(maxStep,math.sqrt((chef.x-previousX)^2+(chef.y-previousY)^2));previousX,previousY=chef.x,chef.y
  if step==5 then
   local loaded=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite');s=loaded;own=s.buildings[own.id];far=s.buildings[far.id];chef=s.workers[own.id..':1']
  end
  delivered=delivered or s.produced.food>=4
 end
 V.assert(delivered and own.inputs==0,'Unpaid externally walking chef returns through the actual road to complete its ready local batch, including mid-return save/load')
 V.assert(maxStep<.5,'Returning chef keeps continuous real movement without teleporting to the kitchen')
 -- Local preference is evaluated when selecting/reselecting a destination.
 -- A still-valid unpaid journey to another stocked hall is not preempted
 -- merely because its own counter receives a meal mid-journey.
 s,own,far,chef=setup();chef.x,chef.y=10,9;own.mealStock=1
 chef.meal={target=far.id,phase='walk',paid=false,timer=0,resumeX=13,resumeY=9};Move.route(s,chef,7,9)
 s:update(.1)
 V.assert(chef.meal.target==far.id and chef.meal.phase=='walk' and own.mealStock==1,'An existing unpaid journey to a still-stocked hall remains valid when local food appears; local preference does not teleport or preempt it')
 s,own,far,chef=setup();own.inputs=1;own.inputGoods={bread=1};chef.x,chef.y=7,9
 chef.meal={target=far.id,phase='enter',paid=true,seat=1,timer=2.8,resumeX=13,resumeY=9};far.mealStock=7;s.mealsServed=1
 local kept=true
 for _=1,150 do s:update(.1);if chef.meal and chef.meal.target~=far.id then kept=false end end
 V.assert(kept and s.mealsServed==1 and far.mealStock==7,'Already paid external meal is completed at its original hall without interruption or double charging')
 V.finish()
end)
