-- New ordinary workers receive one of two random looks at creation. Legacy
-- workers use a stable index fallback; drawing never changes their identity.
local C = {}
---@class VillagePersonProfile
---@field id? string
---@field color number[]
---@field hat string
---@field age? string
---@field gender string
---@type VillagePersonProfile[]
C.civilians = {
    { id = "blue-man", color = { 78, 108, 135 }, hat = "straw", age = "adult", gender = "male" },
    { id = "ochre-woman", color = { 143, 91, 62 }, hat = "scarf", age = "adult", gender = "female" },
}
local specialists = {
    woodcutter = {id="lumberjack",color={83,107,68},hat="scarf",age="adult",gender="male"},
    ranch = {id="herder",color={152,125,84},hat="cap",age="adult",gender="male"},
    kitchen = { id = "chef", color = { 74, 91, 116 }, hat = "scarf", age = "adult", gender = "female" },
    butcher = { id = "butcher", color = { 132, 79, 57 }, hat = "cap", age = "adult", gender = "male" },
}
function C.carrier(index, carrying,actor)
    local profile = C.civilians[actor and actor.workerLook or (index - 1) % #C.civilians + 1]
    return (carrying and "loaded-" or "civilian-") .. profile.id, profile
end
function C.worker(building, index,actor)
    if not building or not building.complete or index > building.workers or index < 1 then return nil end
    local specialist = specialists[building.kind]
    if specialist then return "occupation-" .. specialist.id, specialist end
    -- Carrying, construction and ordinary production are assignments of the
    -- same civilian profession. A stable building/slot seed keeps each face.
    return C.carrier((building.id or 1) + index - 1, false,actor)
end
function C.militia(index)
    if index % 2 == 0 then
        return "occupation-guard", { color = { 143, 66, 55 }, hat = "scarf", gender = "female" }
    end
    return "militia", { color = { 125, 64, 53 }, hat = "cap", gender = "male" }
end
-- A pose is selected from simulation time, so pausing and restoring a save do
-- not require storing any visual animation state in the world data.
function C.sprite(role, direction, walking, action, clock, phase)
    if action=="eat" then
        local civilian=role:match("^civilian%-(.+)$") or role:match("^loaded%-(.+)$")
        if civilian then return "person-eating-" .. civilian .. "-" .. (math.floor((clock or 0)*1.5+(phase or 0)*0.3)%2+1) end
        local occupation=role:match("^occupation%-(.+)$")
        if occupation=="chef" or occupation=="butcher" or occupation=="guard" then
            return "person-eating-" .. occupation .. "-" .. (math.floor((clock or 0)*1.5+(phase or 0)*0.3)%2+1)
        end
        if role=="militia" then return "person-eating-militia-" .. (math.floor((clock or 0)*1.5+(phase or 0)*0.3)%2+1) end
    end
    local base = "person-" .. role .. "-" .. (direction or "se")
    local offset = (phase or 0) * 0.7
    if action == "hammer" then
        return base .. (math.floor((clock or 0) * 4 + offset) % 2 == 0 and "-hammer-up" or "-hammer-down")
    end
    if (action=="plow" or action=="water" or action=="tend" or action=="harvest") and
        math.floor((clock or 0)*2.4+offset)%2==1 then return base .. "-stride" end
    if action == "farm" and math.floor((clock or 0)*3+offset)%2==1 then return base .. "-stride" end
    if walking and math.floor((clock or 0) * 6 + offset) % 2 == 1 then return base .. "-stride" end
    return base
end
return C
