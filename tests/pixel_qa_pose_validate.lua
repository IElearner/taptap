-- Repeat-render and motion continuity against real new-game construction.
local Sim=require 'game.Simulation'
local Actors=require 'game.PixelActors'
local A=require 'game.PixelAssets'
V.atFrame(8,function()
    A.loadCatalog()
    local s=Sim.new('finite',23);s.started,s.skipped=true,true
    local ok=s:build('house',8,8)
    V.assert(ok,'Pose regression follows actual new-game construction')
    local history,previous={},{}
    local maxRepeat,maxStep,seenHammer,framesStable=0,0,false,true
    for _=1,1000 do
        s:update(.05)
        local first=Actors.collect(s,history)
        local indexed={}
        for _,a in ipairs(first) do
            indexed[a.key]=a
            if a.action=='hammer' then seenHammer=true end
            local before=previous[a.key]
            if before then maxStep=math.max(maxStep,math.sqrt(((a.x-before.x)*64)^2+((a.y-before.y)*48)^2)) end
        end
        local second=Actors.collect(s,history)
        for _,a in ipairs(second) do
            local b=indexed[a.key]
            if b then
                maxRepeat=math.max(maxRepeat,math.abs(a.x-b.x)+math.abs(a.y-b.y))
                if a.frame~=b.frame or a.action~=b.action or a.look~=b.look then framesStable=false end
            end
        end
        previous=indexed
    end
    V.assert(seenHammer,'Continuity checks include genuine construction contact phases')
    V.assert(maxRepeat<.0000001,'Rendering twice without simulation time never teleports an actor: '..maxRepeat)
    V.assert(framesStable,'Pause/repeated render preserves frame, action and identity')
    V.assert(maxStep<=3.60001,'Consecutive visible poses follow the registered approach at bounded walking speed: '..maxStep)
    V.assert(s:buildingAt(8,8).complete,'Visual projection leaves actual house completion intact')
end)
V.atFrame(25,function() V.finish() end)
