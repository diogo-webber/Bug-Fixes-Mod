
local SAVEINTEGRATION_OVERRITES = {
    SW_COMP_DESCRIPTION = "Would you like to make this world compatible with Shipwrecked? This will add new mechanics to your world like wetness and overheating.",
    SW_COMP_ROG_DESCRIPTION = "Would you like to make this world compatible with Shipwrecked?",

    DLC_CHOICE_DESC_2 = "Making the save compatible with Hamlet also makes it compatible with Shipwrecked.",

    PORK_COMP_DESCRIPTION = "Would you like to make this world compatible with Hamlet? This will add new mechanics to your world like wetness and overheating.\n\nMaking the save compatible with Hamlet also makes it compatible with Shipwrecked.",
    PORK_COMP_ROG_DESCRIPTION = "Would you like to make this world compatible with Hamlet?\n\nMaking the save compatible with Hamlet also makes it compatible with Shipwrecked.",
    PORK_COMP_SW_DESCRIPTION =  "Would you like to make this world compatible with Hamlet?",
}

-- Replaces the deprecated "Only works with X dlc compatible mods." by Hamlet compatibility explanation.
for key, value in pairs(SAVEINTEGRATION_OVERRITES) do
    STRINGS.UI.SAVEINTEGRATION[key] = value
end

local function DlcCompatibilityPrompt(self)
    -- Pop just one screen.
    self.menu.items[2].onclick = function()
        TheFrontEnd:PopScreen(self)
    end

    -- ESC support.
    local _OnControl = self.OnControl
    function self:OnControl(control, down)
        return _OnControl(self, control, down) or (control == CONTROL_CANCEL and not down and TheFrontEnd:PopScreen(self))
    end
end

AddGlobalClassPostConstruct("screens/dlccompatibilityprompt", "DlcCompatibilityPrompt", DlcCompatibilityPrompt)

------------------------------------------------------------------------------------

local cancel_like_words = {"No", "Stay", "Cancel", "Never mind..."}

local function PopUpOnControl(self, control, down)
    if self._base.OnControl(self, control, down) then return true end

    if self.cancel_button and control == CONTROL_CANCEL and not down then
        self.cancel_button.cb()
    end
end

local function PopUpOnBecomeActive(self)
    self._base.OnBecomeActive(self)

    -- A little adjust in text positions
    self.title:SetPosition(0, 60, 0)
    self.text:SetPosition(0, 0, 0)
end

local function PopupHook(self)
    self.cancel_button = nil

    for _, button in pairs(self.buttons) do
        for _, word in pairs(cancel_like_words) do
            if button.text and button.text:find(word) then
                self.cancel_button = button
                break
            end
        end

        if self.cancel_button then break end
    end

    self.OnControl = PopUpOnControl
end

-- Many Popups now support ESQ to close them
AddGlobalClassPostConstruct("screens/bigpopupdialog", "BigPopupDialogScreen", PopupHook)

AddGlobalClassPostConstruct("screens/popupdialog", "PopupDialogScreen", function(self)
    PopupHook(self)
    self.OnBecomeActive = PopUpOnBecomeActive
end)

------------------------------------------------------------------------------------

local function EnableDLCOnControlInternal(self, control, down)
    if self._base.OnControl(self, control, down) then return true end
    
    if control == CONTROL_CANCEL and not down then
        EnableAllDLC()
        TheFrontEnd:PopScreen(self)
        return true
    end
end

-- Slot Detail Screen ESC Fix.
local function EnableDLCOnControl(self)
    self.OnControl = EnableDLCOnControlInternal
end

AddGlobalClassPostConstruct("screens/loadgamescreen", "LoadGameScreen", EnableDLCOnControl)
AddGlobalClassPostConstruct("screens/slotdetailsscreen", "SlotDetailsScreen", EnableDLCOnControl)

------------------------------------------------------------------------------------

-- Some little changes to Mods Screen text positions.
AddGlobalClassPostConstruct("screens/modsscreen", "ModsScreen", function(self)
    if env.IsModEnabled(MODS.BetterModsScreen) then
        return
    end

    local _RefreshOptions = self.RefreshOptions
    local _CreateDetailPanel = self.CreateDetailPanel

    function self:RefreshOptions()
        _RefreshOptions(self)

        for _, opt in pairs(self.optionwidgets) do
            opt.name:SetPosition(70, 8, 0)
            opt.status:SetPosition(70, -22, 0)
        end
    end

    function self:CreateDetailPanel()
        _CreateDetailPanel(self)

        self.detailtitle:EnableWordWrap(true)
        self.detailtitle:SetRegionSize(270, 40) --> Fake WordWrap

        self.detailauthor:SetRegionSize(270, 30) --> Fake WordWrap
        self.detailauthor:SetColour(0.8, 0.8, 0.8, 1)
        self.detailauthor:SetPosition(70, 118, 0)

        self.modlinkbutton:SetTextSize(28)

        self.detailcompatibility:SetSize(22)
        self.detailcompatibility:SetColour(0.7, 0.7, 0.7 ,1)

        self.detaildesc:SetRegionSize(337,145) --> More padding
    end
    
    self:CreateDetailPanel()
    self:Scroll(0)

    if #self.modnames > 0 then
        self:ShowModDetails(1)
    end
end)