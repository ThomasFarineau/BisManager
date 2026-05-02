local BisManager = _G.BisManager
if not BisManager then
    return
end

local L = BisManager.L
local MINIMAP_ICON = BisManager.MINIMAP_ICON or "Interface/AddOns/BisManager/Assets/GameIcon"
local BD_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local LibStub = _G.LibStub
local LDB = LibStub and LibStub("LibDataBroker-1.1", true) or nil
local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true) or nil
local MINIMAP_LDB_NAME = "BisManager"

local function GetClassColor(classFile)
    local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile] or nil
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

local function HandleMinimapClick(mouseButton)
    if mouseButton == "RightButton" then
        if BisManager.ToggleConfigUI then
            BisManager:ToggleConfigUI()
        else
            BisManager:HandleSlashCommand("")
        end
        return
    end
    BisManager:ToggleGroupReport()
end

local function AddMinimapTooltipLines(tooltip)
    tooltip:AddLine(L["minimap_tooltip_title"], 0.36, 0.78, 1)
    local playerGuid = UnitGUID and UnitGUID("player") or nil
    local cachedIlvl = playerGuid and BisManager.GetCachedInspectAverageItemLevel and BisManager:GetCachedInspectAverageItemLevel(playerGuid) or nil
    if cachedIlvl then
        tooltip:AddLine("iLvl " .. BisManager:FormatAverageItemLevel(cachedIlvl), 1, 0.82, 0)
    end
    tooltip:AddLine(L["minimap_tooltip_desc"], 1, 1, 1, true)
    tooltip:AddLine(L["minimap_tooltip_right_click"], 0.8, 0.8, 0.8, true)
end

