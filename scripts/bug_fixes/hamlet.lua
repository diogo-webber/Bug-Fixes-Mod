
if GetConfig("rain") then
    -- Interiors issue - Hurricane Storm Fix
    AddComponentPostInit("seasonmanager", function(self)
        local _StartHurricaneStorm = self.StartHurricaneStorm
        function self:StartHurricaneStorm(duration_override, disablehail, dont_reset)
            if not dont_reset then 
                _StartHurricaneStorm(self, duration_override, disablehail)
                return
            end

            if not self:IsHurricaneStorm() then
                self.hurricane = true
                self:StartPrecip(true)
                self.inst:PushEvent("hurricanestart")
            end
        end

        local _StopHurricaneStorm = self.StopHurricaneStorm
        function self:StopHurricaneStorm(continue)
            if not continue then
                _StopHurricaneStorm(self)
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
    end, GetWorld())
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

    -- Wilba gifts load fix.
    for _, prefab in ipairs(pigman_city) do
        AddPrefabPostInit("pigman_"..prefab, function(inst)
            local _OnSave = inst.OnSave
            inst.OnSave = function(inst, data)
                _OnSave(inst, data)
                data.daily_gift = inst.daily_gift
            end

            local _OnLoad = inst.OnLoad
            inst.OnLoad = function(inst, data)
                _OnLoad(inst, data)
                if data and data.daily_gift then
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
                not inst.components.inventory:GetItemInSlot(1).components.stackable:IsFull()
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

-- Trusty_shooter will aceppt everything in the Load Prompt.
local GIVE_fn = ACTIONS.GIVE.fn
ACTIONS.GIVE.fn = function(act)
    if act.target:HasTag("hand_gun") then
        if act.target.components.trader then
            act.target.components.trader:AcceptGift(act.doer, act.invobject)
            return true
        end
    end
    return GIVE_fn(act)
end

AddComponentPostInit("inventoryitem", function(self)    
    local _CollectUseActions = self.CollectUseActions
    function self:CollectUseActions(doer, target, actions)
        if target:HasTag("hand_gun") then
            if target.components.trader:CanAccept(self.inst, doer) then
                table.insert(actions, ACTIONS.GIVE)
            end
        end

        return _CollectUseActions(self, doer, target, actions)
    end
end)

------------------------------------------------------------------------------------

local function SpiderMonkeySpawnTest(inst)
    if not (inst.components.herd and not inst.components.herd:IsFull()) then
        return false
    end

    local x,y,z = inst.Transform:GetWorldPosition()

    local ents = TheSim:FindEntities(
        x,y,z, 
        inst.components.herd.gatherrange,
        inst.components.herd.membertag and {inst.components.herd.membertag} or nil
    )
    return #ents < TUNING.ROCKYHERD_MAX_IN_RANGE
end

local function SpiderMonkeyHerdOnLoadPostPass(inst, ents, data)
    if data and data.homeTree and ents[data.homeTree] then
        inst.homeTree = ents[data.homeTree].entity
        inst.homeTree.spiderMonkeyHerd = inst

        for k, v in pairs(inst.components.herd.members) do
            if inst.homeTree then
                k.components.knownlocations:RememberLocation("home", Point(inst.homeTree.Transform:GetWorldPosition()), false)
            end
        end
    end
end

local function SpiderMonkeyHerdOnSave(inst, data)
    if inst.homeTree and inst.homeTree:IsValid() then
        data.homeTree = inst.homeTree.GUID
        return {inst.homeTree.GUID}
    end
end

AddPrefabPostInit("spider_monkey_herd", function(inst)
    -- Add aditional herd limit for Spider Monkeys
    inst.components.periodicspawner:SetSpawnTestFn(SpiderMonkeySpawnTest)

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
    inst.OnSave = SpiderMonkeyHerdOnSave
    inst.OnLoadPostPass = SpiderMonkeyHerdOnLoadPostPass
end)

------------------------------------------------------------------------------------

-- Fixes missing crocodog tuning override in hamlet worlds.
require("tuning_override_sw").OVERRIDES["crocodog"] =
    {
        doit = 	function(difficulty)
            local hounded = GetWorld().components.hounded
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
    inst.MiniMapEntity:SetEnabled(false)
end)

------------------------------------------------------------------------------------

-- Fix a incoerrent shadow in grabbing_vine idle.
AddStategraphPostInit("grabbing_vine", function(sg)
    Hooks.sg.state.onenter.Post(sg, "idle_up", function(inst, arg)
        inst:shadowoff()
    end)
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
        TheCamera:Snap()
        
        GetPlayer():DoTaskInTime(0, function()
            if TheCamera.interior or inst.interior then
                GetPlayer().Transform:SetRotation(0)
                local interiorSpawner = GetWorld().components.interiorspawner
                interiorSpawner:PlayTransition(GetPlayer(), nil, inst.interior, inst)			
            else		
                GetPlayer().Transform:SetRotation(inst.Transform:GetRotation())
            end

            if not inst.interior then
                if TheCamera.interior then
                    local interiorSpawner = GetWorld().components.interiorspawner
                    interiorSpawner.exteriorCamera:SetDistance(12)
                else
                    TheCamera:SetDistance(12)	
                end
            end
        end)
    end
end

AddPrefabPostInit("resurrectionstone", FixInteriorRessurect)
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

local states = {"play_flute", "play_horn", "play_bell", "use_fan", "map", "toolbroke"}
    
-- Fixes ghost carry arm for Wilba in Werewilba form.
AddStategraphPostInit("wilson", function(sg)
    for _, state in ipairs(states) do
        Hooks.sg.state.onexit.Post(sg, state, function(inst, arg) 
            if inst.were then
                inst.AnimState:Hide("ARM_carry") 
                inst.AnimState:Show("ARM_normal")
            end
        end)
    end
end)

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
        local _DropLootPrefab = inst.components.lootdropper.DropLootPrefab

        hackable:SetOnRegenFn(function(inst)
            if not inst:HasTag("burnt") then
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
            
            -- Fixes a weird situation where tubers > maxtubers [Crash].
            if data.tubers then
                inst.tubers = math.min(data.tubers, inst.maxtubers)
            end

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
        
        -- Give the loot the same colour of the tree.
        function inst.components.lootdropper:DropLootPrefab(...)
            local loot = _DropLootPrefab(self, ...)

            if self.inst.AnimState and loot.AnimState then
                loot.AnimState:SetMultColour(self.inst.AnimState:GetMultColour())
            end

            return loot
        end
    end)
end

------------------------------------------------------------------------------------

local function spawnFixer(inst, old_fn)
    local x,y,z = inst.Transform:GetWorldPosition()
    local fixers = TheSim:FindEntities(x,y,z, 30, {"fixer"})
    local pigs = TheSim:FindEntities(x,y,z, 40, {"city_pig"})

    -- Only spawn the mechanic pig if the entity is in a "city".
    if #fixers > 0 or #pigs >= 5 then 
        old_fn(inst) -- Pig alredy exist, go fix it!
    end

    -- if _spawnFixer create the task, re-create its with the new timer.
    if inst.task then
        -- From ~10-12 seconds to 30-60 seconds.
        local new_delay = TUNING.SEG_TIME + (math.random() * TUNING.SEG_TIME)

        if #fixers > 0 then -- Pig alredy exist, go fix it!
            new_delay = 10
        end

        inst.task:Cancel()
        inst.task = nil
        inst.task = inst:DoTaskInTime(new_delay, function() spawnFixer(inst, old_fn) end)
    end
end

local function reconstruction_project_displaynamefn(inst)
    local name = inst.construction_prefab:find("topiary") and "topiary" or inst.construction_prefab
    local prefix = inst.reconstruction_stages[1].anim == "burnt" and "Burnt " or "Broken "
    return prefix .. STRINGS.NAMES[string.upper(name)]
end

AddPrefabPostInit("reconstruction_project", function(inst)
    -- Can be breaked by city hammer:
    --inst:AddTag("fixable") --TODO

    if GetConfig("pigfixer") then
        local _spawnFixer = inst.task.fn

        inst.task:Cancel()
        inst.task = nil
        inst.task = inst:DoTaskInTime(5, function() spawnFixer(inst, _spawnFixer) end)
    end

    -- reconstruction_project have his own quotes.
    inst:DoTaskInTime(0.3, function()
        inst.nameoverride = nil
    end)

    -- Fixes the missing name after load and add a sufix.
    inst.displaynamefn = reconstruction_project_displaynamefn
end)

------------------------------------------------------------------------------------

local function ReworkPlantStruture(inst)
    inst.AnimState:OverrideSymbol("snow", "", "")

    if not GetConfig("cityplants") then return end
    
    local _onwork = inst.components.workable.onwork
    inst.components.workable:SetOnWorkCallback(function(inst, worker)
        local fx = SpawnPrefab("robot_leaf_fx")
        local x, y, z= inst.Transform:GetWorldPosition()
        fx.Transform:SetPosition(x, y + math.random()*0.5, z)
                
        inst.SoundEmitter:PlaySound("dontstarve_DLC002/common/vine_hack")
    
        _onwork(inst, worker)
    end)

    local _onfinish = inst.components.workable.onfinish
    inst.components.workable:SetOnFinishCallback(function(inst, worker)
        local x, y, z = inst.Transform:GetWorldPosition()
        for i=1,math.random(3,4) do
            local fx = SpawnPrefab("robot_leaf_fx")
            fx.Transform:SetPosition(x + (math.random()*2) , y+math.random()*0.5, z + (math.random()*2))
            if math.random() < 0.5 then
                fx.Transform:SetScale(-1,1,-1)
            end
        end
        inst.SoundEmitter:PlaySound("dontstarve/common/destroy_straw")
        inst.SoundEmitter:OverrideVolumeMultiplier(0)
        _onfinish(inst, worker)
        inst.SoundEmitter:OverrideVolumeMultiplier(1)
    end)
end

for n=1, 7 do
    -- Each Lawnornament have his own name. Also add some fx.
    -- Remove the bugged snow symbol that bug the mouse over.
    AddPrefabPostInit("lawnornament_"..n, function(inst)
        inst.nameoverride = nil
        inst.components.inspectable.nameoverride = "lawnornament"
        if n ~= 7 then
            ReworkPlantStruture(inst)
        end
    end)
end

for n=1, 4 do
    -- Fix missing name for broken/burnt topyaries, make them burnable and add some fx.
    -- Remove the bugged snow symbol that bug the mouse over.
    AddPrefabPostInit("topiary_"..n, function(inst)
        inst.components.fixable:SetPrefabName("topiary")

        if n == 3 or n == 4 then
            MakeLargeBurnable(inst, nil, nil, true)
            MakeLargePropagator(inst)
        else
            MakeMediumBurnable(inst, nil, nil, true)
            MakeMediumPropagator(inst)
        end

        inst:ListenForEvent("burntup", inst.Remove)

        ReworkPlantStruture(inst)
    end)
end

------------------------------------------------------------------------------------

-- Make Hedges burnable.
for _, sufix in ipairs({"layered", "block", "cone"}) do
    AddPrefabPostInit("hedge_"..sufix, function(inst)
        MakeMediumBurnable(inst, nil, nil, true)
        MakeMediumPropagator(inst)
        inst:ListenForEvent("burntup", inst.Remove)
    end)
end

------------------------------------------------------------------------------------

-- Dry the player at end.
AddPrefabPostInit("living_artifact", function(inst)
    local _Revert = inst.Revert
    inst.Revert = function(inst)
        _Revert(inst)

        local player = GetPlayer()
        if player.components.moisture then
            player.components.moisture.moisture = 0
        end

        if player.components.temperature then
            player.components.temperature:SetTemperature(TUNING.STARTING_TEMP)
        end
    end
end)

------------------------------------------------------------------------------------

local doors = {
    "wood",
    "stone",
    "organic",
    "iron",
    "pillar",
    "curtain",
    "round",
    "plate"
}

for _, door in pairs(doors) do
    -- Fixes a wrong funtion name on doors.
    AddPrefabPostInit(door.."_door", function(inst)
        inst.components.workable.canbeworkedby = inst.components.workable.canbeworkedbyfn
    end)
end

------------------------------------------------------------------------------------

-- Fixes mouse over effect missing in childrens for Aporkalypse Calendar.
AddPrefabPostInit("aporkalypse_clock1", function(inst)
    inst:DoTaskInTime(.1, function()
        inst.highlightchildren = {inst.parent}

        for ent, _ in pairs(inst.parent.children) do
            if not ent.prefab:find("plate") then
                table.insert(inst.highlightchildren, ent)
            end
        end
    end)
end)

------------------------------------------------------------------------------------

local ignored_prefabs = {"pig_ruins_spear_trap", "leif", "mangrovetree", "treeguard"}

-- Add the possibility for mysteries in all trees, stalagmites and Magma Piles.
AddPrefabPostInitAny(function(inst)
    if inst:HasTag("tree") and inst.prefab and (inst.components and not inst.components.mystery) then
        for _, prefab in pairs(ignored_prefabs) do
            if inst.prefab:find(prefab) then
                return
            end
        end
        
        inst:AddComponent("mystery")
    end
end)

local stages = {"", "_low", "_med", "_full"}

for _, pile in ipairs({"magmarock", "magmarock_gold", "stalagmite", "stalagmite_tall"}) do
    for _, stage in ipairs(stages) do
        AddPrefabPostInit(pile..stage, function(inst)
            inst:AddComponent("mystery")
        end)
    end
end

local function mystery_AddReward(self, reward)
    local color = 0.5 + math.random() * 0.5
    self.inst.AnimState:SetMultColour(color-0.15, color-0.15, color, 1)

    self.inst:AddTag("mystery")
    self.reward = reward or self:GenerateReward()

    self.inst:ListenForEvent("onremove", function()
        if self.inst:HasTag("mystery") and self.inst.components.mystery.investigated then
            self.inst:RemoveTag("mystery")
            self.inst.components.lootdropper:SpawnLootPrefab(self.reward)
        end
    end)
end

-- Fixes the duplicate loot... Klei and her code...
AddComponentPostInit("mystery", function(self)
    self.AddReward = mystery_AddReward
end)

------------------------------------------------------------------------------------

-- Apply the special gas mask voice.
AddPrefabPostInit("gasmaskhat", function(inst)
    inst:AddTag("muffler")
end)

------------------------------------------------------------------------------------

local function RocStatesMounted(sg, event)
    Hooks.sg.handler.Event(sg, event, function(inst, data, _old)
        if not GetPlayer().components.rider:IsRiding() then
            _old(inst, data)
        end
    end)
end

-- BFB cannot grab the player if mounted.
AddStategraphPostInit("roc_head", function(sg)
    RocStatesMounted(sg,"gobble")
    RocStatesMounted(sg, "bash")
end)

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

------------------------------------------------------------------------------------

-- Fixes a crash caused by the global root trunk entity being destroyed.
AddPrefabPostInit("roottrunk", function(inst)
    inst:RemoveComponent("workable")
    inst:RemoveComponent("burnable")
    inst:RemoveComponent("propagator")
end)

------------------------------------------------------------------------------------

-- Fixes a crash related to build house doors with space bar.
AddComponentPostInit("playercontroller", function(self)
    local _DoActionButton = self.DoActionButton
    function self:DoActionButton()
        if self.placer_recipe and self.placer and self.placer.components.placer.can_build then
            local modifydata = self.placer.components.placer.modifyfn and self.placer.components.placer.modifyfn(self.placer) or nil
            self.inst.components.builder:MakeRecipe(self.placer_recipe, Vector3(self.placer.Transform:GetWorldPosition()), self.placer:GetRotation(), nil, modifydata)
            return true
        end

        return _DoActionButton(self)
    end
end)

------------------------------------------------------------------------------------

-- Fixes the shop keeper from getting stuck in pedestals :)
AddStategraphPostInit("pig", function(sg)
    sg.states["run"].onupdate = function(inst)
        if inst:HasTag("shopkeep") and inst.changestock then
            inst.components.locomotor:ResetPath()
        end
    end
end)

local SGwilson = require("stategraphs/SGwilson")
package.loaded["stategraphs/SGwilson"] = nil -- Unload the file

-- Wormwood uses the correct anims now.
AddStategraphPostInit("wilsonboating", function(sg)
    for i, state in ipairs({"form_log", "fertilize", "fertilize_short"}) do
        sg.states[state] = deepcopy(SGwilson.states[state])
        AddTagToState(sg, state, "boating")
    end

    Hooks.sg.state.ToggleBoat(sg, "fertilize")
    Hooks.sg.state.ToggleBoat(sg, "fertilize_short")

    Hooks.sg.handler.Action(sg, "BUILD", function(inst, action, _fn)
        if not inst.sg:HasStateTag("busy") and 
            action.doer and
            action.doer.prefab == "wormwood" and
            action.recipe and
            action.recipe == "livinglog" then
                return "form_log"
        end

        return _fn(inst, action)
    end)

    Hooks.sg.handler.Action(sg, "HEAL", function(inst, action, _fn)
        if action.invobject and action.invobject:HasTag("heal_fertilize") then
            return "fertilize"
        end

        return _fn(inst, action)
    end)

    Hooks.sg.handler.Action(sg, "FERTILIZE", function(inst, action, _fn)
        if inst:HasTag("healonfertilize") and not action.target then
            return "fertilize_short"
        end

        return _fn(inst, action)
    end)
end)

------------------------------------------------------------------------------------

local function HideLayers(anim)
    local rays = {1, 2, 3}
    for i = 1, #rays, 1 do
        anim:Hide("joint"..i)
        anim:Hide("pipe"..i)
    end
end

AddPrefabPostInit("water_pipe", function(inst)
    -- Sprinker Pipes don't block the Sprinker mouse over after load anymore.
    inst:AddTag("NOCLICK")

    -- Don't block placement.
    inst:AddTag("NOBLOCK")

    -- The saved symbols weren't really used...
    local _OnLoad = inst.OnLoad
    function inst:OnLoad(data)
        _OnLoad(inst, data)

        local anim = inst.AnimState

        HideLayers(anim)
        anim:Show(inst.jointLayerShown)
        anim:Show(inst.pipeLayerShown)
    end
end)

------------------------------------------------------------------------------------

-- Amphibious Snakes will target the tree chopper as intended.
AddPrefabPostInit("snake_amphibious", function(inst)
    inst:AddTag("snake_amphibious")
end)

------------------------------------------------------------------------------------

for _, suffix in pairs({
    "",
    "_normal",
    "_tall",
    "_short"
}) do
    -- Removes the spawn of mobs when ignited (It spawns SW snakes and it
    -- doesn't make much sense for the tree to be infested by 2 mobs at the same time.)
    AddPrefabPostInit("spider_monkey_tree"..suffix, function(inst)
        local _onignite = inst.components.burnable.onignite

        local function NewIgnite(inst)
            inst.flushed = true
            _onignite(inst)
        end

        inst.components.burnable:SetOnIgniteFn(NewIgnite)

        local _OnEntityWake = inst.OnEntityWake
        function inst.OnEntityWake(inst)
            _OnEntityWake(inst)

            if  not inst:HasTag("burnt") and
                not inst:HasTag("fire")  and
                not inst:HasTag("stump")
            then
                inst.components.burnable:SetOnIgniteFn(NewIgnite)
            end
        end
    end)
end

------------------------------------------------------------------------------------

-- TODO: This fix needs verification [Leonidas IV]

--[[Fixes child spawning in the void when the child spawner is located in an interior. By https://github.com/L-Benjamin
AddComponentPostInit("childspawner", function(self)
    local _SpawnChild = self.SpawnChild
    function self:SpawnChild(target, prefab, radius, tries)
        if not self.inst:IsInLimbo() then
            return _SpawnChild(self)
        end

        if not self:CanSpawn() then
            return
        end

        tries = tries or 1
        if tries < 100 then
            self.inst:DoTaskInTime(5, function(inst)
                inst.components.childspawner:SpawnChild(target, prefab, radius, tries + 1)
            end)
        end
    end
end)

AddComponentPostInit("spawner", function(self)
    local _ReleaseChild = self.ReleaseChild
    function self:ReleaseChild(tries)
        if not self.inst:IsInLimbo() then
            return _ReleaseChild(self)
        end

        tries = tries or 1
        if tries < 100 then
            self.inst:DoTaskInTime(5, function(inst)
                inst.components.spawner:ReleaseChild(tries + 1)
            end)
        end
    end
end)]]

------------------------------------------------------------------------------------

-- Fixes the pig queen obnoxiously following Wilba sometimes. By: https://github.com/L-Benjamin
AddPrefabPostInit("pigman_queen", function(inst)
    inst.daily_gift = math.huge
end)

------------------------------------------------------------------------------------

-- Fixes infinity pig fiesta after load.
-- GetClock():GetTotalTime() is 0 on load...
AddComponentPostInit("aporkalypse", function(self)
    local _OnSave = self.OnSave
    function self:OnSave(data)
        data = _OnSave(self, data)

        data.fiesta_elapsed = GetClock():GetTotalTime() - self.fiesta_begin_date

        return data
    end

    local _OnLoad = self.OnLoad
    function self:OnLoad(data)
        _OnLoad(self, data)

        if self.fiesta_task then
            self.fiesta_task:Cancel()

            local duration = self.fiesta_duration - (data.fiesta_elapsed or 0)
            self.fiesta_task = self.inst:DoTaskInTime(duration, function() self:EndFiesta() end)
        end
    end
end)