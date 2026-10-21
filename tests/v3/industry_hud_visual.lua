-- Native small-screen inspection and touch controls on the actual earned
-- village. Paused display fixture; no economic or resource earning claim.
local UI=require 'urhox-libs/UI'
local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local D=require 'game.Definitions'
local run='industry-hud'
for _,arg in ipairs(GetArguments())do run=arg:match('^-pixelqa%-run=([%w_-]+)$') or run end
local s,view,hud,pending,b,seq=nil,nil,nil,nil,nil,800
local records={}
local function tap(id)
 local w=hud.root:FindById(id);V.assert(w and w:IsVisible(),'Actual industry HUD control is visible: '..id)
 if not w then return end
 local l=w:GetAbsoluteLayoutForHitTest();seq=seq+1
 UI.HandleTouchBegin(seq,(l.x+l.w*.5)*UI.GetScale(),(l.y+l.h*.5)*UI.GetScale())
 UI.HandleTouchEnd(seq,(l.x+l.w*.5)*UI.GetScale(),(l.y+l.h*.5)*UI.GetScale());hud.update()
end
local function scroll(id)
 local l=hud.root:FindById(id or 'drawer_selected'):GetAbsoluteLayout();seq=seq+1
 UI.HandleTouchBegin(seq,(l.x+l.w*.5)*UI.GetScale(),(l.y+l.h-25)*UI.GetScale())
 for i=1,10 do UI.HandleTouchMove(seq,(l.x+l.w*.5)*UI.GetScale(),(l.y+l.h-25-i*(l.h-70)/10)*UI.GetScale())end
 UI.HandleTouchEnd(seq,(l.x+l.w*.5)*UI.GetScale(),(l.y+45)*UI.GetScale())
end
local function shot(label)pending=label end
function CaptureV3IndustryHud()
 if not pending then return end
 local im=Image();if graphics:TakeScreenShot(im)then
  local path='tests/v3/evidence/visual/'..run..'-'..pending..'.png';im:SavePNG(path)
  records[#records+1]={path=path,label=pending,kind=b and b.kind,flow=hud.root:FindById('selectedFlow').props.text,details=hud.root:FindById('industryDetails').props.text}
 end
 pending=nil
end
V.atFrame(6,function()
 local f=File('tests/v3/fixtures/earned242_after_failed_endurance.json',FILE_READ);local raw=cjson.decode(f:ReadString());f:Close()
 raw.application='shanheli.pixel';raw.saveSchema=1;raw.savedAt=1000;raw.world.paused=true
 local encoded=cjson.encode(raw)
 Game.UseStore(Store.new({now=function()return 1000 end,read=function()return encoded end,write=function()return true end}))
 s,view,hud=Game.Inspect();hud.dismissIntro();s.paused=true;view.zoom(-100);hud.update()
 SubscribeToEvent('EndAllViewsRender','CaptureV3IndustryHud')
end)
local kinds={'smelter','ironmine','fishery','forester','ironarmor'}
for i,kind in ipairs(kinds)do
 local start=12+(i-1)*44
 V.atFrame(start,function()
  if i>1 then tap('closeDrawer建 筑 详 情')end
  for _,v in ipairs(s.buildings)do if v.kind==kind then b=v;break end end
  view.focus(b.x-1,b.y-.5);hud.update()
 end)
 V.atFrame(start+4,function()
  local x,y=view.worldToScreen(b.x-.5,b.y-.3);seq=seq+1
  UI.HandleTouchBegin(seq,x*UI.GetScale(),y*UI.GetScale());UI.HandleTouchEnd(seq,x*UI.GetScale(),y*UI.GetScale());hud.update()
 end)
 V.atFrame(start+8,function()
  V.assert(hud.root:FindById('drawer_selected'):IsVisible(),'Actual map touch selects expanded '..kind)
  V.assert(hud.root:FindById('selectedFlow').props.text:find('已暂停经营',1,true)~=nil,'Paused restored expanded industry does not claim active work: '..kind)
  shot(kind..'-top')
 end)
 V.atFrame(start+12,function()scroll()end)
 V.atFrame(start+16,function()
  local text=hud.root:FindById('industryDetails').props.text
  if kind=='smelter'or kind=='ironarmor'then V.assert(text:find('当前订单',1,true)~=nil and text:find('秒',1,true)~=nil,'Expanded order panel reports the actual recipe and duration: '..kind)
  elseif kind=='forester'then V.assert(text:find('180',1,true)~=nil and text:find('540',1,true)~=nil,'Forestry panel exposes actual natural recovery and care timing')
  else V.assert(text:find('余量',1,true)~=nil,'Resource industry panel displays the actual shared finite reserve: '..kind)end
  shot(kind..'-scroll')
 end)
end
-- The short screen needs a second real swipe to expose all order controls.
V.atFrame(29,function()scroll()end)
V.atFrame(32,function()shot('smelter-controls')end)
V.atFrame(34,function()tap('cycleRecipe')end)
V.atFrame(36,function()V.assert(b.recipe==2 or b.queuedRecipe==2,'Real recipe-cycle touch selects the alternate gold order exactly once')end)
V.atFrame(38,function()tap('cancelRecipe')end)
V.atFrame(40,function()V.assert(b.recipe==0 or b.queuedRecipe==0,'Real cancel touch records cancellation instead of starting a duplicate order')end)
local toggleBefore
V.atFrame(42,function()toggleBefore=b.stopped;tap('toggleProduction')end)
V.atFrame(44,function()V.assert(b.stopped~=toggleBefore,'Real pause/resume production touch changes the selected building once')end)
V.atFrame(236,function()
 tap('closeDrawer建 筑 详 情');tap('open_village')
end)
V.atFrame(242,function()
 local text=hud.root:FindById('warehouseLedger').props.text
 for _,r in ipairs(D.goods)do V.assert(text:find(D.names[r],1,true)~=nil,'Expanded ledger lists actual resource '..r)end
 shot('all-goods-ledger')
end)
V.atFrame(246,function()scroll('drawer_village')end)
V.atFrame(250,function()shot('ledger-middle')end)
V.atFrame(254,function()scroll('drawer_village')end)
V.atFrame(258,function()shot('ledger-bottom')end)
V.atFrame(264,function()
 local f=File('tests/v3/evidence/visual/'..run..'-states.json',FILE_WRITE);f:WriteString(cjson.encode(records));f:Close();V.finish()
end)
