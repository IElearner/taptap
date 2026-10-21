-- Controlled isolation of a genuine standing tree. Neighbor trees are marked
-- felled (no inventory reward) solely to remove overdraw from the ROI. This is
-- rendering evidence, not logging/regrowth/earned-resource acceptance.
local Game=require 'network.Standalone';local Store=require 'game.PixelSaveStore'
local run='life-wind-isolated';for _,v in ipairs(GetArguments())do run=v:match('^-pixelqa%-run=([%w_-]+)$')or run end
local s,view,hud,pending;local records={};local ticks=0
function CaptureLifeWind()
 if not pending then return end;pending.delay=pending.delay-1;if pending.delay>0 then return end
 local im=Image();if graphics:TakeScreenShot(im)then im:SavePNG(pending.path);records[#records+1]=pending end;pending=nil
end
local function shot(label)
 local x,y=view.worldToScreen(3,5);pending={delay=3,path='tests/life/evidence/visual/'..run..'-'..label..'.png',label=label,elapsed=s.elapsed,tree={x=3,y=5},screen={x=x,y=y},camera=view.cameraState()}
end
V.atFrame(6,function()
 Game.UseStore(Store.new({now=function()return 1000 end,read=function()return nil end,write=function()return true end}))
 s,view,hud=Game.Inspect();hud.dismissIntro();s.started,s.skipped,s.menuOpen,s.paused=true,true,false,true
 local Forestry=require 'game.Forestry';local cleared=0
 for y=1,10 do for x=1,7 do if not(x==3 and y==5)and s:standingTree(x,y)then s.felledTrees[x..':'..y]=true;Forestry.fell(s,x,y);cleared=cleared+1 end end end
 print('CONTROLLED_WIND_NEIGHBORS_CLEARED',cleared,'no stock credit')
 view.zoom(-100);view.zoom(1);view.focus(3,4.6);hud.update();SubscribeToEvent('EndAllViewsRender','CaptureLifeWind')
 V.assert(s:standingTree(3,5),'Fixed wind ROI is a genuine standing forest tree')
end)
for frame=7,150 do V.atFrame(frame,function()
 if pending then return end
 if ticks>=80 then return end
 ticks=ticks+1;s.paused=false;s:update(.1);s.paused=true
 if ticks==10 or ticks==20 or ticks==30 or ticks==50 or ticks==80 then shot('clock-'..ticks)end
end)end
V.atFrame(155,function()shot('paused-repeat')end)
V.atFrame(165,function()
 V.assert(#records==6,'Fixed camera wind and paused repeat actual images captured')
 local f=File('tests/life/evidence/visual/'..run..'-states.json',FILE_WRITE);f:WriteString(cjson.encode(records));f:Close();V.finish()
end)
