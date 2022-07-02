Assets = {
    -- Teleblella effects and sounds + Thumper Sounds.
    Asset("ANIM", "anim/player_wagstaff.zip"),
    Asset("ANIM", "anim/player_mount_wagstaff.zip"),

    Asset("SOUNDPACKAGE", "sound/dontstarve_wagstaff.fev"),
    Asset("SOUND", "sound/dontstarve_wagstaff.fsb"),
    
    -- Bundle Fx
    Asset("ANIM", "anim/player_wrap_bundle.zip"),
}

------------------------------------------------------------------------------------

-- Teleblella effects + Bundle Fx for everybody.
AddPlayerPostInit(function(inst)
    inst.AnimState:AddOverrideBuild("player_wagstaff")
    inst.AnimState:AddOverrideBuild("player_mount_wagstaff")
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

    AddTagToState(self, "bundle", "nodangle")

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
local function FixTelebrellaShadow(sg)
    local function EnableShadow(inst, arg)
        inst.DynamicShadow:Enable(true)
    end
    local function DisableShadow(inst, arg)
        inst.DynamicShadow:Enable(true)
    end

    HookSG_StatePost(sg, "telebrella_finish", "onenter", DisableShadow)
    HookSG_StatePost(sg, "telebrella_finish", "onexit",  EnableShadow)
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

-- Remove  the option to cast if the tornado will do nothing.
AddPrefabPostInit("staff_tornado", function(inst)
    local _spelltest = inst.components.spellcaster.spelltest
    inst.components.spellcaster:SetSpellTestFn(function(staff, caster, target, pos)
        local old_test = _spelltest(staff, caster, target, pos)

        if old_test and target.components.workable then
            return not table.contains({_G.ACTIONS.NET, _G.ACTIONS.FISH}, target.components.workable:GetWorkAction())
        end

        return old_test
    end)
end)

------------------------------------------------------------------------------------

-- 3 hits to break them
local function SkeletonTweak(inst)
    inst.components.workable:SetWorkLeft(3)
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
    AddStategraphPostInit("wilson", function(sg)
        for _, state in ipairs(states) do
            HookSG_StatePost(sg, state, "onexit", function(inst, arg) 
                if inst.were then
                    inst.AnimState:Hide("ARM_carry") 
                    inst.AnimState:Show("ARM_normal")
                end
            end)
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

-- Fixes the not persist "burned" tag check.
AddComponentPostInit("homeseeker", function(self)
    local _HasHome = self.HasHome
    function self:HasHome()
        return _HasHome(self) and not self.home:HasTag("burnt")
    end
end)

------------------------------------------------------------------------------------

-- Fixes mouse over effect missing in childrens.
AddComponentPostInit("highlight", function(self)
    local _ApplyColour = self.ApplyColour
    function self:ApplyColour(...)
        _ApplyColour(self, ...)
        local parent =  self.inst

        if parent.AnimState and parent.highlightchildren then
            for _, children in ipairs(parent.highlightchildren) do
                if children:IsValid() and children.AnimState then
                    children.AnimState:SetAddColour(parent.AnimState:GetAddColour())
                end
            end
        end
    end
end)

local highlight_fixes_data = 
    {
        eyeturret = "base",
        fence_gate = "dooranim",
        slow_farmplot = "decor",
        fast_farmplot = "decor",
        telipad = "decor",
        fish_farm = "sign_prefab",
    }

for prefab, table_key in pairs(highlight_fixes_data) do
    AddPrefabPostInit(prefab, function(inst)
        inst:DoTaskInTime(.1, function()
            local var = inst[table_key]
            local is_table = table_key == "decor" -- type check for ents return table, so...
            if var then
                inst.highlightchildren = is_table and var or {var}
            end
        end)
    end)
end

------------------------------------------------------------------------------------

-- Fixes a lot of problems with WorkedBy/Destroy things with FISH and NET actions.
-- (Explosives and Weather Pain)
local function FixNegativeWorkleft(inst)
    inst.components.workable.canbeworkedby = function(worker, numworks)
        return worker.components.inventory ~= nil
    end
end

AddComponentPostInit("sinkable", function(self)
    local _onhitwater = self.onhitwater
    function self:onhitwater()
        _onhitwater(self)
        FixNegativeWorkleft(self.inst)
    end 
end)

local net_workables = {
    "bee",
    "killerbee",
    "butterfly",
    "fireflies",
    "bioluminescence",
    "jellyfish_planted",
    "rainbowjellyfish_planted",
    "mosquito",
    "mosquito_poison",
    "glowfly",
}

for _, prefab in ipairs(net_workables) do
    AddPrefabPostInit(prefab, FixNegativeWorkleft)
end

------------------------------------------------------------------------------------

local function FixMountedState(sg, state)
    local function SetFourFaces(inst, arg)
        if inst.components.rider:IsRiding() then
            inst.Transform:SetFourFaced()
        end
    end

    local function SetSixFaces(inst, arg)
        if inst.components.rider:IsRiding() then
            inst.Transform:SetSixFaced()
        end
    end

    HookSG_StatePre(sg, state, "onenter", SetFourFaces)
    HookSG_StatePre(sg, state, "onexit",  SetSixFaces)
end

------------------------------------------------------------------------------------

-- Make the projectile in the hat (for mounted anim).
AddPrefabPostInit("gogglesshoothat", function(inst)
    inst.components.weapon.projectilelaunchsymbol = "swap_hat"
    inst:RemoveTag("Shockwhenwet")
end)

------------------------------------------------------------------------------------

local mounted_funnyidle_state = _G.State{
    name = "mounted_funnyidle",
    tags = {"idle", "canrotate"},
    onenter = function(inst)
        if inst.wantstosneeze then
            inst.sg:GoToState("sneeze")
        elseif inst.components.poisonable and inst.components.poisonable:IsPoisoned() then
            inst.AnimState:PlayAnimation("idle_poison_pre")
            inst.AnimState:PushAnimation("idle_poison_loop")
            inst.AnimState:PushAnimation("idle_poison_pst", false)
        elseif inst.components.temperature:GetCurrent() < 10 then
            inst.AnimState:PlayAnimation("idle_shiver_pre")
            inst.AnimState:PushAnimation("idle_shiver_loop")
            inst.AnimState:PushAnimation("idle_shiver_pst", false)
        end
    end,

    events = {EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end)},
}

 local states_to_fix = {
    "peertelescope",
    "goggleattack",
    "goggle_attack_post",
    "goggle",
    "goggle_post",
    "investigate",
    "investigate_post",
    "blowdart",
    "speargun",
    "shoot",
    "sneeze",
    "mounted_funnyidle",
}

local function IsMounting()
    return _G.GetPlayer().components.rider:IsRiding()
end

    -- Beefalo Fixes:
AddStategraphPostInit("wilson", function(sg)
    sg.states["domediumaction"] = 
    _G.State{
        name = "domediumaction",
        
        onenter = function(inst)
            inst.sg:GoToState("dolongaction", .5)
        end,
    }
    
    -- Make always long action when mounting.
    HookSG_ActionHandler(sg, "PICKUP", function(inst, action, _old)
        return IsMounting() and "domediumaction" or "doshortaction"
    end)

    HookSG_ActionHandler(sg, "PICK", function(inst, action, _old)
        return IsMounting() and "dolongaction" or _old(inst, action)
    end)

    -- BFB cann't grab the player if mounting.
    HookSG_EventHandler(sg, "cower", function(inst, data, _old)
        return not IsMounting() and _old(inst, data)
    end)

    -- Will no longer use the beefalo atk animation for Weather Pain when mounting.
    HookSG_StatePost(sg, "castspell_tornado", "onenter", function(inst, arg)
        return IsMounting() and inst.AnimState:PlayAnimation("player_atk")
    end)

    -- Shitty fix for be able to use Wheeler Gun when mounting.
    HookSG_StatePost(sg, "shoot", "onenter", function(inst, arg)
        return IsMounting() and inst.AnimState:PlayAnimation("speargun")
    end)

    local function EnableMoviment(inst, arg)
        inst.components.playercontroller:Enable(true)
    end

    local function DisableMoviment(inst, arg)
        inst.components.playercontroller:Enable(false)
    end
    
    -- Fixes player enabled to action during bucked state.
    AddTagToState(sg, "bucked", "doing")
    AddTagToState(sg, "bucked_post", "doing")

    --                    state           fn        fn_to_apply
    HookSG_StatePre(sg, "bucked",      "onenter", DisableMoviment)
    HookSG_StatePre(sg, "bucked",      "onexit",  EnableMoviment)
    HookSG_StatePre(sg, "bucked_post", "onenter", DisableMoviment)
    HookSG_StatePre(sg, "bucked_post", "onexit",  EnableMoviment)

    sg.states["mounted_funnyidle"] = mounted_funnyidle_state
    
    HookSG_StatePre(sg, "mounted_idle", "ontimeout", function(inst)
        if (inst.components.poisonable and inst.components.poisonable:IsPoisoned())
        or inst.components.temperature:GetCurrent() < 10 then
            inst.sg:GoToState("mounted_funnyidle")
            return true
        end
    end)

    for _, state in ipairs(states_to_fix) do
        FixMountedState(sg, state)
    end
end)

-- Extinguish smolders when mounting.
if hasRoG then _G.ACTIONS.SMOTHER.mount_enabled = true end

-- Player can now pick pickables when mounting.
_G.ACTIONS.PICK.mount_enabled = true

-- Player can now pickup items when mounting.
_G.ACTIONS.PICKUP.mount_enabled = true

AddComponentPostInit("playercontroller", function(self)
    local _GetToolAction = self.GetToolAction
    function self:GetToolAction(tool)
        if not self.inst.components.rider:IsRiding() then 
            return _GetToolAction(self, tool)
        end
        
        local action = nil
        local notags = {"FX", "NOCLICK"}
        local rad = self.directwalking and 3 or 6

        local pickup = _G.FindEntity(self.inst, rad, 
            function(guy) return (
                (
                    guy.components.inventoryitem and 
                    guy.components.inventoryitem.canbepickedup and 
                    (not guy.components.sinkable or not guy.components.sinkable.sunken) and 
                    (not guy.components.mine or guy.components.mine.inactive)
                ) 
                or
                (
                    guy.components.pickable and
                    guy.components.pickable:CanBePicked() and
                    guy.components.pickable.caninteractwith
                )
            )end, nil, notags)
        
        if pickup then
            if pickup.components.inventoryitem and pickup.components.inventoryitem.canbepickedup and (not pickup.components.mine or pickup.components.mine.inactive) then 
                action = _G.ACTIONS.PICKUP
            elseif pickup.components.pickable and pickup.components.pickable:CanBePicked() then 
                action = _G.ACTIONS.PICK
            end
        end
        
        return action and _G.BufferedAction(self.inst, pickup, action, tool) or _GetToolAction(self, tool)
    end
end)

------------------------------------------------------------------------------------

-- Make the quotes compatiple with beefalo heigh.
AddPlayerPostInit(function(player)
    player:ListenForEvent("mounted", function(inst, data)
        player.components.talker.offset = _G.Vector3(0, -720, 0)
    end)
    player:ListenForEvent("dismounted", function(inst, data)
        player.components.talker.offset = _G.Vector3(0, -400, 0)
    end)
end)

------------------------------------------------------------------------------------

-- Allow the player to load weapons and etc when mounting.
AddComponentPostInit("tradable", function(self)
    local _CollectUseActions = self.CollectUseActions
    function self:CollectUseActions(doer, target, actions)
        if doer.components.rider and doer.components.rider:IsRiding() then
            if target.components.trader and
              target.components.trader.enabled and
              target.components.inventoryitem and
              target.components.inventoryitem.owner == _G.GetPlayer() then
                if target.components.trader:CanAccept(self.inst, doer) then
                    table.insert(actions, _G.ACTIONS.GIVE)
                    return
                end
            end
        end
        
        _CollectUseActions(self, doer, target, actions)
    end
end)

------------------------------------------------------------------------------------

-- Leave the check for placement to builder.
local _BUILD_fn = _G.ACTIONS.BUILD.fn
_G.ACTIONS.BUILD.fn = function(act)
    local success = _BUILD_fn(act)
    if not success then
        if act.doer.components.builder then
            return act.doer.components.builder:DoBuild(act.recipe, act.pos, act.rotation, act.modifydata)
        end
    end
    
    return success
end

-- Players can now craft when mounting.
AddComponentPostInit("builder", function(self)
    local _DoBuild = self.DoBuild
    function self:DoBuild(recname, ...)
        local recipe = _G.GetRecipe(recname)
        if recipe and self:IsBuildBuffered(recname) or self:CanBuild(recname) then
            if recipe.placer ~= nil and
            self.inst.components.rider ~= nil and
            self.inst.components.rider:IsRiding() then
                return false, "MOUNTED"
            end
        end

        return _DoBuild(self, recname, ...)
    end
end)

------------------------------------------------------------------------------------

local function AddDesconstrutive(recipe, recipetab, ingredients)
    if not _G.GetRecipe(recipe) then
        Recipe(recipe, ingredients, _G.RECIPETABS[recipetab], _G.TECH.LOST)
    end
end

-- Strutures build by characters will drop his loot then destroyed.
if hasSW then AddDesconstrutive("woodlegsboat", "NAUTICAL", {Ingredient("boatcannon", 1), Ingredient("boards", 4), Ingredient("dubloon", 4)}) end
AddDesconstrutive("telipad", "TOWN", {Ingredient("gears", 1), Ingredient("transistor", 1),Ingredient("cutstone", 2)})
AddDesconstrutive("thumper", "TOWN", {Ingredient("gears", 1), Ingredient("flint", 6), Ingredient("hammer", 2)})

------------------------------------------------------------------------------------

-- Fuck you wood sound -_-
local function ChangeBreakSound(prefab, sound_sufix)
    AddPrefabPostInit(prefab, function(inst)
        if inst.components.workable and inst.components.workable.onfinish then
            local _onfinish = inst.components.workable.onfinish
            inst.components.workable:SetOnFinishCallback(function(inst, worker)
                inst.SoundEmitter:OverrideVolumeMultiplier(0)
                _onfinish(inst, worker)
                inst.SoundEmitter:OverrideVolumeMultiplier(1)
                inst.SoundEmitter:PlaySound("dontstarve/common/destroy_"..sound_sufix)
            end)
        end
    end)
end

local sounds = {
    metal = {
        "telipad",
        "birdcage",
        "basefan",
        "firesuppressor",
        "lightning_rod",
        "sprinkler",
        "tar_extractor",
        "roc_nest_rusty_lamp",
    },

    straw = {
        "doydoynest",
    },

    stone = {
        "ballphinhouse",
        "spoiled_fish",
        "houndbone",
        "pig_guard_tower",
        "roc_nest_house",
        "sea_yard",
        "skeleton",
        "skeleton_player",
        "snake_bone",
        "researchlab5",
        "antcombhome",
        "mandrakehouse",
        "pig_shop_general",
        "pig_shop_antiquities",
        "pig_shop_bank",
        "pig_shop_cityhall",
        "pig_shop_cityhall_player",
        "pig_shop_tinker",
    },

    magic = {
        "researchlab3",
        "researchlab4",
        "piratihatitator",
        "hogusporkusator",
        "nightlight",
        "telebase",
    },

    tool = {
        "tent",
    },
}

for n=1, 7 do
    table.insert(sounds.straw, "lawnornament_"..n)
end

for n=1, 4 do
    table.insert(sounds.straw, "topiary_"..n)
    table.insert(sounds.stone, "roc_nest_egg"..n)
end

for sufix, prefabs in pairs(sounds) do
    for _, prefab in ipairs(prefabs) do
        ChangeBreakSound(prefab, sufix)
    end
end

------------------------------------------------------------------------------------

local needs_projectile_tag = {
    "icestaff",
    "firestaff",
    "gogglesshoothat",
}

-- Reflective attacks will not do damage to attackers at distance.
for _, prefab in pairs(needs_projectile_tag) do
    AddPrefabPostInit(prefab, function(inst)
        inst:AddTag("projectile")
    end)
end

if _G.EntityScript then
    local _PushEvent = _G.EntityScript.PushEvent

    function _G.EntityScript.PushEvent(inst, event, data)
        if event == "attacked" and 
          data.attacker and
          not data.weapon then
            data.weapon = data.attacker.components.combat and
            data.attacker.components.combat:GetWeapon() or nil
        end

        _PushEvent(inst, event, data)
    end
end

------------------------------------------------------------------------------------

local function OnPooped(inst, poop)
    local heading_angle = -(inst.Transform:GetRotation()) + 180

    local pos = _G.Vector3(inst.Transform:GetWorldPosition())
    pos.x = pos.x + (math.cos(heading_angle*_G.DEGREES))
    pos.y = pos.y + 0.9
    pos.z = pos.z + (math.sin(heading_angle*_G.DEGREES))
    poop.Transform:SetPosition(pos.x, pos.y, pos.z)

    if poop.components.inventoryitem and poop.components.inventoryitem.OnStartFalling then
        poop.components.inventoryitem:OnStartFalling()
    end
end

local function FixPoopedPos(inst)
    inst.components.periodicspawner:SetOnSpawnFn(OnPooped)
end

-- This mobs will have the correct poop position spawn.
AddPrefabPostInit("babybeefalo", FixPoopedPos)
AddPrefabPostInit("beefalo", FixPoopedPos)
AddPrefabPostInit("spat", FixPoopedPos)
AddPrefabPostInit("koalefant_summer", FixPoopedPos)
AddPrefabPostInit("koalefant_winter", FixPoopedPos)

------------------------------------------------------------------------------------

-- Fixes the frygoggles spam and double shock damage.
AddStategraphPostInit("wilson", function(sg)
    sg.states["goggleattack"].timeline = {
        TimeEvent(17*FRAMES, function(inst) 
            inst.components.combat:DoAttack(inst.sg.statemem.target) 
            inst.sg:RemoveStateTag("abouttoattack") 
        end),
        TimeEvent(20*FRAMES, function(inst)
            inst.sg:RemoveStateTag("attack")
            if inst.components.moisture and inst.components.moisture:GetMoisture() > 0 and not inst.components.inventory:IsInsulated() then
                inst.components.health:DoDelta(-TUNING.HEALING_MEDSMALL, false, "Shockwhenwet", nil, true)
                inst.sg:GoToState("electrocute")
            end
        end)
    }
end)

------------------------------------------------------------------------------------

if hasRoG then
    local back = -1 local front = 0 local left = 1.5 local right = -1.5 local rock_front = 1

    local decor_defs = {
        [2] = {{stick={{left-0.9,0,back},{right,0,front},}},{stickleft={{0.0,0,back},{left,0,front},}},{stickright={{right+0.9,0,back},{left-0.3,0,back+0.5},{right+0.3,0,back+0.5},}},{signleft={{-1.0,0,0.5}}}},
        [3] = {{signleft={{-1.0,0,0.5}}},{farmrock={{right+3.0,0,rock_front+0.2},{right+3.05,0,rock_front-1.5},}},{farmrocktall={{right+3.07,0,rock_front-1.0},}},{farmrockflat={{right+3.06,0,rock_front-0.4},}},{farmrock={{left-3.05,0,rock_front-1.0},}},{farmrocktall={{left-3.07,0,rock_front-1.5},}},{farmrockflat={{left-3.06,0,rock_front-0.4},}},{farmrock={{right+1.1,0,rock_front+0.21},{right+2.4,0,rock_front+0.25},}},{farmrocktall={{right+0.5,0,rock_front+0.195},}},{farmrockflat={{right+0.0,0,rock_front-0.0},{right+1.8,0,rock_front+0.22},}},{farmrockflat={{left-1.3,0,back-0.19},}},{farmrock={{left-0.5,0,back-0.21},{left-2.5,0,back-0.22},}},{farmrocktall={{left+0.0,0,back-0.15},{left-3.0,0,back-0.20},{left-1.9,0,back-0.205},}},{fencepost={{left-1.0,0,back+0.15},{right+0.8,0,back+0.15},{right+0.3,0,back+0.15},},},{fencepostright={{left-0.5,0,back+0.15},{0,0,back+0.15},},},},
    }

    -- Create linked system if don't have it (vanilla, RoG...)
    AddComponentPostInit("placer", function(self)
        local _OnUpdate = self.OnUpdate

        if self.LinkEntity then 
            function self:OnUpdate(...)
                _OnUpdate(self, ...)
                if self.fixedcameraoffset then
                    for i, v in ipairs(self.linked) do
                        local color = self.can_build and _G.Vector3(.25, .75, .25) or _G.Vector3(.75, .25, .25)		
                        v.AnimState:SetAddColour(color.x, color.y, color.z, 1)
                    end
                end
            end
            return
        end 

        self.linked = {}

        function self:LinkEntity(ent)
            table.insert(self.linked, ent)
        end

        function self:OnUpdate(...)
            _OnUpdate(self, ...)
        
            local downvec = _G.TheCamera:GetDownVec()
            local facedown = math.atan2(downvec.z, downvec.x) * (180/math.pi)

            self.inst.Transform:SetRotation(90-facedown)

            for i, v in ipairs(self.linked) do
                v.Transform:SetRotation(90-facedown)
                local color = self.can_build and _G.Vector3(.25, .75, .25) or _G.Vector3(.75, .25, .25)		
                v.AnimState:SetAddColour(color.x, color.y, color.z, 1)
            end
        end
    end)

    local function FarmPlacerFix(inst, level)
        inst.AnimState:SetOrientation(_G.ANIM_ORIENTATION.OnGround)
        inst.AnimState:SetLayer(_G.LAYER_BACKGROUND)
        inst.AnimState:SetSortOrder(3)

        --Show decor on top of the ground placer
        for i, item_info in ipairs(decor_defs[level]) do
            for item_name, item_offsets in pairs(item_info) do
                for j, offset in ipairs(item_offsets) do
                    local item_inst = _G.SpawnPrefab(item_name)
                    item_inst:AddTag("NOCLICK") --not all decor pieces come with NOCLICK by default
                    item_inst:AddTag("placer")
                    item_inst:AddTag("NOBLOCK")
                    item_inst.entity:SetCanSleep(false)
                    item_inst.entity:SetParent(inst.entity)
                    item_inst.Transform:SetPosition(_G.unpack(offset))
                    item_inst.AnimState:SetLightOverride(1)
                    inst.components.placer:LinkEntity(item_inst)
                end
            end
        end
    end

    AddPrefabPostInit("slow_farmplot_placer", function(inst) FarmPlacerFix(inst, 2) end)
    AddPrefabPostInit("fast_farmplot_placer", function(inst) FarmPlacerFix(inst, 3) end)

    local function FarmRotationFix(inst)
        local downvec = _G.TheCamera:GetDownVec()
        local facedown = math.atan2(downvec.z, downvec.x) * (180/math.pi)

        inst.Transform:SetRotation(90-facedown)

        inst:AddComponent("savedrotation")
    end

    AddPrefabPostInit("slow_farmplot", FarmRotationFix)
    AddPrefabPostInit("fast_farmplot", FarmRotationFix)
end


