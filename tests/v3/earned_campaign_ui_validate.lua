-- Actual completed earned village: UI reread of historical objectives.
-- Not a first-time new-game walkthrough. No lesson/resource/goal assignments.
-- Pause is selected through the real menu before rereading, keeping relief isolated.
local UI=require 'urhox-libs/UI'
local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local Data=require 'game.SaveData'
local D=require 'game.Definitions'
local run='earned-campaign-ui'
for _,a in ipairs(GetArguments())do run=a:match('^-pixelqa%-run=([%w_-]+)$')or run end
local s,view,hud,store,files,seq,pending,baseline,records=nil,nil,nil,nil,{},910,nil,nil,{}
local aborted=false
local function atFrame(frame,fn)V.atFrame(frame,function()if not aborted then fn()end end)end
local function requireState(ok,message)
 V.assert(ok,message)
 if not ok then
  local im=Image();if graphics:TakeScreenShot(im)then im:SavePNG('tests/v3/evidence/visual/'..run..'-prerequisite-failure.png')end
  aborted=true;V.finish()
 end
 return ok
end
local function inspect()s,view,hud=Game.Inspect()end
local function tap(id)
 local w=hud.root:FindById(id);V.assert(w and w:IsVisible(),'Visible actual control: '..id)
 if not w then return end
 local p=w:GetAbsoluteLayoutForHitTest();seq=seq+1
 UI.HandleTouchBegin(seq,(p.x+p.w*.5)*UI.GetScale(),(p.y+p.h*.5)*UI.GetScale());UI.HandleTouchEnd(seq,(p.x+p.w*.5)*UI.GetScale(),(p.y+p.h*.5)*UI.GetScale());inspect();hud.update()
end
local function scroll()
 local p=hud.root:FindById('drawer_village'):GetAbsoluteLayout();seq=seq+1
 local x=(p.x+p.w*.5)*UI.GetScale();local y=p.y+p.h-25
 UI.HandleTouchBegin(seq,x,y*UI.GetScale())
 for i=1,12 do UI.HandleTouchMove(seq,x,(y-i*(p.h-70)/12)*UI.GetScale())end
 UI.HandleTouchEnd(seq,x,(p.y+45)*UI.GetScale());hud.update()
end
function CaptureEarnedCampaignUI()
 if not pending then return end
 local im=Image();if graphics:TakeScreenShot(im)then
  local path='tests/v3/evidence/visual/'..run..'-'..pending..'.png';im:SavePNG(path)
  records[#records+1]={label=pending,path=path,lesson=s.lesson,paused=s.paused,victory=s.victory,campaignCompleted=s.campaignCompleted}
 end
 pending=nil
end
atFrame(6,function()
 local f=File('tests/v3/fixtures/earned_cad35_campaign_victory.json',FILE_READ);local raw=cjson.decode(f:ReadString());f:Close()
 local old,why=Data.restore(raw,'finite');V.assert(old and old.victory and old.campaignCompleted,'Real earned six-enemy victory restores: '..tostring(why))
 store=Store.new({now=function()return 1000+old.elapsed end,read=function(k)return files[k]end,write=function(k,v)files[k]=v;return true end})
 V.assert(store:save(old,true),'Actual completed village uses isolated real save encoder')
 Game.UseStore(store);inspect();SubscribeToEvent('EndAllViewsRender','CaptureEarnedCampaignUI')
end)
atFrame(12,function()tap('enterVillage')end)
atFrame(16,function()pending='earned-victory'end)
atFrame(20,function()tap('continueFreePlay');V.assert(s.freePlay and not s.victory and s.campaignCompleted,'Actual victory Continue preserves earned industrial completion')end)
atFrame(22,function()tap('enterVillage');requireState(not s.menuOpen,'After removing saved victory overlay, actual mode-entry touch enters the village')end)
atFrame(24,function()tap('open_system')end)
atFrame(28,function()tap('pause');requireState(s.paused,'Real menu pauses before isolated historical tutorial reread')end)
atFrame(32,function()tap('closeDrawer系 统 与 存 档');tap('open_village')end)
for _,f in ipairs({36,40,44,48,52})do atFrame(f,scroll)end
atFrame(56,function()
 tap('restartMentor');if not requireState(s.lesson==1 and not s.skipped,'Real village action reopens lesson one without overwriting world goals')then return end
 baseline=Data.capture(s,1000,1,true);pending='lesson-01'
end)
for lesson=1,20 do
 local frame=64+(lesson-1)*8
 atFrame(frame,function()
  local value,target=s:lessonProgress()
  if not requireState(s.lesson==lesson and value>=target,'Historical earned objective actually satisfies lesson '..lesson)then return end
  V.assert(hud.root:FindById('mentorDialogue'):IsVisible(),'Real teaching dialogue shown in sequence for lesson '..lesson)
  if lesson==10 or lesson==11 or lesson==19 or lesson==20 then pending='lesson-'..lesson end
 end)
 atFrame(frame+4,function()
  tap('mentorGo');V.assert(s.lesson==lesson+1,'Actual teaching touch advances exactly one step from lesson '..lesson)
 end)
end
atFrame(228,function()
 V.assert(s.lesson==21 and not hud.root:FindById('mentorDialogue'):IsVisible(),'Twentieth actual teaching click ends the reread normally')
 V.assert(s.elapsed==baseline.world.elapsed,'Paused teaching reread advances no simulation time or food relief')
 local same=true;for _,r in ipairs(D.goods)do if s.stock[r]~=baseline.world.stock[r]then same=false end end
 V.assert(same and #s.buildings==#baseline.world.buildings and s.population==baseline.world.population,'Twenty UI clicks retain the entire earned village and goods')
 V.assert(store:save(s,true),'Actual reread completion persists through ordinary save')
 local restored=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,2,true))),'finite')
 V.assert(restored and restored.lesson==21 and restored.campaignCompleted and restored.freePlay and not restored.victory,'Saved reread and continued victory stay completed without relocking')
 local f=File('tests/v3/evidence/visual/'..run..'-states.json',FILE_WRITE);f:WriteString(cjson.encode(records));f:Close();V.finish()
end)
