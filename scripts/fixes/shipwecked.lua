
-- Spice Pack will not be invisible when the player isn't Warly.
table.insert(Assets, Asset("ANIM", "anim/swap_chefpack.zip"))

------------------------------------------------------------------------------------

if GetConfig("recipe") then
    -- Learn non-unlockable recipes + Wicker Science 1
    AddComponentPostInit("builder", function (self)
        local _oldMakeRecipe = self.MakeRecipe

        function self:MakeRecipe(recipe, pt, rot, onsuccess, modifydata)
            local makeRecipeSuccess = false
            if hasHAM then
                makeRecipeSuccess = _oldMakeRecipe(self, recipe, pt, rot, onsuccess, modifydata)
            else
                makeRecipeSuccess = _oldMakeRecipe(self, recipe, pt, rot, onsuccess)
            end

            if makeRecipeSuccess and not self.brainjellyhat then
                self:AddRecipe(recipe.name)
            end

            return makeRecipeSuccess
        end
    end)
end

------------------------------------------------------------------------------------

-- Wilbore in water fix
AddPrefabPostInit("wildbore", function(inst)
    inst:DoPeriodicTask(TUNING.TOTAL_DAY_TIME, function(inst)
        if inst and inst.Transform and _G.GetWorld() and _G.GetWorld().Map then
            local pos = _G.Vector3(inst.Transform:GetWorldPosition())
            local tile = _G.GetWorld().Map:GetTileAtPoint(pos:Get())
            if _G.GetWorld().Map:IsWater(tile) then
                print("Finded a ".. inst.prefab .. " in the ocean! Removing him!")
                inst:Remove()
            end
        end
    end)
end)

------------------------------------------------------------------------------------

if GetConfig("shadowcreature") then
    -- Shadows water spawn fix
    AddStategraphPostInit("shadowcreature", function(self)
        self.states["hit"].events.animover.fn = function(inst)
            if _G.GetWorld().Map then
                local max_tries = 4
                for k = 1, max_tries do
                    local pos = _G.Vector3(inst.Transform:GetWorldPosition())
                    local offset = 10
                    pos.x = pos.x + (math.random(2*offset)-offset)          
                    pos.z = pos.z + (math.random(2*offset)-offset)
                    local tile = _G.GetWorld().Map:GetTileAtPoint(pos:Get())
                    if tile ~= GROUND.IMPASSABLE  and not _G.GetWorld().Map:IsWater(tile) and not _G.GetWorld().Map:IsShore(tile) then
                        inst.Transform:SetPosition(pos:Get())
                        break
                    end
                end
            end
            inst.sg:GoToState("appear")
        end
    end)
end

------------------------------------------------------------------------------------

if GetConfig("limpet") then
    -- Remove Limpet Rock from being targeted by Ice Flingomatic
    AddPrefabPostInit("limpetrock", function(inst)
        inst:AddTag("fire_proof")
    end)
end

------------------------------------------------------------------------------------
local COLLISION = _G.COLLISION

if GetConfig("bee") then
    local function FlyOverWater(inst)
        inst.components.inventoryitem.nosink = true
        inst:AddTag("amphibious")

        inst.Physics:SetCollisionGroup(COLLISION.FLYERS)
        inst.Physics:ClearCollisionMask()
        
        if hasHAM then
            _G.SetAquaticEntityCollision(inst)
            inst.Physics:CollidesWith(COLLISION.INTWALL)
        else
            inst.Physics:CollidesWith(COLLISION.GROUND)
        end

        if inst.prefab == "butterfly" then return end

        inst.Physics:CollidesWith(COLLISION.FLYERS)
    end

    -- Now can fly over water:
    AddPrefabPostInit("bee", FlyOverWater)
    AddPrefabPostInit("killerbee", FlyOverWater)
    AddPrefabPostInit("butterfly", FlyOverWater)
    AddPrefabPostInit("glowfly", FlyOverWater)
end

------------------------------------------------------------------------------------
-- Obsidian Equips load fix
local _oldMakeObsidianTool = _G.MakeObsidianTool
_G.MakeObsidianTool = function(inst, tooltype)
    _oldMakeObsidianTool(inst, tooltype)

    if inst.components.floatable then
        inst.components.floatable:SetOnHitWaterFn(function(inst)
            if _G.InGamePlay() then
                inst.SoundEmitter:PlaySound("dontstarve_DLC002/common/obsidian_wetsizzles")
                inst.components.obsidiantool:SetCharge(0)
            end
        end)
    end
