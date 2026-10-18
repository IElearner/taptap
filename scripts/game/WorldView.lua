local UI = require "urhox-libs/UI"
local D = require "game.Definitions"
local Art = require "game.Art"
local Characters = require "game.Characters"
local Meals = require "game.Meals"
local Farm = require "game.FarmCycle"
local Theme = require "urhox-libs/UI/Core/Theme"
local WorldView = {}
local function color(c, alpha) return nvgRGBA(c[1], c[2], c[3], alpha or c[4] or 255) end
local function polygon(vg, points, c)
    nvgBeginPath(vg); nvgMoveTo(vg, points[1], points[2])
    for i = 3, #points, 2 do nvgLineTo(vg, points[i], points[i + 1]) end
    nvgClosePath(vg); nvgFillColor(vg, color(c)); nvgFill(vg)
end
local function rect(vg, x, y, w, h, c)
    nvgBeginPath(vg); nvgRect(vg, x, y, w, h); nvgFillColor(vg, color(c)); nvgFill(vg)
end
local function circle(vg, x, y, r, c)
    nvgBeginPath(vg); nvgCircle(vg, x, y, r); nvgFillColor(vg, color(c)); nvgFill(vg)
end
local function line(vg, x1, y1, x2, y2, c, width)
    nvgBeginPath(vg); nvgMoveTo(vg, x1, y1); nvgLineTo(vg, x2, y2)
    nvgStrokeColor(vg, color(c)); nvgStrokeWidth(vg, width or 1); nvgStroke(vg)
end
-- Knights & Merchants-like map: world X runs across the screen and world Y
-- runs down it. Buildings retain a painted facade, but roads are orthogonal.
local TILE_W,TILE_H=56,42
local function project(x,y) return (x-10)*TILE_W,(y-9)*TILE_H end
local function unproject(x,y) return x/TILE_W+10,y/TILE_H+9 end
local function buildingVisualSize(b)
    local width,height=b.footprintW or 1,b.footprintH or 1
    return math.min(width*TILE_W-4,height*TILE_H+48)
end
local function tile(vg, x, y, c, shrink)
    local sx,sy=project(x,y)
    local gap=shrink or 0
    rect(vg,sx-TILE_W/2+gap,sy-TILE_H/2+gap,TILE_W-2*gap,TILE_H-2*gap,c)
end
local function tileOutline(vg, x, y, c)
    local sx,sy=project(x,y)
    nvgBeginPath(vg);nvgRect(vg,sx-TILE_W/2,sy-TILE_H/2,TILE_W,TILE_H)
    nvgStrokeColor(vg,color(c));nvgStrokeWidth(vg,1);nvgStroke(vg)
end
local function roadSurface(vg,sim,x,y,planned)
    local sx,sy=project(x,y)
    local function connected(dx,dy)
        local nx,ny=x+dx,y+dy
        return sim.roads[nx .. ":" .. ny] or sim:roadSiteAt(nx,ny)
    end
    local base=planned and {126,107,71} or {149,136,103}
    rect(vg,sx-17,sy-14,34,28,base)
    if connected(-1,0) then rect(vg,sx-28,sy-14,12,28,base) end
    if connected(1,0) then rect(vg,sx+16,sy-14,12,28,base) end
    if connected(0,-1) then rect(vg,sx-17,sy-21,34,8,base) end
    if connected(0,1) then rect(vg,sx-17,sy+13,34,8,base) end
    if not planned then
        for j=-2,2 do for k=-1,1 do
            local px=sx+j*6+(k%2)*3
            local py=sy+k*8+(j%2)*2
            nvgBeginPath(vg);nvgEllipse(vg,px,py,3+(j+k)%2,2)
            nvgFillColor(vg,color({183+(x+y)%9,170+(x*3+y)%8,137+(x+y*2)%8,220}));nvgFill(vg)
        end end
    end
end
local function tree(vg, sx, sy, seed)
    local kinds = { "tree-oak", "tree-pine", "tree-bamboo" }
    local size = 74 + seed % 9
    if Art.draw(vg, kinds[seed % 3 + 1], sx-size/2, sy-size*0.8, size, size) then return end
    nvgBeginPath(vg); nvgEllipse(vg, sx + 8, sy + 3, 20, 8); nvgFillColor(vg, color({ 20, 32, 20, 65 })); nvgFill(vg)
    local h = 32 + seed % 12
    polygon(vg, {sx-3,sy+1,sx+4,sy-1,sx+2,sy-h,sx-1,sy-h}, {76, 65, 40})
    line(vg, sx, sy-15, sx-9, sy-27, {91,76,43}, 2)
    line(vg, sx+1, sy-19, sx+10, sy-30, {91,76,43}, 2)
    for i = 0, 6 do
        local a = i * 2.4 + seed
        local px, py = sx + math.cos(a)*10, sy-h + math.sin(a)*8
        circle(vg, px+2, py+3, 12, {42,63+seed%17,37})
        circle(vg, px-1, py-2, 10, {69+seed%11,88+seed%19,43})
        circle(vg, px-4, py-5, 6, {98+seed%18,112+seed%15,55})
    end
