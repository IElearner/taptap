local Game = require "network.Standalone"
local Store = require "game.SaveStore"
local files, cloudReads = {}, 0
V.atFrame(6, function()
    Game.UseStore(Store.new({ now = function() return 1000 end,
        read = function(k) return files[k] end,
        write = function(k,v) files[k]=v; return true end,
        cloudGet = function() cloudReads=cloudReads+1; return false end,
    }), true)
end)
V.atFrame(9, function()
    local s, _, hud = Game.Inspect()
    V.assert(hud.root:FindById("loginScreen"):IsVisible(), "First entry presents separate login screen")
    V.assert(cloudReads == 0, "No save loading before account choice")
    hud.root:FindById("enterVillage").props.onClick()
    V.assert(not s.started, "Account gate blocks world entry")
    if not clientCloud or clientCloud.userId <= 0 then
        hud.root:FindById("loginTapTap").props.onClick()
        V.assert(not s.started and hud.root:FindById("loginScreen"):IsVisible(), "Missing platform identity never fakes successful login")
    end
    hud.root:FindById("loginGuest").props.onClick()
    local state, _, active = Game.Inspect()
    V.assert(not active.root:FindById("loginScreen"):IsVisible(), "Guest transitions to mode menu")
    active.root:FindById("enterVillage").props.onClick(); active.update()
    V.assert(state.started and not state.menuOpen, "Mode choice enters playable village")
    for _, name in ipairs({"build","village","army","system","selected"}) do
        V.assert(not active.root:FindById("drawer_" .. name):IsVisible(), "Closed by default: " .. name)
    end
    active.root:FindById("open_build").props.onClick(); active.update()
    V.assert(active.root:FindById("drawer_build"):IsVisible(), "Construction button opens build catalog")
    active.root:FindById("open_army").props.onClick(); active.update()
    V.assert(not active.root:FindById("drawer_build"):IsVisible() and active.root:FindById("drawer_army"):IsVisible(), "Opening military dismisses construction")
    active.root:FindById("open_build").props.onClick(); active.update()
    active.root:FindById("build_road").props.onClick(); active.update()
    V.assert(not active.root:FindById("drawer_build"):IsVisible(), "Choosing building frees map for placement")
    active.root:FindById("cancelPlacement").props.onClick(); active.update()
    active.root:FindById("open_system").props.onClick(); active.update()
    active.root:FindById("saveGame").props.onClick()
    V.assert(files["shanheli_save_v1_finite.json"] ~= nil, "Manual save remains accessible within system drawer")
    active.root:FindById("showModes").props.onClick(); active.update()
    active.root:FindById("modeInfinite").props.onClick()
    local inf, _, infiniteHud = Game.Inspect()
    V.assert(inf.mode == "infinite" and not infiniteHud.root:FindById("loginScreen"):IsVisible(), "Session survives mode switch without repeated login")
end)
V.atFrame(25, function() V.finish() end)
