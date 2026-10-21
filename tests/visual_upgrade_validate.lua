local Game=require 'network.Standalone'
local Animation=require 'game.DirectionalAnimation'
local Catalog=require 'game.PaintedArchitectureManifest'
local Meals=require 'game.Meals'
local sim,view,hall,ranch
V.atFrame(8,function()
    Game.UseStore(require('game.SaveStore').new({now=function() return 1000 end,read=function() return nil end,write=function() return true end}),true)
    local hud;sim,view,hud=Game.Inspect();hud.dismissIntro();sim,view,hud=Game.Inspect();hud.dismissIntro()
    sim.started,sim.skipped,sim.population=true,true,40;sim.stock.food=200
    hall=sim:addBuilding('kitchen',8,8,true);hall.workers=1;hall.inputs=4;hall.mealStock=8
    ranch=sim:addBuilding('ranch',15,8,true);ranch.workers=1;ranch.inputs=4
    sim.carriers[4]={x=10,y=9,path={},index=1,job=false,carrying=false,hunger=100,energy=20,workerLook=2}
    for _,a in ipairs(sim.carriers) do a.hunger=100 end
    for _=1,400 do
        sim:update(.1)
        local seated=0;for _,a in ipairs(sim.carriers) do if a.meal and a.meal.phase=='eat' then seated=seated+1 end end
        if seated==4 then break end
    end
    sim.paused=true;hud.update()
end)
V.atFrame(20,function()
    local count=0
    for kind,spec in pairs(Catalog) do
        count=count+1
        V.assert(cache:GetResource('Material',spec.material)~=nil,'New architecture material loads: '..kind)
        V.assert(spec.width>300 and spec.height>150,'Production artwork has a real source rectangle: '..kind)
    end
    V.assert(count==10,'Every non-field building has its own upgraded architecture')
    local world=view.modelWorld
    for _,b in ipairs({sim.buildings[1],hall,ranch}) do
        local record=world.buildings[b.id]
        V.assert(record and record.painted and record.painted.draw.material~=nil,'Actual running world uses the new building: '..b.kind)
        local shell=record.node:GetChild('AuthoredBuilding'):GetChild('ArchitectureMesh')
        V.assert(not shell or not shell.enabled,'The obsolete shell does not draw over the new building: '..b.kind)
        V.assert(not shell or not shell:GetComponent('StaticModel').enabled,'The old shell drawable is explicitly disabled: '..b.kind)
        V.assert(record.stockRoot~=nil,'Physical inventory survives the visual replacement: '..b.kind)
    end
    local room=world.buildings[hall.id]
    V.assert(#room.chairs==4 and Meals.occupancy(sim,hall.id)==4,'Four actual meals still occupy four real dining places')
    local previousX,previousY
    for seat=1,4 do
        local x,y=Meals.seatPosition(hall,seat)
        V.assert(not previousX or x-previousX>.15 and math.abs(y-previousY)<.001,'Diners occupy four separate indoor places behind the facade')
        previousX,previousY=x,y
    end
    local pen=world.buildings[ranch.id]
    V.assert(#pen.pigs==3,'The ranch still owns three independent animals')
    for i,pig in ipairs(pen.pigs) do
        V.assert(pig.art and pig.art.draw.material~=nil,'The original pig motion atlas is actually rendered: '..i)
        V.assert(pig.art.direction>=1 and pig.art.direction<=8,'Each pig has a valid facing direction')
        V.assert(pig.penU>=.52 and pig.penU<=.86 and pig.penV>=.64 and pig.penV<=.66,'The pig stays inside its illustrated paddock lane, clear of the complete front fence and posts')
    end
    for key,r in pairs(world.roads) do
        V.assert(#r.node:GetChildren()<=6,'Road geometry is bounded at every junction: '..key)
        if not r.planned then V.assert(r.node:GetChild('SurveyStake')==nil,'Finished roads have no survey stakes') end
    end
    V.assert(math.abs(Animation.turn(170,-170,.01)-170)<=5.41,'Turns use the short angle and obey an angular speed limit')
    V.assert(Animation.turn(0,180,.05)==180,'An about-turn never leaves a worker walking backwards along the return route')
    V.assert(Animation.stableDirection(204,1)==1 and Animation.stableDirection(211,1)~=1,'Small heading noise does not chatter between directional rows')
    local actor={x=11,y=11,phase='idle',timer=0,facing='sw',workerLook=1,carrying=false,job={resource='wood'}}
    local _,profile=require('game.Characters').carrier(1,false,actor)
    world:person('upgradeProbe',actor,profile,nil,11,11,1)
    local p=world.actors.upgradeProbe;local node=p.node;local size=p.quad.size
    actor.meal=false
    world:person('upgradeProbe',actor,profile,false,11,11,1)
    V.assert(world.actors.upgradeProbe.node==node and p.directional,'A false idle predicate after eating never replaces the worker with an old low-detail model')
    actor.carrying,actor.phase=true,'toSite';sim.elapsed=sim.elapsed+.05
    world:person('upgradeProbe',actor,profile,nil,11,11,1)
    V.assert(p.previousNode.enabled and p.actionKey=='carry','Carry begins with a retained previous pose instead of a replacement body')
    sim.elapsed=sim.elapsed+.09;world:person('upgradeProbe',actor,profile,nil,11,11,1)
    V.assert(p.quad.color.a>.2 and p.quad.color.a<.8,'Action change passes through an actual intermediate blend')
    V.assert(p.node==node and p.quad.size.x==size.x and p.quad.size.y==size.y,'Transitions preserve the same character, ground pivot and world scale')
    sim.elapsed=sim.elapsed+.2;world:person('upgradeProbe',actor,profile,nil,11,11,1)
    V.assert(not p.previousNode.enabled and p.quad.color.a==1,'The transition finishes with exactly one visible pose')
    for _,resource in ipairs({'wood','stone','grain','flour','meat','gold','food'}) do
        actor.job.resource=resource;world:person('upgradeProbe',actor,profile,nil,11,11,1)
        V.assert(p.node==node and p.load.enabled,'Every replaceable cargo retains the same person: '..resource)
    end
    V.finish()
end)
