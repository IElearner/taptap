-- Pure observation of the immutable actual 35-entity state. No orders or grants.
local Data=require 'game.SaveData'
local E=require 'game.Economy'
local run='earned35-mill-trace'
for _,arg in ipairs(GetArguments())do run=arg:match('^-pixelqa%-run=([%w_-]+)$')or run end
local s,b,start,events={},nil,nil,{}
local seen,lastInputs,lastTimer={},nil,nil
local serialSingles=0
V.atFrame(8,function()
 local f=File('tests/v3/fixtures/earned_cad35_four_chefs_after30.json',FILE_READ);local raw=cjson.decode(f:ReadString());f:Close()
 s=Data.restore(raw,'finite');for _,v in ipairs(s.buildings)do if v.kind=='mill'then b=v;break end end
 start=s.elapsed;lastInputs=b.inputs;lastTimer=b.timer
 V.assert(b.recipeVersion~=1 and E.recipe(b).inputs.grain==2 and b.workers==2,'Actual earned village uses a two-grain modern mill with two assigned workers')
end)
local function observe()
 local jobs={};for _,j in ipairs(s.jobs)do if j.b==b and j.inbound and not j.service then jobs[#jobs+1]={job=j,location='queue'}end end
 for i,c in ipairs(s.carriers)do local j=c.job;if j and j.b==b and j.inbound and not j.service then jobs[#jobs+1]={job=j,location='carrier',carrier=i,x=c.x,y=c.y,index=c.index,path=#c.path,carrying=c.carrying}end end
 for _,row in ipairs(jobs)do
  local j=row.job
  if not seen[j]then
   seen[j]=true
   local event={kind='inbound',time=s.elapsed-start,amount=j.amount,resource=j.resource,inputs=b.inputs,grainStock=s.stock.grain,space=E.deliverySpace(b,'grain'),incoming=b.incoming,timer=b.timer,workRate=b.workRate,active=b.activeWorkers,location=row.location,carrier=row.carrier,x=row.x,y=row.y,index=row.index,path=row.path}
   events[#events+1]=event
   if j.amount==1 and #jobs==1 and b.inputs<2 and s.stock.grain>=4 and E.deliverySpace(b,'grain')>=2 then serialSingles=serialSingles+1 end
  end
 end
 if b.inputs~=lastInputs then events[#events+1]={kind='input-change',time=s.elapsed-start,before=lastInputs,after=b.inputs,timer=b.timer,grainStock=s.stock.grain,workRate=b.workRate,incoming=b.incoming};lastInputs=b.inputs end
 if b.timer==0 and lastTimer>0 then events[#events+1]={kind='batch-finished',time=s.elapsed-start,inputs=b.inputs,output=b.buffer}end
 lastTimer=b.timer
end
for frame=9,68 do V.atFrame(frame,function()
 for _=1,100 do observe();s:update(.1)end
end)end
V.atFrame(69,function()
 V.assert(serialSingles>=2,'Observed at least two single-grain serial warehouse tasks despite stock and space for a complete two-grain batch')
 local report={elapsed=s.elapsed-start,serialSingles=serialSingles,events=events,final={stock=s.stock.grain,inputs=b.inputGoods,timer=b.timer,buffer=b.buffer}}
 local f=File('tests/v3/evidence/'..run..'-trace.json',FILE_WRITE);f:WriteString(cjson.encode(report));f:Close()
 print('V3_REAL_MILL_INBOUND_TRACE',cjson.encode(report));V.finish()
end)
