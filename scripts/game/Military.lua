-- Equipment comes from the warehouse after real production and hauling.
local M={units={
    militia={name='乡勇',power=1,cost={wood=2,food=2},equipment={}},
    archer={name='弓手',power=2,cost={bow=1,leatherarmor=1,gold=1,food=2},equipment={bow=1,leatherarmor=1}},
    spearman={name='长枪兵',power=3,cost={ironspear=1,ironarmor=1,gold=1,food=2},equipment={ironspear=1,ironarmor=1}},
}}
function M.train(sim,unit)
    unit=unit or 'militia'
    local profile=M.units[unit]
    if not profile then return false,'未知兵种。' end
    if sim.defeat or sim.victory then return false,'本轮守村已结束。' end
    if sim:count('barracks')==0 then return false,'请先完成乡勇营。' end
    if sim:availableWorkers()<1 then return false,'待命村民不足，请等待施工队返仓、建民居或减少岗位。' end
    if not sim:spend(profile.cost) then
        return false,unit=='militia' and '训练需要2木料、2口粮。' or ('征募'..profile.name..'需要对应武器、护甲、1金锭和2口粮，先送回义仓。')
    end
    local gear={};for resource,n in pairs(profile.equipment)do gear[resource]=n end
    sim.militia=sim.militia+1
    sim.guards[#sim.guards+1]={x=10,y=9,path={},index=1,meal=false,hunger=0,energy=100,unit=unit,equipment=gear}
    return true,profile.name..'已领装，在义仓前集结。'
end
function M.power(sim)
    local power=0
    for _,guard in ipairs(sim.guards)do power=power+(M.units[guard.unit or 'militia'] or M.units.militia).power end
    return power
end
function M.count(sim,unit)local n=0;for _,g in ipairs(sim.guards)do if (g.unit or 'militia')==unit then n=n+1 end end;return n end
return M
