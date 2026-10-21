-- 2D scaffold: urhox-libs/UI owns the NanoVG context and DPI conversion.
-- The world uses integer physical pixel magnification inside its UI panel.
local UI=require 'urhox-libs/UI'
local D=require 'game.Definitions'
local A=require 'game.PixelAssets'
local Actors=require 'game.PixelActors'
local Industry=require 'game.PixelIndustry'
local Layout=require 'game.PixelLayout'
local Combat=require 'game.PixelCombat'
local Theme=require 'urhox-libs/UI/Core/Theme'
local LifeView=require 'game.PixelLife'
local Cargo=require 'game.PixelCargo'
local Pixel={}
function Pixel.enemyMaxHP(sim)
    if sim.mode=='infinite' then return 3+math.floor(sim.wave/2) end
    return (sim.campaignRaid or sim.freePlay and sim.defended) and 5 or 3
end
local function project(x,y) return (x-10)*64,(y-9)*48 end
local function unproject(x,y) return x/64+10,y/48+9 end
local function rect(vg,x,y,w,h,c)
    nvgBeginPath(vg);nvgRect(vg,math.floor(x+.5),math.floor(y+.5),w,h)
    nvgFillColor(vg,nvgRGBA(c[1],c[2],c[3],c[4] or 255));nvgFill(vg)
end
local function label(vg,x,y,t,size)
    nvgFontFace(vg,Theme.FontFace());nvgFontSize(vg,size or 10)
    nvgTextAlign(vg,NVG_ALIGN_CENTER_VISUAL+NVG_ALIGN_MIDDLE)
    nvgFillColor(vg,nvgRGBA(255,239,196,255));nvgText(vg,x,y,t)
end
local function initialZoom() return math.max(1,math.floor(graphics:GetHeight()/360))/UI.GetScale() end
local function quantize(z) return math.max(1,math.min(6,math.floor(z*UI.GetScale()+.5)))/UI.GetScale() end
local function pickBuilding(sim,event,projection,zoom)
    local _,ox,oy=projection()
    local x,y=(event.x-ox)/zoom,(event.y-oy)/zoom
    local best,depth=nil,-math.huge
    for _,b in ipairs(sim.buildings) do
        local spec=A.buildings[b.kind];local px,py=project(b.x,b.y)
        local box=spec and (spec.hitbox or spec.packed_box or {0,0,spec.width,spec.height})
        local r=b.site and b.site.compound and b.site.compound.bounds
        local inCourt=r and x>=px+r[1]and x<=px+r[3]and y>=py+r[2]and y<=py+r[4]
        local inHouse=box and x>=px-spec.anchorX+box[1]and x<=px-spec.anchorX+box[3]and
            y>=py-spec.anchorY+box[2]and y<=py-spec.anchorY+box[4]
        if (inHouse or inCourt)and py>depth then best,depth=b,py end
    end
    return best
