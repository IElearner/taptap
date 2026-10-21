-- Pure Lua simulation: no engine dependency. All goods move on connected roads.
local D = require "game.Definitions"
local WorldMap = require "game.WorldMap"
local Construction = require "game.Construction"
local Meals = require "game.Meals"
local Farm = require "game.FarmCycle"
local Ranch = require "game.RanchCycle"
local Move = require "game.Movement"
local Cargo = require "game.Cargo"
local Economy=require "game.Economy"
local Production=require "game.Production"
local Forestry=require "game.Forestry"
local Deposits=require "game.Deposits"
local Military=require "game.Military"
local Campaign=require "game.Campaign"
local WorkSites=require 'game.WorkSites'
local WorkLife=require 'game.WorkLife'
local CarrierLife=require 'game.CarrierLife'
---@class VillageSimulation
---@field roads table<string,boolean>
---@field buildings table[]
---@field jobs table[]
---@field carriers table[]
---@field stock table<string,number>
---@field produced table<string,number>
---@field population number
---@field militia number
---@field lesson number
---@field elapsed number
---@field foodClock number
---@field speed number
---@field paused boolean
---@field started boolean
---@field skipped boolean
---@field message string
---@field messageTime number
---@field raid boolean
---@field victory boolean
---@field defeat boolean
---@field enemies table[]
---@field health number
---@field combatClock number
---@field roadCount number
---@field mode string
---@field map VillageWorldMap
---@field wave number
---@field wavesDefeated number
---@field nextRaid number
---@field defended boolean
---@field timber number
---@field rock number
---@field score number
---@field buildingIndex table<string,table>
---@field menuOpen boolean?
---@field pendingRoads table[]
---@field roadPlanIndex table<string,table>
---@field builders table[]
---@field workers table<string,table>
---@field guards table[]
---@field mealsServed number
local S = {}
S.__index = S
local directions = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local function key(x, y) return x .. ":" .. y end
local function copy(t) local result = {}; for k, v in pairs(t) do result[k] = v end; return result end

function S.new(mode, seed)
    local self = setmetatable({}, S)
    self:init(mode, seed)
    return self
end
function S:init(mode, seed)
    self.mode = mode == "infinite" and "infinite" or "finite"
    self.map = WorldMap.new(self.mode, seed)
    self.wave, self.wavesDefeated, self.nextRaid = 0, 0, 240
    self.defended, self.timber, self.rock, self.score = false, 320, 180, 0
    self.roads, self.buildings, self.jobs, self.carriers = {}, {}, {}, {}
    self.felledTrees,self.treeGrowth,self.minerals,self.regrownTrees = {},{},{},0
    self.buildingIndex = {}
    self.pendingRoads,self.roadPlanIndex,self.builders,self.workers,self.guards,self.mealsServed={},{},{},{},{},0
    ---@type table<string, number>
    self.stock = { wood = 72, stone = 40, grain = 0, flour = 0, livestock = 0, meat = 0, rawwood = 0, bread = 0, food = 28 }
    for _,resource in ipairs(D.goods) do self.stock[resource]=self.stock[resource] or 0 end
    if self.mode == "infinite" then self.stock.food = 48 end
    self.produced = { food = 0 }
    self.forestryTendSeconds,self.fishMealsCooked=0,0
    self.campaignCompleted,self.freePlay,self.campaignRaid=false,false,false
    self.milestoneEligible,self.campaignMilestoneWave=false,0
    self.population, self.militia, self.lesson = 10, 0, 1
    self.elapsed, self.foodClock, self.speed = 0, 0, 1
    self.paused, self.started, self.skipped = false, false, false
    self.message, self.messageTime = "欢迎来到清溪里，随里正一起重建村庄。", 6
    self.raid, self.victory, self.defeat = false, false, false
    self.enemies, self.health, self.combatClock = {}, 100, 0
    self.roadCount = 0
    self:addBuilding("store", 10, 8, true)
    for x = 8, 12 do self.roads[key(x, 9)] = true end
    for i = 1, 3 do
        self.carriers[i] = { x = 10, y = 9, path = {}, index = 1, job = false, carrying = false, hunger = i*7, energy = 100,workerLook=math.random(2) }
    end
end
function S:notify(message)
    self.message, self.messageTime = message, 4
end
function S:terrain(x, y)
    return self.map:terrain(x, y)
end
function S:standingTree(x,y)
    -- Irregular stands read as a woodland, while each tile remains stable for saves.
    return self:terrain(x,y)=="forest" and (x*17+y*31+x*y*7)%11<7 and not self.felledTrees[key(x,y)]
end
function S:treeCount(b, maximum)
    local total=0
    local cx=b.x-((b.footprintW or 1)-1)*.5
    for x=math.floor(cx-maximum),math.ceil(cx+maximum) do
        for y=b.y-maximum,b.y+maximum do
            if math.abs(x-cx)+math.abs(y-b.y)<=maximum and self:standingTree(x,y) then total=total+1 end
        end
    end
    return total
