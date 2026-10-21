-- Runtime pixel resources. Source art and packing are maintained separately.
local A = { root = 'art/pixel-v1/', cellW = 64, cellH = 48, actorW = 40, actorH = 48, walkCycle=40, cargoColumns=32, goods={wood=0,stone=1,grain=2,flour=3,livestock=4,meat=5,food=6,rawwood=8,bread=9,rawstone=10,ironore=11,coal=12,goldore=13,iron=14,gold=15,fish=16,hide=17,leather=18,bow=19,leatherarmor=20,ironspear=21,ironarmor=22} }
local handles, context = {}, nil
---@class PixelBuildingSpec
---@field path string
---@field width number
---@field height number
---@field anchorX number
---@field anchorY number
---@field doorX number
---@field doorY number
---@field seats number[][]?
---@field workBounds number[]?
---@field packed_box number[]?
---@field hitbox number[]?
---@field cookWindow number[]?
---@field chimney number[]?
---@field sawPoint number[]?
---@field ovenPoint number[]?
---@field workPoint number[]?
---@field smokeBounds number[]?
---@type table<string,PixelBuildingSpec>
A.buildings = {}
for kind in pairs(require('game.Definitions').buildings) do
    A.buildings[kind] = { path='buildings/'..kind..'.png', width=256, height=224, anchorX=192, anchorY=176,doorX=128,doorY=196 }
end
-- A generated asset may use another canvas, but its registered door is always
-- mapped to the simulation's existing south-east entrance. Never bbox-fit it.
function A.register(kind,spec) A.buildings[kind]=spec end
function A.loadCatalog()
    if A.catalogLoaded then return end
    local path=A.root..'buildings-import.json'
    if not cache:Exists(path) then return end
    local file=cache:GetFile(path)
    if not file then return end
    local content=file:ReadString();file:Close()
    local ok,catalog=pcall(cjson.decode,content)
    if ok and type(catalog)=='table' then
        A.catalogLoaded=true
        for kind,spec in pairs(catalog.buildings or {}) do A.register(kind,spec) end
    end
end
function A.texture(vg,path)
    context=vg
    local full=A.root..path
    if handles[full] then return handles[full] end
    if not cache:Exists(full) then return nil end
    local handle=nvgCreateImage(vg,full,NVG_IMAGE_NEAREST or 32)
    if handle and handle>0 then handles[full]=handle;return handle end
end
function A.draw(vg,path,x,y,w,h,col,row,cols,rows,alpha)
    local image=A.texture(vg,path)
    if not image then return false end
    cols,rows=cols or 1,rows or 1
    x,y=math.floor(x+.5),math.floor(y+.5)
    nvgBeginPath(vg);nvgRect(vg,x,y,w,h)
    nvgFillPaint(vg,nvgImagePattern(vg,x-(col or 0)*w,y-(row or 0)*h,w*cols,h*rows,0,image,alpha or 1));nvgFill(vg)
    return true
end
A.roles={forester='roles/forester.png',miner='roles/miner.png',fisher='roles/fisher.png',mason='roles/mason.png',
    smith='roles/smith.png',leatherworker='roles/leatherworker.png',carpenter='roles/carpenter.png',archer='roles/archer.png',spearman='roles/longspearman.png'}
function A.profession(p)
    if p.faction=='guard' then return p.actor.unit end
    return p.building and require('game.Definitions').buildings[p.building.kind].profession or p.actor.profession
end
function A.sprite(vg,sprite,x,y)
    local w,h=sprite.width or 40,sprite.height or 48
    local ax,ay=sprite.anchorX or 20,sprite.anchorY or 44
    nvgSave(vg);nvgTranslate(vg,math.floor(x+.5),math.floor(y+.5))
    if sprite.flipX then nvgScale(vg,-1,1)end
    local drawn=A.draw(vg,sprite.path,-ax,-ay,w,h,sprite.frame,sprite.row,sprite.cols,sprite.rows)
    nvgRestore(vg);return drawn
end
function A.loadLifeCatalog()
    if A.lifeAtlases then return end
    local path=A.root..'life/life-import.json'
    if not cache:Exists(path)then return end
    local f=cache:GetFile(path);if not f then return end
    local content=f:ReadString();f:Close()
    local ok,data=pcall(cjson.decode,content)
    if ok and type(data)=='table'then A.lifeAtlases=data.atlases end
end
local function special(path,row,frame,rows,flip)
    A.loadLifeCatalog()
    local m=A.lifeAtlases and A.lifeAtlases[path]
    return {path='life/'..path..'.png',row=row,frame=frame,cols=m and m.columns or 4,rows=m and #m.rows or rows,
        width=m and m.cell[1]or 80,height=m and m.cell[2]or 72,
        anchorX=m and m.anchor[1]or 40,anchorY=m and m.anchor[2]or 64,flipX=flip}
