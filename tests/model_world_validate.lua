local Game=require "network.Standalone"
local Data=require "game.SaveData"
local Art=require "game.Art"
local originalDraw=Art.draw
local worldSprites=0
Art.draw=function(vg,name,...)
    if name:match("^person%-") or name:match("^building%-") or name:match("^construction%-") or name:match("^ground%-") then worldSprites=worldSprites+1 end
    return originalDraw(vg,name,...)
end
local sim,view,snapshot,building,armBefore
V.atFrame(8,function()
    Game.UseStore(require("game.SaveStore").new({now=function() return 1000 end,
        read=function() return nil end,write=function() return true end}),true)
    local hud
    sim,view,hud=Game.Inspect();hud.dismissIntro()
    sim,view,hud=Game.Inspect();hud.dismissIntro();sim.skipped=true
    -- Reach a spacious site without crossing its future footprint.
    for _,p in ipairs({{7,9},{6,9},{6,8},{6,7},{6,6}}) do
        sim.roads[p[1] .. ":" .. p[2]]=true;sim.roadCount=sim.roadCount+1
    end
    V.assert(sim:build("house",6,5),"A site with access to all four faces is placed")
    building=sim:buildingAt(6,5)
    local reached=false
    for _=1,450 do
        sim:update(0.1)
        local hammering=0
        for _,a in ipairs(sim.builders) do if a.phase=="hammer" then hammering=hammering+1 end end
        if hammering==4 then reached=true;break end
    end
    V.assert(reached and not building.complete,"Four workers arrive before the shared job is complete")
    local sides,spots={},{}
    for _,a in ipairs(sim.builders) do
        local j=a.job
        V.assert(j and j.kind=="building" and j.workX==a.x and j.workY==a.y,"Worker really stands at its reserved work tile")
        V.assert(not sim:buildingAt(math.floor(a.x+0.5),math.floor(a.y+0.5)),"Worker stays outside the building footprint")
        V.assert(not spots[a.x .. ":" .. a.y],"Workers have distinct construction positions")
        spots[a.x .. ":" .. a.y]=true;sides[j.side]=true
    end
    V.assert(sides.south and sides.north and sides.east and sides.west,"An accessible site is built from all four sides")
    snapshot=Data.capture(sim,1000,1,true)
    V.assert(Data.restore(cjson.decode(cjson.encode(snapshot)),"finite")~=nil,"Perimeter paths and working positions survive save/load")
    local corrupt=cjson.decode(cjson.encode(snapshot))
    corrupt.world.builders[2].job.workX=corrupt.world.builders[1].job.workX
    corrupt.world.builders[2].job.workY=corrupt.world.builders[1].job.workY
    V.assert(not Data.restore(corrupt,"finite"),"A corrupted save cannot overlap two reserved work positions")
    sim.paused=true
    local camera=view.cameraState()
    view.panel.props.onPanMove({deltaX=4.5*56*camera.zoom,deltaY=4.5*42*camera.zoom})
    hud.update()
end)
V.atFrame(12,function()
    local model=view.modelWorld
    V.assert(model and model.scene and model.camera.orthographic,"The game renders a real scene through an orthographic camera")
    local site=model.buildings[building.id]
    V.assert(site and site.node:GetChild("Foundation") and site.node:GetChild("TimberPost"),"Construction contains separate mesh foundations and timber members")
    for i=1,4 do
        local worker=model.actors["builder" .. i]
        V.assert(worker and worker.node:GetChild("Head") and worker.shoulders[2] and worker.tool.enabled,"Each construction worker is an articulated mesh with a physical hammer")
    end
    local rotation=model.actors.builder1.shoulders[2].rotation
    armBefore={rotation.x,rotation.y,rotation.z,rotation.w}
    sim.elapsed=sim.elapsed+0.5
end)
V.atFrame(16,function()
    local rotation=view.modelWorld.actors.builder1.shoulders[2].rotation
    V.assert(math.abs(rotation.x-armBefore[1])+math.abs(rotation.y-armBefore[2])+math.abs(rotation.z-armBefore[3])+math.abs(rotation.w-armBefore[4])>0.01,
        "The hammer stroke rotates real joints over time")
    V.assert(worldSprites==0,"World rendering does not request people, terrain or building sprites")
    local restored=Data.restore(cjson.decode(cjson.encode(snapshot)),"finite")
    local oldPopulation=restored.population
    for _=1,500 do restored:update(0.1) end
    V.assert(restored.buildings[building.id].complete and restored.population==oldPopulation+4,"Resumed crew completes the building exactly once")
    for _,a in ipairs(restored.builders) do V.assert(not a.active and restored.roads[math.floor(a.x+0.5) .. ":" .. math.floor(a.y+0.5)],"Workers walk back to the road network after completing the site") end
end)
V.atFrame(45,function() Art.draw=originalDraw;V.finish() end)