end
local function drawFarm(vg,b,sim,ghost)
    local width,height=b.footprintW or 1,b.footprintH or 1
    local stage=Farm.stage(b,D.buildings.farm.period)
    local alpha=ghost and 0.65 or (b.complete and 1 or 0.65)
    for dx=1-width,0 do for dy=1-height,0 do
        local tx,ty=b.x+dx,b.y+dy
        local sx,sy=project(tx,ty)
        rect(vg,sx-27,sy-20,54,40,{112,88,52,math.floor(alpha*245)})
        for row=0,3 do
            local ry=sy-15+row*10
            line(vg,sx-25,ry+4,sx+25,ry+4,{76,58,35,115},2)
            for col=0,6 do
                local px=sx-22+col*7+(row%2)*2
                local sway=math.sin((sim and sim.elapsed or 0)*1.1+col+row+tx)*1.3
                if stage=="seed" then
                    circle(vg,px,ry,1.5,{190,158,93,180})
                else
                    local ripe=stage=="ripe"
                    local h=stage=="sprout" and 4 or ripe and 12 or 8
                    local blade=ripe and {221,182,71,240} or {91,145,64,225}
                    line(vg,px,ry+2,px+sway,ry+2-h,blade,ripe and 2 or 1.5)
                    line(vg,px,ry,px-3+sway,ry-h*0.55,blade,1)
                    line(vg,px,ry,px+3+sway,ry-h*0.60,blade,1)
                    if ripe then circle(vg,px+sway,ry-h,2,{237,200,99,235}) end
                end
            end
        end
    end end
    local points={west={-28,-21,-28,21},north={-28,-21,28,-21},east={28,-21,28,21},south={-28,21,28,21}}
    for _,edge in ipairs(Farm.exposedEdges(sim,b)) do
        local sx,sy=project(edge.x,edge.y)
        local p=points[edge.side]
        local x1,y1,x2,y2=sx+p[1],sy+p[2],sx+p[3],sy+p[4]
        local gate=edge.side=="south" and edge.x==b.x and edge.y==b.y
        if gate then
            for _,span in ipairs({{0,0.3},{0.7,1}}) do
                local a,z=span[1],span[2]
                line(vg,x1+(x2-x1)*a,y1+(y2-y1)*a-8,x1+(x2-x1)*z,y1+(y2-y1)*z-8,{146,99,54,230},2.6)
            end
        else
            line(vg,x1,y1-8,x2,y2-8,{146,99,54,230},2.6)
            line(vg,x1,y1-3,x2,y2-3,{107,72,41,210},1.8)
        end
        line(vg,x1,y1-12,x1,y1,{111,76,44,240},2.8)
        line(vg,x2,y2-12,x2,y2,{111,76,44,240},2.8)
    end
    if b.complete and Farm.needsWork(b,D.buildings.farm.period) and (b.farmWork or 0)>0 then
        local centerX=project(b.x-(width-1)*0.5,b.y-(height-1)*0.5)
        local sx,sy=project(b.x,b.y)
        local progress=math.min(1,(b.farmWork or 0)/Farm.workSeconds)
        rect(vg,sx-20,sy+19,40,4,{66,52,34,210})
        rect(vg,sx-19,sy+20,38*progress,2,{224,187,97,240})
        if Farm.step(b)==1 then
            for i=1,5 do
                local px=centerX-19+i*7
                local py=sy-18+(i%2)*4
                line(vg,px,py,px-2,py+5,{126,185,198,170},1.5)
            end
        elseif Farm.step(b)==3 then
            for i=1,3 do circle(vg,centerX-10+i*9,sy-11+i%2*4,2,{235,203,111,150}) end
        end
    end
    if not b.complete and not ghost then
        local sx,sy=project(b.x-(width-1)*0.5,b.y-(height-1)*0.5)
        rect(vg,sx-25,sy+17,50,4,{68,59,41});rect(vg,sx-25,sy+17,50*(b.progress or 0),4,{225,191,105})
    end
