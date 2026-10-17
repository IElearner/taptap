-- Lifecycle based on templates/scaffold-2d.lua. Single-player mobile prototype.
local UI = require "urhox-libs/UI"
local Simulation = require "game.Simulation"
local WorldView = require "game.WorldView"
local Hud = require "game.Hud"
local Game = {}
---@type VillageSimulation
local state
---@type VillageWorldView
local view
---@type VillageHud
local hud
---@type {mode:string,selected:table|false,setMode:function,restart:function,changeMode:function}
local actions = { mode = "inspect", selected = false, setMode = function() end, restart = function() end, changeMode = function() end }
local uiClock = 0
local function create(mode, seed)
    state = Simulation.new(mode, seed)
    actions.mode, actions.selected = "inspect", false
    actions.setMode = function(mode)
        actions.mode, actions.selected = mode, false
        view.setMode(mode); view.select(false)
        if mode ~= "inspect" then state:notify(require("game.Definitions").buildings[mode].description) end
    end
    view = WorldView.create(state, function(x, y)
        local b = state:buildingAt(x, y)
        if b then actions.selected = b; actions.mode = "inspect"; view.setMode("inspect"); view.select(b)
        elseif actions.mode ~= "inspect" then
            local _, message, built = state:build(actions.mode, x, y)
            state:notify(message)
            if built then actions.selected = built; view.select(built) end
        else actions.selected = false; view.select(false) end
    end)
    actions.restart = function() create(state.mode, state.map.seed) end
    actions.changeMode = function(value) create(value) end
    hud = Hud.create(state, view, actions)
    UI.SetRoot(hud.root); hud.update()
    print("[山河里] Single-player village ready")
end
function Game.Start()
    graphics.windowTitle = "山河里 · 炊烟再起"
    UI.Init({ theme = "default-light", scale = UI.Scale.DEFAULT,
        fonts = { { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } } } })
    create()
end
function Game.Update(dt)
    state:update(dt)
    uiClock = uiClock + dt
    if uiClock >= 0.15 then uiClock = 0; hud.update() end
end
function Game.Stop() UI.Shutdown() end
function Game.Inspect() return state, view, hud end
return Game
