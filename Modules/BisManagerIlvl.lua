local BisManager = _G.BisManager
if not BisManager then
    return
end

local SLOT_DEFINITIONS = BisManager.SLOT_DEFINITIONS
local TOOLTIP_GUID_UNITS = { "mouseover", "target", "focus", "player" }

-- Returns true when Blizzard's InspectFrame is currently showing inspected gear.
-- While that frame is up, calling ClearInspectPlayer() wipes the data that Blizzard
-- is actively displaying, which causes items to disappear and their tooltips to break.
local function IsBlizzardInspectActive()
    local frame = _G.InspectFrame
    return frame ~= nil and frame.IsShown and frame:IsShown()
end

-- Centralized guard around ClearInspectPlayer so the addon never races with
-- the Blizzard inspect UI or with another of its own pending inspect requests.
local function SafeClearInspectPlayer(owner)
    if not ClearInspectPlayer then
        return
    end
    if IsBlizzardInspectActive() then
        return
    end
    if BisManager.tooltipInspectGUID and owner ~= "tooltip" then
        return
    end
    if BisManager.groupInspectCurrentGUID and owner ~= "group" then
        return
    end
    if BisManager.pendingInspectImport and owner ~= "import" then
        return
    end
    ClearInspectPlayer()
end
BisManager.SafeClearInspectPlayer = SafeClearInspectPlayer

local function GetItemQualityColor(quality)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] or nil
    if color then
        return color.r, color.g, color.b
    end
    return 0.9, 0.9, 0.9
end

local function StripInspectItemLevelSuffix(text)
    return (text or ""):gsub("%s+%-%s+i[Ll]vl%s+[%d%.,]+$", "")
end

local function GetInspectNameLabel()
    return _G.InspectFrameTitleText or _G.InspectNameText
end

local function FormatInspectSummaryItemLevel(value)
    return ("%.1f"):format(tonumber(value) or 0)
end

local function SetSingleLineLabelWidth(label, width)
    if not label then
        return
    end
    label:SetMaxLines(1)
    label:SetWordWrap(false)
    if width then
        label:SetWidth(width)
    end
end

local function GetUnitDisplayName(unit, fallbackLabel)
    local unitName = unit and UnitName and UnitName(unit) or nil
    if unitName and unitName ~= "" then
        return unitName
    end
    return StripInspectItemLevelSuffix(fallbackLabel and fallbackLabel:GetText() or "")
end

local function FormatTooltipItemLevel(value)
    return "iLvl " .. BisManager:FormatAverageItemLevel(value)
end

local function GetLocalizedButtonText(key, fallback)
    local value = BisManager.L and BisManager.L[key] or nil
    if not value or value == key then
        return fallback
    end
    return value
end

local EQUIP_LOC_TO_SLOT_IDS = { INVTYPE_HEAD = { INVSLOT_HEAD }, INVTYPE_NECK = { INVSLOT_NECK }, INVTYPE_SHOULDER = { INVSLOT_SHOULDER }, INVTYPE_BODY = { INVSLOT_BODY }, INVTYPE_CHEST = { INVSLOT_CHEST }, INVTYPE_ROBE = { INVSLOT_CHEST }, INVTYPE_WAIST = { INVSLOT_WAIST }, INVTYPE_LEGS = { INVSLOT_LEGS }, INVTYPE_FEET = { INVSLOT_FEET }, INVTYPE_WRIST = { INVSLOT_WRIST }, INVTYPE_HAND = { INVSLOT_HAND }, INVTYPE_FINGER = { INVSLOT_FINGER1, INVSLOT_FINGER2 }, INVTYPE_TRINKET = { INVSLOT_TRINKET1, INVSLOT_TRINKET2 }, INVTYPE_CLOAK = { INVSLOT_BACK }, INVTYPE_WEAPON = { INVSLOT_MAINHAND, INVSLOT_OFFHAND }, INVTYPE_2HWEAPON = { INVSLOT_MAINHAND }, INVTYPE_WEAPONMAINHAND = { INVSLOT_MAINHAND }, INVTYPE_WEAPONOFFHAND = { INVSLOT_OFFHAND }, INVTYPE_SHIELD = { INVSLOT_OFFHAND }, INVTYPE_HOLDABLE = { INVSLOT_OFFHAND }, INVTYPE_RANGED = { INVSLOT_MAINHAND }, INVTYPE_RANGEDRIGHT = { INVSLOT_MAINHAND }, INVTYPE_THROWN = { INVSLOT_MAINHAND }, INVTYPE_RELIC = { INVSLOT_MAINHAND }, }

