Assets = {
    -- Teleblella effects and sounds + Thumper Sounds.
    Asset("ANIM", "anim/player_wagstaff.zip"),
    Asset("SOUNDPACKAGE", "sound/dontstarve_wagstaff.fev"),
    Asset("SOUND", "sound/dontstarve_wagstaff.fsb"),
    
    -- Bundle Fx
    Asset("ANIM", "anim/player_wrap_bundle.zip"),
}

------------------------------------------------------------------------------------

-- Teleblella effects + Bundle Fx for everybody.
AddPlayerPostInit(function(inst)
    inst.AnimState:AddOverrideBuild("player_wagstaff")
    inst.AnimState:AddOverrideBuild("player_wrap_bundle")
end)

------------------------------------------------------------------------------------

STRINGS.ACTIONS.ACTIVATE.OPEN = "Open"
STRINGS.ACTIONS.ACTIVATE.CLOSE = "Close"

STRINGS.ACTIONS.DEPLOY.FENCE = "Build Fence"
STRINGS.ACTIONS.DEPLOY.GATE = "Build Gate"

-- Fix "Activate" string on fence/gate toggle.
AddPrefabPostInit("fence_gate", function(inst)
    inst.components.activatable.getverb = function(inst, doer)
        return inst.isopen and "CLOSE" or "OPEN"
    end
end)

-- Fix "plant" string on fence/gate deploy.
local _ACTIONS_DEPLOY_strfn = _G.ACTIONS.DEPLOY.strfn
_G.ACTIONS.DEPLOY.strfn = function(act)
    if act.invobject then
        return 
            act.invobject:HasTag("gatebuilder") and "GATE" or 
            act.invobject:HasTag("fencebuilder") and "FENCE" or
            _ACTIONS_DEPLOY_strfn(act)
    end
end

------------------------------------------------------------------------------------

-- Slot Detail Screen ESC Fix
local LoadGameScreen = _G.require("screens/loadgamescreen")
local SlotDetailsScreen = _G.require("screens/slotdetailsscreen")

local function FixedOnControl(self, control, down)
    if SlotDetailsScreen._base.OnControl(self, control, down) then return true end

    if control == _G.CONTROL_CANCEL and not down then
        _G.EnableAllDLC()
        _G.TheFrontEnd:PopScreen(self)
        return true
    end
end

function LoadGameScreen:OnControl(control, down)
    return FixedOnControl(self, control, down)
end

function SlotDetailsScreen:OnControl( control, down )
    return FixedOnControl(self, control, down)
end

------------------------------------------------------------------------------------

local function FixCompanions(inst)
    if inst.prefab ~= "chester" then
        inst:RemoveTag("chester")
    else
        inst:DoTaskInTime(1.5, function(inst)
            if not _G.TheSim:FindFirstEntityWithTag("chester_eyebone2") then
                inst:Remove()
            end
        end)
    end

    inst:DoTaskInTime(0, function(inst)
        local next_inst = _G.TheSim:FindFirstEntityWithTag(inst.prefab)
        if next_inst and next_inst ~= inst then
            print(inst, "is a duplicate! Removing it...")
            inst:Remove()
        end
    end)
end

-- Fix for companions duplicates
AddPrefabPostInit("chester", FixCompanions)
AddPrefabPostInit("packim", FixCompanions)
AddPrefabPostInit("ro_bin", FixCompanions)

AddPrefabPostInit("chester_eyebone", function(inst)
    inst:AddTag("chester_eyebone2")
end)

------------------------------------------------------------------------------------

-- Makes bundle more similar to DST:

local function spawnfx()
    local inst = _G.CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()

    inst.AnimState:SetBank("bundle")
    inst.AnimState:SetBuild("bundle")
    inst.AnimState:PlayAnimation("unwrap")

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst:ListenForEvent("animover", inst.Remove)
    inst.persists = false

    return inst
end

_G.ACTIONS.UNWRAP.priority = 3

AddPrefabPostInit("bundle", function(inst)
    inst.components.unwrappable:SetOnUnwrappedFn(function(inst, pos, doer)
        if inst.burnt then
            _G.SpawnPrefab("ash").Transform:SetPosition(pos:Get())
        else
            local waxpaper = _G.SpawnPrefab("waxpaper")
            waxpaper.Transform:SetPosition(pos:Get())
            waxpaper.components.inventoryitem:OnDroppedBundle() --Custom method
                        
            if waxpaper.components.moisturelistener then
                local bundle_moisture = inst.components.moisturelistener:GetMoisture()
                local bundle_iswet = inst.components.moisturelistener:IsWet()

                waxpaper.components.moisturelistener.moisture = bundle_moisture
                waxpaper.components.moisturelistener.wet = bundle_iswet
            end
            
            spawnfx().Transform:SetPosition(pos:Get())
        end

        if doer ~= nil and doer.SoundEmitter ~= nil then
            doer.SoundEmitter:PlaySound("dontstarve/common/craftable/bundles/packaged")
        end
        inst:Remove()
    end)
end)

