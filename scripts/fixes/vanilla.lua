Assets = {
    -- Teleblella effects and sounds + Thumper Sounds.
    Asset("ANIM", "anim/player_wagstaff.zip"),
    Asset("SOUNDPACKAGE", "sound/dontstarve_wagstaff.fev"),
    Asset("SOUND", "sound/dontstarve_wagstaff.fsb"),
    
    -- Bundle Fx
    Asset("ANIM", "anim/player_wrap_bundle.zip"),
}

------------------------------------------------------------------------------------

-- Teleblella effects for everybody + Bundle Fx
for _, prefab in pairs(CHARACTERLIST) do
    AddPrefabPostInit(prefab, function(inst)
        inst.AnimState:AddOverrideBuild("player_wagstaff")
        inst.AnimState:AddOverrideBuild("player_wrap_bundle")
    end)
end

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

local TimeEvent = _G.TimeEvent
local FRAMES = _G.FRAMES
local EventHandler = _G.EventHandler

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
            end)
        end
    end
end)

------------------------------------------------------------------------------------

-- Wilson/Generic quotes. Oh, dear Klei...
local GENERIC = STRINGS.CHARACTERS.GENERIC
GENERIC.DESCRIBE.FENCE = "It's just a wood fence."
GENERIC.DESCRIBE.FENCE_ITEM = "All I need to build a nice, sturdy fence."
GENERIC.DESCRIBE.FENCE_GATE = "It opens. And closes sometimes, too."
GENERIC.DESCRIBE.FENCE_GATE_ITEM = "All I need to build a nice, sturdy gate."

GENERIC.DESCRIBE.BUNDLE = "My supplies are in there!"
GENERIC.DESCRIBE.BUNDLEWRAP = "Wrapping things up should make them easier to carry."

GENERIC.DESCRIBE.BEEFALO.DOMESTICATED = "This one is slightly less smelly than the others."
GENERIC.DESCRIBE.BEEFALO.ORNERY = "It looks deeply angry."
GENERIC.DESCRIBE.BEEFALO.RIDER = "This fellow appears quite ridable."
GENERIC.DESCRIBE.BEEFALO.PUDGY = "Hmmm, there may be too much food inside it."
GENERIC.DESCRIBE.BEEFALO.MYPARTNER = "We're beef friends forever."

GENERIC.DESCRIBE.SADDLE_BASIC = "That'll allow the mounting of some smelly animal."
GENERIC.DESCRIBE.SADDLE_RACE = "This saddle really flies!"
GENERIC.DESCRIBE.SADDLE_WAR = "The only problem is the saddle sores."
GENERIC.DESCRIBE.SADDLEHORN = "This could take a saddle off."
GENERIC.DESCRIBE.SALTLICK = "How many licks does it take to get to the center?"
GENERIC.DESCRIBE.BRUSH = "I bet the beefalo really like this."

GENERIC.DESCRIBE.FEATHERPENCIL = "The feather increases the scientific properties of the writing."

GENERIC.DESCRIBE.MINISIGN_ITEM = "It's not much use like this. I should place it."
GENERIC.DESCRIBE.MINISIGN = {
    GENERIC = "I could draw better than that!",
    UNDRAWN = "I should draw something on there.",
}

GENERIC.ACTIONFAIL.WRAPBUNDLE = {
    EMPTY = "I need to have something to wrap.",
}