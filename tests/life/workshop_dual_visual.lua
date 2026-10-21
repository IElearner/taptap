-- Controlled two real positions and two complete input batches; only clothing
-- appearance is fixed to look1/look2. Every phase/load/path is autonomous.
local hf=File('tests/life/support.lua',FILE_READ);local H=assert(load(hf:ReadString(),'@tests/life/support.lua'))();hf:Close()
local Sim=require 'game.Simulation';local Game=require 'network.Standalone';local Store=require 'game.PixelSaveStore';local Actors=require 'game.PixelActors';local A=require 'game.PixelAssets'
local run='life-workshop-mill-dual';for _,v in ipairs(GetArguments())do run=v:match('^-pixelqa%-run=([%w_-]+)$')or run end
local kind=assert(run:match('workshop%-([%w]+)'));local s,b,id,view,hud,pending;local records,trace,history,counts,last={}, {}, {}, {}, {};local fixed=false;local supplied=false;local done=false
function CaptureDualWorkshop()
 if not pending then return end;pending.delay=pending.delay-1;if pending.delay>0 then return end
 local im=Image();if graphics:TakeScreenShot(im)then im:SavePNG(pending.path);records[#records+1]=pending end;pending=nil
end
local function finish()
 if done then return end;done=true
 for i=1,2 do
  V.assert((counts['look'..i..'-work']or 0)>=2,'Real look'..i..' reaches distinct outdoor work point')
  V.assert((counts['look'..i..'-finish']or 0)>=2,'Real look'..i..' finishes actual batch with held goods before stow')
  V.assert((counts['look'..i..'-stow']or 0)>=1,'Real look'..i..' walks to actual storage to hand off output')
 end
 local o=File('tests/life/evidence/visual/'..run..'-states.json',FILE_WRITE);o:WriteString(cjson.encode({records=records,trace=trace,kind=kind,controlledMaterials=true,controlledAppearanceOnly=true}));o:Close();V.finish()
end
V.atFrame(6,function()
 local z=Sim.new('finite',23);z.started,z.skipped=true,true;z.stock.wood,z.stock.stone,z.stock.food=1000,1000,500
 local target=H.add(z,kind);id=target.id;local hall=H.add(z,'kitchen');hall.mealStock=8;hall.inputGoods.bread=4;hall.inputs=4
 for _,r in ipairs(H.D.goods)do if r~='food'then z.stock[r]=0 end end
 assert(z:staff(target,1));assert(z:staff(target,1));if H.D.buildings[kind].recipes then assert(z:setRecipe(target,1))end
 local files={};local store=Store.new({now=function()return 1000 end,read=function(k)return files[k]end,write=function(k,v)files[k]=v;return true end})
 assert(store:save(z,true));Game.UseStore(store);s,view,hud=Game.Inspect();hud.dismissIntro();s.paused=true;b=s.buildings[id];view.zoom(-100);view.zoom(1);hud.update();SubscribeToEvent('EndAllViewsRender','CaptureDualWorkshop')
end)
for frame=10,4200 do V.atFrame(frame,function()
 if done or pending or not b then return end;s.paused=false;s:update(.1);s.paused=true;hud.update()
 if not fixed and s.workers[id..':1']and s.workers[id..':2']then s.workers[id..':1'].workerLook=1;s.workers[id..':2'].workerLook=2;fixed=true end
 local projections={};for _,p in ipairs(Actors.collect(s,history))do projections[p.key]=p end
 for i=1,2 do
  local a=s.workers[id..':'..i];local p=projections['worker'..id..':'..i];local phase=a and a.breaks and a.breaks.phase
  if a and p and phase then
   trace[#trace+1]=cjson.decode(cjson.encode({time=s.elapsed,slot=i,look=a.workerLook,phase=phase,x=a.x,y=a.y,load=a.workLoad,held=b.workOutputHeld,output=b.outputGoods,timer=b.timer}))
   local label='look'..i..'-'..phase
   if not pending and(counts[label]or 0)<3 and(not last[label]or s.elapsed-last[label]>=.35)then
    counts[label]=(counts[label]or 0)+1;last[label]=s.elapsed
    if phase=='work'or phase=='finish'then view.focus(b.site.workCell.x,b.site.workCell.y-.5)else view.focus(a.x,a.y-.5)end
    local sx,sy=view.worldToScreen(a.x,a.y)
    pending=cjson.decode(cjson.encode({delay=3,path='tests/life/evidence/visual/'..run..'-'..label..'-'..counts[label]..'.png',label=label,slot=i,time=s.elapsed,actor=a,allWorkers=s.workers,sprite=A.actorSprite(p,s.elapsed),projection=p,actorScreen={x=sx,y=sy},site=b.site,timer=b.timer,workRate=b.workRate,outputGoods=b.outputGoods,workOutputHeld=b.workOutputHeld,camera=view.cameraState()}))
   end
  end
 end
 if not supplied and(counts['look1-idle']or 0)>=2 and(counts['look2-idle']or 0)>=2 and not pending then
  local r=H.E.recipe(b);local inputs=r and r.inputs or {[H.D.buildings[kind].input]=1};for k,n in pairs(inputs)do b.inputGoods[k]=n*2;b.inputs=b.inputs+n*2 end;supplied=true
 end
 local ready=supplied and not pending
 for i=1,2 do if(counts['look'..i..'-finish']or 0)<2 or(counts['look'..i..'-stow']or 0)<2 then ready=false end end
 if ready then finish()end
end)end
V.atFrame(4210,finish)
