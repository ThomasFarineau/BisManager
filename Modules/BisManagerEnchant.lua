local BisManager = _G.BisManager
if not BisManager then
    return
end

local L = BisManager.L
local SLOT_DEFINITIONS = BisManager.SLOT_DEFINITIONS
local ENCHANT_BUTTON_ICON = "Interface\\Icons\\Trade_Engraving"
local tooltipScanner = CreateFrame("GameTooltip", "BisManagerEnchantScanner", UIParent, "GameTooltipTemplate")
local SOCKET_LABELS = {
    EMPTY_SOCKET_PRISMATIC,
    EMPTY_SOCKET_RED,
    EMPTY_SOCKET_YELLOW,
    EMPTY_SOCKET_BLUE,
    EMPTY_SOCKET_META,
    EMPTY_SOCKET_COGWHEEL,
    EMPTY_SOCKET_HYDRAULIC,
    EMPTY_SOCKET_PUNCHCARDRED,
    EMPTY_SOCKET_PUNCHCARDYELLOW,
    EMPTY_SOCKET_PUNCHCARDBLUE,
}

local ENCHANTABLE_SLOT_IDS = {
    [INVSLOT_BACK] = true,
    [INVSLOT_CHEST] = true,
    [INVSLOT_WRIST] = true,
    [INVSLOT_FEET] = true,
    [INVSLOT_FINGER1] = true,
    [INVSLOT_FINGER2] = true,
    [INVSLOT_MAINHAND] = true,
    [INVSLOT_OFFHAND] = true,
}

local function GetInventoryUnit(unit)
    if unit == "inspect" then
        return (InspectFrame and InspectFrame.unit) or BisManager.inspectUnit or "target"
    end
    return unit or "player"
end

local function GetEnchantIDFromLink(itemLink)
    if not itemLink then
        return nil
    end

    local payload = itemLink:match("|Hitem:([^|]+)|h") or itemLink:match("^item:(.+)$")
    if not payload then
        return nil
    end

    local index = 0
    for field in (payload .. ":"):gmatch("(.-):") do
        index = index + 1
        if index == 2 then
            local enchantID = tonumber(field)
            return enchantID and enchantID > 0 and enchantID or 0
        end
    end

    return 0
end

local function IsEnchantExpected(slotID)
    return slotID and ENCHANTABLE_SLOT_IDS[slotID] or false
end

