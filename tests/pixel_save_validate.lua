local Sim=require 'game.Simulation'
local Store=require 'game.PixelSaveStore'
local Legacy=require 'game.SaveStore'
local Data=require 'game.SaveData'
V.atFrame(8,function()
    local files,reads,writes={},{},{}
    local old=cjson.encode(Data.capture(Sim.new('finite'),100,1,true))
    files['shanheli_save_v1_finite.json']=old
    local backend={now=function() return 200 end,
        read=function(k) reads[#reads+1]=k;return files[k] end,
        write=function(k,v) writes[#writes+1]=k;files[k]=v;return true end}
    local pixel=Store.new(backend)
    local loaded='pending'
    pixel:load('finite',function(value) loaded=value end)
    V.assert(loaded==nil,'Pixel new game does not load the legacy game slot')
    V.assert(reads[1]=='shanheli_pixel_v1_finite.json','Pixel local slot has its own namespace')
    V.assert(not pixel:decode(old,'finite'),'Pixel schema explicitly rejects a legacy bundle even at a pixel key')
    local s=Sim.new('finite');s.stock.wood=123
    V.assert(pixel:save(s,true),'Pixel game saves through the mature store backend')
    local bundle=cjson.decode(files['shanheli_pixel_v1_finite.json'])
    V.assert(bundle.application=='shanheli.pixel' and bundle.saveSchema==1,'Pixel bundle carries its independent schema')
    local restored
    Store.new(backend):load('finite',function(value) restored=Data.restore(value,'finite') end)
    V.assert(restored and restored.stock.wood==123,'Pixel save survives a new store instance')
    V.assert(files['shanheli_save_v1_finite.json']==old,'Pixel save never overwrites the old game data')
    V.assert(Legacy.new(backend):decode(old,'finite')~=nil,'Legacy save compatibility remains available to the legacy implementation')
    local cloudReads,cloudWrites={},{}
    backend.cloudGet=function(k,callback) cloudReads[#cloudReads+1]=k;callback(true,nil);return true end
    backend.cloudSet=function(k,v,callback) cloudWrites[#cloudWrites+1]=k;callback(true);return true end
    local online=Store.new(backend);online:load('infinite',function() end);online:save(Sim.new('infinite'),true)
    V.assert(cloudReads[1]=='shanheli_pixel_v1_infinite' and cloudWrites[1]=='shanheli_pixel_v1_infinite','TapTap cloud reads and writes are isolated from legacy keys too')
end)
V.atFrame(25,function() V.finish() end)
