local UI=require 'urhox-libs/UI'
local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local D=require 'game.Definitions'
local s,view,hud,pending=nil,nil,nil,nil
local id=500
local pendingFrames=0
local function scrollDrawer(name)
 local d=hud.root:FindById(name):GetAbsoluteLayout();id=id+1
 UI.HandleTouchBegin(id,(d.x+d.w/2)*UI.GetScale(),(d.y+d.h-25)*UI.GetScale())
 for step=1,12 do UI.HandleTouchMove(id,(d.x+d.w/2)*UI.GetScale(),(d.y+d.h-25-step*(d.h-95)/12)*UI.GetScale())end
 UI.HandleTouchEnd(id,(d.x+d.w/2)*UI.GetScale(),(d.y+70)*UI.GetScale())
end
local function tap(idName)
 local w=hud.root:FindById(idName);V.assert(w~=nil,'HUD control exists: '..idName);if not w then return end
 local l=w:GetAbsoluteLayout();id=id+1
 UI.HandleTouchBegin(id,(l.x+l.w/2)*UI.GetScale(),(l.y+l.h/2)*UI.GetScale())
 UI.HandleTouchEnd(id,(l.x+l.w/2)*UI.GetScale(),(l.y+l.h/2)*UI.GetScale());hud.update()
end
local function mapTap(x,y)
 local px,py=view.worldToScreen(x,y);id=id+1
 UI.HandleTouchBegin(id,px*UI.GetScale(),py*UI.GetScale());UI.HandleTouchEnd(id,px*UI.GetScale(),py*UI.GetScale());hud.update()
end
local function assertLoggerLedger(resource)
 local camp
 for _,b in ipairs(s.buildings)do if b.kind=='woodcutter'then camp=b;break end end
 local a=s.workers[camp.id..':1']
 a.meal=false;a.carrying=false;a.stockedLoad=false;a.felledLoad=nil;a.loadAmount=1;a.woodPhase='toCamp';a.woodClock=0;a.path={};a.index=1;a.x=camp.x;a.y=camp.y+1
 local function counts()
  hud.update()
  local text=hud.root:FindById('warehouseLedger').props.text
  local shelf,transit=text:match(D.names[resource]..'  仓 [%d%.]+ / 待运 ([%d%.]+) / 在途 ([%d%.]+)')
  return tonumber(shelf),tonumber(transit)
 end
 local shelf,transit=counts()
 a.carrying=true
 local heldShelf,heldTransit=counts()
 V.assert(heldShelf==shelf and heldTransit==transit+1,'Logger held cargo appears once in the correct resource transit column: '..resource)
 local initialBuffer=camp.buffer
 for _=1,100 do if camp.buffer>initialBuffer then break end;s:updateWoodcutter(camp,.1)end
 V.assert(camp.buffer==initialBuffer+1 and not a.carrying,'Actual logger unload places one item onto its shelf: '..resource)
 local deliveredShelf,deliveredTransit=counts()
 V.assert(deliveredShelf==shelf+1 and deliveredTransit==transit,'Handoff moves the ledger count from transit to shelf without duplication: '..resource)
end
function CaptureV2Hud()
 if not pending then pendingFrames=0;return end
 pendingFrames=pendingFrames+1;if pendingFrames<3 then return end;pendingFrames=0
 local im=Image();if graphics:TakeScreenShot(im)then V.assert(im:SavePNG('tests/v2/evidence/visual/hud-'..pending..'.png'),'Native v2 small HUD evidence saved: '..pending)end;pending=nil
