-- Explicit versioned save format. Jobs reference building IDs instead of table identity.
local Sim = require "game.Simulation"
local D = require "game.Definitions"
local Data = { VERSION = 1 }
local fields = { "population", "militia", "lesson", "elapsed", "foodClock", "speed", "paused", "started", "skipped",
    "raid", "victory", "defeat", "health", "combatClock", "roadCount", "wave", "wavesDefeated", "nextRaid", "defended", "timber", "rock", "score" }
local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k, v in pairs(value) do result[k] = clone(v) end; return result
end
local function number(value, low, high)
    return type(value) == "number" and value == value and value >= low and value <= high
end
local function jobData(job)
    if not job then return false end
    return { building = job.b.id, inbound = job.inbound, resource = job.resource, amount = job.amount }
end
function Data.capture(s, savedAt, revision, idleEnabled)
    local world = { stock = clone(s.stock), produced = clone(s.produced), roads = clone(s.roads),
        buildings = {}, jobs = {}, carriers = {}, enemies = clone(s.enemies) }
    for _, name in ipairs(fields) do world[name] = s[name] end
    for _, b in ipairs(s.buildings) do
        local entry = clone(b); entry.cachedConnected, entry.networkRevision = nil, nil
        world.buildings[#world.buildings + 1] = entry
    end
    for _, job in ipairs(s.jobs) do world.jobs[#world.jobs + 1] = jobData(job) end
    for _, c in ipairs(s.carriers) do
        world.carriers[#world.carriers + 1] = { x = c.x, y = c.y, path = clone(c.path), index = c.index,
            job = jobData(c.job), carrying = c.carrying }
    end
    return { version = Data.VERSION, mode = s.mode, seed = s.map.seed, expansion = s.map.expansion,
        savedAt = savedAt, revision = revision or 1, idleEnabled = idleEnabled ~= false, world = world }
end
local function restoreUnsafe(data, mode)
    assert(type(data) == "table" and data.version == Data.VERSION, "version")
    assert(data.mode == mode and (mode == "finite" or mode == "infinite"), "mode")
    assert(number(data.savedAt, 0, 4102444800) and number(data.revision, 1, 1e12), "timestamp")
    assert(number(data.seed, -1e9, 1e9) and number(data.expansion, 0, 1e6) and data.expansion % 1 == 0, "map")
    assert(type(data.idleEnabled) == "boolean" and (mode == "infinite" or data.expansion == 0), "options")
    local w = data.world
    assert(type(w) == "table" and type(w.stock) == "table" and type(w.produced) == "table", "world")
    for _, r in ipairs(D.goods) do assert(number(w.stock[r], 0, 1e12), "stock") end
    assert(number(w.produced.food, 0, 1e12), "production")
    for _, name in ipairs(fields) do
        local value = w[name]
        if name == "paused" or name == "started" or name == "skipped" or name == "raid" or name == "victory"
            or name == "defeat" or name == "defended" then assert(type(value) == "boolean", name)
        else assert(number(value, 0, 1e12), name) end
    end
    assert(w.health <= 100 and (w.speed == 1 or w.speed == 2) and w.lesson >= 1 and w.lesson <= #D.lessons + 1, "state")
    assert(type(w.roads) == "table" and type(w.buildings) == "table" and #w.buildings >= 1 and #w.buildings <= 10000, "buildings")
    local roads = 0
    for k, value in pairs(w.roads) do
        assert(type(k) == "string" and k:match("^%-?%d+:%-?%d+$") and value == true, "roads")
        roads = roads + 1; assert(roads <= 100000, "road limit")
    end
    assert(type(w.jobs) == "table" and #w.jobs <= 20000 and type(w.carriers) == "table" and #w.carriers >= 3 and #w.carriers <= 10000, "logistics")
    local s = Sim.new(mode, data.seed)
    s.map.expansion = data.expansion
    for _, name in ipairs(fields) do s[name] = w[name] end
    s.stock, s.produced, s.roads = clone(w.stock), clone(w.produced), clone(w.roads)
    s.buildings, s.buildingIndex, s.jobs, s.carriers = {}, {}, {}, {}
    for i, b in ipairs(w.buildings) do
        assert(type(b) == "table" and b.id == i and D.buildings[b.kind] and b.kind ~= "road", "building ID")
        assert(number(b.x, -1e9, 1e9) and b.x % 1 == 0 and number(b.y, -1e9, 1e9) and b.y % 1 == 0, "position")
        assert(type(b.complete) == "boolean" and number(b.progress, 0, 1) and number(b.workers, 0, 2), "building state")
        assert(number(b.timer, 0, 1e12) and number(b.buffer, 0, 1e12) and number(b.inputs, 0, 1e12), "buffer")
        assert(type(b.incoming) == "boolean" and type(b.outgoing) == "boolean", "transit flags")
        assert(not s:buildingAt(b.x, b.y), "duplicate position")
        local restored = clone(b); restored.cachedConnected, restored.networkRevision = nil, nil
        s.buildings[i], s.buildingIndex[b.x .. ":" .. b.y] = restored, restored
    end
    assert(s.buildings[1].kind == "store" and s.buildings[1].x == 10 and s.buildings[1].y == 8, "warehouse")
    local function restoreJob(job)
        if job == false then return false end
        assert(type(job) == "table" and s.buildings[job.building], "job building")
        assert(type(job.inbound) == "boolean" and D.names[job.resource] and number(job.amount, 1, 1e12), "job")
        return { b = s.buildings[job.building], inbound = job.inbound, resource = job.resource, amount = job.amount }
    end
    for _, job in ipairs(w.jobs) do s.jobs[#s.jobs + 1] = restoreJob(job) end
    for _, c in ipairs(w.carriers) do
        assert(number(c.x, -1e9, 1e9) and number(c.y, -1e9, 1e9) and number(c.index, 1, 100001), "carrier")
        assert(type(c.carrying) == "boolean" and type(c.path) == "table" and #c.path <= 100000, "route")
        for _, p in ipairs(c.path) do assert(type(p) == "table" and number(p.x, -1e9, 1e9) and number(p.y, -1e9, 1e9), "path point") end
        local restored = clone(c); restored.job = restoreJob(c.job)
        s.carriers[#s.carriers + 1] = restored
    end
    assert(type(w.enemies) == "table" and #w.enemies <= 10000, "enemies")
    for _, e in ipairs(w.enemies) do assert(number(e.x, -1e9, 1e9) and number(e.y, -1e9, 1e9) and number(e.hp, -1e12, 1e12), "enemy state") end
    s.enemies = clone(w.enemies)
    assert(s:availableWorkers() >= 0, "workforce")
    return s
end
function Data.restore(data, mode)
    local ok, result = pcall(restoreUnsafe, data, mode)
    if ok then return result end
    return nil
end
return Data
