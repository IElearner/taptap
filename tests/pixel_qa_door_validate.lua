-- Independent actual-meal geometry and real JSON recovery regression.
-- Door point measured from the approved left-door kitchen PNG, not tool targets.
local Sim=require 'game.Simulation'
local Actors=require 'game.PixelActors'
local Assets=require 'game.PixelAssets'
local Data=require 'game.SaveData'
local Meals=require 'game.Meals'
V.atFrame(8,function()
    Assets.loadCatalog()
    local s=Sim.new('finite',23);s.started,s.skipped,s.population=true,true,40
    s.stock.food=300
    local hall=s:addBuilding('kitchen',8,8,true)
    hall.workers,hall.mealStock=0,8
    for i,a in ipairs(s.carriers) do a.hunger=i==1 and 100 or 0 end
    local dx,dy=hall.x+(49-192)/64,hall.y+(194-176)/48
    local function distance(x,y) return math.sqrt(((x-dx)*64)^2+((y-dy)*48)^2) end
    local history,previous,saved={},nil,{}
    local entryMiss,exitMiss,maxStep,entries,exits=0,0,0,0,0
    local seenEat,finished=false,false
    for _=1,1200 do
        s:update(.05)
        local a=s.carriers[1]
        local phase=a.meal and a.meal.phase or 'none'
        local current
        for _,p in ipairs(Actors.collect(s,history)) do
            if p.key=='carrier1' then current={x=p.x,y=p.y,phase=phase} end
        end
        if current and previous then
            maxStep=math.max(maxStep,math.sqrt(((current.x-previous.x)*64)^2+((current.y-previous.y)*48)^2))
        elseif not current and previous and previous.phase=='enter' and phase=='enter' then
            entries=entries+1;entryMiss=math.max(entryMiss,distance(previous.x,previous.y))
        elseif current and not previous and phase=='exit' and seenEat then
            exits=exits+1;exitMiss=math.max(exitMiss,distance(current.x,current.y))
        end
        previous=current
        if phase=='eat' then seenEat=true end
        if seenEat and not a.meal then finished=true end
        if (phase=='enter' or phase=='eat' or phase=='exit') and not saved[phase] then
            saved[phase]=true
            local bundle=cjson.decode(cjson.encode(Data.capture(s,1000,1,true)))
            local restored=Data.restore(bundle,'finite')
            V.assert(restored~=nil,'Actual '..phase..' survives real JSON save/load')
            if restored then
                local m=restored.carriers[1].meal
                V.assert(m and m.phase==phase and m.timer==a.meal.timer and m.paid,
                    'Paid '..phase..' retains the exact remaining timer')
                V.assert(Meals.availableFood(restored)==Meals.availableFood(s),
                    'Saving '..phase..' preserves distributed food')
                for _=1,1000 do restored:update(.05) end
                V.assert(restored.mealsServed==1 and not restored.carriers[1].meal,
                    'Resumed '..phase..' completes once without a second ration charge')
            end
        end
    end
    V.assert(entries>0 and entryMiss<=8,'Entering vanishes at the real left doorway, not midway along the road: '..entryMiss)
    V.assert(exits>0 and exitMiss<=8,'Exiting first appears at the same real doorway: '..exitMiss)
    V.assert(maxStep<=3.60001,'Visible doorway travel stays continuous at 72 px/s: '..maxStep)
    V.assert(seenEat and finished and s.mealsServed==1,'A real hunger-to-meal-to-work cycle completes exactly once')
    print('PIXEL_QA_DOOR',entries,exits,entryMiss,exitMiss,maxStep)
end)
V.atFrame(25,function() V.finish() end)