local function StripColorCodes(text)
    return (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local function GetTooltipLines(itemLink)
    if not itemLink then
        return {}
    end

    tooltipScanner:SetOwner(UIParent, "ANCHOR_NONE")
    tooltipScanner:ClearLines()
    tooltipScanner:SetHyperlink(itemLink)

    local lines = {}
    local numLines = tooltipScanner:NumLines() or 0
    for index = 1, numLines do
        local leftRegion = _G["BisManagerEnchantScannerTextLeft" .. index]
        if leftRegion then
            lines[#lines + 1] = {
                text = leftRegion:GetText(),
                r = select(1, leftRegion:GetTextColor()),
                g = select(2, leftRegion:GetTextColor()),
                b = select(3, leftRegion:GetTextColor()),
            }
        end
    end
    return lines
end

local function GetGemIDsFromLink(itemLink)
    if not itemLink then
        return {}
    end

    local payload = itemLink:match("|Hitem:([^|]+)|h") or itemLink:match("^item:(.+)$")
    if not payload then
        return {}
    end

    local fields = {}
    for field in (payload .. ":"):gmatch("(.-):") do
        fields[#fields + 1] = field
    end

    local gemIDs = {}
    for index = 3, 6 do
        local gemID = tonumber(fields[index])
        if gemID and gemID > 0 then
            gemIDs[#gemIDs + 1] = gemID
        end
    end
    return gemIDs
end

local function GetSocketCountFromTooltip(itemLink)
    local count = 0
    for _, line in ipairs(GetTooltipLines(itemLink)) do
        local text = StripColorCodes(line.text)
        if text and text ~= "" then
            for _, socketLabel in ipairs(SOCKET_LABELS) do
                if socketLabel and socketLabel ~= "" and text:find(StripColorCodes(socketLabel), 1, true) then
                    count = count + 1
                    break
                end
            end
        end
    end
    return count
end

local function GetEnchantName(itemLink)
    if not itemLink then
        return nil
    end

    for index, line in ipairs(GetTooltipLines(itemLink)) do
        if index > 1 and line.text and line.text ~= "" then
            local text = StripColorCodes(line.text)
            local explicitEnchantName = text:match("^Enchant[^:]*:%s*(.+)$")
            if explicitEnchantName and explicitEnchantName ~= "" then
                return explicitEnchantName
            end
            explicitEnchantName = text:match("^Enchant[eé][^:]*:%s*(.+)$")
            if explicitEnchantName and explicitEnchantName ~= "" then
                return explicitEnchantName
            end
            explicitEnchantName = text:match("^Enchanted[^:]*:%s*(.+)$")
            if explicitEnchantName and explicitEnchantName ~= "" then
                return explicitEnchantName
            end
            if line.g and line.g > 0.75 and line.r and line.r < 0.5 then
                if not text:find("Niveau d'objet", 1, true)
                    and not text:find("Item Level", 1, true)
                    and not text:find("Prix de vente", 1, true)
                    and not text:find("Sell Price", 1, true)
                    and not text:find("+%d+ Endurance")
                    and not text:find("+%d+ Stamina")
                    and not text:find("^%+%d+ ")
                then
                    return text
                end

                if text:find("^%+%d+ ") and not text:find("Endurance", 1, true) and not text:find("Stamina", 1, true) then
                    return text
                end
            end
        end
    end

    return nil
end

local function GetGemNames(itemLink)
    local names = {}
    for _, gemID in ipairs(GetGemIDsFromLink(itemLink)) do
        local gemName = GetItemInfo(gemID)
        if gemName and gemName ~= "" then
            names[#names + 1] = gemName
        end
    end
    return names
end

local function CreateToggleButton(parent, anchor)
    local button = CreateFrame("Button", "BisManagerEnchantToggle", parent)
    button:SetSize(20, 20)
    button:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetColorTexture(0, 0, 0, 0.8)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 2, -2)
    button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    button.icon:SetTexture(ENCHANT_BUTTON_ICON)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.border = CreateFrame("Frame", nil, button)
    button.border:SetAllPoints()
    button.border.top = button.border:CreateTexture(nil, "OVERLAY")
    button.border.top:SetColorTexture(0.36, 0.78, 1, 0.9)
    button.border.top:SetPoint("TOPLEFT")
    button.border.top:SetPoint("TOPRIGHT")
    button.border.top:SetHeight(1)
    button.border.bottom = button.border:CreateTexture(nil, "OVERLAY")
    button.border.bottom:SetColorTexture(0.36, 0.78, 1, 0.9)
    button.border.bottom:SetPoint("BOTTOMLEFT")
    button.border.bottom:SetPoint("BOTTOMRIGHT")
    button.border.bottom:SetHeight(1)
    button.border.left = button.border:CreateTexture(nil, "OVERLAY")
    button.border.left:SetColorTexture(0.36, 0.78, 1, 0.9)
    button.border.left:SetPoint("TOPLEFT")
    button.border.left:SetPoint("BOTTOMLEFT")
    button.border.left:SetWidth(1)
    button.border.right = button.border:CreateTexture(nil, "OVERLAY")
    button.border.right:SetColorTexture(0.36, 0.78, 1, 0.9)
    button.border.right:SetPoint("TOPRIGHT")
    button.border.right:SetPoint("BOTTOMRIGHT")
    button.border.right:SetWidth(1)

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            if BisManager.ToggleConfigUI then
                BisManager:ToggleConfigUI()
            else
                BisManager:HandleSlashCommand("")
            end
            return
        end
        if BisManager.db and BisManager.db.display then
            BisManager.db.display.showEnchants = not BisManager.db.display.showEnchants
            BisManager:RefreshAll()
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local enabled = BisManager.db and BisManager.db.display and BisManager.db.display.showEnchants
        GameTooltip:AddLine(enabled and "Cacher enchantements" or "Afficher enchantements", 0.36, 0.78, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    function button:RefreshState()
        local enabled = BisManager.db and BisManager.db.display and BisManager.db.display.showEnchants
        self.icon:SetDesaturated(not enabled)
        self.icon:SetAlpha(enabled and 1 or 0.4)
        self.bg:SetColorTexture(0, 0, 0, enabled and 0.8 or 0.45)
    end

    button:RefreshState()
    return button
end

local function CreateEnchantIndicator(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(16, 16)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    frame:SetFrameStrata(parent:GetFrameStrata())
    frame:SetFrameLevel((parent:GetFrameLevel() or 1) + 6)
    frame:EnableMouse(true)

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.8)

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.text:SetPoint("CENTER", 0, 0)

    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["enchant_title"], 0.36, 0.78, 1)
        if not self.state then
            GameTooltip:AddLine(L["enchant_not_applicable"], 1, 1, 1, true)
        else
            if self.state.enchantExpected then
                if self.state.hasEnchant then
                    if self.state.enchantName then
                        GameTooltip:AddLine(self.state.enchantName, 0.3, 1, 0.3, true)
                    else
                        GameTooltip:AddLine(L["enchant_present"], 0.3, 1, 0.3, true)
                    end
                else
                    GameTooltip:AddLine(L["enchant_missing"], 1, 0.25, 0.25, true)
                end
            end
            if self.state.missingSockets and self.state.missingSockets > 0 then
                GameTooltip:AddLine(("%s (%d)"):format(L["gems_missing"], self.state.missingSockets), 1, 0.25, 0.25, true)
            elseif self.state.hasSockets then
                GameTooltip:AddLine(L["gems_ok"], 0.3, 1, 0.3, true)
                for _, gemName in ipairs(self.state.gemNames or {}) do
                    GameTooltip:AddLine(gemName, 1, 1, 1, true)
                end
            end
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)

    function frame:SetState(state)
        self.state = state
        if not state then
            self:Hide()
            return
        end
        if state.hasIssue then
            self.bg:SetColorTexture(0.25, 0.05, 0.05, 0.9)
            self.text:SetText("|cffff4c4c!|r")
        elseif state.enchantExpected or state.hasSockets then
            self.bg:SetColorTexture(0.05, 0.2, 0.05, 0.85)
            self.text:SetText("|cff4cff4cE|r")
        else
            self:Hide()
            return
        end
        self:Show()
    end

    frame:SetState(nil)
    return frame
end

local function UpdateIndicator(indicator, unit, slotID)
    if not indicator then
        return
    end
    if not BisManager.db or not BisManager.db.display or not BisManager.db.display.showEnchants then
        indicator:SetState(nil)
        return
    end
    local inventoryUnit = GetInventoryUnit(unit)
    local itemLink = GetInventoryItemLink(inventoryUnit, slotID)
    if not itemLink then
        indicator:SetState(nil)
        return
    end

    local enchantExpected = IsEnchantExpected(slotID)
    local hasEnchant = (GetEnchantIDFromLink(itemLink) or 0) > 0
    local totalSockets = GetSocketCountFromTooltip(itemLink)
    local gemNames = GetGemNames(itemLink)
    local missingSockets = math.max(totalSockets - #gemNames, 0)
    local hasSockets = totalSockets > 0
    local enchantName = hasEnchant and GetEnchantName(itemLink) or nil
    local hasIssue = (enchantExpected and not hasEnchant) or missingSockets > 0

    if not enchantExpected and not hasSockets then
        indicator:SetState(nil)
        return
    end

    indicator:SetState({
        enchantExpected = enchantExpected,
        hasEnchant = hasEnchant,
        enchantName = enchantName,
        missingSockets = missingSockets,
        hasSockets = hasSockets,
        gemNames = gemNames,
        hasIssue = hasIssue,
    })
end

function BisManager:InitializeEnchantUI()
    if self.enchantUiReady or not CharacterFrame then
        return
    end

    for _, slotDef in ipairs(SLOT_DEFINITIONS) do
        if slotDef.subSlots then
            for _, subSlot in ipairs(slotDef.subSlots) do
                local button = _G[subSlot.button]
                if button and not self.enchantIndicators[subSlot.button] then
                    self.enchantIndicators[subSlot.button] = CreateEnchantIndicator(button)
                end
            end
        elseif slotDef.button then
            local button = _G[slotDef.button]
            if button and not self.enchantIndicators[slotDef.button] then
                self.enchantIndicators[slotDef.button] = CreateEnchantIndicator(button)
            end
        end
    end

    if not self.enchantToggleBtn and self.charToggleBtn then
        self.enchantToggleBtn = CreateToggleButton(CharacterFrame, self.charToggleBtn)
    end

    self.enchantUiReady = true
end

function BisManager:RefreshEnchantDisplay()
    if not self.enchantUiReady then
        return
    end

    if self.enchantToggleBtn and self.enchantToggleBtn.RefreshState then
        self.enchantToggleBtn:RefreshState()
    end

    for _, slotDef in ipairs(SLOT_DEFINITIONS) do
        if slotDef.subSlots then
            for _, subSlot in ipairs(slotDef.subSlots) do
                UpdateIndicator(self.enchantIndicators[subSlot.button], "player", subSlot.slotID)
            end
        elseif slotDef.button and slotDef.slotID then
            UpdateIndicator(self.enchantIndicators[slotDef.button], "player", slotDef.slotID)
        end
    end
end

function BisManager:InitializeEnchantInspect()
    if self.inspectEnchantUiReady or not InspectFrame then
        return
    end

    for _, slotDef in ipairs(SLOT_DEFINITIONS) do
        if slotDef.subSlots then
            for _, subSlot in ipairs(slotDef.subSlots) do
                local button = _G[subSlot.inspectButton]
                if button and not self.inspectEnchantIndicators[subSlot.inspectButton] then
                    self.inspectEnchantIndicators[subSlot.inspectButton] = CreateEnchantIndicator(button)
                end
            end
        elseif slotDef.inspectButton then
            local button = _G[slotDef.inspectButton]
            if button and not self.inspectEnchantIndicators[slotDef.inspectButton] then
                self.inspectEnchantIndicators[slotDef.inspectButton] = CreateEnchantIndicator(button)
            end
        end
    end

    InspectFrame:HookScript("OnHide", function()
        BisManager:ClearInspectEnchantDisplay()
    end)

    self.inspectEnchantUiReady = true
end

function BisManager:ClearInspectEnchantDisplay()
    for _, indicator in pairs(self.inspectEnchantIndicators) do
        indicator:SetState(nil)
    end
end

function BisManager:RefreshEnchantInspectDisplay()
    if not self.inspectEnchantUiReady or not InspectFrame or not InspectFrame:IsShown() then
        return
    end

    for _, slotDef in ipairs(SLOT_DEFINITIONS) do
        if slotDef.subSlots then
            for _, subSlot in ipairs(slotDef.subSlots) do
                UpdateIndicator(self.inspectEnchantIndicators[subSlot.inspectButton], "inspect", subSlot.slotID)
            end
        elseif slotDef.inspectButton and slotDef.slotID then
            UpdateIndicator(self.inspectEnchantIndicators[slotDef.inspectButton], "inspect", slotDef.slotID)
        end
    end
end
