-- Expanded industrial controls are isolated from the retained mentor/menu HUD.
local UI=require 'urhox-libs/UI'
local Skin=require 'game.Skin'
local D=require 'game.Definitions'
local E=require 'game.Economy'
local P=require 'game.Deposits'
local F=require 'game.Forestry'
local I={}
local function goodsText(goods)
    local text={}
    for _,r in ipairs(D.goods)do if (goods[r] or 0)>0 then text[#text+1]=D.names[r]..' '..goods[r] end end
    return #text>0 and table.concat(text,' / ') or '无'
end
function I.create(sim,selection)
    local detail=Skin.label('',12,Skin.gold,'industryDetails');detail:SetStyle{width='100%',whiteSpace='normal'}
    local order=Skin.button('',function()
        local b=selection();if not b then return end
        local recipes=D.buildings[b.kind].recipes
        local next=((b.queuedRecipe or b.recipe or 0)%#recipes)+1
        local _,message=sim:setRecipe(b,next);sim:notify(message)
    end,{id='cycleRecipe'})
    local cancel=Skin.button('取消订单 · 余料退仓',function()
        local b=selection();if b then local _,message=sim:setRecipe(b,0);sim:notify(message)end
    end,{id='cancelRecipe'})
    local stop=Skin.button('',function()
        local b=selection();if b then local _,message=sim:setWorking(b,b.stopped==true);sim:notify(message)end
    end,{id='toggleProduction'})
    local root=UI.Panel{gap=8,children={detail,order,cancel,stop}}
    local function update(b)
        local def=b and D.buildings[b.kind]
        local lines={}
        if b and def.recipes then
            local recipe=E.recipe(b)
            if recipe then
                lines[#lines+1]='当前订单：'..recipe.name..' · '..math.floor(b.timer/recipe.period*100)..'%'
                lines[#lines+1]=goodsText(recipe.inputs)..' → '..goodsText(recipe.outputs)..' / '..recipe.period..'秒'
            else lines[#lines+1]='尚未排单 · 选择配方后才会取料开工' end
            if b.queuedRecipe~=nil then lines[#lines+1]=b.queuedRecipe==0 and '待停单 · 本批完成后，等货架腾空退料' or ('待改单：'..def.recipes[b.queuedRecipe].name) end
            local next=((b.queuedRecipe or b.recipe or 0)%#def.recipes)+1
            order:SetText('排单：'..def.recipes[next].name)
        end
        if b and def.deposit then lines[#lines+1]=(def.deposit=='fish' and '共享鱼群余量 ' or '共享矿脉余量 ')..P.stock(sim,b,def.deposit) end
        if b and b.kind=='quarry' then lines[#lines+1]='本区原石余量 '..sim.rock..' · 原石须经石作坊加工' end
        if b and b.kind=='forester' then
            lines[#lines+1]='范围内待恢复树格 '..F.count(sim,b)..' · 已成熟再生 '..(sim.regrownTrees or 0)
            lines[#lines+1]='自然：桩180秒 + 幼苗540秒；实际到场照料时×2'
        end
        if b and b.outputGoods then lines[#lines+1]='成品/退料货架：'..goodsText(b.outputGoods) end
        if b and def.input then lines[#lines+1]='已到原料：'..goodsText(b.inputGoods or {}) end
        detail:SetText(table.concat(lines,'\n'))
        local ready=b and b.complete
        order:SetVisible(ready and def.recipes~=nil);cancel:SetVisible(ready and def.recipes~=nil)
        stop:SetVisible(ready and (def.output~=nil or def.service~=nil))
        stop:SetText(b and b.stopped and '恢复生产 / 护林' or '暂停生产 / 护林')
    end
    return{root=root,update=update}
end
return I