local function GetItemLevelData(itemLink)
    if not itemLink then
        return nil, nil
    end

    local itemLevel
    if GetDetailedItemLevelInfo then
        itemLevel = GetDetailedItemLevelInfo(itemLink)
    end
    if not itemLevel then
        local _, _, quality, fallbackItemLevel = GetItemInfo(itemLink)
        return tonumber(fallbackItemLevel), quality
    end

    local _, _, quality = GetItemInfo(itemLink)
    return tonumber(itemLevel), quality
end

local function CreateIlvlOverlay(parent, point, xOffset, yOffset)
    local overlay = parent:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    overlay:SetPoint(point or "BOTTOM", parent, point or "BOTTOM", xOffset or 0, yOffset or 2)
    overlay:SetShadowOffset(1, -1)
    overlay:SetShadowColor(0, 0, 0, 1)
    do
        local font, size, flags = overlay:GetFont()
        if font and size then
            overlay:SetFont(font, size + 1, flags)
        end
    end
    function overlay:ClearItemData()
        self:SetText("")
        self:Hide()
    end
    function overlay:SetItemData(itemLevel, quality)
        itemLevel = tonumber(itemLevel)
        if not itemLevel or itemLevel <= 1 then
            self:ClearItemData()
            return
        end
        local r, g, b = GetItemQualityColor(quality)
        self:SetTextColor(r, g, b)
        self:SetText(tostring(itemLevel))
        self:Show()
    end
    overlay:ClearItemData()
    return overlay
end

local function CreateBagUpgradeBorder(parent)
    local border = CreateFrame("Frame", nil, parent)
    border:SetPoint("CENTER", parent, "CENTER", 0, 0)
    border:SetSize(parent:GetWidth(), parent:GetHeight())
    border:SetFrameStrata(parent:GetFrameStrata())
    border:SetFrameLevel((parent:GetFrameLevel() or 1) + 5)

    border.top = border:CreateTexture(nil, "OVERLAY")
    border.top:SetColorTexture(0.2, 1, 0.2, 0.95)
    border.top:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
    border.top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
    border.top:SetHeight(2)

    border.bottom = border:CreateTexture(nil, "OVERLAY")
    border.bottom:SetColorTexture(0.2, 1, 0.2, 0.95)
    border.bottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 1, 1)
    border.bottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -1, 1)
    border.bottom:SetHeight(2)

    border.left = border:CreateTexture(nil, "OVERLAY")
    border.left:SetColorTexture(0.2, 1, 0.2, 0.95)
    border.left:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
    border.left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 1, 1)
    border.left:SetWidth(2)

    border.right = border:CreateTexture(nil, "OVERLAY")
    border.right:SetColorTexture(0.2, 1, 0.2, 0.95)
    border.right:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -1)
    border.right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -1, 1)
    border.right:SetWidth(2)

    border.anim = border:CreateAnimationGroup()
    border.anim:SetLooping("REPEAT")

    local fadeOut = border.anim:CreateAnimation("Alpha")
    fadeOut:SetOrder(1)
    fadeOut:SetFromAlpha(0.85)
    fadeOut:SetToAlpha(0.25)
    fadeOut:SetDuration(0.7)

    local fadeIn = border.anim:CreateAnimation("Alpha")
    fadeIn:SetOrder(2)
    fadeIn:SetFromAlpha(0.25)
    fadeIn:SetToAlpha(0.85)
    fadeIn:SetDuration(0.7)

    function border:ShowUpgrade()
        self:Show()
        if self.anim and not self.anim:IsPlaying() then
            self.anim:Play()
        end
    end

    function border:HideUpgrade()
        if self.anim and self.anim:IsPlaying() then
            self.anim:Stop()
        end
        self:Hide()
    end

    border:HideUpgrade()
    return border
end

