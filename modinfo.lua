name = "Bug Fixes"
author = "Leonidas IV"

version = "1.13.2"

description = "\nFixes more than 150 bugs!\n\n\n- Version: " .. version

------------------------------------------------------------------------------------

local configs = {
    {id = "recipe",             label = "Learn Recipes",                yesno=true },
    {id = "bundle_fx",          label = "DST Bundle Effects",           yesno=true },
    {id = "treeseed",           label = "Tree Seed Exploit/Bug",                   },
    {id = "trap",               label = "Extra Trapped Mobs",           yesno=true },
    {id = "speed",              label = "Speed after World Reset",                 },
    {id = "shadowcreature",     label = "Shadow Creatures Spawn",                  },
    {id = "limpet",             label = "Flingomatic Limpet Rock",                 },
    {id = "rain",               label = "Hurricane Storm",                         },
    {id = "butterfly",          label = "Plant Flower Test",                       },
    {id = "flup",               label = "Flup Respawn",                            },
    {id = "fishfarm",           label = "Fish Farm's Raids",                       },
    {id = "lava",               label = "Pitch Fork Volcano-Lava",                 },
    {id = "pressureplate",      label = "Pressures Plates",                        },
    {id = "gifts",              label = "Wilba Gifts",                             },
    {id = "pigfixer",           label = "Worker Pig Changes",           yesno=true },
    {id = "cityplants",         label = "City Plants Changes",          yesno=true },
    {id = "hulk_basalt",        label = "Basalt Drops Auto-Stack",      yesno=true },
}

------------------------------------------------------------------------------------

configuration_options = {}

for i=1, #configs do
    configuration_options[i] = {
        name = configs[i].id,
        label = configs[i].label,
        default = true,
        options = configs[i].yesno and
        {
            {description = "Yes", data = true},
            {description = "No", data = false},
        }
            or 
        {
            {description = "Fixed", data = true},
            {description = "Vanilla", data = false},
        }
    }
end

------------------------------------------------------------------------------------

api_version = 6
priority = -99999999999999
forumthread = ""

dont_starve_compatible = true
reign_of_giants_compatible = true
shipwrecked_compatible = true
hamlet_compatible = true

icon_atlas = "Icons/modicon.xml"
icon = "modicon.tex"


