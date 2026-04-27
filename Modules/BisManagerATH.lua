local BisManager = _G.BisManager
if not BisManager then
    return
end

local TOOLTIP_GUID_UNITS = { "mouseover", "target", "focus", "player" }
local ATH_ICON = "Interface/AddOns/BisManager/Assets/GameIcon2"

local function IsBlizzardInspectActive()
    local frame = _G.InspectFrame
    return frame ~= nil and frame.IsShown and frame:IsShown()
end

local function SafeClearTooltipInspect()
    if BisManager.SafeClearInspectPlayer then
        BisManager.SafeClearInspectPlayer("tooltip")
    elseif ClearInspectPlayer then
        ClearInspectPlayer()
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
    if ok then
        return result
    end
    return nil
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

local function SafeStringsEqual(left, right)
    if left == nil or right == nil then
        return false
    end
    local ok, result = pcall(function()
        return left == right
    end)
    return ok and result
end

local function IsPlayerGUID(guid)
    if type(guid) ~= "string" then
        return false
    end
    -- Use the global strsub to avoid indexing `guid` directly, which can
    -- raise "attempt to index a secret string value" when the tooltip data
    -- carries a Blizzard-tainted GUID.
    local ok, prefix = pcall(strsub, guid, 1, 7)
    return ok and prefix == "Player-"
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

local function GetTooltipGUIDAndUnit(tooltip, tooltipData)
    local guid, unit

    if tooltipData and tooltipData.guid then
        guid = tooltipData.guid
    elseif tooltip and tooltip.GetUnit then
        local _, tooltipUnit = tooltip:GetUnit()
        unit = tooltipUnit
        guid = unit and SafeUnitExists(unit) and SafeUnitGUID(unit) or nil
    end

    if not IsPlayerGUID(guid) then
        return nil, nil
    end

    if not unit then
        unit = FindUnitByGUID(guid)
    end

    if not unit or not SafeUnitExists(unit) or not SafeUnitIsPlayer(unit) then
        if UnitGUID and SafeStringsEqual(guid, UnitGUID("player")) then
            unit = "player"
        else
            unit = nil
        end
    end

    return guid, unit
end

local function FormatTooltipATH(value)
    return "iLvl " .. BisManager:FormatAverageItemLevel(value)
end

function BisManager:EnsureTooltipATHWidget()
    if self.tooltipATHWidget then
        return self.tooltipATHWidget
    end

    local widget = CreateFrame("Frame", nil, GameTooltip, BackdropTemplateMixin and "BackdropTemplate" or nil)
    widget:SetPoint("BOTTOMLEFT", GameTooltip, "TOPLEFT", 0, 2)
    widget:SetFrameStrata("TOOLTIP")
    widget:SetFrameLevel((GameTooltip:GetFrameLevel() or 1) + 10)
    widget:SetClampedToScreen(true)

    if widget.SetBackdrop then
        widget:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        widget:SetBackdropColor(0.08, 0.08, 0.1, 0.96)
        widget:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end

    widget.icon = widget:CreateTexture(nil, "ARTWORK")
    widget.icon:SetSize(16, 16)
    widget.icon:SetPoint("LEFT", 8, 0)
    widget.icon:SetTexture(ATH_ICON)

    widget.text = widget:CreateFontString(nil, "ARTWORK", "GameTooltipText")
    widget.text:SetPoint("LEFT", widget.icon, "RIGHT", 6, 0)
    widget.text:SetPoint("BOTTOMRIGHT", -8, 6)
    widget.text:SetJustifyH("LEFT")
    widget.text:SetJustifyV("MIDDLE")
    widget.text:SetTextColor(1, 0.82, 0)

    widget:Hide()
    self.tooltipATHWidget = widget
    return widget
end

function BisManager:ShowTooltipATH(tooltip, guid, value)
    if not tooltip or tooltip ~= GameTooltip or not tooltip:IsShown() or not guid or not value then
        return
    end

    local widget = self:EnsureTooltipATHWidget()
    local text = FormatTooltipATH(value)
    widget.text:SetText(text)
    -- GetStringHeight() can return a "secret number" when the tooltip is
    -- tainted by Blizzard, so wrap it in pcall and fall back to a fixed height.
    local okH, strH = pcall(widget.text.GetStringHeight, widget.text)
    local height = 24
    if okH and type(strH) == "number" then
        local computed = strH + 12
        if computed > height then
            height = computed
        end
    end
    widget:SetHeight(height)
    widget:ClearAllPoints()
    widget:SetPoint("BOTTOMLEFT", tooltip, "TOPLEFT", 0, 2)
    widget:SetPoint("BOTTOMRIGHT", tooltip, "TOPRIGHT", 0, 2)
    widget:Show()

    tooltip._bmAthGuid = guid
    tooltip._bmAthText = text
