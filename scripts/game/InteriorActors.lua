local Architecture=require 'game.PaintedArchitecture'
local Meals=require 'game.Meals'
local I={}
function I.presentation(sim,actor,action)
    local m=actor.meal
    if m then
        local b=sim.buildings[m.target]
        if not b or b.kind~='kitchen' then return end
        local progress=m.phase=='eat' and 1 or
            m.phase=='enter' and 1-m.timer/Meals.doorwaySeconds or
            m.phase=='exit' and m.timer/Meals.doorwaySeconds or 0
        if progress>.74 then return 'diner',b,m.seat or 1,math.min(1,(progress-.74)/.13) end
        if progress>.29 then return 'hidden',b end
    elseif action=='cook' and actor.building then
        local b=sim.buildings[actor.building]
        if b and b.kind=='kitchen' and (actor.workPresence or 0)<=.001 then
            if (actor.slot or 1)>1 then return 'hidden',b end
            return 'chef',b,1,1
        end
    end
end
function I.apply(world,p,actor,action)
    local kind,b,seat,alpha=I.presentation(world.sim,actor,action)
    local was=p.interior
    p.interior=kind
    if p.shadow then p.shadow.enabled=kind==nil end
    if kind=='hidden' then p.node.enabled=false;return end
    if not kind then
        if was then
            p.previousNode.enabled=false;p.blendAt=nil
            p.quad.color=Color(1,1,1,1);p.billboards:Commit()
        end
        return
    end
    local record=world.buildings[b.id]
    if not record or not record.painted then return end
    local u,v,top,bottom,scale
    if kind=='chef' then u,v,top,bottom,scale=.135,.646,.15,.47,.72
    else
        u=({565/1701,688/1701,1270/1701,1400/1701})[seat] or 565/1701
        v=seat<=2 and .600 or .622
        top,bottom,scale=0,1,.48
    end
    -- Older saves retain smaller reserved plots. Match their actual window
    -- size instead of allowing full-size portraits to spill over the facade.
    scale=scale*((b.footprintW or 1)+.16)/3.16
    local uv=p.quad.uv
    p.quad.uv=Rect(uv.min.x,uv.min.y+(uv.max.y-uv.min.y)*top,uv.max.x,uv.min.y+(uv.max.y-uv.min.y)*bottom)
    local projection=math.max(.25,math.abs((world.cameraNode.worldRotation*Vector3.UP).y))
    p.quad.size=Vector2(p.height*.5*scale,p.height*.5*(bottom-top)*scale/projection)
    p.quad.position=Vector3.ZERO
    p.quad.color=Color(1,1,1,alpha or 1)
    local forward=world.cameraNode.worldRotation*Vector3.FORWARD
    p.node.worldPosition=Architecture.anchor(world,b,u,v)-forward*4.25
    p.node.enabled=true
    p.previousNode.enabled=false;p.load.enabled=false
    p.billboards:Commit()
    if was~=kind then p.blendAt=nil end
end
return I
