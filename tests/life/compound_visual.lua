-- Native integrated building/yard presentation. Explicit completed-building and
-- input scaffold; natural actors/jobs/phases only. No fake shader/actor overlay.
local f=File('tests/life/compound_support.lua',FILE_READ);local C=assert(load(f:ReadString(),'@tests/life/compound_support.lua'))();f:Close()
local H=C.H;local Game=require 'network.Standalone';local Store=require 'game.PixelSaveStore'
local Actors=require 'game.PixelActors';local A=require 'game.PixelAssets'
local run=C.runName('compoundvisual-fishery');local kind=assert(run:match('compoundvisual%-([%w]+)'),'Identify compoundvisual-kind in run name')
local lastFrame=tonumber(run:match('budget(%d+)'))or 2400
local s,b,id,view,hud,pending;local records,trace,counts,last,history={},{},{},{},{}
local seenWork,seenLoad,seenStow,seenPickup,done=false,false,false,false,false
function CaptureCompoundView()
 if not pending then return end
 pending.delay=pending.delay-1;if pending.delay>0 then return end
 local im=Image();if graphics:TakeScreenShot(im)then im:SavePNG(pending.path);records[#records+1]=pending end;pending=nil
end
local function shot(label,actor,projection)
 counts[label]=(counts[label]or 0)+1;last[label]=s.elapsed
 -- Fixed building camera makes compactness/rail continuity assessable; never
 -- moves the worker/prop or substitutes a standalone pretty arrangement.
 view.focus(b.x,b.y-.2)
 pending=C.copy({delay=4,path='tests/life/evidence/visual/'..run..'-'..label..'-'..counts[label]..'.png',label=label,time=s.elapsed,building=b,actor=actor,projection=projection and{x=projection.x,y=projection.y,action=projection.action,cargo=projection.cargo,walking=projection.walking},sprite=projection and A.actorSprite(projection,s.elapsed),camera=view.cameraState(),controlledMaterials=true,controlledCompletion=true})
end
V.atFrame(6,function()
 local z=C.new();local target=C.add(z,kind);id=target.id
 local hall=C.add(z,'kitchen');hall.mealStock=8
 assert(z:staff(target,1),'Real staffing prerequisite')
 if H.D.buildings[kind].recipes then assert(z:setRecipe(target,1))end
 local recipe=H.E.recipe(target)
 if recipe then for r,n in pairs(recipe.inputs or {})do target.inputGoods[r]=2*n;target.inputs=target.inputs+2*n end end
 for _,r in ipairs(H.D.goods)do if r~='food'then z.stock[r]=0 end end
 local files={};local store=Store.new({now=function()return 1000 end,read=function(k)return files[k]end,write=function(k,v)files[k]=v;return true end})
 assert(store:save(z,true));Game.UseStore(store);s,view,hud=Game.Inspect();hud.dismissIntro();s.paused=true;b=s.buildings[id]
 view.zoom(-100);view.zoom(1);hud.update();SubscribeToEvent('EndAllViewsRender','CaptureCompoundView')
 V.assert(b.site and b.site.compound,'Native scene restores its actual newly built compound')
 shot('overview',nil,nil)
end)
local function finish()
 if done then return end;done=true
 V.assert(seenWork,'Actual worker reaches its registered integrated station and works')
 V.assert(seenLoad and seenStow,'Same worker genuinely holds and stows real output')
 V.assert(seenPickup,'Ordinary carrier is visibly carrying goods during real private storage pickup, not hidden door packing')
 V.assert(#records>=10,'Held native overview and natural phase images exist')
 C.write('tests/life/evidence/visual/'..run..'-states.json',{complete=true,kind=kind,records=records,trace=trace,controlledMaterials=true,controlledCompletion=true})
 V.finish()
end
for frame=10,lastFrame-10 do V.atFrame(frame,function()
 if done or pending or not b then return end
 s.paused=false;s:update(.1);s.paused=true;hud.update()
 local a=s.workers[id..':1'];if not a then return end
 local phase=a.meal and 'meal-'..a.meal.phase or a.life and a.life.phase or a.breaks and a.breaks.phase or a.woodPhase or 'routine'
 local p;for _,v in ipairs(Actors.collect(s,history))do if v.key=='worker'..id..':1'then p=v;break end end
 if (b.workRate or 0)>0 or phase=='fish'or phase=='mine'or phase=='cut'or phase=='chop'then seenWork=true end
 if a.carrying or a.workLoad or a.life and a.life.load then seenLoad=true end
 if phase=='stow'or phase=='stack'then seenStow=true end
 trace[#trace+1]=C.copy({time=s.elapsed,phase=phase,x=a.x,y=a.y,path=a.path,index=a.index,life=a.life,workLoad=a.workLoad,buffer=b.buffer,output=b.outputGoods,rail=b.site.railRoute,timer=b.timer,workRate=b.workRate})
 if (counts[phase]or 0)<3 and(not last[phase]or s.elapsed-last[phase]>=.35)then shot(phase,a,p)end
 for i,c in ipairs(s.carriers)do if c.job and c.job.b==b and not c.job.inbound and c.job.pickedUp and c.carrying then
  local cp;for _,v in ipairs(Actors.collect(s,history))do if v.key=='carrier'..i then cp=v;break end end
  local private=c.sitePickup and(c.sitePickup.phase=='loading'or c.sitePickup.phase=='return')
  if private and cp and cp.cargo==c.job.resource then
   seenPickup=true
   if not pending and(counts['carrier-picked']or 0)<3 then shot('carrier-picked',c,cp)end
  end
 end end
 if not pending and seenWork and seenLoad and seenStow and seenPickup and(counts['carrier-picked']or 0)>=3 and(counts.stow or counts.stack or 0)>=3 then finish()end
end)end
V.atFrame(lastFrame,finish)
