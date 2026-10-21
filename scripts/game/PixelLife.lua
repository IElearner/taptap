-- Equipment and stock are read-only projections of the real occupation cycle.
local A=require 'game.PixelAssets'
local E=require 'game.Economy'
local Life={}
local function prop(vg,name,x,y,col,row,rows)
    A.sprite(vg,{path='life/'..name..'.png',width=80,height=72,anchorX=40,anchorY=64,
        frame=col or 0,row=row or 0,cols=4,rows=rows or 5},x,y)
end
local stations={mill={0,0},bakery={1,0},butcher={2,0},sawmill={3,0},woodweapons={3,0},smelter={0,1},ironweapons={0,1},ironarmor={0,1},tannery={1,1},leatherarmor={1,1}}
local heat=setmetatable({},{__mode='k'})
local function box(vg,x,y,w,h,r,g,b,alpha)
    nvgBeginPath(vg);nvgRect(vg,math.floor(x),math.floor(y),w,h)
    nvgFillColor(vg,nvgRGBA(r,g,b,alpha or 255));nvgFill(vg)
end
local function polygon(vg,points,r,g,b,alpha)
    nvgBeginPath(vg)
    for i,p in ipairs(points)do
        if i==1 then nvgMoveTo(vg,math.floor(p[1]+.5),math.floor(p[2]+.5))
        else nvgLineTo(vg,math.floor(p[1]+.5),math.floor(p[2]+.5))end
    end
    nvgClosePath(vg);nvgFillColor(vg,nvgRGBA(r,g,b,alpha or 255));nvgFill(vg)
end
-- Ground, buildings, props and actors share the same world-space plot. These
-- surfaces never create roads, inventory or a second, decorative workplace.
local function court(vg,x,y,w,h,material)
    box(vg,x-3,y+4,w+6,h,46,51,32,55)
    if material=='wood'then
        box(vg,x,y,w,h+4,80,56,34)
        box(vg,x+2,y+1,w-4,h-2,141,103,62)
        for row=0,math.floor((h-5)/6)do
            local sy=y+3+row*6
            local start=x+3-(row%2)*18
            for plank=0,math.ceil(w/36)do
                local sx=math.max(x+3,start+plank*36)
                local right=math.min(x+w-3,start+plank*36+35)
                local width=right-sx
                if width>0 then
                    local grain=(row*13+plank*7)%9
                    box(vg,sx,sy,width,4,145+grain,108+grain,65+grain)
                    box(vg,sx,sy+4,width,1,99,72,43)
                    if width>12 then
                        box(vg,sx+3,sy+1,1,1,86,62,39)
                        box(vg,right-3,sy+1,1,1,86,62,39)
                        if grain<5 then box(vg,sx+7,sy+2,math.min(width-10,8+grain),1,126,91,54,150)end
                    end
                end
            end
        end
        box(vg,x+2,y+h,w-4,2,111,77,43)
        for _,post in ipairs({x+7,x+w-10})do
            box(vg,post,y+h+2,4,6,78,56,36)
            box(vg,post,y+h+2,2,5,146,107,62)
        end
    elseif material=='stone'then
        box(vg,x,y,w,h+2,105,101,79)
        A.pave(vg,x+2,y+2,w-4,h-4)
        box(vg,x+2,y+h-2,w-4,2,158,148,117)
    else
        polygon(vg,{{x+6,y},{x+w-8,y},{x+w,y+7},{x+w-2,y+h-5},{x+w-9,y+h},{x+5,y+h-1},{x,y+h-8},{x+1,y+6}},133,123,84)
        for sy=y+5,y+h-3,7 do for sx=x+4,x+w-5,11 do
            local grain=(math.floor(sx)*17+math.floor(sy)*31)%13
            box(vg,sx,sy,grain%3+1,1,grain<6 and 153 or 113,grain<6 and 139 or 108,grain<6 and 96 or 73,150)
        end end
    end
end
local function fence(vg,x,y,w)
    box(vg,x,y-10,w,2,103,71,40);box(vg,x,y-4,w,2,135,96,53)
    for px=x,x+w,14 do
        box(vg,px,y-14,3,16,87,60,35);box(vg,px,y-14,2,13,179,135,77)
        box(vg,px,y-15,2,1,215,171,106)
    end
