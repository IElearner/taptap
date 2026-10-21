-- Pre-rendered architectural art in the existing depth-tested world. Gameplay,
-- footprints, construction points and physical inventory remain independent.
local Catalog=require 'game.PaintedArchitectureManifest'
Catalog.kitchen={material='art/v12/kitchen.material',width=1701,height=925,source='kitchen-source.png',sourceCell={0,0,1701,925}}
Catalog.ranch={material='art/v11/ranch.material',width=1740,height=904,source='ranch-source.png',sourceCell={0,0,1740,904}}
local P={}
function P.supports(b) return b.complete and Catalog[b.kind]~=nil end
function P.create(world,root,b)
    local spec=Catalog[b.kind]
    local base=cache:GetResource('Material',spec.material)
    local material=world.buildings[b.id].artBlendAt and base:Clone() or base
    local node=root:CreateChild('PaintedArchitecture')
    local plane=world:part(node,'ArtworkPlane','Plane',material,0,0,0,1,1,1,Quaternion(-90,Vector3.RIGHT))
    local draw=plane:GetComponent('StaticModel');draw.castShadows=false
    world.buildings[b.id].painted={node=node,draw=draw,spec=spec,material=material,base=base}
    if b.kind=='kitchen' then
        local foreground=root:CreateChild('DiningForeground')
        local plane=world:part(foreground,'DiningTablesAndSills','Plane',cache:GetResource('Material','art/v12/dining-foreground.material'),0,0,0,1,1,1,Quaternion(-90,Vector3.RIGHT))
        plane:GetComponent('StaticModel').castShadows=false
        world.buildings[b.id].painted.foreground=foreground
    end
    if b.kind=='ranch' then
        local fence=root:CreateChild('RanchFrontFence')
        local plane=world:part(fence,'PenOcclusionArt','Plane',cache:GetResource('Material','art/v12/ranch-foreground.material'),0,0,0,1,1,1,Quaternion(-90,Vector3.RIGHT))
        plane:GetComponent('StaticModel').castShadows=false
        plane:GetComponent('StaticModel').material.renderOrder=135
        world.buildings[b.id].painted.frontFence=fence
    end
    -- Keep the actual loading inventory, but suppress the old architectural
    -- shell. The rendered mesh remains a pickable child of the building.
    local shape=root:GetChild('AuthoredBuilding')
    if shape then
        for _,child in ipairs(shape:GetChildren()) do
            if child.name=='ArchitectureMesh' or child.name=='MainHall' or child.name=='LoadingBay' then
                child.enabled=false
                local drawable=child:GetComponent('StaticModel')
                if drawable then drawable.enabled=false end
            end
        end
    end
    local wheel=world.buildings[b.id].wheel
    if wheel then wheel.position=Vector3(-.80,.39,-.95) end
end
function P.update(world,b)
    local r=world.buildings[b.id];local p=r and r.painted
    if not p then return end
    local width=(b.footprintW or 1)+.16
    local height=width*p.spec.height/p.spec.width
    local flatten=({store=.93,mill=.94,quarry=.94})[b.kind] or 1
    height=height*flatten
    local up=world.cameraNode.worldRotation*Vector3(0,1,0)
    local forward=world.cameraNode.worldRotation*Vector3(0,0,1)
    local physicalHeight=height/math.max(.25,math.abs(up.y))
    -- Move the art backwards along the view ray without shifting its screen
    -- anchor. Front-door visitors and delivered parcels stay in front of it.
    local front=Vector3(0,.012,-(b.footprintH or 1)*.46)
    p.node.position=front+forward*2.25+Vector3(0,physicalHeight*.5,0)
    p.node.scale=Vector3(width,physicalHeight,1)
    p.node.rotation=Quaternion((({store=2,mill=1.5,quarry=2,house=1,butcher=1,woodcutter=1})[b.kind] or 0),Vector3.FORWARD)
    if p.foreground then
        p.foreground.worldPosition=p.node.worldPosition-forward*4.50
        p.foreground.worldRotation=p.node.worldRotation;p.foreground.worldScale=p.node.worldScale
    end
    if p.frontFence then
        p.frontFence.worldPosition=p.node.worldPosition-forward*4.50
        p.frontFence.worldRotation=p.node.worldRotation;p.frontFence.worldScale=p.node.worldScale
    end
    local t=r.artBlendAt and math.max(0,math.min(1,(world.sim.elapsed-r.artBlendAt)/.38)) or 1
    if p.material~=p.base then
        p.material:SetShaderParameter('opacity',t*t*(3-2*t))
        if t>=1 then p.draw.material=p.base;p.material=p.base end
    end
end
-- Image-normalized anchors keep windows and chimney effects registered with
-- the illustration even when zoom, plot size or architectural tilt changes.
---@return Vector3
function P.anchor(world,b,u,v)
    local p=world.buildings[b.id].painted
    local x=(u-.5)*p.node.scale.x
    local y=(.5-v)*p.node.scale.y
    return p.node.worldPosition+p.node.worldRotation*Vector3(x,y,0)
end
---@param height number
---@return Vector3
function P.groundPoint(world,b,u,v,height)
    local point=P.anchor(world,b,u,v)
    local forward=world.cameraNode.worldRotation*Vector3.FORWARD
    return point+forward*((height-point.y)/forward.y)
end
return P
