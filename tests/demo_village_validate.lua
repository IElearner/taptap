local Game=require 'network.Standalone'
local Data=require 'game.SaveData'
local Demo=require 'game.DemoVillage'
local clock={now=1000}
local memory,writes={},0
local original,originalWood,atEntry
V.atFrame(6,function()
    local s=Demo.new()
    local occupied={}
    for _,b in ipairs(s.buildings) do
        for _,c in ipairs(require('game.Definitions').cells(b)) do
            local x,y=b.x+c.x,b.y+c.y;local k=x..':'..y
            V.assert(s:terrain(x,y)=='grass' and not s.roads[k] and not occupied[k],'Demo buildings reserve valid grass cells without road overlap')
            occupied[k]=true
        end
        V.assert(s:connected(b),'Every demo entrance connects to the warehouse')
    end
    V.assert(Data.restore(cjson.decode(cjson.encode(Data.capture(s,1000,1,true))),'finite')~=nil,'The demonstration uses a valid playable simulation')
    Game.UseStore(require('game.SaveStore').new({now=function() return clock.now end,
        read=function(k) return memory[k] end,write=function(k,v) memory[k]=v;writes=writes+1;return true end}))
end)
V.atFrame(9,function()
    local s,_,hud=Game.Inspect();hud.root:FindById('enterVillage').props.onClick();hud.update()
    original,originalWood=s,s.stock.wood
    hud.root:FindById('visitDemo').props.onClick()
    local demo,_,demoHud,info=Game.Inspect()
    V.assert(demo~=original and info.demo==true and demo:count('ranch')==1,'The system menu opens a populated independent demonstration')
    atEntry=writes
    demo.stock.wood=1234
    Game.Update(31)
    demoHud.root:FindById('saveGame').props.onClick()
    demoHud.root:FindById('toggleIdle').props.onClick()
    Game.Focus(false);clock.now=1300;Game.Focus(true);Game.Update(.1)
    V.assert(writes==atEntry,'Demo autosave, manual save, idle toggle and background resume never write over the real slot')
    demoHud.root:FindById('visitDemo').props.onClick()
    local restored,_,normalHud,normalInfo=Game.Inspect()
    V.assert(restored==original and restored.stock.wood==originalWood and not normalInfo.demo,'Leaving the demo restores the exact original village')
    normalHud.root:FindById('saveGame').props.onClick()
    V.assert(writes>atEntry,'Saving remains functional after returning to the real village')
end)
V.atFrame(25,function() V.finish() end)
