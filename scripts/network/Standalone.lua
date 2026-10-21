-- Lifecycle based on templates/scaffold-2d.lua. Single-player mobile prototype.
local UI = require "urhox-libs/UI"
local Simulation = require "game.Simulation"
local WorldView = require "game.PixelWorldView"
local Hud = require "game.Hud"
local SaveStore = require "game.PixelSaveStore"
local SaveData = require "game.SaveData"
local Offline = require "game.Offline"
local Game = {}
local session = { accepted = false, userId = 0, guest = false }
local injectedStore = false
---@type false|{state:table, info:table}
local demoReturn=false
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
    if demoReturn then return false end
    if state and state.started and not info.loading and not info.settling then
        return store:save(state, info.idleEnabled)
    end
    return false
end
local function finishSettlement()
    info.settling, info.summary = false, settlement:summary()
    if settlement.seconds > 0 then state:notify(info.summary) end
    -- Timestamp is committed with the resulting economy, so a reload cannot claim twice.
    if state.started and not demoReturn then store:save(state, info.idleEnabled) end
    saveClock = 0
end
local function startSettlement(savedAt)
    settlement = Offline.new(state, savedAt, store.now(), info.idleEnabled)
    info.settling, info.progress = settlement.remaining > 0, 0
    if not info.settling then finishSettlement() end
end
render = function()
    if view then view.dispose() end
    actions.mode, actions.selected, actions.saveInfo, actions.session, actions.road = "inspect", false, info, session, false
    actions.login = function(guest)
        local id = clientCloud and tonumber(clientCloud.userId) or 0
        if not guest and id <= 0 then return false, "尚未识别账号，请用 TapTap 扫码进入，或选游客试玩。" end
        session.accepted, session.userId, session.guest = true, id, guest
        if not injectedStore then
            local backend = SaveStore.nativeBackend()
            if guest then
                local read, write = backend.read, backend.write
                backend.cloudGet, backend.cloudSet = nil, nil
                backend.read = function(name) return read("guest_" .. name) end
                backend.write = function(name, value) return write("guest_" .. name, value) end
            end
            store = SaveStore.new(backend)
        end
        create(state.mode, false)
        return true, guest and "游客试玩 · 仅本地存档" or "已连接 TapTap 账号"
    end
    actions.setMode = function(mode)
        if info.loading or info.settling then return end
        actions.mode, actions.selected, actions.road = mode, false, false
        view.setMode(mode); view.select(false)
        if mode ~= "inspect" then state:notify(require("game.Definitions").buildings[mode].description) end
    end
    view = WorldView.create(state, function(x, y)
        if info.loading or info.settling or background then return end
        local b = state:buildingAt(x, y)
        if actions.mode == "inspect" and b then actions.road=false; actions.selected = b; actions.mode = "inspect"; view.setMode("inspect"); view.select(b)
        elseif actions.mode == "inspect" and state:roadSiteAt(x,y) then
            actions.selected,actions.road=false,state:roadSiteAt(x,y);view.select(false)
        elseif actions.mode ~= "inspect" then
            local _, message, built = state:build(actions.mode, x, y)
            state:notify(message)
            if built then actions.selected = built; view.select(built) end
        else actions.selected,actions.road = false,false; view.select(false) end
    end)
    actions.demo = function()
        if info.loading or info.settling then return end
        if demoReturn then
            state,info=demoReturn.state,demoReturn.info;demoReturn=false
            lastWall=store.now();saveClock=0;render();state:notify("已返回你的村庄。")
        else
            persist()
            demoReturn={state=state,info=info}
            state=require("game.DemoVillage").new()
            info={demo=true,loading=false,settling=false,idleEnabled=false,status="演示村庄",summary="演示不会覆盖原存档；可在系统中返回自己的村庄。"}
            lastWall=store.now();saveClock=0;render()
        end
    end
    actions.restart = function() if demoReturn then actions.demo() end;create(state.mode, true) end
    actions.changeMode = function(value)
        if demoReturn then actions.demo() end
        persist()
        create(value, false)
    end
    actions.enter = function()
        if not session.accepted or info.loading or info.settling then return false end
        state.started, state.paused, state.menuOpen = true, false, false
        persist()
        return true
    end
    actions.save = function()
        if demoReturn then state:notify("演示村不会覆盖原存档；返回自己的村庄后可保存。");return end
        persist()
        state:notify(store.status)
    end
    actions.toggleIdle = function()
        if info.loading or info.settling then return end
        if demoReturn then state:notify("演示村不会进行离线结算。");return end
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
    if not session.accepted then
        info.loading, info.status = false, "选择账号后读取进度"
        hud.update()
        return
    end
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
    graphics.windowTitle = "山河里 · 像素村庄 产业拓展 v3"
    UI.Init({ theme = require('game.PixelTheme'), scale = UI.Scale.DEFAULT })
    session = { accepted = false, guest = false, userId = clientCloud and tonumber(clientCloud.userId) or 0 }
    injectedStore = false
    demoReturn=false
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
        elseif not demoReturn and now - lastWall > 5 and state.started and not state.menuOpen then
            startSettlement(lastWall)
        else
            if not state.menuOpen then state:update(dt) end
            saveClock = saveClock + dt
            if saveClock >= 30 then persist(); saveClock = 0 end
        end
    end
    lastWall = now
    info.status = demoReturn and "演示村庄 · 原存档已保留" or store.status
    uiClock = uiClock + dt
    if uiClock >= 0.15 then local elapsed = uiClock; uiClock = 0; hud.update(elapsed) end
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
function Game.Stop()
    persist()
    if view then view.dispose(); view = nil end
    UI.Shutdown()
end
function Game.Inspect() return state, view, hud, info, store end
-- Dependency injection also lets tests avoid touching a real player's files or cloud data.
function Game.UseStore(storage, showLogin)
    demoReturn=false
    if store then store.generation = store.generation + 1 end
    store, injectedStore = storage, true
    session.accepted = not showLogin
    create("finite", false)
end
return Game
