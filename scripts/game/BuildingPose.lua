-- Small, stable turns of the architecture, independent of the camera and of
-- the grid reserved for roads/logistics. Interior interactions use this same
-- transform so furniture, occupants and doorways cannot drift apart.
local Pose={}
local sizes={house={3,2},kitchen={3,2},mill={2,3},woodcutter={3,2},quarry={3,2},barracks={3,3},butcher={3,2},ranch={3,2}}
---@type number[]
local angles={-4,-2,2,4}
---@param b table
---@return number
function Pose.yaw(b)
    if not sizes[b.kind] or (b.footprintW or 1)<2 or (b.footprintH or 1)<2 then return 0 end
    local hash=b.x*17+b.y*31
    for i=1,#b.kind do hash=hash+b.kind:byte(i) end
    return angles[hash%#angles+1] or -5
end
function Pose.fit(b)
    local a=math.rad(Pose.yaw(b))
    local c,s=math.abs(math.cos(a)),math.abs(math.sin(a))
    local w,h=b.footprintW or 1,b.footprintH or 1
    -- A narrow eave margin is allowed, while long rectangular roofs are kept
    -- from expanding arbitrarily into the neighbouring reserved plots.
    return math.min(1,(w+.40)/(w*c+h*s),(h+.40)/(h*c+w*s))
end
function Pose.point(b,x,y)
    local canonical=sizes[b.kind] or {b.footprintW or 1,b.footprintH or 1}
    local scale=Pose.fit(b)
    x,y=x*(b.footprintW or 1)/canonical[1]*scale,y*(b.footprintH or 1)/canonical[2]*scale
    local a=math.rad(Pose.yaw(b));local c,s=math.cos(a),math.sin(a)
    return b.x-((b.footprintW or 1)-1)*.5+x*c-y*s,
        b.y-((b.footprintH or 1)-1)*.5+x*s+y*c
end
function Pose.workTarget(b,j)
    local directions={south={0,-1},north={0,1},west={1,0},east={-1,0}}
    local d=directions[j.side] or {0,0}
    local x=j.workX+d[1]*.65
    local y=j.workY+d[2]*.65
    -- Work positions are already in the current save's footprint units.
    local cx=b.x-((b.footprintW or 1)-1)*.5
    local cy=b.y-((b.footprintH or 1)-1)*.5
    local a=math.rad(Pose.yaw(b));local c,s=math.cos(a),math.sin(a)
    x,y=(x-cx)*Pose.fit(b),(y-cy)*Pose.fit(b)
    return cx+x*c-y*s,cy+x*s+y*c
end
return Pose
