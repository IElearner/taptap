local Game=require "network.Standalone"
local Store=require "game.SaveStore"
V.atFrame(8,function()
    Game.UseStore(Store.new({now=function() return 1000 end,read=function() return nil end,write=function() return true end}),true)
    local sim,view,hud=Game.Inspect()
    hud.dismissIntro()
    sim,view,hud=Game.Inspect()
    hud.dismissIntro()
    sim.skipped=true
    for x=7,5,-1 do sim:build("road",x,9) end
    for x=13,14 do sim:build("road",x,9) end
    sim:build("farm",6,8)
    sim:build("mill",7,8)
    sim:build("kitchen",12,8)
    sim:build("butcher",8,8)
    sim:build("ranch",14,8)
    sim.stock.food=100
    for _=1,1600 do sim:update(0.1) end
    local hall=sim:buildingAt(12,8)
    if hall then hall.mealStock=math.max(hall.mealStock or 0,8) end
    for _,c in ipairs(sim.carriers) do c.hunger=95;c.meal=false;c.job=false;c.path={};c.index=1;c.x=10;c.y=9 end
    local farm=sim:buildingAt(6,8)
    local farmWorker=farm and sim.workers[farm.id .. ":1"]
    if farmWorker then farmWorker.hunger=95;farmWorker.meal=false;farmWorker.path={};farmWorker.index=1 end
    local seated=false
    for _=1,180 do
        sim:update(0.1)
        local diners=0
        for _,a in ipairs(sim.carriers) do if a.meal and a.meal.phase=="eat" then diners=diners+1 end end
        if farmWorker and farmWorker.meal and farmWorker.meal.phase=="eat" then diners=diners+1 end
        if diners>=4 then seated=true;break end
    end
    V.assert(seated,"Four villagers are seated at the enlarged canteen in the visual fixture")
    V.assert(farm and sim.workers[farm.id .. ":1"] and (sim.workers[farm.id .. ":1"].workClock or 0)>0,
        "A farmer actually works the visible field")
    view.zoom(0.3)
    hud.update()
end)
V.atFrame(65,function() V.finish() end)
