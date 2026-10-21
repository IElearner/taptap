-- Real native HUD/touch at a requested viewport; isolated memory save backend.
local UI=require 'urhox-libs/UI'
local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local run='small01'
for _,arg in ipairs(GetArguments()) do run=arg:match('^-pixelqa%-run=([%w_-]+)$') or run end
local out='/workspace/artifacts/pixel-v1/independent-qa/'
local pending
local records={}
local sequence=300
local function hud() local _,_,h=Game.Inspect();return h end
local function record(id)
    local w=hud().root:FindById(id)
    if not w then V.assert(false,'HUD control exists: '..id);return end
    local l=w:GetAbsoluteLayout()
    local scale=UI.GetScale()
    local r={id=id,x=l.x*scale,y=l.y*scale,width=l.w*scale,height=l.h*scale,
        cssWidth=l.w*scale/math.max(1,graphics:GetDPR()),cssHeight=l.h*scale/math.max(1,graphics:GetDPR()),fontSize=w.props.fontSize}
    records[#records+1]=r
    V.assert(r.cssWidth>=44 and r.cssHeight>=44,'Touch target is at least 44 CSS pixels: '..id)
    V.assert(r.x>=0 and r.y>=0 and r.x+r.width<=graphics:GetWidth()+.5 and r.y+r.height<=graphics:GetHeight()+.5,'Control remains within the actual viewport: '..id)
    return w,r
end
local function tap(id)
    local w,r=record(id)
    if not w then return end
    sequence=sequence+1
    UI.HandleTouchBegin(sequence,r.x+r.width/2,r.y+r.height/2)
    UI.HandleTouchEnd(sequence,r.x+r.width/2,r.y+r.height/2)
    hud().update()
end
function CapturePixelQAHud()
    if not pending then return end
    local frame=Image()
    if graphics:TakeScreenShot(frame) then
        V.assert(frame:SavePNG(out..run..'-'..pending..'.png'),'Native lossless HUD evidence saved: '..pending)
        pending=nil
    end
end
V.atFrame(6,function()
    Game.UseStore(Store.new({now=function() return 1000 end,read=function() return nil end,write=function() return true end}),true)
    SubscribeToEvent('EndAllViewsRender','CapturePixelQAHud')
end)
V.atFrame(12,function() pending='login';record('loginTapTap');record('loginGuest') end)
V.atFrame(15,function() tap('loginGuest') end)
V.atFrame(20,function()
    V.assert(not hud().root:FindById('loginScreen'):IsVisible(),'Actual guest touch dismisses login')
    pending='mode';record('enterVillage')
end)
V.atFrame(23,function() tap('enterVillage') end)
V.atFrame(30,function()
    local s=Game.Inspect()
    V.assert(s.started and not s.menuOpen,'Actual enter-village touch starts a fresh game')
    pending='tutorial';record('mentorGo');record('mentorSkip')
    local mentor=hud().root:FindById('mentorDialogue')
    V.assert(mentor:IsVisible() and (mentor.props.opacity or 1)==1,'Tutorial guidance is fully opaque while open')
end)
V.atFrame(33,function() tap('mentorGo');hud().update(1) end)
V.atFrame(39,function()
    pending='world';record('open_build');record('open_system')
    for _,id in ipairs({'hudVersion','stock_wood','stock_stone','stock_food','population'}) do
        local label=hud().root:FindById(id)
        local l=label and label:GetAbsoluteLayout()
        V.assert(l and l.w*UI.GetScale()>15 and l.h>0 and label.props.text~='', 'Essential HUD text has visible layout and content: '..id)
    end
end)
V.atFrame(42,function() tap('open_build') end)
V.atFrame(48,function()
    V.assert(hud().root:FindById('drawer_build'):IsVisible(),'Actual bottom toolbar touch opens the build drawer')
    pending='build'
    local s,view=Game.Inspect()
    local before=#s.buildings
    local c=view.cameraState()
    local l=hud().root:FindById('drawer_build'):GetAbsoluteLayout()
    sequence=sequence+1
    UI.HandleTouchBegin(sequence,(l.x+l.w-8)*UI.GetScale(),(l.y+20)*UI.GetScale())
    UI.HandleTouchEnd(sequence,(l.x+l.w-8)*UI.GetScale(),(l.y+20)*UI.GetScale())
    V.assert(#s.buildings==before and view.cameraState().x==c.x,'Tapping build-drawer chrome does not act on the world beneath it')
end)
V.atFrame(54,function() tap('build_house') end)
V.atFrame(60,function()
    local s,view=Game.Inspect()
    V.assert(not hud().root:FindById('drawer_build'):IsVisible(),'Choosing a house through actual touch closes the build drawer')
    local before=#s.buildings
    local wood,stone=s.stock.wood,s.stock.stone
    local x,y=view.worldToScreen(8,8)
    sequence=sequence+1
    UI.HandleTouchBegin(sequence,x*UI.GetScale(),y*UI.GetScale())
    UI.HandleTouchEnd(sequence,x*UI.GetScale(),y*UI.GetScale())
    hud().update()
    local b=s:buildingAt(8,8)
    V.assert(#s.buildings==before+1 and b and b.kind=='house' and not b.complete,'Actual HUD-to-map touch plans a real new house on the selected tile')
    V.assert(s.stock.wood==wood-8 and s.stock.stone==stone-2,'The actual house placement charges its displayed material cost once')
end)
V.atFrame(64,function() pending='planned-house' end)
V.atFrame(70,function()
    local f=File(out..run..'-layout.json',FILE_WRITE)
    f:WriteString(cjson.encode({viewport={graphics:GetWidth(),graphics:GetHeight()},uiScale=UI.GetScale(),dpr=graphics:GetDPR(),controls=records}));f:Close()
    V.finish()
end)
