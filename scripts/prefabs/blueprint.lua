require "recipes"

local assets =
{
    Asset("ANIM", "anim/blueprint.zip"),
}

local function onload(inst, data)
    if data and data.recipetouse then
        inst.recipetouse = data.recipetouse
        inst.components.teacher:SetRecipe(inst.recipetouse)
        inst.components.named:SetName((STRINGS.NAMES[string.upper(inst.recipetouse)] or STRINGS.NAMES.UNKNOWN).." "..STRINGS.NAMES.BLUEPRINT)
    end
end

local function onsave(inst, data)
    if inst.recipetouse then
		data.recipetouse = inst.recipetouse
	end
end

local function GetValidRecipe(recname)
    local rec = GetRecipe(recname)
    return rec ~= nil and rec or nil
end

local function IsRecipeValid(recname)
    return GetValidRecipe(recname) ~= nil
end

local function OnTeach(inst, learner)
    if learner.SoundEmitter then
		learner.SoundEmitter:PlaySound("dontstarve/HUD/get_gold")    
	end
end

local function CanBlueprintRandomRecipe(recipe)
    if recipe.nounlock or recipe.builder_tag ~= nil then
        --Exclude crafting station and character specific
        return false
    end
    local hastech = false
    for k, v in pairs(recipe.level) do
        if v >= 10 then
            --Exclude TECH.LOST
            return false
        elseif v > 0 then
            hastech = true
        end
    end
    --Exclude TECH.NONE
    return hastech
end

local function CanBlueprintSpecificRecipe(recipe)
    --Exclude crafting station and character specific
    if recipe.nounlock or recipe.builder_tag ~= nil then
        return false
    end
    for k, v in pairs(recipe.level) do
        if v > 0 then
            return true
        end
    end
    --Exclude TECH.NONE
    return false
end

local function fn()
    local inst = CreateEntity()
	inst.entity:AddTransform()
    MakeInventoryPhysics(inst)
	inst.entity:AddAnimState()
    inst.AnimState:SetBank("blueprint")
	inst.AnimState:SetBuild("blueprint")
	inst.AnimState:PlayAnimation("idle")

    if IsDLCEnabled(2) or IsDLCEnabled(3) then
	    MakeInventoryFloatable(inst, "idle_water", "idle")
    end

    inst:AddComponent("inspectable")
    inst.components.inspectable.nameoverride = "blueprint"
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:ChangeImageName("blueprint")
    inst:AddComponent("named")
    inst:AddComponent("teacher")
    inst.components.teacher.onteach = OnTeach

    MakeSmallBurnable(inst, TUNING.SMALL_BURNTIME)
    MakeSmallPropagator(inst)

    inst.OnLoad = onload
    inst.OnSave = onsave

   	return inst
end

local function MakeAnyBlueprint()
    local inst = fn()

    local unknownrecipes = {}
    local knownrecipes = {}
    for k, v in pairs(GetAllRecipes()) do
        if IsRecipeValid(v.name) and CanBlueprintRandomRecipe(v) then
            local known = GetPlayer().components.builder:KnowsRecipe(v) and v.tab and not v.tab.isReno and not v:is_a(RecipeCategory)
    
            table.insert(known and knownrecipes or unknownrecipes, v)
        end
    end

    inst.recipetouse =
        (#unknownrecipes > 0 and unknownrecipes[math.random(#unknownrecipes)].name) or
        (#knownrecipes > 0 and knownrecipes[math.random(#knownrecipes)].name) or
        "unknown"

    inst.components.teacher:SetRecipe(inst.recipetouse)
    inst.components.named:SetName(STRINGS.NAMES[string.upper(inst.recipetouse)].." "..STRINGS.NAMES.BLUEPRINT)
    return inst
end

local function MakeSpecificBlueprint(specific_item)
    return function()
        local inst = fn()

        local r = GetValidRecipe(specific_item)
        inst.recipetouse = r ~= nil and not r.nounlock and r.name or "unknown"
        inst.components.teacher:SetRecipe(inst.recipetouse)
        inst.components.named:SetName(STRINGS.NAMES[string.upper(inst.recipetouse)].." "..STRINGS.NAMES.BLUEPRINT)

        return inst
    end
end

local function MakeAnyBlueprintFromTab(recipetab)
    return function()
        local inst = fn()

        local unknownrecipes = {}
        local knownrecipes = {}
        for k, v in pairs(GetAllKnownRecipes()) do
            if IsRecipeValid(v.name) and v.tab == recipetab and CanBlueprintRandomRecipe(v) then
				local known = GetPlayer().components.builder:KnowsRecipe(v) and v.tab and not v.tab.isReno and not v:is_a(RecipeCategory)
    
				table.insert(known and knownrecipes or unknownrecipes, v)
            end
        end
        inst.recipetouse =
            (#unknownrecipes > 0 and unknownrecipes[math.random(#unknownrecipes)].name) or
            (#knownrecipes > 0 and knownrecipes[math.random(#knownrecipes)].name) or
            "unknown"
        inst.components.teacher:SetRecipe(inst.recipetouse)
        inst.components.named:SetName(STRINGS.NAMES[string.upper(inst.recipetouse)].." "..STRINGS.NAMES.BLUEPRINT)
        return inst
    end
end

local prefabs = {}

table.insert(prefabs, Prefab("common/inventory/blueprint", MakeAnyBlueprint, assets))
for k, v in pairs(RECIPETABS) do
    if not v.crafting_station then
        table.insert(prefabs, Prefab(string.lower(v.str or "NONAME").."_blueprint", MakeAnyBlueprintFromTab(v), assets))
    end
end
for k, v in pairs(GetAllKnownRecipes()) do
    if CanBlueprintSpecificRecipe(v) then
        table.insert(prefabs, Prefab("common/inventory/"..string.lower(k or "NONAME").."_blueprint", MakeSpecificBlueprint(k), assets))
    end
end
CanBlueprintSpecificRecipe = nil --don't need this anymore
return unpack(prefabs)
