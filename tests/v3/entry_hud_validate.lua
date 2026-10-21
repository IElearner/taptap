-- Native UI/storage integration, isolated from all player files and cloud traffic.
-- Planned for the frozen v3 candidate; this source file is not itself pass evidence.
local UI=require 'urhox-libs/UI'
local Game=require 'network.Standalone'
local PixelStore=require 'game.PixelSaveStore'
local Data=require 'game.SaveData'
local D=require 'game.Definitions'
local files,reads,writes,cloudReads,cloudWrites={},{},{},{},{}
local s,hud,store,guestRaw
local originalNew,originalBackend,originalCloud=PixelStore.new,PixelStore.nativeBackend,clientCloud
local pointer=700
local function backend()
 return {now=function()return 1000 end,
 read=function(k)reads[#reads+1]=k;return files[k]end,
 write=function(k,v)writes[#writes+1]=k;files[k]=v;return true end,
 cloudGet=function(k,callback)cloudReads[#cloudReads+1]=k;callback(true,nil);return true end,
 cloudSet=function(k,v,callback)cloudWrites[#cloudWrites+1]=k;callback(true);return true end}
end
local function inspect()s,_,hud,_,store=Game.Inspect()end
local function tap(name)
 local widget=hud.root:FindById(name);V.assert(widget~=nil,'Required real control exists: '..name);if not widget then return end
 local l=widget:GetAbsoluteLayout();pointer=pointer+1
 UI.HandleTouchBegin(pointer,(l.x+l.w*.5)*UI.GetScale(),(l.y+l.h*.5)*UI.GetScale())
 UI.HandleTouchEnd(pointer,(l.x+l.w*.5)*UI.GetScale(),(l.y+l.h*.5)*UI.GetScale());inspect();hud.update()
end
local function visibleText(widget,needle)
 if not widget:IsVisible()then return false end
 if widget.props and type(widget.props.text)=='string' and widget.props.text:find(needle,1,true)then return true end
 for _,child in ipairs(widget:GetChildren())do if visibleText(child,needle)then return true end end
 return false
end
V.atFrame(6,function()
 Game.UseStore(originalNew(backend()),true);Game.Stop()
 PixelStore.nativeBackend=backend
 PixelStore.new=function(b)return originalNew(b or backend())end
 clientCloud={userId=0};Game.Start();inspect()
 V.assert(hud.root:FindById('loginScreen'):IsVisible(),'Actual startup retains login screen before consent')
end)
V.atFrame(12,function()tap('loginGuest')end)
V.atFrame(18,function()
 V.assert(not hud.root:FindById('loginScreen'):IsVisible(),'Actual touch guest callback accepts guest session')
 tap('enterVillage')
 V.assert(s.started and not s.menuOpen,'Actual touch mode entry starts the village')
 V.assert(#s.buildings==1 and s.buildings[1].kind=='store','New guest has only the initial warehouse, no gifted industries')
 V.assert(s.stock.wood==72 and s.stock.stone==40 and s.stock.food==28 and s.population==10,'New guest keeps declared baseline stock and population')
 for _,r in ipairs(D.goods)do if r~='wood' and r~='stone' and r~='food'then V.assert(s.stock[r]==0,'New guest has no gifted intermediate/advanced good: '..r)end end
 s.paused=true;hud.update()
end)
V.atFrame(24,function()
 tap('mentorSkip')
 V.assert(s.skipped and s.lesson==#D.lessons+1,'Actual skip enables free play after the current last lesson')
 local restored=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite')
 V.assert(restored and restored.skipped and restored.lesson==s.lesson,'Skip state and lesson survive the actual serialization format')
 V.assert(store:save(s,true),'Guest saves through the actual session-created backend')
 guestRaw=files['guest_shanheli_pixel_v1_finite.json']
 V.assert(guestRaw~=nil and files['shanheli_pixel_v1_finite.json']==nil,'Actual guest callback prefixes the local slot and leaves account slot untouched')
 V.assert(#cloudReads==0 and #cloudWrites==0,'Actual guest callback disables all cloud read/write functions')
end)
V.atFrame(30,function()
 -- These controlled outcome fixtures validate panel synchronization only;
 -- actual battle victories are tested separately in end-to-end progression.
 s.victory=true;s.defeat=false;hud.update()
 V.assert(visibleText(hud.root,'炊烟又起'),'Victory state displays its visible victory panel')
 V.assert(not visibleText(hud.root,'义仓失守'),'Victory does not display the defeat title')
end)
V.atFrame(33,function()
 local beforeStock=Data.capture(s,1000,1,true).world.stock;local beforeBuildings=#s.buildings;local beforePopulation=s.population
 tap('continueFreePlay')
 V.assert(s.freePlay and not s.victory and not s.campaignCompleted,'Actual victory Continue control starts free play without falsely awarding unfinished industrial campaign')
 local same=true;for _,r in ipairs(D.goods)do if s.stock[r]~=beforeStock[r]then same=false end end
 V.assert(same and #s.buildings==beforeBuildings and s.population==beforePopulation,'Actual Continue control preserves all existing inventory, buildings and population')
 local continuation=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite')
 V.assert(continuation and continuation.freePlay and not continuation.victory and not continuation.campaignCompleted,'Non-campaign victory continuation survives actual JSON restore without claiming industrial completion')
 s.paused=true
 s.victory=false;s.defeat=true;hud.update()
 V.assert(visibleText(hud.root,'义仓失守'),'Defeat state displays its visible defeat panel')
 V.assert(not visibleText(hud.root,'炊烟又起'),'Defeat does not keep the victory title')
 s.defeat=false;hud.update()
 Game.Stop();guestRaw=files['guest_shanheli_pixel_v1_finite.json'];clientCloud={userId=42};Game.Start();inspect()
end)
V.atFrame(36,function()tap('loginTapTap')end)
V.atFrame(42,function()
 V.assert(not hud.root:FindById('loginScreen'):IsVisible(),'Account callback accepts an identified isolated account')
 tap('enterVillage');s.paused=true;hud.update()
 V.assert(not s.skipped and s.lesson==1,'Account startup does not silently read the guest tutorial state')
 V.assert(store:save(s,true),'Account session saves through its independently keyed backend')
 V.assert(files['shanheli_pixel_v1_finite.json']~=nil,'Account uses the unprefixed pixel slot')
 V.assert(files['guest_shanheli_pixel_v1_finite.json']==guestRaw,'Account write leaves the guest bytes unchanged')
 V.assert(#cloudReads>0,'Account callback retains the in-memory cloud path')
 V.assert(files['guest_shanheli_pixel_v1_infinite.json']==nil and files['shanheli_pixel_v1_infinite.json']==nil,'Finite operations leave both infinite slots untouched')
end)
V.atFrame(48,function()
 PixelStore.new=originalNew;PixelStore.nativeBackend=originalBackend;clientCloud=originalCloud
 V.finish()
end)
