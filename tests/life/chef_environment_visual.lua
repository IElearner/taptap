-- Controlled buildings/materials, autonomous actual worker movement/production.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local Sim=require 'game.Simulation';local Game=require 'network.Standalone';local Store=require 'game.PixelSaveStore'
local Actors=require 'game.PixelActors';local A=require 'game.PixelAssets';local E=H.E
local actualCollect=Actors.collect;local isolateMachine=false
Actors.collect=function(...)if isolateMachine then return {} end;return actualCollect(...)end
local run='life-environment';for _,v in ipairs(GetArguments())do run=v:match('^-pixelqa%-run=([%w_-]+)$')or run end
local s,view,hud,b,pending,history;local records,trace,seen={}, {}, {};local held=0;local mode,step=0,0
local function shot(label,p)
 pending={delay=3,path='tests/life/evidence/visual/'..run..'-'..label..'.png',label=label,time=s.elapsed,kind=b.kind,building=b.id,timer=b.timer,visualWorkSeconds=b.visualWorkSeconds,inputs=b.inputGoods,output=b.outputGoods,workRate=b.workRate,stopped=b.stopped,actor=s.workers[b.id..':1'],sprite=p and A.actorSprite(p,s.elapsed),projection=p and{x=p.x,y=p.y,action=p.action}}
 local bx,by=view.worldToScreen(b.x,b.y);local camera=view.cameraState();local spec=A.buildings[b.kind]
 pending.renderIsolation=isolateMachine and 'Actor drawing omitted to isolate machine ROI; actual production actors unchanged'or false;pending.camera=camera;pending.buildingScreen={x=bx,y=by};pending.spriteSpec=spec
 if b.site and b.site.workCell then local wx,wy=view.worldToScreen(b.site.workCell.x,b.site.workCell.y);pending.workScreen={x=wx,y=wy}end
 pending=cjson.decode(cjson.encode(pending));held=4
