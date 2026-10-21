-- Normal online new-game progression, using only the game's real starter stock.
-- Unlike the old village fixture, road work never uses offline=true.
local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
local Store=require 'game.PixelSaveStore'
local D=require 'game.Definitions'
local ticks=0
local function tick(s)
 s:update(.1);ticks=ticks+1
 if ticks%100==0 then coroutine.yield() end
end
local function untilTrue(s,predicate,seconds)
    for _=1,seconds*10 do if predicate() then return true end;tick(s) end
    return predicate()
end
local function build(s,kind,x,y)
    local ok,message,b=s:build(kind,x,y)
    V.assert(ok,'New-game plan '..kind..' at '..x..','..y..': '..tostring(message))
    if not ok then return nil end
    local complete=untilTrue(s,function() return kind=='road' and s.roads[x..':'..y] or b and b.complete end,600)
    V.assert(complete,'Normal online workers finish '..kind..' at '..x..','..y)
    return b
end
local function nextLesson(s,n)
    V.assert(s:nextLesson() and s.lesson==n+1,'Normal new-game lesson '..n..' completes its real objective')
end
local task=coroutine.create(function()
    local s=Sim.new('finite',23);s.started=true
    V.assert(s.stock.wood==72 and s.stock.stone==40 and s.stock.food==28 and s.population==10,'Fixture starts from the actual player new-game inventory and population')
    for x=7,4,-1 do build(s,'road',x,9) end
    nextLesson(s,1)
    local ok,_,home=s:build('house',7,8)
    V.assert(ok,'Player plans the first house with real earned road access')
    for _=1,120 do tick(s) end
    V.assert(home and not home.complete,'Save is taken during active first-house work')
    local files={}
    local backend={now=function() return 1000 end,read=function(k)return files[k] end,write=function(k,v)files[k]=v;return true end}
    V.assert(Store.new(backend):save(s,true),'Active new game saves through the actual pixel schema encoder')
    local restored
    Store.new(backend):load('finite',function(bundle) restored=Data.restore(bundle,'finite') end)
    V.assert(restored~=nil,'The pixel save rebuilds a live simulation with active construction')
    if not restored then return end
    s=restored;home=s:buildingAt(7,8)
    V.assert(untilTrue(s,function()return home.complete end,600) and s.population==14,'Resumed first house completes once and adds four residents')
    nextLesson(s,2)
    for y=10,13 do build(s,'road',9,y) end
    build(s,'road',10,13);build(s,'road',11,13);build(s,'farm',11,12);nextLesson(s,3)
    build(s,'road',13,9);build(s,'mill',13,8);nextLesson(s,4)
    build(s,'road',8,13);build(s,'road',7,13);build(s,'bakery',7,12)
    V.assert(untilTrue(s,function()return (s.produced.bread or 0)>=2 end,900),'Actual flour is baked and transported as bread before the fifth lesson completes')
    nextLesson(s,5)
    build(s,'road',14,9);build(s,'road',15,9)
    for y=10,13 do build(s,'road',15,y) end
    build(s,'road',14,13);build(s,'kitchen',14,12)
    V.assert(untilTrue(s,function()return s.produced.food>=4 end,600),'Unboosted normal new game grows grain, mills flour, cooks and delivers four new rations')
    nextLesson(s,6)
    V.assert(untilTrue(s,function()return s.mealsServed>0 end,180),'A real worker eats from the newly built food system')
    build(s,'road',16,9);build(s,'road',17,9);build(s,'woodcutter',17,8)
    V.assert(untilTrue(s,function()return (s.produced.rawwood or 0)>=1 end,900),'Logger delivers actual rawwood before lesson seven completes')
    nextLesson(s,7)
    V.assert(untilTrue(s,function()return next(s.felledTrees)~=nil end,180),'The new-game woodcutter really fells a standing tree')
    for y=14,17 do build(s,'road',11,y) end
    build(s,'road',10,17);build(s,'sawmill',10,16)
    V.assert(untilTrue(s,function()return (s.produced.wood or 0)>=2 end,900),'Real rawwood is transported and sawn into buildable wood')
    nextLesson(s,8)
    local funded=untilTrue(s,function()return s.stock.wood>=18 end,900)
    print('NEWGAME_FUNDING_DIAGNOSTIC',cjson.encode({stock=s.stock,produced=s.produced,jobsCount=#s.jobs,carriersCount=#s.carriers,free=s:availableWorkers(),trees=s:nearestTree(s.buildings[7],6),timber=s.timber}))
    V.assert(not funded and s.stock.wood==14 and s:treeCount(s.buildings[7],6)==0,'East-site two real trees deplete and expose the known low-wood planning boundary')
    build(s,'road',8,8);build(s,'road',8,7);build(s,'road',8,6);build(s,'road',8,5);build(s,'road',7,5);build(s,'road',6,5)
    local before=s.stock.wood
    build(s,'woodcutter',6,4)
    V.assert(s.stock.wood==before-6,'Recovery new camp uses remaining real wood rather than a grant')
    V.assert(untilTrue(s,function()return s.stock.wood>=18 end,1800),'Building a second camp at the western woodlot recovers enough real wood for barracks and three guards')
    V.assert((s.produced.rawwood or 0)>=7 and (s.produced.wood or 0)>=14,'Recovery uses additional felled trees, transported logs and sawmill production')
    print('EAST_RECOVERY',s.elapsed,s.stock.wood,s.produced.rawwood,s.produced.wood)
    build(s,'road',9,5);build(s,'road',10,5);build(s,'road',10,4);build(s,'barracks',10,3)
    V.assert(untilTrue(s,function()return s:availableWorkers()>=3 end,180),'Recovered east village frees three real residents for training')
    for _=1,3 do V.assert(s:train(),'Recovered east village trains an actual guard')end
    nextLesson(s,9)
    V.assert(s:startRaid(),'Recovered east village begins final defense')
    V.assert(untilTrue(s,function()return s.victory or s.defeat end,120) and s.victory,'Recovered east village wins the defense without resource grants')
    nextLesson(s,10)
end)
for frame=8,600 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead' then return end
 local ok,err=coroutine.resume(task)
 if not ok then V.assert(false,'Independent newgame coroutine: '..tostring(err));V.finish()
 elseif coroutine.status(task)=='dead' then V.finish() end
end) end