end
function S:nearestTree(b, maximum)
    local best, distance
    local cx=b.x-((b.footprintW or 1)-1)*0.5
    for x=math.floor(cx-maximum),math.ceil(cx+maximum) do
        for y=b.y-maximum,b.y+maximum do
            local d=math.abs(x-cx)+math.abs(y-b.y)
            if d<=maximum and (not distance or d<distance) and self:standingTree(x,y) then
                local claimed=false
                for _,a in pairs(self.workers) do
                    if a.treeX==x and a.treeY==y and a.woodPhase then claimed=true;break end
                end
                if not claimed then best,distance={x=x,y=y},d end
            end
        end
    end
    return best
end
function S:reachableTree(b,maximum,blocked)
    local candidates={};local cx=b.x-((b.footprintW or 1)-1)*.5
    for x=math.floor(cx-maximum),math.ceil(cx+maximum)do for y=b.y-maximum,b.y+maximum do
        local distance=math.abs(x-cx)+math.abs(y-b.y)
        if distance<=maximum and self:standingTree(x,y)then
            local claimed=false
            for _,a in pairs(self.workers)do if a.treeX==x and a.treeY==y and a.woodPhase then claimed=true;break end end
            if not claimed then candidates[#candidates+1]={x=x,y=y,distance=distance}end
        end
    end end
    table.sort(candidates,function(a,c)if a.distance~=c.distance then return a.distance<c.distance end;if a.y~=c.y then return a.y<c.y end;return a.x<c.x end)
    for _,tree in ipairs(candidates)do
        local path=self:forestPath(b.x,b.y+1,tree.x,tree.y,blocked or {},b)
        if path then return {x=tree.x,y=tree.y},path end
    end
end
function S:forestPath(sx,sy,tx,ty,blocked,plotOwner)
    local queue,seen,head={{x=sx,y=sy}},{[key(sx,sy)]=false},1
    while head<=#queue do
        local p=queue[head];head=head+1
        if p.x==tx and p.y==ty then
            local route={}
            while p do table.insert(route,1,p);p=seen[key(p.x,p.y)] end
            return route
        end
        for _,d in ipairs(directions) do
            local x,y=p.x+d[1],p.y+d[2]
            local k=key(x,y)
            local terrain=self:terrain(x,y)
            if seen[k]==nil and math.abs(x-sx)<=8 and math.abs(y-sy)<=8
                and (terrain=="grass" or terrain=="forest") and not self:buildingAt(x,y)
                and(not blocked or not blocked[k]and(not WorkSites.owner(self,x,y)or WorkSites.owner(self,x,y)==plotOwner))then
                seen[k]=p;queue[#queue+1]={x=x,y=y}
            end
        end
    end
end
function S:roadSiteAt(x,y) return self.roadPlanIndex[key(x,y)] end
function S:buildingAt(x, y)
    return self.buildingIndex[key(x, y)]
end
function S:path(sx, sy, tx, ty)
    if not self.roads[key(sx, sy)] or not self.roads[key(tx, ty)] then return nil end
    local queue, seen, head = { { x = sx, y = sy } }, { [key(sx, sy)] = false }, 1
    local found = false
    while head <= #queue do
        local p = queue[head]; head = head + 1
        if p.x == tx and p.y == ty then found = true; break end
        for _, d in ipairs(directions) do
            local nx, ny = p.x + d[1], p.y + d[2]
            local k = key(nx, ny)
            if self.roads[k] and seen[k] == nil then
                seen[k] = p; queue[#queue + 1] = { x = nx, y = ny }
            end
        end
    end
    if not found then return nil end
    local result, p = {}, { x = tx, y = ty }
    while p do table.insert(result, 1, p); p = seen[key(p.x, p.y)] end
    return result
end
function S:connected(b)
    if b.networkRevision ~= self.roadCount then
        b.cachedConnected = self:path(10, 9, b.x, b.y + 1) ~= nil
        b.networkRevision = self.roadCount
    end
    return b.cachedConnected
end
function S:availableWorkers()
    local used = #self.carriers + self.militia + Construction.busy(self)
    for _, b in ipairs(self.buildings) do
        if b.complete then used = used + b.workers
        elseif b.kind == "courier" then used = used + 1 end
    end
    return self.population - used
end
function S:canAfford(cost)
    for resource, amount in pairs(cost) do if (self.stock[resource] or 0) < amount then return false end end
    return true
end
function S:spend(cost)
    if not self:canAfford(cost) then return false end
    for resource, amount in pairs(cost) do self.stock[resource] = self.stock[resource] - amount end
    return true
end
function S:addBuilding(kind, x, y, complete)
    local width, height = D.footprint(kind)
    local b = { id = #self.buildings + 1, kind = kind, x = x, y = y, complete = complete or false,
        footprintW = width, footprintH = height, footprintCells=D.cells(kind),
        progress = 0, workers = 0, timer = 0, buffer = 0, inputs = 0, inputGoods={}, incoming = false, outgoing = false, mealStock=0,mealIncoming=false,
        farmStep=0,farmWork=0 }
    if kind=='mill' then b.recipeVersion=2 end
    self.buildings[#self.buildings + 1] = b
    for _,c in ipairs(D.cells(b)) do self.buildingIndex[key(x+c.x,y+c.y)]=b end
    return b
end
function S:canBuild(kind, x, y)
    if self.defeat or self.victory then return false, "本局已结束，可重新选择模式。" end
    if type(x) ~= "number" or type(y) ~= "number" or x ~= math.floor(x) or y ~= math.floor(y) then return false, "请在完整地块上营造。" end
    local def = D.buildings[kind]
    if not def then return false, "未知建筑。" end
    local width, height = D.footprint(kind)
    local occupied={}
    for _,c in ipairs(D.cells(kind)) do
        local tx,ty=x+c.x,y+c.y
        occupied[key(tx,ty)]=true
        if self:terrain(tx, ty) == "fog" then return false, "此处尚未勘探，点击「拓荒」发现新区域。" end
        if self:terrain(tx, ty) ~= "grass" then return false, "建筑占地包含树林、水域或地图边界。" end
        if self:buildingAt(tx, ty) or WorkSites.owner(self,tx,ty)or self.roads[key(tx, ty)] or self:roadSiteAt(tx,ty) then return false, "建筑占地与现有建筑、院落或道路重叠。" end
    end
    -- Protect all existing doors; a door occupies the tile immediately south.
    for _, b in ipairs(self.buildings) do
        if kind ~= "road" and occupied[key(b.x,b.y+1)] then
            return false, "请为建筑门前保留一格道路。"
        end
    end
    if kind == "road" then
        local neighbor = false
        for _, d in ipairs(directions) do
            if self.roads[key(x+d[1],y+d[2])] or self:roadSiteAt(x+d[1],y+d[2]) then neighbor=true;break end
        end
        if not neighbor then return false, "请从现有道路向外延伸。" end
        return true, "已规划道路，空闲村民将取材到场铺设。"
    end
    if self:terrain(x, y + 1) ~= "grass" or self:buildingAt(x, y + 1) then return false, "建筑门前需要可通行的空地。" end
    local spaced,spaceReason=WorkSites.visualClearance(self,kind,x,y)
    if not spaced then return false,spaceReason end
    if kind == "courier" and self:availableWorkers() < 1 then return false, "驿站需要 1 名空闲村民。" end
    if def.deposit then
        local vein=def.deposit=="fish" and Deposits.water(self,{x=x,y=y}) or Deposits.nearest(self,def.deposit,x,y,3)
        if not vein then return false,def.deposit=="fish" and "渔场要靠近三格内的可见水域。" or "矿场要靠近三格内对应的可见矿脉。" end
        if Deposits.stock(self,{x=x,y=y},def.deposit)<=0 then return false,"此资源点已采尽，请另寻矿脉或拓荒。" end
    end
    if kind == "woodcutter" and not self:nearestTree({x=x,y=y,footprintW=width},6) then
        return false, "伐木场要靠近树林，请选离树木六格以内的路旁。"
    end
    if not self:canAfford(def.cost) then
        if (self.stock.wood or 0)<(def.cost.wood or 0) then return false, "木料不足：伐木场采原木，接路送入锯木坊加工成木料，再运回义仓。" end
        return false, "物资不足，先让生产链补充库存。"
    end
    local site,siteReason=WorkSites.plan(self,kind,x,y,false)
    if not site then return false,siteReason end
    local access,accessReason=WorkSites.keepsAccess(self,kind,x,y,site)
    if not access then return false,accessReason end
    if not self:connected({x=x,y=y}) then return true,def.name .. "已规划，等待门前道路接通义仓。",site end
    return true, def.name .. "已规划，工人将取材到场施工。",site
end
function S:build(kind, x, y)
    local ok, message,site = self:canBuild(kind, x, y)
    if not ok then return false, message end
    if kind == "road" then
        local site={x=x,y=y,progress=0}
        self.pendingRoads[#self.pendingRoads+1],self.roadPlanIndex[key(x,y)]=site,site
        return true, message
    end
    local def = D.buildings[kind]
    self:spend(def.cost)
    local b = self:addBuilding(kind, x, y)
    if site and(site.compound or site.chairCell or site.profile=='breaks')then WorkSites.attach(self,b,site)end
    return true, message, b
end
function S:upgradeCompound(b)
    if not b or not b.complete or b.kind=='store'then return false,'此处暂不能重整院落。'end
    local present=false;for _,other in ipairs(self.buildings)do if other==b then present=true;break end end
    if not present then return false,'请重新选中村内建筑。'end
    if b.site and b.site.compound and not(b.kind=='woodcutter'and not b.site.storageCell)then return false,'这座建筑已有相连院落。'end
    local D=require'game.Definitions';local Sites=require'game.WorkSites'
    local def=D.buildings[b.kind]
    if(def.output or def.service)and not b.stopped then return false,'请先停工，等村民空手归位后再重整。'end
    if(b.workers or 0)>0 or(b.lifeOutputHeld or 0)>0 or(b.workOutputHeld or 0)>0 then return false,'请先安全减下岗位，等手持货物交妥后再重整。'end
    local function matches(j)return j and(j.b==b or j.destination==b or j.building==b.id)end
    for _,j in ipairs(self.jobs)do if matches(j)then return false,'请等这座建筑已有的搬运任务完成。'end end
    local function busy(a)
        return matches(a.job)or a.building==b.id or a.sitePickup and a.sitePickup.building==b.id or a.meal and a.meal.target==b.id
    end
    for _,group in ipairs({self.carriers,self.workers,self.builders,self.guards or {}})do
        for _,a in pairs(group)do if busy(a)then return false,'请等搬运、施工和已有饭局自然结束后再重整。'end end
    end
    if b.incoming or b.outgoing or b.mealIncoming then return false,'已有物资正在交接，请等交接完成。'end
    local actual,expected={},{}
    for _,p in ipairs(D.cells(b))do actual[p.x..':'..p.y]=true end
    for _,p in ipairs(D.cells(b.kind))do expected[p.x..':'..p.y]=true end
    for k in pairs(actual)do if not expected[k]then return false,'此旧址结构尺寸不同，将保留原有布局。'end end
    for k in pairs(expected)do if not actual[k]then return false,'此旧址结构尺寸不同，将保留原有布局。'end end
    -- A read-only planning view omits this building's old reservations and
    -- visual box. The live village, actors, jobs, inventory and map stay put.
    local view=setmetatable({buildings={},activityIndex={}},{__index=self})
    for _,other in ipairs(self.buildings)do if other~=b then view.buildings[#view.buildings+1]=other end end
    for k,owner in pairs(self.activityIndex or {})do if owner~=b then view.activityIndex[k]=owner end end
    local ok,reason=Sites.visualClearance(view,b.kind,b.x,b.y);if not ok then return false,reason end
    local site,msg=Sites.plan(view,b.kind,b.x,b.y,false);if not site then return false,msg end
    local clear,message=Sites.keepsAccess(view,b.kind,b.x,b.y,site);if not clear then return false,message end
    Sites.attach(self,b,site);b.siteAttemptRevision=nil;b.lifeSiteReason=nil
    return true,'院落已在原址重整，库存、人口和道路均保留。'
end

function S:count(kind)
    local n = 0; for _, b in ipairs(self.buildings) do if b.kind == kind and b.complete then n = n + 1 end end
    return n
end
function S:lessonProgress()
    local lesson = D.lessons[self.lesson]
    if not lesson then return 1, 1 end
    local industrial,total=Campaign.progress(self,lesson.kind)
    if industrial~=nil then return industrial,total end
    local value
    if lesson.kind == "road" then value = self.roadCount
    elseif lesson.kind == "food" or lesson.kind == "wood" or lesson.kind == "rawwood" or lesson.kind == "bread" then value = self.produced[lesson.kind] or 0
    elseif lesson.kind == "defended" then value=self.defended and 1 or 0
    elseif lesson.kind == "militia" then value = self.militia
    elseif lesson.kind == "victory" then value = (self.victory or (self.mode == "infinite" and self.wavesDefeated > 0)) and 1 or 0
    else value = self:count(lesson.kind) end
    return math.min(value, lesson.target), lesson.target
end
function S:nextLesson()
    local value, target = self:lessonProgress()
    if value < target then return false end
    self.lesson = math.min(#D.lessons + 1, self.lesson + 1)
    return true
end
function S:train(unit)return Military.train(self,unit)end
function S:continueFreePlay()return Campaign.continue(self)end
function S:staff(b, change)
    if not b or not b.complete or not (D.buildings[b.kind].output or D.buildings[b.kind].service) then return false, "此处没有生产岗位。" end
    if change ~= 1 and change ~= -1 then return false, "每次调整一名工人。" end
    if change > 0 and self:availableWorkers() <= 0 then return false, "没有空闲村民，请建民居或调配其他岗位。" end
    local target=math.max(0,math.min(D.buildings[b.kind].maxWorkers or 2,b.workers+change))
    if target==b.workers then return false, change>0 and "岗位已满。" or "已无工人。" end
    if target<b.workers then
        local actor=self.workers[b.id .. ":" .. b.workers]
        -- Finish a paid meal or return the felled log before releasing this
        -- villager. Never erase paid meals, claimed trees or a carried load.
        if actor and (actor.meal or actor.woodPhase or actor.forestryPhase or actor.carrying or actor.felledLoad or WorkLife.busy(actor)or actor.lean or require('game.WorkBreaks').busy(actor)) then
            return false, "工人正在用餐、搬运或护林，请暂停岗位并等他空手归位后减员。"
        end
        if b.kind=="ranch" and Ranch.busy(b) then return false, "养殖户正在喂料，请等他回屋后减员。" end
        self.workers[b.id .. ":" .. b.workers]=nil
    end
    b.workers=target
    b.activeWorkers=math.min(b.activeWorkers or 0,target)
    return true, "已安排 " .. b.workers .. " 名" .. D.job(b.kind) .. "。"
end
function S:outputResource(b)
    return Economy.outputResource(b)
end
function S:startRaid()
    if self.raid or self.victory or self.defeat then return false, "守村已经开始或结束。" end
    local final=self.mode=='finite' and self.defended and not self.freePlay
    if final then
        local ok,message=Campaign.ready(self)
        if not ok then return false,message end
    elseif self.militia<(self.freePlay and 1 or 3) then return false, "先训练至少3名乡勇；自由经营续战至少需1名守军。" end
    self.raid,self.campaignRaid=true,final
    self.wave,self.enemies=self.wave+1,{}
    if self.mode=="infinite" then Campaign.armInfiniteWave(self) end
    local advanced=self.mode=='finite' and self.defended
    local count=self.mode=='infinite' and (3+self.wave) or advanced and (self.freePlay and 5+self.wave or 6) or 4
    local hp=self.mode=='infinite' and (3+math.floor(self.wave/2)) or advanced and 5 or 3
    for i=1,count do self.enemies[i]={x=15+i*.4,y=3,hp=hp} end
    return true,final and "终章守村开始：弓手、长枪兵共同迎战6名强敌！" or "山匪来袭，守军会自动守护义仓。"
end
function S:expansionCost()
    return { wood = 12 + self.map.expansion * 6, food = 8 + self.map.expansion * 4 }
end
function S:expand()
    if self.mode ~= "infinite" then return false, "有限关卡边界固定，请在本地完成目标。" end
    if self.defeat then return false, "本局已结束。" end
    if not self:spend(self:expansionCost()) then return false, "拓荒物资不足，先补充木料和口粮。" end
    self.map:expand()
    self.timber, self.rock = self.timber + 160, self.rock + 100
    return true, "新区域已发现：向外拖动地图，沿路开辟新聚落。"
end
function S:repair()
    if self.health >= 100 then return false, "义仓完好，无需修缮。" end
    if self.defeat or self.victory then return false, "本局已结束。" end
    if not self:spend({ wood = 4, stone = 4 }) then return false, "修缮需要 4 木料、4 石料。" end
    self.health = math.min(100, self.health + 30)
    return true, "义仓已修复 30 点耐久。"
end
function S:enqueue(b,inbound,selectedResource)
    local resource=selectedResource or (inbound and D.buildings[b.kind].input or self:outputResource(b))
    if not resource then return end
    local destination
    if not inbound then
        local bestScore
        for _,other in ipairs(self.buildings)do
            if other~=b and other.complete and self:connected(other) and not other.incoming and Economy.wants(other,resource) then
                local path=self:path(b.x,b.y+1,other.x,other.y+1)
                if path then
                    local score=(not Economy.hasInputs(other) and 100 or 0)+math.min(120,other.demandAge or 0)
                        +(resource=="grain" and other.kind=="mill" and 10 or 0)-#path*.1
                    if not bestScore or score>bestScore then destination,bestScore=other,score end
                end
            end
        end
    end
    local amount
    if inbound then
        if not Economy.allowed(b,resource) then return end
        amount=math.min((D.buildings[b.kind].recipes or b.kind=='kitchen' or b.kind=='mill' and b.recipeVersion~=1 or b.kind=='ranch' or b.kind=='bakery' or b.kind=='sawmill') and 4 or 1,self.stock[resource] or 0,Economy.deliverySpace(b,resource))
        if amount<=0 then return end
        self.stock[resource],b.incoming=self.stock[resource]-amount,true
    else
        amount=math.min(4,Economy.outputAmount(b,resource))
        if destination then amount=math.min(amount,Economy.deliverySpace(destination,resource)) end
        if amount<=0 then return end
        b.outgoing=true
        if destination then destination.incoming=true end
    end
    local job={b=b,destination=destination,inbound=inbound,resource=resource,amount=amount}
    if not inbound and CarrierLife.eligible(self,b)then job.sitePickup=true end
    self.jobs[#self.jobs+1]=job
end
function S:normalizeInputs(b)
    local def=D.buildings[b.kind]
    b.inputGoods=b.inputGoods or {}
    if not def.input then return end
    local total=0;for _,amount in pairs(b.inputGoods) do total=total+amount end
    if total<b.inputs then b.inputGoods[def.input]=(b.inputGoods[def.input] or 0)+b.inputs-total end
end
function S:inputResource(b)
    local def=D.buildings[b.kind]
    self:normalizeInputs(b)
    if (b.inputGoods[def.input] or 0)>0 then return def.input end
    if def.alternateInput and (b.inputGoods[def.alternateInput] or 0)>0 then return def.alternateInput end
    if b.kind=="kitchen" and (b.inputGoods.flour or 0)>0 then return "flour" end
    for _,resource in ipairs(def.extraInputs or {})do if (b.inputGoods[resource] or 0)>0 then return resource end end
    return def.input
end
function S:receiveInput(b,resource,amount)
    self:normalizeInputs(b)
    b.inputs=b.inputs+amount
    b.inputGoods[resource]=(b.inputGoods[resource] or 0)+amount
end
function S:consumeInput(b)
    self:normalizeInputs(b)
    Economy.consume(b,b.processingResource or self:inputResource(b))
end
function S:setRecipe(b,index)return Economy.setRecipe(b,index)end
function S:setWorking(b,enabled)
    if not b or not b.complete or not (D.buildings[b.kind].output or D.buildings[b.kind].service) then return false,"此建筑没有生产岗位。" end
    b.stopped=not enabled
    return true,b.stopped and "已停工，岗位与原料保留，成品继续运送。" or "已复工，工人将继续原批作业。"
end
function S:completeDelivery(job)
    if job.construction then
        require("game.ConstructionSites").deliver(job.b,job.supplyPhase,job.resource)
        job.b.deliveredLoads=(job.b.deliveredLoads or 0)+1
    elseif job.service then job.b.mealStock,job.b.mealIncoming=(job.b.mealStock or 0)+job.amount,false
    elseif job.inbound then self:receiveInput(job.b,job.resource,job.amount);job.b.incoming=false
    else
        if job.destination then
            self:receiveInput(job.destination,job.resource,job.amount);job.destination.incoming=false
        else
            self.stock[job.resource]=self.stock[job.resource]+job.amount
            self.warehouseDisplay={resource=job.resource,amount=job.amount,at=self.elapsed}
        end
        if Economy.isProduct(job.b,job.resource) then self.produced[job.resource]=(self.produced[job.resource] or 0)+job.amount end
        job.b.outgoing=false
    end
end
function S:updateCarrier(c, dt, offline)
    if Meals.tick(self,c,dt,offline,c.job ~= false and c.job ~= nil) then return end
    if not c.job and #self.jobs > 0 then
        c.job = table.remove(self.jobs, 1)
        local job = c.job
        local sx, sy = 10, 9
        if not job.inbound then sx, sy = job.b.x, job.b.y + 1 end
        c.path, c.index, c.carrying = self:path(math.floor(c.x + 0.5), math.floor(c.y + 0.5), sx, sy) or {}, 1, false
    end
    if not c.job then return end
    local job=c.job
    if CarrierLife.update(self,c,dt)then return end
    if c.phase=="packing" or c.phase=="unload" then
        c.timer=math.max(0,(c.timer or 0)-dt)
        local duration=c.doorDuration or Cargo.doorSeconds
        if c.phase=="packing" then
            if c.timer<=duration*.5 and not c.carrying then
                if not job.inbound and not job.pickedUp then
                    Economy.take(job.b,job.resource,job.amount)
                    job.pickedUp=true
                end
                c.carrying=true
            end
            if c.timer>0 then return end
            c.phase="travel"
            c.doorDuration=nil
            local tx,ty=10,9
            if job.inbound then tx,ty=job.b.x,job.b.y+1
            elseif job.destination then tx,ty=job.destination.x,job.destination.y+1 end
            c.path,c.index=self:path(math.floor(c.x+.5),math.floor(c.y+.5),tx,ty) or {},1
            return
        end
        if c.timer<=duration*.5 and not c.handedOff then
            self:completeDelivery(job)
            c.deliveryCount=(c.deliveryCount or 0)+1
            c.handedOff,c.carrying=true,false
        end
        if c.timer==0 then c.job,c.carrying,c.phase,c.timer,c.handedOff,c.doorDuration=false,false,"idle",0,false,nil end
        return
    end
    local target = c.path[c.index]
    if target then
        Move.step(c,dt,(c.energy or 100)<25 and .65 or c.carrying and .85 or 1.05,self)
        return
    end
    c.phase=not c.carrying and 'packing' or 'unload'
    c.doorDuration=Cargo.duration(Cargo.phaseBuilding(self,c,c.phase))
    c.timer=c.doorDuration
end
-- A modern rack trip is selected at the beginning of an outing only. Old
-- saved excursions keep their original door handoff until they finish.
local function rackBusy(sim,b,a)
    for _,other in pairs(sim.workers)do
        if other~=a and other.building==b.id and other.rackVisit and
            (other.woodPhase=='toRack'and not other.rackWaiting or other.woodPhase=='stack'or other.woodPhase=='fromRack')then return true end
    end
    return false
end
local function clearWoodTrip(a)
    a.woodPhase,a.treeX,a.treeY,a.path,a.index,a.stockedLoad=nil,nil,nil,{},1,nil
    a.loadAmount,a.rackVisit,a.rackWaiting,a.campWaiting=nil,nil,nil,nil
end
function S:updateWoodcutter(b,dt)
    if b.legacyOutput then
        local returning=false
        for _,actor in pairs(self.workers) do
            if actor.building==b.id and (actor.woodPhase or actor.carrying or actor.felledLoad) then returning=true;break end
        end
        if b.buffer==0 and not b.outgoing and not returning then b.legacyOutput=nil end
    end
    for slot=1,b.workers do
        local a=self.workers[b.id .. ":" .. slot]
        if a and not a.meal then
            if not a.woodPhase then
                local tree,route
                if not b.stopped and not b.legacyOutput and b.buffer<6 then
                    if b.site and b.site.compound then tree,route=self:reachableTree(b,6)
                    else tree=self:nearestTree(b,6)end
                end
                if tree and self.timber>0 then
                    route=route or self:forestPath(b.x,b.y+1,tree.x,tree.y)
                    if b.site and b.site.compound then b.site.compound.source={id='forest:edge',resource='rawwood',x=tree.x,y=tree.y}end
                    if route then
                        a.treeX,a.treeY=tree.x,tree.y
                        a.woodPhase,a.woodClock="toTree",0
                        a.rackVisit=WorkSites.pickupPoint(b)and b.site and b.site.compound and true or nil
                        if #route>0 then route[#route]={x=tree.x-.36,y=tree.y+.20} end
                        a.path,a.index=route,1
                    end
                end
            elseif a.woodPhase=="toTree" then
                if Move.step(a,dt,.85,self) then a.woodPhase,a.woodClock="chop",0 end
            elseif a.woodPhase=="chop" then
                a.woodClock=(a.woodClock or 0)+dt
                if a.woodClock>=5 then
                    local x,y=a.treeX,a.treeY
                    if self:standingTree(x,y) and self.timber>0 then
                        self.felledTrees[key(x,y)]=true
                        Forestry.fell(self,x,y)
                        self.timber=self.timber-1
                        a.carrying=true
                        a.loadAmount=D.buildings.woodcutter.amount
                    end
                    a.felledLoad=a.carrying
                    a.carrying=false
                    a.woodPhase,a.woodClock="felling",0
                end
            elseif a.woodPhase=="felling" then
                a.woodClock=(a.woodClock or 0)+dt
                if a.woodClock>=1.4 then a.woodPhase,a.woodClock="gather",0 end
            elseif a.woodPhase=="gather" then
                a.woodClock=(a.woodClock or 0)+dt
                if a.woodClock>=.7 then a.carrying=a.felledLoad==true end
                if a.woodClock>=1.4 then
                    a.felledLoad=nil;a.woodPhase="toCamp"
                    local route=self:forestPath(math.floor(a.x+.5),math.floor(a.y+.5),b.x,b.y+1,a.rackVisit and {}or nil,b)
                    a.campWaiting=a.rackVisit and not route or nil
                    a.path=route or(a.rackVisit and {}or {{x=b.x,y=b.y+1}})
                    a.index=1
                end
            elseif a.woodPhase=="toCamp" then
                if a.campWaiting then
                    local route=self:forestPath(math.floor(a.x+.5),math.floor(a.y+.5),b.x,b.y+1,{},b)
                    if route then a.path,a.index,a.campWaiting=route,1,nil end
                elseif Move.step(a,dt,.85,self)then
                    a.woodPhase,a.woodClock="toRack",0
                    if a.rackVisit then a.rackWaiting=true;a.path,a.index={},1 end
                end
            elseif a.woodPhase=="toRack" then
                if a.rackVisit then
                    if a.rackWaiting then
                        if not rackBusy(self,b,a)and WorkSites.route(self,a,b,WorkSites.pickupPoint(b))then a.rackWaiting=nil end
                    elseif Move.step(a,dt,.8,self)then a.woodPhase,a.woodClock,a.stockedLoad="stack",0,false end
                else
                    a.woodClock=(a.woodClock or 0)+dt
                    if a.woodClock>=1.2 then a.woodPhase,a.woodClock,a.stockedLoad="stack",0,false end
                end
            elseif a.woodPhase=="stack" then
                a.woodClock=(a.woodClock or 0)+dt
                if a.woodClock>=1.05 and not a.stockedLoad then
                    if a.carrying then
                        if a.rackVisit then Economy.add(b,self:outputResource(b),a.loadAmount or 1)
                        else b.buffer=b.buffer+(a.loadAmount or 1)end
                    end
                    a.carrying,a.stockedLoad=false,true
                end
                if a.woodClock>=1.4 then
                    a.woodPhase,a.woodClock="fromRack",0
                    if a.rackVisit then a.rackWaiting=true;a.path,a.index={},1 end
                end
            elseif a.woodPhase=="fromRack" then
                if a.rackVisit then
                    if a.rackWaiting then
                        if WorkSites.route(self,a,b,{x=b.x,y=b.y+1})then a.rackWaiting=nil end
                    elseif Move.step(a,dt,.8,self)then clearWoodTrip(a)end
                else
                    a.woodClock=(a.woodClock or 0)+dt
                    if a.woodClock>=1.2 then clearWoodTrip(a)end
                end
            end
        end
    end
end
function S:update(dt, offline)
    self.messageTime = math.max(0, self.messageTime - dt)
    if not self.started or self.paused or self.defeat or self.victory then return end
    dt = math.min(dt, 0.25) * (offline and 1 or self.speed)
    if not offline then self.elapsed, self.foodClock = self.elapsed + dt, self.foodClock + dt end
    if not offline and self.foodClock >= 15 then
        self.foodClock = self.foodClock - 15
        -- Tutorial relief floor prevents an unrecoverable beginner starvation spiral.
        local floorFood = self.mode == "finite" and not self.skipped and 8 or 0
        self.stock.food = math.max(floorFood, self.stock.food)
        if self.mode == "infinite" and Meals.availableFood(self) == 0 then
            self.health = math.max(0, self.health - 4)
            self:notify("粮仓告急！断粮会损耗义仓耐久，请尽快打通粮食链。")
            if self.health == 0 then self.defeat = true end
        end
    end
    while #self.guards<self.militia do self.guards[#self.guards+1]={x=10,y=9,path={},index=1,meal=false,hunger=0,energy=100} end
    while #self.guards>self.militia do table.remove(self.guards) end
    Move.prepare(self)
    Construction.update(self,dt,offline)
    Meals.prepareWorkers(self,dt,offline)
    for _,guard in ipairs(self.guards) do Meals.tick(self,guard,dt,offline,self.raid,true) end
    Forestry.update(self,dt,offline)
    Production.update(self,dt)
    -- An old save or a simultaneous rush to the dining room can put every
    -- carrier in a food queue while their own food delivery waits outside.
    -- Let one queued carrier return to work so the village cannot deadlock.
    if #self.jobs>0 then
        local available=false
        for _,c in ipairs(self.carriers) do if not c.meal then available=true;break end end
        if not available then
            for _,c in ipairs(self.carriers) do
                if c.meal and c.meal.phase=="queue" then
                    c.meal=false;c.path={};c.index=1;break
                end
            end
        end
    end
    for _, c in ipairs(self.carriers) do self:updateCarrier(c, dt, offline) end
    -- Offline time advances production/logistics only, never raids, hunger or records.
    if offline then return end
    self.score = math.floor(self.elapsed / 10) + self.map.expansion * 100 + self.wavesDefeated * 200 + #self.buildings * 10
    if self.mode == "infinite" and not self.raid then
        self.nextRaid = math.max(0, self.nextRaid - dt)
        if self.nextRaid == 0 then
            -- Automatic waves do not require militia: inadequate preparation can lose.
            self.wave, self.raid, self.enemies = self.wave + 1, true, {}
            Campaign.armInfiniteWave(self)
            for i = 1, 3 + self.wave do
                self.enemies[i] = { x = 15 + i * 0.4, y = 3, hp = 3 + math.floor(self.wave / 2) }
            end
            self:notify("第 " .. self.wave .. " 波山匪来袭，乡勇自动守村！")
        end
    end
    if self.raid then
        for _, e in ipairs(self.enemies) do
            if e.hp > 0 then
                local dx, dy = 10 - e.x, 9 - e.y
                local distance = math.sqrt(dx * dx + dy * dy)
                if distance > 1.4 then e.x, e.y = e.x + dx / distance * dt * 0.65, e.y + dy / distance * dt * 0.65 end
            end
        end
        self.combatClock = self.combatClock + dt
        if self.combatClock >= 1.2 then
            self.combatClock = 0
            local alive, near = {}, {}
            for _, e in ipairs(self.enemies) do
                if e.hp > 0 then
                    alive[#alive + 1] = e
                    if (e.x - 10)^2 + (e.y - 9)^2 < 14 then near[#near + 1] = e end
                end
            end
            if #alive == 0 then
                self.raid, self.defended = false, true
                self.wavesDefeated = self.wavesDefeated + 1
                if self.mode == "infinite" then
                    local milestone=Campaign.finishInfiniteWave(self)
                    self.nextRaid = math.max(75, 180 - self.wave * 10)
                    self:notify(milestone and "二十课工业守村里程碑已成；后续来袭与经营继续。" or ("第 " .. self.wave .. " 波已守住。休整、修仓，再向远方拓荒。"))
                elseif self.campaignRaid then
                    self.campaignCompleted,self.victory,self.campaignRaid=true,true,false
                    self:notify("二十课产业战役已成，清溪里可继续经营。")
                elseif self.freePlay then self:notify("这一波已守住，继续经营或再来一波。")
                else self:notify("首场守村已成！接着发展林业、矿冶与正规兵，开启第二幕。") end
            elseif #near > 0 then
                near[1].hp = near[1].hp - Military.power(self)
                if self.militia > 0 then
                    -- Three trained villagers can win this introductory encounter.
                    if near[1].hp > 0 then self.militia = math.max(0, self.militia - 1); table.remove(self.guards) end
                else self.health = math.max(0, self.health - 12) end
                if self.health == 0 then self.defeat = true; self:notify("义仓失守。点击重新开始再试一次。") end
            end
        end
    end

end
function S:snapshot()
    return { stock = copy(self.stock), population = self.population, lesson = self.lesson, militia = self.militia,
        mode = self.mode, seed = self.map.seed, expansion = self.map.expansion, waves = self.wavesDefeated, score = self.score }
end
return S
