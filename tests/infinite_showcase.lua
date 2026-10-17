-- Deterministic fixture showing the infinite-mode HUD after establishing a village.
V.atFrame(8, function()
    local _, _, originalHud = require("network.Standalone").Inspect()
    originalHud.root:FindById("modeInfinite").props.onClick()
    local state, _, hud = require("network.Standalone").Inspect()
    hud.dismissIntro()
    for x = 7, 4, -1 do state:build("road", x, 9) end
    for x = 13, 16 do state:build("road", x, 9) end
    for _, item in ipairs({ {"house",7}, {"farm",6}, {"mill",5}, {"kitchen",4}, {"woodcutter",13}, {"barracks",14}, {"quarry",15}, {"courier",16} }) do
        local ok = state:build(item[1], item[2], 8)
        V.assert(ok, "Showcase building: " .. item[1])
    end
    for _ = 1, 1800 do state:update(0.1) end
    V.assert(state:expand(), "Showcase explores frontier")
    state.lesson, state.paused = 9, true
    hud.update()
end)