end
function Life.outcrop(vg,x,y,resource,remaining,onRoad)
    -- Reuse the terrain's pixel-painted rocks: exposed geology belongs to the
    -- ground, with no floating icon or standing obstacle in a public lane.
    if onRoad then
        local tint=resource=='goldore'and {175,143,75}or resource=='ironore'and {145,107,82}or resource=='coal'and {66,69,61}or {139,137,115}
        for i=0,3 do
            box(vg,x-15+i*9,y-2+(i%2)*3,5,2,tint[1],tint[2],tint[3],remaining and remaining<=0 and 90 or 180)
        end
        return
    end
    box(vg,x-25,y+2,49,4,66,73,43,75)
    A.draw(vg,'rocks.png',x-27,y-33,50,42)
    A.draw(vg,'rocks.png',x+9,y-13,20,17)
    if resource~='rawstone'and(not remaining or remaining>0)then
        local tint=resource=='goldore'and {195,153,68}or resource=='ironore'and {164,102,65}or {57,62,57}
        for _,p in ipairs({{-13,-10,5},{-7,-19,3},{3,-7,6}})do
            box(vg,x+p[1],y+p[2],p[3],2,tint[1],tint[2],tint[3])
        end
    end
end
function Life.ground(sim,project,vg)
    for _,b in ipairs(sim.buildings)do
        local c=b.site and b.site.compound
        if c and c.bounds then
            local px,py=project(b.x,b.y);local r=c.bounds
            -- Foundations exist during construction; furnishings activate only
            -- on completion in Life.add below.
            -- The reserved plot is conservative clearance, not a giant floor.
            -- A close porch carries the furnishings; only a narrow connected
            -- pier reaches the actual shore. Movement targets remain unchanged.
            local left,top,right,bottom=-160,16,32,74
            court(vg,px+left,py+top,right-left,bottom-top,c.ground)
            if b.kind=='fishery'and b.site.shoreApproach then
                local sx,sy=project(b.site.shoreApproach.x,b.site.shoreApproach.y)
                sx,sy=sx-px,sy-py
                if sx>right-10 then
                    court(vg,px+right-5,py+math.max(top,sy-14),math.max(5,sx+18-right+5),28,'wood')
                elseif sx<left+10 then
                    court(vg,px+sx-18,py+math.max(top,sy-14),left-sx+23,28,'wood')
                elseif sy>bottom-10 then
                    -- Include the timber feet in the already reserved southern plot.
                    court(vg,px+sx-14,py+bottom-5,28,math.max(5,r[4]-8-bottom+5),'wood')
                elseif sy<top+10 then
                    court(vg,px+sx-14,py+sy-14,28,top-sy+19,'wood')
                end
            end
            if b.complete then
                local dx,dy=require('game.PixelLayout').door(b)
                local ex,ey=project(dx,dy);local rx,ry=project(b.x,b.y+1)
                if c.ground~='wood'then
                    A.pave(vg,ex-6,ey,12,math.max(1,ry-ey)+5)
                    A.pave(vg,math.min(ex,rx)-6,ry-6,math.abs(rx-ex)+12,12)
                end
                if c.ground~='stone'then
                    -- An open, low boundary ties the side yard to the house;
                    -- the front gate/public doorway remains completely open.
                    fence(vg,px+left+4,py+bottom-3,36)
                end
            end
        end
    end
