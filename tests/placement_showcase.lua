local Game=require "network.Standalone"
local Store=require "game.SaveStore"
V.atFrame(6,function()
    Game.UseStore(Store.new({now=function() return 1000 end,read=function() return nil end,write=function() return true end}))
end)
V.atFrame(9,function()
    local _,view,hud=Game.Inspect()
    hud.root:FindById("enterVillage").props.onClick()
    hud.root:FindById("mentorSkip").props.onClick()
    hud.root:FindById("build_quarry").props.onClick()
    local l=view.panel:GetAbsoluteLayout()
    local x,y=8,8
    view.panel.props.onPointerMove({x=l.x+l.w*0.53+(x-y)*30,y=l.y+l.h*0.52-270+(x+y)*15})
end)
V.atFrame(65,function() V.finish() end)
