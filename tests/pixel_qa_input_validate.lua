-- Independent native UI touch regression. No player save files or product state.
-- Scaffold: tests/pixel_calibration_validate.lua; events: UI/Core/UI.lua.
local UI=require 'urhox-libs/UI'
local Sim=require 'game.Simulation'
local Pixel=require 'game.PixelWorldView'
local view
local calls={}
local function begin(id,x,y) UI.HandleTouchBegin(id,x*UI.GetScale(),y*UI.GetScale()) end
local function move(id,x,y) UI.HandleTouchMove(id,x*UI.GetScale(),y*UI.GetScale()) end
local function finish(id,x,y) UI.HandleTouchEnd(id,x*UI.GetScale(),y*UI.GetScale()) end
local function count() return #calls end
local function worldAt(x,y)
    local ox,oy=view.worldToScreen(10,9)
    local z=view.cameraState().zoom
    return (x-ox)/z,(y-oy)/z
end
V.atFrame(6,function()
    view=Pixel.create(Sim.new('finite'),function(x,y) calls[#calls+1]={x=x,y=y} end)
    UI.SetRoot(UI.Panel{width='100%',height='100%',children={
        UI.Panel{position='absolute',left=80,top=50,right=40,bottom=40,children={view.panel}}
    }})
end)
V.atFrame(12,function()
    local l=view.panel:GetAbsoluteLayout()
    V.assert(l.x>0 and l.y>0,'Independent input fixture uses a nonzero panel origin')
    local x,y=view.worldToScreen(10,9)
    view.setMode('house')
    begin(101,x,y)
    local g=view.previewState()
    V.assert(g and g.x==10 and g.y==9,'Actual touch preview picks the projected tile in an offset panel')
    UI.HandleTouchCancel(101)
    -- A canceled drag (e.g. incoming call) must never place a building.
    local before=count()
    begin(102,x-25,y)
    move(102,x+25,y)
    UI.HandleTouchCancel(102)
    V.assert(count()==before,'Canceling an actual construction drag never commits placement')
    V.assert(not view.previewState(),'Canceling construction clears the canceled ghost')
    -- A normal release is a single explicit placement, not duplicate pan/tap.
    begin(103,x-25,y)
    move(103,x+25,y)
    finish(103,x+25,y)
    V.assert(count()==before+1,'Releasing an actual construction drag commits exactly once')
    local last=calls[#calls]
    V.assert(last and last.x==10 and last.y==9,'Released construction uses the same tile as its visual projection')
    view.setMode('inspect')
    before=count()
    local camera=view.cameraState()
    begin(104,x,y);move(104,x+30,y+15);finish(104,x+30,y+15)
    V.assert(count()==before,'Inspect pan does not trigger a tile tap')
    V.assert(view.cameraState().x~=camera.x,'Actual single-finger inspect input pans the map')
    view.home()
    view.setMode('house')
    x,y=view.worldToScreen(10.5,9)
    local wx,wy=worldAt(x,y)
    local oldScale=view.cameraState().pixelScale
    before=count()
    begin(105,x-30,y);begin(106,x+30,y)
    move(105,x-60,y);move(106,x+60,y)
    local after=view.cameraState()
    local qx,qy=worldAt(x,y)
    V.assert(after.pixelScale==math.floor(after.pixelScale) and after.pixelScale>oldScale,'Actual spread increases an integer physical pixel scale')
    V.assert(math.abs(wx-qx)<.001 and math.abs(wy-qy)<.001,'Offset-panel pinch preserves the world point under the fingers: '..wx..','..wy..' -> '..qx..','..qy..' scale '..oldScale..' -> '..after.pixelScale)
    finish(105,x-60,y);finish(106,x+60,y)
    V.assert(count()==before and not view.previewState(),'Releasing both pinch fingers neither builds nor leaves a ghost')
    view.setMode('inspect')
    camera=view.cameraState()
    begin(107,x,y);move(107,x+30,y);finish(107,x+30,y)
    V.assert(view.cameraState().x~=camera.x,'Single-finger pan works after releasing a pinch')
    V.assert(count()==before,'Pan after pinch still does not select or build')
end)
V.atFrame(28,function() V.finish() end)
