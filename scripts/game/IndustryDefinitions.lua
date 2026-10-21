-- The expanded production slice is data-driven; retained v1 recipes keep their
-- existing identity, timings and starting inventory.
return function(D)
    local goods={
        {'rawstone','原石'},{'ironore','铁矿石'},{'coal','煤'},{'goldore','金矿石'},
        {'iron','铁锭'},{'gold','金锭'},{'fish','鲜鱼'},{'hide','猪皮'},
        {'leather','皮革'},{'bow','弓'},{'leatherarmor','皮甲'},
        {'ironspear','铁长枪'},{'ironarmor','铁甲'},
    }
    D.expandedGoods={}
    for _,g in ipairs(goods) do D.expandedGoods[g[1]]=true; D.goods[#D.goods+1]=g[1];D.names[g[1]]=g[2] end
    local function recipe(name,inputs,outputs,period)return{name=name,inputs=inputs,outputs=outputs,period=period}end
    local rows={
        {'forester','护林场','护林人','forester',nil,nil,0,'照护六格内的原林地树桩与幼苗。树桩180秒、幼苗540秒自然再生；护林人到场浇护时成长速度翻倍。'},
        {'mason','石作坊','石匠','mason','rawstone','stone',60,'每60秒把2份原石凿成1份可营造石料。'},
        {'ironmine','铁矿','矿工','miner',nil,'ironore',60,'新址须依着实际铁矿脉边缘营造并留出入洞通路。每60秒产2份铁矿石，同一矿脉储量共享，采尽需另寻矿脉。'},
        {'coalmine','煤矿','矿工','miner',nil,'coal',60,'新址须依着实际煤脉边缘营造并留出入洞通路。每60秒产2份煤，冶炼和铁器都需要煤。'},
        {'goldmine','金矿','矿工','miner',nil,'goldore',60,'新址须依着实际金矿脉边缘营造并留出入洞通路。每60秒产1份金矿石，冶炼成金锭后用于征募正规兵。'},
        {'smelter','冶炼坊','冶炼工','smith','ironore','iron',60,'选择冶铁或冶金配方：每批只消耗对应矿石1份和煤1份，产出对应金属1锭。'},
        {'fishery','渔场','渔夫','fisher',nil,'fish',60,'新址须贴可达干岸，前院与岸边作业点连成栈台。每60秒捕2鱼，送到食堂供餐；河道渔场共享有限鱼群，采尽需另寻水域。'},
        {'tannery','皮革坊','革匠','leatherworker','hide','leather',60,'每60秒将2张猪皮制成1张皮革。猪皮在真实屠宰时产生，送皮甲坊制甲。'},
        {'woodweapons','木作坊','木匠','carpenter','wood','bow',60,'每60秒用2份木料制成1张弓；弓和皮甲由义仓统一发给弓手。'},
        {'leatherarmor','皮甲坊','革匠','leatherworker','leather','leatherarmor',60,'每60秒用1张皮革与1份木料缝成1件皮甲，真实装备一名弓手。'},
        {'ironweapons','铁器坊','铁匠','smith','iron','ironspear',90,'每90秒用1铁锭、1煤锻成1柄铁长枪，配铁甲征募长枪兵。'},
        {'ironarmor','铁甲坊','甲匠','smith','iron','ironarmor',90,'每90秒用1铁锭、1煤制成1件铁甲，正规兵的装备由搬运工真实运入义仓。'},
    }
    for _,r in ipairs(rows) do
        local kind,name,job,profession,input,output,period,description=r[1],r[2],r[3],r[4],r[5],r[6],r[7],r[8]
        local def={name=name,cost={wood=10,stone=6},workers=1,footprint={3,3},
            input=input,output=output,period=period,amount=1,capacity=28,inputCapacity=12,
            profession=profession,expanded=true,color={133,105,70},description=description}
        if kind=='forester' then def.service='forestry';def.capacity=0;def.maxWorkers=1 end
        if kind=='smelter' then def.footprint={4,3};def.cost={wood=14,stone=10};def.capacity=32 end
        if kind=='ironmine' or kind=='coalmine' or kind=='goldmine' then def.capacity=20;def.deposit=output end
        if kind=='ironmine' or kind=='coalmine' or kind=='fishery' then def.amount=2 end
        if kind=='fishery' then def.deposit='fish';def.capacity=24;def.footprint={3,2};def.cost={wood=6,stone=3} end
        D.buildings[kind],D.jobs[kind]=def,job
        D.order[#D.order+1]=kind
    end
    D.buildings.mason.recipes={recipe('凿制石料',{rawstone=2},{stone=1},60)}
    D.buildings.smelter.recipes={recipe('冶铁',{ironore=1,coal=1},{iron=1},60),recipe('冶金',{goldore=1,coal=1},{gold=1},60)}
    D.buildings.tannery.recipes={recipe('鞣制皮革',{hide=2},{leather=1},60)}
    D.buildings.woodweapons.recipes={recipe('制弓',{wood=2},{bow=1},60)}
    D.buildings.leatherarmor.recipes={recipe('缝制皮甲',{leather=1,wood=1},{leatherarmor=1},60)}
    D.buildings.ironweapons.recipes={recipe('锻造长枪',{iron=1,coal=1},{ironspear=1},90)}
    D.buildings.ironarmor.recipes={recipe('打造铁甲',{iron=1,coal=1},{ironarmor=1},90)}
    D.millRecipes={
        {name='旧磨坊续用',inputs={grain=1},outputs={flour=2},period=6},
        {name='磨制面粉',inputs={grain=2},outputs={flour=2},period=90},
    }
    D.buildings.mill.period=90
    D.buildings.mill.description='每90秒将2袋麦粒磨成2袋面粉，送饼坊烘饼；旧存档磨坊按每栋保存的原配方续用。'
    D.buildings.woodcutter.description='新址依着森林边缘并接路，院口须能走到实际树木；樵夫每树背回1原木，交棚旁木架。砍后原树格180秒留桩、540秒长苗后再生；护林工实际照料可加速。'
    D.buildings.woodcutter.profession='forester'
    D.buildings.sawmill.profession='carpenter'
    D.buildings.quarry.profession='miner'
    D.buildings.quarry.output,D.buildings.quarry.amount,D.buildings.quarry.period='rawstone',2,60
    D.buildings.quarry.description='新址须依着可见岩露边缘营造，留出入洞通路；每60秒开采2份原石，送石作坊凿成建筑用石料；本区原石储量有限，拓荒发现新储量。'
    D.buildings.butcher.outputs={meat=3,hide=1}
    D.buildings.butcher.description='1头牲畜加工为3份鲜肉，附产1张真实猪皮；鲜肉供餐，猪皮送皮革坊。不追溯赠送旧屠宰产物。'
    D.buildings.kitchen.extraInputs={'fish'}
    D.lessons[1].lines[3]='道路不扣木石；空闲村民到场花时间铺好后，才可运输。'
    D.lessons[8].lines[3]='每原木锯2木/60秒；先备军营三兵18木，扩建再增第二锯木坊/岗位，可开2倍速度。'
    D.lessons[9].lines[3]='军营12木，三兵再需6木6粮和3待命村民；木不足就继续锯木。'
    D.lessons[10].kind='defended'
    D.lessons[10].lines={'首场守村是序章，先守护刚建好的粮道。','备齐三名乡勇，在军务里点开始守村。','首防成功后继续护林、矿冶与装备产业篇，村庄不会停止经营。'}
    D.lessons[10].complete='首场守村已成。村庄继续经营，接着建立林业、矿冶与正规兵。'
    local chapters={
        {'十一 · 林木长青','建护林场，先让附近樵夫砍一棵成熟树。','原树格180秒树桩变幼苗，再长540秒后成熟。','实际到场照料满5秒；照料时成长×2，不赠树木或原木。','industryForest'},
        {'十二 · 石料与驿运','采石出原石；石作坊选单，2原石→1切石/60秒，用于建造。','建筑蓝图先扣全栋费用；工地分批搬运不重复扣。','建驿站自动配置1搬运员，等他实际交货一趟。','industryStone'},
        {'十三 · 寻矿开采','沿地图实际矿脉边缘，选合法预览各建铁、煤、金矿。','铁矿和煤矿每60秒出2份；金矿出1份。','三种矿石都须实际交付，矿脉余量共享且有限。','industryMines'},
        {'十四 · 炉火炼金','冶炼坊需矿石和煤，先选冶铁订单。','1铁矿石+1煤→1铁；改排冶金，再用1金矿石+1煤→1金。','本批结束后才改单；等铁锭、金锭真实出炉交付。','industryMetals'},
        {'十五 · 河鲜入席','靠近水域建渔场，渔夫每60秒捕2鱼。','食堂可选面饼、鲜肉或鲜鱼，每份只用一种。','让鲜鱼真正送进食堂并煮成口粮；河道鱼量有限。','industryFish'},
        {'十六 · 猪皮成革','牧场吃麦，累计105秒有料成长后出栏。','屠宰1牲畜得3鲜肉和1猪皮；两猪皮才能制1皮革。','皮革坊选鞣制订单，等真实皮革交付；喂料约3麦/猪。','industryLeather'},
        {'十七 · 制弓缝甲','木作坊选制弓：2木料→1弓，每60秒一批。','皮甲坊选缝制：1皮革+1木料→1皮甲。','两件装备都要由搬运工真正交付，随后到军务征募。','industryWoodArms'},
        {'十八 · 铁枪铁甲','分别建铁器坊、铁甲坊，明确选择订单。','每栋每90秒消耗1铁锭+1煤，产铁长枪或铁甲。','缺任何一项都不开批，等两件装备真正交付。','industryIronArms'},
        {'十九 · 正规兵列队','军务中征募1弓手与1长枪兵。','每人用对应武器、护甲、1金锭、2口粮和1待命居民。','先备足两套装备和2金锭；领装后保留真实兵种身份。','industryArmy'},
        {'二十 · 山河共守','二十四类可建楼都已建成，各工业任务实作完成。','让弓手和长枪兵归队，再从军务开启终章守村。','击退6名耐力5的来敌后完成战役；胜后可继续经营。','campaignVictory'},
    }
    for _,r in ipairs(chapters)do D.lessons[#D.lessons+1]={title=r[1],lines={r[2],r[3],r[4]},complete='这一环已真实运转，继续发展清溪里。',kind=r[5],target=1}end
    D.lessons[20].infiniteLines={'工业目标、二十四类可建楼与弓枪正规兵都已就绪。','第4波或更后的增强来袭，开战时弓枪必须归队；第4波为7敌×5耐力。','本波守胜且两兵存活即记产业里程碑；后续来袭不停，村庄继续经营。'}
    D.modes.finite.description='30×30河谷 / 二十课产业战役 / 胜后继续经营'
end
