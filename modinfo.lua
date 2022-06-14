name = "Bug Fixes"
author = "Leonidas IV"

version = "1.10"

api_version = 6
forumthread = ""

dont_starve_compatible = true
reign_of_giants_compatible = true
shipwrecked_compatible = true
hamlet_compatible = true

icon_atlas = "Icons/modicon.xml"
icon = "modicon.tex"

description = "\nFixes several popular bugs!"

------------------------------------------------------------------------------------

local function Config(id, label)
    return {
        name = id,
        label = label,
        default = true,
        options = {
            {description = "Fixed", data = true},
            {description = "Vanilla", data = false},
        }
    }    
end

configuration_options = {
    Config("recipe", "Learn Recipes"),
    Config("shadowcreature", "Shadow Creatures Spawn"),
    Config("limpet", "Flingomatic - Limpet Rock"),
    Config("trap", "Extra Trapped Mobs"),
    Config("rain", "Hurricane Storm Fix"),
    Config("pressureplate", "Pressures Plates"),
    Config("gifts", "Wilba Gifts"),
    Config("flup", "Flup Respawn"),
    Config("butterfly", "Plant Flower Test"),
    Config("bundle_fx", "Bundle Effects"),
    Config("treeseed", "Tree Seed Exploit/Bug"),
    Config("fishfarm", "Fish Farm Raids"),
    Config("lava", "Pitch Fork Volcano-Lava"),
    Config("speed", "Speed after World Reset"),
}