-- Test if the item is irreplaceable
AddPrefabPostInit("bundle_container", function(inst)
    local _itemtestfn = inst.components.container.itemtestfn
    inst.components.container.itemtestfn = function(inst, item, slot)
        local _return = _itemtestfn(inst, item, slot)

        return _return and not item:HasTag("irreplaceable")
    end
end)

AddComponentPostInit("unwrappable", function(self)
    function self:Unwrap(doer)
        local pos = self.inst:GetPosition()
        pos.y = 0
        if self.itemdata ~= nil then
            if doer ~= nil and
                self.inst.components.inventoryitem ~= nil and
                self.inst.components.inventoryitem:GetGrandOwner() == doer then
                local doerpos = doer:GetPosition()
                local offset = _G.FindWalkableOffset(doerpos, doer.Transform:GetRotation() * _G.DEGREES, 1, 8, false, true)
                if offset ~= nil then
                    pos.x = doerpos.x + offset.x
                    pos.z = doerpos.z + offset.z
                else
                    pos.x, pos.z = doerpos.x, doerpos.z
                end
            end

            for i, v in ipairs(self.itemdata) do
                local item = _G.SpawnPrefab(v.prefab)
                if item ~= nil and item:IsValid() then
                    if item.Physics ~= nil then
                        item.Physics:Teleport(pos:Get())
                    else
                        item.Transform:SetPosition(pos:Get())
                    end
                    item:SetPersistData(v.data)
                    if item.components.inventoryitem ~= nil then
                        item.components.inventoryitem:OnDroppedBundle() -- Custom method
                    end
                end
            end
            self.itemdata = nil
        end

        if self.onunwrappedfn ~= nil then
            self.onunwrappedfn(self.inst, pos, doer)
        end
    end
end)

local bundle_anim = GetConfig("bundle_fx") and "wrap" or "build"

-- Make bundling states more like in DST, with custom effects + some fixes to timing
AddStategraphPostInit("wilson", function(self)
    local bundle_state = self.states["bundle"]

    table.insert(bundle_state.tags, "nodangle")

    bundle_state.onenter = function(inst)
        inst.components.locomotor:Stop()
        inst.SoundEmitter:PlaySound("dontstarve/wilson/make_trap", "make")
        inst.AnimState:PlayAnimation(bundle_anim.."_pre")
        inst.AnimState:PushAnimation(bundle_anim.."_loop", true)
        inst.sg:SetTimeout(.7)
    end

    bundle_state.timeline = {
        TimeEvent(7 * FRAMES, function(inst)
            inst.sg:RemoveStateTag("busy")
        end),
        TimeEvent(9 * FRAMES, function(inst)
            inst:PerformBufferedAction()
        end),
    }

    bundle_state.ontimeout = function(inst)
        inst.SoundEmitter:KillSound("make")
        inst.AnimState:PlayAnimation(bundle_anim.."_pst")
    end

    bundle_state.events = {
        EventHandler("animqueueover", function(inst)
            if inst.AnimState:AnimDone() then
                inst.sg:GoToState("idle")
            end
        end),
    }

    bundle_state.onexit = function(inst)
        if not inst.sg.statemem.bundling then
            inst.SoundEmitter:KillSound("make")
        end
    end

    ---------------------------------------------------

    local bundling_state = self.states["bundling"]

    bundling_state.onenter = function(inst)
        inst.components.locomotor:Stop()
        if not inst.SoundEmitter:PlayingSound("make") then
            inst.SoundEmitter:PlaySound("dontstarve/wilson/make_trap", "make")
        end
        if not inst.AnimState:IsCurrentAnimation(bundle_anim.."_loop") then
            inst.AnimState:PlayAnimation(bundle_anim.."_loop", true)
        end
    end

    bundling_state.onupdate = function(inst)
        if not _G.CanEntitySeeTarget(inst, inst) then
            inst.AnimState:PlayAnimation(bundle_anim.."_pst")
            inst.sg:GoToState("idle", true)
        end
    end

    ---------------------------------------------------

    local bundle_pst_state = self.states["bundle_pst"]

    bundle_pst_state.onenter = function(inst)
        inst.components.locomotor:Stop()
        if not inst.SoundEmitter:PlayingSound("make") then
            inst.SoundEmitter:PlaySound("dontstarve/wilson/make_trap", "make")
        end
        if not inst.AnimState:IsCurrentAnimation(bundle_anim.."_loop") then
            inst.AnimState:PlayAnimation(bundle_anim.."_loop", true)
        end
        inst.sg:SetTimeout(.7)
    end

    bundle_pst_state.ontimeout = function(inst)
        inst.sg:RemoveStateTag("busy")
        inst.AnimState:PlayAnimation(bundle_anim.."_pst")
        inst.sg.statemem.finished = true
        inst.components.bundler:OnFinishBundling()
    end
end)

