local Sim=require 'game.Simulation'
local Actors=require 'game.PixelActors'
local Combat=require 'game.PixelCombat'
V.atFrame(8,function()
    local s=Sim.new('infinite');s.started=true;s.militia=3;s.raid=true
    s.enemies={{x=12,y=9,hp=3}}
    local history={}
    V.assert(#Combat.update(s,history)==0,'An unharmed raider does not emit invented hit effects')
    for i=1,5 do s:update(.25) end
    local hits=Combat.update(s,history)
    V.assert(s.enemies[1].hp==0 and #hits==1 and hits[1].damage==3,'A real defence HP reduction produces a matching impact, including a lethal hit')
    local age=hits[1].age
    V.assert(Combat.update(s,history)[1].age==age,'Repeated rendering does not restart the hit event')
    s.elapsed=s.elapsed+1
    V.assert(#Combat.update(s,history)==0,'Impact feedback ends after its short display interval')
    local positions,guards={},0
    for _,p in ipairs(Actors.collect(s,{})) do
        if p.faction=='guard' then guards=guards+1;positions[p.x..':'..p.y]=true end
    end
    local distinct=0;for _ in pairs(positions) do distinct=distinct+1 end
    V.assert(guards==3 and distinct==3,'Three real militia remain individually visible in the defence formation')
    V.assert(s.guards[1].x==10 and s.guards[2].x==10,'Visual spacing never changes the simulation defence coordinates')
end)
V.atFrame(25,function() V.finish() end)