end

------------------------------------------------------------------------------------

if GetConfig("trap") then
    local function AddTrapTag(inst)
        inst:AddTag("canbetrapped")
    end

    -- Trapapped animals
    AddPrefabPostInit("snake", AddTrapTag)
    AddPrefabPostInit("snake_poison", AddTrapTag)
    AddPrefabPostInit("flup", AddTrapTag)
    if hasHAM then AddPrefabPostInit("snake_amphibious", AddTrapTag) end

end

------------------------------------------------------------------------------------

if GetConfig("flup") then
    -- Fix Flup Respawn
    AddPrefabPostInit("flupspawner", function(inst)
        inst.components.areaspawner.spawntest = nil
    end)
end

------------------------------------------------------------------------------------
if GetConfig("butterfly") then
    local notags = {'NOBLOCK', 'player', 'FX'}
    local function test_ground(inst, pt)
        local tiletype = _G.GetGroundTypeAtPosition(pt)

        if tiletype > GROUND.UNDERGROUND then
            return false
        end

        if _G.GetWorld().Map:IsWater(tiletype) then 
            return false
        end
        
        local notiles = {
            GROUND.ROCKY, GROUND.ROAD,  GROUND.IMPASSABLE, GROUND.UNDERROCK,
            GROUND.WOODFLOOR, GROUND.MAGMAFIELD, GROUND.CARPET, GROUND.CHECKER,
            GROUND.ASH, GROUND.VOLCANO, GROUND.VOLCANO_ROCK
        }

        if hasHAM then
            table.insert(notiles, GROUND.INTERIOR)
            table.insert(notiles, GROUND.BRICK_GLOW)
        end
        
        for _, tile in ipairs(notiles) do
            if tiletype == tile then
                return false
            end
        end

        local ents = _G.TheSim:FindEntities(pt.x,pt.y,pt.z, 4, nil, notags)
        local min_spacing = inst.components.deployable.min_spacing or 2

        for k, v in pairs(ents) do
            if v ~= inst and v:IsValid() and v.entity:IsVisible() and not v.components.placer and v.parent == nil then
                if _G.distsq(_G.Vector3(v.Transform:GetWorldPosition()), pt) < min_spacing*min_spacing then
                    return false
                end
            end
        end   
        return true
    end

    -- Butterfly deploy test
    AddPrefabPostInit("butterfly", function(inst)
        inst.components.deployable.min_spacing = 0.5
        inst.components.deployable.test = test_ground
    end)
end

------------------------------------------------------------------------------------

