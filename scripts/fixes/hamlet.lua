
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
    local function TestForExtraTag(inst)
        local _TestFn = inst.components.creatureprox.testfn
        inst.components.creatureprox:SetTestfn(function(inst)
            return _TestFn(inst) and not inst:HasTag("trap_imune")
        end)
    end

    AddPrefabPostInit("pig_ruins_pressure_plate", TestForExtraTag)
    AddPrefabPostInit("pig_ruins_light_beam", TestForExtraTag) -- This tragger the spears 
    
    local function DontTriggerTraps(inst)
        inst:AddTag("trap_imune")
    end
    
    -- Dont trigger traps fix
    AddPrefabPostInit("pigghost", DontTriggerTraps)
    AddPrefabPostInit("abigail", DontTriggerTraps)
    AddPrefabPostInit("terrorbeak", DontTriggerTraps)
    AddPrefabPostInit("crawlinghorror", DontTriggerTraps)
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

AddPrefabPostInit("spider_monkey_herd", function(inst)
    -- Add aditional herd limit for Spider Monkeys
    inst.components.periodicspawner:SetSpawnTestFn(
        function(inst)
            if not (inst.components.herd and not inst.components.herd:IsFull()) then
                return false
            end

            local x,y,z = inst.Transform:GetWorldPosition()

            local ents = _G.TheSim:FindEntities(
                x,y,z, 
                inst.components.herd.gatherrange,
                inst.components.herd.membertag and {inst.components.herd.membertag} or nil
            )
            return #ents < TUNING.ROCKYHERD_MAX_IN_RANGE
        end
    )

    -- Find a new tree if the currently is removed.
    local _RefreshHomeTreeFn = inst.RefreshHomeTreeFn
    inst.RefreshHomeTreeFn = function(inst)
        if inst.homeTree and not inst.homeTree:IsValid() then
            inst.homeTree = nil
        end
        _RefreshHomeTreeFn(inst)
    end

    for periodic_task, _ in pairs(inst.pendingtasks) do
        if periodic_task.period == 5 then
            periodic_task.fn = inst.RefreshHomeTreeFn
        end
    end

    -- Spidermonkeys will no longer switch of tree after load. Thanks to: Faintly Macabre.
    inst.OnSave = function(inst, data)
        if inst.homeTree and inst.homeTree:IsValid() then
            data.homeTree = inst.homeTree.GUID
            return {inst.homeTree.GUID}
        end
    end

    inst.OnLoadPostPass = function(inst, ents, data)
        if data and data.homeTree and ents[data.homeTree] then
            inst.homeTree = ents[data.homeTree].entity
            inst.homeTree.spiderMonkeyHerd = inst

            for k, v in pairs(inst.components.herd.members) do
                if inst.homeTree then
                    k.components.knownlocations:RememberLocation("home", _G.Point(inst.homeTree.Transform:GetWorldPosition()), false)
                end
            end
        end
    end
end)

------------------------------------------------------------------------------------

-- Fixes missing crocodog tuning override in hamlet worlds.
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

------------------------------------------------------------------------------------

-- Now we can ressurect inside interiors properly.
local function FixInteriorRessurect(inst)
    local _doresurrect = inst.components.resurrector.doresurrect

    inst.components.resurrector.doresurrect = function(inst, dude)
        _doresurrect(inst, dude)
        _G.GetPlayer():DoTaskInTime(0, function()
            if _G.TheCamera.interior or inst.interior then
                _G.GetPlayer().Transform:SetRotation(0)
                local interiorSpawner = _G.GetWorld().components.interiorspawner
                interiorSpawner:PlayTransition(_G.GetPlayer(), nil, inst.interior, inst)			
            else		
                _G.GetPlayer().Transform:SetRotation(inst.Transform:GetRotation())
            end

            if not inst.interior then
                if _G.TheCamera.interior then
                    local interiorSpawner = _G.GetWorld().components.interiorspawner
                    interiorSpawner.exteriorCamera:SetDistance(12)
                else
                    _G.TheCamera:SetDistance(12)	
                end
            end
        end)
    end
end

AddPrefabPostInit("resurrectionstatue", FixInteriorRessurect)
AddPrefabPostInit("lifeplant", FixInteriorRessurect)

------------------------------------------------------------------------------------

-- Adds generic missing fishing symbols for relic 4 and 5.
local function RetriaveRelic(inst)
    inst.components.sinkable.swapsymbol = "fish03"
