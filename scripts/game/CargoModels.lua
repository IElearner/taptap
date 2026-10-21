-- Load separately authored UV-textured 3D cargo meshes. The same nodes attach
-- to both worker looks and to the existing carrying/unloading motion rig.
local M={}
function M.add(world,load,existing,mesh)
    for _,key in ipairs({"planks","stoneSack","sacks","flourSack","meatBasket","foodBasket","coinChest"}) do
        existing[key]=mesh(world,load,key,"cargo_" .. key)
    end
    existing.pigCrate=mesh(world,load,"PigCrate","pig_crate")
    existing.logBundle=mesh(world,load,"LogBundle","log_bundle")
    return existing
end
return M
