-- Civilian excursions own real movement, reserved resources and carried goods.
-- Rendering reads these states; it never creates or commits the goods itself.
local D=require 'game.Definitions'
local E=require 'game.Economy'
local Move=require 'game.Movement'
local Sites=require 'game.WorkSites'
local Deposits=require 'game.Deposits'
local Layout=require 'game.PixelLayout'
local Life={}
local function phase(a,name)a.life.phase,a.life.clock=name,0 end
local function hasMealNeed(a)return (a.hunger or 0)>=90 or (a.energy or 100)<=25 end
local function heldInputs(sim,b,resource)
    local n=0
    for _,other in pairs(sim.workers)do
        local r=other.building==b.id and other.life and other.life.reservation
        if r and r.inputs then n=n+(r.inputs[resource]or 0)end
    end
    return n
end
function Life.managed(b)return b and b.lifeEnabled==true end
function Life.working(a)
    local l=a.life
    return l and (l.phase=='fish' or l.phase=='mine' or l.phase=='cut') and l.reservation~=nil
end
function Life.busy(a)
    local l=a.life
    return l and (l.reservation~=nil or l.load~=nil or l.phase~='rest' and l.phase~='mealReady')or false
end
local function route(sim,a,b,target,name)
    if Sites.route(sim,a,b,target)then phase(a,name);return true end
    a.life.retry={x=target.x,y=target.y,phase=name};phase(a,'blocked');return false
end
local function release(b,l)
    if l.reservation then b.lifeOutputHeld=math.max(0,(b.lifeOutputHeld or 0)-l.reservation.amount);l.reservation=nil end
end
local function updateRecipeHold(sim,b,exclude)
    if b.kind~='mason'then return end
    b.processingRecipe=nil
    for _,a in pairs(sim.workers)do
        if a~=exclude and a.building==b.id and a.life and a.life.reservation and a.life.reservation.inputs then b.processingRecipe=b.recipe or 1;break end
    end
end
local function goHome(sim,a,b)
    local site=b.site
    local rest=site.restCells and site.restCells[a.slot]or site.chairCell
    if not route(sim,a,b,rest,'toChair')then
        route(sim,a,b,site.door,'toDoor')
    end
end
local function begin(sim,a,b)
    local l=a.life
    if b.stopped or not sim:connected(b)or not E.canWork(b)then return false end
    -- One physical work station is shared by both shifts; the second worker
    -- waits at a separate rest point instead of occupying the same prop.
    for _,other in pairs(sim.workers)do
        if other~=a and other.building==b.id and not other.meal and Life.busy(other)then return false end
    end
    local outputs=E.outputs(b)
    local resource=next(outputs)
    if not resource then return false end
    local amount=outputs[resource]
    local source
    if b.kind=='mason'then
        if (b.inputGoods.rawstone or 0)-heldInputs(sim,b,'rawstone')<2 then return false end
    else
        if b.legacyOutput then return false end
        source=Deposits.source(sim,b,resource)
        if not source then return false end
        amount=math.min(amount,math.max(0,source.remaining-Deposits.reserved(sim,source.id)))
        if amount<=0 then return false end
    end
    if b.buffer+(b.lifeOutputHeld or 0)+amount>E.capacity(b)then return false end
    l.reservation={resource=resource,amount=amount,sourceId=source and source.id or nil,
        inputs=b.kind=='mason'and {rawstone=2}or nil}
    b.lifeOutputHeld=(b.lifeOutputHeld or 0)+amount
    if b.kind=='mason'then b.processingRecipe=b.recipe or 1 end
    phase(a,'rise');return true
end
local function catch(sim,a,b)
    local l=a.life;local r=l.reservation
    if not r then return false end
    if r.inputs then
        if (b.inputGoods.rawstone or 0)<2 then return false end
        E.consume(b,'rawstone')
        updateRecipeHold(sim,b,a)
    elseif not Deposits.commit(sim,r)then return false end
    l.load={resource=r.resource,amount=r.amount}
    l.reservation=nil;l.workSeconds=math.max(0,(l.workSeconds or 0)-E.period(b));a.carrying=true
    return true
