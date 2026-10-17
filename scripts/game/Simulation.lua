-- Pure Lua simulation: no engine dependency. All goods move on connected roads.
local D = require "game.Definitions"
local WorldMap = require "game.WorldMap"
local Construction = require "game.Construction"
local Meals = require "game.Meals"
---@class VillageSimulation
---@field roads table<string,boolean>
---@field buildings table[]
---@field jobs table[]
---@field carriers table[]
---@field stock table<string,number>
---@field produced table<string,number>
---@field population number
---@field militia number
---@field lesson number
---@field elapsed number
---@field foodClock number
---@field speed number
---@field paused boolean
---@field started boolean
---@field skipped boolean
---@field message string
---@field messageTime number
---@field raid boolean
---@field victory boolean
---@field defeat boolean
---@field enemies table[]
---@field health number
---@field combatClock number
---@field roadCount number
---@field mode string
---@field map VillageWorldMap
---@field wave number
---@field wavesDefeated number
---@field nextRaid number
---@field defended boolean
---@field timber number
---@field rock number
---@field score number
---@field buildingIndex table<string,table>
---@field menuOpen boolean?
---@field pendingRoads table[]
---@field roadPlanIndex table<string,table>
---@field builders table[]
---@field workers table<string,table>
---@field mealsServed number
local S = {}
S.__index = S
local directions = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local function key(x, y) return x .. ":" .. y end
local function copy(t) local result = {}; for k, v in pairs(t) do result[k] = v end; return result end

function S.new(mode, seed)
    local self = setmetatable({}, S)
    self:init(mode, seed)
    return self
end
function S:init(mode, seed)
    self.mode = mode == "infinite" and "infinite" or "finite"
    self.map = WorldMap.new(self.mode, seed)
    self.wave, self.wavesDefeated, self.nextRaid = 0, 0, 240
    self.defended, self.timber, self.rock, self.score = false, 320, 180, 0
    self.roads, self.buildings, self.jobs, self.carriers = {}, {}, {}, {}
    self.buildingIndex = {}
    self.pendingRoads,self.roadPlanIndex,self.builders,self.workers,self.mealsServed={},{},{},{},0
    ---@type table<string, number>
    self.stock = { wood = 72, stone = 40, grain = 0, flour = 0, food = 28 }
    if self.mode == "infinite" then self.stock.food = 48 end
    self.produced = { food = 0 }
    self.population, self.militia, self.lesson = 10, 0, 1
    self.elapsed, self.foodClock, self.speed = 0, 0, 1
    self.paused, self.started, self.skipped = false, false, false
    self.message, self.messageTime = "欢迎来到清溪里，随里正一起重建村庄。", 6
    self.raid, self.victory, self.defeat = false, false, false
    self.enemies, self.health, self.combatClock = {}, 100, 0
    self.roadCount = 0
    self:addBuilding("store", 10, 8, true)
    for x = 8, 12 do self.roads[key(x, 9)] = true end
    for i = 1, 3 do
        self.carriers[i] = { x = 10, y = 9, path = {}, index = 1, job = false, carrying = false }
    end
end
function S:notify(message)
    self.message, self.messageTime = message, 4
end
function S:terrain(x, y)
    return self.map:terrain(x, y)
end
function S:roadSiteAt(x,y) return self.roadPlanIndex[key(x,y)] end
function S:buildingAt(x, y)
    return self.buildingIndex[key(x, y)]
