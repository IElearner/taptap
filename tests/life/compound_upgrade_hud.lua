-- Actual touch hit-testing for the new player-facing upgrade control.
-- Synthetic legacy omission, controlled construction, paused; not earned economy.
local f=File('tests/life/compound_support.lua',FILE_READ);local C=assert(load(f:ReadString(),'@tests/life/compound_support.lua'))();f:Close()
local H=C.H;local UI=require 'urhox-libs/UI';local Game=require 'network.Standalone';local Store=require 'game.PixelSaveStore'
local run=C.runName('compound-upgrade-hud');local s,b,view,hud,pending;local seq=900;local records={};local before;local failed=false
local function requireUI(ok,msg)V.assert(ok,msg);if not ok then failed=true;V.finish();return false end;return true end
local function tapAt(x,y)
 seq=seq+1;UI.HandleTouchBegin(seq,x*UI.GetScale(),y*UI.GetScale());UI.HandleTouchEnd(seq,x*UI.GetScale(),y*UI.GetScale());hud.update()
end
local function tapUpgrade()
 local w=hud.root:FindById('upgradeCompound');if not requireUI(w and w:IsVisible(),'Upgrade button exists and is visible')then return end
 local l=w:GetAbsoluteLayoutForHitTest();local d=hud.root:FindById('drawer_selected'):GetAbsoluteLayoutForHitTest()
 if not requireUI(l.w>0 and l.h>0 and l.y+l.h*.5>=d.y and l.y+l.h*.5<=d.y+d.h,'Upgrade touch center lies inside the visible drawer viewport')then return end
 tapAt(l.x+l.w*.5,l.y+l.h*.5)
end
local function scroll()
 local l=hud.root:FindById('drawer_selected'):GetAbsoluteLayout();seq=seq+1
 UI.HandleTouchBegin(seq,(l.x+l.w*.5)*UI.GetScale(),(l.y+l.h-25)*UI.GetScale())
 for i=1,10 do UI.HandleTouchMove(seq,(l.x+l.w*.5)*UI.GetScale(),(l.y+l.h-25-i*(l.h-70)/10)*UI.GetScale())end
 UI.HandleTouchEnd(seq,(l.x+l.w*.5)*UI.GetScale(),(l.y+45)*UI.GetScale())
end
local function shot(label)pending={label=label,delay=4}end
function CaptureCompoundUpgradeHud()
 if not pending then return end;pending.delay=pending.delay-1;if pending.delay>0 then return end
 local im=Image();if graphics:TakeScreenShot(im)then
  local path='tests/life/evidence/visual/'..run..'-'..pending.label..'.png';im:SavePNG(path)
  local w=hud.root:FindById('upgradeCompound')
  records[#records+1]={path=path,label=pending.label,message=s.message,site=C.copy(b.site or {}),upgradeVisible=w and w:IsVisible(),layout=w and w:GetAbsoluteLayoutForHitTest()}
 end;pending=nil
end
local function at(n,fn)V.atFrame(n,function()if not failed then fn()end end)end
at(6,function()
 local z=C.new();local old=C.add(z,'mill');local id=old.id
 local data=H.Data.capture(z,1000,1,true);data.version=8
 for _,entry in ipairs(data.world.buildings)do entry.site=nil;entry.lifeEnabled=nil end
 local restored,why=H.Data.restore(C.copy(data),'finite');assert(restored,why)
 local files={};local store=Store.new({now=function()return 1000 end,read=function(k)return files[k]end,write=function(k,v)files[k]=v;return true end})
 assert(store:save(restored,true));Game.UseStore(store);s,view,hud=Game.Inspect();hud.dismissIntro();s.paused=true;b=s.buildings[id]
 view.zoom(-100);view.focus(b.x-1,b.y-.5);hud.update();SubscribeToEvent('EndAllViewsRender','CaptureCompoundUpgradeHud')
end)
at(12,function()local x,y=view.worldToScreen(b.x-.5,b.y-.3);tapAt(x,y)end)
at(18,function()requireUI(hud.root:FindById('drawer_selected'):IsVisible(),'Actual world touch opens the legacy building details')end)
for _,n in ipairs({22,28,34})do at(n,scroll)end
at(40,function()shot('before-busy-touch');before=H.Data.capture(s,1000,1,true)end)
at(48,tapUpgrade)
at(54,function()
 V.assert(not(b.site and b.site.compound)and C.same(before,H.Data.capture(s,1000,1,true)),'Real button rejects running building without persistent changes')
 V.assert(type(s.message)=='string'and s.message:find('停工',1,true)~=nil,'Real rejected touch gives actionable stop-work feedback')
 shot('busy-reason')
end)
at(62,function()assert(s:setWorking(b,false));hud.update();before=H.Data.capture(s,1000,1,true)end) -- Normal public stop API; upgrade itself is never called by the test.
at(68,tapUpgrade)
at(74,function()
 V.assert(b.site and b.site.compound,'Actual upgrade touch attaches compound at the existing building')
 V.assert(C.same(before.world.stock,s.stock)and C.same(before.world.roads,s.roads)and before.world.population==s.population,'Actual UI upgrade preserves stock, roads and population')
 V.assert(not hud.root:FindById('upgradeCompound'):IsVisible(),'Completed upgrade removes the now-inapplicable button')
 local z,e=H.restore(s);V.assert(z and C.same(z.buildings[b.id].site,b.site),'Touch-created compound survives JSON reload: '..tostring(e))
 shot('success')
end)
at(84,function()
 V.assert(#records==3,'Busy, refusal and success UI screenshots are all complete held frames')
 C.write('tests/life/evidence/visual/'..run..'-states.json',{complete=true,records=records,actualTouch=true,stopViaPublicAPI=true,controlledMaterials=true,controlledCompletion=true,syntheticLegacy=true});V.finish()
end)
