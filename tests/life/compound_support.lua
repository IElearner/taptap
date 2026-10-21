-- Independent controlled-material geometry scaffold. Never assigns site/phase/load.
local f=File('tests/life/support.lua',FILE_READ)
local H=assert(load(f:ReadString(),'@tests/life/support.lua'))();f:Close()
local C={H=H,Sim=require 'game.Simulation',Layout=require 'game.PixelLayout'}
C.kinds={'fishery','quarry','ironmine','coalmine','goldmine','mason','woodcutter','mill','bakery','butcher','sawmill','smelter','tannery','woodweapons','leatherarmor','ironweapons','ironarmor'}
function C.copy(t)return cjson.decode(cjson.encode(t))end
function C.same(a,b,field)
 if type(a)~=type(b)then return false end
 -- JSON's decimal roundtrip can differ by <1 ulp (registered door thirds).
 -- This tolerance is <1e-7 screen pixel; integer cells/IDs remain exact in use.
 if type(a)=='number'then
  local continuous=field=='x'or field=='y'
  return continuous and math.abs(a-b)<=1e-9 or a==b
 end
 if type(a)~='table'then return a==b end
 for k,v in pairs(a)do if not C.same(v,b[k],k)then return false end end
 for k in pairs(b)do if a[k]==nil then return false end end
 return true
end
function C.diff(a,b,path)
 path=path or '$'
 if type(a)~=type(b)then return path..' type '..type(a)..'/'..type(b)end
 if type(a)~='table'then
  if a~=b then return path..' '..(type(a)=='number'and string.format('%.17g / %.17g delta %.17g',a,b,a-b)or tostring(a)..' / '..tostring(b))end
  return
 end
 for k,v in pairs(a)do local d=C.diff(v,b[k],path..'.'..tostring(k));if d then return d end end
 for k in pairs(b)do if a[k]==nil then return path..'.'..tostring(k)..' added'end end
end
function C.key(x,y)return math.floor(x+.5)..':'..math.floor(y+.5)end
function C.new(seed)
 local s=C.Sim.new('finite',seed or 7319);s.started,s.skipped=true,true
 s.stock.wood,s.stock.stone,s.stock.food=100000,100000,500
 return s
end
function C.find(s,kind)
 local q={}
 local known={fishery={16,6},quarry={3,11},mill={6,3},woodcutter={6,3},ironmine={8,3},mason={6,3},house={6,3}}
 for y=2,s.map.worldSize or 30 do for x=2,s.map.worldSize or 30 do q[#q+1]={x=x,y=y,d=math.abs(x-10)+math.abs(y-8)}end end
 -- Developer-supplied candidate is merely tried first; every geometry and
 -- road feasibility check below still runs and can reject it.
 if s.map.seed==7319 and known[kind]then local p=known[kind];q[#q+1]={x=p[1],y=p[2],d=-1}end
 table.sort(q,function(a,b)if a.d~=b.d then return a.d<b.d end;if a.y~=b.y then return a.y<b.y end;return a.x<b.x end)
 for _,p in ipairs(q)do
  local ok,_,site=s:canBuild(kind,p.x,p.y)
  if ok then
   local blocked={};for _,v in ipairs(H.D.cells(kind))do blocked[C.key(p.x+v.x,p.y+v.y)]=true end
   for _,v in ipairs(site and site.yardCells or {})do blocked[C.key(v.x,v.y)]=true end
   if H.path(s,p.x,p.y+1,blocked)then return p,site end
  end
 end
 error('No legal reachable compound fixture for '..kind)
end
function C.add(s,kind)
 local p,planned=C.find(s,kind)
 local ok,why,b=s:build(kind,p.x,p.y);assert(ok,why)
 -- Completion and road work are declared geometry scaffolding, not earned work.
 b.complete,b.progress=true,1;H.connect(s,b)
 return b,planned
end
function C.points(site)
 local result={}
 for _,name in ipairs({'chairCell','tankCell','stackCell','workCell','storageCell','shoreCell'})do
  if site[name]then result[#result+1]={name=name,p=site[name]}end
 end
 for _,name in ipairs({'restCells','idleCells'})do for i,p in ipairs(site[name]or {})do result[#result+1]={name=name..i,p=p}end end
 return result
end
function C.write(path,value)local f=File(path,FILE_WRITE);f:WriteString(cjson.encode(value));f:Close()end
function C.runName(fallback)
 for _,v in ipairs(GetArguments())do local n=v:match('^-pixelqa%-run=([%w_-]+)$');if n then return n end end
 return fallback
end
return C
