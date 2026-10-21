local A=require 'game.PixelAssets'
local L=require 'game.PixelLayout'
local Ranch=require 'game.RanchCycle'
local Sim=require 'game.Simulation'
local Actors=require 'game.PixelActors'
V.atFrame(8,function()
    A.loadCatalog()
    local s=Sim.new('finite')
    local b=s:addBuilding('ranch',8,8,true);b.workers=1
    local spec=A.buildings.ranch
    local function source(x,y) return (x-b.x)*64+spec.anchorX,(y-b.y)*48+spec.anchorY end
    local x,y=source(L.ranch(b,1))
    V.assert(math.abs(x-80)<.01 and math.abs(y-142)<.01,'Feeding caretaker stands on registered dry floor behind the actual water trough')
    local safe,smooth=true,true
    local lastX,lastY
    for step=0,1000 do
        local p=step/1000
        x,y=source(L.ranch(b,p))
        -- Whole visible body, including shoes, must avoid the source trough.
        if x+7>53 and x-7<108 and y+2>153 and y-24<171 then safe=false end
        if lastX and math.sqrt((x-lastX)^2+(y-lastY)^2)>72*Ranch.doorSeconds/1000+.001 then smooth=false end
        lastX,lastY=x,y
    end
    V.assert(safe,'The complete route goes around the right side and behind the basin without standing in water')
    V.assert(smooth,'The registered route is continuous and stays within walking speed for the real excursion duration')
    local reverse=true
    for step=0,20 do
        local p=step/20
        b.ranchPhase='exit';b.ranchClock=Ranch.doorSeconds*(1-p)
        local ax,ay=L.ranch(b,Ranch.presence(b))
        b.ranchPhase='return';b.ranchClock=Ranch.doorSeconds*p
        local bx,by=L.ranch(b,Ranch.presence(b))
        if math.abs(ax-bx)+math.abs(ay-by)>.00001 then reverse=false end
    end
    V.assert(reverse,'Leaving the trough reverses the same safe route instead of cutting through the water')
    b.ranchPhase='feed';b.feedClock=2
    local worker={building=b.id,slot=1,x=8,y=9,workerLook=1}
    s.workers={caretaker=worker}
    local shown
    for _,p in ipairs(Actors.collect(s,{})) do if p.key=='workercaretaker' then shown=p end end
    V.assert(shown and math.abs(shown.x-(b.x+(80-spec.anchorX)/64))<.001 and shown.layerBuilding==b,
        'The real actor projection uses the dry feeding position in the pen layer')
    V.finish()
end)
