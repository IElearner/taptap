-- Hand-authored elder portrait for the opening guide. A painted PNG can replace
-- it later without changing the dialogue flow.
local UI = require "urhox-libs/UI"
local Art = require "game.Art"
local Mentor = {}
local function fill(vg,c)
    nvgFillColor(vg,nvgRGBA(c[1],c[2],c[3],c[4] or 255));nvgFill(vg)
end
local function shape(vg,points,c)
    nvgBeginPath(vg);nvgMoveTo(vg,points[1],points[2])
    for i=3,#points,2 do nvgLineTo(vg,points[i],points[i+1]) end
    nvgClosePath(vg);fill(vg,c)
end
local function ellipse(vg,x,y,rx,ry,c)
    nvgBeginPath(vg);nvgEllipse(vg,x,y,rx,ry);fill(vg,c)
end
local function stroke(vg,x1,y1,x2,y2,c,width)
    nvgBeginPath(vg);nvgMoveTo(vg,x1,y1);nvgLineTo(vg,x2,y2)
    nvgStrokeColor(vg,nvgRGBA(c[1],c[2],c[3],c[4] or 255));nvgStrokeWidth(vg,width or 1);nvgStroke(vg)
end
function Mentor.portrait()
    local p=UI.Panel { id="mentorPortrait",width=112,height=128,flexShrink=0,pointerEvents="none" }
    function p:Render(vg)
        local l=self:GetAbsoluteLayout()
        local x,y,s=l.x,l.y,math.min(l.w/112,l.h/128)
        nvgSave(vg);nvgTranslate(vg,x,y);nvgScale(vg,s,s)
        if Art.draw(vg,"portrait-elder",0,0,112,128) then nvgRestore(vg);return end
        -- Warm paper ground, layered robe, weathered face and long white beard.
        nvgBeginPath(vg);nvgRoundedRect(vg,3,3,106,122,9);fill(vg,{83,65,39})
        nvgBeginPath(vg);nvgRoundedRect(vg,7,7,98,114,7);fill(vg,{177,145,91})
        nvgBeginPath(vg);nvgRoundedRect(vg,10,10,92,108,6);fill(vg,{197,175,125})
        ellipse(vg,56,110,48,22,{85,95,79})
        shape(vg,{17,119,24,86,38,74,74,74,90,87,98,119},{50,79,72})
        shape(vg,{30,83,43,70,56,79,69,70,84,85,65,118,47,118},{91,108,91})
        stroke(vg,55,84,43,117,{196,178,130},2)
        stroke(vg,58,85,70,117,{37,66,62},2)
        -- Bound black hair, grey temples and a cloth headband.
        ellipse(vg,56,52,34,34,{64,60,51})
        ellipse(vg,56,57,26,32,{196,145,104})
        ellipse(vg,29,61,5,8,{176,125,91});ellipse(vg,83,61,5,8,{176,125,91})
        shape(vg,{23,50,31,32,46,23,61,25,77,31,86,48,82,39,69,36,56,39,42,36,29,46},{68,69,62})
        shape(vg,{29,38,44,30,64,31,81,40,79,45,58,41,36,45},{164,154,123})
        stroke(vg,34,45,77,43,{72,71,62},2)
        -- Eyes, brow, nose and fine age lines.
        stroke(vg,38,55,50,52,{72,55,45},3)
        stroke(vg,62,52,75,54,{72,55,45},3)
        stroke(vg,40,60,48,61,{48,44,37},2)
        stroke(vg,64,61,73,60,{48,44,37},2)
        ellipse(vg,45,60,1.5,2,{34,37,32});ellipse(vg,69,60,1.5,2,{34,37,32})
        stroke(vg,54,59,51,72,{121,79,60},2)
        stroke(vg,51,72,58,73,{117,78,60},1)
        stroke(vg,33,67,40,69,{155,100,75},1)
        stroke(vg,74,69,81,66,{155,100,75},1)
        -- Moustache and beard use several ink and pale-brush layers.
        shape(vg,{48,73,57,78,65,73,76,76,67,82,58,82,48,82,38,77},{222,209,172})
        shape(vg,{39,78,48,81,56,82,65,81,74,78,72,94,64,108,57,116,46,106,40,91},{224,215,187})
        stroke(vg,48,86,47,103,{167,159,137},1)
        stroke(vg,59,85,58,111,{169,160,139},1)
        stroke(vg,68,86,64,102,{169,160,139},1)
        stroke(vg,51,83,62,83,{101,80,66},1)
        -- Bamboo staff on the outer edge.
        stroke(vg,94,23,93,116,{76,63,42},4)
        stroke(vg,92,29,96,27,{180,151,86},1)
        stroke(vg,92,64,96,62,{180,151,86},1)
        stroke(vg,92,97,96,95,{180,151,86},1)
        nvgRestore(vg)
    end
    return p
end
return Mentor
