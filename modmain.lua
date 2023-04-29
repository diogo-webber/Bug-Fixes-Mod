GLOBAL.setmetatable(env,{__index=function(t,k) return GLOBAL.rawget(GLOBAL,k) end})

------------------------------------------------------------------------------------

Assets = {}
PrefabFiles = {}

env.GetConfig = GetModConfigData
env.pre2023update = APP_VERSION == "429404"

env.UpvalueHacker = require("upvaluehacker") -- Tool designed by Rezecib. <3
modimport("scripts/utils.lua") -- Some functions.

if pre2023update then
    modimport("scripts/extra_fx.lua") -- New Fxs.
end

------------------------------------------------------------------------------------

env.hasHAM = IsDLCEnabled(3)
env.hasSW  = IsDLCEnabled(2) or hasHAM
env.hasRoG = IsDLCEnabled(1) or hasSW or hasHAM

local function ImportFixesFile(filename)
    modimport("scripts/bug_fixes/"..filename..".lua")
end

------------------------------------------------------------------------------------

if pre2023update then
    ImportFixesFile("vanilla")
    ImportFixesFile("screens")

    if hasSW  then ImportFixesFile("shipwecked")  end
    if hasHAM then ImportFixesFile("hamlet")      end
else
    ImportFixesFile("post2023update")
end

------------------------------------------------------------------------------------

local ImportFixesFile = nil