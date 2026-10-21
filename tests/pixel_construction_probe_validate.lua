local Game=require 'network.Standalone'
local Store=require 'game.PixelSaveStore'
local sim,view
V.atFrame(8,function()
    Game.UseStore(Store.new({now=function() return 1000 end,read=function() end,write=function() return true end}))
    local hud;sim,view,hud=Game.Inspect();hud.dismissIntro()
    sim.started,sim.skipped,sim.population,sim.menuOpen=true,true,10,false
    V.assert(sim:build('house',8,8),'Probe begins an affordable connected house with original stock')
    for i=1,500 do sim:update(.05) end
    sim.paused=true;view.focus(7.5,7.4);hud.update()
    local points=require('game.ConstructionSites').ensure(sim.buildings[2])
    V.assert(#points>0 and sim.buildings[2].progress>0,'Probe shows real construction point progress')
end)
V.atFrame(30,function() V.finish() end)
