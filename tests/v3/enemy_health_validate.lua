-- Rendering denominator must match the actual spawn rules in both modes.
local Sim=require 'game.Simulation'
local Pixel=require 'game.PixelWorldView'
V.atFrame(8,function()
 local s=Sim.new('finite',23)
 V.assert(Pixel.enemyMaxHP(s)==3,'Finite initial defense displays three actual hit points')
 s.defended=true
 V.assert(Pixel.enemyMaxHP(s)==3,'Legacy defended flag alone does not upgrade an old active first-wave bar')
 s.campaignRaid=true
 V.assert(Pixel.enemyMaxHP(s)==5,'Industrial campaign defense displays five actual hit points')
 V.assert(math.floor(18*4/Pixel.enemyMaxHP(s))==14 and math.floor(18*2/Pixel.enemyMaxHP(s))==7,'Damaged advanced enemies show proportional fourteen and seven pixel health bars')
 s.campaignRaid=false;s.freePlay=true
 V.assert(Pixel.enemyMaxHP(s)==5,'Continued defended village uses the actual advanced free-play spawn denominator')
 s.mode='infinite';s.wave=4
 V.assert(Pixel.enemyMaxHP(s)==5,'Infinite fourth wave displays its real five hit points')
 s.wave=6
 V.assert(Pixel.enemyMaxHP(s)==6,'Later infinite wave health scale follows actual spawn growth')
 V.finish()
end)
