function env.HookStateFn(sg, state, fn, new_fn, extra_arg)
    if not sg.states[state] then return end

    local _fn = sg.states[state][fn]
    sg.states[state][fn] = function(inst, arg) new_fn(inst, arg, _fn, extra_arg) end
end

function env.HookSG_StatePre(sg, state, fn, add_fn)
    HookStateFn(sg, state, fn, function(inst, arg, _fn)
        local should_return = add_fn(inst, arg)
        if _fn and not should_return then _fn(inst, arg) end
    end)
end

function env.HookSG_StatePost(sg, state, fn, add_fn)
    HookStateFn(sg, state, fn, function(inst, arg, _fn)
        if _fn then _fn(inst, arg) end
        add_fn(inst, arg)
    end)
end

function env.AddTagToState(sg, state, tag)
    if not sg.states[state] then return end

    sg.states[state].tags[tag] = true
end

function env.HookSG_ActionHandler(sg, action, hook_fn)
    action = _G.ACTIONS[action]
    if not sg.actionhandlers[action] then return end
    
    local _deststate = sg.actionhandlers[action].deststate
    sg.actionhandlers[action].deststate = function(inst, action) return hook_fn(inst, action, _deststate) end
end

function env.HookSG_EventHandler(sg, event, hook_fn)
    if not sg.events[event] then return end

    local _fn = sg.events[event].fn
    sg.events[event].fn = function(inst, data) hook_fn(inst, event, _fn) end
end

------------------------------------------------------------------------------------

