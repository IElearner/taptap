-- Wheat grows on its own between four deliberate visits by an assigned worker.
local Farm = { workSeconds = 4 }
local thresholds = { 0, 1/3, 2/3, 1 }
local actions = { "plow", "water", "tend", "harvest" }
function Farm.step(b)
    return b.farmStep or ((b.timer or 0) > 0 and 1 or 0)
end
function Farm.action(b) return actions[Farm.step(b)+1] end
-- Only the outline of a connected cluster gets fence rails. This works with
-- legacy 1x2 farms as well as newly built 2x2 farms.
function Farm.exposedEdges(sim,b)
    local edges={}
    local width,height=b.footprintW or 1,b.footprintH or 1
    local sides={{dx=-1,dy=0,name="west"},{dx=0,dy=-1,name="north"},
        {dx=1,dy=0,name="east"},{dx=0,dy=1,name="south"}}
    for dx=1-width,0 do for dy=1-height,0 do
        local x,y=b.x+dx,b.y+dy
        for _,side in ipairs(sides) do
            local nx,ny=x+side.dx,y+side.dy
            local same=nx>=b.x-width+1 and nx<=b.x and ny>=b.y-height+1 and ny<=b.y
            local neighbor=sim and sim:buildingAt(nx,ny)
            if not same and not (neighbor and neighbor.kind=="farm" and neighbor.complete) then
                edges[#edges+1]={x=x,y=y,side=side.name}
            end
        end
    end end
    return edges
end
function Farm.needsWork(b, period)
    if not b.complete or (b.buffer or 0) > 0 then return false end
    local step=Farm.step(b)
    return (b.timer or 0) >= period*thresholds[step+1]
end
function Farm.stage(b, period)
    if Farm.step(b)==0 then return "seed" end
    local growth=math.min(1,(b.timer or 0)/period)
    if growth<0.16 then return "seed" end
    if growth<0.42 then return "sprout" end
    if growth<0.78 then return "green" end
    return "ripe"
end
function Farm.update(b,dt,period,workRate)
    if Farm.needsWork(b,period) then
        if workRate<=0 then return false end
        b.farmWork=(b.farmWork or 0)+dt*workRate
        if b.farmWork<Farm.workSeconds then return false end
        b.farmWork=0
        if Farm.step(b)==3 then
            b.farmStep,b.timer=0,0
            return true
        end
        b.farmStep=Farm.step(b)+1
        return false
    end
    if Farm.step(b)>0 then b.timer=math.min(period,(b.timer or 0)+dt) end
    return false
end
return Farm