local function GetEquippableSlotIDs(itemLink)
    if not itemLink or not GetItemInfoInstant then
        return nil
    end
    local _, _, _, equipLoc = GetItemInfoInstant(itemLink)
    return equipLoc and EQUIP_LOC_TO_SLOT_IDS[equipLoc] or nil
end

local function IsBagItemUpgrade(itemLink, itemLevel)
    local slotIDs = GetEquippableSlotIDs(itemLink)
    if not slotIDs or not itemLevel then
        return false
    end

    local lowestEquippedLevel
    for _, slotID in ipairs(slotIDs) do
        local equippedLevel = BisManager:GetItemLevel("player", slotID)
        if equippedLevel then
            if not lowestEquippedLevel or equippedLevel < lowestEquippedLevel then
                lowestEquippedLevel = equippedLevel
            end
        end
    end

    if not lowestEquippedLevel then
        return false
    end
    return itemLevel > lowestEquippedLevel
end

function BisManager:ClearInspectSummaryIlvl()
    if InspectLevelText then
        InspectLevelText:SetText(StripInspectItemLevelSuffix(InspectLevelText:GetText()))
    end
    local nameLabel = GetInspectNameLabel()
    if nameLabel then
        nameLabel:SetText(StripInspectItemLevelSuffix(nameLabel:GetText()))
    end
    if self.inspectIlvlText then
        self.inspectIlvlText:SetText("")
        self.inspectIlvlText:Hide()
    end
end

function BisManager:SetInspectSummaryIlvl(value)
    local nameLabel = GetInspectNameLabel()
    if nameLabel then
        local baseName = GetUnitDisplayName(self.inspectUnit, nameLabel)
        if baseName ~= "" then
            nameLabel:SetText(baseName .. " - " .. FormatInspectSummaryItemLevel(value))
        end
    elseif InspectLevelText then
        local baseText = StripInspectItemLevelSuffix(InspectLevelText:GetText())
        if baseText ~= "" then
            InspectLevelText:SetText(baseText .. " - " .. FormatInspectSummaryItemLevel(value))
        end
    else
        return
    end

    if self.inspectIlvlText then
        self.inspectIlvlText:SetText("")
        self.inspectIlvlText:Hide()
    end
end

function BisManager:GetAverageEquippedItemLevel(unit)
    local total, count = 0, 0
    for _, slotDef in ipairs(SLOT_DEFINITIONS) do
        if slotDef.subSlots then
            for _, subSlot in ipairs(slotDef.subSlots) do
                local itemLevel = self:GetItemLevel(unit, subSlot.slotID)
                if itemLevel then
                    total = total + itemLevel
                    count = count + 1
                end
            end
        elseif slotDef.slotID then
            local itemLevel = self:GetItemLevel(unit, slotDef.slotID)
            if itemLevel then
                total = total + itemLevel
                count = count + 1
            end
        end
    end
    if count == 0 then
        return nil
    end
    return total / count
end

function BisManager:GetCachedInspectAverageItemLevel(guid)
    if not guid then
        return nil
    end
    if self.db and type(self.db.ilvlCache) == "table" and self.db.ilvlCache[guid] then
        return self.db.ilvlCache[guid]
    end
    self.inspectIlvlCache = self.inspectIlvlCache or {}
    return self.inspectIlvlCache[guid]
end

function BisManager:SetCachedInspectAverageItemLevel(guid, value)
    if not guid or not value then
        return
    end
    self.inspectIlvlCache = self.inspectIlvlCache or {}
    self.inspectIlvlCache[guid] = value
    if self.db and type(self.db.ilvlCache) == "table" then
        self.db.ilvlCache[guid] = value
    end
end

