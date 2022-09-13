-- Spice Pack will not be invisible when the player isn't Warly.
LoadAsset.Anim("swap_chefpack")
LoadAsset.Anim("normal_ice")

------------------------------------------------------------------------------------

if GetConfig("recipe") then
    -- Learn non-unlockable recipes + Wicker Science 1
    AddComponentPostInit("builder", function (self)
        local _MakeRecipe = self.MakeRecipe

        function self:MakeRecipe(recipe, pt, rot, onsuccess, modifydata)
            local makeRecipeSuccess = _MakeRecipe(self, recipe, pt, rot, onsuccess, modifydata)

            if makeRecipeSuccess and not self.brainjellyhat then
                self:AddRecipe(recipe.name)
            end

            return makeRecipeSuccess
        end
    end)
end

------------------------------------------------------------------------------------

local function RemoveWildboreInWater(inst)
    if inst and inst.Transform and GetWorld() and GetMap() then
        if inst:GetIsOnWater(inst:GetPosition():Get()) then
            print("Finded a ".. inst.prefab .. " in the ocean! Removing him!")
            inst:Remove()
        end
    end
end

-- Wilbore in water fix.
AddPrefabPostInit("wildbore", function(inst)
    inst:DoPeriodicTask(TUNING.TOTAL_DAY_TIME, RemoveWildboreInWater)
end)

------------------------------------------------------------------------------------

