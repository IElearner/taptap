-- Controlled shelf levels, then actual ordinary carrier pickup reducing level.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local Game=require 'network.Standalone';local Store=require 'game.PixelSaveStore'
local run='life-tank';for _,v in ipairs(GetArguments())do run=v:match('^-pixelqa%-run=([%w_-]+)$')or run end
local s,b,view,hud,pending;local records={};local observed=false;local previous=5
function CaptureLifeTank()
 if not pending then return end;pending.delay=pending.delay-1;if pending.delay>0 then return end
 local im=Image();if graphics:TakeScreenShot(im)then im:SavePNG(pending.path);records[#records+1]=pending end;pending=nil
end
local function shot(label)
 pending={delay=3,path='tests/life/evidence/visual/'..run..'-'..label..'.png',label=label,buffer=b.buffer,output=b.outputGoods,carriers=s.carriers,controlledLevel=label:find('level',1,true)~=nil}
 pending=cjson.decode(cjson.encode(pending))
end
V.atFrame(6,function()
 local z,target=H.setup('fishery',1);z:update(.1);assert(target.lifeEnabled);z:setWorking(target,false);local files={};local store=Store.new({now=function()return 1000 end,read=function(k)return files[k]end,write=function(k,v)files[k]=v;return true end});assert(store:save(z,true));Game.UseStore(store);s,view,hud=Game.Inspect();hud.dismissIntro();s.paused=true;b=s.buildings[target.id]
 V.assert(b.lifeEnabled and b.site~=nil,'Actual worker first tick initialized real fish tank before controlled tier rendering');view.zoom(-100);view.zoom(2);view.focus(b.site.tankCell.x,b.site.tankCell.y-.4);hud.update();SubscribeToEvent('EndAllViewsRender','CaptureLifeTank')
end)
for i,n in ipairs({0,1,3,5})do V.atFrame(10+(i-1)*8,function()
 b.outputGoods.fish=n;b.buffer=n;shot('level-'..n)
end)end
for frame=45,1245 do V.atFrame(frame,function()
 if pending then return end
 s.paused=false;s:update(.1);s.paused=true;hud.update()
 if b.buffer~=previous then
  for _,c in ipairs(s.carriers)do if c.carrying and c.job and c.job.b==b and c.job.resource=='fish'and c.job.pickedUp then observed=true end end
  shot('actual-pickup-'..b.buffer);previous=b.buffer
 end
end)end
V.atFrame(1250,function()
 V.assert(observed and b.buffer==0 and s.stock.fish==5,'Actual carriers remove all five controlled shelf fish once and deliver them')
 V.assert(#records>=5,'Native tank tiers and actual stock reductions captured')
 local f=File('tests/life/evidence/visual/'..run..'-states.json',FILE_WRITE);f:WriteString(cjson.encode(records));f:Close();V.finish()
end)
