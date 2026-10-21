local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local A=require 'game.PixelAssets'
local s,view,hud,saw,bake,count=nil,nil,nil,nil,nil,0
local capture=false
function CaptureV2Independent()
 if not capture then return end
 local image=Image()
 if graphics:TakeScreenShot(image) then
  image:SavePNG(string.format('tests/v2/evidence/visual/frame-%03d.png',count));count=count+1
 end
 capture=false
end
V.atFrame(6,function()
 Game.UseStore(Store.new({now=function()return 1000 end,read=function()return nil end,write=function()return true end}))
 s,view,hud=Game.Inspect();hud.dismissIntro()
 s.started,s.skipped,s.menuOpen=true,true,false
 s.stock.rawwood=8;s.stock.flour=8
 for x=4,14 do s.roads[x..':9']=true end;s.roadCount=11
 saw=s:addBuilding('sawmill',7,8,true);saw.workers=1
 bake=s:addBuilding('bakery',14,8,true);bake.workers=1
 s:update(.1)
 for _=1,400 do s:update(.1) end
 s.paused=true;hud.update();view.zoom(-100);view.focus(10,8)
 SubscribeToEvent('EndAllViewsRender','CaptureV2Independent')
 V.assert(cache:Exists(A.root..A.buildings.sawmill.path),'Native asset cache contains sawmill image')
 V.assert(cache:Exists(A.root..A.buildings.bakery.path),'Native asset cache contains bakery image')
end)
for frame=12,812 do
 V.atFrame(frame,function()
  s.paused=false;s:update(.1);s.paused=true
  if frame==262 then view.zoom(1);view.focus(6.3,7.2) end
  if frame==512 then view.focus(13,7.2) end
  if frame%15==0 then capture=true end
 end)
end
V.atFrame(820,function()
 V.assert((s.produced.wood or 0)>0,'Sawmill produces and physically transports construction wood during the recording')
 V.assert((s.produced.bread or 0)>0,'Bakery produces and physically transports bread during the recording')
 V.assert(count>=50,'Continuous actual native production has at least 50 retained screenshot frames')
 print('V2_VISUAL_PRODUCTION',cjson.encode(s.produced))
 V.finish()
end)
