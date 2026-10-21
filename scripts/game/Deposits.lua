-- Coordinate-stable finite veins. Every mine at the same deposit shares one
-- reserve; rebuilding a mine never recreates ore.
local P={capacity={ironore=120,coal=160,goldore=60}}
local fixed={
    {x=8,y=15,resource='ironore'},{x=9,y=3,resource='ironore'},
    {x=16,y=6,resource='coal'},{x=5,y=6,resource='coal'},
    {x=5,y=10,resource='goldore'},{x=16,y=20,resource='goldore'},
}
local function key(d)return d.resource..':'..d.x..':'..d.y end
function P.at(sim,x,y)
    for _,d in ipairs(fixed) do if d.x==x and d.y==y then return d end end
    if x>=1 and x<=22 and y>=1 and y<=22 then return end
    if x%8==4 and y%8==4 and sim:terrain(x,y)=='grass' then
        local resources={'ironore','coal','goldore'}
        return {x=x,y=y,resource=resources[(math.floor(x/8)*17+math.floor(y/8)*31+sim.map.seed)%3+1]}
    end
end
-- Visible rock exposures are locations, not additional inventories. Every
-- exposure in this valley still draws from the one retained sim.rock pool.
local rocks={{x=4,y=11},{x=9,y=16},{x=16,y=11}}
function P.rockAt(sim,x,y)
    for _,p in ipairs(rocks)do if p.x==x and p.y==y and sim:terrain(x,y)~='fog'then return {x=x,y=y,resource='rawstone',id='rawstone:valley'}end end
    if(x<1 or x>22 or y<1 or y>22)and x%8==2 and y%8==3 and sim:terrain(x,y)=='grass'then
        return {x=x,y=y,resource='rawstone',id='rawstone:valley'}
    end
end
function P.rockNearest(sim,x,y,radius,excluded)
    local best,distance
    for tx=x-radius,x+radius do for ty=y-radius,y+radius do
        local p=P.rockAt(sim,tx,ty);local delta=math.abs(tx-x)+math.abs(ty-y)
        if p and not(excluded and excluded[tx..':'..ty])and delta<=radius and(not distance or delta<distance)then best,distance=p,delta end
    end end
    return best
end
function P.nearest(sim,resource,x,y,radius,excluded)
    local best,distance
    for tx=x-radius,x+radius do for ty=y-radius,y+radius do
        local d=P.at(sim,tx,ty)
        local delta=math.abs(tx-x)+math.abs(ty-y)
        if d and d.resource==resource and not(excluded and excluded[tx..':'..ty])and delta<=radius and sim:terrain(tx,ty)~='fog'
            and (not distance or delta<distance) then best,distance=d,delta end
    end end
    return best
end
function P.water(sim,b)
    local best,distance
    for x=b.x-3,b.x+3 do for y=b.y-3,b.y+3 do
        local d=math.abs(x-b.x)+math.abs(y-b.y)
        if d<=3 and sim:terrain(x,y)=='water' and (not distance or d<distance) then best,distance={x=x,y=y},d end
    end end
    return best
end
local function fishKey(w)
    if w.x>=1 and w.x<=22 and w.y>=1 and w.y<=22 then return 'fish:valley' end
    return 'fish:'..math.floor(w.x/8)..':'..math.floor(w.y/8)
end
function P.source(sim,b,resource)
    local bound=b.site and b.site.compound and b.site.compound.source
    if resource=='rawstone'then return {id='rawstone:valley',remaining=sim.rock,resource=resource,x=bound and bound.x,y=bound and bound.y}end
    if bound and bound.resource==resource and resource~='fish'then
        return {id=bound.id,remaining=resource=='rawwood'and sim.timber or sim.minerals and sim.minerals[bound.id]or P.capacity[resource],resource=resource,x=bound.x,y=bound.y}
    end
    if resource=='fish'then
        local w=b.site and b.site.waterCell or P.water(sim,b)
        if not w then return end
        local id=fishKey(w)
        return {id=id,remaining=sim.minerals and sim.minerals[id]or 360,resource=resource}
    end
    local d=P.nearest(sim,resource,b.x,b.y,3)
    if d then return {id=key(d),remaining=P.remaining(sim,d),resource=resource}end
end
function P.reserved(sim,id)
    local amount=0
    for _,a in pairs(sim.workers or {})do
        local r=a.life and a.life.reservation
        if r and r.sourceId==id then amount=amount+r.amount end
    end
    return amount
end
function P.commit(sim,reservation)
    local amount,id=reservation.amount,reservation.sourceId
    if not id then return false end
    if id=='rawstone:valley'then
        if sim.rock<amount then return false end
        sim.rock=sim.rock-amount;return true
    end
    sim.minerals=sim.minerals or {}
    local default=reservation.resource=='fish'and 360 or P.capacity[reservation.resource]
    local remaining=sim.minerals[id]or default
    if not remaining or remaining<amount then return false end
    sim.minerals[id]=remaining-amount;return true
end
function P.remaining(sim,d)
    sim.minerals=sim.minerals or {}
    local value=sim.minerals[key(d)]
    return value==nil and P.capacity[d.resource] or value
end
function P.extract(sim,b,resource,amount)
    if resource=='fish' then
        sim.minerals=sim.minerals or {};local w=P.water(sim,b);if not w then return 0 end
        local k=fishKey(w);local available=sim.minerals[k] or 360
        local n=math.min(amount,math.max(0,available-P.reserved(sim,k)));sim.minerals[k]=available-n;return n
    end
    local d=P.nearest(sim,resource,b.x,b.y,3)
    if not d then return 0 end
    local extracted=math.min(amount,math.max(0,P.remaining(sim,d)-P.reserved(sim,key(d))))
    sim.minerals[key(d)]=P.remaining(sim,d)-extracted
    return extracted
end
function P.stock(sim,b,resource)
    if resource=='fish' then
        local w=P.water(sim,b)
        if not w then return 0 end
        return sim.minerals and sim.minerals[fishKey(w)] or 360
    end
    local d=P.nearest(sim,resource,b.x,b.y,3)
    return d and P.remaining(sim,d) or 0
end
return P