function BisManager:CacheUnitAverageItemLevel(unit)
    unit = self:GetInventoryUnit(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end

    local guid = UnitGUID(unit)
    local averageItemLevel = self:GetAverageEquippedItemLevel(unit)
    if guid and averageItemLevel then
        self:SetCachedInspectAverageItemLevel(guid, averageItemLevel)
    end
    return averageItemLevel
end

function BisManager:ClearTooltipInspectState(tooltip)
    if tooltip then
        tooltip._gmIlvlUnitGUID = nil
        tooltip._gmIlvlText = nil
    end
    if self.tooltipInspectTooltip == tooltip or tooltip == nil then
        local hadPending = self.tooltipInspectGUID ~= nil
        self.tooltipInspectTooltip = nil
        self.tooltipInspectUnit = nil
        self.tooltipInspectGUID = nil
        if hadPending then
            SafeClearInspectPlayer("tooltip")
        end
    end
end

local function SafeUnitExists(unit)
    if not unit then
        return false
    end
    local ok, result = pcall(UnitExists, unit)
    return ok and result
end

local function SafeUnitGUID(unit)
    if not unit then
        return nil
    end
    local ok, result = pcall(UnitGUID, unit)
    if ok and result then
        return result
    end
    return nil
end

local function SafeStringsEqual(left, right)
    if left == nil or right == nil then
        return false
    end
    local ok, result = pcall(function()
        return left == right
    end)
    return ok and result
end

local function SafeUnitIsPlayer(unit)
    if not unit then
        return false
    end
    local ok, result = pcall(UnitIsPlayer, unit)
    return ok and result
end

local function SafeUnitIsUnit(unitA, unitB)
    if not unitA or not unitB then
        return false
    end
    local ok, result = pcall(UnitIsUnit, unitA, unitB)
    return ok and result
end

local function SafeCanInspect(unit)
    if not unit or not CanInspect then
        return false
    end
    local ok, result = pcall(CanInspect, unit, false)
    return ok and result
end

local function FindUnitByGUID(guid)
    if not guid then
        return nil
    end

    if UnitTokenFromGUID then
        local ok, unit = pcall(UnitTokenFromGUID, guid)
        if ok and unit and SafeUnitExists(unit) then
            return unit
        end
    end

    for _, unit in ipairs(TOOLTIP_GUID_UNITS) do
        if SafeUnitExists(unit) and SafeStringsEqual(SafeUnitGUID(unit), guid) then
            return unit
        end
    end
    for index = 1, 4 do
        local unit = "party" .. index
        if SafeUnitExists(unit) and SafeStringsEqual(SafeUnitGUID(unit), guid) then
            return unit
        end
    end
    for index = 1, 40 do
        local unit = "raid" .. index
        if SafeUnitExists(unit) and SafeStringsEqual(SafeUnitGUID(unit), guid) then
            return unit
        end
    end
    for index = 1, 40 do
        local unit = "nameplate" .. index
        if SafeUnitExists(unit) and SafeStringsEqual(SafeUnitGUID(unit), guid) then
            return unit
        end
    end
    return nil
end

function BisManager:ApplyTooltipUnitIlvl(tooltip, guid, value)
    if not tooltip or not guid or not value then
        return
    end

    local text = FormatTooltipItemLevel(value)
    if SafeStringsEqual(tooltip._gmIlvlUnitGUID, guid) and tooltip._gmIlvlText == text then
        return
    end

    tooltip:AddLine(text, 1, 0.82, 0)
    tooltip:Show()
    tooltip._gmIlvlUnitGUID = guid
    tooltip._gmIlvlText = text
end

function BisManager:HandleUnitTooltip(tooltip, tooltipData)
    if not tooltip or not tooltip.GetUnit then
        return
    end
    if not self:IsIlvlDisplayAllowed() then
        self:ClearTooltipInspectState(tooltip)
        return
    end

    local _, unit = tooltip:GetUnit()
    self:ClearTooltipInspectState(tooltip)
    local guid = unit and SafeUnitExists(unit) and SafeUnitGUID(unit) or nil
    if not guid and tooltipData and tooltipData.guid then
        guid = tooltipData.guid
        unit = FindUnitByGUID(guid)
    end
    if not guid or not unit or not SafeUnitExists(unit) or not SafeUnitIsPlayer(unit) then
        return
    end

    if SafeUnitIsUnit(unit, "player") then
        local averageItemLevel = self:CacheUnitAverageItemLevel("player")
        if averageItemLevel then
            self:ApplyTooltipUnitIlvl(tooltip, guid, averageItemLevel)
        end
        return
    end

    local cachedValue = self:GetCachedInspectAverageItemLevel(guid)
    if cachedValue then
        self:ApplyTooltipUnitIlvl(tooltip, guid, cachedValue)
        return
    end

    if InCombatLockdown() then
        return
    end

    -- Don't race Blizzard's InspectFrame: firing NotifyInspect here would
    -- preempt the inspect the user is actively looking at, wiping its items
    -- and tooltips. Skip the on-demand fetch; the cache will fill naturally
    -- once an inspect completes elsewhere (group report, manual inspect...).
    if IsBlizzardInspectActive() then
        return
    end

    -- Don't stomp on another pending inspect (group report, profile import).
    if self.groupInspectCurrentGUID or self.pendingInspectImport then
        return
    end

    if SafeCanInspect(unit) and NotifyInspect then
        self.tooltipInspectTooltip = tooltip
        self.tooltipInspectUnit = unit
        self.tooltipInspectGUID = guid
        NotifyInspect(unit)

        -- Watchdog: if INSPECT_READY never fires (target moved out of range,
        -- logged out, ...), clean up stale state after a few seconds so later
        -- tooltips can try again instead of being stuck.
        local pendingGUID = guid
        C_Timer.After(3, function()
            if BisManager.tooltipInspectGUID == pendingGUID then
                BisManager.tooltipInspectTooltip = nil
                BisManager.tooltipInspectUnit = nil
                BisManager.tooltipInspectGUID = nil
                SafeClearInspectPlayer("tooltip")
            end
        end)
    end
end

function BisManager:HandleTooltipInspectReady(guid)
    if not guid or not SafeStringsEqual(guid, self.tooltipInspectGUID) then
        return
    end

    local tooltip = self.tooltipInspectTooltip
    local unit = self.tooltipInspectUnit
    self.tooltipInspectTooltip = nil
    self.tooltipInspectUnit = nil
    self.tooltipInspectGUID = nil

    if not tooltip or not tooltip:IsShown() or not unit or not SafeUnitExists(unit) or not SafeStringsEqual(SafeUnitGUID(unit), guid) then
        SafeClearInspectPlayer("tooltip")
        return
    end

    local averageItemLevel = self:GetAverageEquippedItemLevel(unit)
    if averageItemLevel then
        self:SetCachedInspectAverageItemLevel(guid, averageItemLevel)
        self:ApplyTooltipUnitIlvl(tooltip, guid, averageItemLevel)
    end

    SafeClearInspectPlayer("tooltip")
end

function BisManager:InitializeTooltipIlvl()
    if self.tooltipIlvlHooked then
        return
    end

    local tooltip = GameTooltip
    local hasTooltipDataProcessor = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit
    if tooltip then
        tooltip:HookScript("OnHide", function(frame)
            BisManager:ClearTooltipInspectState(frame)
        end)
        if not hasTooltipDataProcessor then
            tooltip:HookScript("OnTooltipSetUnit", function(frame)
                BisManager:HandleUnitTooltip(frame)
            end)
        end
    end
    if hasTooltipDataProcessor then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(frame, tooltipData)
            BisManager:HandleUnitTooltip(frame, tooltipData)
        end)
    end

    self.tooltipIlvlHooked = true
