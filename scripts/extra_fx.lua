local fxs = {
    {
        name = "sand_puff_large_front",
        bank = "sand_puff",
        build = "sand_puff",
        anim = "forage_out",
        sound = "dontstarve/common/deathpoof",
        transform = Vector3(1.5, 1.5, 1.5),
        fn = function(inst)
            inst.AnimState:SetFinalOffset(2)
            inst.AnimState:Hide("back")
        end,
    },
    {
        name = "sand_puff_large_back",
        bank = "sand_puff",
        build = "sand_puff",
        anim = "forage_out",
        transform = Vector3(1.5, 1.5, 1.5),
        fn = function(inst)
            inst.AnimState:Hide("front")
        end,
    },
    {
        name = "sand_puff",
        bank = "sand_puff",
        build = "sand_puff",
        anim = "forage_out",
        sound = "dontstarve/common/deathpoof",
    },
}

local FxTable = require "fx"

for _, fx_data in pairs(fxs) do
    table.insert(FxTable, fx_data)
end
