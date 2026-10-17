-- A deterministic visual fixture, not a player's save or gameplay automation.
V.atFrame(8, function()
    local state, _, hud = require("network.Standalone").Inspect()
    hud.dismissIntro()
    for x = 7, 4, -1 do state:build("road", x, 9) end
    for x = 13, 15 do state:build("road", x, 9) end
    for _, item in ipairs({ {"house",7}, {"farm",6}, {"mill",5}, {"kitchen",4}, {"woodcutter",13}, {"barracks",14}, {"house",15} }) do
        state:build(item[1], item[2], 8)
    end
    for _ = 1, 900 do state:update(0.1) end
    state.lesson = 5
    hud.update()
end)
