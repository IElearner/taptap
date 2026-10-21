-- Synthetic schema9 serialization of genuinely reached legacy Life phases.
-- Not an archived player save: phase/load/reservation are produced by simulation.
local f=File('tests/life/support.lua',FILE_READ);local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local task=coroutine.create(function()
 for _,kind in ipairs({'fishery','ironmine','mason'})do
  local s,b=H.setup(kind);local id=b.id;local seen={}
  for i=1,9000 do
   H.step(s);local a=s.workers[id..':1'];local l=a and a.life
   local phase=l and l.phase
   if phase and not seen[phase]then
    seen[phase]=true;local before=H.goods(s,H.D.buildings[kind].output);local saved=H.Data.capture(s,1000,1,true);saved.version=9
    local z,why=H.Data.restore(cjson.decode(cjson.encode(saved)),'finite');V.assert(z~=nil,kind..' actual '..phase..' with schema9 tag migrates: '..tostring(why));assert(z,why)
    local la=z.workers[id..':1'].life
    V.assert(la.phase==phase and H.goods(z,H.D.buildings[kind].output)==before and H.holds(z,z.buildings[id]),kind..' legacy Life phase/held reservation survives without new stock or duplicate load')
    s=z;b=s.buildings[id]
   end
   if s.stock[H.D.buildings[kind].output]>=H.D.buildings[kind].amount then break end
  end
  V.assert(s.stock[H.D.buildings[kind].output]==H.D.buildings[kind].amount,kind..' schema9 phase migrations still complete the same one real batch')
 end
end)
for frame=8,500 do V.atFrame(frame,function()
 if coroutine.status(task)=='dead'then return end;local ok,e=coroutine.resume(task);if not ok then V.assert(false,'Actual schema9 Life phase: '..tostring(e));V.finish()elseif coroutine.status(task)=='dead'then V.finish()end
end)end
