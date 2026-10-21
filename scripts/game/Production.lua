-- Production orchestration lives outside Simulation so new industries share
-- typed recipes and real dispatch instead of adding per-building shortcuts.
local D=require 'game.Definitions'
local E=require 'game.Economy'
local Farm=require 'game.FarmCycle'
local Ranch=require 'game.RanchCycle'
local Meals=require 'game.Meals'
local Deposits=require 'game.Deposits'
local Breaks=require 'game.WorkBreaks'
local P={}
function P.update(sim,dt)
    for _,b in ipairs(sim.buildings)do
        local def=D.buildings[b.kind]
        if b.complete and def.output and sim:connected(b) then
            sim:normalizeInputs(b)
            E.applyQueued(b)
            if b.kind=='kitchen' then Meals.restock(sim,b) end
            local ready=E.hasInputs(b)
            if def.input then b.demandAge=not ready and (b.demandAge or 0)+dt or 0 end
            -- Keep real input space for the incoming load: two modern mill
            -- batches, or four one-input feed/work cycles at ordinary shops.
            local lowWater=b.kind=='mill' and b.recipeVersion~=1 and b.inputs<=2 or
                (b.kind=='ranch' or b.kind=='bakery' or b.kind=='sawmill') and b.inputs<=1
            if def.input and E.canWork(b) and (not ready or lowWater) and not b.incoming and (b.activeWorkers or 0)>0 then
                local resource=E.request(b) or def.input
                if not def.recipes and def.alternateInput and (sim.stock[def.alternateInput] or 0)>(sim.stock[resource] or 0) then resource=def.alternateInput end
                if not def.recipes then
                    for _,extra in ipairs(def.extraInputs or {})do
                        if (sim.stock[extra] or 0)>(sim.stock[resource] or 0)then resource=extra end
                    end
                end
                local supply=false
                for _,source in ipairs(sim.buildings)do
                    if source~=b and source.complete and not source.outgoing and sim:connected(source) and E.outputAmount(source,resource)>0 then supply=true;break end
                end
                if not supply then sim:enqueue(b,true,resource) end
            end
            local legacy=false
            if b.kind=='quarry' and b.legacyOutput then
                if b.buffer==0 and not b.outgoing then b.legacyOutput=nil else legacy=true end
            end
            if b.kind=='woodcutter' then sim:updateWoodcutter(b,dt)
            elseif b.kind=='ranch' then
                if b.stopped then Ranch.finishVisit(b,dt)
                elseif Ranch.update(b,dt,b.workRate or 0) then E.add(b,def.output,def.amount) end
            elseif not b.lifeEnabled and not legacy and Breaks.canCommit(sim,b)and E.canWork(b) and E.canProduce(b) and ready and E.resourceAvailable(sim,b) then
                local finished=false
                if b.kind=='farm' then finished=Farm.update(b,dt,def.period,b.workRate or 0)
                elseif (b.activeWorkers or 0)>0 then
                    if def.recipes and not b.processingRecipe then b.processingRecipe=b.recipe or 1 end
                    if def.input and not def.recipes and not b.processingResource then b.processingResource=sim:inputResource(b) end
                    local work=dt*(b.workRate or b.activeWorkers)
                    b.timer=b.timer+work
                    b.visualWorkSeconds=(b.visualWorkSeconds or 0)+work
                    finished=b.timer>=E.period(b)
                end
                if finished then
                    local outputs=E.outputs(b)
                    local primary=def.output
                    if not outputs[primary]then for _,r in ipairs(D.goods)do if outputs[r]then primary=r;break end end end
                    if b.kind~='farm' then b.timer=0 end
                    if b.kind=='kitchen' and (b.processingResource or sim:inputResource(b))=='fish' then sim.fishMealsCooked=(sim.fishMealsCooked or 0)+1 end
                    if def.input then sim:consumeInput(b) end
                    if Breaks.outdoor(b)then
                        assert(Breaks.committed(sim,b,outputs,primary),'Workshop commit requires an actual operator')
                    else for resource,amount in pairs(outputs)do
                        local produced=amount
                        if b.kind=='quarry' then produced=math.min(amount,math.max(0,sim.rock-Deposits.reserved(sim,'rawstone:valley')));sim.rock=sim.rock-produced
                        elseif def.deposit then produced=Deposits.extract(sim,b,resource,amount) end
                        E.add(b,resource,produced)
                        if b.kind=='kitchen' then
                            local incoming=b.mealIncoming and 2 or 0
                            local served=math.min(math.max(0,Meals.pantryCapacity-(b.mealStock or 0)-incoming),produced)
                            b.mealStock=(b.mealStock or 0)+served
                            E.take(b,resource,served)
                            sim.produced.food=(sim.produced.food or 0)+served
                        end
                    end end
                    b.visualFinishAt,b.visualFinishResource=sim.elapsed,primary
                end
            end
            if b.buffer>0 and not b.outgoing then sim:enqueue(b,false) end
        end
    end
end
return P
