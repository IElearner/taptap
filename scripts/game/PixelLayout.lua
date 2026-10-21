-- Registered art anchors never change the retained economic road entrance.
local A=require 'game.PixelAssets'
local Cargo=require 'game.Cargo'
local L={}
function L.door(b)
    local spec=A.buildings[b.kind]
    if not spec then return b.x,b.y+.4 end
    return b.x+((spec.doorX or spec.anchorX)-spec.anchorX)/64,
        b.y+((spec.doorY or spec.anchorY)-spec.anchorY)/48
end
function L.doorWalk(b,t)
    t=math.max(0,math.min(1,t))
    local dx,dy=L.door(b)
    local horizontal=math.abs(dx-b.x)*64
    local vertical=math.abs(dy-b.y-1)*48
    local distance=t*(horizontal+vertical)
    if horizontal>0 and distance<horizontal then
        return b.x+(dx-b.x)*distance/horizontal,b.y+1
    end
    local p=vertical>0 and (distance-horizontal)/vertical or 1
    return dx,b.y+1+(dy-b.y-1)*p
end
function L.exteriorFraction(b)
    local x,y=L.door(b)
    local distance=math.abs(x-b.x)*64+math.abs(y-b.y-1)*48
    return math.min(.92,math.max(.6,distance/(72*2.8)+.05))
end
function L.ranch(b,presence)
    local spec=A.buildings[b.kind]
    -- Registered floor route: leave the gate on the right of the water
    -- trough, then reach the dry ground behind it. Never cross the basin.
    ---@type number[][]
    local points={{spec.doorX,spec.doorY},{122,184},{122,142},{80,142}}
    local lengths,total={},0
    for i=2,#points do
        local dx,dy=points[i][1]-points[i-1][1],points[i][2]-points[i-1][2]
        lengths[i]=math.sqrt(dx*dx+dy*dy);total=total+lengths[i]
    end
    local remaining=math.max(0,math.min(1,presence))*total
    for i=2,#points do
        if remaining<=lengths[i] or i==#points then
            local t=lengths[i]>0 and remaining/lengths[i] or 1
            local x=points[i-1][1]+(points[i][1]-points[i-1][1])*t
            local y=points[i-1][2]+(points[i][2]-points[i-1][2])*t
            return b.x+(x-spec.anchorX)/64,b.y+(y-spec.anchorY)/48
        end
        remaining=remaining-lengths[i]
    end
    return L.door(b)
end
function L.diningHidden(b,meal)
    if meal.phase~='enter' and meal.phase~='exit' then return false end
    local progress=meal.phase=='enter' and 1-meal.timer/2.8 or meal.timer/2.8
    return progress>=L.exteriorFraction(b)
end
function L.workDoor(b,presence,slot)
    local spec=A.buildings[b.kind]
    if require('game.WorkRoutine').visibleWorkplace(b.kind) then
        local point=spec.workPoint or spec.sawPoint or {128,174}
        local wx,wy=b.x+(point[1]-spec.anchorX)/64-(math.max(1,slot or 1)-1)*.4,b.y+(point[2]-spec.anchorY)/48
        local outside=L.exteriorFraction(b);local inside=1-outside
        if presence<.02 then return wx,wy,true,false end
        if presence<inside then return wx,wy,true,true end
        local x,y=L.doorWalk(b,1-(presence-inside)/outside)
        return x,y,false,false
    end
    if b.kind=='kitchen' then
        local window=spec.cookWindow or {206,181}
        local wx,wy=b.x+(window[1]-spec.anchorX)/64,b.y+(window[2]-spec.anchorY)/48
        local outside=L.exteriorFraction(b)
        local inside=1-outside
        if presence<.02 then return wx,wy,true,false end
        if presence<inside then return wx,wy,true,true end
        local x,y=L.doorWalk(b,1-(presence-inside)/outside)
        return x,y,false,false
    end
    if b.kind=='farm' then
        local wx,wy=b.x-((b.footprintW or 1)-1)/2,b.y-((b.footprintH or 1)-1)/2
        local dx,dy=L.door(b)
        if presence<.5 then return wx+(dx-wx)*presence*2,wy+(dy-wy)*presence*2,true,false end
        local x,y=L.doorWalk(b,2-presence*2)
        return x,y,false,false
    end
    if b.kind=='woodcutter' or b.kind=='quarry' then return b.x,b.y+1,false,false end
    local x,y=L.doorWalk(b,1-presence)
    return x,y,false
