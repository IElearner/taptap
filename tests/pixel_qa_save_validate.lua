-- Independent recovery boundaries for the pixel namespace, all in memory.
local Sim=require 'game.Simulation'
local Pixel=require 'game.PixelSaveStore'
local Data=require 'game.SaveData'
V.atFrame(8,function()
    local files,reads,writes,cloudWrites={},{},{},{}
    local legacy=cjson.encode(Data.capture(Sim.new('finite'),900,9,true))
    files['shanheli_save_v1_finite.json']=legacy
    files['shanheli_save_v1_finite.json.bak']=legacy
    local backend={now=function() return 1000 end,
        read=function(k) reads[#reads+1]=k;return files[k] end,
        write=function(k,v) writes[#writes+1]=k;files[k]=v;return true end}
    local sim=Sim.new('finite');sim.stock.wood=71
    local writer=Pixel.new(backend)
    writer:save(sim,true)
    local valid=files['shanheli_pixel_v1_finite.json']
    files['shanheli_pixel_v1_finite.json.bak']=valid
    files['shanheli_pixel_v1_finite.json']='{interrupted write'
    local recovered
    local reader=Pixel.new(backend)
    reader:load('finite',function(value) recovered=value end)
    V.assert(recovered and Data.restore(recovered,'finite').stock.wood==71,'A truncated pixel main file recovers the valid pixel backup')
    backend.cloudGet=function(k,callback) callback(true,legacy);return true end
    backend.cloudSet=function(k,v,callback) cloudWrites[#cloudWrites+1]={key=k,value=v};callback(true);return true end
    local online=Pixel.new(backend)
    online:load('finite',function(value) recovered=value end)
    V.assert(recovered and recovered.application=='shanheli.pixel','An old-format cloud bundle cannot replace a valid pixel backup')
    sim.stock.wood=72
    V.assert(online:save(sim,true),'Invalid remote data does not prevent a valid local pixel save')
    V.assert(#cloudWrites==0,'Unrecognized cloud data remains protected from automatic overwrite')
    V.assert(files['shanheli_pixel_v1_finite.json.bak']==valid,'Saving after corrupt-main recovery preserves the last good pixel backup')
    local future=cjson.decode(valid);future.saveSchema=2
    V.assert(not online:decode(cjson.encode(future),'finite'),'Unknown future pixel schema is rejected without reinterpretation')
    V.assert(not online:decode(valid,'infinite'),'A finite pixel bundle is not loaded into infinite mode')
    files['shanheli_pixel_v1_infinite.json']=legacy
    files['shanheli_pixel_v1_infinite.json.bak']=legacy
    local infinite='waiting'
    Pixel.new(backend):load('infinite',function(value) infinite=value end)
    V.assert(infinite==nil,'Wrong-schema main, backup, and cloud together produce a fresh pixel slot')
    local isolated=true
    local prefix='shanheli_pixel_v1_'
    for _,key in ipairs(reads) do if key:sub(1,#prefix)~=prefix then isolated=false end end
    for _,key in ipairs(writes) do if key:sub(1,#prefix)~=prefix then isolated=false end end
    V.assert(isolated,'Recovery and save operations never even read a legacy local key')
    V.assert(files['shanheli_save_v1_finite.json']==legacy and files['shanheli_save_v1_finite.json.bak']==legacy,'Legacy primary and backup remain byte-for-byte untouched')
end)
V.atFrame(25,function() V.finish() end)