end
local function house(vg, b, selected, clock, art, ghost, sim)
    local width, height = b.footprintW or 1, b.footprintH or 1
    local x, y = project(b.x-(width-1)*0.5, b.y-(height-1)*0.5)
    y=y+18+(height-1)*TILE_H/2-6
    local def = D.buildings[b.kind]
    if b.kind~="farm" and not b.complete then
        for dx=1-width,0 do for dy=1-height,0 do
            tile(vg,b.x+dx,b.y+dy,{111,108,78,75},3)
        end end
    end
    if selected then
        for dx = 1-width, 0 do for dy = 1-height, 0 do tile(vg, b.x+dx, b.y+dy, { 239, 208, 115, 120 }) end end
    end
    if b.kind=="farm" then drawFarm(vg,b,sim,ghost);return end
    -- Anchor each painted facade at the south edge of its rectangular site.
    local size = buildingVisualSize(b)
    local atlasPainted=false
    if not art or art<=0 then
        atlasPainted=Art.draw(vg,"building-" .. b.kind,x-size/2,y-size+6,size,size,ghost and 0.7 or (b.complete and 1 or 0.65))
    end
    if (art and art > 0) or atlasPainted then
        if art and art > 0 then
        nvgBeginPath(vg); nvgRect(vg, x-size/2, y-size+6, size, size)
        nvgFillPaint(vg, nvgImagePattern(vg, x-size/2, y-size+6, size, size, 0, art, b.complete and 1 or 0.65)); nvgFill(vg)
        end
        if b.kind == "kitchen" and b.complete then
            for i = 1, 3 do circle(vg, x+10+math.sin(clock+i)*3, y-50-i*7-clock%1*5, 3+i, {235,225,195,60}) end
        end
    else
        nvgBeginPath(vg); nvgEllipse(vg, x + 8, y + 4, 31, 11); nvgFillColor(vg, color({ 46, 53, 33, 60 })); nvgFill(vg)
        local h = b.kind == "store" and 29 or 22
        polygon(vg, { x - 22, y - h, x, y - h + 11, x, y + 10, x - 22, y - 1 }, { 200, 179, 137 })
        polygon(vg, { x, y - h + 11, x + 23, y - h, x + 23, y - 1, x, y + 10 }, { 161, 143, 107 })
        for i = 0, 2 do line(vg, x - 20 + i * 9, y - h + 2 + i * 4, x - 20 + i * 9, y + i * 4, { 111, 91, 65 }, 2) end
        polygon(vg, { x - 8, y - 8, x - 1, y - 5, x - 1, y + 9, x - 8, y + 5 }, { 72, 65, 49 })
        local c = def.color
        polygon(vg, { x - 31, y - h - 4, x - 2, y - h - 22, x + 29, y - h - 8, x, y - h + 10 }, c)
        polygon(vg, { x - 31, y - h - 4, x, y - h + 10, x + 29, y - h - 8, x + 29, y - h - 3, x, y - h + 15, x - 31, y - h + 1 }, { c[1] * 0.7, c[2] * 0.7, c[3] * 0.7 })
        for i = 1, 6 do
            local t = i / 7
            line(vg, x - 31 + 29 * t, y - h - 4 - 18 * t, x + 31 * t, y - h + 10 - 18 * t, { 218, 217, 184, 60 }, 1)
        end
        line(vg, x - 2, y - h - 23, x + 29, y - h - 9, { 187, 187, 154 }, 3)
        circle(vg, x - 31, y - h - 4, 2.5, c); circle(vg, x + 29, y - h - 8, 2.5, c)
        if b.kind == "kitchen" then
            rect(vg, x + 13, y - h - 28, 6, 17, { 123, 110, 94 })
            for i = 1, 3 do circle(vg, x + 16 + math.sin(clock + i) * 3, y - h - 30 - i * 7 - clock % 1 * 5, 3 + i, { 240, 234, 211, 65 }) end
        elseif b.kind == "mill" then
            circle(vg, x + 21, y - 5, 11, { 91, 72, 48 })
            for i = 0, 5 do
                local a = i * math.pi / 3 + (b.workers > 0 and clock or 0)
                line(vg, x + 21, y - 5, x + 21 + math.cos(a) * 10, y - 5 + math.sin(a) * 10, { 203, 178, 130 }, 2)
            end
        elseif b.kind == "barracks" then
            line(vg, x + 28, y, x + 28, y - 52, { 104, 77, 50 }, 2)
            polygon(vg, { x + 28, y - 51, x + 43, y - 46, x + 28, y - 40 }, { 171, 60, 43 })
        elseif b.kind == "woodcutter" then
            for i = 0, 2 do line(vg, x + 15 + i * 4, y + 5 - i * 2, x + 29 + i * 4, y - 3 - i * 2, { 138, 100, 56 }, 4) end
        elseif b.kind == "store" then
            for i = 0, 2 do circle(vg, x - 23 + i * 7, y + 5, 5, { 204, 170, 105 }) end
        end
    end
    if not b.complete and not ghost then
        for i = -1, 1 do line(vg, x + i * 19, y + 10, x + i * 19, y - 48, { 174, 141, 86 }, 2) end
        line(vg, x - 22, y - 28, x + 22, y - 28, { 199, 169, 110 }, 2)
        rect(vg, x - 22, y + 17, 44, 4, { 75, 72, 49 }); rect(vg, x - 22, y + 17, 44 * b.progress, 4, { 233, 199, 109 })
    end
end
local function diningFloor(vg,b,side)
    local width,height=b.footprintW or 1,b.footprintH or 1
    local x,y=project(b.x-(width-1)*0.5,b.y-(height-1)*0.5)
    -- Open cutaway in the kitchen facade: four seats stay within its footprint.
    rect(vg,x-43,y+7,86,51,{72,51,32,245})
    rect(vg,x-39,y+10,78,43,{173,125,68,248})
    for i=0,5 do line(vg,x-37+i*14,y+10,x-37+i*14,y+53,{207,155,90,90},1) end
    line(vg,x-44,y+8,x+44,y+8,{95,64,39,245},4)
    line(vg,x-44,y+8,x-44,y+57,{94,62,37,245},3)
    line(vg,x+44,y+8,x+44,y+57,{94,62,37,245},3)
    rect(vg,x-12,y+25,24,19,{103,70,43,245})
    rect(vg,x-10,y+26,20,15,{217,174,101,245})
    for seat=1,Meals.seats do
        local wx,wy=Meals.seatPosition(b,seat,side)
        local sx,sy=project(wx,wy)
        nvgBeginPath(vg);nvgEllipse(vg,sx,sy+2,8,4);nvgFillColor(vg,color({66,45,30,230}));nvgFill(vg)
        nvgBeginPath(vg);nvgEllipse(vg,sx,sy,6,3);nvgFillColor(vg,color({180,127,70,245}));nvgFill(vg)
        circle(vg,sx+3,sy-5,2.3,{229,208,164})
    end
