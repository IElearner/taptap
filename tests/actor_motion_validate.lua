local Motion=require "game.ActorMotion"
local Sim=require "game.Simulation"
local Data=require "game.SaveData"
local Game=require "network.Standalone"
V.atFrame(8,function()
    local period=Motion.strokeSeconds
    V.assert(Motion.workBetween(0,.55*period)==0,"Raising a hammer contributes no invisible construction work")
    V.assert(Motion.workBetween(.61*period,.70*period)>0,"Work is performed during the visible contact interval")
    V.assert(math.abs(Motion.workBetween(.37,.37+20*period)-20*period)<.00001,"Large offline steps conserve work across whole hammer cycles")
    local s=Sim.new();s.started,s.skipped=true,true
    s:build("house",8,8)
    local site=s:buildingAt(8,8)
    local unloading=false
    for _=1,800 do
        s:update(.025)
        for _,a in ipairs(s.builders) do
            if a.phase=="unload" then
                unloading=true
                V.assert(site.progress==0 and a.carrying,"Delivered planks remain visible before unloading, with no premature progress")
                local restored=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),"finite")
                V.assert(restored~=nil,"A save made while putting down materials resumes safely")
                break
            end
        end
        if unloading then break end
    end
    V.assert(unloading,"Builders physically reach the site and enter a distinct unloading state")
    for _=1,math.ceil(Motion.unloadSeconds/.025)+1 do s:update(.025) end
    V.assert((site.deliveredLoads or 0)>0,"Materials appear at the site after the load is put down")
    local _,view=Game.Inspect()
    local world=view.modelWorld
    local _,profile=require("game.Characters").carrier(1,false)
    local actor={x=10,y=9,path={},index=1,phase="hammer",timer=.35*period,job={kind="building",side="south"},carrying=false}
    world:person("motionProbe",actor,profile,"hammer",10,9,0)
    local p=world.actors.motionProbe
    V.assert(p.tool.parent==p.hands[2] and p.hands[2].parent==p.elbows[2],"A hammer is attached to the wrist at the actual end of the forearm")
    V.assert(p.shoulders[1].parent==p.body and p.torso.parent==p.body,"Shoulders and torso share the bending upper body")
    V.assert(p.feet[1] and p.hands[1]:GetChild("Grip"),"Worker has separate articulated hands and shoes")
    local hand=p.hands[2].worldPosition
    actor.timer=.68*period
    world:person("motionProbe",actor,profile,"hammer",10,9,0)
    V.assert((p.hands[2].worldPosition-hand):Length()>.08,"Hammer recovery and impact use distinct physical hand positions")
    for _,action in ipairs({"plow","tend","water","harvest","eat"}) do
        actor.phase="idle";world.sim.elapsed=1
        world:person("motionProbe",actor,profile,action,10,9,0)
        local before=p.hands[2].worldPosition
        local beforeRotation=p.hands[2].worldRotation
        world.sim.elapsed=2.25
        world:person("motionProbe",actor,profile,action,10,9,0)
        local afterRotation=p.hands[2].worldRotation
        local changed=(p.hands[2].worldPosition-before):Length()>.001 or
            math.abs(afterRotation.x-beforeRotation.x)+math.abs(afterRotation.y-beforeRotation.y)>.01
        V.assert(changed,"Actual articulated interaction changes over time: " .. action)
    end
    actor.carrying=true;actor.phase="toSite"
    world:person("motionProbe",actor,profile,nil,10,9,0)
    V.assert((p.hands[1].worldPosition-p.hands[2].worldPosition):Length()>.22,"Both hands support opposite ends of a carried load")
    V.assert(math.abs(p.feet[1].worldPosition.y-.04)<.005,"A standing shoe is planted above the ground rather than rotating with the shin")
    local paused=world.sim.paused
    world.sim.paused=true
    world:person("motionProbe",actor,profile,nil,10.04,9,0)
    local frozen=p.feet[2].worldPosition
    world:person("motionProbe",actor,profile,nil,10.04,9,0)
    V.assert((p.feet[2].worldPosition-frozen):Length()<.00001,"Pausing freezes the current gait instead of snapping a raised shoe to the idle pose")
    world.sim.paused=paused
    p.node:Remove();world.actors.motionProbe=nil
    V.finish()
end)
