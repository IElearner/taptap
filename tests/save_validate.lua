local Sim = require "game.Simulation"
local Data = require "game.SaveData"
local Store = require "game.SaveStore"
local Offline = require "game.Offline"
local function advance(s, seconds) for _ = 1, seconds * 10 do s:update(0.1) end end
local function finish(task)
    local batches = 0
    while not task:step(2048) do batches = batches + 1; assert(batches < 1000, "bounded offline work") end
end
local function memoryBackend()
    local memory, clock = {}, { now = 1000 }
    return { now = function() return clock.now end, read = function(k) return memory[k] end,
        write = function(k, v) memory[k] = v; return true end }, memory, clock
end
V.atFrame(8, function()
    local s = Sim.new("infinite"); s.started = true
    s:build("farm", 8, 8); s:build("woodcutter", 12, 8)
    advance(s, 12)
    for _ = 1, 30 do
        s:update(0.1)
        local active = false
        for _, carrier in ipairs(s.carriers) do if carrier.job then active = true end end
        if active then break end
    end
    local save = Data.capture(s, 1000, 3, true)
    local restored = Data.restore(cjson.decode(cjson.encode(save)), "infinite")
    V.assert(restored ~= nil and restored:count("farm") == 1, "JSON round-trip restores buildings")
    local obsoleteMeal=cjson.decode(cjson.encode(save))
    obsoleteMeal.world.carriers[1].meal={target=1,phase="eat",timer=2,resumeX=10,resumeY=9,paid=true,seat=1}
    local migratedMeal=Data.restore(obsoleteMeal,"infinite")
    V.assert(migratedMeal and not migratedMeal.carriers[1].meal,
        "Old warehouse dining is removed when its save loads")
    V.assert(restored:buildingAt(8, 8) == restored.buildings[2], "Building coordinate index is reconstructed")
    for _, c in ipairs(restored.carriers) do if c.job then V.assert(c.job.b == restored.buildings[c.job.b.id], "Active delivery relinks the live building") end end
    for _, j in ipairs(restored.jobs) do V.assert(j.b == restored.buildings[j.b.id], "Queued delivery relinks the live building") end
    advance(s, 30); advance(restored, 30)
    for _, resource in ipairs(require("game.Definitions").goods) do
        V.assert(s.stock[resource] == restored.stock[resource], "Transport preserves " .. resource .. ": " .. s.stock[resource] .. "/" .. restored.stock[resource])
    end
    V.assert(not Data.restore(save, "finite"), "Modes cannot load each other's slot")
    local legacy=Sim.new("finite")
    V.assert(legacy:build("house",8,8),"A new two-by-two home can be placed beside the warehouse")
    local legacySave=Data.capture(legacy,1000,3,true)
    legacySave.world.buildings[2].footprintW=1
    legacySave.world.buildings[2].footprintH=1
    local legacyRestored=Data.restore(legacySave,"finite")
    V.assert(legacyRestored and legacyRestored:buildingAt(8,8).footprintW==1 and not legacyRestored:buildingAt(7,8),
        "Older one-tile homes retain their original footprint when a save loads")
    local bad = cjson.decode(cjson.encode(save)); bad.world.stock.food = -1
    V.assert(not Data.restore(bad, "infinite"), "Corrupt inventory is rejected")
    bad = cjson.decode(cjson.encode(save)); bad.version = 999
    V.assert(not Data.restore(bad, "infinite"), "Unknown save versions cannot silently load")

    local idle = Data.restore(save, "infinite")
    local elapsed, health, nextRaid = idle.elapsed, idle.health, idle.nextRaid
    idle.raid, idle.enemies = true, { { x = 10, y = 9, hp = 5 } }
    local task = Offline.new(idle, 1000, 1600, true)
    V.assert(not task:step(1), "Offline calculation yields between batches")
    finish(task)
    V.assert(task.seconds == 600 and idle.stock.wood > save.world.stock.wood, "Connected producers earn offline resources")
    V.assert(idle.health == health and idle.enemies[1].hp == 5 and idle.nextRaid == nextRaid, "Offline time cannot cause starvation or combat losses")
    V.assert(idle.elapsed == elapsed and idle.wavesDefeated == 0, "Offline production never inflates survival or defense records")
    local before = idle.stock.wood; task:step(2048)
    V.assert(idle.stock.wood == before, "Completed settlement cannot be run twice")
    local capped = Offline.new(Data.restore(save, "infinite"), 1000, 1000 + 86400, true)
    V.assert(capped.seconds == 28800, "Offline earnings are capped at eight hours")
    finish(capped)
    V.assert(capped.sim.timber >= 0, "Eight-hour offline calculation respects finite resource deposits")
    V.assert(Offline.new(idle, 2000, 1000, true).seconds == 0, "Clock rollback grants no negative or duplicate time")
    idle.paused = true
    V.assert(Offline.new(idle, 1000, 1600, true).seconds == 0, "Paused saves do not idle")
    idle.paused = false
    V.assert(Offline.new(idle, 1000, 1600, false).seconds == 0, "Idle toggle is respected")
    idle.victory = true
    V.assert(Offline.new(idle, 1000, 1600, true).seconds == 0, "Finished games do not idle")

    local backend, memory, clock = memoryBackend()
    local disk = Store.new(backend)
    disk:load("infinite", function() end)
    V.assert(disk:save(s, true), "Local snapshot write succeeds")
    clock.now = 1001; s.stock.food = s.stock.food + 1; disk:save(s, true)
    local loaded
    memory.shanheli_save_v1_infinite = nil
    memory["shanheli_save_v1_infinite.json"] = "corrupt"
    disk:load("infinite", function(value) loaded = value end)
    V.assert(loaded ~= nil and loaded.savedAt == 1000, "Corrupt primary save recovers from valid backup")

    local cloudBackend, _, cloudClock = memoryBackend()
    local getReply, writes = false, {}
    cloudBackend.cloudGet = function(_, cb) getReply = cb; return true end
    cloudBackend.cloudSet = function(_, value, cb) writes[#writes + 1] = { value = value, done = cb }; return true end
    local cloud = Store.new(cloudBackend)
    cloud:load("infinite", function(value) loaded = value end)
    getReply(true, cjson.encode(Data.capture(s, 1200, 9, true)))
    V.assert(loaded.savedAt == 1200 and cloud.cloudReady.infinite, "Newer cloud snapshot wins over old local data")
    cloudClock.now = 1201; cloud:save(s, true); cloudClock.now = 1202; cloud:save(s, true)
    V.assert(#writes == 1, "Cloud saves serialize instead of racing")
    writes[1].done(true)
    V.assert(#writes == 2, "Newest queued snapshot uploads after previous acknowledgement")
    writes[2].done(true)
    V.assert(cloud.status == "云端与本地已保存", "Cloud success is shown only after real acknowledgement")
    local timed = Store.new(cloudBackend); local callbacks = 0
    timed:load("finite", function() callbacks = callbacks + 1 end)
    local late = getReply
    timed:update(9); late(true, nil)
    V.assert(callbacks == 1 and not timed.loading, "Timed-out cloud loads cannot later overwrite a running game")
    local oldCount = #writes
    timed:save(Sim.new(), true)
    V.assert(#writes == oldCount, "Unread cloud slot is never overwritten by an empty fallback game")

    local Game = require "network.Standalone"
    local liveBackend, _, liveClock = memoryBackend()
    Game.UseStore(Store.new(liveBackend))
    local live, _, hud = Game.Inspect()
    hud.dismissIntro()
    live:build("woodcutter", 8, 8); advance(live, 8)
    local oldWood = live.stock.wood
    Game.Focus(false); liveClock.now = liveClock.now + 120; Game.Focus(true)
    for _ = 1, 20 do Game.Update(0.1) end
    local info
    live, _, hud, info = Game.Inspect()
    V.assert(not info.settling and live.stock.wood > oldWood, "Background and return trigger offline production")
    local settled = live.stock.wood
    Game.UseStore(Store.new(liveBackend))
    local reloaded, _, loadedHud, loadedInfo = Game.Inspect()
    V.assert(loadedInfo.hasSave and reloaded.stock.wood == settled, "Restart loads checkpoint without claiming the same offline time again")
    loadedHud.root:FindById("modeInfinite").props.onClick()
    local other, _, otherHud = Game.Inspect(); otherHud.dismissIntro(); other:build("farm", 8, 8)
    otherHud.root:FindById("modeFinite").props.onClick()
    local finite, _, finiteHud = Game.Inspect()
    V.assert(finite.mode == "finite" and finite:count("woodcutter") == 1, "Switching modes preserves independent progress")
    finiteHud.root:FindById("toggleIdle").props.onClick()
    finiteHud.root:FindById("saveGame").props.onClick()
    Game.UseStore(Store.new(liveBackend))
    local _, _, _, restoredInfo = Game.Inspect()
    V.assert(not restoredInfo.idleEnabled, "Idle preference is persisted with the save")
    local native = Store.nativeBackend()
    local nativeStore = Store.new({ now = function() return 5000 end,
        read = function(k) return native.read(".tmp/acceptance_" .. k) end,
        write = function(k, v) return native.write(".tmp/acceptance_" .. k, v) end,
    })
    nativeStore:load("finite", function() end)
    local nativeState = Sim.new(); nativeState.started = true; nativeState.stock.food = 57
    V.assert(nativeStore:save(nativeState, true), "Engine File API writes real persistent storage")
    nativeStore:load("finite", function(value) loaded = value end)
    V.assert(loaded and loaded.world.stock.food == 57, "Engine File API reads back the persisted village")
end)
V.atFrame(30, function() V.finish() end)
