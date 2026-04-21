local BisManager = _G.BisManager
if not BisManager then
    return
end

local L = BisManager.L
local SLOT_DEFINITIONS = BisManager.SLOT_DEFINITIONS
local ENCHANT_BUTTON_ICON = "Interface\\Icons\\Trade_Engraving"
local tooltipScanner = CreateFrame("GameTooltip", "BisManagerEnchantScanner", UIParent, "GameTooltipTemplate")
local gemTooltipScanner = CreateFrame("GameTooltip", "BisManagerGemScanner", UIParent, "GameTooltipTemplate")
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
    return slotID and BisManager:IsEnchantableSlot(slotID) or false
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

local function GetTooltipLinesForScanner(scanner, textRegionPrefix, itemLink)
    if not itemLink then
        return {}
    end

    scanner:SetOwner(UIParent, "ANCHOR_NONE")
    scanner:ClearLines()
    scanner:SetHyperlink(itemLink)

    local lines = {}
    local numLines = scanner:NumLines() or 0
    for index = 1, numLines do
        local leftRegion = _G[textRegionPrefix .. index]
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

-- Build the localized "Enchanted" prefix from the Blizzard global so we can
-- reliably detect the enchant line across locales (frFR: "Enchanté : %s",
-- enUS: "Enchanted: %s", deDE: "Verzaubert: %s", etc.).
local function BuildEnchantPrefixes()
    local prefixes = {}
    local seen = {}
    local function add(template)
        if type(template) ~= "string" then
            return
        end
        local prefix = template:match("^(.-)%%s")
        if not prefix then
            return
        end
        prefix = prefix:gsub("%s+$", "")
        prefix = prefix:gsub("[:：]+%s*$", "")
        prefix = prefix:gsub("%s+$", "")
        if prefix ~= "" and not seen[prefix] then
            seen[prefix] = true
            prefixes[#prefixes + 1] = prefix
        end
    end
    add(_G.ENCHANTED_TOOLTIP_LINE)
    -- Safety fallbacks for the most common western clients.
    for _, fallback in ipairs({ "Enchanted", "Enchant", "Enchanté", "Verzaubert", "Encantado", "Incantato", "Encantamento" }) do
        if not seen[fallback] then
            seen[fallback] = true
            prefixes[#prefixes + 1] = fallback
        end
    end
    return prefixes
end

local ENCHANT_PREFIXES = BuildEnchantPrefixes()

local function ExtractEnchantName(text)
    if not text or text == "" then
        return nil
    end
    for _, prefix in ipairs(ENCHANT_PREFIXES) do
        if text:sub(1, #prefix) == prefix then
            local rest = text:sub(#prefix + 1)
            -- Require an explicit ":" separator so we don't match stat lines
            -- that merely start with the same letters.
            local name = rest:match("^%s*[:：]%s*(.+)$")
            if name and name ~= "" then
                return (name:gsub("%s+$", ""))
            end
        end
    end
    return nil
end

local function GetEnchantName(itemLink)
    if not itemLink then
        return nil
    end

    for index, line in ipairs(GetTooltipLines(itemLink)) do
        if index > 1 and line.text and line.text ~= "" then
            local name = ExtractEnchantName(StripColorCodes(line.text))
            if name then
                return name
            end
        end
    end

    return nil
end

local function IsGemBonusLine(line)
    if not line or not line.text then
        return false
    end

    local text = StripColorCodes(line.text)
    if not text or text == "" then
        return false
    end

    if text:find("^Item Level", 1, false)
        or text:find("^Niveau d'objet", 1, false)
        or text:find("^Prix de vente", 1, false)
        or text:find("^Sell Price", 1, false)
        or text:find("^Unique", 1, false)
        or text:find("^Lié", 1, false)
        or text:find("^Soulbound", 1, false)
        or text:find("^Binds", 1, false)
    then
        return false
    end

    return text:find("^%+")
        or text:find("^Equip:")
        or text:find("^Use:")
        or text:find("^Équipé")
        or text:find("^Utiliser")
        or ((line.g or 0) > 0.7 and (line.r or 1) < 0.8)
end

local function GetGemDetails(itemLink)
    local gems = {}
    for _, gemID in ipairs(GetGemIDsFromLink(itemLink)) do
        local gemName, gemLink, _, _, _, _, _, _, _, gemIcon = GetItemInfo(gemID)
        if gemName and gemName ~= "" then
            local bonuses = {}
            local resolvedLink = gemLink or ("item:" .. gemID)
            for index, line in ipairs(GetTooltipLinesForScanner(gemTooltipScanner, "BisManagerGemScannerTextLeft", resolvedLink)) do
                if index > 1 and IsGemBonusLine(line) then
                    bonuses[#bonuses + 1] = StripColorCodes(line.text)
                end
            end
            gems[#gems + 1] = {
                name = gemName,
                icon = gemIcon,
                bonuses = bonuses,
            }
        end
    end
    return gems
end

local function BuildGemTooltipLine(gem)
    if not gem then
        return nil
    end

    local iconText = gem.icon and ("|T" .. gem.icon .. ":0|t ") or ""
    local primaryText = gem.bonuses and gem.bonuses[1]
    if primaryText and primaryText ~= "" then
        return iconText .. primaryText
    end
    return iconText .. (gem.name or "")
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
        local borderColor = enabled and { 0.36, 0.78, 1, 0.95 } or { 0.38, 0.38, 0.38, 0.8 }
        self.border.top:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        self.border.bottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        self.border.left:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        self.border.right:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
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
            end
            for _, gem in ipairs(self.state.gems or {}) do
                local gemLine = BuildGemTooltipLine(gem)
                if gemLine then
                    GameTooltip:AddLine(gemLine, 1, 1, 1, true)
                end
                for bonusIndex = 2, #(gem.bonuses or {}) do
                    GameTooltip:AddLine(" - " .. gem.bonuses[bonusIndex], 0.75, 0.75, 0.75, true)
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
            self.text:SetText(state.enchantExpected and "|cff4cff4cE|r" or "|cff4cd2ffG|r")
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
        return true
    end
    if not BisManager.db or not BisManager.db.display or not BisManager.db.display.showEnchants then
        indicator:SetState(nil)
        return true
    end
    local inventoryUnit = GetInventoryUnit(unit)
    local itemLink = GetInventoryItemLink(inventoryUnit, slotID)
    if not itemLink then
        if unit ~= "inspect" then
            indicator:SetState(nil)
        end
        return false
    end

    local enchantExpected = IsEnchantExpected(slotID)
    local enchantName = GetEnchantName(itemLink)
    -- Some enchants (notably class runes and other consumable-applied effects)
    -- do not populate the enchantID field of the item link on every client,
    -- even though the tooltip clearly shows "Enchanté : ...". Treat either
    -- signal as proof of an active enchant so the badge reflects reality.
    local hasEnchant = ((GetEnchantIDFromLink(itemLink) or 0) > 0) or (enchantName ~= nil)
    local gems = GetGemDetails(itemLink)
    local emptySockets = GetSocketCountFromTooltip(itemLink)
    local totalSockets = math.max(emptySockets, #gems)
    local missingSockets = math.max(totalSockets - #gems, 0)
    local hasSockets = totalSockets > 0
    if not hasEnchant then
        enchantName = nil
    end
    local hasIssue = (enchantExpected and not hasEnchant) or missingSockets > 0

    if not enchantExpected and not hasSockets then
        indicator:SetState(nil)
        return true
    end

    indicator:SetState({
        enchantExpected = enchantExpected,
        hasEnchant = hasEnchant,
        enchantName = enchantName,
        missingSockets = missingSockets,
        hasSockets = hasSockets,
        gems = gems,
        hasIssue = hasIssue,
    })
    return true
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

function BisManager:QueueInspectEnchantRefresh(delay)
    if self.pendingInspectEnchantRefresh then
        return
    end

    self.pendingInspectEnchantRefresh = true
    C_Timer.After(delay or 0.2, function()
        BisManager.pendingInspectEnchantRefresh = nil
        if BisManager.RefreshEnchantInspectDisplay then
            BisManager:RefreshEnchantInspectDisplay()
        end
    end)
end

function BisManager:RefreshEnchantInspectDisplay()
    if not self.inspectEnchantUiReady or not InspectFrame or not InspectFrame:IsShown() then
        return
    end

    local refreshIncomplete = false
    for _, slotDef in ipairs(SLOT_DEFINITIONS) do
        if slotDef.subSlots then
            for _, subSlot in ipairs(slotDef.subSlots) do
                if not UpdateIndicator(self.inspectEnchantIndicators[subSlot.inspectButton], "inspect", subSlot.slotID) then
                    refreshIncomplete = true
                end
            end
        elseif slotDef.inspectButton and slotDef.slotID then
            if not UpdateIndicator(self.inspectEnchantIndicators[slotDef.inspectButton], "inspect", slotDef.slotID) then
                refreshIncomplete = true
            end
        end
    end

    if refreshIncomplete then
        self:QueueInspectEnchantRefresh(0.2)
    end
end
