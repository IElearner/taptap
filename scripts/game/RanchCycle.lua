-- Feed is delivered by the same logistics system as every other input.
-- A caretaker scatters real grain periodically; fed pigs grow between visits.
local R={feedSeconds=35,scatterSeconds=3.6,growSeconds=105,doorSeconds=2.8}
function R.busy(b) return b.ranchPhase~=nil or (b.feedClock or 0)>0 end
function R.presence(b)
    if b.ranchPhase=='exit' then return 1-(b.ranchClock or 0)/R.doorSeconds end
    if b.ranchPhase=='return' then return (b.ranchClock or 0)/R.doorSeconds end
    return (b.feedClock or 0)>0 and 1 or 0
end
-- Stop new feeding/growth, but finish an already started physical visit.
-- Grain paid before the pause and the current growth batch remain intact.
function R.finishVisit(b,dt)
    if not b.ranchPhase and (b.feedClock or 0)>0 then b.ranchPhase='feed' end
    if b.ranchPhase=='exit' then
        b.ranchClock=R.presence(b)*R.doorSeconds
        b.ranchPhase='return'
    end
    if b.ranchPhase=='feed' then
        b.feedClock=math.max(0,(b.feedClock or 0)-dt)
        if b.feedClock==0 then b.ranchPhase='return';b.ranchClock=R.doorSeconds end
    elseif b.ranchPhase=='return' then
        b.ranchClock=math.max(0,(b.ranchClock or 0)-dt)
        if b.ranchClock==0 then b.ranchPhase=nil;b.ranchClock=nil end
    end
end
function R.update(b,dt,rate)
    b.feedRemaining=math.max(0,(b.feedRemaining or 0)-dt)
    b.feedClock=b.feedClock or 0
    if not b.ranchPhase and b.feedClock>0 then b.ranchPhase='feed' end -- old saves
    if b.ranchPhase=='exit' then
        if rate>0 then b.ranchClock=math.max(0,(b.ranchClock or 0)-dt) end
        if b.ranchClock==0 then
            if b.inputs>0 then
                b.inputs=b.inputs-1
                if b.inputGoods then b.inputGoods.grain=math.max(0,(b.inputGoods.grain or 0)-1) end
                b.feedClock=R.scatterSeconds;b.ranchPhase='feed'
                b.feedRemaining=R.feedSeconds+R.scatterSeconds
                b.feedVisits=(b.feedVisits or 0)+1
            else b.ranchPhase='return';b.ranchClock=R.doorSeconds end
        end
    elseif b.ranchPhase=='feed' then
        if rate>0 then b.feedClock=math.max(0,b.feedClock-dt) end
        if b.feedClock==0 then b.ranchPhase='return';b.ranchClock=R.doorSeconds end
    elseif b.ranchPhase=='return' then
        if rate>0 then b.ranchClock=math.max(0,(b.ranchClock or 0)-dt) end
        if b.ranchClock==0 then b.ranchPhase=nil;b.ranchClock=nil end
    elseif b.feedRemaining==0 and rate>0 and b.inputs>0 then
        b.ranchPhase='exit';b.ranchClock=R.doorSeconds
    end
    -- Production pauses when the output stall is full; feeding can still happen.
    if b.feedRemaining>0 and b.feedClock==0 and b.buffer<2 then
        b.timer=b.timer+dt
        if b.timer>=R.growSeconds then b.timer=b.timer-R.growSeconds;return true end
    end
    return false
end
function R.action(b)
    return (b.feedClock or 0)>0 and "feed" or nil
end
return R
