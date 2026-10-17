-- Lifecycle based on templates/scaffold-2d.lua. Single-player mobile prototype.
local UI = require "urhox-libs/UI"
local Simulation = require "game.Simulation"
local WorldView = require "game.WorldView"
local Hud = require "game.Hud"
local SaveStore = require "game.SaveStore"
local SaveData = require "game.SaveData"
local Offline = require "game.Offline"
local Game = {}
---@type VillageSimulation
local state
---@type VillageWorldView
local view
---@type VillageHud
local hud
---@type VillageSaveStore
local store
---@type VillageOffline
local settlement
local uiClock, saveClock, lastWall, backgroundAt = 0, 0, 0, 0
local background, generation = false, 0
---@type table
local info = {}
---@type table
local actions = { mode = "inspect", selected = false }
local render, create
local function persist()
    if state and state.started and not info.loading and not info.settling then
        return store:save(state, info.idleEnabled)
    end
    return false
end
local function finishSettlement()
    info.settling, info.summary = false, settlement:summary()
    if settlement.seconds > 0 then state:notify(info.summary) end
    -- Timestamp is committed with the resulting economy, so a reload cannot claim twice.
    if state.started then store:save(state, info.idleEnabled) end
    saveClock = 0
end
local function startSettlement(savedAt)
    settlement = Offline.new(state, savedAt, store.now(), info.idleEnabled)
    info.settling, info.progress = settlement.remaining > 0, 0
    if not info.settling then finishSettlement() end
end
render = function()
    actions.mode, actions.selected, actions.saveInfo = "inspect", false, info
    actions.setMode = function(mode)
        if info.loading or info.settling then return end
        actions.mode, actions.selected = mode, false
        view.setMode(mode); view.select(false)
        if mode ~= "inspect" then state:notify(require("game.Definitions").buildings[mode].description) end
    end
    view = WorldView.create(state, function(x, y)
        if info.loading or info.settling or background then return end
        local b = state:buildingAt(x, y)
        if b then actions.selected = b; actions.mode = "inspect"; view.setMode("inspect"); view.select(b)
        elseif actions.mode ~= "inspect" then
            local _, message, built = state:build(actions.mode, x, y)
            state:notify(message)
            if built then actions.selected = built; view.select(built) end
        else actions.selected = false; view.select(false) end
    end)
    actions.restart = function() create(state.mode, true) end
    actions.changeMode = function(value)
        persist()
        create(value, false)
    end
    actions.enter = function()
        if info.loading or info.settling then return false end
        state.started, state.paused, state.menuOpen = true, false, false
        persist()
        return true
    end
    actions.save = function()
        persist()
        state:notify(store.status)
    end
    actions.toggleIdle = function()
        if info.loading or info.settling then return end
        info.idleEnabled = not info.idleEnabled
        store:save(state, info.idleEnabled)
    end
    hud = Hud.create(state, view, actions)
    UI.SetRoot(hud.root); hud.update()
end
create = function(mode, fresh)
    generation = generation + 1
    local current = generation
    state = Simulation.new(mode)
    state.menuOpen = true
    info = { loading = not fresh, settling = false, idleEnabled = true, hasSave = false,
        status = "读取存档中…", summary = "离线生产最多累计 8 小时；不结算敌袭与损失。", progress = 0 }
    saveClock, background, lastWall = 0, false, store.now()
    render()
    if fresh then
        store.generation, store.loading, store.completeLoad = store.generation + 1, false, false
        store.activeMode, store.status = state.mode, "新局准备就绪；入村后保存"
        info.status = store.status
        return
    end
    local requestedMode = state.mode
    store:load(requestedMode, function(bundle)
        if generation ~= current then return end
        info.loading, info.status = false, store.status
        if bundle then
            state = SaveData.restore(bundle, requestedMode)
            state.menuOpen = true
            info.hasSave, info.idleEnabled = true, bundle.idleEnabled
            render()
            startSettlement(bundle.savedAt)
        else info.summary = "此模式暂无存档，入村后每 30 秒自动保存。" end
        hud.update()
    end)
    print("[山河里] Save-aware single-player session ready")
end
function Game.Start()
    graphics.windowTitle = "山河里 · 炊烟再起"
    UI.Init({ theme = "default-light", scale = UI.Scale.DEFAULT,
        fonts = { { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } } } })
    store = SaveStore.new()
    create("finite", false)
end
function Game.Update(dt)
    store:update(dt)
    local now = store.now()
    if not background and not info.loading then
        if info.settling then
            local done = settlement:step(1024)
            info.progress = 1 - settlement.remaining / math.max(1, settlement.seconds)
            if done then finishSettlement() end
        elseif now - lastWall > 5 and state.started and not state.menuOpen then
            startSettlement(lastWall)
        else
            if not state.menuOpen then state:update(dt) end
            saveClock = saveClock + dt
            if saveClock >= 30 then persist(); saveClock = 0 end
        end
    end
    lastWall = now
    info.status = store.status
    uiClock = uiClock + dt
    if uiClock >= 0.15 then uiClock = 0; hud.update() end
end
function Game.Focus(focused)
    if not focused then
        if not background then persist(); backgroundAt = store.now() end
        background = true
    elseif background then
        background = false
        if not info.loading and not info.settling then startSettlement(backgroundAt) end
        lastWall = store.now()
    end
end
function Game.Stop() persist(); UI.Shutdown() end
function Game.Inspect() return state, view, hud, info, store end
-- Dependency injection also lets tests avoid touching a real player's files or cloud data.
function Game.UseStore(storage)
    if store then store.generation = store.generation + 1 end
    store = storage
    create("finite", false)
end
return Game
