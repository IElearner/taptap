-- Deterministic frames of the playable pixel renderer, never player saves.
local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local scene,run,limit,warmup,overview,loggingClear='construction','review01',240,0,false,false
for _,arg in ipairs(GetArguments()) do
    scene=arg:match('^%-pixel%-scene=([%w_-]+)$') or scene
    run=arg:match('^%-pixel%-run=([%w_-]+)$') or run
    limit=tonumber(arg:match('^%-pixel%-frames=(%d+)$')) or limit
    warmup=tonumber(arg:match('^%-pixel%-warmup=(%d+)$')) or warmup
    if arg=='-pixel-overview' then overview=true end
    if arg=='-pixel-logging-clear' then loggingClear=true end
end
local sim,view,building,count,ready=nil,nil,nil,0,false
local directory='/workspace/artifacts/pixel-v1/development/frames-'..scene..'-'..run
function CapturePixelGameFrame()
    if not ready or count>=limit then return end
    local image=Image()
    if graphics:TakeScreenShot(image) then
        image:SavePNG(string.format('%s/%04d.png',directory,count));count=count+1
    end
end
V.atFrame(8,function()
    Game.UseStore(Store.new({now=function() return 1000 end,read=function() end,write=function() return true end}))
    local hud;sim,view,hud=Game.Inspect();hud.dismissIntro()
    sim.started,sim.skipped,sim.menuOpen,sim.population=true,true,false,40
    sim.stock.food,sim.stock.grain=300,30
    for i,a in ipairs(sim.carriers) do a.workerLook=(i-1)%2+1;a.hunger=0 end
    if scene=='village' or scene=='logging' then
        hud.root:FindById('visitDemo').props.onClick()
        sim,view,hud=Game.Inspect();hud.dismissIntro()
        -- A previously cleared foreground column exposes the real first
        -- axe cycle. This is an isolated fixture, never a visibility override.
        if scene=='logging' and loggingClear then
            for y=5,7 do sim.felledTrees['3:'..y]=true end
        end
        if scene=='logging' then view.focus(5,5) end
    elseif scene=='combat' then
        building=sim:addBuilding('barracks',14,8,true)
        sim.roads['13:9'],sim.roads['14:9']=true,true
        for i=1,3 do V.assert(sim:train(),'Recording trains a real militia with deducted supplies') end
        V.assert(sim:startRaid(),'Recording starts the real four-enemy introductory raid')
        view.focus(12,7)
    elseif scene=='construction' then
        local ok=sim:build('house',8,8);V.assert(ok,'Recording plans a connected house through the actual simulation')
        building=sim.buildings[2];view.focus(8,7.4)
    elseif scene=='kitchen' or scene=='ranch' or scene=='farm' then
        building=sim:addBuilding(scene,8,8,true);building.workers=1;building.inputs=4
        if scene=='kitchen' then
            building.mealStock=8
            sim.carriers[4]={x=10,y=9,path={},index=1,job=false,carrying=false,hunger=100,energy=20,workerLook=2}
            for _,a in ipairs(sim.carriers) do a.hunger=100 end
        end
        view.focus(7,7.4)
    end
    if scene=='kitchen' then
        sim:update(.05)
        local chef=sim.workers[building.id..':1'];if chef then chef.hunger=83 end
    end
    for i=1,warmup do sim:update(.05) end
    if overview then view.zoom(-100);view.focus(10.5,10.5) end
    sim.paused=true;hud.update()
end)
V.atFrame(12,function()
    fileSystem:CreateDir(directory)
    ready=true;SubscribeToEvent('EndAllViewsRender','CapturePixelGameFrame')
end)
for frame=13,limit+45 do
    V.atFrame(frame,function()
        if sim and count<limit then sim.paused=false;sim:update(.05);sim.paused=true end
    end)
end
V.atFrame(limit+48,function()
    V.assert(count==limit,'Every review frame came from the native playable pixel renderer')
    if building then V.assert(building.complete or (building.progress or 0)>0,'The filmed site is complete or genuinely makes construction progress') end
    V.finish()
end)