end
local function store(a,b)
    local l=a.life
    if not l.load then return end
    E.add(b,l.load.resource,l.load.amount)
    b.lifeOutputHeld=math.max(0,(b.lifeOutputHeld or 0)-l.load.amount)
    l.load=nil;a.carrying=false
end
local function ride(sim,a,b,outbound)
    local l=a.life
    local dx,dy=Layout.door(b)
    if outbound then
        local path={{x=a.x,y=a.y}}
        local original=l.railRoute or {{x=b.x,y=b.y+1},{x=dx,y=b.y+1},{x=dx,y=dy}}
        local from=l.phase=='rideIn'and math.max(1,(a.index or 1)-1)or #original
        for i=from,1,-1 do path[#path+1]={x=original[i].x,y=original[i].y}end
        a.path,a.index=path,1;phase(a,'rideOut')
    else
        local path={}
        for _,p in ipairs(b.site.railRoute or {{x=b.x,y=b.y+1},{x=dx,y=b.y+1},{x=dx,y=dy}})do path[#path+1]={x=p.x,y=p.y}end
        l.railRoute=path;a.path,a.index=path,1;phase(a,'rideIn')
    end
end
function Life.ensure(sim,a,b)
    if not Sites.managed(b.kind)then return false end
    local site=Sites.ensure(sim,b)
    b.lifeEnabled=site~=nil
    if not site then return false end
    if not a.life then
        a.life={kind=b.kind,phase='toChair',clock=0,workSeconds=0}
        if not b.lifeTimerMoved then a.life.workSeconds=b.timer;b.timer=0;b.lifeTimerMoved=true end
        b.lifeOutputHeld=b.lifeOutputHeld or 0
        goHome(sim,a,b)
    end
    return true
end
-- Waiting cooks use the existing public entrance and a private wall approach.
-- They return to that entrance before either production or dining resumes.
function Life.kitchenIdle(sim,a,b,dt,offline)
    if b.kind~='kitchen'then return end
    local waiting=not b.stopped and sim:connected(b)and E.canWork(b)and not E.hasInputs(b)
    if a.meal then a.lean=nil;return end
    local need=not offline and hasMealNeed(a)and require('game.Meals').availableFood(sim)>0
    if not a.lean then
        if not waiting or need or (a.workPresence or 0)<.99 then return end
        local dx,dy=Layout.door(b)
        local spec=require('game.PixelAssets').buildings[b.kind]
        local p=spec.leanPoint or {36,195}
        local wall={x=b.x+(p[1]-spec.anchorX)/64,y=b.y+(p[2]-spec.anchorY)/48}
        a.lean={phase='walk',clock=0,wall=wall,road={x=b.x,y=b.y+1},door={x=dx,y=dy}}
        a.path={{x=a.x,y=a.y},{x=dx,y=b.y+1},{x=dx,y=dy},wall};a.index=1
    end
    local l=a.lean;l.clock=l.clock+dt
    if (not waiting or need)and l.phase~='return'then
        a.path={{x=a.x,y=a.y},l.door,{x=l.door.x,y=b.y+1},l.road};a.index=1;l.phase='return';l.clock=0
    end
    if l.phase=='walk'and Move.step(a,dt,.8,sim)then l.phase='lean';l.clock=0
    elseif l.phase=='return'and Move.step(a,dt,.8,sim)then a.lean=nil end
end
function Life.step(sim,a,b,dt,offline)
    Life.kitchenIdle(sim,a,b,dt,offline)
    if not Life.ensure(sim,a,b)then return end
    local l,site=a.life,b.site
    if a.meal then l.wasEating=true;return end
    if l.wasEating then l.wasEating=nil;goHome(sim,a,b)end
    l.clock=(l.clock or 0)+dt
    -- Pre-catch cancellation releases reservations. A real caught load always
    -- completes its return/stow, even if the road network is disconnected.
    if l.reservation and (b.stopped or not sim:connected(b)or not E.canWork(b))then
        local inside=l.phase=='mine'or l.phase=='rideIn'
        release(b,l);updateRecipeHold(sim,b,a)
        if inside then ride(sim,a,b,true)
        else goHome(sim,a,b)end
    end
    local p=l.phase
    if p=='rest'then
        if not offline and hasMealNeed(a)and require('game.Meals').availableFood(sim)>0 then
            route(sim,a,b,site.door,'toMeal')
        elseif l.clock>=3+a.slot*.3 then begin(sim,a,b)end
    elseif p=='rise'then
        if l.clock>=.8 then
            if b.kind=='fishery'then route(sim,a,b,site.shoreApproach or site.shoreCell,'toShore')
            elseif b.kind=='mason'then route(sim,a,b,site.tankCell,'toBench')
            else
                route(sim,a,b,site.railRoute and site.railRoute[1]or site.door,'toRail')
            end
        end
    elseif p=='toShore' or p=='toBench'then
        if Move.step(a,dt,.85,sim)then phase(a,p=='toShore'and'cast'or'cut')end
    elseif p=='cast'then
        if l.clock>=1.2 then phase(a,'fish')end
    elseif p=='fish' or p=='mine' or p=='cut'then
        local work=dt*((a.energy or 100)<25 and .6 or 1)
        l.workSeconds=(l.workSeconds or 0)+work
        b.visualWorkSeconds=(b.visualWorkSeconds or 0)+work
        if l.workSeconds>=E.period(b)then
            if p=='fish'then phase(a,'reel')
            elseif catch(sim,a,b)then
                if p=='mine'then ride(sim,a,b,true)
                else route(sim,a,b,site.compound and Sites.pickupPoint(b)or site.stackCell or site.tankCell,'toStack')end
            end
        end
    elseif p=='reel'then
        if l.clock>=.35 and l.reservation then
            if not catch(sim,a,b)then release(b,l);goHome(sim,a,b);return end
        end
        if l.clock>=1.4 then route(sim,a,b,Sites.pickupPoint(b)or site.tankCell,'toTank')end
    elseif p=='toRail'then
        if Move.step(a,dt,.85,sim)then ride(sim,a,b,false)end
    elseif p=='rideIn'then
        if Move.step(a,dt,.75,sim)then phase(a,'mine')end
    elseif p=='rideOut'then
        if Move.step(a,dt,.75,sim)then
            if l.load then route(sim,a,b,site.compound and Sites.pickupPoint(b)or site.tankCell,'toTank')else goHome(sim,a,b)end
        end
    elseif p=='toTank'or p=='toStack'then
        if Move.step(a,dt,.8,sim)then phase(a,'stow')end
    elseif p=='stow'then
        if l.clock>=.9 then store(a,b)end
        if l.clock>=1.2 then goHome(sim,a,b)end
    elseif p=='toChair'then
        if Move.step(a,dt,.9,sim)then phase(a,'rest')end
    elseif p=='toMeal'then
        if Move.step(a,dt,.9,sim)then phase(a,'mealReady')end
    elseif p=='mealReady'then
        if l.clock>1 and (offline or not hasMealNeed(a)or require('game.Meals').availableFood(sim)==0)then goHome(sim,a,b)end
    elseif p=='blocked'then
        if l.clock>=1 and l.retry then local r=l.retry;l.retry=nil;route(sim,a,b,r,r.phase)end
    elseif p=='toDoor'then
        if Move.step(a,dt,.9,sim)then phase(a,'rest')end
    end
end
function Life.action(a)
    local l=a.life
    if not l or a.meal then return end
    local phases={rest='rest',rise='rise',cast='cast',fish='wait',reel='reel',stow='stow',cut='cut',rideIn='ride',rideOut='ride',mine='mine'}
    if l.phase=='rest'and a.slot>1 then return 'stand'end
    return phases[l.phase]
end
return Life
