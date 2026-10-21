-- Each ware has a physical carrier, grip and silhouette. The atlas identifies
-- actual cargo; these read-only layers add baskets, straps, crates and hands.
local A=require 'game.PixelAssets'
local C={}
C.specs={
    wood={kind='shoulder',w=28,h=8},rawwood={kind='shoulder',w=30,h=10},
    stone={kind='bundle',w=15,h=10},rawstone={kind='sack',w=14,h=13},
    grain={kind='sack',w=12,h=13},flour={kind='sack',w=12,h=12},
    ironore={kind='sack',w=13,h=12},coal={kind='sack',w=14,h=12},goldore={kind='sack',w=12,h=13},
    bread={kind='basket',w=14,h=8},meat={kind='basket',w=15,h=9},fish={kind='basket',w=16,h=8},food={kind='basket',w=13,h=9},
    livestock={kind='cart',w=24,h=14},hide={kind='roll',w=18,h=10},leather={kind='roll',w=19,h=11},
    iron={kind='bundle',w=19,h=9},gold={kind='chest',w=14,h=10},
    bow={kind='long',w=26,h=13},ironspear={kind='long',w=32,h=9},
    leatherarmor={kind='case',w=14,h=12},ironarmor={kind='case',w=15,h=13},
}
function C.pose(resource,direction,vehicle)
    local s=C.specs[resource]or {kind='crate',w=18,h=14}
    local d=direction or 0;local back=s.kind=='sack'or s.kind=='roll'
    local x,y,behind=0,-1.5,d==3
    if vehicle then x,y,behind=0,-7,false
    elseif s.kind=='cart'then x=d==1 and -22 or 22;y=-1;behind=false
    elseif back then x=d==1 and 6 or d==2 and -6 or 0;y=-5;behind=d~=3
    elseif s.kind=='shoulder'or s.kind=='long'then x=d==1 and -8 or d==2 and 8 or -8;y=-14;behind=true
    else x=d==1 and -13 or d==2 and 13 or d==0 and 7 or -7;y=-1.5 end
    return {kind=s.kind,w=s.w,h=s.h,x=x-s.w/2,y=y-s.h/2,behind=behind,back=back,vehicle=vehicle}
end
local function box(vg,x,y,w,h,r,g,b)
    nvgBeginPath(vg);nvgRect(vg,math.floor(x+.5),math.floor(y+.5),w,h)
    nvgFillColor(vg,nvgRGBA(r,g,b,255));nvgFill(vg)
