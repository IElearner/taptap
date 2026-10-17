local Sim=require "game.Simulation"
local Farm=require "game.FarmCycle"
local Data=require "game.SaveData"
local D=require "game.Definitions"
local Move=require "game.Movement"
V.atFrame(8,function()
    local walker={x=0,y=0,path={{x=1,y=0}},index=1}
    Move.step(walker,0.1)
    V.assert(math.abs(walker.x-0.18)<0.001,"Villagers walk at the slower default pace")
    local planned=Sim.new("finite",23)
    planned.started,planned.skipped=true,true
    V.assert(planned:build("road",7,9) and planned:build("road",6,9),
        "Connected roads can reach the two adjacent wheat fields")
    V.assert(planned:build("farm",8,8) and planned:build("farm",6,8),
        "Players can place two adjacent wheat fields through the normal build action")
    local s=Sim.new("finite",23)
    s.started,s.skipped=true,true
    local b=s:addBuilding("farm",8,8,true)
    V.assert(b.footprintW==2 and b.footprintH==2 and #Farm.exposedEdges(s,b)==8,
        "New wheat field occupies four tiles with one outer fence per boundary edge")
    local neighbor=s:addBuilding("farm",6,8,true)
    V.assert(#Farm.exposedEdges(s,b)==6 and #Farm.exposedEdges(s,neighbor)==6,
        "Two adjacent fields omit the shared fence and keep their outer boundary")
    V.assert(s:staff(b,1),"Assign a worker to the wheat field")
    local stages,steps,actions={},{},{}
    local function tick(count)
        for _=1,count do
            s:update(0.1)
            stages[Farm.stage(b,D.buildings.farm.period)]=true
            steps[Farm.step(b)]=true
            if Farm.needsWork(b,D.buildings.farm.period) then actions[Farm.action(b)]=true end
        end
    end
    tick(55)
    V.assert(b.farmStep==1 and b.timer>0,"Worker visits to sow seeds, then growth starts")
    local workClock=s.workers[b.id .. ":1"].workClock
    V.assert(s:staff(b,-1),"Temporarily remove the worker")
    tick(350)
    V.assert(b.timer>=D.buildings.farm.period/3 and b.farmStep==1 and b.buffer==0,
        "Wheat grows without a worker but cannot skip the tending visit")
    V.assert(s:staff(b,1),"Restore the worker for tending")
    tick(1)
    local returning=s.workers[b.id .. ":1"]
    V.assert(returning and returning.farmPresence>0 and returning.farmPresence<1,
        "Worker walks into the field before tending")
    local snapshot=Data.capture(s,1000,1,true)
    local restored=Data.restore(snapshot,s.mode)
    V.assert(restored and restored.buildings[b.id].farmStep==1,"Mid-growth save keeps the farming step")
    tick(950)
    V.assert(steps[0] and steps[1] and steps[2] and steps[3],"Worker completes sowing, two tending visits and harvest")
    V.assert(actions.plow and actions.water and actions.tend and actions.harvest,
        "Farm visits use plowing, watering, tending and harvesting actions")
    V.assert(stages.seed and stages.sprout and stages.green and stages.ripe,
        "Field displays seed, sprout, green and ripe stages")
    V.assert((s.produced.grain or 0)>0 or b.buffer>0 or b.outgoing,
        "Harvest produces grain for transport")
    V.assert((s.workers[b.id .. ":1"].workClock or 0)>workClock,
        "Worker returns to the field for later visits")
    local old=Data.capture(s,1000,1,true)
    old.world.buildings[b.id].farmStep=nil
    old.world.buildings[b.id].farmWork=nil
    V.assert(Data.restore(old,s.mode)~=nil,"Older farm saves load with default growth state")
    old.world.buildings[b.id].footprintW=1
    V.assert(Data.restore(old,s.mode)~=nil,"Legacy narrow wheat fields remain loadable")
    V.finish()
end)