end

local function ResolveButtonBagSlot(button, fallbackBagID, fallbackSlotID)
    if not button then
        return fallbackBagID, fallbackSlotID
    end

    local bagID = fallbackBagID
    if button.GetBagID then
        local ok, value = pcall(button.GetBagID, button)
        if ok and value ~= nil then
            bagID = value
        end
    end
    if bagID == nil then
        bagID = button.bagID
    end
    if bagID == nil then
        local parent = button:GetParent()
        if parent and parent.GetBagID then
            local ok, value = pcall(parent.GetBagID, parent)
            if ok and value ~= nil then
                bagID = value
            end
        end
    end

    local slotID = fallbackSlotID
    if button.GetID then
        local ok, value = pcall(button.GetID, button)
        if ok and value ~= nil and value > 0 then
            slotID = value
        end
    end
    if slotID == nil or slotID <= 0 then
        slotID = button.slotIndex or button.slotID
    end

    return bagID, slotID
end

local function GetBagItemLink(bagID, slotID)
    if bagID == nil or slotID == nil then
        return nil
    end
    if C_Container and C_Container.GetContainerItemLink then
        local ok, link = pcall(C_Container.GetContainerItemLink, bagID, slotID)
        if ok then
            return link
        end
    elseif GetContainerItemLink then
        local ok, link = pcall(GetContainerItemLink, bagID, slotID)
        if ok then
            return link
        end
    end
    return nil
