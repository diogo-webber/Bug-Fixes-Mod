
local function _LoadAsset(type, path)
    table.insert(Assets, Asset(type, path))
end

env.LoadAsset = {
    Anim = function(anim)
        _LoadAsset("ANIM", "anim/"..anim..".zip")
    end,

    Images = function(image)
        _LoadAsset("ATLAS", "images/"..image..".xml")
        _LoadAsset("IMAGE", "images/"..image..".tex")
    end,

    Sound = function(sound)
        _LoadAsset("SOUND", "sound/"..sound..".fsb")
        _LoadAsset("SOUNDPACKAGE", "sound/"..sound..".fev")
    end
}

------------------------------------------------------------------------------------

function env.LoadModPrefabFile(file)
    table.insert(PrefabFiles, file)
end

env.MODS = {
    Mouse_Through = 1719013848,
    BetterModsScreen = 2842240212,
}

function env.IsModEnabled(mod)
    KnownModIndex:IsModEnabled("workshop-"..mod)
end

------------------------------------------------------------------------------------

local function HookStateFn(sg, state, fn, new_fn, extra_arg)
    if not sg.states[state] then return end

    local _fn = sg.states[state][fn]
    sg.states[state][fn] = function(inst, arg) new_fn(inst, arg, _fn, extra_arg) end
end

local function HookSG_StatePre(sg, state, fn, add_fn)
    HookStateFn(sg, state, fn, function(inst, arg, _fn)
        local should_return = add_fn(inst, arg)
        if _fn and not should_return then _fn(inst, arg) end
    end)
end

local function HookSG_StatePost(sg, state, fn, add_fn)
    HookStateFn(sg, state, fn, function(inst, arg, _fn)
        if _fn then _fn(inst, arg) end
        add_fn(inst, arg)
    end)
end

local function HookSG_ActionHandler(sg, action, hook_fn)
    action = ACTIONS[action]
    if not sg.actionhandlers[action] then return end
    
    local _deststate = sg.actionhandlers[action].deststate
    sg.actionhandlers[action].deststate = function(inst, action) return hook_fn(inst, action, _deststate) end
end

local function HookSG_EventHandler(sg, event, hook_fn)
    if not sg.events[event] then return end
    
    local _fn = sg.events[event].fn
    sg.events[event].fn = function(inst, data) hook_fn(inst, event, _fn) end
end

local function EnableMoviment(inst)
    inst.components.playercontroller:Enable(true)
end

local function DisableMoviment(inst)
    inst.components.playercontroller:Enable(false)
end

local function AddToggleMoviment(sg, state)
    HookSG_StatePre(sg, state, "onenter", DisableMoviment)
    HookSG_StatePost(sg, state, "onexit",  EnableMoviment)
end

local function CreatePrePostFns(state_fn)
    return {
        Pre = function(sg, state, add_fn)
            HookSG_StatePre(sg, state, state_fn, add_fn)
        end,
        Post = function(sg, state, add_fn)
            HookSG_StatePost(sg, state, state_fn, add_fn)
        end,
    }
end

local function Onenter_Onexit(sg, state, enter_fn, exit_fn)
    HookSG_StatePre(sg, state, "onenter", enter_fn)
    HookSG_StatePost(sg, state, "onexit",  exit_fn)
end

------------------------------------------------------------------------------------

local function ShowBoat(inst, arg)
    local vehicle = inst.components.driver.vehicle
    return vehicle and vehicle:Show()
end

local function HideBoat(inst, arg)
    local vehicle = inst.components.driver.vehicle
    return vehicle and vehicle:Hide()
end

local function ToggleBoat(sg, state)
    Onenter_Onexit(sg, state, ShowBoat, HideBoat)
end

------------------------------------------------------------------------------------

function env.AddTagToState(sg, state, tag)
    sg.states[state].tags[tag] = true
end

------------------------------------------------------------------------------------

Hooks = {
    sg = {
        state = {
            onenter = CreatePrePostFns("onenter"),
            onexit = CreatePrePostFns("onexit"),
            AddToggleMoviment = AddToggleMoviment,
            Pre = HookSG_StatePre,      -- It's better to use onenter/onexit.
            Post = HookSG_StatePost,    -- It's better to use onenter/onexit.
            Onenter_Onexit = Onenter_Onexit,
            ToggleBoat = ToggleBoat,
        },
        handler = {
            Event = HookSG_EventHandler,
            Action = HookSG_ActionHandler,
        },
    },
}

CreatePrePostFns = nil