local UI = require "urhox-libs/UI"
local D = require "game.Definitions"
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
local function iso(x, y) return (x - y) * 30, (x + y) * 15 end
local function tile(vg, x, y, c, shrink)
    local sx, sy = iso(x, y); local a = 30 - (shrink or 0); local b = a / 2
    polygon(vg, { sx, sy - b, sx + a, sy, sx, sy + b, sx - a, sy }, c)
end
local function tree(vg, sx, sy, seed)
    nvgBeginPath(vg); nvgEllipse(vg, sx + 5, sy + 2, 19, 7); nvgFillColor(vg, color({ 37, 58, 39, 45 })); nvgFill(vg)
    rect(vg, sx - 2, sy - 29, 5, 30, { 96, 75, 50 })
    local height = 38 + seed % 9
    polygon(vg, { sx, sy - height - 16, sx + 20, sy - 13, sx - 20, sy - 13 }, { 56, 88 + seed % 16, 64 })
    polygon(vg, { sx, sy - height - 16, sx, sy - 12, sx - 20, sy - 13 }, { 75, 112, 74 })
    polygon(vg, { sx, sy - height - 10, sx + 14, sy - 22, sx - 14, sy - 22 }, { 79, 118, 79 })
end
local function house(vg, b, selected, clock)
    local x, y = iso(b.x, b.y)
    local def = D.buildings[b.kind]
    if selected then tile(vg, b.x, b.y, { 239, 208, 115, 210 }) end
    if b.kind == "farm" then
        tile(vg, b.x, b.y, { 132, 113, 65 })
        for row = -2, 2 do
            for col = -2, 2 do
                local px, py = x + (col - row) * 5, y + (col + row) * 2.5
                line(vg, px, py, px + 1, py - 9 - math.sin(clock + col) * 1.5, { 214, 188, 85 }, 2)
                line(vg, px + 1, py - 4, px - 3, py - 7, { 167, 171, 68 }, 1)
            end
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
    if not b.complete then
        for i = -1, 1 do line(vg, x + i * 19, y + 10, x + i * 19, y - 48, { 174, 141, 86 }, 2) end
        line(vg, x - 22, y - 28, x + 22, y - 28, { 199, 169, 110 }, 2)
        rect(vg, x - 22, y + 17, 44, 4, { 75, 72, 49 }); rect(vg, x - 22, y + 17, 44 * b.progress, 4, { 233, 199, 109 })
    end
end
local function person(vg, x, y, c, carrying, clock)
    local sx, sy = iso(x, y); local step = math.sin(clock * 9 + x) * 2
    nvgBeginPath(vg); nvgEllipse(vg, sx, sy + 2, 5, 2); nvgFillColor(vg, color({ 30, 42, 28, 65 })); nvgFill(vg)
    line(vg, sx - 1, sy - 2, sx - 3, sy + 3 + step, { 62, 64, 56 }, 2)
    line(vg, sx + 1, sy - 2, sx + 3, sy + 3 - step, { 62, 64, 56 }, 2)
    rect(vg, sx - 3, sy - 11, 6, 10, c); circle(vg, sx, sy - 14, 3, { 218, 181, 130 })
    polygon(vg, { sx, sy - 19, sx + 6, sy - 13, sx - 6, sy - 13 }, { 197, 167, 103 })
    if carrying then rect(vg, sx + 2, sy - 12, 7, 6, { 190, 144, 75 }) end
