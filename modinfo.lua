name = "Bug Fixes"
author = "Leonidas IV"

version = "1.7"

api_version = 6
forumthread = ""

dont_starve_compatible = true
reign_of_giants_compatible = true
shipwrecked_compatible = true
hamlet_compatible = true

icon_atlas = "Icons/modicon.xml"
icon = "modicon.tex"

description = "\nFixes several popular bugs!"

local pattern =
{
    {description = "Fixed", data = true},
    {description = "Vanilla", data = false}
}

configuration_options =
{
    {
        name = "fence",
        label = "Fence Deploy",
        options = pattern,
        default = true,
    },
    {
        name = "recipe",
        label = "Learn Recipes",
        options = pattern,
        default = true,
    },
    {
        name = "shadowcreature",
        label = "Shadow Creatures Spawn",
        options = pattern,
        default = true,
    },
    {
        name = "limpet",
        label = "Flingomatic - Limpet Rock",
        options = pattern,
        default = true,
    },
    {
        name = "bee",
        label = "Bees Flying over Water",
        options = pattern,
        default = true,
    },
    {
        name = "trap",
        label = "Extra Trapped Mobs",
        options = pattern,
        default = true,
    },
    {
        name = "rain",
        label = "Hurricane Storm Fix",
        options = pattern,
        default = true,
    },
    {
        name = "pressureplate",
        label = "Pressures Plates",
        options = pattern,
        default = true,
    },
    {
        name = "gifts",
        label = "Wilba Gifts",
        options = pattern,
        default = true,
    },
    {
        name = "flup",
        label = "Flup Spawn",
        options = pattern,
        default = true,
    },
    {
        name = "butterfly",
        label = "Plant Flower Test",
        options = pattern,
        default = true,
    },
    {
        name = "bundle_fx",
        label = "Bundle Effects",
        options = pattern,
        default = true,
    },
}
