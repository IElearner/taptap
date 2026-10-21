-- Hand/foot targets in character space. Actual two-bone joints follow the
-- targets; tools are wrist children rather than decorations at the elbow.
local Motion={strokeSeconds=1.6,unloadSeconds=1.4,readySeconds=.65,packingSeconds=2.0}
local Cargo=require "game.Cargo"
local DOWN=Vector3(0,-1,0)
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function smooth(t) t=clamp(t,0,1);return t*t*(3-2*t) end
local function mix(a,b,t) return a+(b-a)*t end
local function track(keys,t)
    for i=2,#keys do
        if t<=keys[i][1] then
            local a,b=keys[i-1],keys[i]
            return mix(a[2],b[2],smooth((t-a[1])/(b[1]-a[1])))
        end
    end
    return keys[#keys][2]
end
-- Integrate contact time across any dt, including several complete cycles.
-- One complete cycle still contributes exactly one cycle of worker-seconds.
function Motion.workBetween(before,after)
    local function cumulative(t)
        local cycles=math.floor(t/Motion.strokeSeconds)
        local phase=t/Motion.strokeSeconds-cycles
        return (cycles+clamp((phase-.60)/.16,0,1))*Motion.strokeSeconds
    end
    return cumulative(after)-cumulative(before)
end
---@param joint Node
---@param child Node
---@param target Vector3
---@param length1 number
---@param length2 number
---@param bend Vector3
local function limb(joint,child,target,length1,length2,bend)
    ---@type Vector3
    local delta=target-joint.position
    local distance=clamp(delta:Length(),.005,length1+length2-.00001)
    local direction=delta:Length()>.00001 and delta:Normalized() or DOWN
    local along=(length1*length1-length2*length2+distance*distance)/(2*distance)
    ---@type Vector3
    local perpendicular=bend-direction*bend:DotProduct(direction)
    if perpendicular:Length()<.001 then perpendicular=Vector3(1,0,0) end
    perpendicular=perpendicular:Normalized()
    local elbow=joint.position+direction*along+perpendicular*math.sqrt(math.max(0,length1*length1-along*along))
    local upper=Quaternion(DOWN,(elbow-joint.position):Normalized())
    joint.rotation=upper
    child.rotation=Quaternion(DOWN,upper:Inverse()*(joint.position+direction*distance-elbow):Normalized())
end
function Motion.apply(p,a,action,walking,clock,distance)
    local cycle=distance*math.pi*2/.34
    local t=((a.timer or clock)/Motion.strokeSeconds)%1
    local lean,bob,seat=0,0,action=="eat"
    local hands={Vector3(-.105,.035,.005),Vector3(.105,.035,.005)}
    local wrist={Quaternion(),Quaternion()}
    local loadY,loadZ=.145,.17
    if walking then
        bob=-.020-.008*math.abs(math.sin(cycle))
        lean=a.carrying and 5 or 2
        for i,sign in ipairs({-1,1}) do hands[i]=Vector3(sign*.104,.025,.060*math.sin(cycle)*sign) end
    end
    if a.carrying then
        local cargo=Cargo.profile(a)
        hands={Vector3(-cargo.halfGrip,cargo.handY,cargo.handZ),Vector3(cargo.halfGrip,cargo.handY,cargo.handZ)}
    end
    if a.phase=="packing" or a.phase=="unload" then
        local u=a.phase=="unload" and smooth(1-(a.timer or 0)/Motion.unloadSeconds) or smooth(1-(a.timer or 0)/Motion.packingSeconds)
        local bend=math.sin(u*math.pi)
        lean=35*bend
        bob=-.14*bend
        loadY,loadZ=.145-.20*u,.17+.10*u
        hands={Vector3(-.135,.13-.15*bend,.17),Vector3(.135,.13-.15*bend,.17)}
    elseif action=="hammer" or action=="chop" then
        local low=a.job and (a.job.kind=="road" or a.job.pointPhase==1)
        t=((a.timer or a.woodTimer or clock)/Motion.strokeSeconds)%1
        if action=="chop" then t=((a.woodClock or clock)/Motion.strokeSeconds)%1 end
        local raised=Vector3(.085,.43,-.025)
        local hit=Vector3(.085,(action=="chop" or low) and .10 or .16,.185)
        hands[2]=track({{0,hit},{.42,raised},{.57,raised},{.66,hit},{.78,hit},{1,hit}},t)
        hands[1]=action=="chop" and hands[2]+Vector3(-.025,-.055,0) or Vector3(-.10,.06,.08)
        lean=track({{0,8},{.42,-5},{.57,-5},{.66,15},{.78,15},{1,8}},t)
        if low then lean=lean+18;bob=-.08 end
        wrist[2]=Quaternion(track({{0,-66},{.42,25},{.57,25},{.66,-66},{1,-66}},t),0,0)
        wrist[1]=wrist[2]
    elseif action=="plow" or action=="tend" or action=="harvest" then
        t=(clock/1.9)%1
        local reach=track({{0,.13},{.35,.21},{.62,.21},{.82,.13},{1,.13}},t)
        lean=track({{0,12},{.35,29},{.62,29},{.82,12},{1,12}},t)
        hands[2]=Vector3(.060,.095,reach)
        hands[1]=Vector3(.040,.16,reach-.015)
        wrist[2]=Quaternion(-22+16*math.sin(t*math.pi*2),0,0)
        wrist[1]=wrist[2]
    elseif action=="water" then
        t=(clock/2.4)%1
        local pour=smooth(math.min(t/.25,(1-t)/.25))
        lean=8+pour*8
        hands[2]=Vector3(.11,.10,.17)
        hands[1]=Vector3(-.02,.13,.15)
        wrist[2]=Quaternion(-28*pour,-90,0)
        p.pouring=pour>.7
    elseif seat then
        t=(clock/2.8)%1
        hands[1]=Vector3(-.08,.19,.205)
        lean=3+2*math.sin(t*math.pi*2)
        local lift=track({{0,0},{.28,1},{.52,1},{.75,0},{1,0}},t)
        hands[2]=mix(Vector3(.02,.235,.22),Vector3(.035,.27,.16),lift)
        local destination=mix(hands[1]+Vector3(0,.006,0),Vector3(0,.315,.047),lift)
        local aim=Vector3(destination.x-hands[2].x,destination.y-hands[2].y,destination.z-hands[2].z)
        local c,s=math.cos(math.rad(lean)),math.sin(math.rad(lean))
        local biteDirection=Vector3(aim.x,aim.y*c-aim.z*s,aim.y*s+aim.z*c)
        wrist[2]=Quaternion(Vector3(0,-.109,.046),biteDirection)
    end
    local waist=seat and .38 or .33
    p.body.position=Vector3(0,waist+bob,0)
    p.body.rotation=Quaternion(lean,0,walking and math.sin(cycle)*1.3 or 0)
    p.torso.rotation=Quaternion(lean*.08,0,0)
    p.head.position=p.body.position+p.body.rotation*Vector3(0,.335,0)
    p.head.rotation=p.body.rotation*Quaternion(-lean*.45,0,0)
    p.neck.position=p.body.position+p.body.rotation*Vector3(0,.276,0)
    p.neck.rotation=p.body.rotation
    for i,sign in ipairs({-1,1}) do
        p.hips[i].position=Vector3(sign*.048,waist+bob,0)
        limb(p.shoulders[i],p.elbows[i],hands[i],.125,.111,Vector3(sign*.5,-1,0))
        p.hands[i].worldRotation=p.node.worldRotation*wrist[i]
        local foot=Vector3(sign*.048,.04,0)
        if walking then
            local f=(distance/.34+(i-1)*.5)%1
            if f<.62 then foot.z=.075-.15*f/.62
            else local u=(f-.62)/.38;foot.z=-.075+.15*smooth(u);foot.y=.04+.055*math.sin(u*math.pi) end
        elseif seat then foot=Vector3(sign*.048,.195,.155) end
        limb(p.hips[i],p.knees[i],foot,.155,.135,Vector3(0,0,1))
        if p.feet[i] then p.feet[i].worldRotation=p.node.worldRotation end
    end
    p.load.position=Vector3(0,loadY,loadZ)
end
return Motion
