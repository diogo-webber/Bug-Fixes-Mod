
LoadAsset.Anim("player_wagstaff") --> Wagstaff anims
LoadAsset.Anim("player_mount_wagstaff")
LoadAsset.Anim("player_wrap_bundle") --> Bundle Fx
LoadAsset.Anim("sand_puff")

LoadAsset.Sound("dontstarve_wagstaff") --> Wagstaff sounds

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

-- Fix "plant" string on fence/gate and portable cook pot deploy.
local _ACTIONS_DEPLOY_strfn = ACTIONS.DEPLOY.strfn
ACTIONS.DEPLOY.strfn = function(act)
    if act.invobject then
        return 
            (act.invobject:HasTag("gatebuilder") and "GATE") or 
            (act.invobject:HasTag("fencebuilder") and "FENCE") or
            (act.invobject:HasTag("portableitem") and "PORTABLE") or
            _ACTIONS_DEPLOY_strfn(act)
    end
end

------------------------------------------------------------------------------------

-- Fix item duplication after broken fences/gates with a charged obsidian tools.
local function FixFenceHit(inst)
    local _onhit = inst.components.combat.onhitfn
    inst.components.combat.onhitfn = function(inst, ...)
        if inst.components.workable.workleft > 0 then
            _onhit(inst, ...)
        end
    end
end

AddPrefabPostInit("fence", FixFenceHit)
AddPrefabPostInit("fence_gate", FixFenceHit)

------------------------------------------------------------------------------------

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
    local inst = CreateEntity()

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

-- Unwrap on ground.
ACTIONS.UNWRAP.priority = 3

local function BundleOnUnwrappedFn(inst, pos, doer)
    if inst.burnt then
        SpawnPrefab("ash").Transform:SetPosition(pos:Get())
    else
        local waxpaper = SpawnPrefab("waxpaper")
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
end

AddPrefabPostInit("bundle", function(inst)
    inst.components.unwrappable:SetOnUnwrappedFn(BundleOnUnwrappedFn)
end)

-- Test if the item is irreplaceable
AddPrefabPostInit("bundle_container", function(inst)
    local _itemtestfn = inst.components.container.itemtestfn
    inst.components.container.itemtestfn = function(inst, item, slot)
        local _return = _itemtestfn(inst, item, slot)

        return _return and not item:HasTag("irreplaceable")
    end
end)

local function unwrappable_Unwrap(self, doer)
    local pos = self.inst:GetPosition()
    pos.y = 0
    if self.itemdata ~= nil then
        if doer ~= nil and
            self.inst.components.inventoryitem ~= nil and
            self.inst.components.inventoryitem:GetGrandOwner() == doer then
            local doerpos = doer:GetPosition()
            local offset = FindWalkableOffset(doerpos, doer.Transform:GetRotation() * DEGREES, 1, 8, false, true)
            if offset ~= nil then
                pos.x = doerpos.x + offset.x
                pos.z = doerpos.z + offset.z
            else
                pos.x, pos.z = doerpos.x, doerpos.z
            end
        end

        for i, v in ipairs(self.itemdata) do
            local item = SpawnPrefab(v.prefab)
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

AddComponentPostInit("unwrappable", function(self)
    self.Unwrap = unwrappable_Unwrap
end)

