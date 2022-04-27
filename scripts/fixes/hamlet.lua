if GetConfig("rain") then
    -- Interiors issue - Hurricane Storm Fix
    AddComponentPostInit("seasonmanager", function(self)
        local _oldStartHurricaneStorm = self.StartHurricaneStorm
        function self:StartHurricaneStorm(duration_override, disablehail, dont_reset)
            if not dont_reset then 
                _oldStartHurricaneStorm(self, duration_override, disablehail)
                return
            end

            if not self:IsHurricaneStorm() then
                self.hurricane = true
                self:StartPrecip(true)
                self.inst:PushEvent("hurricanestart")
            end
        end

        local _oldStopHurricaneStorm = self.StopHurricaneStorm
        function self:StopHurricaneStorm(continue)
            if not continue then
                _oldStopHurricaneStorm(self)
                return
            end
            
            if self:IsHurricaneStorm() then
                self.hurricane = false
                self:StopPrecip()
                self.inst:PushEvent("hurricanestop")
            end
        end

        function self:onEnterInterior(data)
            self.ininterior = true
        
            self.precipoutside = self.precip
            if self.precipoutside then
                self:StopPrecip()
            end
        
            self.hurricaneoutside = self:IsHurricaneStorm()
            if self.hurricaneoutside then
                self:StopHurricaneStorm(true) -- Just to pass true here
            end
        end
        
        function self:onExitInterior(data)
            self.ininterior = false
            if self.precipoutside then
                self:StartPrecip(true)
            end
        
            if self.hurricaneoutside then
                self:StartHurricaneStorm(nil, nil, true) -- Just to pass true here
            end
        end
    end)
end
------------------------------------------------------------------------------------

local function CalcRotationEnum(rot, isdoor)
    return math.floor((math.floor(rot + 0.5) / 45) % (isdoor and 8 or 4))
end

local function FixFenceRotationPosInteior(inst)
    inst:ListenForEvent("endinteriorcam", function()
        inst.Transform:SetRotation(
            CalcRotationEnum(inst.Transform:GetRotation(), inst.prefab == "fence_gate") * 45)
    end, _G.GetWorld())
end

-- On exit interior fence rotation fix
AddPrefabPostInit("fence", FixFenceRotationPosInteior)
AddPrefabPostInit("fence_gate", FixFenceRotationPosInteior)

------------------------------------------------------------------------------------

if GetConfig("pressureplate") then
    local function NoTriggerPressurePlates(inst)
        inst:AddTag("flying")
    end

    -- No trigger traps fix
    AddPrefabPostInit("pigghost", NoTriggerPressurePlates)
    AddPrefabPostInit("terrorbeak", NoTriggerPressurePlates)
    AddPrefabPostInit("crawlinghorror", NoTriggerPressurePlates)
end

------------------------------------------------------------------------------------

if GetConfig("gifts") then
    local pigman_city = {
        "beautician", "florist", "erudite", "hatmaker", "storeowner",
        "banker", "collector", "hunter", "mayor", "mechanic", "professor",
        "usher", "royalguard", "royalguard_2", "farmer", "miner",
    }

    -- Wilba gifts load fix
    for _, prefab in ipairs(pigman_city) do
        AddPrefabPostInit("pigman_"..prefab, function(inst)
            local _oldOnSave = inst.OnSave
            inst.OnSave = function(inst, data)
                _oldOnSave(inst, data)
                data.daily_gift = inst.daily_gift
            end

            local _oldOnLoad = inst.OnLoad
            inst.OnLoad = function(inst, data)
                _oldOnLoad(inst, data)
                if data.daily_gift then
                    inst.daily_gift = data.daily_gift
                end
            end
        end)
    end
end

------------------------------------------------------------------------------------

local function CanTakeAmmo(inst, ammo, giver)

    return (ammo.components.inventoryitem ~= nil) and
            inst.components.trader.enabled and
            (
                inst.components.weapon.projectile == nil or
                (
                    inst.components.weapon.projectile == ammo.prefab and 
                    inst.components.inventory:GetItemInSlot(1).components.stackable and
                    inst.components.inventory:GetItemInSlot(1).components.stackable:RoomLeft() ~= 0
                )
            ) and
            not ammo.components.health and
            not ammo:HasTag("irreplaceable")
end

-- Fix a crash with wheller gun
AddPrefabPostInit("trusty_shooter", function(inst)
    inst.CanTakeItem = CanTakeAmmo
    inst.components.trader:SetAcceptTest(CanTakeAmmo)
end)

------------------------------------------------------------------------------------

-- Add aditional herd limit for Spider Monkeys
AddPrefabPostInit("spider_monkey_herd", function(inst_init)
    inst_init.components.periodicspawner:SetSpawnTestFn( function(inst)
        if not inst.components.herd then
            return false
        end

        if inst.components.herd:IsFull() then
            return false
        end

        local x,y,z = inst.Transform:GetWorldPosition()
        local ents = _G.TheSim:FindEntities(x,y,z, inst.components.herd.gatherrange, inst.components.herd.membertag and {inst.components.herd.membertag} or nil )
        return #ents < TUNING.ROCKYHERD_MAX_IN_RANGE
    end)
end)

------------------------------------------------------------------------------------

-- Fix Chester following Ro-bin Stone
AddPrefabPostInit("ro_bin_gizzard_stone", function(inst)
    inst:RemoveTag("chester_eyebone")
end)

------------------------------------------------------------------------------------

-- Fix missing crocodog tuning override in hamlet worlds.
require("tuning_override_sw").OVERRIDES["crocodog"] =
    {
        doit = 	function(difficulty)
            local hounded = _G.GetWorld().components.hounded
            if hounded then
                if difficulty == "never" then
                    hounded:SpawnModeNever()
                elseif difficulty == "always" then
                    hounded:SpawnModeHeavy()
                elseif difficulty == "often" then
                    hounded:SpawnModeMed()
                elseif difficulty == "rare" then
                    hounded:SpawnModeLight()
                end
            end
        end,
    }

------------------------------------------------------------------------------------

-- Remove the basket map icon from the ballon...
AddPrefabPostInit("deflated_balloon", function(inst)
    inst.MiniMapEntity = nil
end)

------------------------------------------------------------------------------------

-- Fix a incoerrent shadow in grabbing_vine idle.
AddStategraphPostInit("grabbing_vine", function(self)
    local _onenter = self.states["idle_up"].onenter
    self.states["idle_up"].onenter = function(inst)
        _onenter(inst)
        inst.shadowoff(inst)
    end
end)

------------------------------------------------------------------------------------

-- Navigadget sometimes bug, showing the last equip when unequipping it.
AddPrefabPostInit("wheeler_tracker", function(inst)
    local _onequipfn = inst.components.equippable.onequipfn
    inst.components.equippable:SetOnEquip(
        function(inst, owner, force)
            owner.AnimState:ClearOverrideSymbol("swap_object")
            _onequipfn(inst, owner, force)
        end
    )
end)