end
function C.draw(vg,p,px,py,pose,contacts)
    local x,y,w,h=px+pose.x,py+pose.y,pose.w,pose.h
    if contacts then
        if pose.vehicle then return end
        if pose.back then
            -- Leather shoulder loops remain in front even when the sack is behind.
            for _,side in ipairs({-1,1})do box(vg,px+side*5,py-12,2,7,128,86,48)end
        elseif pose.behind and(pose.kind=='shoulder'or pose.kind=='long')then
            for _,side in ipairs({-1,1})do
                box(vg,px+side*11,py-11,2,5,127,89,48)
                box(vg,px+side*11,py-7,3,3,215,167,111)
            end
        else
            local gx=p.direction==1 and x+w-2 or p.direction==2 and x or x+3
            local gy=y+((pose.kind=='shoulder'or pose.kind=='long')and h-1 or 1)
            -- Forearm reaches from the real torso to the load handle.
            local side=p.direction==1 and -1 or 1
            nvgBeginPath(vg);nvgMoveTo(vg,px+side*6,py-8);nvgLineTo(vg,gx+1,gy+1)
            nvgStrokeColor(vg,nvgRGBA(215,167,111,255));nvgStrokeWidth(vg,2);nvgStroke(vg)
            box(vg,gx,gy,3,3,215,167,111)
            if p.direction==0 or p.direction==3 then box(vg,x+w-6,gy,3,3,215,167,111)end
        end
        return
    end
    local kind=pose.kind
    if pose.vehicle then
        A.draw(vg,'cargo.png',x+(w-12)/2,y+(h-12)/2,12,12,A.goods[p.cargo]or 0,0,A.cargoColumns,1);return
    end
    if kind=='long'then
        if p.cargo=='bow'then
            nvgBeginPath(vg);nvgMoveTo(vg,x+2,y+h-2);nvgLineTo(vg,x+5,y+4)
            nvgLineTo(vg,x+w/2,y+1);nvgLineTo(vg,x+w-5,y+4);nvgLineTo(vg,x+w-2,y+h-2)
            nvgStrokeColor(vg,nvgRGBA(178,130,69,255));nvgStrokeWidth(vg,2);nvgStroke(vg)
            box(vg,x+2,y+h-2,w-4,1,225,210,161)
        else
            box(vg,x,y+h/2,w-5,2,160,116,65)
            box(vg,x+w-7,y+h/2-2,5,6,173,190,190);box(vg,x+w-2,y+h/2,2,2,215,223,210)
        end
    elseif kind=='shoulder'then
        box(vg,x,y+2,w,h-3,133,91,46);box(vg,x,y+2,w,2,187,143,78)
        for i=1,2 do box(vg,x+math.floor(w*i/3),y,2,h,94,70,43)end
        if p.cargo=='rawwood'then
            box(vg,x,y+3,3,h-4,202,164,103);box(vg,x+1,y+4,1,h-6,109,78,45)
        else box(vg,x+2,y+h-3,w-4,1,209,168,99)end
    elseif kind=='sack' or kind=='roll'then
        box(vg,x+2,y,w-4,h,165,135,82);box(vg,x,y+3,w,h-5,157,126,74)
        box(vg,x+3,y+2,w-6,2,205,175,106);box(vg,x+w/2-1,y,2,h,106,83,47)
        A.draw(vg,'cargo.png',x+(w-10)/2,y+(h-10)/2,10,10,A.goods[p.cargo]or 0,0,A.cargoColumns,1)
    else
        local dark=kind=='case'and 83 or 116
        box(vg,x,y+2,w,h-2,dark,82,48)
        A.draw(vg,'cargo.png',x+(w-12)/2,y+(h-12)/2,12,12,A.goods[p.cargo]or 0,0,A.cargoColumns,1)
        box(vg,x,y+h-3,w,3,179,131,68)
        if kind=='cart'then
            for _,wx in ipairs({x+4,x+w-7})do box(vg,wx,y+h,4,4,69,53,36);box(vg,wx+1,y+h+1,2,2,137,113,69)end
            local inner=p.direction==1 and x+w or x
            local side=p.direction==1 and -1 or 1
            nvgBeginPath(vg);nvgMoveTo(vg,inner,y+2);nvgLineTo(vg,px+side*6,py-7)
            nvgStrokeColor(vg,nvgRGBA(147,107,59,255));nvgStrokeWidth(vg,2);nvgStroke(vg)
        elseif kind=='crate'then
            for i=0,3 do box(vg,x+i*(w-2)/3,y,2,h,169,123,67)end
            box(vg,x,y,w,2,190,144,82)
        elseif kind=='basket'then
            box(vg,x,y,2,h,180,137,75);box(vg,x+w-2,y,2,h,180,137,75)
            box(vg,x+3,y-2,w-6,2,195,151,89)
        elseif kind=='chest'or kind=='case'then
            box(vg,x+2,y+1,2,h-2,179,151,78);box(vg,x+w-4,y+1,2,h-2,179,151,78)
        end
    end
    local load=p.actor and p.actor.workLoad
    if load then
        local index=0
        for _,resource in ipairs(require('game.Definitions').goods)do
            if resource~=p.cargo and (load.goods[resource]or 0)>0 then
                A.draw(vg,'cargo.png',x+w-4+index*5,y+h-6,8,8,A.goods[resource]or 0,0,A.cargoColumns,1)
                index=index+1
            end
        end
    end

end
return C
