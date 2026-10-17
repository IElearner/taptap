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
    sim:build("farm",6,8)
    sim:build("mill",5,8)
    sim:build("kitchen",7,8)
    sim:build("butcher",8,8)
    sim:build("ranch",12,8)
    sim.stock.food=100
    for _=1,1600 do sim:update(0.1) end
    local hall=sim:buildingAt(7,8)
    if hall then hall.mealStock=math.max(hall.mealStock or 0,4) end
    for i,c in ipairs(sim.carriers) do if i<=2 then c.hunger=95;c.meal=false;c.job=false;c.path={};c.index=1;c.x=10;c.y=9 end end
    local seated=false
    for _=1,90 do
        sim:update(0.1)
        local diners=0
        for _,a in ipairs(sim.carriers) do if a.meal and a.meal.phase=="eat" then diners=diners+1 end end
        if diners>=2 then seated=true;break end
    end
    V.assert(seated,"Two villagers are seated at the canteen in the visual fixture")
    local farm=sim:buildingAt(6,8)
    V.assert(farm and sim.workers[farm.id .. ":1"] and (sim.workers[farm.id .. ":1"].workClock or 0)>0,
        "A farmer actually works the visible field")
    view.zoom(0.3)
    hud.update()
end)
V.atFrame(65,function() V.finish() end)