end

local function IsEquippableItemLink(itemLink)
    if not itemLink or not GetItemInfoInstant then
        return false
    end
    local _, _, _, equipLoc = GetItemInfoInstant(itemLink)
    return equipLoc ~= nil and EQUIP_LOC_TO_SLOT_IDS[equipLoc] ~= nil
end

local function RefreshBagFrame(frame)
    if not frame or not frame:IsShown() then
        return
    end

    if frame.Items then
        for _, button in pairs(frame.Items) do
            if button and button.IsShown and button:IsShown() then
                BisManager:UpdateBagSlotOverlay(button)
            end
        end
        return
    end

    local bagID
    if frame.GetBagID then
        bagID = frame:GetBagID()
    elseif frame.GetID then
        bagID = frame:GetID()
    end
    if bagID == nil then
        return
    end

    local numSlots = 0
    if C_Container and C_Container.GetContainerNumSlots then
        numSlots = C_Container.GetContainerNumSlots(bagID) or 0
    elseif GetContainerNumSlots then
        numSlots = GetContainerNumSlots(bagID) or 0
    end

    for slotID = 1, numSlots do
        local button = _G[frame:GetName() .. "Item" .. slotID]
        if button and button:IsShown() then
            BisManager:UpdateBagSlotOverlay(button, bagID, slotID)
        end
    end
end

function BisManager:RefreshIlvlOverlays(unit)
    local overlays = (unit == "inspect") and self.inspectOverlays or self.ilvlOverlays
    local show = self:IsIlvlDisplayAllowed()
    local inventoryUnit = self:GetInventoryUnit(unit)

    for _, slotDef in ipairs(SLOT_DEFINITIONS) do
        if slotDef.subSlots then
            for _, subSlot in ipairs(slotDef.subSlots) do
                local buttonName = (unit == "inspect") and subSlot.inspectButton or subSlot.button
                local overlay = overlays[buttonName]
                if overlay then
                    if show then
                        local link = GetInventoryItemLink(inventoryUnit, subSlot.slotID)
                        local itemLevel, quality = GetItemLevelData(link)
                        overlay:SetItemData(itemLevel, quality)
                    else
                        overlay:ClearItemData()
                    end
                end
            end
        else
            local buttonName = (unit == "inspect") and slotDef.inspectButton or slotDef.button
            local overlay = overlays[buttonName]
            if overlay then
                if show then
                    local link = GetInventoryItemLink(inventoryUnit, slotDef.slotID)
                    local itemLevel, quality = GetItemLevelData(link)
                    overlay:SetItemData(itemLevel, quality)
                else
                    overlay:ClearItemData()
                end
            end
        end
    end
end

function BisManager:RefreshOverallIlvl()
    if not self.db or not self.overallIlvlText then
        return
    end
    if self:IsIlvlDisplayAllowed() then
        local equippedIlvl = self:GetOverallItemLevel()
        self.overallIlvlText:SetText(self:FormatAverageItemLevel(equippedIlvl))
        self.overallIlvlText:Show()
    else
        self.overallIlvlText:Hide()
    end
end

function BisManager:InitializeIlvlUI()
    if self.ilvlUiReady or not CharacterFrame then
        return
    end

    for _, slotDef in ipairs(SLOT_DEFINITIONS) do
        if slotDef.subSlots then
            for _, subSlot in ipairs(slotDef.subSlots) do
                local button = _G[subSlot.button]
                if button and not self.ilvlOverlays[subSlot.button] then
                    self.ilvlOverlays[subSlot.button] = CreateIlvlOverlay(button, "BOTTOM", 0, 2)
                end
            end
        else
            local button = _G[slotDef.button]
            if button and not self.ilvlOverlays[slotDef.button] then
                self.ilvlOverlays[slotDef.button] = CreateIlvlOverlay(button, "BOTTOM", 0, 2)
            end
        end
    end

    if not self.overallIlvlText then
        local anchor = CharacterLevelText or CharacterFrameTitleText
        if anchor then
            self.overallIlvlText = CharacterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            self.overallIlvlText:SetPoint("BOTTOM", anchor, "TOP", 0, -6)
            self.overallIlvlText:SetTextColor(1, 0.82, 0)
            self.overallIlvlText:Hide()
        end
    end

    self.ilvlUiReady = true
