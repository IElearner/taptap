V.atFrame(6, function()
    local s = require("game.Simulation").new()
    s.started = true
    s:build("farm", 8, 8); s:build("mill", 9, 8); s:build("kitchen", 11, 8); s:build("woodcutter", 12, 8)
    for _ = 1, 80 do s:update(0.1) end
    local data = require("game.SaveData").capture(s, 1000, 1, true)
    local files = { ["shanheli_save_v1_finite.json"] = cjson.encode(data) }
    local storage = require("game.SaveStore").new({ now = function() return 1600 end,
        read = function(k) return files[k] end, write = function(k, v) files[k] = v; return true end })
    require("network.Standalone").UseStore(storage)
end)
V.atFrame(30, function()
    local s, _, _, info = require("network.Standalone").Inspect()
    V.assert(info.hasSave and not info.settling, "Continue menu shows restored save")
    V.assert(s.produced.food > 0, "Offline food chain produces a visible summary")
end)
