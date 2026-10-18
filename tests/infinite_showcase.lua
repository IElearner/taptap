-- Deterministic fixture showing the infinite-mode HUD after establishing a village.
V.atFrame(8, function()
    require("network.Standalone").UseStore(require("game.SaveStore").new({
        now = function() return 1000 end, read = function() return nil end, write = function() return true end,
    }))
    local _, _, originalHud = require("network.Standalone").Inspect()
    originalHud.root:FindById("modeInfinite").props.onClick()
    local state, _, hud = require("network.Standalone").Inspect()
    hud.dismissIntro()
    for x = 7, 4, -1 do state:build("road", x, 9) end
    for x = 13, 17 do state:build("road", x, 9) end
    for _, item in ipairs({ {"house",7}, {"farm",5}, {"mill",8}, {"kitchen",12}, {"woodcutter",14}, {"barracks",15}, {"quarry",17} }) do
        local ok = state:build(item[1], item[2], 8)
        V.assert(ok, "Showcase building: " .. item[1])
    end
    state.stock.wood=math.max(state.stock.wood,80)
    state.stock.food=math.max(state.stock.food,80)
    for _ = 1, 1800 do state:update(0.1) end
    local expanded,reason=state:expand()
    V.assert(expanded, "Showcase explores frontier: " .. tostring(reason))
    state.lesson, state.paused = 9, true
    hud.update()
end)
