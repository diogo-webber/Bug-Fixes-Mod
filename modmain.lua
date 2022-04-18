env._G = GLOBAL

env.TUNING = _G.TUNING
env.GROUND = _G.GROUND
env.GetConfig = GetModConfigData

env.require = _G.require
env.UpvalueHacker = require("upvaluehacker") -- Tool designed by Rezecib. <3

env.hasSW = _G.IsDLCEnabled(2) or _G.IsDLCEnabled(3)
env.hasHAM = _G.IsDLCEnabled(3)

modimport("scripts/fixes/vanilla.lua")

if hasSW then
    modimport("scripts/fixes/shipwecked.lua")
end

if hasHAM then
    modimport("scripts/fixes/hamlet.lua")
end
