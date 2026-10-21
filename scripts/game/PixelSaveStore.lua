-- Independent local and TapTap cloud slots. No automatic V12 import.
local Store=require 'game.SaveStore'
local Pixel={nativeBackend=Store.nativeBackend}
function Pixel.new(backend)
    return Store.new(backend,{namespace='shanheli_pixel_v1',schema='shanheli.pixel'})
end
return Pixel
