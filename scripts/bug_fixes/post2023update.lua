--======================================================================================================================================--
-- Well, 95% of the fixes are now officially implemented, so here are just the unimplemented ones.
-- Basically the mod is now a set of bizarre fixes and some features disguised as fixes :D
--======================================================================================================================================--

local function FixCompanions(inst)
    if inst.prefab ~= "chester" then
        inst:RemoveTag("chester")
    else
        inst:DoTaskInTime(1.5, function(inst)
            if not TheSim:FindFirstEntityWithTag("chester_eyebone2") then
                inst:Remove()
            end
        end)
    end

    inst:DoTaskInTime(0, function(inst)
        local next_inst = TheSim:FindFirstEntityWithTag(inst.prefab)
        if next_inst and next_inst ~= inst then
            print(inst, "is a duplicate! Removing it...")
            inst:Remove()
        end
    end)
end

-- Fix for companions duplicates.
AddPrefabPostInit("chester", FixCompanions)
AddPrefabPostInit("packim", FixCompanions)
AddPrefabPostInit("ro_bin", FixCompanions)

AddPrefabPostInit("chester_eyebone", function(inst)
    inst:AddTag("chester_eyebone2")
end)

------------------------------------------------------------------------------------

-- Delay 3 frames to show the "ARM_carry" symbol to don't glitch the "item_out" anim.
-- Horrible method.
AddComponentPostInit("equippable", function(self)
    function self:SetOnEquip(fn)
        self.onequipfn = function(inst, owner, override)
            if self.equipslot == EQUIPSLOTS.HANDS then
                inst:DoTaskInTime(3*FRAMES, function()
                    if self.isequipped then
                        fn(inst, owner, override)
                        if inst.components.dsskins and inst.components.dsskins.skin then
                            inst:PushEvent("equipped", {owner=self.owner, slot=self.equipslot}) -- Swap to skin build.
                        end
                    end
                end)
                return
            end

            fn(inst, owner, override)
        end
    end
end)

------------------------------------------------------------------------------------

-- 3 hits to break them.
local function SkeletonTweak(inst)
    inst.components.workable:SetWorkLeft(3)
end

AddPrefabPostInit("skeleton", SkeletonTweak)
AddPrefabPostInit("skeleton_player", SkeletonTweak)

------------------------------------------------------------------------------------

local BOUNCESTUFF_MUST_TAGS = { "isinventoryitem" }
local BOUNCESTUFF_CANT_TAGS = { "locomotor", "INLIMBO" }

local function ClearRecentlyBounced(inst, other)
    inst.sg.mem.recentlybounced[other] = nil
end

local function SmallLaunch(inst, launcher, basespeed)
    local hp = inst:GetPosition()
    local pt = launcher:GetPosition()
    local vel = (hp - pt):GetNormalized()
    local speed = basespeed * 2 + 1.5
    local angle = math.atan2(vel.z, vel.x) + (math.random() * 20 - 10) * DEGREES
    inst.Physics:Teleport(hp.x, .1, hp.z)
    inst.Physics:SetVel(math.cos(angle) * speed, 2.5 * speed + math.random(), math.sin(angle) * speed)

    if inst.components.inventoryitem.OnStartFalling then
        inst.components.inventoryitem:OnStartFalling()
    end

    if inst.sg then
        launcher.sg.mem.recentlybounced[inst.GUID] = true
        launcher:DoTaskInTime(.6, ClearRecentlyBounced, inst.GUID)
    end
end

local function BounceStuff(inst, point)
    if inst.sg and inst.sg.mem.recentlybounced == nil then
        inst.sg.mem.recentlybounced = {}
    end

    local ents = TheSim:FindEntities(point.x, point.y, point.z, 3, BOUNCESTUFF_MUST_TAGS, BOUNCESTUFF_CANT_TAGS)
    for i, v in ipairs(ents) do
        if v:IsValid() and 
        v.components.inventoryitem and
        not (v.components.inventoryitem.nobounce or (inst.sg and inst.sg.mem.recentlybounced[v.GUID])) and
        (not v.GetIsOnWater or not v:GetIsOnWater()) and
        v.Physics ~= nil and
        v.Physics:IsActive() then
            local distsq = v:GetDistanceSqToPoint(inst:GetPosition())
            local intensity = math.clamp((36 - distsq) / 27, 0, 1)
            SmallLaunch(v, inst, intensity)
        end
    end
end

-- GroundPound now bounce items.
AddComponentPostInit("groundpounder", function(self)
    local _DestroyPoints = self.DestroyPoints
    function self:DestroyPoints(points, ...)
        _DestroyPoints(self, points, ...)

        if not self.inst:HasTag("minotaur") and self.groundpoundfx ~= "firesplash_fx" then
            for k,v in pairs(points) do
                BounceStuff(self.inst, v)
            end
        end
    end
end)

------------------------------------------------------------------------------------

-- Fixes the spell fx position when mounting.
AddPrefabPostInit("staffcastfx", function(inst)
    if GetPlayer().components.rider:IsRiding() then
        inst.AnimState:PlayAnimation("staff_mount")
        inst.AnimState:SetTime(.3)
    end
end)

--======================================================================================================================================--
--                                                              SHIPWRECKED
--======================================================================================================================================--

if not hasSW then return end

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


--======================================================================================================================================--
--                                                           HAMLET
--======================================================================================================================================--

if not hasHAM then return end

------------------------------------------------------------------------------------

if GetConfig("hulk_basalt") then
    local function BasaltAutoStack(self, pt, loots)
        local prefabs = loots
        if prefabs == nil then
            prefabs = self:GenerateLoot()
        end 
        self:CheckBurnable(prefabs)

        for k,v in pairs(prefabs) do
            local loot = self:SpawnLootPrefab(v, pt)
            loot:AddComponent("selfstacker") --The component will be removed in next load.
            loot.components.selfstacker.searchradius = 10
            loot.components.selfstacker:DoStack()
        end
    end

    -- Self Stack the loot from Rock Basalts to prevent FPS drop.
    AddPrefabPostInit("rock_basalt", function(inst)
        inst.components.lootdropper.DropLoot = BasaltAutoStack
    end)
end