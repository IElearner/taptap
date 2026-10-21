-- Typed recipes and shelves shared by old and expanded industries. Inputs are
-- consumed atomically at batch completion; every output awaits a real carrier.
local D=require 'game.Definitions'
local E={}
function E.resourceAvailable(sim,b)
    if b.kind=='quarry' then return sim.rock>0 end
    local resource=D.buildings[b.kind].deposit
    return not resource or require('game.Deposits').stock(sim,b,resource)>0
end
function E.capacity(b)
    if b.kind=='ranch' then return 2 end
    return D.buildings[b.kind].capacity or 8
end
function E.inputCapacity(b)return D.buildings[b.kind].inputCapacity or 4 end
function E.allowed(b,resource)
    local def=D.buildings[b.kind]
    if def.recipes then
        for _,r in ipairs(def.recipes)do if r.inputs[resource] then return true end end
        return false
    end
    if def.input==resource or def.alternateInput==resource then return true end
    for _,r in ipairs(def.extraInputs or {})do if r==resource then return true end end
    return b.kind=='kitchen' and resource=='flour'
end
function E.recipe(b)
    if b.kind=='mill' then return D.millRecipes[b.recipeVersion or 2] end
    local def=D.buildings[b.kind]
    return def.recipes and def.recipes[b.processingRecipe or b.recipe or 0]
end
function E.wants(b,resource)
    local def=D.buildings[b.kind]
    if b.inputs>=E.inputCapacity(b) then return false end
    local recipe=E.recipe(b)
    if def.recipes and not recipe then return false end
    if b.queuedRecipe~=nil and not b.processingRecipe then return false end
    if recipe then return recipe.inputs[resource]~=nil and (b.inputGoods[resource] or 0)<recipe.inputs[resource]*2 end
    return E.allowed(b,resource) and not (b.kind=='kitchen' and resource=='flour')
end
function E.deliverySpace(b,resource)
    local space=E.inputCapacity(b)-b.inputs
    local recipe=E.recipe(b)
    if recipe then space=math.min(space,math.max(0,(recipe.inputs[resource] or 0)*2-(b.inputGoods[resource] or 0))) end
    return math.max(0,space)
end
function E.hasInputs(b)
    local recipe=E.recipe(b)
    if D.buildings[b.kind].recipes and not recipe then return false end
    if recipe then
        for r,n in pairs(recipe.inputs)do if (b.inputGoods[r] or 0)<n then return false end end
        return true
    end
    return not D.buildings[b.kind].input or b.inputs>0
end
function E.request(b)
    local recipe=E.recipe(b)
    if recipe then
        for _,resource in ipairs(D.goods)do
            local need=recipe.inputs[resource]
            if need and (b.inputGoods[resource] or 0)<need then return resource end
        end
    end
end
function E.period(b)return E.recipe(b) and E.recipe(b).period or D.buildings[b.kind].period end
function E.outputs(b)
    local def=D.buildings[b.kind]
    local recipe=E.recipe(b)
    return recipe and recipe.outputs or def.outputs or (def.output and {[def.output]=def.amount} or {})
end
function E.batchSize(b)local n=0;for _,v in pairs(E.outputs(b))do n=n+v end;return n end
function E.canProduce(b)return b.buffer+(b.lifeOutputHeld or 0)+(b.workOutputHeld or 0)<=E.capacity(b)-E.batchSize(b) end
function E.normalizeOutputs(b)
    if not b.outputGoods then b.outputGoods={} end
    local total=0;for _,n in pairs(b.outputGoods)do total=total+n end
    local resource=b.legacyOutput or D.buildings[b.kind].output
    if resource and total<b.buffer then b.outputGoods[resource]=(b.outputGoods[resource] or 0)+b.buffer-total end
end
function E.outputResource(b)
    E.normalizeOutputs(b)
    local main=b.legacyOutput or D.buildings[b.kind].output
    if main and (b.outputGoods[main] or 0)>0 then return main end
    for _,r in ipairs(D.goods)do if (b.outputGoods[r] or 0)>0 then return r end end
    return main
end
function E.isProduct(b,resource)
    local def=D.buildings[b.kind]
    if resource==(b.legacyOutput or def.output) then return true end
    if def.outputs and def.outputs[resource] then return true end
    for _,recipe in ipairs(def.recipes or {})do if recipe.outputs[resource] then return true end end
    return false
end
function E.outputAmount(b,resource)
    E.normalizeOutputs(b)
    return b.outputGoods[resource] or 0
end
function E.add(b,resource,amount)
    E.normalizeOutputs(b)
    b.outputGoods[resource]=(b.outputGoods[resource] or 0)+amount
    b.buffer=b.buffer+amount
end
function E.take(b,resource,amount)
    E.normalizeOutputs(b)
    assert((b.outputGoods[resource] or 0)+.000001>=amount,'Carrier cannot pick up missing shelf goods')
    b.outputGoods[resource]=math.max(0,(b.outputGoods[resource] or 0)-amount)
    b.buffer=math.max(0,b.buffer-amount)
end
function E.consume(b,resource)
    local recipe=E.recipe(b)
    if recipe then
        assert(E.hasInputs(b),'A recipe cannot consume incomplete ingredients')
        for r,n in pairs(recipe.inputs)do b.inputGoods[r]=b.inputGoods[r]-n;b.inputs=b.inputs-n end
        b.processingRecipe=nil
    else
        b.inputGoods[resource]=math.max(0,(b.inputGoods[resource] or 0)-1)
        b.inputs=math.max(0,b.inputs-1)
    end
    b.processingResource=nil
end
local function selectRecipe(b,index)
    local recipes=D.buildings[b.kind].recipes
    local inputs=index>0 and recipes[index].inputs or {}
    local returning=0
    for resource,amount in pairs(b.inputGoods or {})do if not inputs[resource] then returning=returning+amount end end
    if returning>E.capacity(b)-b.buffer-(b.workOutputHeld or 0)-(b.lifeOutputHeld or 0)+.000001 then return false end
    for resource,amount in pairs(b.inputGoods or {})do
        if amount>0 and not inputs[resource] then
            b.inputGoods[resource]=0;b.inputs=b.inputs-amount;E.add(b,resource,amount)
        end
    end
    b.recipe,b.queuedRecipe=index,nil
    return true
end
function E.applyQueued(b)
    if b.queuedRecipe~=nil and not b.processingRecipe and b.timer==0 and (b.workOutputHeld or 0)==0 and not b.incoming then selectRecipe(b,b.queuedRecipe) end
end
function E.canWork(b)
    local def=D.buildings[b.kind]
    return not b.stopped and (not def.recipes or E.recipe(b) and (b.processingRecipe~=nil or b.queuedRecipe==nil))
end
function E.setRecipe(b,index)
    local recipes=D.buildings[b.kind].recipes
    if not recipes or type(index)~='number' or index%1~=0 or index<0 or index>#recipes then return false,'没有这项配方。' end
    if b.timer>0 or b.processingRecipe or b.incoming or(b.workOutputHeld or 0)>0 then
        b.queuedRecipe=index
        return true,index==0 and '本批结束、在途原料收妥后停单，余料由搬运工退仓。' or ('本批结束后改排'..recipes[index].name..'。')
    end
    if not selectRecipe(b,index) then b.queuedRecipe=index;return true,'已登记改单，等待成品架腾出退料空间。' end
    return true,index==0 and '订单已取消，余料将由搬运工退仓。' or ('已选择'..recipes[index].name..'，按订单取料。')
end
return E