end
local function rail(vg,route,project)
    for i=2,#route do
        local ax,ay=project(route[i-1].x,route[i-1].y)
        local bx,by=project(route[i].x,route[i].y)
        local dx,dy=bx-ax,by-ay;local length=math.sqrt(dx*dx+dy*dy)
        if length>.01 then
            local nx,ny=-dy/length*5,dx/length*5
            for step=0,math.floor(length/6)do
                local t=math.min(1,step*6/length);local x,y=ax+dx*t,ay+dy*t
                polygon(vg,{{x-nx-2,y-ny},{x+nx-2,y+ny},{x+nx+2,y+ny+2},{x-nx+2,y-ny+2}},99,68,42)
            end
            for _,side in ipairs({-1,1})do
                nvgBeginPath(vg);nvgMoveTo(vg,ax+nx*side,ay+ny*side);nvgLineTo(vg,bx+nx*side,by+ny*side)
                nvgStrokeColor(vg,nvgRGBA(65,66,58,255));nvgStrokeWidth(vg,3);nvgStroke(vg)
                nvgBeginPath(vg);nvgMoveTo(vg,ax+nx*side,ay+ny*side-1);nvgLineTo(vg,bx+nx*side,by+ny*side-1)
                nvgStrokeColor(vg,nvgRGBA(180,176,143,255));nvgStrokeWidth(vg,1);nvgStroke(vg)
            end
        end
    end
end
local function workshop(sim,b,objects,project,vg)
    local site=b.site;local station=stations[b.kind]
    if not station or not site.workCell or not site.storageCell then return end
    local x,y=project(site.workCell.x,site.workCell.y)
    local sx,sy=project(site.storageCell.x,site.storageCell.y)
    local working=require('game.PixelIndustry').working(sim,b)
    if working then heat[b]=sim.elapsed end
    local warmth=math.max(0,1-(sim.elapsed-(heat[b]or -100))/2)
    objects[#objects+1]={depth=y-4,draw=function()
        prop(vg,'ground-props',x,y,station[1],station[2],2)
        if b.kind=='mill'then
            local angle=(b.visualWorkSeconds or 0)*.9
            for i=0,2 do
                local a=angle+i*math.pi*2/3
                nvgBeginPath(vg);nvgMoveTo(vg,x,y-17);nvgLineTo(vg,x+math.cos(a)*8,y-17+math.sin(a)*3)
                nvgStrokeColor(vg,nvgRGBA(118,108,90,255));nvgStrokeWidth(vg,1);nvgStroke(vg)
            end
        elseif (b.kind=='smelter'or b.kind=='ironweapons'or b.kind=='ironarmor')and warmth>0 then
            for i=0,2 do
                local flicker=math.floor((b.visualWorkSeconds or 0)*5+i)%3
                box(vg,x-12+i*3,y-12-flicker,2,3+flicker,247,127+flicker*28,43,math.floor(warmth*220))
                local t=(sim.elapsed*.4+i/3)%1
                box(vg,x-9+math.floor(t*4),y-16-math.floor(t*17),2,2,187,177,153,math.floor((1-t)*110*warmth))
            end
        end
        -- These are in-process tools/materials, never finished shelf stock.
        if working then
            if b.kind=='woodweapons'then box(vg,x-10,y-12,20,2,174,126,66);box(vg,x-8,y-14,16,1,219,202,150)
            elseif b.kind=='ironweapons'then box(vg,x+4,y-14,13,2,142,154,155)
            elseif b.kind=='ironarmor'then box(vg,x+6,y-16,9,5,123,144,150)
            elseif b.kind=='leatherarmor'then box(vg,x-7,y-14,13,4,148,100,59)end
        end
    end}
    objects[#objects+1]={depth=sy-2,draw=function()
        prop(vg,'ground-props',sx,sy,2,1,2)
        local group=0
        for _,resource in ipairs(require('game.Definitions').goods)do
            local count=E.outputAmount(b,resource)
            if count>0 then
                for i=1,math.min(3,count)do
                    A.draw(vg,'cargo.png',sx-14+(group%3)*10,sy-20-math.floor(group/3)*8-(i-1)*2,12,12,A.goods[resource]or 0,0,A.cargoColumns,1)
                end
                group=group+1
            end
        end
    end}
