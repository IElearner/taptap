-- Read-only renderer geometry probe complementing (never replacing) the 88
-- native direction images. Capture contact primitives only, not whole cargo.
local Cargo=require 'game.PixelCargo'
V.atFrame(8,function()
 local names={'nvgBeginPath','nvgRect','nvgFillColor','nvgFill','nvgMoveTo','nvgLineTo','nvgStrokeColor','nvgStrokeWidth','nvgStroke'}
 local originals={};for _,n in ipairs(names)do originals[n]=_G[n]end
 local primitives={};local last
 _G.nvgBeginPath=function()last=nil end
 _G.nvgRect=function(_,x,y,w,h)primitives[#primitives+1]={kind='rect',x=x,y=y,w=w,h=h}end
 _G.nvgMoveTo=function(_,x,y)last={x=x,y=y}end
 _G.nvgLineTo=function(_,x,y)if last then primitives[#primitives+1]={kind='line',x=last.x,y=last.y,x2=x,y2=y}end;last={x=x,y=y}end
 for _,n in ipairs({'nvgFillColor','nvgFill','nvgStrokeColor','nvgStrokeWidth','nvgStroke'})do _G[n]=function()end end
 local ok,err=pcall(function()
  for _,resource in ipairs({'wood','rawwood','bow','ironspear'})do for direction=0,3 do
   primitives={};local p={cargo=resource,direction=direction};local pose=Cargo.pose(resource,direction,false)
   Cargo.draw(nil,p,0,0,pose,true)
   local crosses=false
   for _,g in ipairs(primitives)do
    if g.kind=='rect'then
     if g.x<4 and g.x+g.w>-4 and g.y< -9 and g.y+g.h> -15 then crosses=true end
    else
     for i=0,100 do local t=i/100;local x=g.x+(g.x2-g.x)*t;local y=g.y+(g.y2-g.y)*t
      if x>-4 and x<4 and y> -15 and y< -9 then crosses=true end
     end
    end
   end
   V.assert(pose.behind and #primitives>0 and not crosses,resource..' direction '..direction..' contact primitives avoid conservative central face zone')
  end end
 end)
 for n,original in pairs(originals)do _G[n]=original end
 V.assert(ok,'Contact primitive inspection restores all renderer globals: '..tostring(err));V.finish()
end)