end
function CaptureLifeEnvironment()
 if not pending then return end;pending.delay=pending.delay-1;if pending.delay>0 then return end
 local im=Image();if graphics:TakeScreenShot(im)then im:SavePNG(pending.path);records[#records+1]=pending end;pending=nil
end
local function setup(kind)
 isolateMachine=kind~='kitchen' -- declared projection-only isolation; actual workers still update
 local z=Sim.new('finite',23);z.started,z.skipped=true,true;z.stock.wood,z.stock.stone,z.stock.food=1000,1000,500
 local target=H.add(z,kind);assert(z:staff(target,1))
 if kind~='kitchen'then local hall=H.add(z,'kitchen');hall.mealStock=8;hall.inputGoods.bread=4;hall.inputs=4 end
 if kind=='mill'then target.inputGoods.grain=2;target.inputs=2
 elseif kind=='bakery'then target.inputGoods.flour=1;target.inputs=1
 elseif kind=='sawmill'then target.inputGoods.rawwood=1;target.inputs=1
 elseif kind=='smelter'then assert(z:setRecipe(target,1));target.inputGoods.ironore=1;target.inputGoods.coal=1;target.inputs=2
 else target.mealStock=8 end
 local files={};local store=Store.new({now=function()return 1000 end,read=function(k)return files[k]end,write=function(k,v)files[k]=v;return true end});assert(store:save(z,true))
 Game.UseStore(store);s,view,hud=Game.Inspect();hud.dismissIntro();s.paused=true;b=s.buildings[target.id];history={};seen={};step=0
 view.zoom(-100);view.zoom(1);view.focus(b.x,b.y-.4);hud.update()
end
local kinds={'kitchen','mill','bakery','sawmill','smelter'}
local onlyKind=run:match('only%-([%w]+)')
if onlyKind then kinds={onlyKind}end
local function finishEnvironment()
 Actors.collect=actualCollect
 V.assert(mode>#kinds,'Chef and all four machine scenes complete')
 local f=File('tests/life/evidence/visual/'..run..'-states.json',FILE_WRITE);f:WriteString(cjson.encode({records=records,trace=trace,controlledMaterials=true}));f:Close();V.finish()
end

V.atFrame(6,function()SubscribeToEvent('EndAllViewsRender','CaptureLifeEnvironment');setup(kinds[1]);mode=1 end)
for frame=7,12000 do V.atFrame(frame,function()
 if mode>#kinds then return end
 if held>0 then held=held-1;return end
 step=step+1;s.paused=false;s:update(.1);s.paused=true;hud.update()
 local a=s.workers[b.id..':1'];local p;for _,q in ipairs(actualCollect(s,history))do if q.key=='worker'..b.id..':1'then p=q;break end end
 if b.kind=='kitchen' then
  if step==450 then s.stock.bread=4;print('LIFE_CHEF_DECLARED_INPUT',s.elapsed,'warehouse bread4')end
  local phase=a and a.meal and 'meal-'..a.meal.phase or a and a.lean and 'lean-'..a.lean.phase or p and p.action or 'ordinary'
  trace[#trace+1]={time=s.elapsed,phase=phase,timer=b.timer,inputs=b.inputs,food=s.produced.food,x=a and a.x,y=a and a.y,workRate=b.workRate}
  if not seen[phase]then seen[phase]=true;shot('chef-'..phase,p)end
  if phase=='cook' and not pending then
   local n=seen.cookSamples or 0
   if n<4 and (not seen.lastCookShot or s.elapsed-seen.lastCookShot>=.7)then seen.cookSamples=n+1;seen.lastCookShot=s.elapsed;shot('chef-cooking-smoke-'..(n+1),p)end
  end
  if step==1400 then
   V.assert(seen['lean-walk']and seen['lean-lean']and seen['lean-return'],'Real idle cook walks to wall, leans and walks back when real delivered input arrives')
   V.assert((s.produced.food or 0)>0 and seen.cook,'Returned cook actually produces food from supplied bread')
   V.assert(seen['meal-eat'],'Same cook actually requests and eats a meal')
   mode=mode+1;setup(kinds[mode])
  end
 else
  if (b.workRate or 0)>0 and a and a.breaks and a.breaks.phase=='work' then
   if not seen.firstWork then seen.firstWork=s.elapsed end
   local n=seen.workShots or 0
   if n<4 and(not seen.lastWork or s.elapsed-seen.lastWork>=(onlyKind and .37 or .7))then seen.workShots=n+1;seen.lastWork=s.elapsed;shot(b.kind..'-work-'..(n+1),p)end
  end
  if seen.workShots==4 and not seen.stopAt and s.elapsed-(seen.lastWork or 0)>1 then
   assert(s:setWorking(b,false));seen.stopAt=s.elapsed;shot(b.kind..'-stop-start',p)
  end
  if seen.stopAt then
   local n=seen.stopShots or 0
   if n<2 and s.elapsed-seen.stopAt>=5+n*3 then seen.stopShots=n+1;shot(b.kind..'-stopped-'..(n+1),p)end
  end
  if seen.stopShots==2 and s.elapsed-seen.stopAt>=9 and not seen.resumeAt then
   assert(s:setWorking(b,true));seen.resumeAt=s.elapsed
  end
  if seen.resumeAt and b.visualFinishAt and not E.hasInputs(b)and (b.workRate or 0)==0 and s.elapsed-b.visualFinishAt>=4 then
   local n=seen.missingShots or 0
   if n<2 and(not seen.lastMissing or s.elapsed-seen.lastMissing>=.7)then seen.missingShots=n+1;seen.lastMissing=s.elapsed;shot(b.kind..'-missing-'..(n+1),p)end
  end
  if seen.missingShots==2 and s.elapsed-seen.lastMissing>=.5 then
   V.assert((b.visualWorkSeconds or 0)>0 and seen.workShots==4 and seen.stopShots==2,'Real work grows, normal stop cools, resumed real batch exhausts inputs for '..b.kind)
   mode=mode+1;if mode<=#kinds then setup(kinds[mode])else finishEnvironment()end
  elseif step>=2500 then V.assert(false,'Actual work/stop/exhaustion not reached for '..b.kind);V.finish();mode=#kinds+1 end
 end
end)end

V.atFrame(12005,finishEnvironment)