AddStategraphPostInit("wilsonboating", function(self)
    local _onenter = self.states["use_fan"].onenter
    self.states["use_fan"].onenter = function(inst) -- Fix Doydoy Fan Texture on boat
        _onenter(inst)

        local fan = inst:GetBufferedAction().invobject
        if fan then
            inst.AnimState:OverrideSymbol("fan01", fan.animinfo, "fan01")
        end
    end

    self.states["use_fan"].timeline = -- Fix Fans missing sound on boat
        {
            _G.TimeEvent(26*_G.FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC002/common/luxury_fan", "fan") end),
            _G.TimeEvent(70*_G.FRAMES, function(inst) inst:PerformBufferedAction() end),
            _G.TimeEvent(90*_G.FRAMES, function(inst) inst.SoundEmitter:KillSound("fan") end),
        }
end)

------------------------------------------------------------------------------------

local function GetSpawnPoint(pt)
    local theta = math.random() * 2 * _G.PI
    local radius = 30

	local offset = _G.FindWalkableOffset(pt, theta, radius, 12, true)
	if offset then
		return pt+offset
	end
end

local function SpawnPackim(inst) -- Local function and I can't get with UpvalueHacker :(
    local pt = _G.Vector3(inst.Transform:GetWorldPosition())
    local spawn_pt = hasHAM and _G.GetSpawnPoint(inst, pt) or GetSpawnPoint(pt)

    if spawn_pt then
        local packim = _G.SpawnPrefab("packim")
        if packim then
            packim.Physics:Teleport(spawn_pt:Get())
            packim:FacePoint(pt.x, pt.y, pt.z)

            return packim
        end
    end
end

-- Packim's FishBone only lure and checks for Packim
AddPrefabPostInit("packim_fishbone", function(inst)
    inst:RemoveTag("chester_eyebone")
    local _RebindPackim = UpvalueHacker.GetUpvalue(inst.fixtask.fn, "FixPackim", "RebindPackim")

    local function RebindPackim(inst, packim)
        packim = packim or _G.TheSim:FindFirstEntityWithTag("packim")
        if packim then
            _RebindPackim(inst, packim)
        end
    end
    UpvalueHacker.SetUpvalue(inst.fixtask.fn, RebindPackim, "FixPackim", "RebindPackim")

    --------------------

    local StopRespawn = UpvalueHacker.GetUpvalue(inst.OnPackimDeath, "StartRespawn", "StopRespawn")

    local function RespawnPackim(inst)
        StopRespawn(inst)
    
        local packim = _G.TheSim:FindFirstEntityWithTag("packim")
        if not packim then
            packim = SpawnPackim(inst)
        end
        RebindPackim(inst, packim)
    end
    UpvalueHacker.SetUpvalue(inst.OnPackimDeath, RespawnPackim, "StartRespawn", "RespawnPackim")
end)

------------------------------------------------------------------------------------

-- Sword Fish will no longer chase its target forever.
AddPrefabPostInit("swordfish", function(inst)
    local CHASE_DIST = 40 -- From swordfishbrain.lua
    local _keepTarget = inst.components.combat.keeptargetfn

    inst.components.combat:SetKeepTargetFunction(
        function(inst, target)
            local shouldkeep = _keepTarget(inst, target)

            if shouldkeep then
                local home = inst.components.knownlocations:GetLocation("home")
                local isnearhome = inst:GetDistanceSqToPoint(home) <= CHASE_DIST*CHASE_DIST

                return isnearhome
            end

            return shouldkeep
        end
    )
end)

------------------------------------------------------------------------------------

local function CommonFishFix(inst)
    inst.components.floatable:UpdateAnimations(nil, "idle")
                                                                    -- (water, land) anims
    inst.OnLoad = function() inst.components.floatable:UpdateAnimations(nil, "dead") end

    inst.components.inventoryitem:SetOnPickupFn(
        function()
            if inst.components.floatable.landanim ~= "dead" then
                inst.components.floatable:UpdateAnimations(nil, "dead")
            end
        end
    )
end

-- Fixes fish dropped in land anim, which was causing an early dead anim.
AddPrefabPostInit("fish", CommonFishFix)
AddPrefabPostInit("tropical_fish", CommonFishFix)

-- Fixes missing dead anim and missing components for fish farm's fishes.
for _, n in ipairs({3,4,5}) do
    AddPrefabPostInit("fish"..n, function(inst)
        CommonFishFix(inst)

        inst:DoTaskInTime(1, function() inst.AnimState:PlayAnimation("dead") end) -- Only used in console spawn, but I'll left it here.

        _G.MakeBlowInHurricane(inst, TUNING.WINDBLOWN_SCALE_MIN.MEDIUM, TUNING.WINDBLOWN_SCALE_MAX.MEDIUM)
  
        inst:AddComponent("appeasement")
        inst.components.appeasement.appeasementvalue = TUNING.APPEASEMENT_TINY
    end)
end

------------------------------------------------------------------------------------

-- Fix made by Island's Adventure Mod Team <3
-- Sealnado will no longer ignore the player when they are close to him.
AddBrainPostInit("twisterbrain", function(brain)
    local inst = brain.inst
    for i, node in ipairs(brain.bt.root.children) do
        if node.children and node.children[1].name == "Attack Behaviours" then
            node.children[1].fn = function()
                return not inst.CanCharge or
                (
                    inst.components.combat.target and
                    inst.components.combat.target:GetPosition():Dist(inst:GetPosition()) < TUNING.TWISTER_ATTACK_RANGE
                )
            end
            break
        end
    end
end)

------------------------------------------------------------------------------------

-- Litle change to boat position to work properly with the bundling anim hack
AddComponentPostInit("driver", function(self)
    local _OnUpdate = self.OnUpdate
    function self:OnUpdate(dt)
        _OnUpdate(self, dt)
        if self.vehicle ~= nil and self.vehicle:IsValid() then 
            local CameraRight = _G.TheCamera:GetRightVec()
            local CameraDown = _G.TheCamera:GetDownVec()
            
            local myPos = self.inst:GetPosition()
            local displacement = CameraRight:Cross(CameraDown) * 0.05

            local pos = myPos - displacement

            self.vehicle.Transform:SetPosition(pos:Get())
        end
    end
end)

------------------------------------------------------------------------------------

AddStategraphActionHandler("wilsonboating", _G.ActionHandler(_G.ACTIONS.UNWRAP, "dolongaction"))
AddStategraphActionHandler("wilsonboating", _G.ActionHandler(_G.ACTIONS.BUNDLE, "bundle"))

local SGwilson = require("stategraphs/SGwilson")

-- Add the bundling states to boating + hacky to show the boat with the anim (bundling anim don't have boat symbol)
AddStategraphPostInit("wilsonboating", function(self)
    for i, state in ipairs({"bundle", "bundling", "bundle_pst"}) do
	    self.states[state] = SGwilson.states[state]
        table.insert(self.states[state].tags, "boating")

        if GetConfig("bundle_fx") then -- Don't need this for build anim
            local onenter = self.states[state].onenter
            local onexit = self.states[state].onexit

            self.states[state].onenter = function(inst, timeout)
                onenter(inst, timeout)
                local vehicle = inst.components.driver.vehicle
                if vehicle then
                    vehicle:Show()
                end
            end

            self.states[state].onexit = function(inst)
                onexit(inst)
                local vehicle = inst.components.driver.vehicle
                if vehicle then
                    vehicle:Hide()
                end
            end
        end
    end

    ------------------------------------------------------------------------------------

    -- Fix invisible boat on telebrella teleport
    local telebrella_state = self.states["telebrella"]

    local onenter_telebrella = telebrella_state.onenter

    telebrella_state.onenter = function(inst, timeout)
        onenter_telebrella(inst, timeout)
        local downvec = _G.TheCamera:GetDownVec()
        local facedown = -(math.atan2(downvec.z, downvec.x) * (180/math.pi))
        local vehicle = inst.components.driver.vehicle
        if vehicle then
            inst.components.driver.combined = false
            vehicle.Transform:SetRotation(facedown)
            vehicle:Show()
        end
    end

end)

------------------------------------------------------------------------------------

-- Fix made by skittles sour <3       Mod: https://steamcommunity.com/sharedfiles/filedetails/?id=2635513673
-- "Fix for the bug where you're still walking at the speed of your boat upon climbing the volcano."
AddPlayerPostInit(function(inst)
	inst:DoTaskInTime(0, function()
		if not _G.GetWorld():IsVolcano() then return end

		inst.components.locomotor:RemoveSpeedModifier_Additive("DRIVER")
	end)
end)

------------------------------------------------------------------------------------

-- Coconut being cutted in inventory by weather pain + ajust in work action
AddStategraphPostInit("tornado", function(self)
    local function destroystuff(inst)
        local x, y, z = inst.Transform:GetWorldPosition()
        local ents = _G.TheSim:FindEntities(x, y, z, 3, nil, {"INLIMBO"}) -- Inlimbo = in inventory
        for i, v in ipairs(ents) do
            if v ~= inst.WINDSTAFF_CASTER and v:IsValid() then
                if v.components.health ~= nil and
                    not v.components.health:IsDead() and
                    v.components.combat ~= nil then

                    v.components.combat:GetAttacked(inst, TUNING.TORNADO_DAMAGE)
                    if v:IsValid() and
                        inst.WINDSTAFF_CASTER ~= nil and inst.WINDSTAFF_CASTER:IsValid() and
                        v.components.combat ~= nil and
                        not (v.components.health ~= nil and v.components.health:IsDead()) and
                        not (v.components.follower ~= nil and
                            v.components.follower.keepleaderonattacked and
                            v.components.follower:GetLeader() == inst.WINDSTAFF_CASTER) then
                        v.components.combat:SuggestTarget(inst.WINDSTAFF_CASTER)
                    end
                elseif v.components.workable ~= nil and
                    v.components.workable.workleft > 0 then
                    _G.SpawnPrefab("collapse_small").Transform:SetPosition(v.Transform:GetWorldPosition())
                    v.components.workable:WorkedBy(inst, 2)
                end

                if v and v.components.hackable and v.components.hackable.hacksleft > 0 then
                    _G.SpawnPrefab("collapse_small").Transform:SetPosition(v:GetPosition():Get())
                    v.components.hackable:Hack(inst, 2)
        
                end
            end
        end
    end

    UpvalueHacker.SetUpvalue(self.states["idle"].onenter, destroystuff, "destroystuff")
    UpvalueHacker.SetUpvalue(self.states["walk"].onenter, destroystuff, "destroystuff")

    for i, state in pairs({"walk", "run_start", "run", "run_stop"}) do
        self.states[state].timeline =
        {
            _G.TimeEvent(5*_G.FRAMES, destroystuff),
        }
    end
end)

------------------------------------------------------------------------------------

local function FenceDeployFixes(inst)
    -- Fence/gate deploy distance like walls
    inst.components.deployable:SetQuantizeFunction(function(pt)
        return _G.Vector3(math.floor(pt.x)+.5, 0, math.floor(pt.z)+.5)
    end)

    inst.components.deployable.deploydistance = 1.5

    if hasHAM then return end

    -- Fix fence deploy on water in non-hamlet worlds.
    local _test = inst.components.deployable.test
    inst.components.deployable.test = function(inst, pt, deployer)
        local tile = _G.GetWorld().Map:GetTileAtPoint(pt.x,pt.y,pt.z)
        local onWater = _G.GetWorld().Map:IsWater(tile)
        
        return _test and not onWater
    end
end

AddPrefabPostInit("fence_item", FenceDeployFixes)
AddPrefabPostInit("fence_gate_item", FenceDeployFixes)

------------------------------------------------------------------------------------

-- Coconut TreeGuard stats scale with his size scale properly.
AddPrefabPostInit("treeguard", function(inst)
    local _SetRange = inst.SetRange
    local _SetMelee = inst.SetMelee

    
    inst.SetRange =  function(inst)
        if inst.combatmode == "RANGE" then return end
        
        _SetRange(inst)

        local scale = inst.Transform:GetScale()
        inst.components.combat:SetRange(20*scale, 25*scale)
    end

    inst.SetMelee = function(inst)
        if inst.combatmode == "MELEE" then return end
        
        _SetMelee(inst)
        
        local scale = inst.Transform:GetScale()
        inst.components.combat:SetRange(20*scale, 3*scale)

        inst.components.combat:SetDefaultDamage(TUNING.PALMTREEGUARD_DAMAGE*scale)
    end
end)

------------------------------------------------------------------------------------

-- Tar Extractor and Sea Yeard properly require Sea Lab to prototype, istead of handmade:

if GetConfig("sealab") then
    _G.TECH.WATER_TWO = {WATER = 2}

    AddComponentPostInit("builder", function(self)
        self.water_bonus = 0

        local _EvaluateTechTrees = self.EvaluateTechTrees
        local _KnowsRecipe = self.KnowsRecipe

        -- techtreechange event for Water tech
        function self:EvaluateTechTrees()
            local old_accessible_tech_trees = _G.deepcopy(self.accessible_tech_trees or TECH.NONE)

            self.accessible_tech_trees.WATER = self.water_bonus

            _EvaluateTechTrees(self)
            local trees_changed = false

            for k, v in pairs(old_accessible_tech_trees) do
                if v ~= self.accessible_tech_trees[k] then 
                    trees_changed = true
                    break
                end
            end
            if not trees_changed then
                for k, v in pairs(self.accessible_tech_trees) do
                    if v ~= old_accessible_tech_trees[k] then 
                        trees_changed = true
                        break
                    end
                end
            end

            if trees_changed then -- Re-check for tech tree change
                self.inst:PushEvent("techtreechange", {level = self.accessible_tech_trees})
            end
        end

        function self:KnowsRecipe(recname)
            if recname ~= "tar_extractor" and recname ~= "sea_yard" then
                return _KnowsRecipe(self, recname)
            end
            
            local recipe = _G.GetRecipe(recname)
            if recipe then
                if recipe.level.WATER <= self.water_bonus then -- Show the recipe if near Sea Lab
                    return true
                end
            end

            return self.freebuildmode or self.jellybrainhat or (self:IsBuildBuffered(recname) or table.contains(self.recipes, recname))
        end
    end)
end

------------------------------------------------------------------------------------

