local Art=require "game.Art"
V.atFrame(8,function()
    for _,name in ipairs({"login-painting","portrait-elder","atlas-buildings","atlas-environment","atlas-villagers","atlas-workers","atlas-specialists",
        "atlas-loaded","atlas-combatants","atlas-icons","panel-wood","button-painting",
        "atlas-villagers-stride","atlas-loaded-stride","atlas-workers-stride",
        "atlas-builders-hammer-up","atlas-builders-hammer-down"}) do
        V.assert(fileSystem:FileExists("assets/" .. Art.path(name)),"Imported original PNG exists: " .. name)
        V.assert(fileSystem:FileExists("assets/" .. Art.path(name) .. ".meta"),"Official image metadata exists: " .. name)
    end
    V.assert(Art.path("atlas-buildings")=="image/atlas-buildings.png","Runtime image path uses the resource root")
    for _,name in ipairs({"building-store","building-house","building-farm","building-mill","building-kitchen",
        "building-woodcutter","building-quarry","building-courier","building-barracks",
        "ground-grass","ground-road","ground-water","tree-oak","tree-pine","tree-bamboo",
        "person-civilian-blue-man-se","person-civilian-ochre-woman-sw","person-civilian-grey-elder-ne",
        "person-civilian-green-woman-nw","person-loaded-green-woman-se",
        "person-occupation-farmer-se","person-occupation-artisan-sw","person-occupation-logger-ne","person-occupation-guard-nw",
        "person-occupation-chef-se","person-occupation-chef-nw","person-occupation-butcher-sw","person-occupation-butcher-ne",
        "person-civilian-blue-man-se-stride","person-loaded-green-woman-sw-stride",
        "person-occupation-farmer-ne-stride","person-civilian-grey-elder-nw-hammer-up",
        "person-civilian-ochre-woman-se-hammer-down",
        "person-militia-se","person-bandit-sw","icon-build","icon-village","icon-army","icon-system",
        "icon-wood","icon-stone","icon-grain","icon-flour","icon-food","icon-home","icon-pause","icon-save","icon-idle","icon-tutorial"}) do
        V.assert(Art.exists(name),"Runtime sprite resolves to a real imported atlas: " .. name)
    end
end)
V.atFrame(20,function() V.finish() end)
