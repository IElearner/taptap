local M = {}
function M.prepare(sim)
    local all={}
    local function add(a,id) a.trafficId=id;all[#all+1]=a end
    for i,a in ipairs(sim.carriers) do add(a,i) end
    for i,a in ipairs(sim.builders) do add(a,100+i) end
    for _,a in pairs(sim.workers) do add(a,10000+a.building*4+a.slot) end
    for i,a in ipairs(sim.guards or {}) do add(a,100000+i) end
    sim.trafficActors=all
end
function M.route(sim, actor, x, y)
    local path = sim:path(math.floor(actor.x + 0.5), math.floor(actor.y + 0.5), x, y)
    if not path then return false end
    actor.path, actor.index = path, 1
    return true
end
function M.step(actor, dt, speed, sim)
    local target = actor.path[actor.index]
    if not target then return true end
    local dx, dy = target.x - actor.x, target.y - actor.y
    local distance = math.sqrt(dx*dx + dy*dy)
    if distance > 0.001 then
        if math.abs(dx) > math.abs(dy) then actor.facing = dx >= 0 and "se" or "nw"
        else actor.facing = dy >= 0 and "sw" or "ne" end
    end
    local step = dt * (speed or 1.0)
    -- Road followers keep a small gap instead of walking through the same
    -- body. Opposing traffic can pass; stationary loading/meal actors do not
    -- lock the road. A stable priority only separates identical spawn points.
    if sim and distance>.001 and sim.roads[math.floor(actor.x+.5)..":"..math.floor(actor.y+.5)]
        and sim.roads[math.floor(target.x+.5)..":"..math.floor(target.y+.5)] then
        local ux,uy=dx/distance,dy/distance
        for _,other in ipairs(sim.trafficActors or {}) do
            local nextPoint=other.path and other.path[other.index]
            if other~=actor and nextPoint then
                local ox,oy=nextPoint.x-other.x,nextPoint.y-other.y
                local length=math.sqrt(ox*ox+oy*oy)
                local ahead=(other.x-actor.x)*ux+(other.y-actor.y)*uy
                if length>.001 and (ox*ux+oy*uy)/length>.65 and ahead>=-.01 and
                    (ahead>.02 or (other.trafficId or 0)<(actor.trafficId or 0)) then
                    local px,py=actor.x+ux*math.min(step,distance)-other.x,actor.y+uy*math.min(step,distance)-other.y
                    if px*px+py*py<.30*.30 then return false end
                end
            end
        end
    end
    if distance <= step then actor.x,actor.y,actor.index = target.x,target.y,actor.index+1
    else actor.x,actor.y = actor.x+dx/distance*step,actor.y+dy/distance*step end
    return actor.index > #actor.path
end
return M