if GetConfig("shadowcreature") then
    -- Shadows's water spawn fix
    AddStategraphPostInit("shadowcreature", function(self)
        self.states["hit"].events.animover.fn = function(inst)
            if GetMap() then
                local max_tries = 4
                for k = 1, max_tries do
                    local pos = Vector3(inst.Transform:GetWorldPosition())
                    local offset = 10
                    pos.x = pos.x + (math.random(2*offset)-offset)          
                    pos.z = pos.z + (math.random(2*offset)-offset)
                    local tile = GetMap():GetTileAtPoint(pos:Get())
                    if tile ~= GROUND.IMPASSABLE and inst:IsPosSurroundedByLand(pos.x, pos.y, pos.z, 2) then
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

if GetConfig("bee") then
    local function FlyOverWater(inst)
        inst.components.inventoryitem.nosink = true
        inst:AddTag("amphibious")

        inst.Physics:SetCollisionGroup(COLLISION.FLYERS)
        inst.Physics:ClearCollisionMask()
        
        if hasHAM then
            SetAquaticEntityCollision(inst)
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

if GetConfig("trap") then
    local function AddTrapTag(inst)
        inst:AddTag("canbetrapped")
    end

    -- Trapped animals
    AddPrefabPostInit("snake", AddTrapTag)
    AddPrefabPostInit("snake_poison", AddTrapTag)
    AddPrefabPostInit("flup", AddTrapTag)
    AddPrefabPostInit("snake_amphibious", AddTrapTag)

end

------------------------------------------------------------------------------------

if GetConfig("flup") then
    -- Fix Flup Respawn
    local function FlupSpawner(inst)
        inst.components.areaspawner.spawntest = nil
    end

    AddPrefabPostInit("flupspawner", FlupSpawner)
    AddPrefabPostInit("flupspawner_dense", FlupSpawner)
    AddPrefabPostInit("flupspawner_sparse", FlupSpawner)
end

------------------------------------------------------------------------------------

if GetConfig("butterfly") then
    local butterfly_notiles = {
        GROUND.ROCKY, GROUND.ROAD,  GROUND.IMPASSABLE, GROUND.UNDERROCK,
        GROUND.BRICK_GLOW, GROUND.WOODFLOOR, GROUND.MAGMAFIELD, GROUND.CARPET,
        GROUND.CHECKER, GROUND.ASH, GROUND.VOLCANO, GROUND.VOLCANO_ROCK,
    }
    
    if hasHAM then
        table.insert(butterfly_notiles, GROUND.INTERIOR)
    end

    local notags = {'NOBLOCK', 'player', 'FX'}

    local function test_ground(inst, pt)
        local tiletype = GetGroundTypeAtPosition(pt)

        if table.contains(butterfly_notiles, tiletype)
        or GetMap():IsWater(tiletype)
        or  tiletype > GROUND.UNDERGROUND then
            return false
        end

        local ents = TheSim:FindEntities(pt.x,pt.y,pt.z, 4, nil, notags)
        local min_spacing = inst.components.deployable.min_spacing or 2

        for k, v in pairs(ents) do
            if v ~= inst and v:IsValid() and v.entity:IsVisible() and not v.components.placer and v.parent == nil then
                if distsq(Vector3(v.Transform:GetWorldPosition()), pt) < min_spacing*min_spacing then
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
    Hooks.sg.state.onenter.Post(self, "use_fan", function(inst, arg)
        local fan = inst:GetBufferedAction().invobject
        if fan then -- Fix Doydoy Fan Texture on boat
            inst.AnimState:OverrideSymbol("fan01", fan.animinfo, "fan01")
        end
    end)

    self.states["use_fan"].timeline = -- Fix Fans missing sound on boat
        {   
            TimeEvent(26*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC002/common/luxury_fan", "fan") end),
            TimeEvent(70*FRAMES, function(inst) inst:PerformBufferedAction() end),
            TimeEvent(90*FRAMES, function(inst) inst.SoundEmitter:KillSound("fan") end),
        }
end)

------------------------------------------------------------------------------------

local function LocalGetSpawnPoint(pt)
    local theta = math.random() * 2 * PI
    local radius = 30

    local offset = FindWalkableOffset(pt, theta, radius, 12, true)
    if offset then
        return pt+offset
    end
end

local function SpawnPackim(inst) -- Local function and I can't get with UpvalueHacker :(
    local pt = Vector3(inst.Transform:GetWorldPosition())
    local spawn_pt = hasHAM and GetSpawnPoint(inst, pt) or LocalGetSpawnPoint(pt)

    if spawn_pt then
        local packim = SpawnPrefab("packim")
        if packim then
            packim.Physics:Teleport(spawn_pt:Get())
            packim:FacePoint(pt.x, pt.y, pt.z)

            return packim
        end
    end
end

local function RebindPackim(_RebindPackim)
    return function(inst, packim)
        packim = packim or TheSim:FindFirstEntityWithTag("packim")
        if packim then
            _RebindPackim(inst, packim)
        end
    end
end

local function RespawnPackim(StopRespawn, RebindPackim)
    return function(inst)
        StopRespawn(inst)

        local packim = TheSim:FindFirstEntityWithTag("packim")
        if not packim then
            packim = SpawnPackim(inst)
        end
        RebindPackim(inst, packim)
    end
end

-- Packim's FishBone only lure and checks for Packim
AddPrefabPostInit("packim_fishbone", function(inst)
    local _RebindPackim = UpvalueHacker.GetUpvalue(inst.fixtask.fn, "FixPackim", "RebindPackim")

    UpvalueHacker.SetUpvalue(inst.fixtask.fn, RebindPackim(_RebindPackim), "FixPackim", "RebindPackim")

    --------------------

    local StopRespawn = UpvalueHacker.GetUpvalue(inst.OnPackimDeath, "StartRespawn", "StopRespawn")

    UpvalueHacker.SetUpvalue(inst.OnPackimDeath, RespawnPackim(StopRespawn, _RebindPackim), "StartRespawn", "RespawnPackim")
end)

------------------------------------------------------------------------------------

local SwordFish_CHASE_DIST = 40

local function SwordFishKeepTargetFn(_keepTarget)
    return function(inst, target)
        local shouldkeep = _keepTarget(inst, target)
        local home = inst.components.knownlocations:GetLocation("home")

        if shouldkeep and home then
            local isnearhome = inst:GetDistanceSqToPoint(home) <= SwordFish_CHASE_DIST * SwordFish_CHASE_DIST

            return isnearhome
        end

        return shouldkeep
    end
end

-- Sword Fish will no longer chase its target forever.
AddPrefabPostInit("swordfish", function(inst)
    local _keepTarget = inst.components.combat.keeptargetfn

    inst.components.combat:SetKeepTargetFunction(SwordFishKeepTargetFn(_keepTarget))
end)

------------------------------------------------------------------------------------

local function UpdateFishAnims(inst)
    if inst.components.floatable.landanim ~= "dead" then
        inst.components.floatable:UpdateAnimations(nil, "dead")
    end 
end
local function CommonFishFix(inst)
    for task, _ in pairs(inst.pendingtasks) do
        if task.period == 5 then
            task.fn = UpdateFishAnims
        end
    end

    inst.components.floatable:UpdateAnimations(nil, "idle")
    inst.OnLoad = UpdateFishAnims

    inst.components.inventoryitem:SetOnPickupFn(UpdateFishAnims)
end

-- Fixes fish dropped in land anim, which was causing an early dead anim.
AddPrefabPostInit("fish", CommonFishFix)
AddPrefabPostInit("tropical_fish", CommonFishFix)

-- Fixes missing dead anim and missing components for fish farm's fishes.
for _, n in ipairs({3,4,5}) do
    AddPrefabPostInit("fish"..n, function(inst)
        CommonFishFix(inst)

        inst:DoTaskInTime(1, UpdateFishAnims) -- Only used in console spawn, but I'll left it here.

        MakeBlowInHurricane(inst, TUNING.WINDBLOWN_SCALE_MIN.MEDIUM, TUNING.WINDBLOWN_SCALE_MAX.MEDIUM)
  
        inst:AddComponent("appeasement")
        inst.components.appeasement.appeasementvalue = TUNING.APPEASEMENT_TINY
    end)
end

------------------------------------------------------------------------------------

-- Thanks to: Island's Adventure Mod Team <3
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

local function MoveBoatOnUpdate(self)
    if self.vehicle ~= nil and self.vehicle:IsValid() then 
        local CameraRight = TheCamera:GetRightVec()
        local CameraDown = TheCamera:GetDownVec()
        
        local myPos = self.inst:GetPosition()
        local displacement = CameraRight:Cross(CameraDown) * 0.05

        local pos = myPos - displacement

        self.vehicle.Transform:SetPosition(pos:Get())
    end
end

-- Little change to boat position to work properly with the bundling anim hack
AddComponentPostInit("driver", function(self)
    local _OnUpdate = self.OnUpdate
    function self:OnUpdate(dt)
        _OnUpdate(self, dt)
        MoveBoatOnUpdate(self)
    end
end)

------------------------------------------------------------------------------------

AddStategraphActionHandler("wilsonboating", ActionHandler(ACTIONS.UNWRAP, "dolongaction"))
AddStategraphActionHandler("wilsonboating", ActionHandler(ACTIONS.BUNDLE, "bundle"))

local SGwilson = require("stategraphs/SGwilson")
package.loaded["stategraphs/SGwilson"] = nil -- Unload the file

-- Add the bundling states to boating + hacky to show the boat with the anim (bundling anim don't have boat symbol)
AddStategraphPostInit("wilsonboating", function(sg)
    for i, state in ipairs({"bundle", "bundling", "bundle_pst"}) do

        sg.states[state] = deepcopy(SGwilson.states[state])
        AddTagToState(sg, state, "boating")

        if GetConfig("bundle_fx") then -- Don't need this for build anim
            Hooks.sg.state.ToggleBoat(sg, state)
        end
    end

    ------------------------------------------------------------------------------------

    -- Fix invisible boat on telebrella teleport
    Hooks.sg.state.onenter.Post(sg, "telebrella", function(inst, arg)
        local downvec = TheCamera:GetDownVec()
        local facedown = -(math.atan2(downvec.z, downvec.x) * (180/math.pi))
        local vehicle = inst.components.driver.vehicle
        if vehicle then
            inst.components.driver.combined = false
            vehicle.Transform:SetRotation(facedown)
            vehicle:Show()
        end
    end)
end)

------------------------------------------------------------------------------------

-- Inspired by skittles sour's mod: https://steamcommunity.com/sharedfiles/filedetails/?id=2635513673
AddPlayerPostInit(function(inst)
    inst:DoTaskInTime(0, function()
        if not GetWorld():IsVolcano() then return end
        
        -- Fix Boat speed multipliers when climb volcano.
        inst.components.locomotor:RemoveSpeedModifier_Additive("DRIVER")
        inst.components.locomotor:RemoveSpeedModifier_Mult("TRAWL")
        inst.components.locomotor:RemoveSpeedModifier_Mult("SAIL")
    end)
end)

------------------------------------------------------------------------------------

local function destroystuff(inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, 3, nil, {"INLIMBO"}) -- Inlimbo = in inventory
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
            v.components.workable.workleft > 0 and
            not table.contains({ACTIONS.NET, ACTIONS.FISH}, v.components.workable:GetWorkAction()) then
                SpawnPrefab("collapse_small").Transform:SetPosition(v.Transform:GetWorldPosition())
                v.components.workable:WorkedBy(inst, 2)
            end

            if v and v.components.hackable and v.components.hackable.hacksleft > 0 then
                SpawnPrefab("collapse_small").Transform:SetPosition(v:GetPosition():Get())
                v.components.hackable:Hack(inst, 2)
            end
        end
    end
end

-- Fixes Coconut being cut in inventory by weather pain
-- + adjust work rate
AddStategraphPostInit("tornado", function(self)
    UpvalueHacker.SetUpvalue(self.states["idle"].onenter, destroystuff, "destroystuff")
    UpvalueHacker.SetUpvalue(self.states["walk"].onenter, destroystuff, "destroystuff")

    for i, state in pairs({"walk", "run_start", "run", "run_stop"}) do
        self.states[state].timeline = { TimeEvent(5*FRAMES, destroystuff) }
    end
end)

------------------------------------------------------------------------------------

local function FenceDeployFixes(inst)
    -- Fence/gate deploy distance like walls
    inst.components.deployable:SetQuantizeFunction(function(pt)
        return Vector3(math.floor(pt.x)+.5, 0, math.floor(pt.z)+.5)
    end)

    inst.components.deployable.deploydistance = 1.5 -- (Deploy distance don't exist before SW)

    if hasHAM then return end

    -- Fix fence deploy on water in non-hamlet worlds.
    local _test = inst.components.deployable.test
    inst.components.deployable.test = function(inst, pt, deployer)
        return _test and not inst:GetIsOnWater(pt:Get())
    end
end

AddPrefabPostInit("fence_item", FenceDeployFixes)
AddPrefabPostInit("fence_gate_item", FenceDeployFixes)

------------------------------------------------------------------------------------

local function TreeGuardRange(_SetRange)
    return function(inst)
        if inst.combatmode == "RANGE" then return end
        
        _SetRange(inst)
        
        local scale = inst.Transform:GetScale()
        inst.components.combat:SetRange(20*scale, 25*scale)
    end
end

local function TreeGuardMeele(_SetMelee)
    return function(inst)
        if inst.combatmode == "MELEE" then return end
        
        _SetMelee(inst)
        
        local scale = inst.Transform:GetScale()
        inst.components.combat:SetRange(20*scale, 3*scale)

        inst.components.combat:SetDefaultDamage(scale*TUNING.PALMTREEGUARD_DAMAGE)
    end
end

-- Coconut TreeGuard stats scale with his size scale properly. (See TG spawn in palmtrees.lua for details)
AddPrefabPostInit("treeguard", function(inst)
    local _SetRange = inst.SetRange
    local _SetMelee = inst.SetMelee

    inst.SetRange = TreeGuardRange(_SetRange)

    inst.SetMelee = TreeGuardMeele(_SetMelee)
end)

------------------------------------------------------------------------------------

if GetConfig("lava") then
    --Volcano lava can no longer be removed with pitchfork
    AddComponentPostInit("terraformer", function(self)
        local _CanTerraformPoint = self.CanTerraformPoint
        function self:CanTerraformPoint(pt)
            local tile = GetMap():GetTileAtPoint(pt.x, pt.y, pt.z)
            return _CanTerraformPoint(self, pt) and tile ~= GROUND.VOLCANO_LAVA
        end
    end)
end

------------------------------------------------------------------------------------

-- Save-exit when using the Quackering Ram attack don't corrupt the save anymore.
AddPrefabPostInit("quackering_wake", function(inst)
    inst.persists = false -- Don't save FX Klei...
end)

------------------------------------------------------------------------------------

-- Original AmbientSoundMixer is connected to actual DLC map, causing high DLC's sounds 
-- to not exits in that map. For example: hamlet turfs don't have ambient sounds in SW map
AddComponentPostInit("ambientsoundmixer", function(mixer)
    if hasHAM then
        mixer = require "components/ambientsoundmixer_pork"
    else
        mixer = require "components/ambientsoundmixer_sw"
    end
end)

------------------------------------------------------------------------------------

if GetConfig("fishfarm") then
    -- Fixes crocodog's attacks to fish farm. (Klei wrote luretask instead of lureTask)
    AddComponentPostInit("breeder", function(self)
        local _OnSave = self.OnSave
        function self:OnSave()
            local data = _OnSave(self)

            if self.lureTask then
                data.luretasktime = GetTaskRemaining(self.lureTask)
                data.luretask = data.luretasktime -- Other misswrite
            end

            return data
        end
    end)
end

------------------------------------------------------------------------------------

-- Fixes Fish Farm's Sign over the boat.
AddPrefabPostInit("fish_farm_sign", function(inst)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
end)

------------------------------------------------------------------------------------

if GetConfig("speed") then
    -- Fixes character specials speed modifiers in World Reset
    AddComponentPostInit("locomotor", function(self)
        function self:OnProgress()
            if SaveGameIndex:GetCurrentMode(Settings.save_slot) ~= "adventure" then
                self.noserial = true
            end
        end

        local _OnSave = self.OnSave
        function self:OnSave()
            if not self.noserial then
                return _OnSave(self)
            end
            self.noserial = false
        end
    end)
end

------------------------------------------------------------------------------------

-- Cures the poison after World Reset.
AddComponentPostInit("poisonable", function(self)
    function self:OnProgress()
        if SaveGameIndex:GetCurrentMode(Settings.save_slot) ~= "adventure" then
            self:Cure()
        end 
    end
end)

------------------------------------------------------------------------------------

local TreeGuardThrowTimeline = {
    TimeEvent( 0       , function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC002/creatures/palm_tree_guard/tree_movement") end),
    TimeEvent(05*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC002/creatures/palm_tree_guard/attack") end),
    TimeEvent(22*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC002/creatures/palm_tree_guard/tree_movement") end),
    TimeEvent(25*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC002/creatures/palm_tree_guard/coconut_throw") end),
    TimeEvent(25*FRAMES, function(inst) inst:PushEvent("onattackother", {target=inst.sg.statemem.target}) end),
    TimeEvent(26*FRAMES, function(inst) inst.sg:RemoveStateTag("attack") end),
}

local KnightBoatAttackTimeline = {
    TimeEvent( 0, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC002/creatures/knight_steamboat/attack") end),
    TimeEvent(25*FRAMES, function(inst) inst:PushEvent("onattackother", {target=inst.sg.statemem.target or inst.components.combat.target}) end),
    TimeEvent(31*FRAMES, function(inst) inst.SoundEmitter:PlaySound("dontstarve_DLC002/creatures/knight_steamboat/cannon") end),
}

-- Fixes Boat Knight and Palm Tree Guard's "fake" ranged attack
AddStategraphPostInit("treeguard", function(self)
    self.states["throw"].timeline = TreeGuardThrowTimeline
end)

AddStategraphPostInit("knightboat", function(self)
    self.states["attack"].timeline = KnightBoatAttackTimeline
end)

------------------------------------------------------------------------------------

-- Fixes litle glitch with meteor ground fx.
AddPrefabPostInit("meteor_impact", function(inst)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(3)
end)

------------------------------------------------------------------------------------

-- Fixes "ghost" hail/ice caused by save-exiting when it's disappearing.
local function FixIce(inst)
    local _OnLoad = inst.OnLoad
    inst.OnLoad = function(inst, data)
        _OnLoad(inst, data)
        if not inst.components.inventoryitem.canbepickedup then
            inst:Remove()
        end
    end
end

AddPrefabPostInit("hail_ice", FixIce)

-- Gives Ice your texture again. Fuck you hail texture.
AddPrefabPostInit("ice", function(inst)
    FixIce(inst)
    inst.AnimState:SetBuild("normal_ice")
    inst.AnimState:SetBank("normal_ice")
end)

------------------------------------------------------------------------------------

-- Fix for many load bugs, including: Obsidian equips charge lost and relics stuck in inventory.
-- Original OnLoad check if the item is on water, but all items spawn at 0,0,0 (possible water)
-- before going to inventory. So shitty things happens.

local function floatable_OnLoad(self, data)
    if data and data.onwater then
        self:OnHitWater(true)
    else 
        self:OnHitLand(true)
    end
end

AddComponentPostInit("floatable", function(self)
    self.OnLoad = floatable_OnLoad
end)

AddComponentPostInit("inventoryitem", function(self)
    local _OnPutInInventory = self.OnPutInInventory
    function self:OnPutInInventory(...)
        _OnPutInInventory(self, ...)
        if self.inst.components.floatable then
            self.inst.components.floatable.onwater = false
            self.inst:RemoveTag("aquatic")
        end
    end
end)

------------------------------------------------------------------------------------

-- Some Staffs can now cast on land when the player in the ocean.
ACTIONS.CASTSPELL.crosseswaterboundary = true

------------------------------------------------------------------------------------

AddPrefabPostInit("packim", function(inst)
    -- Stop packim from attacking Webber :(
    inst.components.combat.notags = {"player"}

    -- Stop triggring spider web and being slowed down by it.
    inst:AddTag("flying")
    inst.components.locomotor:EnableGroundSpeedMultiplier(false)
    inst.components.locomotor:SetTriggersCreep(false)
    inst.components.locomotor.pathcaps = {ignorecreep = true}
end)

------------------------------------------------------------------------------------

-- Shoals have her own quotes.
AddPrefabPostInit("fishinhole", function(inst)
    inst.components.inspectable.nameoverride = nil
end)

------------------------------------------------------------------------------------

local function SetBlankAction(inst)
    inst.components.workable:SetWorkAction(ACTIONS.BLANK)
end

-- Obsidian Rock and Dragoon Den can now be destroyed by living artifact.
AddPrefabPostInit("rock_obsidian", SetBlankAction)
AddPrefabPostInit("dragoonden", SetBlankAction)

------------------------------------------------------------------------------------

-- Sealnado can't grab the player if mounted.
AddStategraphPostInit("twister", function(sg)
    Hooks.sg.state.onenter.Post(sg, "vacuum_loop", function(inst, arg)
        if GetPlayer().components.rider:IsRiding() then
            inst.components.vacuum.ignoreplayer = true
        end
    end)
end)

------------------------------------------------------------------------------------

-- Items after deconstruction will float.
AddPrefabPostInit("greenstaff", function(inst)
    local _spell = inst.components.spellcaster.spell
    inst.components.spellcaster.spell = function(staff, target)
        _spell(staff, target)
        local pt = target:GetPosition()
        local ents = TheSim:FindEntities(pt.x,pt.y,pt.z, 5, {"isinventoryitem"}, {"INLIMBO", "NOCLICK", "FX"})

        for _, ent in ipairs(ents) do
            if ent:GetTimeAlive() < 1 then
                ent.components.inventoryitem:OnLootDropped(0)
            end
        end
    end
end)

------------------------------------------------------------------------------------

-- Sunken items can be couth with trawl net!
AddPrefabPostInit("sunkenprefab", function(inst)
    inst:RemoveTag("FX")
    inst:RemoveTag("NOCLICK")

    inst:AddTag("NOBLOCK")
end)

------------------------------------------------------------------------------------

-- Throw poop with Wilbur will not cause reflective damage.
-- + effect for landing in water.

local function PoopOnThrown(inst, thrower, pt)
    inst.flies:Remove()
    inst:RemoveComponent("inventoryitem")

    inst:AddTag("thrown")
    inst:AddTag("projectile")

    inst.AnimState:SetBank("monkey_projectile")
    inst.AnimState:SetBuild("monkey_projectile")
    inst.AnimState:PlayAnimation("idle", true)

    inst.Physics:SetFriction(.2)

    inst.GroundTask = inst:DoPeriodicTask(FRAMES, function()
        local pos = inst:GetPosition()
        if pos.y <= 0.5 then
            local ents = TheSim:FindEntities(pos.x, pos.y, pos.z, 1.5, nil, {"FX", "NOCLICK", "DECOR", "INLIMBO"})

            for k,v in pairs(ents) do
                if v.components.combat then
                    v.components.combat:GetAttacked(thrower, TUNING.POOP_THROWN_DAMAGE, inst)
                end
            end

            local fx = "poop_splat"

            if inst:GetIsOnWater() then
                inst.SoundEmitter:PlaySound("dontstarve_DLC002/common/item_sink")
                fx =  "splash_water_sink"
            end

            local pt = inst:GetPosition()
            SpawnPrefab(fx).Transform:SetPosition(pt:Get())

            inst:Remove()
        end
    end)
end

AddPrefabPostInit("poop", function(inst)
    if not inst.components.equippable then return end

    inst.components.throwable.onthrown = PoopOnThrown
end)

------------------------------------------------------------------------------------

-- Fixes the Ox trying to go home when attacking on ocean (not mangrove)
AddBrainPostInit("oxbrain", function(brain)
    local ocean_node = nil
    local ocean_index = nil

    for i, node in ipairs(brain.bt.root.children) do
        if node.children and node.children[1].name == "intheocean" then
            ocean_node = node
            ocean_index = i
            break
        end
    end

    table.remove(brain.bt.root.children, ocean_index)
    table.insert(brain.bt.root.children, #brain.bt.root.children - 2, ocean_node)
end)

------------------------------------------------------------------------------------

local function FixAnimOnSpawn(inst, arg)
    if inst:GetTimeAlive() < 3 then
        if not inst:GetIsOnWater() then
            inst.AnimState:SetBank("ox")
        end
        if inst:HasTag("wasbaby") then
            inst:RemoveTag("wasbaby")
            inst:DoTaskInTime(0.2, function()
                inst.sg:GoToState("hair_growth_pop")
            end) 
        else
            inst.sg:GoToState("idle")
        end
    end
end

-- Fixes animation on spawn of oxs.
AddStategraphPostInit("ox", function(sg)
    Hooks.sg.state.onenter.Post(sg, "emerge", FixAnimOnSpawn)
    Hooks.sg.state.onenter.Post(sg, "submerge", FixAnimOnSpawn)
end)

------------------------------------------------------------------------------------

AddStategraphPostInit("wilsonboating", function(sg)
    -- Can use goggles attack when boating
    Hooks.sg.handler.Event(sg, "doattack", function(inst, data, _old)
        if not inst.components.health:IsDead() and not inst.sg:HasStateTag("attack") and not inst.sg:HasStateTag("sneeze") then
            local weapon = inst.components.combat and inst.components.combat:GetWeapon()
            if weapon and weapon:HasTag("goggles") then 
                inst.sg:GoToState("goggleattack")
            end
            
            return _old(inst, data)
        end
    end)

    sg.states["goggleattack"] = deepcopy(SGwilson.states["goggleattack"])
    sg.states["goggle_attack_post"] = deepcopy(SGwilson.states["goggle_attack_post"])
    AddTagToState(sg, "goggleattack", "boating")
    AddTagToState(sg, "goggle_attack_post", "boating")

    -- Wagstaff special voice parameter when boating.
    Hooks.sg.state.onenter.Pre(sg, "talk", function(inst, noanim)
        if inst:HasTag("hasvoiceintensity_health") then
            local percent = inst.components.health:GetPercent()
            inst.SoundEmitter:SetParameter( "talk", "intensity", percent)
        end
    end)
end)

------------------------------------------------------------------------------------

-- Fixes meat/fish spawning mobs on load.
AddComponentPostInit("inventoryitem", function(self)
    local _OnHitWater = self.OnHitWater
    function self:OnHitWater()
        if self.inst.components.floatable and 
        self.inst.components.floatable.onwater then
            self.inst:RemoveTag("falling")
            if self.inst.components.blowinwind ~= nil then
                self.inst.components.blowinwind:Stop()
            end
        else
            _OnHitWater(self)
        end
    end
end)

-----------------------------------------------------------------------------------

-- Klei has a outdated "version" of speechs for SW, and forgot to update in the QoL update...
if not hasHAM then
    local missing_quotes = require("missing_speech_SW")

    for char, quotes_table in pairs(missing_quotes) do
        for key_type, quotes in pairs(quotes_table) do
            local parentTable = STRINGS.CHARACTERS[string.upper(char)][key_type]
            for k, v in pairs(quotes) do
                if type(parentTable[k]) == "table" then
                    for kk, vv in pairs(v) do
                        if not parentTable[k][kk] then
                            parentTable[k][kk]=  vv
                        end
                    end
                elseif not parentTable[k] then
                    parentTable[k] = v
                end
            end
        end
    end

end

------------------------------------------------------------------------------------

STRINGS.ACTIONS.DEPLOY.PORTABLE = "Place"

AddPrefabPostInit("portablecookpot_item", function(inst)
    inst.components.inventoryitem:SetOnDroppedFn(nil) --> Don't Auto-Place
    inst:AddTag("portableitem") --> Place Verb

    inst.components.deployable.deploydistance = 1.5
end)

------------------------------------------------------------------------------------

local function PushPlayAnim(inst)
    inst.components.floatable:OnHitWater()
    if inst.components.blowinwind ~= nil then
        inst.components.blowinwind:Stop()
    end
    inst:RemoveEventCallback("animover", PushPlayAnim)
end

local function DeathOnEnter(inst, anim, sound)
    inst.SoundEmitter:PlaySound("dontstarve_DLC002/creatures/"..sound)
    inst.components.locomotor:Stop()
    RemovePhysicsColliders(inst)

    local item = SpawnPrefab(inst.components.lootdropper.loot[1])

    item.Transform:SetPosition(inst.Transform:GetWorldPosition())

    item.Transform:SetTwoFaced()
    item.Transform:SetRotation(inst:GetRotation())
    item.Transform:SetPosition(inst.Transform:GetWorldPosition())

    if inst.components.poisonable and inst.components.poisonable:IsPoisoned() and item.components.perishable then
        item.components.perishable:ReducePercent(TUNING.POISON_PERISH_PENALTY)
    end

    inst:ApplyInheritedMoisture(item)
    
    if anim then
        item.AnimState:PlayAnimation(anim)
        item:ListenForEvent("animover", PushPlayAnim)
    else
        item.components.floatable:OnHitWater()
        if item.components.blowinwind ~= nil then
            item.components.blowinwind:Stop()
        end
    end

    inst:Remove()
end

local function ReworkFishDeath(sg_name, prefab, sound, anim)
    AddPrefabPostInit(prefab, function(inst)
        inst.components.health.nofadeout = true
    end)

    AddStategraphPostInit(sg_name, function(self)
        local death = self.states["death"]
        death.onenter = function(inst) DeathOnEnter(inst, anim, sound) end
    end)
end

ReworkFishDeath("jellyfish", "jellyfish_planted", "jellyfish/death_murder", "death")
ReworkFishDeath("rainbowjellyfish", "rainbowjellyfish_planted", "jellyfish/death_murder", "death")

ReworkFishDeath("solofish", "solofish", "Dogfish/death")
ReworkFishDeath("swordfish", "swordfish", "swordfish/death")

------------------------------------------------------------------------------------

local function SeaweedStalkOnDeploy(inst, pt) 
    inst = inst.components.stackable:Get()    
    inst:Remove()
    local stalk = SpawnPrefab("seaweed_planted")
    stalk.Transform:SetPosition(pt:Get()) 
    stalk.components.pickable:MakeEmpty()
    stalk.AnimState:PlayAnimation("picked", true)
end

-- Fixes a non-looped animation on seaweed stalk deploy.
AddPrefabPostInit("seaweed_stalk", function(inst)
    inst.components.deployable.ondeploy = SeaweedStalkOnDeploy
end)

------------------------------------------------------------------------------------

-- Fixes some mobs burning to ash instead of dying when burned.

require "behaviours/panic"

AddPrefabPostInit("flup", function(inst)
    inst:RemoveComponent("burnable")
    MakeSmallBurnableCharacter(inst, "flup_body")
end)

AddPrefabPostInit("sharkitten", function(inst)
    inst:RemoveComponent("burnable")
    inst:RemoveComponent("propagator")
    MakeMediumBurnableCharacter(inst, "hound_body")
end)

local prefabs_to_add_panic = {"flup", "sharkitten"}

for _, prefab in pairs(prefabs_to_add_panic) do
    AddBrainPostInit(prefab.."brain", function(brain)
        local inst = brain.inst
        table.insert(brain.bt.root.children, 1,
            WhileNode(function() return inst.components.health.takingfiredamage end, "OnFire", Panic(inst))
        ) 
    end)
end

------------------------------------------------------------------------------------

--The original noTags was being overwrited by {"sharkitten"}
AddPrefabPostInit("tigershark", function(inst)
    inst.components.groundpounder.noTags = {"sharkitten", "FX", "NOCLICK", "DECOR", "INLIMBO", "groundpoundimmune"}
end)

------------------------------------------------------------------------------------

local function FloatingBeard(sg)
    Hooks.sg.state.onexit.Post(sg, "shave", function(inst, arg)
        local pt = inst:GetPosition()
        local ents = TheSim:FindEntities(pt.x,pt.y,pt.z, 5, {"isinventoryitem"}, {"INLIMBO", "NOCLICK", "FX"})

        for _, ent in ipairs(ents) do
            if ent:GetTimeAlive() < 1 then
                ent.components.inventoryitem:OnLootDropped(0)
            end
        end
    end)
end

AddStategraphPostInit("wilson", FloatingBeard)
AddStategraphPostInit("wilsonboating", FloatingBeard)

------------------------------------------------------------------------------------

local function test_ground(inst, pt, deployer)
    return not inst:GetIsOnWater(pt:Get())
end

-- Don't deploy mini signs on water...
AddPrefabPostInit("minisign_item", test_ground)
AddPrefabPostInit("minisign_drawn", test_ground)