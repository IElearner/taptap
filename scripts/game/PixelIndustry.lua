local A=require 'game.PixelAssets'
local D=require 'game.Definitions'
local Farm=require 'game.FarmCycle'
local Meals=require 'game.Meals'
local E=require 'game.Economy'
local Industry={}
local warmth=setmetatable({},{__mode='k'})
local goods=A.goods
local Breaks=require 'game.WorkBreaks'
function Industry.working(sim,b)
    return not b.stopped and sim:connected(b) and (b.activeWorkers or 0)>0 and (b.workRate or 0)>0
        and E.canWork(b) and E.hasInputs(b) and E.canProduce(b) and E.resourceAvailable(sim,b)
end
function Industry.tool(b)
    if b.kind=='smelter' then return 'furnace' end
    if b.kind=='ironweapons' then return 'spear' end
    if b.kind=='ironarmor' then return 'plate' end
    if b.kind=='tannery' then return 'scrape' end
    if b.kind=='leatherarmor' then return 'stitch' end
    if b.kind=='woodweapons' then return 'bow' end
    if b.kind=='mason' or b.kind=='quarry' then return 'stone' end
    if D.buildings[b.kind].deposit then return b.kind=='fishery' and 'net' or 'pick' end
end
local function tools(vg,b,left,top,spec)
    local p=spec.toolPoint or spec.workPoint or {128,174}
    local x,y=left+p[1],top+p[2]
    local beat=math.floor((b.timer or 0)*4)%4
    local tool=Industry.tool(b)
    local function box(dx,dy,w,h,r,g,blue)
        nvgBeginPath(vg);nvgRect(vg,math.floor(x+dx),math.floor(y+dy),w,h)
        nvgFillColor(vg,nvgRGBA(r,g,blue,255));nvgFill(vg)
    end
    if tool=='furnace' then
        for i=0,2 do box(-11+i*4,-8-beat,3,5+beat,248,124+i*28,48) end
    elseif tool=='spear' then
        box(-17,-5,32,2,154,119,71);box(12,-7,5,5,198,209,202)
        if beat==1 then box(-1,-9,2,3,255,192,72) end
    elseif tool=='plate' then
        box(-10,-9,17,10,104,127,139);box(-6,-11,9,2,190,204,203)
        if beat==1 then box(8,-8,2,3,255,192,72) end
    elseif tool=='scrape' then
        box(-13,-5,24,7,153,102,62);box(-9+beat*4,-8,6,2,206,205,173)
    elseif tool=='stitch' then
        box(-11,-7,20,10,138,86,51);box(-8+beat*4,-9,1,5,222,210,159)
    elseif tool=='bow' then
        box(-12,-6,23,2,180,135,70);box(-12,-10,2,4,180,135,70);box(9,-10,2,4,180,135,70)
        box(-10,-10,19,1,215,205,154)
    elseif tool=='stone' or tool=='pick' then
        box(-9,-3,16,7,118,127,132)
        if beat==1 then box(-11,-7,2,2,204,203,176);box(8,-5,2,2,204,203,176) end
    elseif tool=='net' then
        for i=0,3 do box(-18+i*8,-12+beat,1,14,205,196,142);box(-18,-12+i*4+beat,25,1,205,196,142) end
    end
end
function Industry.pigPose(b,index,clock)
    if index==1 then
        local p=0
        if b.ranchPhase=='exit' then p=1-(b.ranchClock or 0)/2.8
        elseif b.ranchPhase=='feed' then p=1
        elseif b.ranchPhase=='return' then p=(b.ranchClock or 0)/2.8 end
        p=math.max(0,math.min(1,p))
        local x=118+4*math.min(1,p/.4)
        local y=148+14*math.max(0,(p-.4)/.6)
        local direction=b.ranchPhase=='feed' and 1 or b.ranchPhase=='return' and (p>.4 and 3 or 1) or (p>.4 and 0 or 2)
        return x,y,direction
    end
    local t=(clock*.12+index*.9)%4
    local triangle=t<2 and t-1 or 3-t
    return (index==2 and 153 or 185)+triangle*(index==2 and 1 or 2),index==2 and 162 or 169,t<2 and 2 or 1
end
function Industry.buildingPath(b,default)
    if b.kind=='farm' and b.complete then
        local stages={seed=0,sprout=1,green=2,ripe=3}
        return 'buildings/farm-'..stages[Farm.stage(b,D.buildings.farm.period)]..'.png'
    end
    if b.lifeEnabled and cache:Exists(A.root..'life/'..b.kind..'.png')then return 'life/'..b.kind..'.png'end
    return default
