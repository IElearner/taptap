-- Controlled new legal adjacency and actual immutable legacy village display.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local Sim=require 'game.Simulation';local Game=require 'network.Standalone';local Store=require 'game.PixelSaveStore'
local run='life-yard';for _,v in ipairs(GetArguments())do run=v:match('^-pixelqa%-run=([%w_-]+)$')or run end
local s,view,hud,pending;local records={}
function CaptureLifeYard()
 if not pending then return end;pending.delay=pending.delay-1;if pending.delay>0 then return end
 local im=Image();if graphics:TakeScreenShot(im)then im:SavePNG(pending.path);records[#records+1]=pending end;pending=nil
end
local function display(z,b,label)
 local files={};local store=Store.new({now=function()return 1000 end,read=function(k)return files[k]end,write=function(k,v)files[k]=v;return true end});assert(store:save(z,true));Game.UseStore(store);s,view,hud=Game.Inspect();hud.dismissIntro();s.paused=true
 view.zoom(-100);view.zoom(0);view.focus(b.x,b.y-.4);hud.update()
 pending={delay=4,path='tests/life/evidence/visual/'..run..'-'..label..'.png',label=label,buildings=s.buildings,roads=s.roads,controlled=label:find('new',1,true)~=nil}
 pending=cjson.decode(cjson.encode(pending))
end
V.atFrame(6,function()SubscribeToEvent('EndAllViewsRender','CaptureLifeYard')end)
local kinds={'fishery','quarry','ironmine','coalmine','goldmine','mason','mill','bakery','butcher','sawmill','smelter','tannery','woodweapons','leatherarmor','ironweapons','ironarmor'}
for i,kind in ipairs(kinds)do
 V.atFrame(10+(i-1)*12,function()
  local z=Sim.new('finite',23);z.started,z.skipped=true,true;z.stock.wood,z.stock.stone,z.stock.food=1000,1000,500
  local b=H.add(z,kind);local hall=H.add(z,'kitchen');hall.mealStock=8;assert(z:staff(b,1))
  for _=1,5 do H.add(z,'house')end
  V.assert(#z.buildings==8,'Real canBuild places main '..kind..' plus hall and five legally separated neighboring houses')
  z:update(.1)
  display(z,b,'new-'..kind..'-neighbors')
 end)
end
for i,kind in ipairs({'mason','fishery','ironmine'})do
 V.atFrame(210+(i-1)*12,function()
  local f=File('tests/life/fixtures/schema8_earned35.json',FILE_READ);local old=cjson.decode(f:ReadString());f:Close();local z,why=H.Data.restore(old,'finite');assert(z,why)
  z:update(.1);local b;for _,candidate in ipairs(z.buildings)do if candidate.kind==kind then b=candidate;break end end;assert(b)
  V.assert(b.site==nil or b.site.version==1,'Legacy '..kind..' uses compact sites without new yard occupation')
  display(z,b,'legacy-'..kind..'-neighbors')
 end)
end
V.atFrame(250,function()
 V.assert(#records==19,'All sixteen new adjacency and three actual legacy layout views captured')
 local f=File('tests/life/evidence/visual/'..run..'-states.json',FILE_WRITE);f:WriteString(cjson.encode(records));f:Close();V.finish()
end)
