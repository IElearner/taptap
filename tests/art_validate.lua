local Art=require "game.Art"
V.atFrame(8,function()
    for _,name in ipairs({"login-painting","portrait-elder","atlas-buildings","atlas-environment","atlas-villagers","atlas-workers"}) do
        V.assert(fileSystem:FileExists(Art.path(name)),"Imported original PNG exists: " .. name)
        V.assert(fileSystem:FileExists(Art.path(name) .. ".meta"),"Official image metadata exists: " .. name)
    end
    for _,name in ipairs({"building-store","building-house","building-farm","building-mill","building-kitchen",
        "building-woodcutter","building-quarry","building-courier","building-barracks",
        "ground-grass","ground-road","ground-water","tree-oak","tree-pine","tree-bamboo",
        "person-civilian-blue-man-se","person-civilian-ochre-woman-sw","person-civilian-grey-elder-ne",
        "person-civilian-green-woman-nw","person-loaded-green-woman-se",
        "person-occupation-farmer-se","person-occupation-artisan-sw","person-occupation-logger-ne","person-occupation-guard-nw"}) do
        V.assert(Art.exists(name),"Runtime sprite resolves to a real imported atlas: " .. name)
    end
end)
V.atFrame(20,function() V.finish() end)
