-- Stable visual fixture; never reads or writes player data.
V.atFrame(6, function()
    require("network.Standalone").UseStore(require("game.SaveStore").new({ now = function() return 1000 end,
        read = function() return nil end, write = function() return true end }), true)
end)