end

function BisManager:HideTooltipATH()
    if self.tooltipATHWidget then
        self.tooltipATHWidget:Hide()
    end
end

function BisManager:ClearTooltipInspectState(tooltip)
    if self.tooltipInspectTooltip == tooltip or tooltip == nil then
        local hadPending = self.tooltipInspectGUID ~= nil
        self.tooltipInspectTooltip = nil
        self.tooltipInspectUnit = nil
        self.tooltipInspectGUID = nil
        if hadPending then
            SafeClearTooltipInspect()
        end
    end

    if tooltip then
        tooltip._bmAthGuid = nil
        tooltip._bmAthText = nil
    end

    self:HideTooltipATH()
end

function BisManager:RequestTooltipATHInspect(tooltip, guid, unit)
    if not tooltip or not guid or not unit then
        return
    end
    if InCombatLockdown() then
        return
    end
    if IsBlizzardInspectActive() then
        return
    end
    if self.groupInspectCurrentGUID or self.pendingInspectImport then
        return
    end
    if SafeStringsEqual(self.tooltipInspectGUID, guid) then
        return
    end
    if not SafeCanInspect(unit) or not NotifyInspect then
        return
    end

    self.tooltipInspectTooltip = tooltip
    self.tooltipInspectUnit = unit
    self.tooltipInspectGUID = guid
    NotifyInspect(unit)

    local pendingGUID = guid
    C_Timer.After(3, function()
        if BisManager.tooltipInspectGUID == pendingGUID then
            BisManager.tooltipInspectTooltip = nil
            BisManager.tooltipInspectUnit = nil
            BisManager.tooltipInspectGUID = nil
            SafeClearTooltipInspect()
        end
    end)
end

function BisManager:HandleTooltipATH(tooltip, tooltipData)
    if not tooltip then
        return
    end
    if not self:IsIlvlDisplayAllowed() then
        self:ClearTooltipInspectState(tooltip)
        return
    end

    local guid, unit = GetTooltipGUIDAndUnit(tooltip, tooltipData)
    if not guid then
        self:ClearTooltipInspectState(tooltip)
        return
    end

    if self.tooltipInspectTooltip == tooltip and self.tooltipInspectGUID and not SafeStringsEqual(self.tooltipInspectGUID, guid) then
        self:ClearTooltipInspectState(tooltip)
    end

    if SafeUnitIsUnit(unit, "player") then
        local itemLevel = self:CacheUnitAverageItemLevel("player")
        if itemLevel then
            self:ShowTooltipATH(tooltip, guid, itemLevel)
        else
            self:HideTooltipATH()
        end
        return
    end

    local cached = self:GetCachedInspectAverageItemLevel(guid)
    if cached then
        self:ShowTooltipATH(tooltip, guid, cached)
        return
    end

    self:HideTooltipATH()
    if unit then
        self:RequestTooltipATHInspect(tooltip, guid, unit)
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

    if not unit or not SafeUnitExists(unit) or not SafeStringsEqual(SafeUnitGUID(unit), guid) then
        SafeClearTooltipInspect()
        return
    end

    local averageItemLevel = self:GetAverageEquippedItemLevel(unit)
    if averageItemLevel then
        self:SetCachedInspectAverageItemLevel(guid, averageItemLevel)

        if tooltip and tooltip:IsShown() then
            local currentGuid = GetTooltipGUIDAndUnit(tooltip)
            if SafeStringsEqual(currentGuid, guid) then
                self:ShowTooltipATH(tooltip, guid, averageItemLevel)
            end
        end
    end

    SafeClearTooltipInspect()
end

function BisManager:InitializeTooltipIlvl()
    if self.tooltipATHInitialized then
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
                BisManager:HandleTooltipATH(frame)
            end)
        end
    end

    if hasTooltipDataProcessor then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(frame, tooltipData)
            BisManager:HandleTooltipATH(frame, tooltipData)
        end)
    end

    self.tooltipATHInitialized = true
end
