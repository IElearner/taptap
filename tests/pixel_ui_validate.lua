-- Real HUD fixtures; storage stays in memory and no player/cloud data is read.
local UI=require "urhox-libs/UI"
local Game=require "network.Standalone"
local Theme=require "game.PixelTheme"
local case=os.getenv("PIXEL_UI_CASE") or "play"
local sim,hud
local writes={}
local function click(id)
    local widget=hud.root:FindById(id)
    V.assert(widget~=nil,"Retained control: "..id)
    if widget then widget.props.onClick() end
    sim,_,hud=Game.Inspect()
end
V.atFrame(6,function()
    Game.UseStore(require("game.PixelSaveStore").new({now=function() return 1000 end,read=function() return nil end,
        write=function(key,value) writes[key]=value;return true end}),true)
    sim,_,hud=Game.Inspect()
    V.assert(cache:Exists(Theme.fonts[1].weights.normal),"Pixel body font is packaged")
    V.assert(cache:Exists(Theme.fonts[1].weights.bold),"Pixel bold font is packaged")
    V.assert(hud.root:FindById("loginScreen"):IsVisible(),"Authentication screen starts visible")
end)
V.atFrame(8,function()
    if case=="login" then return end
    click("loginGuest")
    V.assert(not hud.root:FindById("loginScreen"):IsVisible(),"Guest uses the real authentication callback")
    if case=="mode" then return end
    click("enterVillage");hud.update(1)
    V.assert(sim.started and not sim.menuOpen,"Real entry action starts the village")
    sim.paused=true
    if case~="tutorial" then click("mentorSkip");hud.update(1) end
    if case=="build" then click("open_build");hud.update(1)
    elseif case=="system" then click("open_system");hud.update(1) end
end)
V.atFrame(20,function()
    UI.Layout()
    local dpr=graphics:GetDPR()
    local ids=case=="login" and {"loginTapTap","loginGuest"} or case=="mode" and {"modeFinite","modeInfinite","enterVillage"}
        or case=="tutorial" and {"mentorGo","mentorSkip","open_build"} or case=="build" and {"build_road","build_house","open_build"}
        or {"open_build","open_village","open_army","open_system"}
    for _,id in ipairs(ids) do
        local b=hud.root:FindById(id);local l=b:GetAbsoluteLayout()
        V.assert(l.w*UI.GetScale()/dpr>=43.9 and l.h*UI.GetScale()/dpr>=43.9,id.." meets 44 CSS touch size")
    end
    V.assert(Theme.componentDefaults.borderRadius==0 and Theme.components.Button.borderRadius==0,"Resolved theme uses hard pixel corners")
    if case~="login" and case~="mode" then
        for _,id in ipairs({"hudVersion","stock_wood","stock_stone","stock_food","population"}) do
            local item=hud.root:FindById(id)
            V.assert(item~=nil and item:GetAbsoluteLayout().w>20,id.." retains visible text width")
        end
    end
    if case=="login" then V.assert(not hud.root:FindById("modeScreen"):IsVisible(),"Mode chooser does not show behind login") end
    V.assert(hud.root:FindById("modeScreen")~=nil and hud.root:FindById("saveGame")~=nil,"Menus and save controls remain available")
    if case=="build" then V.assert(hud.root:FindById("drawer_build"):IsVisible(),"Build drawer opens through the real button") end
    if case=="tutorial" then V.assert(hud.root:FindById("mentorDialogue"):IsVisible(),"Opening lesson is visible without a portrait dependency") end
end)
