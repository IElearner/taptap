-- Actual legal south-bank compound plus isolated production ground primitives.
-- This is a renderer-boundary check and held native overview, not a fish cycle.
local f=File('tests/life/compound_support.lua',FILE_READ);local C=assert(load(f:ReadString(),'@tests/life/compound_support.lua'))();f:Close()
local H=C.H;local PixelLife=require 'game.PixelLife';local Game=require 'network.Standalone';local Store=require 'game.PixelSaveStore'
local run=C.runName('compound-south');local s,b,view,hud,pending;local records={};local boundsRecord
function CaptureSouthCompound()
 if not pending then return end;pending.delay=pending.delay-1;if pending.delay>0 then return end
 local im=Image();if graphics:TakeScreenShot(im)then
  local path='tests/life/evidence/visual/'..run..'-'..pending.label..'.png';im:SavePNG(path)
  records[#records+1]={path=path,label=pending.label,site=C.copy(b.site),actor=C.copy(s.workers[b.id..':1']or{}),elapsed=s.elapsed}
 end;pending=nil
end
V.atFrame(6,function()
 local z=C.new();local chosen
 -- South-facing alone is insufficient: explicitly choose a real legal site
 -- whose actual approach exercises the changed southern-extension branch.
 for y=2,29 do for x=2,29 do
  local ok,_,site=z:canBuild('fishery',x,y)
  if not chosen and ok and site and site.shoreApproach and site.waterCell.y==site.shoreCell.y+1 and site.waterCell.x==site.shoreCell.x and (site.shoreApproach.y-y)*48>64 then
   local blocked={};for _,p in ipairs(H.D.cells('fishery'))do blocked[C.key(x+p.x,y+p.y)]=true end
   for _,p in ipairs(site.yardCells or{})do blocked[C.key(p.x,p.y)]=true end
   if H.path(z,x,y+1,blocked)then chosen={x=x,y=y}end
  end
 end end
 assert(chosen,'No legal reachable southern-extension fixture; do not alter terrain/site')
 local built,msg,target=z:build('fishery',chosen.x,chosen.y);assert(built,msg);target.complete,target.progress=true,1;H.connect(z,target)
 local site=target.site
 V.assert(site.waterCell.y==site.shoreCell.y+1 and site.waterCell.x==site.shoreCell.x,'Fixture is a genuinely legal south-facing dry bank beside water')
 V.assert(z:terrain(site.shoreCell.x,site.shoreCell.y)~='water'and z:terrain(site.waterCell.x,site.waterCell.y)=='water','Actual world terrain retains dry actor bank and adjacent water')
 local rectangles={};local names={'nvgBeginPath','nvgRect','nvgFillColor','nvgFill'};local originals={}
 for _,n in ipairs(names)do originals[n]=_G[n]end
 _G.nvgBeginPath=function()end;_G.nvgFillColor=function()end;_G.nvgFill=function()end
 _G.nvgRect=function(_,x,y,w,h)rectangles[#rectangles+1]={x=x,y=y,w=w,h=h}end
 local ok,e=pcall(function()PixelLife.ground({buildings={target}},function(x,y)return(x-target.x)*64,(y-target.y)*48 end,nil)end)
 for _,n in ipairs(names)do _G[n]=originals[n]end
 V.assert(ok,'Production ground primitive capture restores renderer globals: '..tostring(e));assert(ok,e)
 local maxY=-math.huge;for _,r in ipairs(rectangles)do maxY=math.max(maxY,r.y+r.h)end
 local sy=(site.shoreApproach.y-target.y)*48
 V.assert(sy>64 and #rectangles>20,'Real south approach exercises the southern pier branch and timber feet')
 V.assert(maxY<=site.compound.bounds[4]+1e-9,'Every actual ground rectangle including timber feet stays within reserved south bound')
 boundsRecord={bounds=C.copy(site.compound.bounds),shoreY=sy,maxRenderedY=maxY,rectangles=rectangles,productionRenderer=true}
 assert(z:staff(target,1));local files={};local store=Store.new({now=function()return 1000 end,read=function(k)return files[k]end,write=function(k,v)files[k]=v;return true end})
 assert(store:save(z,true));Game.UseStore(store);s,view,hud=Game.Inspect();hud.dismissIntro();s.paused=true;b=s.buildings[target.id]
 view.zoom(-100);view.zoom(1);view.focus(b.x,b.y+.2);hud.update();SubscribeToEvent('EndAllViewsRender','CaptureSouthCompound')
 pending={label='overview',delay=4}
end)
for frame=12,170 do V.atFrame(frame,function()
 if not b or pending then return end;s.paused=false;s:update(.1);s.paused=true;hud.update()
 if frame==160 then pending={label='actual-bank',delay=4}end
end)end
V.atFrame(180,function()
 V.assert(#records==2,'Held native south compound overview and actual early bank scene both exist')
 C.write('tests/life/evidence/visual/'..run..'-states.json',{complete=true,records=records,bounds=boundsRecord,controlledMaterials=true,controlledCompletion=true,fullCycle=false});V.finish()
end)
