-- Exact simulation in bounded per-frame batches. No optimistic resource multiplier.
local D = require "game.Definitions"
---@class VillageOffline
---@field sim VillageSimulation
---@field seconds number
---@field remaining number
---@field before table<string,number>
---@field gains table<string,number>
local Offline = {}
Offline.__index = Offline
Offline.CAP_SECONDS = 8 * 60 * 60
function Offline.new(sim, savedAt, now, enabled)
    local self = setmetatable({}, Offline)
    self:init(sim, savedAt, now, enabled)
    return self
end
function Offline:init(sim, savedAt, now, enabled)
    self.sim = sim
    self.seconds = math.min(Offline.CAP_SECONDS, math.max(0, math.floor(now - savedAt)))
    if enabled == false or not sim.started or sim.paused or sim.victory or sim.defeat then self.seconds = 0 end
    self.remaining = self.seconds
    self.before, self.gains = {}, {}
    for _, resource in ipairs(D.goods) do self.before[resource] = sim.stock[resource] end
end
function Offline:step(budget)
    for _ = 1, budget or 512 do
        if self.remaining <= 0 then break end
        local dt = math.min(0.25, self.remaining)
        self.sim:update(dt, true)
        self.remaining = self.remaining - dt
    end
    if self.remaining <= 0 then
        for _, resource in ipairs(D.goods) do self.gains[resource] = self.sim.stock[resource] - self.before[resource] end
        return true
    end
    return false
end
function Offline:summary()
    if self.seconds == 0 then return "没有待结算的离线生产。" end
    local parts = {}
    for _, r in ipairs(D.goods) do
        local amount = self.gains[r] or 0
        if amount ~= 0 then parts[#parts + 1] = D.names[r] .. (amount > 0 and "+" or "") .. amount end
    end
    return "离线 " .. math.floor(self.seconds / 60) .. " 分钟：" .. (#parts > 0 and table.concat(parts, " / ") or "生产链暂未产出。")
end
return Offline