end

function BisManager:RefreshIlvlDisplay()
    self:RefreshIlvlOverlays("player")
    self:RefreshOverallIlvl()
    self:CacheUnitAverageItemLevel("player")
end

function BisManager:UpdateBagSlotOverlay(button, bagID, slotID)
    if not button then
        return
    end

    if not button._gm_ilvl then
        button._gm_ilvl = CreateIlvlOverlay(button, "BOTTOM", 0, 2)
    end
    if not button._gm_upgradeBorder then
        button._gm_upgradeBorder = CreateBagUpgradeBorder(button)
    end

    local overlay = button._gm_ilvl
    local border = button._gm_upgradeBorder
    if not self:IsIlvlDisplayAllowed() then
        overlay:ClearItemData()
        border:HideUpgrade()
        return
    end

    bagID, slotID = ResolveButtonBagSlot(button, bagID, slotID)
    local link = GetBagItemLink(bagID, slotID)
    if not IsEquippableItemLink(link) then
        overlay:ClearItemData()
        border:HideUpgrade()
        return
    end

    local itemLevel, quality = GetItemLevelData(link)
    overlay:SetItemData(itemLevel, quality)
    if IsBagItemUpgrade(link, itemLevel) then
        border:ShowUpgrade()
    else
        border:HideUpgrade()
    end
end

function BisManager:RefreshAllBagOverlays()
    for index = 1, 20 do
        RefreshBagFrame(_G["ContainerFrame" .. index])
    end
    RefreshBagFrame(_G["ContainerFrameCombinedBags"])
end

function BisManager:InitializeBags()
    if self.bagsInitialized then
        return
    end

    local function SafeHook(frame)
        if not frame then
            return
        end
        pcall(function()
            frame:HookScript("OnShow", function()
                C_Timer.After(0.05, function()
                    BisManager:RefreshAllBagOverlays()
                end)
            end)
        end)
    end

    for index = 1, 20 do
        SafeHook(_G["ContainerFrame" .. index])
    end
    SafeHook(_G["ContainerFrameCombinedBags"])

    self.bagsInitialized = true
end

function BisManager:InitializeInspect()
    if self.inspectHooked then
        return
    end

    local inspectFrame = InspectFrame
    if not inspectFrame then
        return
    end

    for _, slotDef in ipairs(SLOT_DEFINITIONS) do
        if slotDef.subSlots then
            for _, subSlot in ipairs(slotDef.subSlots) do
                local button = _G[subSlot.inspectButton]
                if button and not self.inspectOverlays[subSlot.inspectButton] then
                    self.inspectOverlays[subSlot.inspectButton] = CreateIlvlOverlay(button, "BOTTOM", 0, 2)
                end
            end
        elseif slotDef.inspectButton then
            local button = _G[slotDef.inspectButton]
            if button and not self.inspectOverlays[slotDef.inspectButton] then
                self.inspectOverlays[slotDef.inspectButton] = CreateIlvlOverlay(button, "BOTTOM", 0, 2)
            end
        end
    end

    local nameLabel = GetInspectNameLabel()
    if nameLabel then
        SetSingleLineLabelWidth(nameLabel, 220)
    end

    if not self.inspectImportBtn then
        self.inspectImportBtn = CreateFrame("Button", nil, inspectFrame, "UIPanelButtonTemplate")
        self.inspectImportBtn:SetSize(130, 22)
        self.inspectImportBtn:SetPoint("TOPLEFT", inspectFrame, "BOTTOMLEFT", 12, -42)
        self.inspectImportBtn:SetText(GetLocalizedButtonText("inspect_import_button", "Copier Equipement"))
        self.inspectImportBtn:SetScript("OnClick", function()
            local unit = BisManager.inspectUnit or (InspectFrame and InspectFrame.unit)
            local profileName = unit and UnitName(unit) or nil
            if not profileName or profileName == "" or not unit or not UnitExists(unit) then
                DEFAULT_CHAT_FRAME:AddMessage("|cff5cc8ffBisManager|r: " .. L["inspect_import_fail"])
                return
            end

            local guid = UnitGUID(unit)
            local count = BisManager:ImportProfileFromUnit(profileName, unit)
            if count > 0 then
                DEFAULT_CHAT_FRAME:AddMessage("|cff5cc8ffBisManager|r: " .. L["inspect_import_success"]:format(profileName, profileName))
                return
            end

            if guid and CanInspect and NotifyInspect and CanInspect(unit, false) then
                BisManager.pendingInspectImport = { guid = guid, profileName = profileName, unit = unit, retries = 2, }
                NotifyInspect(unit)
            else
                DEFAULT_CHAT_FRAME:AddMessage("|cff5cc8ffBisManager|r: " .. L["inspect_import_fail"])
            end
        end)
    end

    inspectFrame:HookScript("OnHide", function()
        BisManager.inspectUnit = nil
        BisManager.pendingInspectImport = nil
        for _, overlay in pairs(self.inspectOverlays) do
            overlay:ClearItemData()
        end
        BisManager:ClearInspectSummaryIlvl()
        if BisManager.inspectImportBtn then
            BisManager.inspectImportBtn:Hide()
        end
    end)
    inspectFrame:HookScript("OnShow", function(frame)
        BisManager.inspectUnit = frame.unit or BisManager.inspectUnit
        BisManager:ClearInspectSummaryIlvl()
        if BisManager.inspectImportBtn then
            BisManager.inspectImportBtn:Show()
        end
        C_Timer.After(0.1, function()
            BisManager:RefreshInspect()
        end)
    end)

    self.inspectHooked = true