------------------------------------------------------------------------------------

-- Make a custom method with HAM's OnDropped, to use setspeed param in bundle
AddComponentPostInit("inventoryitem", function(self)
    function self:OnDroppedBundle()
        if not self.inst:IsValid() then
            return
        end
        
        local x,y,z = self.inst.Transform:GetWorldPosition()

        local dropper = nil
        if self.owner then
            dropper = self.owner
            x,y,z = self.owner.Transform:GetWorldPosition()
        end

        self:OnRemoved()

        self.inst.Transform:SetPosition(x,y,z)
        self.inst.Transform:UpdateTransform()

        if self.inst.Physics then
            if not self.nobounce then
                y = y + 1
                self.inst.Physics:Teleport(x,y,z)
            end

            local vel = _G.Vector3(0, 5, 0)
            
            local speed = 0.5 + math.random()          
            local angle = math.random()*2*_G.PI
            vel.x = speed*math.cos(angle)
            vel.y = speed*3
            vel.z = speed*math.sin(angle)
            
            if self.nobounce then
                vel.y = 0
            end
            self.inst.Physics:SetVel(vel.x, vel.y, vel.z)
        end

        if self.ondropfn then
            self.ondropfn(self.inst, dropper)
        end
        self.inst:PushEvent("ondropped")
        
        if self.inst.components.propagator then
            self.inst.components.propagator:Delay(5)
        end

        if self.OnStartFalling then
            self:OnStartFalling()
        end
    end
end)

------------------------------------------------------------------------------------

-- Fix a incoerent shadow in telebrella anim
local function FixTelebrellaShadow(self)
    local telebrella_state = self.states["telebrella_finish"]
    local _onenter = telebrella_state.onenter
    local _onexit = telebrella_state.onexit

    telebrella_state.onenter = function(inst, timeout)
        _onenter(inst, timeout)
        inst.DynamicShadow:Enable(false)
    end

    telebrella_state.onexit = function(inst)
        _onexit(inst)
        inst.DynamicShadow:Enable(true)
    end
end

AddStategraphPostInit("wilson", FixTelebrellaShadow)
AddStategraphPostInit("wilsonboating", FixTelebrellaShadow)

------------------------------------------------------------------------------------

-- Make telebrella be removed only after animation.
AddPrefabPostInit("telebrella", function(inst)
    inst.components.finiteuses:SetOnFinished(function(inst)
        inst:DoTaskInTime(1.2, inst.Remove)
    end)
end)

------------------------------------------------------------------------------------

if GetConfig("treeseed") then
    local trees = {
        "pinecone",
        "acorn",
        "coconut",
        "jungletreeseed",
        "burr",
        "teatree_nut",
    }

    -- Fix the tree fire exploit, because chest growing trees isn't cool
    for _, tree in ipairs(trees) do
        AddPrefabPostInit(tree, function(inst)
            local _onextinguish_fn = inst.event_listeners and inst.event_listeners["onextinguish"] and inst.event_listeners["onextinguish"][inst][1]
            if _onextinguish_fn then
                inst.event_listeners["onextinguish"][inst][1] = function(inst)
                    if not inst.components.inventoryitem then
                        _onextinguish_fn(inst)
                    end
                end
            end
        end)
    end
end

------------------------------------------------------------------------------------

-- Delay 3 frames to show the ARM_carry to don't glith the item_out anim
AddComponentPostInit("equippable", function(self)
    local _Equip = self.Equip
    function self:Equip(owner, slot)
        local _onequipfn = self.onequipfn
        
        self.onequipfn = nil
        _Equip(self, owner, slot)
        self.onequipfn = _onequipfn
        
        if self.onequipfn then
            owner:DoTaskInTime(3*FRAMES, function()
                self.onequipfn(self.inst, owner, self.swapbuildoverride or nil)
                self.inst:PushEvent("equipped", {owner=owner, slot=slot}) -- For work with the skins mod.
            end)
        end
    end
end)