local function CollectGroupUnits()
    local units = {}
    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            units[#units + 1] = "raid" .. index
        end
    elseif IsInGroup() then
        units[#units + 1] = "player"
        for index = 1, GetNumSubgroupMembers() do
            units[#units + 1] = "party" .. index
        end
    else
        units[#units + 1] = "player"
    end
    return units
end

local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(300, 22)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * 24)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", 4, 0)
    row.nameText:SetPoint("RIGHT", -96, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    row.valueText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.valueText:SetPoint("RIGHT", -4, 0)
    row.valueText:SetJustifyH("RIGHT")

    row:Hide()
    return row
end

local function GetGroupReportSettings()
    local db = BisManager.db and BisManager.db.groupReport or nil
    if not db then
        return {
            width = 360,
            height = 410,
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
        }
    end
    return db
end

function BisManager:UpdateMinimapButtonPosition()
    if not self.db or not self.db.minimap then
        return
    end

    if DBIcon and self.minimapLauncher then
        self.db.minimap.minimapPos = self.db.minimap.angle or self.db.minimap.minimapPos or 220
        self.db.minimap.angle = self.db.minimap.minimapPos
        if self.db.minimap.hide then
            DBIcon:Hide(MINIMAP_LDB_NAME)
        else
            DBIcon:Show(MINIMAP_LDB_NAME)
        end
    end

    if not self.minimapButton or not Minimap then
        return
    end

    local angle = math.rad(self.db.minimap.angle or self.db.minimap.minimapPos or 220)
    local radius = (Minimap:GetWidth() / 2) + 5
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
    self.minimapButton:SetShown(not self.db.minimap.hide)
end

function BisManager:InitializeMinimapButton()
    if self.minimapLauncher then
        self:UpdateMinimapButtonPosition()
        return
    end

    if LDB and DBIcon and self.db and self.db.minimap then
        self.minimapLauncher = LDB:NewDataObject(MINIMAP_LDB_NAME, {
            type = "launcher",
            label = MINIMAP_LDB_NAME,
            text = MINIMAP_LDB_NAME,
            icon = MINIMAP_ICON,
            OnClick = function(_, mouseButton)
                HandleMinimapClick(mouseButton)
            end,
            OnTooltipShow = function(tooltip)
                AddMinimapTooltipLines(tooltip)
            end,
        })
        DBIcon:Register(MINIMAP_LDB_NAME, self.minimapLauncher, self.db.minimap)
        self:UpdateMinimapButtonPosition()
        return
    end

    if self.minimapButton or not Minimap then
        self:UpdateMinimapButtonPosition()
        return
    end

    local button = CreateFrame("Button", "BisManagerMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button.icon = button:CreateTexture(nil, "BACKGROUND")
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("CENTER")
    button.icon:SetTexture(MINIMAP_ICON)

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetAllPoints()
    button.border:SetTexture("Interface/Minimap/MiniMap-TrackingBorder")

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")
    button.highlight:SetBlendMode("ADD")
    button.highlight:SetAllPoints()

    button:SetScript("OnClick", function(_, mouseButton)
        HandleMinimapClick(mouseButton)
    end)
    button:SetScript("OnEnter", function(frame)
        GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
        AddMinimapTooltipLines(GameTooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript("OnDragStart", function()
        button:SetScript("OnUpdate", function()
            local scale = Minimap:GetEffectiveScale()
            local x, y = GetCursorPosition()
            local mx, my = Minimap:GetCenter()
            x = x / scale
            y = y / scale
            BisManager.db.minimap.angle = math.deg(math.atan(y - my, x - mx))
            BisManager.db.minimap.minimapPos = BisManager.db.minimap.angle
            BisManager:UpdateMinimapButtonPosition()
        end)
    end)
    button:SetScript("OnDragStop", function()
        button:SetScript("OnUpdate", nil)
    end)

    self.minimapButton = button
    self:UpdateMinimapButtonPosition()
end

function BisManager:InitializeGroupReportFrame()
    if self.groupReportFrame then
        return
    end

    local frame = CreateFrame("Frame", "BisManagerGroupReportFrame", UIParent, BD_TEMPLATE)
    local settings = GetGroupReportSettings()
    frame:SetSize(settings.width, settings.height)
    frame:SetPoint(settings.point, UIParent, settings.relativePoint, settings.x, settings.y)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetClampedToScreen(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(280, 220, 900, 900)
    else
        if frame.SetMinResize then
            frame:SetMinResize(280, 220)
        end
        if frame.SetMaxResize then
            frame:SetMaxResize(900, 900)
        end
    end
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        BisManager:SaveGroupReportFrameState()
    end)
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(0, 0, 0, 0.18)
    frame:Hide()

    frame.refresh = CreateFrame("Button", nil, frame)
    frame.refresh:SetSize(24, 24)
    frame.refresh:SetPoint("TOPLEFT", 8, -8)
    frame.refresh.icon = frame.refresh:CreateTexture(nil, "ARTWORK")
    frame.refresh.icon:SetAllPoints()
    frame.refresh.icon:SetTexture("Interface/Buttons/UI-RotationRight-Button-Up")
    frame.refresh.highlight = frame.refresh:CreateTexture(nil, "HIGHLIGHT")
    frame.refresh.highlight:SetAllPoints()
    frame.refresh.highlight:SetTexture("Interface/Buttons/ButtonHilight-Square")
    frame.refresh.highlight:SetBlendMode("ADD")
    frame.refresh:SetScript("OnClick", function()
        BisManager:RefreshGroupReport(true)
    end)
    frame.refresh:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_TOP")
        GameTooltip:AddLine(L["group_report_refresh"], 1, 1, 1)
        GameTooltip:Show()
    end)
    frame.refresh:SetScript("OnLeave", GameTooltip_Hide)

    frame.scroll = CreateFrame("ScrollFrame", nil, frame)
    frame.scroll:SetPoint("TOPLEFT", 8, -36)
    frame.scroll:SetPoint("BOTTOMRIGHT", -8, 8)
    frame.scroll:EnableMouseWheel(true)
    frame.scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local range = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(current - (delta * 24), range)))
    end)

    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.content:SetSize(300, 960)
    frame.scroll:SetScrollChild(frame.content)

    frame.rows = {}
    for index = 1, 40 do
        frame.rows[index] = CreateRow(frame.content, index)
    end

    frame.resize = CreateFrame("Button", nil, frame)
    frame.resize:SetSize(16, 16)
    frame.resize:SetPoint("BOTTOMRIGHT", -6, 6)
    frame.resize:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
    frame.resize:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
    frame.resize:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
    frame.resize:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    frame.resize:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        BisManager:SaveGroupReportFrameState()
    end)

    frame:SetScript("OnShow", function()
        BisManager:RefreshGroupReport()
    end)
    frame:SetScript("OnSizeChanged", function()
        BisManager:UpdateGroupReportLayout()
    end)

    self.groupReportFrame = frame
    self:UpdateGroupReportLayout()
end

function BisManager:ToggleGroupReport()
    self:InitializeGroupReportFrame()
    if self.groupReportFrame:IsShown() then
        self.groupReportFrame:Hide()
    else
        self.groupReportFrame:Show()
    end
end

function BisManager:SaveGroupReportFrameState()
    if not self.groupReportFrame or not self.db or not self.db.groupReport then
        return
    end

    local point, _, relativePoint, x, y = self.groupReportFrame:GetPoint(1)
    self.db.groupReport.point = point or "CENTER"
    self.db.groupReport.relativePoint = relativePoint or "CENTER"
    self.db.groupReport.x = x or 0
    self.db.groupReport.y = y or 0
    self.db.groupReport.width = self.groupReportFrame:GetWidth()
    self.db.groupReport.height = self.groupReportFrame:GetHeight()
end

function BisManager:UpdateGroupReportLayout()
    if not self.groupReportFrame then
        return
    end

    local frame = self.groupReportFrame
    local contentWidth = math.max(frame.scroll:GetWidth() - 8, 240)
    frame.content:SetWidth(contentWidth)
    frame.content:SetHeight(#frame.rows * 24)

    for _, row in ipairs(frame.rows) do
        row:SetWidth(contentWidth)
        row.nameText:ClearAllPoints()
        row.nameText:SetPoint("LEFT", 4, 0)
        row.nameText:SetPoint("RIGHT", -104, 0)
        row.valueText:ClearAllPoints()
        row.valueText:SetPoint("RIGHT", -4, 0)
    end
end

function BisManager:GetGroupReportEntries(forceInspect)
    self.tooltipIlvlCache = self.tooltipIlvlCache or {}

    if forceInspect then
        for _, unit in ipairs(CollectGroupUnits()) do
            if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                local guid = UnitGUID(unit)
                if guid then
                    self.tooltipIlvlCache[guid] = nil
                end
            end
        end
    end

    local pending = {}
    if self.groupInspectCurrentGUID then
        pending[self.groupInspectCurrentGUID] = true
    end
    if self.groupInspectQueue then
        for _, request in ipairs(self.groupInspectQueue) do
            pending[request.guid] = true
        end
    end

    local entries = {}
    local requests = {}
    local canDisplayIlvl = self:IsIlvlDisplayAllowed()
    for _, unit in ipairs(CollectGroupUnits()) do
        if UnitExists(unit) and UnitIsPlayer(unit) then
            local guid = UnitGUID(unit)
            local name = GetUnitName(unit, true) or UNKNOWN
            local _, classFile = UnitClass(unit)
            local r, g, b = GetClassColor(classFile)
            local entry = { guid = guid, unit = unit, name = name, color = { r, g, b } }

            if not canDisplayIlvl then
                entry.value = ""
                entry.valueColor = { 1, 1, 1 }
            elseif UnitIsUnit(unit, "player") then
                local itemLevel = self:GetAverageEquippedItemLevel("player")
                entry.value = itemLevel and self:FormatAverageItemLevel(itemLevel) or L["group_report_unavailable"]
                entry.valueColor = { 1, 0.82, 0 }
            else
                local cached = guid and self.tooltipIlvlCache[guid] or nil
                if cached then
                    entry.value = self:FormatAverageItemLevel(cached)
                    entry.valueColor = { 1, 0.82, 0 }
                elseif pending[guid] then
                    entry.value = L["group_report_loading"]
                    entry.valueColor = { 0.8, 0.8, 0.8 }
                elseif not UnitIsConnected(unit) then
                    entry.value = L["group_report_unavailable"]
                    entry.valueColor = { 1, 0.3, 0.3 }
                elseif CanInspect and CanInspect(unit, false) then
                    entry.value = L["group_report_loading"]
                    entry.valueColor = { 0.8, 0.8, 0.8 }
                    requests[#requests + 1] = { guid = guid, unit = unit }
                else
                    entry.value = L["group_report_out_of_range"]
                    entry.valueColor = { 1, 0.3, 0.3 }
                end
            end

            entries[#entries + 1] = entry
        end
    end

    return entries, requests
end

function BisManager:RenderGroupReport(entries)
    self:InitializeGroupReportFrame()

    for index, row in ipairs(self.groupReportFrame.rows) do
        local entry = entries[index]
        if entry then
            row.nameText:SetText(entry.name)
            row.nameText:SetTextColor(entry.color[1], entry.color[2], entry.color[3])
            row.valueText:SetText(entry.value or "")
            row.valueText:SetTextColor(entry.valueColor[1], entry.valueColor[2], entry.valueColor[3])
            row:Show()
        else
            row:Hide()
        end
    end

    if #entries == 0 then
        local row = self.groupReportFrame.rows[1]
        row.nameText:SetText(L["group_report_empty"])
        row.nameText:SetTextColor(0.8, 0.8, 0.8)
        row.valueText:SetText("")
        row:Show()
    end
end

function BisManager:ProcessGroupInspectQueue()
    if self.groupInspectCurrentGUID or not self.groupInspectQueue or #self.groupInspectQueue == 0 then
        return
    end
    if not self:IsIlvlDisplayAllowed() then
        return
    end
    if InCombatLockdown() then
        return
    end
    if self.tooltipInspectGUID then
        C_Timer.After(0.3, function()
            BisManager:ProcessGroupInspectQueue()
        end)
        return
    end
    if InspectFrame and InspectFrame:IsShown() then
        return
    end

    local request = table.remove(self.groupInspectQueue, 1)
    if not request or not request.guid or not request.unit or not UnitExists(request.unit) or UnitGUID(request.unit) ~= request.guid then
        self:ProcessGroupInspectQueue()
        return
    end
    if not CanInspect or not CanInspect(request.unit, false) or not NotifyInspect then
        self:ProcessGroupInspectQueue()
        return
    end

    self.groupInspectCurrentGUID = request.guid
    self.groupInspectCurrentUnit = request.unit
    NotifyInspect(request.unit)
    C_Timer.After(1.2, function()
        if BisManager.groupInspectCurrentGUID == request.guid then
            BisManager.groupInspectCurrentGUID = nil
            BisManager.groupInspectCurrentUnit = nil
            if BisManager.SafeClearInspectPlayer then
                BisManager.SafeClearInspectPlayer("group")
            elseif ClearInspectPlayer then
                ClearInspectPlayer()
            end
            if BisManager.groupReportFrame and BisManager.groupReportFrame:IsShown() then
                BisManager:RefreshGroupReport()
            end
            BisManager:ProcessGroupInspectQueue()
        end
    end)
end

function BisManager:HandleGroupReportCombatStateChanged()
    self.groupInspectQueue = {}
    self.groupInspectCurrentGUID = nil
    self.groupInspectCurrentUnit = nil
    if self.SafeClearInspectPlayer then
        self.SafeClearInspectPlayer("group")
    elseif ClearInspectPlayer then
        ClearInspectPlayer()
    end
    if self.groupReportFrame and self.groupReportFrame:IsShown() then
        self:RefreshGroupReport()
    end
end

function BisManager:HandleGroupReportInspectReady(guid)
    if not guid or guid ~= self.groupInspectCurrentGUID then
        return
    end

    local unit = self.groupInspectCurrentUnit
    self.groupInspectCurrentGUID = nil
    self.groupInspectCurrentUnit = nil

    if unit and UnitExists(unit) and UnitGUID(unit) == guid then
        local itemLevel = self:GetAverageEquippedItemLevel(unit)
        if itemLevel then
            self.tooltipIlvlCache = self.tooltipIlvlCache or {}
            self.tooltipIlvlCache[guid] = itemLevel
        end
    end

    if self.SafeClearInspectPlayer then
        self.SafeClearInspectPlayer("group")
    elseif ClearInspectPlayer then
        ClearInspectPlayer()
    end

    if self.groupReportFrame and self.groupReportFrame:IsShown() then
        self:RefreshGroupReport()
    end
    self:ProcessGroupInspectQueue()
end

function BisManager:RefreshGroupReport(forceInspect)
    if not self.groupReportFrame or not self.groupReportFrame:IsShown() then
        return
    end

    local entries, requests = self:GetGroupReportEntries(forceInspect)
    self:RenderGroupReport(entries)

    self.groupInspectQueue = {}
    local seen = {}
    for _, request in ipairs(requests) do
        if request.guid and not seen[request.guid] and request.guid ~= self.groupInspectCurrentGUID then
            self.groupInspectQueue[#self.groupInspectQueue + 1] = request
            seen[request.guid] = true
        end
    end
    self:ProcessGroupInspectQueue()
end
