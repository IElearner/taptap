local M = {}
function M.route(sim, actor, x, y)
    local path = sim:path(math.floor(actor.x + 0.5), math.floor(actor.y + 0.5), x, y)
    if not path then return false end
    actor.path, actor.index = path, 1
    return true
end
function M.step(actor, dt, speed)
    local target = actor.path[actor.index]
    if not target then return true end
    local dx, dy = target.x - actor.x, target.y - actor.y
    local distance = math.sqrt(dx*dx + dy*dy)
    if distance > 0.001 then
        if math.abs(dx) > math.abs(dy) then actor.facing = dx >= 0 and "se" or "nw"
        else actor.facing = dy >= 0 and "sw" or "ne" end
    end
    local step = dt * (speed or 2.8)
    if distance <= step then actor.x,actor.y,actor.index = target.x,target.y,actor.index+1
    else actor.x,actor.y = actor.x+dx/distance*step,actor.y+dy/distance*step end
    return actor.index > #actor.path
end
return M
