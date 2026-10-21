-- Unoccupied original-forest tile for unambiguous stage artwork inspection.
-- Controlled explicit ecology time; real forester care is a separate native sequence.
local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local F=require 'game.Forestry'
local run='ecology-stage'
for _,arg in ipairs(GetArguments())do run=arg:match('^-pixelqa%-run=([%w_-]+)$') or run end
local s,view,hud,pending;local records={}
function CaptureEcologyStage()
 if not pending then return end
 local im=Image();if graphics:TakeScreenShot(im)then
  local path='tests/v3/evidence/visual/'..run..'-'..pending..'.png';im:SavePNG(path)
  records[#records+1]={path=path,label=pending,growth=s.treeGrowth['3:9'],standing=s:standingTree(3,9),controlledTime=true}
 end;pending=nil
end
V.atFrame(6,function()
 Game.UseStore(Store.new({now=function()return 1000 end,read=function()return nil end,write=function()return true end}))
 s,view,hud=Game.Inspect();hud.dismissIntro();s.started,s.skipped,s.paused=true,true,true
 V.assert(s:standingTree(3,9),'Stage visual starts on an actual original mature forest tile')
 s.felledTrees['3:9']=true;F.fell(s,3,9)
 view.zoom(-100);view.zoom(1);view.focus(3,9);hud.update()
 SubscribeToEvent('EndAllViewsRender','CaptureEcologyStage')
end)
V.atFrame(12,function()pending='stump';V.assert(s.treeGrowth['3:9'].phase=='stump' and not s:standingTree(3,9),'Unoccupied stump stage is not harvestable')end)
V.atFrame(18,function()F.update(s,180)end)
V.atFrame(22,function()pending='sapling';V.assert(s.treeGrowth['3:9'].phase=='sapling' and not s:standingTree(3,9),'Unoccupied 180-second sapling is not harvestable')end)
V.atFrame(28,function()F.update(s,270)end)
V.atFrame(32,function()pending='youngtree';V.assert(s.treeGrowth['3:9'].phase=='sapling' and s.treeGrowth['3:9'].age==270,'Older sapling keeps correct remaining growth time')end)
V.atFrame(38,function()F.update(s,270)end)
V.atFrame(42,function()pending='mature';V.assert(s:standingTree(3,9) and s.stock.rawwood==0,'Unoccupied total720-second mature tree returns without rawwood grants')end)
V.atFrame(48,function()local f=File('tests/v3/evidence/visual/'..run..'-states.json',FILE_WRITE);f:WriteString(cjson.encode(records));f:Close();V.finish()end)
