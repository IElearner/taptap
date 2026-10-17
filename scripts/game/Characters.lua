-- Presentation only. Identity derives from stable carrier order / building coordinates,
-- so loading a save or changing camera never randomizes a villager's appearance.
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
    { id = "ochre-woman", color = { 174, 126, 64 }, hat = "scarf", age = "adult", gender = "female" },
    { id = "grey-elder", color = { 124, 121, 108 }, hat = "cap", age = "elder", gender = "male" },
    { id = "green-woman", color = { 88, 128, 91 }, hat = "braid", age = "young-adult", gender = "female" },
}
local occupations = {
    farm = { id = "farmer", color = { 171, 139, 72 }, hat = "straw", gender = "female" },
    mill = { id = "artisan", color = { 119, 131, 146 }, hat = "cap", age = "elder", gender = "male" },
    kitchen = { id = "artisan", color = { 119, 131, 146 }, hat = "cap", age = "elder", gender = "male" },
    woodcutter = { id = "logger", color = { 133, 100, 67 }, hat = "scarf", gender = "male" },
    quarry = C.civilians[3],
}
function C.carrier(index, carrying)
    local profile = C.civilians[(index - 1) % #C.civilians + 1]
    return (carrying and "loaded-" or "civilian-") .. profile.id, profile
end
function C.worker(building, index)
    if not building.complete or index > building.workers or index < 1 then return nil end
    local profile = occupations[building.kind]
    if not profile then return nil end
    local role = building.kind == "quarry" and "civilian-grey-elder" or ("occupation-" .. profile.id)
    return role, profile
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
    local base = "person-" .. role .. "-" .. (direction or "se")
    local offset = (phase or 0) * 0.7
    if action == "hammer" then
        return base .. (math.floor((clock or 0) * 4 + offset) % 2 == 0 and "-hammer-up" or "-hammer-down")
    end
    if walking and math.floor((clock or 0) * 6 + offset) % 2 == 1 then return base .. "-stride" end
    return base
end
return C
