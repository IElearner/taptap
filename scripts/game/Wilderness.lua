-- Original painted tree silhouettes share the same upright world plane as
-- villagers. Short felling motion is visual only; simulation owns the timber.
local W={}
function W.tree(world,key,x,y)
    local seed=(x*17+y*23)%9
    local root=world.scene:CreateChild('Tree_'..key)
    root.position=Vector3(x-10+((x*13+y*7)%9-4)*.025,0,9-y+((x*3+y*19)%7-3)*.025)
    local draw=root:CreateComponent('BillboardSet')
    draw.numBillboards=1;draw.relative=true;draw.scaled=false;draw.sorted=true;draw.faceCameraMode=FC_ROTATE_Y
    draw.material=cache:GetResource('Material','environment/village-v7/trees.material')
    local type=(x*7+y*11)%4;local col=type%2;local row=math.floor(type/2)
    local q=draw:GetBillboard(0);q.enabled=true;q.color=Color(1,1,1,1)
    q.uv=Rect((col*512+1)/1024,(row*512+1)/1024,((col+1)*512-1)/1024,((row+1)*512-1)/1024)
    local screenHeight=1.25+seed*.035
    local up=world.cameraNode.worldRotation*Vector3(0,1,0)
    local height=screenHeight/math.max(.25,math.abs(up.y))
    q.size=Vector2(screenHeight*.5,height*.5)
    q.position=Vector3(0,height*(496/512-.5),0)
    draw:Commit()
    local shadow=world:part(root,'TreeShadow','Sphere',cache:GetResource('Material','actors/directional-v6/shadow.material'),-.15,.005,.12,.75,.006,.38)
    shadow:GetComponent('StaticModel').castShadows=false
    return {node=root,draw=draw,quad=q,height=height,x=x,y=y,fallAt=nil}
end
function W.fall(world,tree)
    tree.fallAt=tree.fallAt or world.sim.elapsed
    local t=math.max(0,math.min(1,(world.sim.elapsed-tree.fallAt)/1.25))
    local angle=t*t*math.pi*.5
    local offset=tree.height*(496/512-.5)
    tree.quad.rotation=math.deg(angle)
    tree.quad.position=Vector3(-math.sin(angle)*offset,math.cos(angle)*offset+.015,0)
    tree.quad.color=Color(1,1,1,1-math.max(0,(t-.70)/.30))
    tree.draw:Commit()
    return t>=1
end
function W.occlusion(world,tree)
    -- A foreground canopy should not hide the entire felling interaction.
    -- Fade the complete silhouette together, preserving a continuous outline.
    local occluded=false
    for _,a in pairs(world.sim.workers) do
        if a.woodPhase and a.treeX then
            local ahead=tree.y-a.y
            local working=a.treeX==tree.x and a.treeY==tree.y and (a.woodPhase=='chop' or a.woodPhase=='gather')
            if working or ahead>0 and ahead<1.55 and math.abs(tree.x-a.x)<.72 then occluded=true;break end
        end
    end
    local dt=math.max(0,math.min(.25,world.sim.elapsed-(tree.lastFadeTime or world.sim.elapsed)))
    tree.lastFadeTime=world.sim.elapsed
    local target=occluded and .28 or 1
    tree.opacity=tree.opacity and tree.opacity+(target-tree.opacity)*math.min(1,dt*5) or target
    tree.quad.color=Color(1,1,1,tree.opacity);tree.draw:Commit()
end
function W.stump(world,key,x,y)
    local n=world.scene:CreateChild('Stump_'..key);n.position=Vector3(x-10,0,9-y)
    world:part(n,'StumpBark','Cylinder',world:material(109,79,48),0,.075,0,.19,.15,.18)
    world:part(n,'TreeCut','Cylinder',world:material(191,155,94),0,.153,0,.18,.008,.17)
    return n
end
return W
