-- A disposable living village for inspecting V7 without replacing a player's save.
local Sim=require 'game.Simulation'
local Demo={}
function Demo.new()
    local s=Sim.new('finite')
    s.started,s.skipped,s.population,s.lesson=true,true,40,9
    s.stock.wood,s.stock.stone,s.stock.food,s.stock.grain,s.stock.flour,s.stock.meat=200,100,180,12,8,2
    local function road(x,y)
        s.roads[x..':'..y]=true
    end
    for x=5,16 do road(x,9) end
    for _,p in ipairs({{5,12},{6,10},{6,11},{6,12},{7,10},{8,10},{9,10},{9,11},{9,12},
        {6,5},{7,5},{8,5},{8,6},{9,6},{10,6},{11,6},{11,7},{11,8},{16,7},{16,8}}) do road(p[1],p[2]) end
    for x=8,16 do road(x,13) end
    for y=14,17 do road(11,y) end
    road(10,17)
    s.roadCount=60
    local function add(kind,x,y,inputs)
        local b=s:addBuilding(kind,x,y,true)
        b.workers=require('game.Definitions').buildings[kind].workers
        b.inputs=inputs or 0
        return b
    end
    local kitchen=add('kitchen',8,8,4);kitchen.mealStock=8
    add('butcher',5,11,1)
    add('ranch',15,8,3)
    add('farm',8,12)
    add('farm',16,12)
    add('mill',12,12,3)
    local camp=add('woodcutter',6,4);camp.buffer=2
    add('quarry',10,16)
    s:build('house',16,6)
    for i,a in ipairs(s.carriers) do a.workerLook=(i-1)%2+1;a.hunger=i<=2 and 97 or 0 end
    s:update(.1)
    local chef=s.workers[kitchen.id..':1'];if chef then chef.hunger=83 end
    s:notify('演示村庄：可观察施工、运料、炊食与喂养；不会覆盖你的原存档。')
    return s
end
return Demo