end
function A.lifeSprite(p)
    local b,l=p.building,p.actor.life
    if not b or not l or p.actor.meal or p.walking and p.action~='ride'then return end
    local action=p.action;local t=p.actionClock or 0
    if b.kind=='fishery'then
        if action=='rest'then return special('fisher-rocker',0,math.floor(t*1.5)%4,1)end
        if action=='rise'then return special('fisher-actions',1,math.min(3,math.floor(t/.2)),5)end
        if action=='stow'then return special('fisher-actions',4,math.min(3,math.floor(t/.3)),5)end
        if action=='cast'or action=='reel'or action=='wait'then
            local water,shore=b.site.waterCell,b.site.shoreCell
            local vertical=water.y~=shore.y
            local frame=action=='wait'and math.floor(t*.7)%4 or math.min(3,math.floor(t/.35))
            if vertical then
                local row=(water.y>shore.y and 3 or 0)+(action=='cast'and 0 or action=='reel'and 1 or 2)
                return special('fisher-vertical',row,frame,6)
            end
            return special('fisher-actions',action=='cast'and 2 or action=='reel'and 3 or 2,
                action=='wait'and 3 or frame,5,water.x<shore.x)
        end
    elseif action=='ride'then
        return special('props',2,1,5)
    end
    if action=='cut'then
        return {path='roles/mason.png',frame=math.floor(t*3)%4,row=4,cols=4,rows=6}
    end
end
A.workshopFamilies={mill='miller',bakery='baker',butcher='butcher',sawmill='carpenter',woodweapons='carpenter',smelter='smith',ironweapons='smith',ironarmor='smith',tannery='leatherworker',leatherarmor='leatherworker'}
function A.loadWorkshops()
    if A.workshops then return end
    local path=A.root..'life/workshop-import.json'
    if not cache:Exists(path)then return end
    local f=cache:GetFile(path);if not f then return end
    local data=f:ReadString();f:Close();local ok,result=pcall(cjson.decode,data)
    if ok and type(result)=='table'then A.workshops=result.atlases end
end
function A.workshopSprite(p)
    local b=p.building;local family=b and A.workshopFamilies[b.kind]
    if not family or p.actor.meal or p.walking then return end
    if p.action~='work'and p.action~='workshopIdle'and p.action~='workshopFinish'then return end
    A.loadWorkshops();local m=A.workshops and A.workshops[family];if not m then return end
    local E=require('game.Economy');local row,frame=0,0
    if p.action=='workshopIdle'then
        local reason=p.actor.breaks and p.actor.breaks.reason
        frame=reason=='stopped'and 0 or math.floor((p.actionClock or 0)*.8)%4
    else
        local finished=p.action=='workshopFinish'and(p.actor.workLoad~=nil or b.visualFinishResource and E.outputAmount(b,b.visualFinishResource)>0)
        local ratio=(b.timer or 0)/E.period(b)
        row=finished and 3 or ratio<.12 and 1 or 2
        if not finished and b.kind=='smelter'then row=1 end
        if not finished and b.kind=='leatherarmor'then row=3 end
        if not finished and p.actor.slot==2 then row=1 end
        frame=finished and math.min(3,math.floor((1.2-(p.actor.workFinishLeft or 0))/.3))or math.floor((b.visualWorkSeconds or b.timer or 0)*3)%4
        -- Keep the orange miller upright while the actual finished batch is held.
        if finished and family=='miller'and p.look==1 then row,frame=0,0 end
    end
    local base=(m.looks or 1)>1 and p.look*4 or 0
    return {path='life/'..m.file,width=m.cell[1],height=m.cell[2],anchorX=m.anchor[1],anchorY=m.anchor[2],
        frame=frame,row=base+row,cols=m.columns,rows=m.rowCount,flipX=p.action~='workshopIdle'and(p.actor.workshopOutdoor and p.actor.slot==2 or A.buildings[b.kind].workFacing=='west')}
