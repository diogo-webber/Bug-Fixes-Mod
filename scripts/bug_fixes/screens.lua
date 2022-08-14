local cancel_like_words = {"No", "Stay", "Cancel", "Never mind..."}

local function PopUpOnControl(self, control, down)
    if self._base.OnControl(self, control, down) then return true end

    if self.cancel_button and control == CONTROL_CANCEL and not down then
        self.cancel_button.cb()
    end
end

local function PopUpOnBecomeActive(self)
    self._base.OnBecomeActive(self)

    -- A litle adjust in text positions
    self.title:SetPosition(0, 60, 0)
    self.text:SetPosition(0, 0, 0)
end

local function PopupHook(self)
    self.cancel_button = nil

    for _, button in pairs(self.buttons) do
        for _, word in pairs(cancel_like_words) do
            if button.text:find(word) then
                self.cancel_button = button
                break
            end
        end

        if self.cancel_button then break end
    end

    self.OnControl = PopUpOnControl
end

-- Many Popups now suport ESQ to close them
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

-- Slot Detail Screen ESC Fix
local function EnableDLCOnControl(self)
    self.OnControl = EnableDLCOnControlInternal
end

AddGlobalClassPostConstruct("screens/loadgamescreen", "LoadGameScreen", EnableDLCOnControl)
AddGlobalClassPostConstruct("screens/slotdetailsscreen", "SlotDetailsScreen", EnableDLCOnControl)

------------------------------------------------------------------------------------

local BetterModsScreenMod = "workshop-2842240212"

-- Some litle changes to Mods Screen text positions.
AddGlobalClassPostConstruct("screens/modsscreen", "ModsScreen", function(self)
    if KnownModIndex:IsModEnabled(BetterModsScreenMod) then
        --return
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
        self.detailtitle:SetRegionSize(270, 40) --> False WordWrap

        self.detailauthor:SetRegionSize(270, 30) --> False WordWrap
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