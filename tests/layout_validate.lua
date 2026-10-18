local Sim=require "game.Simulation"
local D=require "game.Definitions"
local Data=require "game.SaveData"
local Game=require "network.Standalone"
local view
local function advance(s,seconds)
    for _=1,seconds*10 do s:update(0.1,true) end
end
V.atFrame(8,function()
    local s=Sim.new();s.started,s.skipped=true,true
    local stock=s.stock.wood
    local ok,_,house=s:build("house",6,6)
    V.assert(ok and house.footprintW==3 and house.footprintH==2 and #D.cells(house)==6,"A rectangular house can be planned before any road exists")
    advance(s,30)
    V.assert(not house.complete and house.progress==0,"An isolated plan never gets invisible construction work")
    for _,a in ipairs(s.builders) do V.assert(not a.job,"No worker is assigned to an inaccessible plan") end
    V.assert(s.stock.wood==stock-D.buildings.house.cost.wood,"Planning reserves materials exactly once")
    local saved=Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),"finite")
    V.assert(saved and saved.buildings[house.id].progress==0,"Waiting plans survive save/load")
    for _,p in ipairs({{7,9},{6,9},{6,8},{6,7}}) do V.assert(s:build("road",p[1],p[2]),"The access road can be planned later") end
    advance(s,110)
    V.assert(house.complete and s.population==14,"Completing the road automatically dispatches a crew to the waiting house")
    V.assert(s.stock.wood==stock-D.buildings.house.cost.wood,"Automatic dispatch does not charge construction twice")

    local shaped=Sim.new();shaped.started,shaped.skipped=true,true
    local placed,_,courier=shaped:build("courier",8,8)
    V.assert(placed and #D.cells(courier)==5,"An L-shaped courier really occupies five cells")
    V.assert(shaped:buildingAt(8,7)==nil and shaped:buildingAt(7,7)==courier and shaped:buildingAt(8,8)==courier,"The L-shaped recess is free while both wings reserve their exact tiles")
    shaped.roads["8:6"]=true;shaped.roadCount=shaped.roadCount+1
    V.assert(shaped:build("road",8,7),"A road can use the recess without overlapping the building")
    local restored=Data.restore(cjson.decode(cjson.encode(Data.capture(shaped,1000,1,true))),"finite")
    V.assert(restored and restored:buildingAt(8,7)==nil and #D.cells(restored.buildings[courier.id])==5,"An irregular footprint remains irregular after JSON save/load")
    local bad=cjson.decode(cjson.encode(Data.capture(shaped,1000,1,true)))
    bad.world.buildings[courier.id].footprintCells[2]=bad.world.buildings[courier.id].footprintCells[1]
    V.assert(not Data.restore(bad,"finite"),"Corrupt duplicate mask cells are rejected")
    local legacy=cjson.decode(cjson.encode(Data.capture(shaped,1000,1,true)))
    legacy.world.buildings[courier.id].footprintCells=nil
    legacy.world.buildings[courier.id].footprintW=1;legacy.world.buildings[courier.id].footprintH=1
    V.assert(Data.restore(legacy,"finite")~=nil,"Legacy small buildings keep their old area instead of overwriting neighbors")
    for kind in pairs(D.buildings) do
        if kind~="road" then V.assert(#D.cells(kind)>=4,"New " .. kind .. " is a multi-cell structure") end
    end

    Game.UseStore(require("game.SaveStore").new({now=function() return 1000 end,
        read=function() return nil end,write=function() return true end}),true)
    local live,hud
    live,view,hud=Game.Inspect();hud.dismissIntro()
    live,view,hud=Game.Inspect();hud.dismissIntro();live.skipped=true
    live:addBuilding("house",8,8,true)
    live:addBuilding("courier",14,8,true)
    live:addBuilding("mill",13,12,true)
    V.assert(live:build("house",7,5),"The visual comparison includes a disconnected survey plot")
    live.paused=true;hud.update()
end)
V.atFrame(12,function()
    local live=Game.Inspect()
    local model=view.modelWorld
    local layout=view.panel:GetAbsoluteLayout()
    local camera=view.cameraState()
    local at=model.camera:WorldToScreenPoint(Vector3(-4,0,4))
    local expectedX=0.5+(-4*56*camera.zoom+camera.x)/layout.w
    local expectedY=0.5+(-4*42*camera.zoom+camera.y)/layout.h
    V.assert(math.abs(at.x-expectedX)<0.001 and math.abs(at.y-expectedY)<0.001,"Mesh projection, ground grid and planning labels share exactly the same coordinates")
    local plan=model.buildings[#live.buildings]
    V.assert(plan.planned and plan.node:GetChild("SurveyStake") and not plan.node:GetChild("Foundation"),"Waiting construction renders only survey stakes and its real boundary")
    local l=model.buildings[3].node
    local shape=l:GetChild("AuthoredBuilding")
    V.assert(shape and shape:GetChild("LoadingBay"):GetComponent("StaticModel") and shape:GetChild("MainHall"):GetComponent("StaticModel"),"The L-shaped model has separate mesh wings rather than filling its recess")
    local coordinates={{0,-1,1},{1,0,2},{0,1,4},{-1,0,8}}
    for mask=0,15 do
        live.roads["15:11"]=true
        for _,d in ipairs(coordinates) do
            local enabled=math.floor(mask/d[3])%2==1
            live.roads[15+d[1] .. ":" .. 11+d[2]]=enabled or nil
        end
        model:road(15,11,false,1)
        local road=model.roads["15:11"]
        V.assert(road.mask==mask,"Road mesh supports adjacency mask " .. mask)
        if mask==5 then
            for _,child in ipairs(road.node:GetChildren()) do
                V.assert(math.abs(child.position.x)+child.scale.x/2<0.23,"A straight north-south road has no transverse bar")
            end
        end
    end
    -- Leave one vertical stretch and a corner in the screenshot.
    live.roads["14:11"],live.roads["16:11"]=nil,nil
    for y=9,13 do live.roads["15:" .. y]=true end
    for x=13,15 do live.roads[x .. ":9"]=true end
    live.roads["13:13"]=true;live.roads["14:13"]=true
    live.roadCount=live.roadCount+1
end)
V.atFrame(50,function() V.finish() end)
