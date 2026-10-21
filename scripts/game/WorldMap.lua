-- Coordinate-generated terrain: deterministic across visits, no world-size allocation.
---@class VillageWorldMap
---@field mode string
---@field seed number
---@field expansion number
---@field worldSize number
local Map = {}
Map.__index = Map
---@param mode string?
---@param seed number?
function Map.new(mode, seed)
    local self = setmetatable({}, Map)
    self:init(mode, seed)
    return self
end
function Map:init(mode, seed)
    self.mode, self.seed, self.expansion = mode or "finite", seed or 7319, 0
    self.worldSize=self.mode=="finite" and 30 or 22
end
function Map:bounds()
    local margin = self.mode == "infinite" and self.expansion * 8 or 0
    return 1 - margin, self.worldSize + margin
end
function Map:terrain(x, y)
    local low, high = self:bounds()
    if x < low or y < low or x > high or y > high then
        return self.mode == "infinite" and "fog" or "edge"
    end
    -- Shared beginner valley: ensures the original tutorial is always solvable.
    if x >= 1 and y >= 1 and x <= 22 and y <= 22 then
        local riverbank=18+math.floor((math.sin(y*0.65)+1)*0.8)
        if x >= riverbank and y >= 4 and y <= 17 then return "water" end
        if (x <= 3 and y <= 9) or (y >= 18 and x <= 13) or (y <= 4 and x >= 11 and x <= 16)
            or (x >= 4 and x <= 6 and y >= 13 and y <= 17)
            or (x >= 12 and x <= 14 and y >= 14 and y <= 17) then return "forest" end
        return "grass"
    end
    -- The road corridors guarantee traversable entrances into every frontier region.
    if x % 8 == 0 or y % 8 == 0 or x == 10 or y == 9 then return "grass" end
    local regionX, regionY = math.floor(x / 5), math.floor(y / 5)
    local h = (regionX * 7387 + regionY * 1933 + self.seed * 97) % 101
    if h < 15 then return "water" end
    if h < 37 then return "forest" end
    return "grass"
end
function Map:expand()
    if self.mode ~= "infinite" then return false end
    self.expansion = self.expansion + 1
    return true
end
return Map
