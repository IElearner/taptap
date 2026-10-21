-- Feedback follows actual simulation HP changes. This is the existing ranged
-- village defence; it does not invent melee reach or alter combat rules.
local Combat={}
function Combat.update(sim,history)
    local hits={}
    for i,e in ipairs(sim.enemies or {}) do
        local old=history[i] or {hp=e.hp}
        if e.hp<old.hp then old.at=sim.elapsed;old.damage=old.hp-e.hp end
        old.hp=e.hp;history[i]=old
        if old.at and sim.elapsed-old.at<.45 then
            hits[#hits+1]={x=e.x,y=e.y,age=sim.elapsed-old.at,damage=old.damage}
        end
    end
    return hits
end
return Combat
