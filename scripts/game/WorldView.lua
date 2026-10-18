local UI = require "urhox-libs/UI"
local D = require "game.Definitions"
local Art = require "game.Art"
local ModelWorld = require "game.ModelWorld"
local Theme = require "urhox-libs/UI/Core/Theme"
local WorldView = {}
local function color(c) return nvgRGBA(c[1],c[2],c[3],c[4] or 255) end
local function rect(vg,x,y,w,h,c)
    nvgBeginPath(vg);nvgRect(vg,x,y,w,h);nvgFillColor(vg,color(c));nvgFill(vg)
end
local function circle(vg,x,y,r,c)
    nvgBeginPath(vg);nvgCircle(vg,x,y,r);nvgFillColor(vg,color(c));nvgFill(vg)
end
local function line(vg,x1,y1,x2,y2,c,width)
    nvgBeginPath(vg);nvgMoveTo(vg,x1,y1);nvgLineTo(vg,x2,y2)
    nvgStrokeColor(vg,color(c));nvgStrokeWidth(vg,width or 1);nvgStroke(vg)
end
local function project(x,y) return (x-10)*56,(y-9)*42 end
local function unproject(x,y) return x/56+10,y/42+9 end
local function smallText(vg,x,y,value,size)
    nvgFontSize(vg,size or 10);nvgFontFace(vg,Theme.FontFace())
    nvgTextAlign(vg,NVG_ALIGN_CENTER_VISUAL+NVG_ALIGN_MIDDLE)
    nvgFillColor(vg,color({247,233,193}));nvgText(vg,x,y,tostring(value))
end
local function thoughtBubble(vg,sx,sy,thought)
    if not thought then return end
    local bx,by=sx+12,sy-45
    circle(vg,bx-7,by+16,1.5,{245,235,203,165})
    circle(vg,bx-3,by+11,2.5,{245,235,203,195})
    circle(vg,bx+2,by+1,12,{252,243,216,238})
    nvgBeginPath(vg);nvgCircle(vg,bx+2,by+1,12)
    nvgStrokeColor(vg,color({123,98,63,220}));nvgStrokeWidth(vg,1);nvgStroke(vg)
    if thought=="rest" then smallText(vg,bx+2,by+2,"累",12)
    elseif not Art.draw(vg,"icon-" .. thought,bx-6,by-7,16,16) then
        smallText(vg,bx+2,by+2,thought=="livestock" and "畜" or thought=="meat" and "肉" or "?",11)
    end
