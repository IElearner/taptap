-- Same real first-house workload as motion03, without screenshots or trace IO.
local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local sim,house,updates
V.atFrame(8,function()
    Game.UseStore(Store.new({now=function() return 1000 end,read=function() end,write=function() return true end}))
    local view,hud;sim,view,hud=Game.Inspect();hud.dismissIntro()
    sim.skipped=true;hud.update(1)
    local ok=sim:build('house',8,8)
    V.assert(ok,'Load-only run starts the same real unboosted first house')
    house=sim:buildingAt(8,8);view.focus(8,7.4)
    updates=0;sim.paused=true
end)
for frame=13,812 do
    V.atFrame(frame,function()
        sim.paused=false;sim:update(.05);sim.paused=true;updates=updates+1
    end)
end
V.atFrame(818,function()
    V.assert(updates==800 and house.complete and sim.population==14,
        'Eight hundred native-rendered steps complete the same house once without screenshot or trace writes')
    V.finish()
end)