-- Spawn -> inventory effect fix
AddComponentPostInit("bundler", function(self)
    function self:OnFinishBundling()
        if self.bundlinginst ~= nil and
            self.bundlinginst.components.container ~= nil and
            not self.bundlinginst.components.container:IsEmpty() and
            self.wrappedprefab ~= nil then
            local wrapped = SpawnPrefab(self.wrappedprefab)
            if wrapped ~= nil then
                local give_pos = self.bundlinginst:GetPosition()
                if wrapped.components.unwrappable ~= nil then
                    local items = {}
                    for i = 1, self.bundlinginst.components.container:GetNumSlots() do
                        local item = self.bundlinginst.components.container:GetItemInSlot(i)
                        if item ~= nil then
                            table.insert(items, item)
                        end
                    end
                    wrapped.components.unwrappable:WrapItems(items, self.inst)
                    self.bundlinginst:Remove()
                    self.bundlinginst = nil
                    self.itemprefab = nil
                    self.wrappedprefab = nil
                    if self.inst.components.inventory ~= nil then
                        self.inst.components.inventory:GiveItem(wrapped, nil, Vector3(TheSim:GetScreenPos(give_pos:Get())))
                    else
                        DropItem(self.inst, wrapped)
                    end
                else
                    wrapped:Remove()
                end
            end
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
        ["animqueueover"] = EventHandler("animqueueover", function(inst)
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
        if not CanEntitySeeTarget(inst, inst) then
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

local function inventoryitem_OnDroppedBundle(self)
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

        local vel = Vector3(0, 5, 0)
        
        local speed = 0.5 + math.random()          
        local angle = math.random()*2*PI
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

-- Make a custom method with HAM's OnDropped, to use setspeed param in bundle
AddComponentPostInit("inventoryitem", function(self)
    self.OnDroppedBundle = inventoryitem_OnDroppedBundle
end)

------------------------------------------------------------------------------------

local function EnableShadow(inst, arg)
    inst.DynamicShadow:Enable(true)
end

local function DisableShadow(inst, arg)
    inst.DynamicShadow:Enable(true)
end

-- Fixes a inconsistent shadow in telebrella anim
local function FixTelebrellaShadow(sg)
    Hooks.sg.state.Onenter_Onexit(sg, "telebrella_finish", DisableShadow, EnableShadow)
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

    -- Fixes the tree fire exploit, because chest growing trees isn't cool
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
            return not table.contains({ACTIONS.NET, ACTIONS.FISH}, target.components.workable:GetWorkAction())
        end

        return old_test
    end)
end)

------------------------------------------------------------------------------------

-- 3 hits to break them.
local function SkeletonTweak(inst)
    inst.components.workable:SetWorkLeft(3)
end

AddPrefabPostInit("skeleton", SkeletonTweak)
AddPrefabPostInit("skeleton_player", SkeletonTweak)

------------------------------------------------------------------------------------

local function BeeBox_getstatus(inst)
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

-- Fixes missing Beebox inspection lines for different states.
-- Made by: alainmcd and piratekingflcl [Mod Id - 952458573]
AddPrefabPostInit("beebox", function(inst)
    inst.components.inspectable.getstatus = BeeBox_getstatus
end)

------------------------------------------------------------------------------------

-- Fix Wee Mactusk loot and a Navigadget Crash. Made by: Faintly Macabre.

AddPrefabPostInit("little_walrus", function(inst)
    SetSharedLootTable('walrus_wee_loot', {{'meat', 1}})
end)

------------------------------------------------------------------------------------

if hasRoG then
    local function FixStump(inst)
        local _OnEntityWake = inst.OnEntityWake

        inst.OnEntityWake = function(inst)
            _OnEntityWake(inst)
            if not inst:HasTag("burnt") and not inst:HasTag("fire") and inst:HasTag("stump") then
                inst:RemoveComponent("burnable")
                MakeSmallBurnable(inst)
                inst:RemoveComponent("propagator")
                MakeSmallPropagator(inst)
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