end
function WorldView.create(sim, onTile)
    local modelWorld=ModelWorld.new(sim)
    ---@type {x:number,y:number,zoom:number,pinchZoom:number}
    local camera = { x = 0, y = 0, zoom = 1.55, pinchZoom = 1.55 }
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
            camera.x = math.max(-750, math.min(750, camera.x))
            camera.y = math.max(-520, math.min(520, camera.y))
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
        local l=panel:GetAbsoluteLayout()
        return (event.x or 0)+l.x,(event.y or 0)+l.y
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
        camera.zoom=math.max(0.55,math.min(1.8,physicalPinch.zoom*distance/physicalPinch.distance))
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
    panel.props.onPointerCancel=endPointer
    panel.props.onTap = function(event)
        if pinched then return end
        local x,y = tileAt(event)
        if mode == "inspect" then
            local hit3D=modelWorld:pick(event.x,event.y,panel:GetAbsoluteLayout())
            if hit3D then x,y=hit3D.x,hit3D.y end
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
        local zoom=math.max(0.55,math.min(1.8,camera.pinchZoom*(event.scale or 1)))
        camera.zoom=zoom
        camera.x=anchor.screenX-anchor.x*zoom-l.x-l.w*0.5
        camera.y=anchor.screenY-anchor.y*zoom-l.y-l.h*0.5
        clampCamera()
    end
    panel.props.onPinchEnd = function() pinchAnchor=nil;camera.pinchZoom=camera.zoom end
    local minimap=UI.Panel { id="miniMap",position="absolute",right=12,top=58,width=146,height=126,pointerEvents="auto" }
    local function miniGeometry()
        local l=minimap:GetAbsoluteLayout()
        local low,high=sim.map:bounds()
        return l,low,high,l.x+20,l.y+12,106,106
    end
    minimap.props.onTap=function(event)
        local _,low,high,x0,y0,w,h=miniGeometry()
        local nx=math.max(0,math.min(1,(event.x-x0)/w))
        local ny=math.max(0,math.min(1,(event.y-y0)/h))
        centerOn(low+nx*(high-low),low+ny*(high-low))
    end
    function minimap:Render(vg)
        local l,low,high,x0,y0,w,h=miniGeometry()
        rect(vg,l.x+2,l.y+3,l.w,l.h,{0,0,0,75})
        rect(vg,l.x,l.y,l.w,l.h,{37,34,27})
        rect(vg,l.x+2,l.y+2,l.w-4,l.h-4,{130,106,64})
        rect(vg,l.x+5,l.y+5,l.w-10,l.h-10,{62,65,47})
        local span=high-low+1
        local step=math.max(1,math.ceil(span/32))
        for gy=low,high,step do
            for gx=low,high,step do
                local kind=sim:terrain(gx,gy)
                local c=kind=="water" and {74,111,120} or kind=="forest" and {54,88,58} or {132,143,91}
                local px=x0+(gx-low)/span*w
                local py=y0+(gy-low)/span*h
                rect(vg,px,py,math.max(1,w*step/span+0.5),math.max(1,h*step/span+0.5),c)
            end
        end
        for k in pairs(sim.roads) do
            local rx,ry=k:match("^(%-?%d+):(%-?%d+)$")
            rx,ry=tonumber(rx),tonumber(ry)
            if rx and rx>=low and rx<=high and ry>=low and ry<=high then
                rect(vg,x0+(rx-low+0.5)/span*w-1,y0+(ry-low+0.5)/span*h-1,2,2,{224,198,138})
            end
        end
        for _,b in ipairs(sim.buildings) do
            if b.x>=low and b.x<=high and b.y>=low and b.y<=high then
                local px=x0+(b.x-low+0.5)/span*w
                local py=y0+(b.y-low+0.5)/span*h
                rect(vg,px-2,py-2,4,4,b.kind=="store" and {245,212,117} or {199,116,81})
            end
        end
        local world,ox,oy=projection()
        local cx,cy=unproject((world.x+world.w/2-ox)/camera.zoom,(world.y+world.h/2-oy)/camera.zoom)
        local px=x0+(cx-low+0.5)/span*w
        local py=y0+(cy-low+0.5)/span*h
        line(vg,px-6,py,px+6,py,{255,234,170},1.5)
        line(vg,px,py-6,px,py+6,{255,234,170},1.5)
        rect(vg,l.x+6,l.y+6,l.w-12,1,{219,184,115,105})
    end
    function panel:Render(vg)
        local l,ox,oy=projection()
        modelWorld:update(camera,l,mode,ghost,selected)
        for _,b in ipairs(sim.buildings) do
            if not b.complete and b.progress==0 then
                local at=modelWorld.camera:WorldToScreenPoint(Vector3(b.x-10-((b.footprintW or 1)-1)*0.5,0.08,9-b.y+((b.footprintH or 1)-1)*0.5))
                if at.x>0 and at.x<1 and at.y>0 and at.y<1 then
                    local x,y=l.x+at.x*l.w,l.y+at.y*l.h
                    rect(vg,x-63,y-12,126,24,{55,48,34,215})
                    smallText(vg,x,y,sim:connected(b) and "待修建 · 等待工人" or "待修建 · 等待接路",12)
                end
            end
        end
        -- Only interaction guides and thought bubbles use the HUD canvas.
        if mode~="inspect" then
            nvgSave(vg);nvgTranslate(vg,ox,oy);nvgScale(vg,camera.zoom,camera.zoom)
            local x1,y1=unproject((l.x-ox)/camera.zoom,(l.y-oy)/camera.zoom)
            local x2,y2=unproject((l.x+l.w-ox)/camera.zoom,(l.y+l.h-oy)/camera.zoom)
            for y=math.floor(y1),math.ceil(y2) do for x=math.floor(x1),math.ceil(x2) do
                if sim:terrain(x,y)=="grass" then
                    local sx,sy=project(x,y)
                    nvgBeginPath(vg);nvgRect(vg,sx-28,sy-21,56,42)
                    nvgStrokeColor(vg,color({245,237,206,110}));nvgStrokeWidth(vg,0.6);nvgStroke(vg)
                end
            end end
            nvgRestore(vg)
        end
        for _,person in pairs(modelWorld.actors) do
            local actor=person.actor
            local thought
            if not actor.meal or actor.meal.phase=="walk" or actor.meal.phase=="queue" then
                if (actor.hunger or 0)>=65 then thought="food"
                elseif (actor.energy or 100)<=30 then thought="rest"
                elseif actor.building then
                    local b=sim.buildings[actor.building]
                    local def=b and D.buildings[b.kind]
                    if def and def.input and b.inputs==0 and not b.incoming and (sim.stock[def.input] or 0)==0 and
                        (not def.alternateInput or (sim.stock[def.alternateInput] or 0)==0) then thought=def.input end
                end
            end
            if thought then
                local at=modelWorld.camera:WorldToScreenPoint(person.node.worldPosition+Vector3(0,0.8,0))
                thoughtBubble(vg,l.x+at.x*l.w,l.y+at.y*l.h+35,thought)
            end
        end
    end
    ---@class VillageWorldView
    local result = {
        panel = panel,
        minimap = minimap,
        dispose = function() modelWorld:dispose() end,
        modelWorld = modelWorld,

        setMode = function(value) mode = value; ghost = nil end,
        previewState = function() return ghost end,
        select = function(value) selected = value end,
        selectedBuilding = function() return selected end,
        zoom = function(delta) camera.zoom = math.max(0.55, math.min(1.8, camera.zoom + delta)) end,
        home = function() camera.x, camera.y, camera.zoom = 0, 0, 1.55 end,
        cameraState = function() return {x=camera.x,y=camera.y,zoom=camera.zoom} end,
        frontier = function()
            local _, high = sim.map:bounds()
            local sx, sy = project(high - 2, 9)
            camera.x, camera.y = -sx * camera.zoom, -sy * camera.zoom
        end,
    }
    return result
end
return WorldView
