-- Wheat grows on its own between four short visits by an assigned worker.
local Farm = { workSeconds = 0.9 }
local thresholds = { 0, 1/3, 2/3, 1 }
function Farm.step(b)
    return b.farmStep or ((b.timer or 0) > 0 and 1 or 0)
end
function Farm.needsWork(b, period)
    if not b.complete or (b.buffer or 0) > 0 or b.outgoing then return false end
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