end

function BisManager:RefreshInspect()
    if not self:IsIlvlDisplayAllowed() then
        self:ClearInspectSummaryIlvl()
        return
    end

    self.inspectUnit = (InspectFrame and InspectFrame.unit) or self.inspectUnit
    if not self.inspectUnit or not UnitExists(self.inspectUnit) then
        self:ClearInspectSummaryIlvl()
        return
    end

    self:RefreshIlvlOverlays("inspect")

    local averageItemLevel = self:CacheUnitAverageItemLevel("inspect")
    if averageItemLevel then
        self:SetInspectSummaryIlvl(averageItemLevel)
    else
        self:ClearInspectSummaryIlvl()
    end
end

function BisManager:HandleInspectImportReady(guid)
    local pending = self.pendingInspectImport
    if not pending or not SafeStringsEqual(pending.guid, guid) then
        return
    end

    self.pendingInspectImport = nil

    local unit = pending.unit
    if not unit or not UnitExists(unit) or not SafeStringsEqual(UnitGUID(unit), guid) then
        SafeClearInspectPlayer("import")
        DEFAULT_CHAT_FRAME:AddMessage("|cff5cc8ffBisManager|r: " .. L["inspect_import_fail"])
        return
    end

    local currentCount = self:CountEquippedItemsForUnit(unit)
    if currentCount == 0 and (pending.retries or 0) > 0 then
        pending.retries = pending.retries - 1
        self.pendingInspectImport = pending
        C_Timer.After(0.2, function()
            if BisManager.pendingInspectImport == pending and NotifyInspect and CanInspect and CanInspect(unit, false) then
                NotifyInspect(unit)
            end
        end)
        return
    end

    local count = self:ImportProfileFromUnit(pending.profileName, unit)
    if count == 0 and currentCount > 0 and (pending.retries or 0) > 0 then
        pending.retries = pending.retries - 1
        self.pendingInspectImport = pending
        C_Timer.After(0.2, function()
            if BisManager.pendingInspectImport == pending and NotifyInspect and CanInspect and CanInspect(unit, false) then
                NotifyInspect(unit)
            end
        end)
        return
    end

    SafeClearInspectPlayer("import")

    if count > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cff5cc8ffBisManager|r: " .. L["inspect_import_success"]:format(pending.profileName, pending.profileName))
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff5cc8ffBisManager|r: " .. L["inspect_import_fail"])
    end
end

function BisManager:HandleIlvlCombatStateChanged()
    if InCombatLockdown() then
        self:ClearInspectSummaryIlvl()
        self:ClearTooltipInspectState()
    end
end
