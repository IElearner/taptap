-- Regression for the actual failure that made detailed textures look like
-- stripes: exported atlas UVs must remain diverse, finite and in bounds.
local Sample=require "game.ArtSampleManifest"
V.atFrame(8,function()
    for key,spec in pairs(Sample.models) do
        local model=cache:GetResource("Model",spec.model)
        V.assert(model~=nil,"Art sample mesh loads: " .. key)
        local vb=model:GetGeometry(0,0):GetVertexBuffer(0)
        local offset=vb:GetElementOffset(TYPE_VECTOR2,SEM_TEXCOORD,0)
        V.assert(offset<vb:GetVertexSize(),"Painted sample exposes a real UV channel: " .. key)
        V.assert(not vb:HasElement(SEM_OBJECTINDEX),"Art mesh does not use obsolete lightmap semantics as an object index")
        local data=vb:GetData();local unique,valid={},true
        for i=0,math.min(511,vb:GetVertexCount()-1) do
            data:Seek(i*vb:GetVertexSize()+offset)
            local uv=data:ReadVector2()
            valid=valid and uv.x==uv.x and uv.y==uv.y and uv.x>=-0.001 and uv.x<=1.001 and uv.y>=-0.001 and uv.y<=1.001
            unique[string.format("%.4f:%.4f",uv.x,uv.y)]=true
        end
        local count=0;for _ in pairs(unique) do count=count+1 end
        V.assert(valid and count>32,"Unique painted atlas survives model export: " .. key)
        for _,ref in ipairs(spec.materials) do
            local mat=cache:GetResource("Material",ref)
            local texture=mat and mat:GetTexture(TU_DIFFUSE)
            V.assert(texture~=nil,"Baked painted material has its real texture: " .. key)
        end
    end
end)
V.atFrame(12,function() V.finish() end)