end
function Pixel.create(sim, onTile)
    A.loadCatalog()
    ---@type {x:number,y:number,zoom:number,pinchZoom:number}
    local camera = { x = 0, y = 0, zoom = initialZoom(), pinchZoom = initialZoom() }
    local panel = UI.Panel { position = "absolute", top = 0, bottom = 0, left = 0, right = 0, pointerEvents = "auto" }
    local mode = "inspect"
    local selected = false
    local pinchAnchor = nil
    -- The bundled UI gesture recognizer does not currently emit pinch events.
    -- Track actual pointer IDs here so two physical touches work on iOS.
    local touches, physicalPinch, pinched = {}, nil, false
    local ghost = nil
    local function projection()
        local l = panel:GetAbsoluteLayout()
        return l, l.x + l.w * 0.5 + camera.x, l.y + l.h * 0.5 + camera.y
    end
    local function clampCamera()
        if sim.mode == "finite" then
            local l=panel:GetAbsoluteLayout();local low,high=sim.map:bounds()
            local left,top=project(low,low);local right,bottom=project(high,high)
            camera.x=math.max(-right*camera.zoom,math.min(-left*camera.zoom,camera.x))
            camera.y=math.max(-bottom*camera.zoom,math.min(-top*camera.zoom,camera.y))
        end
    end
    local function centerOn(x,y)
        local l=panel:GetAbsoluteLayout()
        local sx,sy=project(x,y)
        camera.x=-sx*camera.zoom
        camera.y=-sy*camera.zoom
        clampCamera()
    end
    local function tileAt(event)
        local _, ox, oy = projection()
        local wx,wy=unproject((event.x-ox)/camera.zoom,(event.y-oy)/camera.zoom)
        local x,y=math.floor(wx+0.5),math.floor(wy+0.5)
        return x, y
    end
    local function preview(event)
        if mode == "inspect" or not event.x or not event.y then return end
        local x, y = tileAt(event)
        ghost = { x=x, y=y, kind=mode }
    end
    local function point(event)
        return event.x or 0,event.y or 0
    end
    local function beginPhysicalPinch()
        local pair={}
        for _,p in pairs(touches) do pair[#pair+1]=p end
        if #pair<2 then return end
        local ax,ay,bx,by=pair[1].x,pair[1].y,pair[2].x,pair[2].y
        local fx,fy=(ax+bx)*0.5,(ay+by)*0.5
        local l,ox,oy=projection()
        physicalPinch={distance=math.max(1,math.sqrt((ax-bx)^2+(ay-by)^2)),zoom=camera.zoom,
            worldX=(fx-ox)/camera.zoom,worldY=(fy-oy)/camera.zoom}
        ghost=nil;pinched=true
    end
    local function movePhysicalPinch()
        if not physicalPinch then return end
        local pair={}
        for _,p in pairs(touches) do pair[#pair+1]=p end
        if #pair<2 then return end
        local ax,ay,bx,by=pair[1].x,pair[1].y,pair[2].x,pair[2].y
        local distance=math.sqrt((ax-bx)^2+(ay-by)^2)
        local fx,fy=(ax+bx)*0.5,(ay+by)*0.5
        local l=panel:GetAbsoluteLayout()
        camera.zoom=quantize(physicalPinch.zoom*distance/physicalPinch.distance)
        camera.x=fx-physicalPinch.worldX*camera.zoom-l.x-l.w*0.5
        camera.y=fy-physicalPinch.worldY*camera.zoom-l.y-l.h*0.5
        clampCamera()
    end
    panel.props.onPointerDown = function(event)
        if event.pointerId~=nil then
            if not next(touches) then pinched=false end
            local x,y=point(event)
            touches[event.pointerId]={x=x,y=y,startX=x,startY=y,moved=false}
            local count=0;for _ in pairs(touches) do count=count+1 end
            if count>=2 then beginPhysicalPinch();return end
        end
        preview(event)
    end
    panel.props.onPointerMove = function(event)
        local p=event.pointerId and touches[event.pointerId]
        if not p then preview(event);return end
        local x,y=point(event)
        local dx,dy=x-p.x,y-p.y
        p.x,p.y=x,y
        if (x-p.startX)^2+(y-p.startY)^2>64 then p.moved=true end
        if physicalPinch then movePhysicalPinch();return end
        if pinched then return end
        if mode=="inspect" then
            if p.moved then camera.x,camera.y=camera.x+dx,camera.y+dy;clampCamera() end
        else preview(event) end
    end
    local function endPointer(event)
        local p=event.pointerId and touches[event.pointerId]
        if not p then return end
        touches[event.pointerId]=nil
        if physicalPinch then physicalPinch=nil;return end
        if not pinched and mode~="inspect" and p.moved and ghost then
            preview(event);onTile(ghost.x,ghost.y)
        end
    end
    panel.props.onPointerUp=endPointer
    panel.props.onPointerCancel=function(event)
        if event.pointerId~=nil then touches[event.pointerId]=nil end
        physicalPinch=nil;pinchAnchor=nil;ghost=nil;pinched=true
    end
    panel.props.onTap = function(event)
        if pinched then return end
        local x,y = tileAt(event)
        if mode == "inspect" then
            local hit=pickBuilding(sim,event,projection,camera.zoom)
            if hit then x,y=hit.x,hit.y end
        end
        preview(event)
        onTile(x, y)
    end
    panel.props.onPanStart = function() end
    panel.props.onPanMove = function(event)
        if event.pointerId~=nil then return end -- physical pointer move already handled above
        if mode ~= "inspect" then preview(event); return end
        camera.x, camera.y = camera.x + event.deltaX, camera.y + event.deltaY
        clampCamera()
    end
    panel.props.onPanEnd = function(event)
        if mode ~= "inspect" and ghost and not pinchAnchor and event.pointerId==nil then
            preview(event)
            onTile(ghost.x, ghost.y)
        end
    end
    panel.props.onPinchStart = function(event)
        ghost = nil
        camera.pinchZoom = camera.zoom
        local l,ox,oy=projection()
        local fx,fy=event.x or l.x+l.w/2,event.y or l.y+l.h/2
        pinchAnchor={x=(fx-ox)/camera.zoom,y=(fy-oy)/camera.zoom,screenX=fx,screenY=fy}
    end
    panel.props.onPinchMove = function(event)
        local l=panel:GetAbsoluteLayout()
        local anchor=pinchAnchor
        if not anchor then panel.props.onPinchStart(event);anchor=pinchAnchor end
        local zoom=quantize(camera.pinchZoom*(event.scale or 1))
        camera.zoom=zoom
        camera.x=anchor.screenX-anchor.x*zoom-l.x-l.w*0.5
        camera.y=anchor.screenY-anchor.y*zoom-l.y-l.h*0.5
        clampCamera()
    end
    panel.props.onPinchEnd = function() pinchAnchor=nil;camera.pinchZoom=camera.zoom end
    local history,combatHistory={},{}
    local minimap=UI.Panel { id='miniMap',position='absolute',right=12,top=58,width=146,height=126,pointerEvents='auto' }
    function minimap:Render(vg)
        local l=self:GetAbsoluteLayout();local low,high=sim.map:bounds();local span=high-low+1
        rect(vg,l.x,l.y,l.w,l.h,{38,43,35});rect(vg,l.x+2,l.y+2,l.w-4,l.h-4,{104,125,70})
        for k in pairs(sim.roads) do
            local x,y=k:match('^(%-?%d+):(%-?%d+)$');x,y=tonumber(x),tonumber(y)
            rect(vg,l.x+8+(x-low)/span*130,l.y+8+(y-low)/span*110,3,3,{218,189,128})
        end
        for _,b in ipairs(sim.buildings) do rect(vg,l.x+8+(b.x-low)/span*130,l.y+8+(b.y-low)/span*110,5,5,{202,100,61}) end
    end
    minimap.props.onTap=function(e)
        local l=minimap:GetAbsoluteLayout();local low,high=sim.map:bounds()
        centerOn(low+(e.x-l.x-8)/130*(high-low),low+(e.y-l.y-8)/110*(high-low))
    end
    function panel:Render(vg)
        local l,ox,oy=projection()
        -- Snap the camera origin as well as sprites to physical pixels.
        local uiScale=UI.GetScale();ox=math.floor(ox*uiScale+.5)/uiScale;oy=math.floor(oy*uiScale+.5)/uiScale
        nvgSave(vg);nvgIntersectScissor(vg,l.x,l.y,l.w,l.h)
        rect(vg,l.x,l.y,l.w,l.h,{78,102,58})
        nvgTranslate(vg,ox,oy);nvgScale(vg,camera.zoom,camera.zoom)
        local minX,minY=unproject((l.x-ox)/camera.zoom,(l.y-oy)/camera.zoom)
        local maxX,maxY=unproject((l.x+l.w-ox)/camera.zoom,(l.y+l.h-oy)/camera.zoom)
        local objects={}
        for y=math.floor(minY)-3,math.ceil(maxY)+3 do for x=math.floor(minX)-2,math.ceil(maxX)+2 do
            local px,py=project(x,y);local terrain=sim:terrain(x,y)
            local column=terrain=='water' and 2 or terrain=='forest' and 3 or 0
            if not A.draw(vg,'terrain.png',px-32,py-24,64,48,column,0,4,1) then
                local shade=(x*13+y*17)%3*3
                rect(vg,px-32,py-24,64,48,terrain=='water' and {68,113,126} or {112+shade,139+shade,76+shade})
            end
            if terrain=='grass' or terrain=='forest' then rect(vg,px-32,py-24,64,48,{120,141,85,64}) end
            if terrain=='fog' or terrain=='edge' then rect(vg,px-32,py-24,64,48,{28,43,39}) end
            local road=sim.roads[x..':'..y]
            if road then
                local mask=0
                if sim.roads[x..':'..(y-1)] then mask=mask|1 end
                if sim.roads[(x+1)..':'..y] then mask=mask|2 end
                if sim.roads[x..':'..(y+1)] then mask=mask|4 end
                if sim.roads[(x-1)..':'..y] then mask=mask|8 end
                if not A.road(vg,px,py,mask) then rect(vg,px-12,py-12,24,24,{179,157,112}) end
            end
            if sim:standingTree(x,y) then objects[#objects+1]={depth=py,draw=function()
                local gust=math.max(0,math.sin(sim.elapsed*.18+math.floor(x/5)*.7+math.floor(y/5)*.4)-.15)/.85
                local sway=math.floor(math.sin(sim.elapsed*.9+x*1.7+y*.9)*2*gust+.5)
                -- The trunk remains registered to the terrain; only the crown moves.
                nvgSave(vg);nvgIntersectScissor(vg,px-42,py-94,84,73)
                A.draw(vg,'tree.png',px-40+sway,py-92,80,104);nvgRestore(vg)
                nvgSave(vg);nvgIntersectScissor(vg,px-40,py-21,80,33)
                A.draw(vg,'tree.png',px-40,py-92,80,104);nvgRestore(vg)
                if gust>.45 and(x*17+y*31)%7==0 then
                    local t=(sim.elapsed*.22+(x+y)*.17)%1
                    rect(vg,px+12+math.floor(t*20),py-55+math.floor(t*20),2,1,{142,165,62,180})
                end
            end} end
            local growth=sim.treeGrowth and sim.treeGrowth[x..':'..y]
            if sim.felledTrees[x..':'..y] and not sim:buildingAt(x,y) and not sim.roads[x..':'..y] and not sim:roadSiteAt(x,y) then
                objects[#objects+1]={depth=py,draw=function()
                    if growth and growth.phase=='sapling' and not growth.cancelled then A.draw(vg,growth.age>=270 and 'youngtree.png' or 'sapling.png',px-20,py-44,40,48)
                    else A.draw(vg,'stump.png',px-20,py-24,40,32) end
                end}
            end
            local deposits=require('game.Deposits')
            local vein=deposits.at(sim,x,y)or(deposits.rockAt and deposits.rockAt(sim,x,y))
            if vein and terrain~='fog' and terrain~='edge' then
                objects[#objects+1]={depth=py-1,draw=function()
                    local remaining=vein.resource=='rawstone'and sim.rock or
                        (sim.minerals or {})[vein.resource..':'..vein.x..':'..vein.y]or deposits.capacity[vein.resource]
                    LifeView.outcrop(vg,px,py,vein.resource,remaining,sim.roads[x..':'..y])
                    if mode~='inspect'then label(vg,px,py-27,D.names[vein.resource]or'原石',10)end
                end}
            end
            if mode~='inspect' and terrain=='grass' then
                rect(vg,px-32,py+23,64,1,{230,225,178,80});rect(vg,px+31,py-24,1,48,{230,225,178,80})
            end
        end end
        for _,site in ipairs(sim.pendingRoads) do
            local px,py=project(site.x,site.y)
            for i=-10,10,5 do rect(vg,px+i,py-11,3,2,{230,197,131});rect(vg,px+i,py+10,3,2,{230,197,131}) end
            rect(vg,px-10,py-2,math.floor(20*(site.progress or 0)),3,{194,169,113})
        end
        LifeView.ground(sim,project,vg)
        for _,b in ipairs(sim.buildings) do
            if sim.roads[b.x..':'..(b.y+1)]and not(b.site and b.site.compound)then
                local dx,dy=Layout.door(b);local x,y=project(dx,dy);local rx,ry=project(b.x,b.y+1)
                -- Registered doorway -> worn courtyard -> the real road tile.
                A.pave(vg,x-7,y,14,math.max(1,ry-y)+7)
                A.pave(vg,math.min(x,rx)-7,ry-7,math.abs(rx-x)+14,14)
            end
        end
        for _,b in ipairs(sim.buildings) do
            local px,py=project(b.x,b.y);local spec=A.buildings[b.kind]
            objects[#objects+1]={depth=py+22,draw=function()
                if selected==b then
                    for _,c in ipairs(D.cells(b)) do local sx,sy=project(b.x+c.x,b.y+c.y);rect(vg,sx-32,sy-24,64,48,{244,210,100,75}) end
                    local r=b.site and b.site.compound and b.site.compound.bounds
                    if r then
                        rect(vg,px+r[1],py+r[2],r[3]-r[1],1,{244,210,100,190})
                        rect(vg,px+r[1],py+r[4],r[3]-r[1],1,{244,210,100,190})
                        rect(vg,px+r[1],py+r[2],1,r[4]-r[2],{244,210,100,190})
                        rect(vg,px+r[3],py+r[2],1,r[4]-r[2],{244,210,100,190})
                    end
                end
                local path=spec.path
                if not b.complete then
                    local w,h=D.footprint(b.kind)
                    path='construction/'..w..'x'..h..'-'..math.min(3,math.floor((b.progress or 0)*4))..'.png'
                end
                path=Industry.buildingPath(b,path)
                local drawn=A.building(vg,path,px-spec.anchorX,py-spec.anchorY,spec.width,spec.height)
                if not drawn then
                    local w,h=D.footprint(b.kind)
                    rect(vg,px-(w-.5)*64,py-(h-.5)*48,w*64,h*48,{62,66,48})
                    label(vg,px-(w-1)*32,py-(h-1)*24,D.buildings[b.kind].name,12)
                end
                if not b.complete then
                    rect(vg,px-56,py+25,64,4,{45,40,31});rect(vg,px-56,py+25,math.floor(64*(b.progress or 0)),4,{222,175,76})
                end
            end}
        end
        for _,p in ipairs(Actors.collect(sim,history)) do
            local px,py=project(p.x,p.y)
            local depth=py
            if p.layerBuilding then local _,baseY=project(p.layerBuilding.x,p.layerBuilding.y);depth=baseY+(p.leaning and 27 or 23)end
            objects[#objects+1]={depth=depth,draw=function()
                rect(vg,px-5,py-1,10,3,{38,48,31,125})
                if p.faction then
                    local c=p.faction=='guard' and {75,192,212} or {221,76,56}
                    rect(vg,px-7,py,14,2,c);rect(vg,px-7,py-2,2,2,c);rect(vg,px+5,py-2,2,2,c)
                    label(vg,px,py-32,p.faction=='guard' and '勇' or '匪',12)
                    if p.faction=='enemy' then
                        local maxHP=Pixel.enemyMaxHP(sim)
                        rect(vg,px-9,py-26,18,3,{49,36,31})
                        rect(vg,px-9,py-26,math.max(0,math.min(18,math.floor(18*p.actor.hp/maxHP))),2,c)
                    end
                end
                local sprite=A.actorSprite(p,sim.elapsed)
                if not A.texture(vg,sprite.path) then sprite={path='workers-walk.png',frame=p.frame,row=p.look*4+p.direction,cols=4,rows=8} end
                local embedded=p.building and p.building.kind=='fishery'and(p.action=='stow'or p.action=='reel')
                local cargo=p.cargo and not embedded and Cargo.pose(p.cargo,p.direction,p.action=='ride')
                if cargo and p.action=='stow'then cargo.y=cargo.y+math.floor(math.min(1,(p.actionClock or 0)/.9)*6)end
                local function load()
                    Cargo.draw(vg,p,px,py,cargo,false)
                end
                if cargo and cargo.behind then load()end
                A.sprite(vg,sprite,px,py)
                if cargo and not cargo.behind then load()end
                if cargo then Cargo.draw(vg,p,px,py,cargo,true)end
            end}
        end
        for _,hit in ipairs(Combat.update(sim,combatHistory)) do
            local x,y=project(hit.x,hit.y)
            objects[#objects+1]={depth=y+30,draw=function()
                local spread=2+math.floor(hit.age*12)
                for _,sign in ipairs({-1,1}) do
                    rect(vg,x+sign*spread,y-13+sign*spread,3,2,{255,210,119})
                    rect(vg,x+sign*spread,y-13-sign*spread,3,2,{216,65,46})
                end
                label(vg,x,y-24-math.floor(hit.age*12),'-'..hit.damage,10)
            end}
        end
        Industry.add(sim,objects,project,vg)
        LifeView.add(sim,objects,project,vg)
        for i,o in ipairs(objects) do o.order=i end
        table.sort(objects,function(a,b) if a.depth==b.depth then return a.order<b.order end;return a.depth<b.depth end)
        for _,o in ipairs(objects) do o.draw() end
        if ghost then
            local valid,_,site=sim:canBuild(ghost.kind,ghost.x,ghost.y)
            for _,c in ipairs(D.cells(ghost.kind)) do
                local x,y=project(ghost.x+c.x,ghost.y+c.y)
                rect(vg,x-32,y-24,64,48,valid and {115,205,121,130} or {223,89,72,150})
            end
            if site then for _,p in ipairs(site.yardCells or {})do
                local x,y=project(p.x,p.y)
                rect(vg,x-31,y-23,62,46,valid and {146,193,137,100}or {223,89,72,120})
            end end
            local r=site and site.compound and site.compound.bounds
            if r then
                local x,y=project(ghost.x,ghost.y)
                rect(vg,x+r[1],y+r[2],r[3]-r[1],r[4]-r[2],valid and{183,193,119,65}or{223,89,72,90})
            end
        end
        nvgRestore(vg)
    end
    return {
        panel=panel,minimap=minimap,dispose=function() A.release() end,
        setMode=function(value) mode=value;ghost=nil end,previewState=function() return ghost end,
        select=function(value) selected=value end,selectedBuilding=function() return selected end,
        zoom=function(delta) camera.zoom=quantize(camera.zoom+delta) end,
        home=function() camera.x,camera.y,camera.zoom=0,0,initialZoom() end,
        cameraState=function() return {x=camera.x,y=camera.y,zoom=camera.zoom,pixelScale=camera.zoom*UI.GetScale()} end,
        worldToScreen=function(x,y) local _,ox,oy=projection();local px,py=project(x,y);return ox+px*camera.zoom,oy+py*camera.zoom end,
        focus=function(x,y) centerOn(x,y) end,
        frontier=function() local _,high=sim.map:bounds();centerOn(high-2,9) end,
        project=project,
    }
end
return Pixel
