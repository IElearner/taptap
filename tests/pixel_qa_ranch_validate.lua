-- Real caretaker/feeding cycle, tested against independent PNG obstacle bounds.
local Sim=require 'game.Simulation'
local Actors=require 'game.PixelActors'
local A=require 'game.PixelAssets'
V.atFrame(8,function()
    A.loadCatalog()
    local s=Sim.new('finite',23);s.started,s.skipped,s.population=true,true,40;s.stock.food=300
    local b=s:addBuilding('ranch',8,8,true);b.workers,b.inputs=1,6
    local history,previous,phases={},nil,{}
    local inWater,maxStep,visible=0,0,0
    for _=1,1000 do
        s:update(.05);phases[b.ranchPhase or 'inside']=true
        local current
        for _,p in ipairs(Actors.collect(s,history)) do
            if p.building==b and p.key:match('^worker') then current=p end
        end
        if current then
            visible=visible+1
            local x,y=(current.x-b.x)*64+192,(current.y-b.y)*48+176
            -- Body/feet must not stand inside the source water rectangle.
            if x+6>53 and x-6<108 and y+2>153 and y-3<171 then inWater=inWater+1 end
            if previous then maxStep=math.max(maxStep,math.sqrt(((current.x-previous.x)*64)^2+((current.y-previous.y)*48)^2)) end
            previous={x=current.x,y=current.y}
        else previous=nil end
    end
    V.assert(visible>20 and phases.exit and phases.feed and phases['return'] and phases.inside,
        'Actual caretaker exits, feeds, returns and is concealed indoors')
    V.assert(inWater==0,'No visible caretaker foot/body sample enters the independently measured trough')
    V.assert(maxStep<=3.60001,'The complete visible feeding route remains continuous: '..maxStep)
    V.assert((b.feedVisits or 0)>=2 and b.inputs==6-b.feedVisits,
        'Two real feed visits consume one grain each, without altering feeding economics')
end)
V.atFrame(25,function() V.finish() end)
