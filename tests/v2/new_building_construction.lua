local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local A=require 'game.PixelAssets'
local s,view,hud,saw,bake,count=nil,nil,nil,nil,nil,0
local capture=false
function CaptureV2Construction()
 if not capture then return end
 local image=Image()
 if graphics:TakeScreenShot(image) then
  image:SavePNG(string.format('tests/v2/evidence/construction/frame-%03d.png',count));count=count+1
 end
 capture=false
end
V.atFrame(6,function()
 Game.UseStore(Store.new({now=function()return 1000 end,read=function()return nil end,write=function()return true end}))
 s,view,hud=Game.Inspect();hud.dismissIntro()
 s.started,s.skipped,s.menuOpen=true,true,false
 s.stock.rawwood=0;s.stock.flour=0
 for x=4,14 do s.roads[x..':9']=true end;s.roadCount=11
 local ok,msg;saw=nil;ok,msg,saw=s:build('sawmill',7,8);V.assert(ok,'Real sawmill foundation: '..tostring(msg))
 ok,msg,bake=s:build('bakery',14,8);V.assert(ok,'Real bakery foundation: '..tostring(msg))
 s:update(.1)
 
 s.paused=true;hud.update();view.zoom(-100);view.focus(10,8)
 SubscribeToEvent('EndAllViewsRender','CaptureV2Construction')
 V.assert(cache:Exists(A.root..A.buildings.sawmill.path),'Native asset cache contains sawmill image')
 V.assert(cache:Exists(A.root..A.buildings.bakery.path),'Native asset cache contains bakery image')
end)
for frame=12,1012 do
 V.atFrame(frame,function()
  s.paused=false;s:update(.1);s.paused=true
  if frame==62 then view.zoom(1);view.focus(6.3,7.2) end
  if frame==512 then view.focus(13,7.2) end
  if frame%20==0 then capture=true end
 end)
end
V.atFrame(1020,function()
 V.assert(saw.complete,'Actual sawmill construction completes during this native recording')
 V.assert(bake.complete,'Actual bakery construction completes during this native recording')
 V.assert(count>=50,'Continuous actual native production has at least 50 retained screenshot frames')
 V.assert(s.stock.wood==52 and s.stock.stone==28,'Two workshops charge their total 20 wood and 12 stone once')
 V.finish()
end)
