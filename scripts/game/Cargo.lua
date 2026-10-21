-- Presentation registry. Goods production, save data and worker identity do
-- not depend on a particular carried mesh. New goods can register a profile.
local Cargo={doorSeconds=2.0}
-- New excursions match the registered pixel courtyard. Restored excursions
-- without doorDuration retain their original two-second timeline.
function Cargo.duration(building)
    if building and building.kind=='kitchen' then return 6.5 end
    if building and (building.footprintW or 1)>=3 then return 2.8 end
    return Cargo.doorSeconds
end
function Cargo.phaseBuilding(sim,actor,phase)
    local job=actor.job
    if not job then return nil end
    if phase=='packing' then return job.inbound and sim.buildings[1] or job.b end
    if job.inbound then return job.b end
    return job.destination or sim.buildings[1]
end
Cargo.profiles={
    livestock={mesh="pigCrate",halfGrip=.135,handY=.13,handZ=.17},
    rawwood={mesh="logBundle",halfGrip=.13,handY=.13,handZ=.17},
    bread={mesh="foodBasket",halfGrip=.14,handY=.13,handZ=.17},
    wood={mesh="planks",halfGrip=.135,handY=.13,handZ=.17},
    stone={mesh="stoneSack",halfGrip=.13,handY=.13,handZ=.17},
    grain={mesh="sacks",halfGrip=.13,handY=.13,handZ=.17},
    flour={mesh="flourSack",halfGrip=.13,handY=.13,handZ=.17},
    meat={mesh="meatBasket",halfGrip=.14,handY=.13,handZ=.17},
    gold={mesh="coinChest",halfGrip=.13,handY=.13,handZ=.17},
    food={mesh="foodBasket",halfGrip=.14,handY=.13,handZ=.17},
    default={mesh="crate",halfGrip=.135,handY=.13,handZ=.17},
}
Cargo.aliases={coins="gold",coin="gold",money="gold",wheat="grain",rice="grain"}
function Cargo.resource(actor)
    local name=actor and actor.workLoad and actor.workLoad.resource or actor and actor.life and actor.life.load and actor.life.load.resource or actor and actor.job and actor.job.resource or "wood"
    return Cargo.aliases[name] or name
end
function Cargo.profile(actor)
    if actor.woodPhase=="toCamp" or actor.woodPhase=="gather" or actor.woodPhase=="toRack" or actor.woodPhase=="stack" then return {mesh="logBundle",halfGrip=.13,handY=.13,handZ=.17} end
    return Cargo.profiles[Cargo.resource(actor)] or Cargo.profiles.default
end
function Cargo.apply(person,actor)
    local carrying=actor.carrying==true
    person.load.enabled=carrying
    local profile=Cargo.profile(actor)
    for key,node in pairs(person.cargo or {}) do node.enabled=carrying and key==profile.mesh end
    return profile
end
-- The simulated carrier stays on a road tile; only its presentation crosses
-- the doorway. Inventory changes at the hidden midpoint of this excursion.
function Cargo.doorPose(actor,x,y)
    if not actor.job or (actor.phase~="packing" and actor.phase~="unload") then return x,y,false end
    local t=math.max(0,math.min(1,1-(actor.timer or 0)/(actor.doorDuration or Cargo.doorSeconds)))
    local depth=math.sin(t*math.pi)
    return x,y-.62*depth,t>=.39 and t<=.61
end
-- Offsets are measured from the actor foot. Back loads are drawn behind a
-- front-facing body; baskets stay below the hands and never cover the head.
local sacks={grain=true,flour=true,rawstone=true,stone=true,ironore=true,coal=true,goldore=true,hide=true,leather=true}
local shoulder={wood=true,rawwood=true,ironspear=true,bow=true}
function Cargo.pixelPose(resource,direction)
    local d=direction or 0
    if shoulder[resource]then
        return {family='shoulder',x=d==1 and -23 or d==2 and 8 or -19,y=-18,behind=d==0 or d==1}
    elseif sacks[resource]then
        return {family='back',x=d==1 and -1 or d==2 and -15 or -8,y=-16,behind=d~=3}
    end
    return {family='basket',x=d==1 and -21 or d==2 and 6 or -8,y=d==3 and -14 or -10,behind=d==3}
end
return Cargo
