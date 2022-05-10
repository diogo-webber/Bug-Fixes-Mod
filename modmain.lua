env._G = GLOBAL

env.TUNING = _G.TUNING
env.GROUND = _G.GROUND
env.STRINGS = _G.STRINGS
env.FRAMES = _G.FRAMES
env.EventHandler = _G.EventHandler
env.TimeEvent = _G.TimeEvent

env.GetConfig = GetModConfigData

env.require = _G.require
env.UpvalueHacker = require("upvaluehacker") -- Tool designed by Rezecib. <3

env.hasHAM = _G.IsDLCEnabled(3)
env.hasSW = _G.IsDLCEnabled(2) or hasHAM
env.hasRoG = _G.IsDLCEnabled(1) or hasSW or hasHAM

modimport("scripts/fixes/vanilla.lua")

if hasSW then
    modimport("scripts/fixes/shipwecked.lua")
end

if hasHAM then
    modimport("scripts/fixes/hamlet.lua")
end
