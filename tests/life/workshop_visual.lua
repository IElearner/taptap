-- One selected workshop per run (run name contains workshop-<kind>). Real
-- autonomous worker phases with declared controlled two-batch input supply.
local hf=File('tests/life/support.lua',FILE_READ);local H=assert(load(hf:ReadString(),'@tests/life/support.lua'))();hf:Close()
local Sim=require 'game.Simulation';local Game=require 'network.Standalone';local Store=require 'game.PixelSaveStore';local Actors=require 'game.PixelActors';local A=require 'game.PixelAssets'
local run='life-workshop-mill';for _,v in ipairs(GetArguments())do run=v:match('^-pixelqa%-run=([%w_-]+)$')or run end
local kind=assert(run:match('workshop%-([%w]+)'),'run name must identify workshop-kind')
local initialLook=tonumber(run:match('look([12])'));local appearanceSet=false
local s,b,id,view,hud,pending;local records,trace,history,counts,last={}, {}, {}, {}, {};local supplied=false;local sawIdle,sawWork,sawFinish,sawEat,sawReturn=false,false,false,false,false
function CaptureWorkshopLife()
 if not pending then return end;pending.delay=pending.delay-1;if pending.delay>0 then return end
 local image=Image();if graphics:TakeScreenShot(image)then image:SavePNG(pending.path);records[#records+1]=pending end;pending=nil
end
local function capture(label,p,a)
 view.focus(p and p.x or b.x,(p and p.y or b.y)-.5)
 local sx,sy=view.worldToScreen(p and p.x or b.x,p and p.y or b.y)
 pending=cjson.decode(cjson.encode({delay=3,path='tests/life/evidence/visual/'..run..'-'..label..'-'..counts[label]..'.png',label=label,time=s.elapsed,actor=a,projection=p and {x=p.x,y=p.y,action=p.action,walking=p.walking,direction=p.direction},actorScreen={x=sx,y=sy},sprite=p and A.actorSprite(p,s.elapsed),building=id,kind=kind,site=b.site,timer=b.timer,workRate=b.workRate,inputGoods=b.inputGoods,outputGoods=b.outputGoods,visualFinishAt=b.visualFinishAt,visualFinishResource=b.visualFinishResource,camera=view.cameraState(),controlled=true}))
end
V.atFrame(6,function()
 local z=Sim.new('finite',23);z.started,z.skipped=true,true;z.stock.wood,z.stock.stone,z.stock.food=1000,1000,500
 local target=H.add(z,kind);id=target.id;local hall=H.add(z,'kitchen');hall.mealStock=8;hall.inputGoods.bread=4;hall.inputs=4
 for _,r in ipairs(H.D.goods)do if r~='food'then z.stock[r]=0 end end
 assert(z:staff(target,1));if H.D.buildings[kind].recipes then assert(z:setRecipe(target,1))end
 local files={};local store=Store.new({now=function()return 1000 end,read=function(k)return files[k]end,write=function(k,v)files[k]=v;return true end})
 assert(store:save(z,true));Game.UseStore(store);s,view,hud=Game.Inspect();hud.dismissIntro();s.paused=true;b=s.buildings[id];view.zoom(-100);view.zoom(1);hud.update();SubscribeToEvent('EndAllViewsRender','CaptureWorkshopLife')
end)
local function finishWorkshop()
 V.assert(sawIdle and supplied,'Actual workshop idle observed before declared material arrival: '..kind)
 V.assert(sawWork and sawFinish,'Actual workshop work and committed typed-product finish observed: '..kind)
 V.assert(sawEat and sawReturn,'Same workshop worker naturally eats and returns: '..kind)
 V.assert(#records>=12,'Held native actual-state frames exist for workshop: '..kind)
 local f=File('tests/life/evidence/visual/'..run..'-states.json',FILE_WRITE);f:WriteString(cjson.encode({records=records,trace=trace,kind=kind,controlled=true}));f:Close();V.finish()
end

for frame=10,5610 do V.atFrame(frame,function()
 if pending or not b then return end
 s.paused=false;s:update(.1);s.paused=true;hud.update()
 local a=s.workers[id..':1'];if not a then return end
 if initialLook and not appearanceSet then a.workerLook=initialLook;appearanceSet=true end -- Appearance-only initial fixture; never phase/load/path.
 local p;for _,v in ipairs(Actors.collect(s,history))do if v.key=='worker'..id..':1'then p=v;break end end
 local finished=a.workLoad and a.breaks and a.breaks.phase=='finish'
 local label=a.meal and'meal-'..a.meal.phase or a.breaks and'break-'..a.breaks.phase or finished and'finish'or p and p.action or'ordinary'
 if a.breaks and a.breaks.phase=='idle'then sawIdle=true end
 if a.breaks and a.breaks.phase=='work'and (b.workRate or 0)>0 and b.timer>0 then sawWork=true end
 if finished then sawFinish=true end
 if a.meal and a.meal.phase=='eat'then sawEat=true elseif sawEat and not a.meal then sawReturn=true end
 trace[#trace+1]={time=s.elapsed,x=a.x,y=a.y,phase=label,timer=b.timer,workRate=b.workRate,inputs=b.inputs,buffer=b.buffer,workLoad=a.workLoad,workOutputHeld=b.workOutputHeld,finishAt=b.visualFinishAt,finishResource=b.visualFinishResource}
 if (counts[label]or 0)<3 and(not last[label]or s.elapsed-last[label]>=.45)then counts[label]=(counts[label]or 0)+1;last[label]=s.elapsed;capture(label,p,a)end
 if not supplied and sawIdle and(counts['break-idle']or 0)>=3 and not pending then
  local recipe=H.E.recipe(b);local inputs=recipe and recipe.inputs or {[H.D.buildings[kind].input]=1}
  for r,n in pairs(inputs)do b.inputGoods[r]=2*n;b.inputs=b.inputs+2*n end
  supplied=true;print('CONTROLLED_TWO_BATCH_INPUT',kind,cjson.encode(inputs))
 end
 if not pending and sawIdle and supplied and sawWork and sawFinish and sawEat and sawReturn and(counts['break-stow']or 0)>=2 and(counts['break-finish']or 0)>=2 and(counts['break-toStorage']or 0)>=2 then finishWorkshop()end
end)end

V.atFrame(5620,finishWorkshop)