end
local function smallText(vg,x,y,value,size)
    nvgFontSize(vg,size or 10);nvgFontFace(vg,Theme.FontFace())
    nvgTextAlign(vg,NVG_ALIGN_CENTER_VISUAL+NVG_ALIGN_MIDDLE)
    nvgFillColor(vg,color({247,233,193}));nvgText(vg,x,y,tostring(value))
end
local function thoughtBubble(vg,sx,sy,thought)
    if not thought then return end
    local bx,by=sx+15,sy-56
    circle(vg,bx-8,by+20,2,{245,235,203,165})
    circle(vg,bx-4,by+14,3,{245,235,203,195})
    circle(vg,bx+3,by+2,15,{252,243,216,238})
    nvgBeginPath(vg);nvgCircle(vg,bx+3,by+2,15)
    nvgStrokeColor(vg,color({123,98,63,220}));nvgStrokeWidth(vg,1);nvgStroke(vg)
    if thought=="rest" then smallText(vg,bx+3,by+3,"累",15)
    elseif not Art.draw(vg,"icon-" .. thought,bx-7,by-8,20,20) then
        smallText(vg,bx+3,by+3,thought=="livestock" and "畜" or thought=="meat" and "肉" or "?",14)
    end
end
local function person(vg, x, y, c, carrying, clock, role, direction, profile, action, cargo, walking, phase, thought, cargoAmount)
    local sx, sy = project(x, y)
    local step = walking and math.abs(math.sin(clock * 7 + (phase or 0))) * 1.4 or 0
    local size = action == "hammer" and 47 or action == "eat" and 30 or 42
    local base = "person-" .. (role or (carrying and "loaded" or "carrier")) .. "-" .. (direction or "se")
    local name = Characters.sprite(role or (carrying and "loaded" or "carrier"),direction,walking,action,clock,phase)
    nvgBeginPath(vg); nvgEllipse(vg, sx+2, sy+3, 8, 3); nvgFillColor(vg, color({ 26, 32, 24, 48 })); nvgFill(vg)
    local poseY=action=="eat" and math.sin(clock*2.2)*0.8 or 0
    local painted
    if name:sub(1,12)=="person-farm-" then
        -- Action cells are twice as wide as high; fit by height rather than
        -- squeezing the whole frame into the usual square portrait box.
        painted=Art.draw(vg,name,sx-42,sy-43,84,43)
    else
        painted=Art.draw(vg, name, sx-size/2, sy-size*0.85-step+poseY, size, size)
    end
    if not painted and name~=base then painted=Art.draw(vg,base,sx-size/2,sy-size*0.85-step+poseY,size,size) end
    if not painted then
    nvgBeginPath(vg); nvgEllipse(vg, sx, sy + 2, 5, 2); nvgFillColor(vg, color({ 30, 42, 28, 65 })); nvgFill(vg)
    line(vg, sx - 1, sy - 2, sx - 3, sy + 3 + step, { 62, 64, 56 }, 2)
    line(vg, sx + 1, sy - 2, sx + 3, sy + 3 - step, { 62, 64, 56 }, 2)
    rect(vg, sx - 3, sy - 11, 6, 10, c); circle(vg, sx, sy - 14, 3, { 218, 181, 130 })
    local hat = profile and profile.hat or "straw"
    if hat == "straw" then polygon(vg, { sx, sy - 19, sx + 6, sy - 13, sx - 6, sy - 13 }, { 197, 167, 103 })
    elseif hat == "cap" then rect(vg, sx-3, sy-18, 6, 4, {62,65,58})
    else
        circle(vg, sx,sy-16,3,{64,54,42})
        if hat == "braid" then line(vg,sx+2,sy-15,sx+4,sy-7,{50,45,36},2)
        else line(vg,sx-3,sy-15,sx+3,sy-15,{180,154,105},2) end
    end
    if profile and profile.age == "elder" then line(vg,sx-1,sy-12,sx,sy-9,{215,212,190},2) end
    if profile and profile.gender == "female" then polygon(vg,{sx-2,sy-7,sx+2,sy-7,sx+4,sy-1,sx-4,sy-1},c) end
    end
    if carrying then
        local good=cargo or "wood"
        if not Art.draw(vg,"icon-" .. good,sx+2,sy-19,13,13) then
            if good=="wood" then
                for i=0,2 do line(vg,sx+3,sy-9-i*3,sx+13,sy-13-i*3,{137,94,49},3) end
            elseif good=="stone" then
                polygon(vg,{sx+3,sy-8,sx+1,sy-14,sx+7,sy-18,sx+14,sy-13,sx+12,sy-7},{146,148,137})
            elseif good=="food" then
                rect(vg,sx+2,sy-15,12,8,{176,139,76});line(vg,sx+2,sy-11,sx+14,sy-11,{104,82,43},1)
            else
                circle(vg,sx+8,sy-12,6,good=="flour" and {225,215,179} or {181,145,80})
                line(vg,sx+5,sy-17,sx+11,sy-17,{92,75,42},2)
            end
        end
    end
    if carrying and cargo and cargoAmount and cargoAmount>0 then
        rect(vg,sx+5,sy-29,27,15,{63,48,32,215})
        rect(vg,sx+6,sy-28,25,13,{143,109,59,220})
        if not Art.draw(vg,"icon-" .. cargo,sx+6,sy-28,13,13) then
            smallText(vg,sx+12,sy-21,cargo=="livestock" and "畜" or cargo=="meat" and "肉" or "货",10)
        end
        smallText(vg,sx+24,sy-21,math.floor(cargoAmount),10)
    end
    if action=="hammer" and not painted then
        local angle=-0.8+math.sin(clock*9)*1.05
        local hx,hy=sx+5+math.sin(angle)*12,sy-11-math.cos(angle)*12
        line(vg,sx+3,sy-10,hx,hy,{173,133,78},2)
        line(vg,hx-3,hy+1,hx+3,hy-1,{167,172,163},4)
        if math.sin(clock*9)>0.8 then
            line(vg,sx+11,sy-2,sx+15,sy-5,{224,201,116},1)
            line(vg,sx+12,sy-1,sx+17,sy,{224,201,116},1)
        end
    elseif action=="hammer" and name:sub(-11)=="hammer-down" then
        local strikeX = (direction == "sw" or direction == "nw") and sx+10 or sx-10
        circle(vg,strikeX,sy-1,3,{185,169,126,95})
        line(vg,strikeX-5,sy-3,strikeX-8,sy-6,{217,194,139,150},1)
        line(vg,strikeX+4,sy-3,strikeX+7,sy-7,{217,194,139,150},1)
    elseif action=="chop" then
        local swing=math.sin(clock*2.7)
        local hx,hy=sx+7+swing*6,sy-17+swing*9
        line(vg,sx+3,sy-10,hx,hy,{149,101,55},3)
        line(vg,hx-5,hy-2,hx+6,hy+2,{184,190,179},5)
        if swing>0.7 then
            circle(vg,sx+15,sy-2,2,{214,184,115,180})
            line(vg,sx+14,sy-4,sx+20,sy-9,{222,194,134,150},1)
        end
    elseif action=="eat" then
        if name:sub(1,14)=="person-eating-" or name:sub(1,14)=="person-seated-" then
            circle(vg,sx+4,sy-20-math.sin(clock*2)*2,1.3,{246,234,202,110})
        else
            circle(vg,sx+5,sy-5,4,{229,214,175})
            circle(vg,sx+5,sy-5,2,{177,123,63})
            line(vg,sx+8,sy-12,sx+4,sy-6-math.sin(clock*2.5)*2,{158,126,80},2)
        end
    elseif action=="farm" then
        local swing=math.sin(clock*2.4)
        line(vg,sx+3,sy-10,sx+12+swing*4,sy-20+swing*5,{139,103,59},2)
        line(vg,sx+7+swing*4,sy-22+swing*5,sx+17+swing*4,sy-18+swing*5,{96,108,102},3)
        if swing>0.7 then circle(vg,sx+13,sy-1,2,{189,159,91,130}) end
    elseif (action=="plow" or action=="tend") and name:sub(1,12)~="person-farm-" then
        local swing=math.sin(clock*2.2)
        local hx,hy=sx+11+swing*3,sy-20+swing*6
        line(vg,sx+3,sy-9,hx,hy,{132,91,52},2.5)
        line(vg,hx-2,hy,hx+7,hy+4,{130,139,126},3)
        line(vg,hx+7,hy+4,hx+8,hy+9,{130,139,126},2)
        if swing>0.6 then circle(vg,sx+12,sy-1,2,{142,112,67,145}) end
    elseif action=="water" and name:sub(1,12)~="person-farm-" then
        local tilt=math.sin(clock*2)*2
        line(vg,sx+3,sy-9,sx+9,sy-12,{141,103,61},2)
        polygon(vg,{sx+8,sy-15+tilt,sx+18,sy-14+tilt,sx+16,sy-6+tilt,sx+10,sy-6+tilt},{120,103,78,230})
        line(vg,sx+9,sy-14+tilt,sx+12,sy-18+tilt,{171,151,108},2)
        line(vg,sx+12,sy-18+tilt,sx+17,sy-15+tilt,{171,151,108},2)
        for i=0,2 do
            line(vg,sx+18+i*2,sy-8+tilt,sx+20+i*3,sy-1+math.sin(clock*2+i)*2,{116,167,181,190},1.4)
        end
    elseif action=="harvest" and name:sub(1,12)~="person-farm-" then
        local swing=math.sin(clock*2.3)
        line(vg,sx+3,sy-9,sx+11+swing*3,sy-15+swing*4,{144,100,53},2)
        line(vg,sx+11+swing*3,sy-15+swing*4,sx+17+swing*3,sy-17+swing*4,{189,188,164},2.4)
        line(vg,sx+17+swing*3,sy-17+swing*4,sx+19+swing*3,sy-13+swing*4,{189,188,164},2)
        if swing>0.4 then circle(vg,sx+15,sy-2,2,{222,186,85,170}) end
    elseif action=="cook" then
        local stir=math.sin(clock*6)
        nvgBeginPath(vg);nvgEllipse(vg,sx+10,sy-1,8,4);nvgFillColor(vg,color({82,68,51,220}));nvgFill(vg)
        nvgBeginPath(vg);nvgEllipse(vg,sx+10,sy-3,6,2);nvgFillColor(vg,color({176,137,78,230}));nvgFill(vg)
        line(vg,sx+8,sy-13,sx+10+stir*4,sy-5,{180,145,86},2)
        if stir>0 then circle(vg,sx+13,sy-18-stir*2,2,{233,222,191,100}) end
    elseif action=="butcher" then
        local swing=math.sin(clock*7)
        rect(vg,sx+3,sy-2,17,4,{108,75,45,225})
        line(vg,sx+4,sy-10,sx+12+swing*3,sy-17+swing*8,{139,98,58},2)
        line(vg,sx+10+swing*3,sy-17+swing*8,sx+17+swing*3,sy-15+swing*8,{171,172,157},3)
    end
    thoughtBubble(vg,sx,sy,thought)