end
function Life.add(sim,objects,project,vg)
    for _,b in ipairs(sim.buildings)do
        local rack=b.site and b.site.compound and b.kind=='woodcutter'and b.site.storageCell
        if b.complete and rack then
            local sx,sy=project(rack.x,rack.y)
            objects[#objects+1]={depth=sy-2,draw=function()
                prop(vg,'ground-props',sx,sy,2,1,2)
                -- The small front rack is the actual output buffer. The logs
                -- painted inside the shed are raw work scenery, never stock.
                local shown=0
                for _,resource in ipairs({'wood','rawwood'})do
                    for _=1,math.min(6-shown,E.outputAmount(b,resource))do
                        local row=math.floor(shown/3);local col=shown%3
                        A.draw(vg,'cargo.png',sx-18+col*8,sy-19-row*5,20,20,A.goods[resource],0,A.cargoColumns,1)
                        shown=shown+1
                    end
                end
            end}
        end
    end
    for _,b in ipairs(sim.buildings)do if b.complete and b.site and b.site.profile=='breaks'then workshop(sim,b,objects,project,vg)end end
    for _,b in ipairs(sim.buildings)do if b.complete and require('game.WorkSites').managed(b.kind)and b.site then
        local site=b.site
        local cx,cy=project(site.chairCell.x,site.chairCell.y)
        local tx,ty=project(site.tankCell.x,site.tankCell.y)
        if b.kind=='fishery'then
            local occupied=false
            for _,a in pairs(sim.workers)do
                if a.building==b.id and a.life and a.slot==1 and a.life.phase=='rest'and not a.meal then occupied=true end
            end
            if not occupied then objects[#objects+1]={depth=cy,draw=function()prop(vg,'rocker-empty',cx,cy,0,0,1)end}end
            local n=E.outputAmount(b,'fish')
            local level=n>=5 and 3 or n>=3 and 2 or n>=1 and 1 or 0
            objects[#objects+1]={depth=ty+3,draw=function()
                prop(vg,'props',tx,ty,level,1)
            end}
        elseif b.kind=='mason'then
            local stage=0
            for _,a in pairs(sim.workers)do if a.building==b.id and a.life then
                local l=a.life
                if l.phase=='cut'and l.reservation then stage=(l.workSeconds or 0)<E.period(b)/2 and 1 or 2 end
            end end
            objects[#objects+1]={depth=ty+3,draw=function()prop(vg,'props',tx+18,ty+3,stage,4)end}
            local sp=site.stackCell or site.tankCell
            local sx,sy=project(sp.x,sp.y)
            local stone,rough=E.outputAmount(b,'stone'),E.outputAmount(b,'rawstone')
            if stone+rough>0 then objects[#objects+1]={depth=sy+2,draw=function()
                for group,count in ipairs({stone,rough})do for i=1,math.min(8,count)do
                    local row=math.floor((i-1)/3);local col=(i-1)%3
                    A.draw(vg,'cargo.png',sx-18+col*7-row*3+(group-1)*23,sy-7-row*5,16,16,
                        A.goods[group==1 and 'stone'or 'rawstone'],0,A.cargoColumns,1)
                end end
            end}end
        else
            -- Rail occupies the private registered entrance, not the public road.
            local spec=A.buildings[b.kind]
            local dx=b.x+((spec.doorX or 128)-spec.anchorX)/64
            local dy=b.y+((spec.doorY or 196)-spec.anchorY)/48
            local rx,ry=project(dx,b.y+1);local ex,ey=project(dx,dy)
            objects[#objects+1]={depth=math.min(ry,ey)-2,draw=function()
                if site.railRoute then rail(vg,site.railRoute,project)
                else prop(vg,'props',rx,ry,0,3);prop(vg,'props',ex,ey,1,3)end
            end}
            if site.compound and site.railRoute then
                local onExcursion=false
                for _,a in pairs(sim.workers)do
                    local phase=a.life and a.life.phase
                    if a.building==b.id and(phase=='rideIn'or phase=='mine'or phase=='rideOut')then onExcursion=true;break end
                end
                if not onExcursion then
                    local dock=site.railRoute[1];local cx,cy=project(dock.x,dock.y)
                    objects[#objects+1]={depth=cy-1,draw=function()prop(vg,'props',cx,cy,0,2)end}
                end
            end
            local n=b.buffer
            if n>0 then objects[#objects+1]={depth=ty+2,draw=function()
                for i=1,math.min(4,n)do
                    A.draw(vg,'cargo.png',tx-12+(i-1)*8,ty-12,16,16,A.goods[E.outputResource(b)]or 0,0,A.cargoColumns,1)
                end
            end}end
        end
    end end
end
return Life