end
function A.actorSprite(p,clock)
    local workshop=A.workshopSprite(p)
    if workshop then return workshop end
    local life=A.lifeSprite(p)
    if life then return life end
    if p.action=='lean'and cache:Exists(A.root..'life/chef-lean.png')then return {path='life/chef-lean.png',row=0,frame=math.floor((p.actionClock or 0)*.5)%4,cols=4,rows=1}end
    local role=A.profession(p)
    local path=role and A.roles[role]
    if path and cache:Exists(A.root..path) then
        if role=='forester' and p.action=='chop' and cache:Exists(A.root..'roles/forester-chop.png') then
            return {path='roles/forester-chop.png',frame=math.floor((p.actionClock or 0)/.4)%4,row=0,cols=4,rows=1}
        end
        local row=p.direction
        local frame=p.frame
        if p.action=='eat' then row,frame=5,math.floor((p.actionClock or 0)*2)%4
        elseif p.action=='work' or p.action=='chop' or p.action=='plant' or p.action=='attack' then row,frame=4,math.floor((p.actionClock or 0)*3)%4 end
        return {path=path,frame=frame,row=row,cols=4,rows=6}
    end
    local row=p.look*4+p.direction
    local workClock=p.actionClock or 0
    if p.building and p.building.kind=='kitchen' then
        if p.action=='eat' then return {path='chef-eat.png',frame=math.floor(workClock*2)%4,row=0,cols=4,rows=1} end
        if p.action=='cook' then return {path='chef-cook.png',frame=math.floor(workClock*3)%4,row=0,cols=4,rows=1} end
        return {path='chef-walk.png',frame=p.frame,row=p.direction,cols=4,rows=4}
    end
    if p.action=='eat' then return {path='workers-eat.png',frame=math.floor(workClock*2)%4,row=p.look,cols=4,rows=2} end
    if p.action=='chop' then return {path=p.actor.treeX and p.actor.treeX<p.x and 'workers-chop-left.png' or 'workers-chop.png',
        frame=math.floor(workClock/.4)%4,row=p.look,cols=4,rows=2} end
    if p.action=='plow' or p.action=='water' or p.action=='tend' or p.action=='harvest' then
        return {path='workers-farm.png',frame=math.floor(workClock/.45)%4,row=p.look,cols=4,rows=2}
    end
    if p.action=='hammer' then
        local side=p.actor.job and p.actor.job.side
        local job=p.actor.job
        if job and job.kind=='road' then
            side=job.doorX<job.x and 'west' or job.doorX>job.x and 'east' or job.doorY<job.y and 'north' or 'south'
        end
        local back=side=='south'
        if back then return {path='workers-hammer-back.png',frame=math.floor((p.actor.timer or clock)/.4)%4,row=p.look,cols=4,rows=2} end
        -- Unavailable orientations retain a truthful facing rather than flip
        -- the actor each cycle. Back-facing tools are a separate asset contract.
        return {path=side=='east' and 'workers-actions-left.png' or 'workers-actions.png',
            frame=math.floor((p.actor.timer or clock)/.4)%4,row=p.look*4+(side=='north' and 1 or 0),cols=4,rows=8}
    end
    if(p.cargo or p.action=='pickup')and p.direction~=3 then
        return {path=p.direction==1 and 'workers-actions-left.png' or 'workers-actions.png',
            frame=p.frame,row=p.look*4+(p.direction==0 and 3 or 2),cols=4,rows=8}
    end
    return {path='workers-walk.png',frame=p.frame,row=row,cols=4,rows=8}
end
function A.road(vg,x,y,mask)
    local image=A.texture(vg,'terrain.png')
    if not image then return false end
    nvgBeginPath(vg);nvgRect(vg,x-12,y-12,24,24)
    if mask&1~=0 then nvgRect(vg,x-12,y-24,24,12) end
    if mask&2~=0 then nvgRect(vg,x+12,y-12,20,24) end
    if mask&4~=0 then nvgRect(vg,x-12,y+12,24,12) end
    if mask&8~=0 then nvgRect(vg,x-32,y-12,20,24) end
    nvgFillPaint(vg,nvgImagePattern(vg,x-96,y-24,256,48,0,image,1));nvgFill(vg)
    return true
end
function A.pave(vg,x,y,w,h)
    nvgSave(vg);nvgIntersectScissor(vg,x,y,w,h)
    for gy=math.floor(y/48),math.floor((y+h)/48) do
        for gx=math.floor(x/64),math.floor((x+w)/64) do A.draw(vg,'terrain.png',gx*64,gy*48,64,48,1,0,4,1) end
    end
    nvgRestore(vg)
end
function A.building(vg,path,x,y,w,h)
    if path~='buildings/kitchen.png' then return A.draw(vg,path,x,y,w,h) end
    -- The original kitchen sheet has decorative smoke. Keep it out of the
    -- base so production, rather than the illustration, controls the chimney.
    local bounds=A.buildings.kitchen.smokeBounds or {198,0,226,89}
    local regions={{0,0,bounds[1],224},{bounds[3],0,256-bounds[3],224},
        {bounds[1],bounds[4],bounds[3]-bounds[1],224-bounds[4]}}
    local drawn=false
    for _,r in ipairs(regions) do
        nvgSave(vg);nvgIntersectScissor(vg,x+r[1],y+r[2],r[3],r[4])
        drawn=A.draw(vg,path,x,y,w,h) or drawn;nvgRestore(vg)
    end
    return drawn
end
function A.release()
    if context then for _,handle in pairs(handles) do nvgDeleteImage(context,handle) end end
    handles,context={},nil
end
return A
