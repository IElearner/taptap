-- Campaign objectives read earned deliveries and real actors, never stock gifts
-- or construction counts in place of using an industry.
local D=require 'game.Definitions'
local Military=require 'game.Military'
local C={}
local function made(s,kind,r,n)return s:count(kind)>0 and (s.produced[r] or 0)>=n end
local function courier(s)
    for _,a in ipairs(s.carriers)do
        local b=a.courier and s.buildings[a.courier]
        if b and b.kind=='courier' and b.complete and (a.deliveryCount or 0)>=1 then return true end
    end
    return false
end
local objectives={
    industryForest=function(s)return{s:count('forester')>0,(s.forestryTendSeconds or 0)>=5}end,
    industryStone=function(s)return{made(s,'quarry','rawstone',2),made(s,'mason','stone',1),courier(s)}end,
    industryMines=function(s)return{made(s,'ironmine','ironore',2),made(s,'coalmine','coal',2),made(s,'goldmine','goldore',1)}end,
    industryMetals=function(s)return{made(s,'smelter','iron',1),made(s,'smelter','gold',1)}end,
    industryFish=function(s)return{s:count('fishery')>0,(s.fishMealsCooked or 0)>=1}end,
    industryLeather=function(s)return{made(s,'ranch','livestock',1),made(s,'butcher','meat',3),made(s,'butcher','hide',1),made(s,'tannery','leather',1)}end,
    industryWoodArms=function(s)return{made(s,'woodweapons','bow',1),made(s,'leatherarmor','leatherarmor',1)}end,
    industryIronArms=function(s)return{made(s,'ironweapons','ironspear',1),made(s,'ironarmor','ironarmor',1)}end,
    industryArmy=function(s)return{Military.count(s,'archer')>=1,Military.count(s,'spearman')>=1}end,
    campaignVictory=function(s)return{s.campaignCompleted==true}end,
}
function C.progress(s,kind)
    local test=objectives[kind]
    if not test then return end
    local conditions=test(s);local count=0
    for _,met in ipairs(conditions)do if met then count=count+1 end end
    return count,#conditions
end
function C.ready(s)
    for i=11,19 do
        local lesson=D.lessons[i];local done,total=C.progress(s,lesson.kind)
        if done<total then return false,'先完成'..lesson.title..'（'..done..'/'..total..'），再开启终章守村。' end
    end
    for _,kind in ipairs(D.order)do
        if kind~='road' and s:count(kind)==0 then return false,'终章还需建成'..D.buildings[kind].name..'。' end
    end
    local ready={archer=false,spearman=false}
    for _,a in ipairs(s.guards)do
        if ready[a.unit]~=nil and not a.meal and (a.x-10)^2+(a.y-9)^2<4 then ready[a.unit]=true end
    end
    if not ready.archer or not ready.spearman then return false,'等待弓手与长枪兵用餐后归队，再开启终章。' end
    return true
end
-- Eligibility is a start-of-wave snapshot. An eating/returning survivor at
-- the victory instant does not invalidate having fought in that encounter.
function C.armInfiniteWave(s)
    if s.campaignCompleted then s.milestoneEligible=false;return end
    s.campaignMilestoneWave=s.wave
    s.milestoneEligible=s.wave>=4 and C.ready(s)==true
end
function C.finishInfiniteWave(s)
    local earned=s.milestoneEligible and s.campaignMilestoneWave==s.wave
        and Military.count(s,'archer')>=1 and Military.count(s,'spearman')>=1
    if earned then s.campaignCompleted=true end
    s.milestoneEligible=false
    return earned
end
function C.continue(s)
    if not s.victory or s.defeat then return false,'先完成守村胜利。' end
    s.freePlay,s.victory,s.campaignRaid=true,false,false
    s.started,s.paused,s.skipped,s.lesson=true,false,true,#D.lessons+1
    return true,'村庄已保留，继续经营、造装备或再守下一波。'
end
return C
