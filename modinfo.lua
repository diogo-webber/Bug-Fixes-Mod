name = "Bug Fixes!"
author = "Leonidas IV"

version = "2.0.1"

description = "Note: 95% of the fixes are now officially\nimplemented, so here are just the\nunimplemented ones and some features disguised as fixes."

------------------------------------------------------------------------------------

local configs = {
    --{id = "recipe",             label = "Learn Recipes",                yesno=true },
    --{id = "bundle_fx",          label = "DST Bundle Effects",           yesno=true },
    --{id = "treeseed",           label = "Tree Seed Exploit/Bug",                   },
    --{id = "trap",               label = "Extra Trapped Mobs",           yesno=true },
    --{id = "speed",              label = "Speed after World Reset",                 },
    --{id = "shadowcreature",     label = "Shadow Creatures Spawn",                  },
    --{id = "limpet",             label = "Flingomatic Limpet Rock",                 },
    --{id = "rain",               label = "Hurricane Storm",                         },
    --{id = "butterfly",          label = "Plant Flower Test",                       },
    --{id = "flup",               label = "Flup Respawn",                            },
    --{id = "fishfarm",           label = "Fish Farm's Raids",                       },
    --{id = "lava",               label = "Pitch Fork Volcano-Lava",                 },
    --{id = "pressureplate",      label = "Pressures Plates",                        },
    --{id = "gifts",              label = "Wilba Gifts",                             },
    --{id = "pigfixer",           label = "Worker Pig Changes",           yesno=true },
    --{id = "cityplants",         label = "City Plants Changes",          yesno=true },
      {id = "hulk_basalt",        label = "Basalt Drops Auto-Stack",      yesno=true },
}

------------------------------------------------------------------------------------

local yes_no_table = {
    {description = "Yes", data = true },
    {description = "No" , data = false},
}

local fixed_vanilla_table = {
    {description = "Fixed",   data = true },
    {description = "Vanilla", data = false},
}


configuration_options = {}

for i=1, #configs do
    configuration_options[i] = {
        name = configs[i].id,
        label = configs[i].label,
        default = true,
        options = configs[i].yesno and yes_no_table or fixed_vanilla_table
    }
end

configs, yes_no_table, fixed_vanilla_table = nil, nil, nil

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