end
function WorldView.create(sim, onTile)
    ---@type {x:number,y:number,zoom:number,pinchZoom:number}
    local camera = { x = 0, y = 0, zoom = 1.15, pinchZoom = 1.15 }
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
            local _,ox,oy=projection()
            local px, py = (event.x-ox)/camera.zoom, (event.y-oy)/camera.zoom
            local hit, depth = nil, -math.huge
            for _, building in ipairs(sim.buildings) do
                local width,height=building.footprintW or 1,building.footprintH or 1
                local bx, by = project(building.x-(width-1)*0.5,building.y-(height-1)*0.5)
                local size=buildingVisualSize(building)
                local bottom=18+(height-1)*TILE_H/2
                local facade=building.kind~="farm" and px>=bx-size*0.48 and px<=bx+size*0.48 and
                    py>=by+bottom-size and py<=by+bottom
                local porch=building.kind=="kitchen" and building.complete and
                    px>=bx-44 and px<=bx+44 and py>=by+8 and py<=by+58
                if (facade or porch) and building.y+building.x*0.001 > depth then
                    hit, depth = building, building.y+building.x*0.001
                end
            end
            if hit then x,y = hit.x,hit.y end
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
        local l, ox, oy = projection()
        rect(vg, l.x, l.y, l.w, l.h, { 63, 77, 48 })
        nvgSave(vg); nvgIntersectScissor(vg, l.x, l.y, l.w, l.h)
        nvgTranslate(vg, ox, oy); nvgScale(vg, camera.zoom, camera.zoom)
        -- Inverse-project just the viewport. Work stays bounded as the world expands.
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        for _, px in ipairs({ l.x - 80, l.x + l.w + 80 }) do
            for _, py in ipairs({ l.y - 80, l.y + l.h + 80 }) do
                local wx,wy=unproject((px-ox)/camera.zoom,(py-oy)/camera.zoom)
                minX,maxX=math.min(minX,wx),math.max(maxX,wx)
                minY,maxY=math.min(minY,wy),math.max(maxY,wy)
            end
        end
        minX, maxX, minY, maxY = math.floor(minX), math.ceil(maxX), math.floor(minY), math.ceil(maxY)
        if sim.mode == "finite" then minX, maxX, minY, maxY = math.max(1, minX), math.min(22, maxX), math.max(1, minY), math.min(22, maxY) end
        for y=minY,maxY do
            for x=minX,maxX do
                do
                    local terrain = sim:terrain(x, y)
                    local variation = (x * 17 + y * 23) % 13
                    -- Neighboring ground tiles share one color. Terrain detail is scattered
                    -- separately, so ordinary play has no checkerboard tile boundaries.
                    local c = { 118, 133, 78 }
                    if terrain == "water" then c = { 77, 116, 116 }
                    elseif terrain == "fog" then c = { 69, 88, 68 } end
                    -- Slight overlap hides antialiased hairlines between equal-color diamonds.
                    tile(vg, x, y, c, -1)
                    local sx, sy = project(x, y)
                    if terrain=="grass" or terrain=="forest" then
                        if (x*7+y*11)%3==0 then
                            nvgBeginPath(vg);nvgEllipse(vg,sx+(x*13+y*5)%19-9,sy+(x*3+y*17)%13-6,18,8)
                            nvgFillColor(vg,color({151,150,76,16}));nvgFill(vg)
                        end
                        if (x*11+y*7)%5==0 then
                            for i=0,2 do
                                local tx=sx-17+i*8+(x*3+y)%5
                                local ty=sy+((x*5+y*7+i*3)%17)-9
                                line(vg,tx,ty,tx-2,ty-4,{65,103,50,105},1.4)
                                line(vg,tx,ty,tx+2,ty-3,{153,163,82,100},1)
                            end
                        end
                        if sim:terrain(x+1,y)=="water" or sim:terrain(x-1,y)=="water" then
                            local bankX=sim:terrain(x+1,y)=="water" and sx+TILE_W/2-4 or sx-TILE_W/2+4
                            rect(vg,bankX-4,sy-TILE_H/2,8,TILE_H,{176,158,91,58})
                        end
                    end
                    if (terrain == "grass" or terrain == "forest") and (x*13+y*19)%4 == 0 then
                        local dx, dy = ((x*31+y*13)%27)-13, ((x*11+y*23)%9)-4
                        line(vg, sx+dx, sy+dy, sx+dx-2, sy+dy-3, {76,101,52,85}, 1)
                        circle(vg,sx+dx+3,sy+dy-1,1,{205,190,117,85})
                    end
                    if mode ~= "inspect" and terrain == "grass" then tileOutline(vg,x,y,{239,225,167,105}) end
                    local site=sim:roadSiteAt(x,y)
                    if site then
                        roadSurface(vg,sim,x,y,true)
                        for k=-1,1 do line(vg,sx-12+k*7,sy-3,sx-5+k*7,sy+2,{188,163,102},1) end
                        rect(vg,sx-14,sy+5,28,3,{58,57,37});rect(vg,sx-14,sy+5,28*site.progress,3,{222,184,95})
                    elseif sim.roads[x .. ":" .. y] then
                        roadSurface(vg,sim,x,y,false)
                        line(vg, sx-20,sy+9,sx-6,sy+9,{168,149,110},1)
                        line(vg, sx+7,sy-7,sx+21,sy-7,{213,194,155},1)
                    elseif terrain == "water" and (x*7+y*11)%3 == 0 then
                        line(vg, sx - 9, sy + math.sin(sim.elapsed + x) * 2, sx + 10, sy + 1, { 187, 210, 188, 95 }, 1)
                    elseif (x * 7 + y) % 9 == 0 then
                        line(vg, sx, sy, sx - 2, sy - 3, { 107, 137, 78 }, 1)
                        circle(vg, sx + 7, sy - 2, 1, { 223, 207, 141 })
                    end
                end
            end
        end
        local agentsByDepth,diningSides={},{}
        local function diningSide(b)
            if not diningSides[b.id] then diningSides[b.id]=Meals.diningSide(sim,b) end
            return diningSides[b.id]
        end
        local function addAgent(a,role,profile,action,cargo,queueSlot,guardIndex)
            if Meals.hidden(sim,a) then return end
            local drawX,drawY=a.x,a.y
            local diningHall=nil
            if a.meal and sim.buildings[a.meal.target] and sim.buildings[a.meal.target].kind=="kitchen"
                and (a.meal.phase=="enter" or a.meal.phase=="eat" or a.meal.phase=="exit") then
                diningHall=sim.buildings[a.meal.target]
                local sx,sy=Meals.seatPosition(diningHall,a.meal.seat or 1,diningSide(diningHall))
                local progress=a.meal.phase=="enter" and (1-a.meal.timer/0.7) or
                    a.meal.phase=="exit" and (a.meal.timer/0.7) or 1
                progress=math.max(0,math.min(1,progress))
                drawX=diningHall.x+(sx-diningHall.x)*progress
                drawY=diningHall.y+1+(sy-diningHall.y-1)*progress
            elseif a.meal and a.meal.phase=="queue" then
                local place=(queueSlot or 1)%3
                drawX=drawX+(place-1)*0.18
                drawY=drawY+math.floor((queueSlot or 1)/3)*0.13
            elseif (a.farmPresence or 0)>0 and a.building then
                local field=sim.buildings[a.building]
                if field and field.kind=="farm" then
                    local clock=a.workClock or 0
                    local presence=a.farmPresence
                    local centerX=field.x-((field.footprintW or 1)-1)*0.5
                    local centerY=field.y-((field.footprintH or 1)-1)*0.5
                    drawX=a.x+(centerX+math.sin(clock*0.8+(a.slot or 0))*0.22-a.x)*presence
                    drawY=a.y+(centerY+0.42+math.cos(clock*0.8+(a.slot or 0))*0.14-a.y)*presence
                end
            elseif guardIndex and not a.meal and not (a.path and a.path[a.index]) then
                drawX=9.3+((guardIndex-1)%3)*0.28
                drawY=9.25+math.floor((guardIndex-1)/3)*0.2
            end
            local depth=math.floor(drawY+0.5)
            if diningHall then depth=diningHall.y end
            if (a.farmPresence or 0)>0 and a.building then
                local field=sim.buildings[a.building]
                if field and field.kind=="farm" then depth=math.max(depth,field.y) end
            end
            local sx,sy=project(drawX,drawY)
            if depth < minY or depth > maxY or sx*camera.zoom+ox < l.x-70 or sx*camera.zoom+ox > l.x+l.w+70
                or sy*camera.zoom+oy < l.y-70 or sy*camera.zoom+oy > l.y+l.h+70 then return end
            agentsByDepth[depth]=agentsByDepth[depth] or {}
            local walking=(a.path and a.path[a.index] ~= nil) or (a.farmPresence and a.farmPresence>0 and a.farmPresence<1) or
                (a.meal and (a.meal.phase=="enter" or a.meal.phase=="exit"))
            local clock=(walking or action=="hammer" or action=="eat" or action=="farm" or action=="plow" or
                action=="water" or action=="tend" or action=="harvest" or action=="cook" or action=="butcher" or action=="chop") and sim.elapsed or 0
            local thought
            if not a.meal or a.meal.phase=="walk" or a.meal.phase=="queue" then
                if (a.hunger or 0)>=65 then thought="food"
                elseif (a.energy or 100)<=30 then thought="rest"
                elseif a.building then
                    local b=sim.buildings[a.building]
                    local def=b and D.buildings[b.kind]
                    if def and def.input and b.inputs==0 and not b.incoming and (sim.stock[def.input] or 0)==0
                        and (not def.alternateInput or (sim.stock[def.alternateInput] or 0)==0) then thought=def.input
                    elseif b and b.kind=="woodcutter" and (sim.timber==0 or not sim:nearestTree(b,6)) and not a.woodPhase then thought="wood"
                    elseif b and b.kind=="quarry" and sim.rock==0 then thought="stone" end
                end
            end
            local entry={actor=a,x=drawX,y=drawY,role=role,profile=profile,action=action,cargo=cargo,
                amount=a.job and a.job.amount or nil,thought=thought,clock=clock,walking=walking,phase=queueSlot or 0}
            table.insert(agentsByDepth[depth],entry)
        end
        for index,a in ipairs(sim.carriers) do
            local role,profile=Characters.carrier(index,a.carrying)
            local action=a.meal and a.meal.phase=="eat" and "eat" or nil
            addAgent(a,role,profile,action,a.job and a.job.resource or nil,index)
        end
        for _,a in pairs(sim.workers) do
            local b=sim.buildings[a.building]
            local role,profile=Characters.worker(b,a.slot)
            local action=a.meal and a.meal.phase=="eat" and "eat" or
                (not a.meal and (b.kind=="farm" and Farm.needsWork(b,D.buildings.farm.period) and (a.farmPresence or 0)>=0.95 and Farm.action(b) or
                    b.kind=="ranch" and "farm" or
                    b.kind=="woodcutter" and a.woodPhase=="chop" and "chop" or
                    b.kind=="kitchen" and "cook" or b.kind=="butcher" and "butcher" or nil))
            if role then addAgent(a,role,profile,action,a.carrying and "wood" or nil,a.building*2+a.slot) end
        end
        for index,a in ipairs(sim.builders) do
            if a.active or a.meal then
                local role,profile=Characters.carrier(index,false)
                local action=a.meal and a.meal.phase=="eat" and "eat" or (a.phase=="hammer" and "hammer" or nil)
                addAgent(a,role,profile,action,a.carrying and "wood" or nil,index)
            end
        end
        for index,a in ipairs(sim.guards or {}) do
            local role,profile=Characters.militia(index)
            local action=a.meal and a.meal.phase=="eat" and "eat" or nil
            addAgent(a,role,profile,action,nil,index,index)
        end
        for y=minY,maxY do
            for x=minX,maxX do
                do
                    if sim:standingTree(x,y) and not sim:buildingAt(x,y) then local sx, sy = project(x, y); tree(vg, sx, sy, x * 3 + y) end
                    local b = sim:buildingAt(x, y)
                    if not b and not sim.roads[x .. ":" .. y] then
                        local terrain = sim:terrain(x,y)
                        local sx,sy = project(x,y)
                        if terrain == "forest" and (x*7+y*3)%13 == 0 then Art.draw(vg, "rock-moss", sx-27,sy-32,54,40)
                        elseif terrain == "grass" and (x*11+y*7)%13 == 0 then Art.draw(vg, "bush-flowers",sx-18,sy-22,36,30)
                        elseif terrain == "water" and sim:terrain(x-1,y) ~= "water" and (x+y)%3 == 0 then Art.draw(vg,"reeds",sx-20,sy-28,40,35) end
                    end
                    if b and b.x==x and b.y==y then
                        house(vg,b,selected==b,sim.elapsed,nil,false,sim)
                        if b.kind=="kitchen" and b.complete then diningFloor(vg,b,diningSide(b)) end
                    end
                    if ghost and mode ~= "inspect" and ghost.x==x and ghost.y==y then
                        local width,height=D.footprint(mode)
                        local valid=sim:canBuild(mode,x,y)
                        for dx=1-width,0 do for dy=1-height,0 do
                            tile(vg,x+dx,y+dy,valid and {106,207,150,180} or {220,95,78,185},2)
                        end end
                        if mode ~= "road" then
                            house(vg,{kind=mode,x=x,y=y,footprintW=width,footprintH=height,complete=false,progress=0},false,sim.elapsed,nil,true,sim)
                        end
                    end
                end
            end
            local bucket=agentsByDepth[y]
            if bucket then
                for _,entry in ipairs(bucket) do
                    local a=entry.actor
                    person(vg,entry.x,entry.y,entry.profile.color,a.carrying,entry.clock,entry.role,a.facing or "se",entry.profile,entry.action,entry.cargo,entry.walking,entry.phase,entry.thought,entry.amount)
                end
            end
        end
        for _, e in ipairs(sim.enemies) do if e.hp > 0 then person(vg, e.x, e.y, { 74, 64, 73 }, false, sim.elapsed, "bandit", "sw") end end
        nvgRestore(vg)
    end
    ---@class VillageWorldView
    local result = {
        panel = panel,
        minimap = minimap,
        dispose = function() end,

        setMode = function(value) mode = value; ghost = nil end,
        previewState = function() return ghost end,
        select = function(value) selected = value end,
        selectedBuilding = function() return selected end,
        zoom = function(delta) camera.zoom = math.max(0.55, math.min(1.8, camera.zoom + delta)) end,
        home = function() camera.x, camera.y, camera.zoom = 0, 0, 1.15 end,
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
