-- Presentation of indoor occupations is driven by the same simulation clock
-- as production. Returning from a break takes time before work resumes.
local D=require "game.Definitions"
local R={doorSeconds=2.8}
function R.indoor(kind) return (D.buildings[kind].profession~=nil and kind~='forester' and kind~='woodcutter') or kind=='kitchen' or kind=='butcher' or kind=='mill' or kind=='sawmill' or kind=='bakery' end
function R.visibleWorkplace(kind)return require('game.WorkBreaks').kinds[kind]or D.buildings[kind].profession~=nil and kind~='forester' and kind~='woodcutter' end
function R.update(a,kind,working,dt)
    if a.life or a.lean or a.breaks or a.workshopOutdoor then return end
    if not R.indoor(kind) or a.meal then return end
    local p=a.workPresence or 0
    a.workPresence=math.max(0,math.min(1,p+(working and -1 or 1)*dt/R.doorSeconds))
end
function R.atWork(a,kind)
    if a.workshopOutdoor then return not a.meal and not a.workLoad and a.breaks and a.breaks.phase=='work'or false end
    if a.lean or a.breaks or(a.workFinishLeft or 0)>0 then return false end
    if a.life then return require('game.WorkLife').working(a) end
    return not R.indoor(kind) or (a.workPresence or 0)<=.00001
end
return R
