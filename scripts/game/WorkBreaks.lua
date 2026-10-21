-- Workshops use actual yard paths. Production alone consumes a recipe;
-- completed goods are held by its operator until a real storage handoff.
local E=require 'game.Economy'
local Move=require 'game.Movement'
local Sites=require 'game.WorkSites'
local Meals=require 'game.Meals'
local Breaks={}
Breaks.kinds=Sites.breakKinds
function Breaks.reason(sim,b)
    if b.stopped then return 'stopped'end
    if not sim:connected(b)then return 'disconnected'end
    if not E.canWork(b)then return 'noOrder'end
    if not E.hasInputs(b)then return 'missingInput'end
    if not E.canProduce(b)then return 'fullOutput'end
    if not E.resourceAvailable(sim,b)then return 'resourceEmpty'end
end
function Breaks.outdoor(b)return b.site and b.site.workCell and b.site.storageCell end
function Breaks.busy(a)
    return a.workLoad~=nil or a.breaks and a.breaks.phase~='idle'and a.breaks.phase~='mealReady'or false
end
local function go(sim,a,b,target,phase)
    local state=a.breaks
    state.target={x=target.x,y=target.y};state.destination=phase
    if phase=='toStorage'then
        for _,other in pairs(sim.workers)do
            local os=other.breaks
            if other~=a and other.building==b.id and os and(os.phase=='toStorage'or os.phase=='stow')then
                state.phase,state.clock='blocked',0;return false
            end
        end
    end
    if not Sites.route(sim,a,b,target)then state.phase,state.clock='blocked',0;return false end
    state.phase,state.clock=phase,0;return true
end
local function door(b)return {x=b.x,y=b.y+1}end
local function hungry(sim,a,offline)
    return not offline and ((a.hunger or 0)>=90 or(a.energy or 100)<=25)and Meals.canEat(sim)
end
local function idle(sim,a,b)
    local p=Sites.breakPoint(sim,b,a.slot)
    if p then go(sim,a,b,p,'walk')end
end
local function compact(sim,a,b,dt,offline)
    -- A historical tight plot may lack an outdoor work/storage pair. Keep
    -- its original indoor routine and nonclaiming porch, without moving it.
    if a.meal then a.breaks=nil;return end
    if(a.workFinishLeft or 0)>0 and not b.stopped and sim:connected(b)then return end
    local reason=Breaks.reason(sim,b);local wantsFood=hungry(sim,a,offline)
    if not a.breaks then
        if not reason or wantsFood or(a.workPresence or 0)<.99 then return end
        local point=Sites.breakPoint(sim,b,a.slot);if not point then return end
        a.breaks={phase='walk',clock=0,point=point,reason=reason}
        if not go(sim,a,b,point,'walk')then a.breaks=nil;return end
    end
    local state=a.breaks;state.clock=state.clock+dt;state.reason=reason
    if(not reason or wantsFood)and state.phase~='return'and state.phase~='blocked'then go(sim,a,b,door(b),'return')end
    if state.phase=='walk'then
        if Move.step(a,dt,.85,sim)then state.phase,state.clock='idle',0 end
    elseif state.phase=='return'then
        if Move.step(a,dt,.85,sim)then a.breaks=nil end
    elseif state.phase=='blocked'and state.clock>=1 then go(sim,a,b,door(b),'return')end
end
function Breaks.update(sim,a,b,dt,offline)
    if not Breaks.kinds[b.kind]then return end
    Sites.ensure(sim,b)
    if not Breaks.outdoor(b)then compact(sim,a,b,dt,offline);return end
    a.workshopOutdoor=true
    if a.meal then a.breaks=nil;return end
    local state=a.breaks
    if not state then
        local point=Sites.breakPoint(sim,b,a.slot)
        state={phase='mealReady',clock=0,point={x=point.x,y=point.y}}
        a.breaks=state
        if not hungry(sim,a,offline)then
            if Breaks.reason(sim,b)then idle(sim,a,b)else go(sim,a,b,Sites.workPoint(b,a.slot),'workApproach')end
        end
    end
    state.clock=state.clock+dt;state.reason=Breaks.reason(sim,b)
    local loaded=a.workLoad~=nil
    if loaded then
        -- Once a recipe commits, stopping, hunger and loss of public road
        -- never discard its output. Private routes retry without teleporting.
        if state.phase=='finish'then
            a.workFinishLeft=math.max(0,1.2-state.clock)
            if state.clock>=1.2 then a.workFinishLeft=0;go(sim,a,b,Sites.pickupPoint(b),'toStorage')end
        elseif state.phase=='toStorage'then
            if Move.step(a,dt,.75,sim)then state.phase,state.clock='stow',0 end
        elseif state.phase=='stow'and state.clock>=.9 then
            local total=0
            for resource,amount in pairs(a.workLoad.goods)do E.add(b,resource,amount);total=total+amount end
            b.workOutputHeld=math.max(0,(b.workOutputHeld or 0)-total)
            a.workLoad,a.carrying=nil,false
            go(sim,a,b,door(b),'return')
        elseif state.phase=='blocked'and state.clock>=1 then go(sim,a,b,state.target,state.destination)end
        return
    end
    local wantsFood=hungry(sim,a,offline)
    if state.phase=='work'then
        if wantsFood then go(sim,a,b,door(b),'return')
        elseif state.reason then idle(sim,a,b)end
    elseif state.phase=='workApproach'then
        if wantsFood or state.reason then go(sim,a,b,door(b),'return')
        elseif Move.step(a,dt,.85,sim)then state.phase,state.clock='work',0 end
    elseif state.phase=='walk'then
        if wantsFood or not state.reason then go(sim,a,b,door(b),'return')
        elseif Move.step(a,dt,.85,sim)then state.phase,state.clock='idle',0 end
    elseif state.phase=='idle'then
        if wantsFood or not state.reason then go(sim,a,b,door(b),'return')end
    elseif state.phase=='return'then
        if Move.step(a,dt,.85,sim)then
            if wantsFood then state.phase,state.clock='mealReady',0
            elseif state.reason then idle(sim,a,b)
            else go(sim,a,b,Sites.workPoint(b,a.slot),'workApproach')end
        end
    elseif state.phase=='mealReady'then
        if not wantsFood then
            if state.reason then idle(sim,a,b)else go(sim,a,b,Sites.workPoint(b,a.slot),'workApproach')end
        end
    elseif state.phase=='blocked'and state.clock>=1 then go(sim,a,b,state.target,state.destination)end
end
function Breaks.operator(sim,b)
    for slot=1,b.workers do
        local a=sim.workers[b.id..':'..slot]
        if a and not a.meal and not a.workLoad and a.breaks and a.breaks.phase=='work'then
            local p=Sites.workPoint(b,slot)
            if p and math.abs(a.x-p.x)<.001 and math.abs(a.y-p.y)<.001 then return a end
        end
    end
end
function Breaks.canCommit(sim,b)return not Breaks.outdoor(b)or Breaks.operator(sim,b)~=nil end
function Breaks.committed(sim,b,goods,primary)
    if not Breaks.outdoor(b)then return end
    local actor=Breaks.operator(sim,b)
    if not actor then return end
    local load,total={},0
    for resource,amount in pairs(goods)do
        if amount>0 then load[resource]=amount;total=total+amount end
    end
    if total==0 then return end
    actor.workLoad={goods=load,resource=primary}
    actor.carrying,actor.workFinishLeft=true,1.2
    b.workOutputHeld=(b.workOutputHeld or 0)+total
    actor.breaks.phase,actor.breaks.clock='finish',0
    return true
end
return Breaks