end
V.atFrame(6,function()
 local f=File('tests/v2/fixtures/v2_playable_fixture.json',FILE_READ);local data=cjson.decode(f:ReadString());f:Close()
 data.application='shanheli.pixel';data.saveSchema=1;data.savedAt=1000;data.world.skipped=true
 local raw=cjson.encode(data)
 Game.UseStore(Store.new({now=function()return 1000 end,read=function()return raw end,write=function()return true end}))
 s,view,hud=Game.Inspect();hud.dismissIntro();s.paused=true;hud.update();view.zoom(-100);view.focus(10,10)
 SubscribeToEvent('EndAllViewsRender','CaptureV2Hud')
end)
V.atFrame(12,function()tap('open_village');pending='ledger-top' end)
V.atFrame(14,function()
 V.assert(hud.root:FindById('drawer_village'):IsVisible(),'Real village tap opens the ledger drawer')
 assertLoggerLedger('rawwood')
end)
V.atFrame(18,function()
 local text=hud.root:FindById('warehouseLedger').props.text
 for _,r in ipairs(D.goods)do V.assert(text:find(D.names[r],1,true)~=nil,'Warehouse ledger contains actual good '..r)end
 local d=hud.root:FindById('drawer_village'):GetAbsoluteLayout();id=id+1
 UI.HandleTouchBegin(id,(d.x+d.w/2)*UI.GetScale(),(d.y+d.h-25)*UI.GetScale())
 for step=1,12 do UI.HandleTouchMove(id,(d.x+d.w/2)*UI.GetScale(),(d.y+d.h-25-step*(d.h-95)/12)*UI.GetScale())end
 UI.HandleTouchEnd(id,(d.x+d.w/2)*UI.GetScale(),(d.y+70)*UI.GetScale())
 V.assert(hud.root:FindById('drawer_village'):GetChildren()[2].state.scrollY>0,'Actual touch pan scrolls the long warehouse ledger')
 pending='ledger-scroll'
end)
V.atFrame(25,function()tap('closeDrawer乡 里 事 务');view.focus(9,15)end)
V.atFrame(30,function()mapTap(9,15.5)end)
V.atFrame(36,function()
 V.assert(hud.root:FindById('drawer_selected'):IsVisible(),'Actual map touch opens new workshop details')
 local text=hud.root:FindById('selectedInventory').props.text
 V.assert(text:find('原木',1,true)~=nil and text:find('60',1,true)~=nil,'Sawmill detail identifies actual raw material and sixty-second batch')
 local flow=hud.root:FindById('selectedFlow').props.text
 local state=hud.root:FindById('selectedInventory').props.text
 V.assert(flow:find('已暂停经营',1,true)~=nil and not flow:find('正在作业',1,true),'Paused loaded workshop never claims active work')
 V.assert(state:find('暂停中',1,true)~=nil,'Paused staffing is identified explicitly instead of a misleading zero active count')
 local b;for _,candidate in ipairs(s.buildings)do if candidate.kind=='sawmill'then b=candidate;break end end
 local active,rate=b.activeWorkers,b.workRate;b.activeWorkers=0;b.workRate=1;s.paused=false;hud.update()
 V.assert(not hud.root:FindById('selectedFlow').props.text:find('正在作业',1,true),'Unpaused stale workRate without an active worker cannot claim production')
 b.activeWorkers,b.workRate=active,rate;s.paused=true;hud.update()
 pending='sawmill-details'
end)
V.atFrame(43,function()tap('closeDrawer建 筑 详 情');view.focus(6,11)end)
V.atFrame(48,function()mapTap(6,11.5)end)
V.atFrame(54,function()
 local text=hud.root:FindById('selectedInventory').props.text
 V.assert(text:find('面饼',1,true)~=nil and text:find('面粉',1,true)~=nil,'Bakery detail identifies flour and bread separately')
 pending='bakery-details'
end)
V.atFrame(61,function()tap('closeDrawer建 筑 详 情');hud.root:FindById('build_woodcutter').props.onClick();hud.update();view.focus(16,8)end)
V.atFrame(65,function()
 local px,py=view.worldToScreen(17,8);id=id+1
 UI.HandleTouchBegin(id,px*UI.GetScale(),py*UI.GetScale());hud.update();pending='east-wood-preview'
 V.assert(s:treeCount({x=17,y=8,footprintW=3},6)==2,'East preview uses the actual two-tree count')
end)
V.atFrame(70,function()UI.HandleTouchCancel(id)end)
V.atFrame(76,function()
 local f=File('tests/v2/fixtures/legacy_v3_fixture.json',FILE_READ);local data=cjson.decode(f:ReadString());f:Close();data.savedAt=1000;data.world.skipped=true
 local raw=cjson.encode(data)
 Game.UseStore(Store.new({now=function()return 1000 end,read=function()return raw end,write=function()return true end}))
 s,view,hud=Game.Inspect();hud.dismissIntro();s.paused=true;hud.update();view.zoom(-100);view.focus(7,7)
end)
V.atFrame(80,function()assertLoggerLedger('wood')end)
V.atFrame(83,function()mapTap(7,7.5)end)
V.atFrame(90,function()
 local text=hud.root:FindById('selectedInventory').props.text
 V.assert(text:find('旧档面粉',1,true)~=nil,'Migrated kitchen visibly identifies remaining legacy flour')
 pending='legacy-flour'
end)
V.atFrame(93,function()scrollDrawer('drawer_selected');V.assert(hud.root:FindById('drawer_selected'):GetChildren()[2].state.scrollY>0,'Actual touch pan exposes lower kitchen inventory');pending='legacy-flour-scroll'end)
V.atFrame(98,function()
 s.paused=false;
 tap('closeDrawer建 筑 详 情');s.buildings[4].buffer=2;view.focus(14,7)
end)
V.atFrame(104,function()mapTap(14,7.5)end)
V.atFrame(110,function()
 V.assert(hud.root:FindById('selectedFlow').props.text:find('出栏区已满',1,true)~=nil,'Actual selected ranch reports its real two-head full threshold')
 pending='ranch-full';
end)
V.atFrame(116,function()
 tap('closeDrawer建 筑 详 情');s.buildings[8].buffer=6;view.focus(5,3)
end)
V.atFrame(122,function()mapTap(5,3.5)end)
V.atFrame(128,function()
 V.assert(hud.root:FindById('selectedFlow').props.text:find('暂停新采伐',1,true)~=nil,'Selected logger reports the actual six-log start threshold')
 pending='logger-full'
end)
V.atFrame(134,function()
 tap('closeDrawer建 筑 详 情');s.rock=0;s.buildings[9].buffer=0;view.focus(9,15)
end)
V.atFrame(140,function()mapTap(9,15.5)end)
V.atFrame(146,function()
 V.assert(hud.root:FindById('selectedFlow').props.text:find('石料已采尽',1,true)~=nil,'Selected quarry reports exhausted finite stone')
 pending='quarry-empty'
end)
V.atFrame(154,function()V.finish()end)
