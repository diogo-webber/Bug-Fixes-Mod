GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})

------------------------------------------------------------------------------------

Assets = {}
PrefabFiles = {}

env.GetConfig = GetModConfigData

env.UpvalueHacker = require("upvaluehacker") -- Tool designed by Rezecib. <3
modimport("scripts/utils.lua") -- Some functions.
modimport("scripts/extra_fx.lua") -- New Fxs.

------------------------------------------------------------------------------------

env.hasHAM = IsDLCEnabled(3)
env.hasSW = IsDLCEnabled(2) or hasHAM
env.hasRoG = IsDLCEnabled(1) or hasSW or hasHAM

local function ImportFixesFile(filename)
    modimport("scripts/bug_fixes/"..filename..".lua")
end

------------------------------------------------------------------------------------

ImportFixesFile("vanilla")
ImportFixesFile("screens")

if hasSW  then ImportFixesFile("shipwecked")  end
if hasHAM then ImportFixesFile("hamlet")      end

------------------------------------------------------------------------------------

local ImportFixesFile = nil