local function FixLightOnDay(inst)
    local _onfar = inst.components.playerprox.onfar
    inst.components.playerprox:SetOnPlayerFar(function(inst)
        if not GetClock():IsDay() then
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

-- Fixes mouse over effect missing in children.
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

local function FISH_AND_NET_canbeworkedby(worker, numworks)
    return worker.components.inventory ~= nil
end

local function FixNegativeWorkleft(inst)
    if inst.components.workable then
        inst.components.workable.canbeworkedby = FISH_AND_NET_canbeworkedby
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

local function FixMountedState(sg, state)
    Hooks.sg.state.Onenter_Onexit(sg, state, SetFourFaces, SetSixFaces)
end

------------------------------------------------------------------------------------

-- Launch the projectile in the hat (for mounted anim).
AddPrefabPostInit("gogglesshoothat", function(inst)
    inst.components.weapon.projectilelaunchsymbol = "swap_hat"
    inst:RemoveTag("Shockwhenwet")
end)

------------------------------------------------------------------------------------

local mounted_funnyidle_state = State{
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

    events = {
        ["animqueueover"] = EventHandler("animqueueover", function(inst) inst.sg:GoToState("idle") end)
    },
}

 local states_to_fix = {
    "peertelescope",
    "goggleattack",
    "goggle_attack_post",
    "goggle",
    "goggle_post",
    "investigate",
    "investigate_post",
    "speargun",
    "shoot",
    "sneeze",
    "mounted_funnyidle",
}

local function IsMounting()
    return GetPlayer().components.rider:IsRiding()
end

-- Beefalo Fixes:
AddStategraphPostInit("wilson", function(sg)
    sg.states["domediumaction"] = State{
        name = "domediumaction",
        
        onenter = function(inst)
            inst.sg:GoToState("dolongaction", .5)
        end,
    }
    
    -- Make always long action when mounting.
    Hooks.sg.handler.Action(sg, "PICKUP", function(inst, action, _old)
        return IsMounting() and "domediumaction" or "doshortaction"
    end)

    Hooks.sg.handler.Action(sg, "PICK", function(inst, action, _old)
        return IsMounting() and "dolongaction" or _old(inst, action)
    end)

    -- BFB cannot grab the player if mounting.
    Hooks.sg.handler.Event(sg, "cower", function(inst, data, _old)
        return not IsMounting() and _old(inst, data)
    end)

    -- Will no longer use the beefalo atk animation for Weather Pain and Lazy Explorer when mounting.
    Hooks.sg.state.Post(sg, "castspell_tornado", "onenter", function(inst, arg)
        return IsMounting() and inst.AnimState:PlayAnimation("player_atk")
    end)

    Hooks.sg.state.Post(sg, "quicktele", "onenter", function(inst, arg)
        return IsMounting() and inst.AnimState:PlayAnimation("player_atk")
    end)

    -- Shitty fix for be able to use Wheeler Gun when mounting.
    Hooks.sg.state.Post(sg, "shoot", "onenter", function(inst, arg)
        return IsMounting() and inst.AnimState:PlayAnimation("speargun")
    end)
    
    -- Fixes player enabled to action during bucked state.
    AddTagToState(sg, "bucked", "doing")
    AddTagToState(sg, "bucked_post", "doing")

    Hooks.sg.state.AddToggleMoviment(sg, "bucked")
    Hooks.sg.state.AddToggleMoviment(sg, "bucked_post")

    sg.states["mounted_funnyidle"] = mounted_funnyidle_state
    
    Hooks.sg.state.Pre(sg, "mounted_idle", "ontimeout", function(inst)
        if (inst.components.poisonable and inst.components.poisonable:IsPoisoned())
        or inst.components.temperature:GetCurrent() < 10 then
            inst.sg:GoToState("mounted_funnyidle")
            return true
        end
    end)

    -- This is not totally correct...
    if not sg.states["book"].timeline[1].defline:find("workshop-") then -- I don't want to override other mods.
        sg.states["book"].timeline[1].fn = function(inst)
            local fxtoplay = inst.prefab == "waxwell" and "waxwell_book_fx" or "book_fx"
        
            local fx = SpawnPrefab(fxtoplay)
            local pos = inst:GetPosition()

            pos.y = inst.components.rider:IsRiding() and pos.y + 2.8 or pos.y - .2

            fx.Transform:SetRotation(inst.Transform:GetRotation())
            fx.Transform:SetPosition(pos:Get()) 

            inst.sg.statemem.book_fx = fx
        end
    end

    for _, state in ipairs(states_to_fix) do
        FixMountedState(sg, state)
    end
end)

-- Extinguish smolders when mounting.
if hasRoG then ACTIONS.SMOTHER.mount_enabled = true end

-- Player can now pick pickables when mounting.
ACTIONS.PICK.mount_enabled = true

-- Player can now pickup items when mounting.
ACTIONS.PICKUP.mount_enabled = true

AddComponentPostInit("playercontroller", function(self)
    local _GetToolAction = self.GetToolAction
    function self:GetToolAction(tool)
        if not self.inst.components.rider:IsRiding() then 
            return _GetToolAction(self, tool)
        end
        
        local action = nil
        local notags = {"FX", "NOCLICK"}
        local rad = self.directwalking and 3 or 6

        local pickup = FindEntity(self.inst, rad, 
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
                action = ACTIONS.PICKUP
            elseif pickup.components.pickable and pickup.components.pickable:CanBePicked() then 
                action = ACTIONS.PICK
            end
        end
        
        return action and BufferedAction(self.inst, pickup, action, tool) or _GetToolAction(self, tool)
    end
end)

-- Beefalo no longer uses the player equipment to do melee attacks.
AddComponentPostInit("combat", function(self)
    local _GetWeapon = self.GetWeapon
    function self:GetWeapon(...)
        local weapon = _GetWeapon(self, ...)

        if not (
            self.inst.components.rider ~= nil and self.inst.components.rider:IsRiding()
        )
        or (
            weapon and (
                weapon:HasTag("rangedweapon")
                or (weapon.components.weapon and weapon.components.weapon:CanRangedAttack())
                or weapon.components.complexprojectile
                or weapon.components.projectile
            )
        ) then
            return weapon
        end
    end
end)

------------------------------------------------------------------------------------

-- Make the quotes compatible with beefalo heigh.
AddPlayerPostInit(function(player)
    player:ListenForEvent("mounted", function(inst, data)
        player.components.talker.offset = Vector3(0, -700, 0)
    end)
    player:ListenForEvent("dismounted", function(inst, data)
        player.components.talker.offset = Vector3(0, -400, 0)
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
              target.components.inventoryitem.owner == GetPlayer() then
                if target.components.trader:CanAccept(self.inst, doer) then
                    table.insert(actions, ACTIONS.GIVE)
                    return
                end
            end
        end
        
        _CollectUseActions(self, doer, target, actions)
    end
end)

------------------------------------------------------------------------------------

-- Leave the check for placement to builder.
local _BUILD_fn = ACTIONS.BUILD.fn
ACTIONS.BUILD.fn = function(act, ...)
    local success = _BUILD_fn(act, ...)
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
        local recipe = GetRecipe(recname)
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

local function AddDesconstrutive(recipe, ingredients)
    if not GetRecipe(recipe) then
        Recipe(recipe, ingredients, nil, TECH.LOST)
    end
end

if hasSW then 
    -- Deployed Surfboard now drops loot.
    AddDesconstrutive("surfboard", {Ingredient("boards", 1), Ingredient("seashell", 2)})

    -- Structures build by characters will drop his loot then destroyed by a different character.
    AddDesconstrutive("woodlegsboat", {Ingredient("boatcannon", 1), Ingredient("boards", 4), Ingredient("dubloon", 4)})
end

AddDesconstrutive("telipad", {Ingredient("gears", 1), Ingredient("transistor", 1), Ingredient("cutstone", 2)})
AddDesconstrutive("thumper", {Ingredient("gears", 1), Ingredient("flint"     , 6), Ingredient("hammer"  , 2)})

-- Deployed Mini Sign now drops loot.
AddDesconstrutive("minisign", {Ingredient("boards", 1)})

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

if EntityScript then
    local _PushEvent = EntityScript.PushEvent

    function EntityScript.PushEvent(inst, event, data)
        if event == "attacked" and
          data and
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

    local pos = Vector3(inst.Transform:GetWorldPosition())
    pos.x = pos.x + (math.cos(heading_angle*DEGREES))
    pos.y = pos.y + 0.9
    pos.z = pos.z + (math.sin(heading_angle*DEGREES))
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
    local back, front, left, right, rock_front = -1, 0, 1.5, -1.5, 1

    local decor_defs = {
        [2] = {{stick={{left-0.9,0,back},{right,0,front},}},{stickleft={{0.0,0,back},{left,0,front},}},{stickright={{right+0.9,0,back},{left-0.3,0,back+0.5},{right+0.3,0,back+0.5},}},{signleft={{-1.0,0,0.5}}}},
        [3] = {{signleft={{-1.0,0,0.5}}},{farmrock={{right+3.0,0,rock_front+0.2},{right+3.05,0,rock_front-1.5},}},{farmrocktall={{right+3.07,0,rock_front-1.0},}},{farmrockflat={{right+3.06,0,rock_front-0.4},}},{farmrock={{left-3.05,0,rock_front-1.0},}},{farmrocktall={{left-3.07,0,rock_front-1.5},}},{farmrockflat={{left-3.06,0,rock_front-0.4},}},{farmrock={{right+1.1,0,rock_front+0.21},{right+2.4,0,rock_front+0.25},}},{farmrocktall={{right+0.5,0,rock_front+0.195},}},{farmrockflat={{right+0.0,0,rock_front-0.0},{right+1.8,0,rock_front+0.22},}},{farmrockflat={{left-1.3,0,back-0.19},}},{farmrock={{left-0.5,0,back-0.21},{left-2.5,0,back-0.22},}},{farmrocktall={{left+0.0,0,back-0.15},{left-3.0,0,back-0.20},{left-1.9,0,back-0.205},}},{fencepost={{left-1.0,0,back+0.15},{right+0.8,0,back+0.15},{right+0.3,0,back+0.15},},},{fencepostright={{left-0.5,0,back+0.15},{0,0,back+0.15},},},},
    }

    -- Create linked system if don't have it (RoG...)
    AddComponentPostInit("placer", function(self)
        local _OnUpdate = self.OnUpdate

        if self.LinkEntity then 
            function self:OnUpdate(...)
                _OnUpdate(self, ...)
                if self.fixedcameraoffset then
                    for i, v in ipairs(self.linked) do
                        local color = self.can_build and Vector3(.25, .75, .25) or Vector3(.75, .25, .25)		
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
        
            local downvec = TheCamera:GetDownVec()
            local facedown = math.atan2(downvec.z, downvec.x) * (180/math.pi)

            self.inst.Transform:SetRotation(90-facedown)

            for i, v in ipairs(self.linked) do
                v.Transform:SetRotation(90-facedown)
                local color = self.can_build and Vector3(.25, .75, .25) or Vector3(.75, .25, .25)		
                v.AnimState:SetAddColour(color.x, color.y, color.z, 1)
            end
        end
    end)

    local function FarmPlacerFix(inst, level)
        inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
        inst.AnimState:SetLayer(LAYER_BACKGROUND)
        inst.AnimState:SetSortOrder(3)

        --Show decor on top of the ground placer
        for i, item_info in ipairs(decor_defs[level]) do
            for item_name, item_offsets in pairs(item_info) do
                for j, offset in ipairs(item_offsets) do
                    local item_inst = SpawnPrefab(item_name)
                    item_inst:AddTag("NOCLICK") --not all decor pieces come with NOCLICK by default
                    item_inst:AddTag("placer")
                    item_inst:AddTag("NOBLOCK")
                    item_inst.entity:SetCanSleep(false)
                    item_inst.entity:SetParent(inst.entity)
                    item_inst.Transform:SetPosition(unpack(offset))
                    item_inst.AnimState:SetLightOverride(1)
                    inst.components.placer:LinkEntity(item_inst)
                end
            end
        end
    end

    AddPrefabPostInit("slow_farmplot_placer", function(inst) FarmPlacerFix(inst, 2) end)
    AddPrefabPostInit("fast_farmplot_placer", function(inst) FarmPlacerFix(inst, 3) end)

    ------------------------------------------------------------------------------------
    
    local function FarmRotationFix(inst)
        local downvec = TheCamera:GetDownVec()
        local facedown = math.atan2(downvec.z, downvec.x) * (180/math.pi)

        inst.Transform:SetRotation(90-facedown)

        inst:AddComponent("savedrotation")
    end

    AddPrefabPostInit("slow_farmplot", FarmRotationFix)
    AddPrefabPostInit("fast_farmplot", FarmRotationFix)
end

------------------------------------------------------------------------------------

-- Werepigs will not de-transform at daytime if the cause of transformation isn't full moon
AddComponentPostInit("werebeast", function(self)
    self.forced_were = false

    local _events = GetWorld().event_listeners["daytime"][self.inst]
    local _eventfn = _events[1]
    _events[1] = function(world, data)
        if not self.forced_were then
            _eventfn(world, data)
        end
    end

    local _TriggerDelta = self.TriggerDelta

    function self:TriggerDelta(amount)
        local _triggeramount = math.max(0, self.triggeramount + amount)
        if _triggeramount >= self.triggerlimit then
            self.forced_were = true
        end
        _TriggerDelta(self, amount)
    end
end)

------------------------------------------------------------------------------------

-- Mobs can now unfreeze by heat properly.
AddComponentPostInit("freezable", function(self)
    local _AddColdness = self.AddColdness
    function self:AddColdness(coldness, ...)
        if coldness < 0 and self:IsFrozen() then
            self:Unfreeze()
        else
            _AddColdness(self, coldness, ...)
        end
    end
end)

local unfrezee_handler = EventHandler("unfreeze", function(inst)
    if inst.sg.sg.states.hit then
        inst.sg:GoToState("hit")
    else
        inst.sg:GoToState("idle")
    end
end)

AddPrefabPostInitAny(function(inst)
    if inst.sg and inst.sg.sg.states["frozen"] and inst.sg.sg.states["frozen"].events then
        inst.sg.sg.states["frozen"].events["unfreeze"] = unfrezee_handler
        inst.sg.sg.states["thaw"].events["unfreeze"] = unfrezee_handler
    end
end)

------------------------------------------------------------------------------------

-- The mouse over selection for "statueharp" and "tigershark" will no longer be a giant box
local function RemoveBBMouseOver(prefab)
    AddPrefabPostInit(prefab, function(inst)
        inst.AnimState:SetRayTestOnBB(false)
    end)
end

RemoveBBMouseOver("statueharp")
RemoveBBMouseOver("tigershark")

------------------------------------------------------------------------------------

-- Small change to prevent Lazy Explorer spam.
AddStategraphPostInit("wilson", function(sg)
    Hooks.sg.state.AddToggleMoviment(sg, "quicktele")
end)

local function blinkstaff_SpawnEffect(self, inst)
    local x, y, z = inst.Transform:GetWorldPosition()
    SpawnPrefab("sand_puff_large_back").Transform:SetPosition(x, y - .1, z)
    SpawnPrefab("sand_puff_large_front").Transform:SetPosition(x, y, z)
end

AddComponentPostInit("blinkstaff", function(self)
    self.SpawnEffect = blinkstaff_SpawnEffect
end)

local function CanAcceptItem(inventory, _item)
    local can = false

    if not inventory:IsFull() then
        can = true

    elseif _item.components.stackable then
        local found_item = inventory:FindItem(function(item) 
            return (item.prefab == _item.prefab and
                    not item.components.stackable:IsFull() and
                    item ~= inventory.activeitem) 
        end)

        can = found_item and true or can
    end

    return can
end

local ORANGE_PICKUP_MUST_TAGS = { "isinventoryitem" }
local ORANGE_PICKUP_CANT_TAGS = {"sunken", "bookshelfed", "INLIMBO", "NOCLICK", "NOFORAGE", "catchable", "fire", "minesprung", "mineactive", "spider" }
local function pickup(inst, owner)
    if owner == nil or owner.components.inventory == nil then
        return
    end

    local x, y, z = owner.Transform:GetWorldPosition()
    local ents = TheSim:FindEntities(x, y, z, TUNING.ORANGEAMULET_RANGE, ORANGE_PICKUP_MUST_TAGS, ORANGE_PICKUP_CANT_TAGS)
    local ba = owner:GetBufferedAction()

    for i, v in ipairs(ents) do
        if v.components.inventoryitem ~= nil and
        v.components.inventoryitem.canbepickedup and
        v.components.inventoryitem.cangoincontainer and
        not v.components.inventoryitem:IsHeld() and
        (ba == nil or ba.action ~= ACTIONS.PICKUP or ba.target ~= v) and
        CanAcceptItem(owner.components.inventory, v) then

            SpawnPrefab("sand_puff").Transform:SetPosition(v.Transform:GetWorldPosition())

            inst.components.finiteuses:Use(1)

            local v_pos = v:GetPosition()
            if v.components.stackable ~= nil then
                v = v.components.stackable:Get()
            end

            if v.components.trap ~= nil and v.components.trap:IsSprung() then
                v.components.trap:Harvest(owner)
            else
                owner.components.inventory:GiveItem(v, nil, Vector3(TheSim:GetScreenPos(v_pos:Get())))
            end

            return
        end
    end
end

AddPrefabPostInit("orangeamulet", function(inst)
    local _onequip = inst.components.equippable.onequipfn
    inst.components.equippable:SetOnEquip(function(inst, owner)
        _onequip(inst, owner)
        inst.task:Cancel()
        inst.task = inst:DoPeriodicTask(TUNING.ORANGEAMULET_ICD, function() pickup(inst, owner) end)
    end)
end)

------------------------------------------------------------------------------------

-- Bats will no longer "slip" after being killed.
AddPrefabPostInit("bat", function(inst)
    if MakeAmphibiousCharacterPhysics then
        MakeAmphibiousCharacterPhysics(inst, 1, .5)
    else
        MakeCharacterPhysics(inst, 1, .5)
    end
end)

------------------------------------------------------------------------------------

-- Remove the collision after death for some mobs.
local function RemovePhysicsOnDeath(state)
    local _onenter = state.onenter

    state.onenter = function(inst)
        _onenter(inst)
        RemovePhysicsColliders(inst)

        if inst.components.locomotor then
            inst.components.locomotor:Stop()
        end
    end
end

require("stategraphs/commonstates")

local _AddCombatStates = CommonStates.AddCombatStates
CommonStates.AddCombatStates = function(states, ...)
    _AddCombatStates(states, ...)

    for _, state in pairs(states) do
        if state.name == "death" then
            RemovePhysicsOnDeath(state)
            break
        end
    end
end

local death_adjust_prefabs = {
    "ballphin",
    "bearger",
    "dragonfly",
    "koalefant_winter",
    "koalefant_summer",
    "krampus",
    "minotaur",
    "penguin",
    "tungray",
    "twister_seal",
    "walrus",
    "little_walrus",
}

for _, prefab in pairs(death_adjust_prefabs) do
    AddPrefabPostInit(prefab, function(inst)
        if inst.sg.sg.states["death"] then
            RemovePhysicsOnDeath(inst.sg.sg.states["death"])
        end
    end)
end

------------------------------------------------------------------------------------

if hasRoG then -- Crops don't wither when protected by flingo (flingo unloaded problem)
    local function Crop_OnEntitySleep(self)
        self.inst:RemoveEventCallback("witherplants", self.witherHandler, GetWorld())
    end

    local function Crop_OnEntityWake(self)
        local data = {temp = GetSeasonManager():GetCurrentTemperature()}
        self:witherHandler(data)
        self.inst:ListenForEvent("witherplants", self.witherHandler, GetWorld())
    end


    AddComponentPostInit("crop", function(self)
        local inst = self.inst
        if inst.event_listening then
            inst.event_listening["witherplants"] = nil
        end

        self.witherHandler = function(world_or_self, data) 
            if self.witherable and not self.withered and not self.protected and data.temp > self.wither_temp then
                self:MakeWithered()
            end
        end

        self.OnEntitySleep = Crop_OnEntitySleep
        self.OnEntityWake = Crop_OnEntityWake
    end)
end

------------------------------------------------------------------------------------

-- Fixes many problems caused by burn things with childspawner component.
-- I needed to overwrite the ignite fn because it removes the childspawner component.

local function DefaultOnIgniteEventHandler(inst)
    if inst.components.childspawner then
        if inst.prefab == "wasphive" then
            inst.components.childspawner:ReleaseAllChildren(nil, "killerbee")
        else
            inst.components.childspawner:ReleaseAllChildren()
        end
        inst.components.childspawner:StopSpawning()
    end
end

AddPrefabPostInit("beebox", function(inst)
    if inst.event_listeners and inst.event_listeners["onignite"] then
        inst.event_listeners["onignite"][inst][1] = nil
    end
end)

local function BeesOnIgnite(inst)
    DefaultOnIgniteEventHandler(inst)
    inst.SoundEmitter:KillSound("loop")
    DefaultBurnFn(inst)
end

local function SpiderDenOnIgnite(inst)
    if inst.components.childspawner then
        inst.components.combat.onhitfn(inst)
    end

    inst.SoundEmitter:KillSound("loop")
    DefaultBurnFn(inst)
end

local bee_stuctures = {"honeychest", "beehive", "wasphive", "beebox"}

for _, prefab in pairs(bee_stuctures) do
    AddPrefabPostInit(prefab, function(inst)
        if inst.components.burnable then
            inst.components.burnable:SetOnIgniteFn(BeesOnIgnite)
        end
    end)
end

local spider_dens = {"", "_2", "_3"}

for _, den_sufix in pairs(spider_dens) do
    AddPrefabPostInit("spiderden"..den_sufix, function(inst)
        if inst.components.burnable then
            inst.components.burnable:SetOnIgniteFn(SpiderDenOnIgnite)
        end
    end)
end


local function SlurtleHomeOnIgnite(inst)
    inst.AnimState:PlayAnimation("shake", true)
    inst.SoundEmitter:PlaySound("dontstarve/common/blackpowder_fuse_LP", "hiss")

    if inst.components.childspawner then
        inst.components.childspawner:ReleaseAllChildren()
    end
end

local function SlurtleHome_onextinguish(inst, data)
    inst.AnimState:PlayAnimation("idle", true)
end

AddPrefabPostInit("slurtlehole", function(inst)
    if inst.components.explosive then
        inst.components.explosive:SetOnIgniteFn(SlurtleHomeOnIgnite)
    end

    inst:ListenForEvent("onextinguish", SlurtleHome_onextinguish)
end)

------------------------------------------------------------------------------------

local function Explosive_onextinguish(inst)
    inst.SoundEmitter:KillSound("hiss")
    inst.SoundEmitter:KillSound("rattle")
end

-- Stop the sound if a active explosive is extinguished.
AddComponentPostInit("explosive", function(self)
    self.inst:ListenForEvent("onextinguish", Explosive_onextinguish)
end)

------------------------------------------------------------------------------------

local monkey_houses = {"monkeybarrel", "primeapebarrel"}

-- Add the release all function to monkey houses for consistency.
for _, prefab in pairs(monkey_houses) do
    AddPrefabPostInit(prefab, function(inst)
        if inst.components.burnable then
            inst.components.burnable:SetOnIgniteFn(DefaultOnIgniteEventHandler)
        end
    end)
end

------------------------------------------------------------------------------------

AddComponentPostInit("deployable", function(self)
    self.deploydistance = 1
end)

local needDeploySpace = {
    "spidereggsack",
    "lureplantbulb",
    "eyeturret_item",
}

local function AddDeployDistance(inst)
    if inst.components.deployable then
        inst.components.deployable.deploydistance = 1.5
    end
end

-- Don't need to go exactly to pos to deploy.
for _, prefab in pairs(needDeploySpace) do
    AddPrefabPostInit(prefab, AddDeployDistance)
end

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

-- Fixes the grid blocking placement in Geometric Placement Mod.
AddPrefabPostInit("gridplacer", function(inst)
    inst:AddTag("NOBLOCK")
end)

------------------------------------------------------------------------------------

if not env.IsModEnabled(MODS.Mouse_Through) then -- Mouse Through do it, but in a different way.
    if not hasHAM then
        -- Port the pick condition system from hamlet.
        local function GetSortedEntitiesAtScreenPoint(self)
            local function PickWeight(ent)
                local weight = 0

                for i,v in pairs(self.pickConditions) do
                    local condition = v[1]
                    weight = weight + (condition(ent) and v[2] or 0)
                end

                return weight
            end

            local function cmp(a, b)
                return PickWeight(a) > PickWeight(b)
            end

            local ents = TheSim:GetEntitiesAtScreenPoint(TheSim:GetPosition())

            table.insert(ents, nil)
            table.sort(ents, cmp)

            return ents
        end

        TheInput.pickConditions = {}

        function TheInput:AddPickCondition(name, condition, weight)
            self.pickConditions[name] = {condition, weight}
        end

        function TheInput:OnUpdate()        
            local useController = TheInput:ControllerAttached()
            if useController ~= self.useController then
                self.useController = useController
                local world = GetWorld()
                if world then
                    GetWorld():PushEvent("controllermode_changed", {enabled = useController})
                end
            end
        
            if self.mouse_enabled then
                self.entitiesundermouse = GetSortedEntitiesAtScreenPoint(self)
                
                local inst = self.entitiesundermouse[1]
                if inst ~= self.hoverinst then
                    
                    if inst and inst.Transform then
                        inst:PushEvent("mouseover")
                    end
        
                    if self.hoverinst and self.hoverinst.Transform then
                        self.hoverinst:PushEvent("mouseout")
                    end
                    
                    self.hoverinst = inst
                end
            end
        end
    end

    -------------------------------------------

    local function PrioritizeChest(ent)
        return ent:HasTag("chest")
    end

    local function PrioritizeMiniSign(ent)
        if ent.prefab == "minisign" and not ent._imagename then
            local activeitem = GetPlayer().components.inventory:GetActiveItem()

            return activeitem and activeitem.prefab == "featherpencil"
        end
    end

    -- The mouse now prioritizes chests. Solving the issue with mini signs getting in the way.
    TheInput:AddPickCondition("chests",   PrioritizeChest,    3)
    TheInput:AddPickCondition("minisign", PrioritizeMiniSign, 4)
    --                           name          test fn     priority
end

------------------------------------------------------------------------------------

-- Mini Signs no longer can draw the utility "shelf_slot" entity.
-- Fixed the 10x range typo (15 to 1.5 range)
function _G.FindEntityToDraw(target, tool)
    if target ~= nil then
        local x, y, z = target.Transform:GetWorldPosition()
        for i, v in ipairs(TheSim:FindEntities(x, y, z, 1.5, {"isinventoryitem" }, {"INLIMBO", "NOFORAGE"})) do
            if v ~= target and v ~= tool and v.entity:IsVisible() then
                return v
            end
        end
    end
end

------------------------------------------------------------------------------------

-- Fixes the spell fx position when mounting.
AddPrefabPostInit("staffcastfx", function(inst)
    if GetPlayer().components.rider:IsRiding() then
        inst.AnimState:PlayAnimation("staff_mount")
        inst.AnimState:SetTime(.3)
    end
end)

------------------------------------------------------------------------------------

-- Fixes foliage being invisible in base game and ROG:
AddPrefabPostInit("foliage", function(inst)
    inst.AnimState:PlayAnimation("idle")
end)