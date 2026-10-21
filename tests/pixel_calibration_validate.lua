local UI=require 'urhox-libs/UI'
local Sim=require 'game.Simulation'
local Pixel=require 'game.PixelWorldView'
local A=require 'game.PixelAssets'
local view,sim
V.atFrame(6,function()
    sim=Sim.new('finite')
    sim.carriers[1].x,sim.carriers[1].y=9,9
    sim.carriers[2].x,sim.carriers[2].y=10,9
    sim.carriers[3].x,sim.carriers[3].y=11,9
    view=Pixel.create(sim,function() end)
    UI.SetRoot(UI.Panel{width='100%',height='100%',children={view.panel}})
end)
V.atFrame(12,function()
    local c=view.cameraState()
    V.assert(c.pixelScale==math.floor(c.pixelScale),'World magnifies each source pixel by an integer physical scale')
    V.assert(cache:Exists('art/pixel-v1/workers-walk.png'),'Original pixel worker atlas exists')
    local x,y=view.worldToScreen(10,9)
    view.setMode('house')
    view.panel.props.onPointerDown({x=x,y=y})
    V.assert(view.previewState().x==10 and view.previewState().y==9,'Pixel projection and tile picking agree at the warehouse road')
    view.setMode('inspect')
    V.assert(not view.previewState(),'Leaving construction clears the pixel ghost')
end)
V.atFrame(28,function() V.finish() end)
