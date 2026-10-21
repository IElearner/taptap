-- Same real ordinary carrier from public door to storage and back. Explicit
-- controlled production materials only; never assigns phase/path/cargo/job.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local Game=require 'network.Standalone';local Store=require 'game.PixelSaveStore';local Actors=require 'game.PixelActors';local A=require 'game.PixelAssets'
local run='life-pickup-fishery';for _,v in ipairs(GetArguments())do run=v:match('^-pixelqa%-run=([%w_-]+)$')or run end
local kind=assert(run:match('pickup%-([%w]+)'));local s,b,id,view,hud,pending;local records,trace,history,counts,last={},{},{},{},{}
local lastFrame=run:find('quick',1,true)and 1600 or 4220
local sawApproach,sawLoad,sawPicked,sawReturn,sawDelivered=false,false,false,false,false;local watched
function CapturePrivatePickup()
 if not pending then return end;pending.delay=pending.delay-1;if pending.delay>0 then return end
 local im=Image();if graphics:TakeScreenShot(im)then im:SavePNG(pending.path);records[#records+1]=pending end;pending=nil
end
local function shot(label,c,p)
 counts[label]=(counts[label]or 0)+1;last[label]=s.elapsed;view.focus(c.x,c.y-.5)
 local sx,sy=view.worldToScreen(c.x,c.y)
 pending=cjson.decode(cjson.encode({delay=3,path='tests/life/evidence/visual/'..run..'-'..label..'-'..counts[label]..'.png',label=label,time=s.elapsed,carrier=watched,actor={x=c.x,y=c.y,phase=c.phase,carrying=c.carrying,sitePickup=c.sitePickup,meal=c.meal},job={resource=c.job.resource,amount=c.job.amount,pickedUp=c.job.pickedUp,sitePickup=c.job.sitePickup},sprite=p and A.actorSprite(p,s.elapsed),projection=p and{x=p.x,y=p.y,cargo=p.cargo,walking=p.walking},screen={x=sx,y=sy},site=b.site,buffer=b.buffer,outputGoods=b.outputGoods,camera=view.cameraState(),controlled=true}))
end
V.atFrame(6,function()
 local z,target=H.setup(kind);id=target.id
 local files={};local store=Store.new({now=function()return 1000 end,read=function(k)return files[k]end,write=function(k,v)files[k]=v;return true end})
 assert(store:save(z,true));Game.UseStore(store);s,view,hud=Game.Inspect();hud.dismissIntro();s.paused=true;b=s.buildings[id];view.zoom(-100);view.zoom(1);hud.update();SubscribeToEvent('EndAllViewsRender','CapturePrivatePickup')
end)
for frame=10,lastFrame-10 do V.atFrame(frame,function()
 if not b or pending then return end
 s.paused=false;s:update(.1);s.paused=true;hud.update()
 if not watched then for i,c in ipairs(s.carriers)do if c.job and c.job.b==b and not c.job.inbound then watched=i;break end end end
 local c=watched and s.carriers[watched]
 if c and c.job and c.job.b==b then
  local v=c.sitePickup;local phase=v and v.phase or c.phase or 'public-travel'
  if phase=='approach'then sawApproach=true elseif phase=='loading'then sawLoad=true elseif phase=='return'then sawReturn=true end
  if c.job.pickedUp then sawPicked=true end
  trace[#trace+1]=cjson.decode(cjson.encode({time=s.elapsed,carrier=watched,x=c.x,y=c.y,phase=phase,clock=v and v.clock,job=c.job.resource,amount=c.job.amount,pickedUp=c.job.pickedUp,carrying=c.carrying,output=b.outputGoods,buffer=b.buffer,stock=s.stock[c.job.resource]}))
  local label=phase..(phase=='loading'and(c.job.pickedUp and '-picked'or '-unpicked')or '')
  if(counts[label]or 0)<4 and(not last[label]or s.elapsed-last[label]>=.35)then
   local p;for _,q in ipairs(Actors.collect(s,history))do if q.key=='carrier'..watched then p=q;break end end
   shot(label,c,p)
  end
 end
 if s.stock[H.D.buildings[kind].output]>=H.D.buildings[kind].amount then sawDelivered=true end
end)end
V.atFrame(lastFrame,function()
 V.assert(sawApproach and sawLoad and sawReturn,'Same carrier really approaches, loads and returns at '..kind..' private station')
 V.assert(sawPicked and sawDelivered,'Real private load subsequently reaches warehouse exactly as model cycle requires')
 V.assert((counts['loading-unpicked']or 0)>0 and(counts['loading-picked']or 0)>0,'Native captures bracket actual storage deduction')
 local out=File('tests/life/evidence/visual/'..run..'-states.json',FILE_WRITE);out:WriteString(cjson.encode({records=records,trace=trace,controlled=true,kind=kind}));out:Close();V.finish()
end)