end
function WorldView.create(sim, onTile)
    ---@type {x:number,y:number,zoom:number,pinchZoom:number}
    local camera = { x = 0, y = 0, zoom = 1, pinchZoom = 1 }
    local panel = UI.Panel { position = "absolute", top = 0, bottom = 0, left = 0, right = 0, pointerEvents = "auto" }
    local mode = "inspect"
    local selected = false
    local function projection()
        local l = panel:GetAbsoluteLayout()
        return l, l.x + l.w * 0.53 + camera.x, l.y + l.h * 0.52 - 270 * camera.zoom + camera.y
    end
    panel.props.onTap = function(event)
        local _, ox, oy = projection()
        local a, b = (event.x - ox) / camera.zoom / 30, (event.y - oy) / camera.zoom / 15
        local x, y = math.floor((a + b) / 2 + 0.5), math.floor((b - a) / 2 + 0.5)
        onTile(x, y)
    end
    panel.props.onPanStart = function() end
    panel.props.onPanMove = function(event)
        camera.x, camera.y = camera.x + event.deltaX, camera.y + event.deltaY
        if sim.mode == "finite" then
            camera.x = math.max(-600, math.min(600, camera.x))
            camera.y = math.max(-350, math.min(350, camera.y))
        end
    end
    panel.props.onPinchStart = function() camera.pinchZoom = camera.zoom end
    panel.props.onPinchMove = function(event) camera.zoom = math.max(0.55, math.min(1.8, camera.pinchZoom * event.scale)) end
    function panel:Render(vg)
        local l, ox, oy = projection()
        rect(vg, l.x, l.y, l.w, l.h, { 89, 111, 78 })
        nvgSave(vg); nvgIntersectScissor(vg, l.x, l.y, l.w, l.h)
        nvgTranslate(vg, ox, oy); nvgScale(vg, camera.zoom, camera.zoom)
        -- Inverse-project just the viewport. Work stays bounded as the world expands.
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        for _, px in ipairs({ l.x - 80, l.x + l.w + 80 }) do
            for _, py in ipairs({ l.y - 80, l.y + l.h + 80 }) do
                local a, b = (px - ox) / camera.zoom / 30, (py - oy) / camera.zoom / 15
                minX, maxX = math.min(minX, (a + b) / 2), math.max(maxX, (a + b) / 2)
                minY, maxY = math.min(minY, (b - a) / 2), math.max(maxY, (b - a) / 2)
            end
        end
        minX, maxX, minY, maxY = math.floor(minX), math.ceil(maxX), math.floor(minY), math.ceil(maxY)
        if sim.mode == "finite" then minX, maxX, minY, maxY = math.max(1, minX), math.min(22, maxX), math.max(1, minY), math.min(22, maxY) end
        for sum = minX + minY, maxX + maxY do
            for x = math.max(minX, sum - maxY), math.min(maxX, sum - minY) do
                local y = sum - x
                do
                    local terrain = sim:terrain(x, y)
                    local variation = (x * 17 + y * 23) % 13
                    local c = { 132 + variation, 151 + variation, 96 + variation }
                    if terrain == "water" then c = { 100, 148 + variation, 154 + variation }
                    elseif terrain == "fog" then c = { 66 + variation, 85 + variation, 66 + variation }
                    elseif terrain == "forest" then c = { 109 + variation, 135 + variation, 84 + variation } end
                    tile(vg, x, y, c)
                    local sx, sy = iso(x, y)
                    if sim.roads[x .. ":" .. y] then
                        tile(vg, x, y, { 193, 174, 132 }, 1)
                        line(vg, sx - 13, sy, sx + 3, sy + 7, { 168, 149, 110 }, 1)
                        line(vg, sx + 8, sy - 6, sx + 18, sy - 1, { 213, 194, 155 }, 1)
                    elseif terrain == "water" then
                        line(vg, sx - 9, sy + math.sin(sim.elapsed + x) * 2, sx + 10, sy + 1, { 187, 210, 188, 95 }, 1)
                    elseif mode ~= "inspect" and terrain == "grass" then
                        polygon(vg, { sx, sy - 14, sx + 28, sy, sx, sy + 14, sx - 28, sy }, { 233, 224, 171, 18 })
                    elseif (x * 7 + y) % 9 == 0 then
                        line(vg, sx, sy, sx - 2, sy - 3, { 107, 137, 78 }, 1)
                        circle(vg, sx + 7, sy - 2, 1, { 223, 207, 141 })
                    end
                end
            end
        end
        for sum = minX + minY, maxX + maxY do
            for x = math.max(minX, sum - maxY), math.min(maxX, sum - minY) do
                local y = sum - x
                do
                    if sim:terrain(x, y) == "forest" and (x + y) % 2 == 0 then local sx, sy = iso(x, y); tree(vg, sx, sy, x * 3 + y) end
                    local b = sim:buildingAt(x, y)
                    if b then house(vg, b, selected == b, sim.elapsed) end
                end
            end
            for _, c in ipairs(sim.carriers) do
                if math.floor(c.x + c.y + 0.5) == sum then person(vg, c.x, c.y, { 91, 116, 131 }, c.carrying, sim.elapsed) end
            end
        end
        for i = 1, sim.militia do person(vg, 8 + (i % 4) * 0.4, 10 + math.floor((i - 1) / 4) * 0.5, { 125, 64, 53 }, false, 0) end
        for _, e in ipairs(sim.enemies) do if e.hp > 0 then person(vg, e.x, e.y, { 74, 64, 73 }, false, sim.elapsed) end end
        nvgRestore(vg)
    end
    ---@class VillageWorldView
    local result = {
        panel = panel,
        setMode = function(value) mode = value end,
        select = function(value) selected = value end,
        zoom = function(delta) camera.zoom = math.max(0.55, math.min(1.8, camera.zoom + delta)) end,
        home = function() camera.x, camera.y, camera.zoom = 0, 0, 1 end,
        frontier = function()
            local _, high = sim.map:bounds()
            local sx, sy = iso(high - 2, 9)
            camera.x, camera.y = -sx * camera.zoom, (270 - sy) * camera.zoom
        end,
    }
    return result
end
return WorldView
