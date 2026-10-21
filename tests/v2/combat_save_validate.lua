local Sim=require 'game.Simulation'
local Data=require 'game.SaveData'
V.atFrame(8,function()
 local s=Sim.new('infinite',23);s.started=true;s.militia=1;s.raid=true
 s.enemies={{x=10,y=9,hp=5}};s.combatClock=1.15
 s:update(.1)
 V.assert(s.militia==0,'A legitimate combat tick consumes one guard')
 local restored,err=Data.restore(Data.capture(s,1000,1,true),'infinite')
 V.assert(restored~=nil,'Save on combat casualty tick restores: '..tostring(err))
end)
V.atFrame(25,function()V.finish()end)