end
function L.cargoDoor(sim,a,x,y)
    local j=a.job
    if not j or (a.phase~='packing' and a.phase~='unload') then return x,y,false end
    local b=Cargo.phaseBuilding(sim,a,a.phase)
    if not b then return x,y,false end
    local t=math.max(0,math.min(1,1-(a.timer or 0)/(a.doorDuration or Cargo.doorSeconds)))
    local depth=t<.5 and t*2 or (1-t)*2
    x,y=L.doorWalk(b,depth)
    return x,y,t>.44 and t<.56
end
function L.seat(b,seat)
    local spec=A.buildings[b.kind]
    ---@type number[][]
    local spots=spec.seats or {{72,181},{104,181},{137,181},{168,181}}
    local p=spots[seat] or spots[1]
    return b.x+(p[1]-spec.anchorX)/64,b.y+(p[2]-spec.anchorY)/48
end
function L.dining(b,meal)
    local t=meal.phase=='enter' and 1-meal.timer/2.8 or meal.phase=='exit' and meal.timer/2.8 or 1
    t=math.max(0,math.min(1,t))
    local outside=L.exteriorFraction(b)
    if t<outside then return L.doorWalk(b,t/outside) end
    local dx,dy=L.door(b);local sx,sy=L.seat(b,meal.seat or 1)
    return dx+(sx-dx)*(t-outside)/(1-outside),dy+(sy-dy)*(t-outside)/(1-outside)
end
function L.construction(sim,a,record,x,y)
    local j=a.job
    if j and j.kind=='road' then record.site=nil;record.road=j
    elseif j and j.kind=='building' then record.site=sim.buildings[j.building];record.road=nil end
    if record.road then
        local road=record.road
        local roadSite=a.phase=='unload' or a.phase=='ready' or a.phase=='hammer' or a.phase=='recover'
        local roadTravel=a.phase=='toSite' or a.phase=='return'
        if roadSite or roadTravel then
            local px=road.x+(road.doorX-road.x)*22/64
            local py=road.y+(road.doorY-road.y)*22/48
            local distance=math.sqrt((x-road.doorX)^2+(y-road.doorY)^2)
            local blend=roadSite and 1 or math.max(0,1-distance/.9)
            return x+(px-road.doorX)*blend,y+(py-road.doorY)*blend
        end
        return x,y
    end
    local b=record.site
    if not b then return x,y end
    local phase=a.phase
    local onSite=phase=='approach' or phase=='unload' or phase=='ready' or phase=='hammer' or
        phase=='recover' or phase=='waitSite' or phase=='waitMaterials' or phase=='awaitStage' or phase=='leaveSite' or phase=='refillExit'
    local travel=phase=='toSite' or phase=='return' or phase=='collect' and record.leavingSite
    if not onSite and not travel then record.leavingSite=false;return x,y end
    if onSite then record.leavingSite=true end
    local w,h=b.footprintW or 1,b.footprintH or 1
    -- Independently registered visible stone-base bounds, measured in the
    -- original construction PNGs. Logical path tiles are not tool targets.
    local bounds=(A.buildings[b.kind] or {}).workBounds or (w==2 and {100,169,219,199} or {36,153,219,199})
    local spec=A.buildings[b.kind]
    local u=(x-(b.x-w))/(w+1)
    local v=(y-(b.y-h))/(h+1)
    local mx=b.x+(bounds[1]-8+(bounds[3]-bounds[1]+16)*u-spec.anchorX)/64
    local my=b.y+(bounds[2]+(bounds[4]+12-bounds[2])*v-spec.anchorY)/48
    local blend=1
    if travel then
        local distance=math.sqrt((x-b.x)^2+(y-b.y-1)^2)
        blend=math.max(0,1-distance/.9)
    end
    return x+(mx-x)*blend,y+(my-y)*blend
end
function L.logging(a,x,y)
    if not a.treeX or not a.treeY then return x,y end
    local phase=a.woodPhase
    if phase~='toTree' and phase~='chop' and phase~='felling' and phase~='gather' and phase~='toCamp' then return x,y end
    local dx,dy=a.treeX-.36,a.treeY+.20
    local distance=math.sqrt((x-dx)^2+(y-dy)^2)
    local blend=(phase=='toTree' or phase=='toCamp') and math.max(0,1-distance/.8) or 1
    -- Tool contact is the trunk's independently registered lower left edge.
    return x+.16*blend,y-.19*blend
end
return L
