-- A deterministic visual fixture, not a player's save or gameplay automation.
V.atFrame(8, function()
    require("network.Standalone").UseStore(require("game.SaveStore").new({
        now = function() return 1000 end, read = function() return nil end, write = function() return true end,
    }))
    local state, _, hud = require("network.Standalone").Inspect()
    hud.dismissIntro()
    for x = 7, 4, -1 do state:build("road", x, 9) end
    for x = 13, 16 do state:build("road", x, 9) end
    for _, item in ipairs({ {"house",7}, {"farm",5}, {"mill",6}, {"kitchen",12}, {"woodcutter",14}, {"barracks",15}, {"house",16} }) do
        state:build(item[1], item[2], 8)
    end
    for _ = 1, 900 do state:update(0.1) end
    state.lesson = 5
    hud.update()
end)