end

AddPrefabPostInit("relic_4", RetriaveRelic)
AddPrefabPostInit("relic_5", RetriaveRelic)

------------------------------------------------------------------------------------

-- Fixes a crash with burnt cook pots and smelters in interiors. Made by: Faintly Macabre.
local function FixCookPots(inst, component)
    local comp = component or "stewer"

    inst.returntointeriorscene = function (inst)
        if inst.components[comp] and inst.components[comp].cooking then
            inst.Light:Enable(true)
        else
            inst.Light:Enable(false)
        end
    end
end

AddPrefabPostInit("cookpot", FixCookPots)
AddPrefabPostInit("portablecookpot", FixCookPots)
AddPrefabPostInit("smelter", function(inst) FixCookPots(inst, "melter") end)

------------------------------------------------------------------------------------

local clawpalmtree_sufixs = {"", "_normal", "_tall", "_short"}

-- Removes the spawn of creatures when claw trees are ignited. 
-- This behavior is caused by a wrong copy of the rain forest trees file.
-- Made by: Faintly Macabre.

for _, sufix in ipairs(clawpalmtree_sufixs) do
    AddPrefabPostInit("clawpalmtree"..sufix, function(inst)
        inst.components.burnable.onignite = nil

        local _OnEntityWake = inst.OnEntityWake

        inst.OnEntityWake = function(inst)
            _OnEntityWake(inst)
            if inst.components.burnable then
                inst.components.burnable.onignite = nil
            end
        end
    end)
end

------------------------------------------------------------------------------------

-- Nettles's pickable component alredy save the time to produce.
-- Thanks to: Faintly Macabre.
AddPrefabPostInit("nettle", function(inst)
    inst.OnLoadPostPass = nil
    inst.OnSave = nil
    inst.OnLoad = nil

    -- Revert the Pause() call.
    inst.components.pickable.pause_time = 0
	inst.components.pickable.paused = false
end)

------------------------------------------------------------------------------------

-- Hides the snow layer from Shanty Shanty placer.
AddPrefabPostInit("playerhouse_city_placer", function(inst)
    inst.AnimState:Hide("snow")
end)

------------------------------------------------------------------------------------

-- Fix a incorrect lawnornament_6's position.
local setpeice = require("map/static_layouts/city_park_2")
setpeice.layers[2].objects[11].x = 128

------------------------------------------------------------------------------------

local tubertree_sufixs = {"", "_tall", "_short", "_burnt", "_stump"}

-- Fixes a lot of irregularities in tuber trees. Thanks to: Faintly Macabre.
for _, sufix in pairs(tubertree_sufixs) do
    AddPrefabPostInit("tubertree"..sufix, function(inst)
        if sufix == "_stump" then
            inst:RemoveComponent("hackable")
        end

        local hackable = inst.components.hackable
        
        local _onregenfn = hackable.onregenfn
        local _onhackedfn = hackable.onhackedfn
        local _OnLoad = inst.OnLoad
        local _startbloom = inst.components.bloomable.bloomfunction
        
        hackable:SetOnRegenFn(function(inst)
            if not inst:hasTag("burnt") then
                _onregenfn(inst)
            end
        end)

        if not inst:HasTag("burnt") and not inst:HasTag("stump") then
            hackable.onhackedfn = function(inst)
                _onhackedfn(inst)
                if math.random() > .5 then
                    inst.AnimState:PushAnimation(inst.anims.sway1, true)
                else
                    inst.AnimState:PushAnimation(inst.anims.sway2, true)
                end
            end
        end

        inst.OnLoad = function (inst, data)
            if not data then return end

            _OnLoad(inst, data)

            if not data.burnt then
                if data.stump then
                    inst:RemoveComponent("hackable")
                else
                    inst:RemoveTag("stump")
                    hackable.canbehacked = true
                    hackable.hasbeenhacked = false
                end
            end

            if not data.stump then
                for i, slot in ipairs(inst.tuberslots) do
                    inst.AnimState:Hide("tubers"..slot)
                end

                for i=1, inst.tubers do
                    inst.AnimState:Show("tubers"..inst.tuberslots[i])
                end
            end
        end

        inst.components.bloomable:SetStartBloomFn(function(inst)
            if hackable and not inst:HasTag("burnt") then
                _startbloom(inst)
            end
        end)
    end)
end