------------------------------------------------------------------------------------

-- Tornado now ignore the spider web (very buggy without this)
AddPrefabPostInit("tornado", function(inst)
    inst.components.locomotor.pathcaps = { ignorecreep = true }
end)

------------------------------------------------------------------------------------

-- No more wood sound :)
local function SkeletonTweak(inst)
    inst.components.workable:SetWorkLeft(3)
    inst.components.workable:SetOnFinishCallback(function(inst)
        inst.components.lootdropper:DropLoot()
        _G.SpawnPrefab("collapse_small").Transform:SetPosition(inst:GetPosition():Get())
        inst.SoundEmitter:PlaySound("dontstarve/wilson/rock_break")
        inst:Remove()
    end)
end

AddPrefabPostInit("skeleton", SkeletonTweak)
AddPrefabPostInit("skeleton_player", SkeletonTweak)

------------------------------------------------------------------------------------

-- Fixes missing Beebox inspection lines for different states.
-- Made by: alainmcd and piratekingflcl [Mod Id - 952458573]
AddPrefabPostInit("beebox", function(inst)
    inst.components.inspectable.getstatus = function(inst)
        if inst.components.harvestable and inst.components.harvestable:CanBeHarvested() then
            if inst.components.harvestable.produce == inst.components.harvestable.maxproduce then
                return "FULLHONEY"
            elseif inst.components.childspawner and inst.components.childspawner:CountChildrenOutside() > 0 then
                return "GENERIC"
            else
                return "SOMEHONEY"
            end
        end
        return "NOHONEY"
    end
end)

------------------------------------------------------------------------------------

-- Fix Wee Mactusk loot and a Navigadget Crash. Made by: Faintly Macabre.
AddPrefabPostInit("little_walrus", function(inst)
    _G.SetSharedLootTable('walrus_wee_loot', {{'meat', 1}})
end)

------------------------------------------------------------------------------------

if hasRoG then
    local function FixStump(inst)
        local _OnEntityWake = inst.OnEntityWake

        inst.OnEntityWake = function(inst)
            _OnEntityWake(inst)
            if not inst:HasTag("burnt") and not inst:HasTag("fire") and inst:HasTag("stump") then
                inst:RemoveComponent("burnable")
                _G.MakeSmallBurnable(inst)
                inst:RemoveComponent("propagator")
                _G.MakeSmallPropagator(inst)
            end
        end
    end

    local prefabs_sufixs = {"", "_normal", "_tall", "_short", "_piko_nest"}
    
    for _, type in ipairs(prefabs_sufixs) do

        -- Fixes Deciduous Tree and Tea Tree Stumps not being burnable after derendering.
        -- Made by: Faintly Macabre.
        AddPrefabPostInit("deciduoustree"..type, FixStump)
        AddPrefabPostInit("teatree"..type, FixStump)
    end
end

------------------------------------------------------------------------------------

if hasHAM then  -- This shit refuses to run in the hamlet file.
    local states = {"play_flute", "play_horn", "play_bell", "use_fan", "map", "toolbroke"}
    
    -- Fixes ghost carry arm for Wilba in Werewilba form.
    AddStategraphPostInit("wilson", function(self)
        for _, state in ipairs(states) do
            local _onexit = self.states[state].onexit

            self.states[state].onexit = function(inst)
                _onexit(inst)
                if inst.were then
                    inst.AnimState:Hide("ARM_carry") 
                    inst.AnimState:Show("ARM_normal")
                end
            end
        end
    end)
end

------------------------------------------------------------------------------------

local function FixLightOnDay(inst)
    local _onfar = inst.components.playerprox.onfar
    inst.components.playerprox:SetOnPlayerFar(function(inst)
        if not _G.GetClock():IsDay() then
            _onfar(inst)
        end
    end)
end

-- Fix for a rare bug where the light stays on during the day.
AddPrefabPostInit("pighouse", FixLightOnDay)
AddPrefabPostInit("wildborehouse", FixLightOnDay)

------------------------------------------------------------------------------------

-- Fixes the misspelled "burnt" tag check.
AddComponentPostInit("homeseeker", function(self)
    local _HasHome = self.HasHome
    function self:HasHome()
        return _HasHome(self) and not self.home:HasTag("burnt")
    end
end)