end
function Industry.add(sim,objects,project,vg)
    for _,b in ipairs(sim.buildings) do if b.complete then
        local px,py=project(b.x,b.y);local spec=A.buildings[b.kind]
        local left,top=px-spec.anchorX,py-spec.anchorY
        local running=Industry.working(sim,b)
        if running then warmth[b]=sim.elapsed end
        local heat=math.max(0,1-(sim.elapsed-(warmth[b]or -100))/2.5)
        if b.kind=='ranch' then
            for i=1,3 do
                local x,y,dir=Industry.pigPose(b,i,sim.elapsed)
                objects[#objects+1]={depth=py+23,draw=function()
                    A.draw(vg,'pigs.png',left+x-16,top+y-28,32,32,dir,0,4,1)
                end}
            end
            objects[#objects+1]={depth=py+25,draw=function() A.draw(vg,'buildings/ranch-foreground.png',left,top,256,224) end}
        elseif b.kind=='sawmill' or b.kind=='bakery' then
            -- Work moves only while the actual production timer advances.
            if Industry.working(sim,b) then
                objects[#objects+1]={depth=py+23,draw=function()
                    if b.kind=='sawmill' then
                        local point=spec.sawPoint or {104,160}
                        local offset=math.floor(math.sin((b.timer or 0)*9)*4)
                        nvgBeginPath(vg);nvgRect(vg,left+point[1]-14+offset,top+point[2],27,2)
                        for tooth=0,8 do nvgRect(vg,left+point[1]-13+offset+tooth*3,top+point[2]+2,1,2) end
                        nvgFillColor(vg,nvgRGBA(211,211,180,255));nvgFill(vg)
                    else
                        local point=spec.ovenPoint or {83,164}
                        for spark=1,3 do
                            local beat=math.floor((b.timer or 0)*5+spark)%3
                            nvgBeginPath(vg);nvgRect(vg,left+point[1]-5+spark*3,top+point[2]-beat,2,3+beat)
                            nvgFillColor(vg,nvgRGBA(242,148+beat*22,54,230));nvgFill(vg)
                        end
                    end
                end}
            end
        elseif b.kind=='mill'then
            -- A mark on the horizontal millstone follows actual worked seconds.
            local angle=(b.visualWorkSeconds or b.timer or 0)*.9
            objects[#objects+1]={depth=py+23,draw=function()
                local point=spec.millCenter or {154,165}
                local x,y=left+point[1],top+point[2]
                for i=0,2 do
                    local a=angle+i*math.pi*2/3
                    nvgBeginPath(vg);nvgMoveTo(vg,x,y);nvgLineTo(vg,x+math.cos(a)*11,y+math.sin(a)*4)
                    nvgStrokeColor(vg,nvgRGBA(123,113,94,255));nvgStrokeWidth(vg,1);nvgStroke(vg)
                end
            end}
        elseif b.kind=='kitchen' then
            if heat>0 then
                objects[#objects+1]={depth=py+26,draw=function()
                    for i=1,3 do
                        local t=(sim.elapsed*.6+i/3)%1
                        local size=2+math.floor(t*3)
                        local chimney=spec.chimney or {210,89}
                        nvgBeginPath(vg);nvgRect(vg,left+chimney[1]+math.floor(t*5),top+chimney[2]-math.floor(t*27),size,size)
                        nvgFillColor(vg,nvgRGBA(238,222,180,math.floor((1-t)*190*heat)));nvgFill(vg)
                    end
                end}
            end
            objects[#objects+1]={depth=py+25,draw=function()
                A.draw(vg,'buildings/kitchen-foreground.png',left,top,256,224)
                for seat=1,4 do
                    local a=Meals.occupant(sim,b.id,seat)
                    if a and a.meal.phase=='eat' then
                        local p=spec.seats and spec.seats[seat]
                        if p then
                        A.draw(vg,'meal-bowl.png',left+p[1]-4,top+171,8,8)
                        end
                    end
                end
            end}
        end
        if not b.lifeEnabled and not Breaks.outdoor(b)and Industry.tool(b) and Industry.working(sim,b) then
            objects[#objects+1]={depth=py+24,draw=function() tools(vg,b,left,top,spec) end}
        end
        -- Keep mixed byproducts and returned ingredients typed on the shelf.
        local display={}
        if b.kind=='store' then
            local delivered=sim.warehouseDisplay
            if delivered and sim.elapsed-delivered.at<4 then
                for _=1,math.min(3,delivered.amount) do display[#display+1]=delivered.resource end
            end
        else
            for _,resource in ipairs(D.goods) do
                if E.outputAmount(b,resource)>0 then display[#display+1]=resource end
            end
            local first=display[1]
            if #display==1 then for _=2,math.min(3,E.outputAmount(b,first)) do display[#display+1]=first end end
        end
        if #display>0 and not b.lifeEnabled and not Breaks.outdoor(b)then
            objects[#objects+1]={depth=py+29,draw=function()
                for n=1,math.min(3,#display) do
                    A.draw(vg,'cargo.png',left+spec.doorX+8+(n-1)*12,top+190,16,16,goods[display[n]] or 0,0,A.cargoColumns,1)
                end
            end}
        end
    end end
end
return Industry
