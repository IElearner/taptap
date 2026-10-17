local Sim=require "game.Simulation"
local Farm=require "game.FarmCycle"
local Data=require "game.SaveData"
local D=require "game.Definitions"
V.atFrame(8,function()
    local s=Sim.new("finite",23)
    s.started,s.skipped=true,true
    local b=s:addBuilding("farm",8,8,true)
    V.assert(s:staff(b,1),"Assign a worker to the wheat field")
    local stages,steps={},{}
    local function tick(count)
        for _=1,count do
            s:update(0.1)
            stages[Farm.stage(b,D.buildings.farm.period)]=true
            steps[Farm.step(b)]=true
        end
    end
    tick(11)
    V.assert(b.farmStep==1 and b.timer>0,"Worker visits to sow seeds, then growth starts")
    local workClock=s.workers[b.id .. ":1"].workClock
    V.assert(s:staff(b,-1),"Temporarily remove the worker")
    tick(80)
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
    tick(190)
    V.assert(steps[0] and steps[1] and steps[2] and steps[3],"Worker completes sowing, two tending visits and harvest")
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
    V.finish()
end)