end
function S:path(sx, sy, tx, ty)
    if not self.roads[key(sx, sy)] or not self.roads[key(tx, ty)] then return nil end
    local queue, seen, head = { { x = sx, y = sy } }, { [key(sx, sy)] = false }, 1
    local found = false
    while head <= #queue do
        local p = queue[head]; head = head + 1
        if p.x == tx and p.y == ty then found = true; break end
        for _, d in ipairs(directions) do
            local nx, ny = p.x + d[1], p.y + d[2]
            local k = key(nx, ny)
            if self.roads[k] and seen[k] == nil then
                seen[k] = p; queue[#queue + 1] = { x = nx, y = ny }
            end
        end
    end
    if not found then return nil end
    local result, p = {}, { x = tx, y = ty }
    while p do table.insert(result, 1, p); p = seen[key(p.x, p.y)] end
    return result
end
function S:connected(b)
    if b.networkRevision ~= self.roadCount then
        b.cachedConnected = self:path(10, 9, b.x, b.y + 1) ~= nil
        b.networkRevision = self.roadCount
    end
    return b.cachedConnected
end
function S:availableWorkers()
    local used = #self.carriers + self.militia + Construction.busy(self)
    for _, b in ipairs(self.buildings) do
        if b.complete then used = used + b.workers
        elseif b.kind == "courier" then used = used + 1 end
    end
    return self.population - used
end
function S:canAfford(cost)
    for resource, amount in pairs(cost) do if (self.stock[resource] or 0) < amount then return false end end
    return true
end
function S:spend(cost)
    if not self:canAfford(cost) then return false end
    for resource, amount in pairs(cost) do self.stock[resource] = self.stock[resource] - amount end
    return true
end
function S:addBuilding(kind, x, y, complete)
    local width, height = D.footprint(kind)
    local b = { id = #self.buildings + 1, kind = kind, x = x, y = y, complete = complete or false,
        footprintW = width, footprintH = height,
        progress = 0, workers = 0, timer = 0, buffer = 0, inputs = 0, incoming = false, outgoing = false, mealStock=0,mealIncoming=false }
    self.buildings[#self.buildings + 1] = b
    for dx = 1-width, 0 do for dy = 1-height, 0 do
        self.buildingIndex[key(x+dx, y+dy)] = b
    end end
    return b
end
function S:canBuild(kind, x, y)
    if self.defeat or self.victory then return false, "本局已结束，可重新选择模式。" end
    if type(x) ~= "number" or type(y) ~= "number" or x ~= math.floor(x) or y ~= math.floor(y) then return false, "请在完整地块上营造。" end
    local def = D.buildings[kind]
    if not def then return false, "未知建筑。" end
    local width, height = D.footprint(kind)
    for dx = 1-width, 0 do for dy = 1-height, 0 do
        local tx, ty = x+dx, y+dy
        if self:terrain(tx, ty) == "fog" then return false, "此处尚未勘探，点击「拓荒」发现新区域。" end
        if self:terrain(tx, ty) ~= "grass" then return false, "建筑占地包含树林、水域或地图边界。" end
        if self:buildingAt(tx, ty) or self.roads[key(tx, ty)] or self:roadSiteAt(tx,ty) then return false, "建筑占地与现有建筑或道路重叠。" end
    end end
    -- Protect all existing doors; a door occupies the tile immediately south.
    for _, b in ipairs(self.buildings) do
        if kind ~= "road" and b.x >= x-width+1 and b.x <= x and b.y+1 >= y-height+1 and b.y+1 <= y then
            return false, "请为建筑门前保留一格道路。"
        end
    end
    if kind == "road" then
        local neighbor = false
        for _, d in ipairs(directions) do
            if self.roads[key(x+d[1],y+d[2])] or self:roadSiteAt(x+d[1],y+d[2]) then neighbor=true;break end
        end
        if not neighbor then return false, "请从现有道路向外延伸。" end
        return true, "已规划道路，空闲村民将取材到场铺设。"
    end
    if self:terrain(x, y + 1) ~= "grass" or self:buildingAt(x, y + 1) then return false, "建筑门前需要可通行的空地。" end
    if not self:connected({ x = x, y = y }) and not self:roadSiteAt(x,y+1) then return false, "门前未通路：请先在下方一格铺路连接义仓。" end
    if kind == "courier" and self:availableWorkers() < 1 then return false, "驿站需要 1 名空闲村民。" end
    if not self:canAfford(def.cost) then return false, "物资不足，先让生产链补充库存。" end
    return true, def.name .. "开始修建。"
end
function S:build(kind, x, y)
    local ok, message = self:canBuild(kind, x, y)
    if not ok then return false, message end
    if kind == "road" then
        local site={x=x,y=y,progress=0}
        self.pendingRoads[#self.pendingRoads+1],self.roadPlanIndex[key(x,y)]=site,site
        return true, message
    end
    local def = D.buildings[kind]
    self:spend(def.cost)
    local b = self:addBuilding(kind, x, y)
    return true, message, b
end
function S:count(kind)
    local n = 0; for _, b in ipairs(self.buildings) do if b.kind == kind and b.complete then n = n + 1 end end
    return n
end
function S:lessonProgress()
    local lesson = D.lessons[self.lesson]
    if not lesson then return 1, 1 end
    local value
    if lesson.kind == "road" then value = self.roadCount
    elseif lesson.kind == "food" then value = self.produced.food
    elseif lesson.kind == "militia" then value = self.militia
    elseif lesson.kind == "victory" then value = (self.victory or (self.mode == "infinite" and self.wavesDefeated > 0)) and 1 or 0
    else value = self:count(lesson.kind) end
    return math.min(value, lesson.target), lesson.target
end
function S:nextLesson()
    local value, target = self:lessonProgress()
    if value < target then return false end
    self.lesson = math.min(#D.lessons + 1, self.lesson + 1)
    return true
end
function S:train()
    if self.defeat or self.victory then return false, "本轮守村已结束。" end
    if self:count("barracks") == 0 then return false, "请先完成乡勇营。" end
    if self:availableWorkers() < 1 then return false, "空闲村民不足，请建民居或减少生产岗位。" end
    if not self:spend({ wood = 2, food = 2 }) then return false, "训练需要 2 木料和 2 口粮。" end
    self.militia = self.militia + 1
    return true, "一名乡勇已在义仓前集结。"
end
function S:staff(b, change)
    if not b.complete or not D.buildings[b.kind].output then return false end
    if change > 0 and self:availableWorkers() <= 0 then return false end
    b.workers = math.max(0, math.min(2, b.workers + change))
    return true
end
function S:startRaid()
    if self.raid or self.victory or self.defeat then return false, "守村已经开始或结束。" end
    if self.militia < 3 then return false, "先训练至少 3 名乡勇。" end
    self.raid = true
    self.wave, self.enemies = self.wave + 1, {}
    local count = self.mode == "infinite" and (3 + self.wave) or 4
    local hp = self.mode == "infinite" and (3 + math.floor(self.wave / 2)) or 3
    for i = 1, count do self.enemies[i] = { x = 15 + i * 0.4, y = 3, hp = hp } end
    return true, "山匪来袭！乡勇会自动守护义仓，可继续补充兵员。"
end
function S:expansionCost()
    return { wood = 12 + self.map.expansion * 6, food = 8 + self.map.expansion * 4 }
end
function S:expand()
    if self.mode ~= "infinite" then return false, "有限关卡边界固定，请在本地完成目标。" end
    if self.defeat then return false, "本局已结束。" end
    if not self:spend(self:expansionCost()) then return false, "拓荒物资不足，先补充木料和口粮。" end
    self.map:expand()
    self.timber, self.rock = self.timber + 160, self.rock + 100
    return true, "新区域已发现：向外拖动地图，沿路开辟新聚落。"
end
function S:repair()
    if self.health >= 100 then return false, "义仓完好，无需修缮。" end
    if self.defeat or self.victory then return false, "本局已结束。" end
    if not self:spend({ wood = 4, stone = 4 }) then return false, "修缮需要 4 木料、4 石料。" end
    self.health = math.min(100, self.health + 30)
    return true, "义仓已修复 30 点耐久。"
end
function S:enqueue(b, inbound)
    local resource = inbound and D.buildings[b.kind].input or D.buildings[b.kind].output
    if not resource then return end
    if inbound then
        if self.stock[resource] <= 0 then return end
        self.stock[resource], b.incoming = self.stock[resource] - 1, true
    else b.outgoing = true end
    self.jobs[#self.jobs + 1] = { b = b, inbound = inbound, resource = resource, amount = inbound and 1 or b.buffer }
    if not inbound then b.buffer = 0 end
end
function S:updateCarrier(c, dt, offline)
    if Meals.tick(self,c,dt,offline,c.job ~= false and c.job ~= nil) then return end
    if not c.job and #self.jobs > 0 then
        c.job = table.remove(self.jobs, 1)
        local job = c.job
        local sx, sy = 10, 9
        if not job.inbound then sx, sy = job.b.x, job.b.y + 1 end
        c.path, c.index, c.carrying = self:path(math.floor(c.x + 0.5), math.floor(c.y + 0.5), sx, sy) or {}, 1, false
    end
    if not c.job then return end
    local target = c.path[c.index]
    if target then
        local dx, dy = target.x - c.x, target.y - c.y
        local distance = math.sqrt(dx * dx + dy * dy)
        local step = dt * 2.8
        if distance <= step then c.x, c.y, c.index = target.x, target.y, c.index + 1
        else c.x, c.y = c.x + dx / distance * step, c.y + dy / distance * step end
        return
    end
    local job = c.job
    if not c.carrying then
        c.carrying = true
        local tx, ty = 10, 9
        if job.inbound then tx, ty = job.b.x, job.b.y + 1 end
        c.path, c.index = self:path(math.floor(c.x + 0.5), math.floor(c.y + 0.5), tx, ty) or {}, 1
    else
        if job.service then job.b.mealStock,job.b.mealIncoming=(job.b.mealStock or 0)+job.amount,false
        elseif job.inbound then job.b.inputs, job.b.incoming = job.b.inputs + 1, false
        else
            self.stock[job.resource] = self.stock[job.resource] + job.amount
            if job.resource == "food" then self.produced.food = self.produced.food + job.amount end
            job.b.outgoing = false
        end
        c.job, c.carrying = false, false
    end
end
function S:update(dt, offline)
    self.messageTime = math.max(0, self.messageTime - dt)
    if not self.started or self.paused or self.defeat or self.victory then return end
    dt = math.min(dt, 0.25) * (offline and 1 or self.speed)
    if not offline then self.elapsed, self.foodClock = self.elapsed + dt, self.foodClock + dt end
    if not offline and self.foodClock >= 15 then
        self.foodClock = self.foodClock - 15
        -- Tutorial relief floor prevents an unrecoverable beginner starvation spiral.
        local floorFood = self.mode == "finite" and not self.skipped and 8 or 0
        self.stock.food = math.max(floorFood, self.stock.food)
        if self.mode == "infinite" and self.stock.food == 0 then
            self.health = math.max(0, self.health - 4)
            self:notify("粮仓告急！断粮会损耗义仓耐久，请尽快打通粮食链。")
            if self.health == 0 then self.defeat = true end
        end
    end
    Construction.update(self,dt)
    Meals.prepareWorkers(self,dt,offline)
    for _, b in ipairs(self.buildings) do
        local def = D.buildings[b.kind]
        if b.complete and def.output and self:connected(b) then
            if def.input and b.inputs == 0 and not b.incoming and b.activeWorkers > 0 then self:enqueue(b, true) end
            if b.activeWorkers > 0 and b.buffer == 0 and not b.outgoing and (not def.input or b.inputs > 0) then
                b.timer = b.timer + dt * b.activeWorkers
                if b.timer >= def.period then
                    b.timer, b.buffer = 0, def.amount
                    if b.kind == "woodcutter" then
                        b.buffer = math.min(def.amount, self.timber); self.timber = self.timber - b.buffer
                    elseif b.kind == "quarry" then
                        b.buffer = math.min(def.amount, self.rock); self.rock = self.rock - b.buffer
                    end
                    if def.input then b.inputs = b.inputs - 1 end
                end
            end
            if b.buffer > 0 and not b.outgoing then self:enqueue(b, false) end
        end
    end
    for _, c in ipairs(self.carriers) do self:updateCarrier(c, dt, offline) end
    -- Offline time advances production/logistics only, never raids, hunger or records.
    if offline then return end
    self.score = math.floor(self.elapsed / 10) + self.map.expansion * 100 + self.wavesDefeated * 200 + #self.buildings * 10
    if self.mode == "infinite" and not self.raid then
        self.nextRaid = math.max(0, self.nextRaid - dt)
        if self.nextRaid == 0 then
            -- Automatic waves do not require militia: inadequate preparation can lose.
            self.wave, self.raid, self.enemies = self.wave + 1, true, {}
            for i = 1, 3 + self.wave do
                self.enemies[i] = { x = 15 + i * 0.4, y = 3, hp = 3 + math.floor(self.wave / 2) }
            end
            self:notify("第 " .. self.wave .. " 波山匪来袭，乡勇自动守村！")
        end
    end
    if self.raid then
        for _, e in ipairs(self.enemies) do
            if e.hp > 0 then
                local dx, dy = 10 - e.x, 9 - e.y
                local distance = math.sqrt(dx * dx + dy * dy)
                if distance > 1.4 then e.x, e.y = e.x + dx / distance * dt * 0.65, e.y + dy / distance * dt * 0.65 end
            end
        end
        self.combatClock = self.combatClock + dt
        if self.combatClock >= 1.2 then
            self.combatClock = 0
            local alive, near = {}, {}
            for _, e in ipairs(self.enemies) do
                if e.hp > 0 then
                    alive[#alive + 1] = e
                    if (e.x - 10)^2 + (e.y - 9)^2 < 14 then near[#near + 1] = e end
                end
            end
            if #alive == 0 then
                self.raid, self.defended = false, true
                self.wavesDefeated = self.wavesDefeated + 1
                if self.mode == "infinite" then
                    self.nextRaid = math.max(75, 180 - self.wave * 10)
                    self:notify("第 " .. self.wave .. " 波已守住。休整、修仓，再向远方拓荒。")
                else self:notify("山匪已退，完成民居与粮食链即可通关。") end
            elseif #near > 0 then
                near[1].hp = near[1].hp - math.max(0, self.militia)
                if self.militia > 0 then
                    -- Three trained villagers can win this introductory encounter.
                    if near[1].hp > 0 then self.militia = math.max(0, self.militia - 1) end
                else self.health = math.max(0, self.health - 12) end
                if self.health == 0 then self.defeat = true; self:notify("义仓失守。点击重新开始再试一次。") end
            end
        end
    end
    if self.mode == "finite" and self.defended and self:count("house") > 0 and self:count("farm") > 0
        and self:count("mill") > 0 and self:count("kitchen") > 0 and self.produced.food >= 4 then
        self.victory = true
    end
end
function S:snapshot()
    return { stock = copy(self.stock), population = self.population, lesson = self.lesson, militia = self.militia,
        mode = self.mode, seed = self.map.seed, expansion = self.map.expansion, waves = self.wavesDefeated, score = self.score }
end
return S
