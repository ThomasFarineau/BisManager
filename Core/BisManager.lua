local addonName, addon = ...
local L = addon.ResolveLocale()

local BisManager = CreateFrame("Frame")
_G.BisManager = BisManager
BisManager.badges = {}
BisManager.ilvlOverlays = {}
BisManager.inspectOverlays = {}
BisManager.bagOverlays = {}
BisManager.enchantIndicators = {}
BisManager.inspectEnchantIndicators = {}
BisManager.uiReady = false

local DEFAULT_ICON = 134400
local ADDON_ICON = "Interface/AddOns/BisManager/Assets/GameIcon"
local MINIMAP_ICON = "Interface/AddOns/BisManager/Assets/GameIcon"
local BIS_BONUS_IDS = { "13335", "12806" }
local sourceTooltipScanner = CreateFrame("GameTooltip", "BisManagerSourceScanner", UIParent, "GameTooltipTemplate")

------------------------------------------------------------------------
-- Slot definitions (no SHIRT/TABARD, merged FINGER/TRINKET)
------------------------------------------------------------------------

local SLOT_DEFINITIONS = { { key = "HEAD", label = L["slot_head"], slotID = INVSLOT_HEAD, button = "CharacterHeadSlot", inspectButton = "InspectHeadSlot", side = "LEFT", aliases = { "head", "tete", "casque" } }, { key = "NECK", label = L["slot_neck"], slotID = INVSLOT_NECK, button = "CharacterNeckSlot", inspectButton = "InspectNeckSlot", side = "LEFT", aliases = { "neck", "cou", "collier" } }, { key = "SHOULDER", label = L["slot_shoulder"], slotID = INVSLOT_SHOULDER, button = "CharacterShoulderSlot", inspectButton = "InspectShoulderSlot", side = "LEFT", aliases = { "shoulder", "epaules", "epaule" } }, { key = "CHEST", label = L["slot_chest"], slotID = INVSLOT_CHEST, button = "CharacterChestSlot", inspectButton = "InspectChestSlot", side = "LEFT", aliases = { "chest", "torse", "robe" } }, { key = "WAIST", label = L["slot_waist"], slotID = INVSLOT_WAIST, button = "CharacterWaistSlot", inspectButton = "InspectWaistSlot", side = "RIGHT", aliases = { "waist", "taille", "ceinture" } }, { key = "LEGS", label = L["slot_legs"], slotID = INVSLOT_LEGS, button = "CharacterLegsSlot", inspectButton = "InspectLegsSlot", side = "RIGHT", aliases = { "legs", "jambes", "pantalon" } }, { key = "FEET", label = L["slot_feet"], slotID = INVSLOT_FEET, button = "CharacterFeetSlot", inspectButton = "InspectFeetSlot", side = "RIGHT", aliases = { "feet", "pieds", "bottes" } }, { key = "HANDS", label = L["slot_hands"], slotID = INVSLOT_HAND, button = "CharacterHandsSlot", inspectButton = "InspectHandsSlot", side = "RIGHT", aliases = { "hands", "mains", "gants" } }, { key = "WRIST", label = L["slot_wrist"], slotID = INVSLOT_WRIST, button = "CharacterWristSlot", inspectButton = "InspectWristSlot", side = "LEFT", aliases = { "wrist", "poignets", "bracelets" } }, { key = "FINGER", label = L["slot_finger"], side = "RIGHT", requiredCount = 2, subSlots = { { slotID = INVSLOT_FINGER1, button = "CharacterFinger0Slot", inspectButton = "InspectFinger0Slot" }, { slotID = INVSLOT_FINGER2, button = "CharacterFinger1Slot", inspectButton = "InspectFinger1Slot" }, }, aliases = { "finger", "doigt", "ring", "anneau", "finger1", "finger2", "doigt1", "doigt2", "ring1", "ring2", "anneau1", "anneau2" }, }, { key = "TRINKET", label = L["slot_trinket"], side = "RIGHT", requiredCount = 2, subSlots = { { slotID = INVSLOT_TRINKET1, button = "CharacterTrinket0Slot", inspectButton = "InspectTrinket0Slot" }, { slotID = INVSLOT_TRINKET2, button = "CharacterTrinket1Slot", inspectButton = "InspectTrinket1Slot" }, }, aliases = { "trinket", "bijou", "trinket1", "trinket2", "bijou1", "bijou2" }, }, { key = "BACK", label = L["slot_back"], slotID = INVSLOT_BACK, button = "CharacterBackSlot", inspectButton = "InspectBackSlot", side = "LEFT", aliases = { "back", "dos", "cape" } }, { key = "MAINHAND", label = L["slot_mainhand"], slotID = INVSLOT_MAINHAND, button = "CharacterMainHandSlot", inspectButton = "InspectMainHandSlot", side = "BOTTOM", aliases = { "mainhand", "weapon", "arme", "maindroite" } }, { key = "OFFHAND", label = L["slot_offhand"], slotID = INVSLOT_OFFHAND, button = "CharacterSecondaryHandSlot", inspectButton = "InspectSecondaryHandSlot", side = "BOTTOM", aliases = { "offhand", "secondaire", "bouclier", "maingauche" } }, }

local SLOT_BY_KEY = {}
local SLOT_BY_ALIAS = {}

local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end
local function normalizeToken(s)
    return trim(string.lower(s or "")):gsub("[%s_%-]", "")
end
local function clamp(v, lo, hi)
    return v < lo and lo or (v > hi and hi or v)
end
local function chatPrint(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff5cc8ffBisManager|r: " .. msg)
end

function BisManager:OpenExternalUrl(url, parent, title)
    if not url or url == "" then
        return false
    end

    if ChatFrame_OpenExternalLink then
        ChatFrame_OpenExternalLink(url)
        return true
    end

    local host = parent or UIParent
    if host.BisManagerUrlPopup then
        host.BisManagerUrlPopup:Hide()
    end

    local popup = CreateFrame("Frame", nil, host, BackdropTemplateMixin and "BackdropTemplate" or nil)
    popup:SetSize(460, 92)
    popup:SetPoint("CENTER", host, "CENTER", 0, 0)
    popup:SetFrameStrata("TOOLTIP")
    if popup.SetBackdrop then
        popup:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        popup:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
        popup:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end

    popup.label = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    popup.label:SetPoint("TOPLEFT", 12, -10)
    popup.label:SetText(title or "Lien")

    popup.editBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    popup.editBox:SetSize(430, 24)
    popup.editBox:SetPoint("TOPLEFT", 12, -34)
    popup.editBox:SetAutoFocus(true)
    popup.editBox:SetText(url)
    popup.editBox:HighlightText()
    popup.editBox:SetCursorPosition(0)
    popup.editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        popup:Hide()
    end)

    popup.closeBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    popup.closeBtn:SetSize(80, 22)
    popup.closeBtn:SetPoint("BOTTOMRIGHT", -12, 10)
    popup.closeBtn:SetText(CLOSE or "Fermer")
    popup.closeBtn:SetScript("OnClick", function()
        popup:Hide()
    end)

    popup:SetScript("OnHide", function(self)
        if self.editBox then
            self.editBox:ClearFocus()
        end
    end)

    host.BisManagerUrlPopup = popup
    popup:Show()
    return true
end

local function copyEntries(entries)
    local copied = {}
    if type(entries) ~= "table" then
        return copied
    end
    for _, entry in ipairs(entries) do
        if type(entry) == "table" and tonumber(entry.itemID) then
            copied[#copied + 1] = {
                itemID = tonumber(entry.itemID),
                source = entry.source,
                sourceType = entry.sourceType,
            }
        end
    end
    return copied
end

for _, sd in ipairs(SLOT_DEFINITIONS) do
    SLOT_BY_KEY[sd.key] = sd
    SLOT_BY_ALIAS[normalizeToken(sd.key)] = sd.key
    SLOT_BY_ALIAS[normalizeToken(sd.label)] = sd.key
    for _, a in ipairs(sd.aliases) do
        SLOT_BY_ALIAS[normalizeToken(a)] = sd.key
    end
end

local function getSlotDefinition(token)
    local k = SLOT_BY_ALIAS[normalizeToken(token)]
    return k and SLOT_BY_KEY[k] or nil
end

BisManager.SLOT_DEFINITIONS = SLOT_DEFINITIONS
BisManager.SLOT_BY_KEY = SLOT_BY_KEY
BisManager.DEFAULT_ICON = DEFAULT_ICON
BisManager.ADDON_ICON = ADDON_ICON
BisManager.MINIMAP_ICON = MINIMAP_ICON
BisManager.L = L

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

function BisManager:OnEvent(event, ...)
    if self[event] then
        self[event](self, ...)
    end
end
BisManager:SetScript("OnEvent", BisManager.OnEvent)

------------------------------------------------------------------------
-- Database
------------------------------------------------------------------------

function BisManager:InitializeDatabase()
    -- Migrate from ManaBiS if needed
    if type(BisManagerDB) ~= "table" and type(ManaBiSDB) == "table" then
        BisManagerDB = ManaBiSDB
        ManaBiSDB = nil
    end
    if type(BisManagerDB) ~= "table" then
        BisManagerDB = {}
    end
    self.db = BisManagerDB
    if type(self.db.display) ~= "table" then
        self.db.display = {}
    end
    if self.db.display.enabled == nil then
        self.db.display.enabled = true
    end
    if type(self.db.display.scale) ~= "number" then
        self.db.display.scale = 1
    end
    if type(self.db.display.alpha) ~= "number" then
        self.db.display.alpha = 1
    end
    if self.db.display.showIlvl == nil then
        self.db.display.showIlvl = true
    end
    if self.db.display.showEnchants == nil then
        self.db.display.showEnchants = true
    end
    if type(self.db.minimap) ~= "table" then
        self.db.minimap = {}
    end
    if type(self.db.minimap.angle) ~= "number" then
        self.db.minimap.angle = 220
    end
    if type(self.db.minimap.minimapPos) ~= "number" then
        self.db.minimap.minimapPos = self.db.minimap.angle
    end
    self.db.minimap.angle = self.db.minimap.minimapPos
    if self.db.minimap.hide == nil then
        self.db.minimap.hide = false
    end
    if type(self.db.groupReport) ~= "table" then
        self.db.groupReport = {}
    end
    if type(self.db.groupReport.width) ~= "number" then
        self.db.groupReport.width = 360
    end
    if type(self.db.groupReport.height) ~= "number" then
        self.db.groupReport.height = 410
    end
    if type(self.db.groupReport.point) ~= "string" then
        self.db.groupReport.point = "CENTER"
    end
    if type(self.db.groupReport.relativePoint) ~= "string" then
        self.db.groupReport.relativePoint = "CENTER"
    end
    if type(self.db.groupReport.x) ~= "number" then
        self.db.groupReport.x = 0
    end
    if type(self.db.groupReport.y) ~= "number" then
        self.db.groupReport.y = 0
    end
    if type(self.db.profiles) ~= "table" then
        self.db.profiles = {}
    end
    if type(self.db.ilvlCache) ~= "table" then
        self.db.ilvlCache = {}
    end
    if type(self.db.activeProfile) ~= "string" or self.db.activeProfile == "" then
        self.db.activeProfile = "Default"
    end

    if type(self.db.slots) == "table" then
        self.db.profiles[self.db.activeProfile] = self.db.profiles[self.db.activeProfile] or {}
        self.db.profiles[self.db.activeProfile].slots = self.db.slots
        self.db.slots = nil
    end

    if next(self.db.profiles) == nil then
        self.db.profiles[self.db.activeProfile] = { slots = {} }
    end

    for profileName, profileData in pairs(self.db.profiles) do
        if type(profileData) ~= "table" then
            self.db.profiles[profileName] = { slots = {} }
        else
            profileData.slots = type(profileData.slots) == "table" and profileData.slots or {}
            for _, pair in ipairs({ { "FINGER1", "FINGER2", "FINGER" }, { "TRINKET1", "TRINKET2", "TRINKET" } }) do
                local old1, old2, newKey = pair[1], pair[2], pair[3]
                if profileData.slots[old1] or profileData.slots[old2] then
                    local merged = copyEntries(profileData.slots[newKey])
                    local seen = {}
                    for _, e in ipairs(merged) do
                        if e.itemID then
                            seen[e.itemID] = true
                        end
                    end
                    for _, oldKey in ipairs({ old1, old2 }) do
                        if type(profileData.slots[oldKey]) == "table" then
                            for _, e in ipairs(profileData.slots[oldKey]) do
                                if e.itemID and not seen[e.itemID] then
                                    merged[#merged + 1] = { itemID = tonumber(e.itemID) }
                                    seen[e.itemID] = true
                                end
                            end
                            profileData.slots[oldKey] = nil
                        end
                    end
                    profileData.slots[newKey] = merged
                end
            end
            profileData.slots["SHIRT"] = nil
            profileData.slots["TABARD"] = nil
            for slotKey, entries in pairs(profileData.slots) do
                if type(entries) ~= "table" then
                    profileData.slots[slotKey] = nil
                else
                    profileData.slots[slotKey] = copyEntries(entries)
                end
            end
        end
    end

    if not self.db.profiles[self.db.activeProfile] then
        self.db.activeProfile = next(self.db.profiles) or "Default"
        self.db.profiles[self.db.activeProfile] = self.db.profiles[self.db.activeProfile] or { slots = {} }
    end
end

------------------------------------------------------------------------
-- Item helpers
------------------------------------------------------------------------

function BisManager:ResolveItemID(text)
    text = trim(text)
    if text == "" then
        return nil, L["chat_no_item"]
    end
    local id = tonumber(text:match("^(%d+)$")) or tonumber(text:match("item:(%d+)"))
    if not id then
        local _, link = GetItemInfo(text)
        if link then
            id = tonumber(link:match("item:(%d+)"))
        end
    end
    if not id then
        return nil, L["chat_bad_item"]
    end
    return id
end

function BisManager:GetItemText(itemID)
    local _, link = GetItemInfo(itemID)
    return link or ("item:%d"):format(itemID)
end

function BisManager:GetBiSItemLink(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end

    local _, baseLink = GetItemInfo(itemID)
    if type(baseLink) == "string" then
        local prefix, payload, suffix = baseLink:match("^(.-|Hitem:)(.-)(|h%[.-%]|h|r)$")
        if prefix and payload and suffix then
            local fields = {}
            for field in (payload .. ":"):gmatch("(.-):") do
                fields[#fields + 1] = field
            end
            for index = #fields + 1, 12 do
                fields[index] = ""
            end
            fields[13] = tostring(#BIS_BONUS_IDS)
            for index, bonusID in ipairs(BIS_BONUS_IDS) do
                fields[13 + index] = bonusID
            end
            for index = #fields, 16, -1 do
                fields[index] = nil
            end
            return prefix .. table.concat(fields, ":") .. suffix
        end
    end

    return ("item:%d::::::::::::%d:%s"):format(itemID, #BIS_BONUS_IDS, table.concat(BIS_BONUS_IDS, ":"))
end

function BisManager:GetBiSItemText(itemID)
    return self:GetBiSItemLink(itemID) or self:GetItemText(itemID)
end

local function parseItemIDFromLink(link)
    if type(link) ~= "string" then
        return nil
    end
    return tonumber(link:match("item:(%d+)"))
end

local function GetSourceTooltipLines(itemLink)
    if not itemLink then
        return {}
    end

    sourceTooltipScanner:SetOwner(UIParent, "ANCHOR_NONE")
    sourceTooltipScanner:ClearLines()
    sourceTooltipScanner:SetHyperlink(itemLink)

    local lines = {}
    local numLines = sourceTooltipScanner:NumLines() or 0
    for index = 1, numLines do
        local leftRegion = _G["BisManagerSourceScannerTextLeft" .. index]
        if leftRegion then
            lines[#lines + 1] = leftRegion:GetText()
        end
    end
    return lines
end

function BisManager:EnsureItemSourceResolverState()
    self.itemSourceCache = self.itemSourceCache or {}
    self.itemSourceInfoCache = self.itemSourceInfoCache or {}
    self.itemSourcePending = self.itemSourcePending or {}
    self.itemSourceQueue = self.itemSourceQueue or {}
    self.itemSpecialSourceCache = self.itemSpecialSourceCache or {}
end

function BisManager:IsItemSourceLookupPending(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end
    self:EnsureItemSourceResolverState()
    return self.itemSourcePending[itemID] == true
end

function BisManager:FormatEncounterJournalSource(encounterName, instanceName)
    if encounterName and encounterName ~= "" and instanceName and instanceName ~= "" then
        return encounterName .. " - " .. instanceName
    end
    if encounterName and encounterName ~= "" then
        return encounterName
    end
    if instanceName and instanceName ~= "" then
        return instanceName
    end
    return nil
end

function BisManager:GetSpecialItemSource(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end

    self:EnsureItemSourceResolverState()
    local cached = self.itemSpecialSourceCache[itemID]
    if cached ~= nil then
        return cached or nil
    end

    local itemName
    local setID
    if C_Item and C_Item.GetItemInfo then
        itemName = C_Item.GetItemInfo(itemID)
        setID = select(16, C_Item.GetItemInfo(itemID))
    else
        itemName = GetItemInfo(itemID)
        setID = select(16, GetItemInfo(itemID))
    end

    if not itemName then
        if C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(itemID)
        end
        return nil
    end

    if tonumber(setID) and tonumber(setID) > 0 then
        self.itemSpecialSourceCache[itemID] = L["source_set"]
        return self.itemSpecialSourceCache[itemID]
    end

    local itemLink = self:GetItemText(itemID)
    if itemLink and itemLink ~= "" then
        for _, line in ipairs(GetSourceTooltipLines(itemLink)) do
            local text = tostring(line or "")
            if text ~= "" then
                if text:find("Crafted", 1, true)
                    or text:find("Crafting", 1, true)
                    or text:find("Fabri", 1, true)
                    or text:find("Confection", 1, true)
                    or text:find("Artisanat", 1, true)
                then
                    self.itemSpecialSourceCache[itemID] = L["source_crafting"]
                    return self.itemSpecialSourceCache[itemID]
                end
            end
        end
    end

    self.itemSpecialSourceCache[itemID] = false
    return nil
end

function BisManager:CollectEncounterJournalSource(itemID)
    if not EJ_GetNumSearchResults or not EJ_GetSearchResult then
        return nil
    end

    local results = {}
    local seen = {}
    local numResults = EJ_GetNumSearchResults() or 0
    for index = 1, numResults do
        local lootID, resultType, _, journalInstanceID, encounterID, itemLink = EJ_GetSearchResult(index)
        if resultType == 0 then
            local resultItemID = parseItemIDFromLink(itemLink)
            if not resultItemID and C_EncounterJournal and C_EncounterJournal.GetLootInfo then
                local info = C_EncounterJournal.GetLootInfo(lootID)
                resultItemID = info and info.itemID or nil
            elseif not resultItemID and EJ_GetLootInfo then
                resultItemID = select(1, EJ_GetLootInfo(lootID))
            end

            if tonumber(resultItemID) == tonumber(itemID) then
                local encounterName = encounterID and EJ_GetEncounterInfo and EJ_GetEncounterInfo(encounterID) or nil
                local instanceName = journalInstanceID and EJ_GetInstanceInfo and EJ_GetInstanceInfo(journalInstanceID) or nil
                local label = self:FormatEncounterJournalSource(encounterName, instanceName)
                if label and not seen[label] then
                    results[#results + 1] = {
                        label = label,
                        encounterID = encounterID,
                        journalInstanceID = journalInstanceID,
                        itemID = tonumber(itemID),
                    }
                    seen[label] = true
                end
            end
        end
    end

    if #results == 0 then
        return nil
    end

    table.sort(results, function(a, b)
        return (a.label or "") < (b.label or "")
    end)

    local labels = {}
    for index, result in ipairs(results) do
        labels[index] = result.label
    end

    local primary = results[1]
    return {
        label = table.concat(labels, "; "),
        encounterID = #results == 1 and primary.encounterID or nil,
        journalInstanceID = #results == 1 and primary.journalInstanceID or nil,
        itemID = tonumber(itemID),
    }
end

function BisManager:CompleteItemSourceLookup(itemID, resolvedSource)
    self:EnsureItemSourceResolverState()
    local sourceLabel = type(resolvedSource) == "table" and resolvedSource.label or resolvedSource
    self.itemSourceCache[itemID] = sourceLabel or false
    self.itemSourceInfoCache[itemID] = type(resolvedSource) == "table" and resolvedSource or false
    self.itemSourcePending[itemID] = nil
    self.itemSourceActive = nil

    if EJ_EndSearch then
        pcall(EJ_EndSearch)
    elseif EJ_ClearSearch then
        pcall(EJ_ClearSearch)
    end

    self:RefreshAll()

    local tooltipOwner = GameTooltip and GameTooltip:GetOwner() or nil
    if tooltipOwner and tooltipOwner.slotKey and self.ShowBadgeTooltip then
        self:ShowBadgeTooltip(tooltipOwner)
    end

    self:ProcessItemSourceQueue()
end

function BisManager:PollItemSourceLookup()
    local active = self.itemSourceActive
    if not active then
        return
    end

    local isFinished = true
    if EJ_IsSearchFinished then
        local ok, finished = pcall(EJ_IsSearchFinished)
        isFinished = ok and finished or false
    end

    local now = GetTime and GetTime() or 0
    if not isFinished and now - active.startedAt < 1.5 then
        C_Timer.After(0.1, function()
            if BisManager then
                BisManager:PollItemSourceLookup()
            end
        end)
        return
    end

    self:CompleteItemSourceLookup(active.itemID, self:CollectEncounterJournalSource(active.itemID))
end

function BisManager:ProcessItemSourceQueue()
    self:EnsureItemSourceResolverState()
    if self.itemSourceActive or #self.itemSourceQueue == 0 then
        return
    end
    if not EJ_SetSearch or not EJ_GetSearchResult then
        while #self.itemSourceQueue > 0 do
            local skippedItemID = table.remove(self.itemSourceQueue, 1)
            self.itemSourcePending[skippedItemID] = nil
            self.itemSourceCache[skippedItemID] = false
            self.itemSourceInfoCache[skippedItemID] = false
        end
        return
    end

    local itemID = table.remove(self.itemSourceQueue, 1)
    if self.itemSourceCache[itemID] ~= nil then
        self.itemSourcePending[itemID] = nil
        self:ProcessItemSourceQueue()
        return
    end

    local itemName = GetItemInfo(itemID)
    if not itemName then
        self.itemSourcePending[itemID] = nil
        if C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(itemID)
        end
        self:ProcessItemSourceQueue()
        return
    end

    self.itemSourceActive = {
        itemID = itemID,
        startedAt = GetTime and GetTime() or 0,
    }

    if EJ_EndSearch then
        pcall(EJ_EndSearch)
    elseif EJ_ClearSearch then
        pcall(EJ_ClearSearch)
    end

    local ok = pcall(EJ_SetSearch, itemName)
    if not ok then
        self:CompleteItemSourceLookup(itemID, nil)
        return
    end

    self:PollItemSourceLookup()
end

function BisManager:QueueItemSourceLookup(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return
    end

    self:EnsureItemSourceResolverState()
    if self.itemSourceCache[itemID] ~= nil or self.itemSourcePending[itemID] then
        return
    end

    self.itemSourcePending[itemID] = true
    self.itemSourceQueue[#self.itemSourceQueue + 1] = itemID
    self:ProcessItemSourceQueue()
end

function BisManager:GetEncounterJournalSource(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end

    self:EnsureItemSourceResolverState()
    local cached = self.itemSourceCache[itemID]
    if cached ~= nil then
        return cached or nil
    end

    self:QueueItemSourceLookup(itemID)
    return nil
end

function BisManager:GetEncounterJournalSourceInfo(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end

    self:EnsureItemSourceResolverState()
    local cached = self.itemSourceInfoCache[itemID]
    if cached ~= nil then
        return cached or nil
    end

    self:QueueItemSourceLookup(itemID)
    return nil
end

function BisManager:GetDisplayItemSourceData(entry, profile)
    if type(entry) ~= "table" then
        return nil
    end

    profile = profile or self:GetProfile()
    local rawSource = type(entry.source) == "string" and entry.source or nil
    local generatedProfile = profile and (profile.autoGenerated or profile.generatedPresetKey)
    local isLikelyManualSource = rawSource and rawSource ~= "" and (
        entry.sourceType == "manual"
        or (entry.sourceType ~= "generated" and not generatedProfile)
    )

    if isLikelyManualSource then
        local sourceUrl = rawSource:match("^https?://") and rawSource or nil
        if not sourceUrl and profile and profile.sourceUrl and profile.sourceUrl ~= "" then
            sourceUrl = profile.sourceUrl
        end
        return {
            label = rawSource,
            url = sourceUrl,
            kind = "manual",
        }
    end

    local specialSource = self:GetSpecialItemSource(entry.itemID)
    if specialSource and specialSource ~= "" then
        return {
            label = specialSource,
            kind = "special",
        }
    end

    local resolvedSource = self:GetEncounterJournalSourceInfo(entry.itemID)
    if resolvedSource and resolvedSource.label and resolvedSource.label ~= "" then
        resolvedSource.kind = "encounter_journal"
        return resolvedSource
    end
    if self:IsItemSourceLookupPending(entry.itemID) then
        return {
            label = L["source_loading"],
            kind = "loading",
        }
    end
    return nil
end

function BisManager:GetDisplayItemSource(entry, profile)
    local data = self:GetDisplayItemSourceData(entry, profile)
    return data and data.label or nil
end

function BisManager:OpenEncounterJournalSource(sourceInfo)
    if type(sourceInfo) ~= "table" or not sourceInfo.journalInstanceID then
        return false
    end

    if not EncounterJournal or not EncounterJournal_OpenJournal then
        local ok = pcall(UIParentLoadAddOn, "Blizzard_EncounterJournal")
        if not ok or not EncounterJournal_OpenJournal then
            return false
        end
    end

    local ok = pcall(EncounterJournal_OpenJournal, nil, sourceInfo.journalInstanceID, sourceInfo.encounterID, nil, nil, sourceInfo.itemID)
    return ok
end

function BisManager:GetItemIcon(itemID)
    if not itemID then
        return DEFAULT_ICON
    end
    if GetItemIcon then
        local i = GetItemIcon(itemID);
        if i then
            return i
        end
    end
    if C_Item and C_Item.GetItemIconByID then
        local i = C_Item.GetItemIconByID(itemID);
        if i then
            return i
        end
    end
    return DEFAULT_ICON
end

function BisManager:GetItemLevel(unit, slotID)
    if not slotID then
        return nil
    end
    local inventoryUnit = unit
    if inventoryUnit == "inspect" then
        inventoryUnit = (InspectFrame and InspectFrame.unit) or self.inspectUnit or "target"
    end
    local link = GetInventoryItemLink(inventoryUnit or "player", slotID)
    if not link then
        return nil
    end
    if GetDetailedItemLevelInfo then
        local ilvl = GetDetailedItemLevelInfo(link)
        if ilvl then
            return tonumber(ilvl)
        end
    end
    local _, _, _, lv = GetItemInfo(link)
    return lv
end

function BisManager:GetInventoryUnit(unit)
    if unit == "inspect" then
        return (InspectFrame and InspectFrame.unit) or self.inspectUnit or "target"
    end
    return unit or "player"
end

function BisManager:GetOverallItemLevel()
    if GetAverageItemLevel then
        local overall, equipped = GetAverageItemLevel()
        return tonumber(equipped) or 0, tonumber(overall) or 0
    end
    return 0, 0
end

function BisManager:FormatAverageItemLevel(value)
    return ("%.1f"):format(tonumber(value) or 0)
end

function BisManager:IsIlvlDisplayAllowed()
    return self.db and self.db.display and self.db.display.showIlvl
end

function BisManager:IsTooltipATHDisplayAllowed()
    return self:IsIlvlDisplayAllowed() and not InCombatLockdown()
end

function BisManager:GetProfileNames()
    local names = {}
    if not self.db or type(self.db.profiles) ~= "table" then
        return names
    end
    for name in pairs(self.db.profiles) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function BisManager:GetActiveProfileName()
    return self.db and self.db.activeProfile or "Default"
end

function BisManager:GetProfile(profileName)
    if not self.db or type(self.db.profiles) ~= "table" then
        return nil
    end
    return self.db.profiles[profileName or self.db.activeProfile]
end

function BisManager:GetOrCreateProfile(profileName)
    if not self.db then
        return nil
    end
    self.db.profiles = type(self.db.profiles) == "table" and self.db.profiles or {}
    profileName = trim(profileName or "") ~= "" and trim(profileName) or "Default"
    if type(self.db.profiles[profileName]) ~= "table" then
        self.db.profiles[profileName] = { slots = {} }
    end
    if type(self.db.profiles[profileName].slots) ~= "table" then
        self.db.profiles[profileName].slots = {}
    end
    return self.db.profiles[profileName]
end

function BisManager:SetActiveProfile(profileName)
    local profile = self:GetOrCreateProfile(profileName)
    if not profile then
        return false
    end
    self.db.activeProfile = trim(profileName or "") ~= "" and trim(profileName) or "Default"
    self:RefreshAll()
    return true
end

function BisManager:IsAutoProfile(profileName)
    local profile = self.db and self.db.profiles and self.db.profiles[profileName]
    return profile and profile.autoGenerated == true
end

function BisManager:DeleteProfile(profileName)
    if not self.db or type(self.db.profiles) ~= "table" then
        return false, "missing"
    end
    profileName = trim(profileName or "")
    if profileName == "" or not self.db.profiles[profileName] then
        return false, "missing"
    end
    if self:IsAutoProfile(profileName) then
        return false, "protected"
    end
    if self:GetProfileNames()[2] == nil then
        return false, "last"
    end
    self.db.profiles[profileName] = nil
    if self.db.activeProfile == profileName then
        self.db.activeProfile = self:GetProfileNames()[1]
    end
    self:RefreshAll()
    return true
end

function BisManager:CopyActiveProfileTo(profileName)
    local source = self:GetProfile()
    local target = self:GetOrCreateProfile(profileName)
    if not source or not target then
        return false
    end
    target.slots = {}
    for slotKey, entries in pairs(source.slots or {}) do
        target.slots[slotKey] = copyEntries(entries)
    end
    self:RefreshAll()
    return true
end

------------------------------------------------------------------------
-- Slot data access
------------------------------------------------------------------------

function BisManager:GetEntries(slotKey, profileName)
    local profile = self:GetProfile(profileName)
    local e = profile and profile.slots and profile.slots[slotKey]
    return type(e) == "table" and e or nil
end

function BisManager:HasConfiguredItem(slotKey, itemID)
    local entries = self:GetEntries(slotKey)
    if not entries or not itemID then
        return false
    end
    for _, e in ipairs(entries) do
        if e.itemID == itemID then
            return true
        end
    end
    return false
end

function BisManager:FindConfiguredItem(itemID, profileName)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end

    local profile = self:GetProfile(profileName)
    if not profile or type(profile.slots) ~= "table" then
        return nil
    end

    for _, slotDef in ipairs(SLOT_DEFINITIONS) do
        local entries = profile.slots[slotDef.key]
        if type(entries) == "table" then
            for _, entry in ipairs(entries) do
                if tonumber(entry.itemID) == itemID then
                    return slotDef.key, entry
                end
            end
        end
    end

    return nil
end

function BisManager:SetSlotItems(slotKey, itemIDs)
    local profile = self:GetOrCreateProfile(self:GetActiveProfileName())
    local t = {}
    for _, id in ipairs(itemIDs) do
        t[#t + 1] = { itemID = tonumber(id) }
    end
    profile.slots[slotKey] = t
    self:RefreshAll()
end

function BisManager:AddSlotItem(slotKey, itemID, source)
    local profile = self:GetOrCreateProfile(self:GetActiveProfileName())
    local entries = self:GetEntries(slotKey)
    if not entries then
        entries = {};
        profile.slots[slotKey] = entries
    end
    for _, e in ipairs(entries) do
        if e.itemID == itemID then
            return false
        end
    end
    entries[#entries + 1] = {
        itemID = tonumber(itemID),
        source = source,
        sourceType = (source and source ~= "") and "manual" or nil,
    }
    self:RefreshAll()
    return true
end

function BisManager:RemoveSlotItem(slotKey, token)
    local profile = self:GetOrCreateProfile(self:GetActiveProfileName())
    local entries = self:GetEntries(slotKey)
    if not entries or #entries == 0 then
        return false
    end
    local num = tonumber(token)
    local removed = false
    if num and num >= 1 and num <= #entries then
        table.remove(entries, num);
        removed = true
    else
        local rid = num or self:ResolveItemID(token)
        for i = #entries, 1, -1 do
            if entries[i].itemID == rid then
                table.remove(entries, i);
                removed = true
            end
        end
    end
    if removed then
        if #entries == 0 then
            profile.slots[slotKey] = nil
        end
        self:RefreshAll()
    end
    return removed
end

function BisManager:ClearSlot(slotKey)
    local profile = self:GetOrCreateProfile(self:GetActiveProfileName())
    profile.slots[slotKey] = nil
    self:RefreshAll()
end

function BisManager:SetItemSource(slotKey, itemID, source)
    local entries = self:GetEntries(slotKey)
    if not entries then return false end
    for _, e in ipairs(entries) do
        if e.itemID == itemID then
            if source and source ~= "" then
                e.source = source
                e.sourceType = "manual"
            else
                e.source = nil
                e.sourceType = nil
            end
            return true
        end
    end
    return false
end

function BisManager:GetItemSource(slotKey, itemID)
    local entries = self:GetEntries(slotKey)
    if not entries then return nil end
    for _, e in ipairs(entries) do
        if e.itemID == itemID then
            return self:GetDisplayItemSource(e)
        end
    end
    return nil
end

function BisManager:ClearActiveProfile()
    local profile = self:GetOrCreateProfile(self:GetActiveProfileName())
    profile.slots = {}
    self:RefreshAll()
end

------------------------------------------------------------------------
-- Import / Export (normalized format)
------------------------------------------------------------------------

function BisManager:ExportBiSString(profileName)
    local profile = self:GetProfile(profileName)
    if not profile or not profile.slots then
        return ""
    end
    local lines = {}
    for _, sd in ipairs(SLOT_DEFINITIONS) do
        local entries = self:GetEntries(sd.key, profileName)
        if entries and #entries > 0 then
            local ids = {}
            for _, e in ipairs(entries) do
                ids[#ids + 1] = tostring(e.itemID)
            end
            lines[#lines + 1] = sd.key .. "=" .. table.concat(ids, ",")
        end
    end
    return table.concat(lines, "\n")
end

function BisManager:ImportBiSString(input, profileName)
    if not input or input == "" then
        return 0
    end
    local profile = self:GetOrCreateProfile(profileName or self:GetActiveProfileName())
    local imported, temp = 0, {}
    for line in input:gmatch("[^\r\n]+") do
        line = trim(line)
        if line ~= "" and not line:match("^#") and not line:match("^%-%-") then
            local slot, items = line:match("^(%S+)%s*[=:]%s*(.+)$")
            if slot and items then
                local sd = getSlotDefinition(slot)
                if sd then
                    local ids = {}
                    for id in items:gmatch("(%d+)") do
                        local n = tonumber(id)
                        if n and n > 0 then
                            ids[#ids + 1] = n
                        end
                    end
                    if #ids > 0 then
                        if not temp[sd.key] then
                            temp[sd.key] = {}
                        end
                        for _, id in ipairs(ids) do
                            local found = false
                            for _, eid in ipairs(temp[sd.key]) do
                                if eid == id then
                                    found = true;
                                    break
                                end
                            end
                            if not found then
                                temp[sd.key][#temp[sd.key] + 1] = id;
                                imported = imported + 1
                            end
                        end
                    end
                end
            end
        end
    end
    if imported > 0 then
        for k, ids in pairs(temp) do
            profile.slots[k] = {}
            for _, id in ipairs(ids) do
                profile.slots[k][#profile.slots[k] + 1] = { itemID = id }
            end
        end
        self:RefreshAll()
    end
    return imported
end

function BisManager:ImportProfileFromUnit(profileName, unit)
    unit = self:GetInventoryUnit(unit)
    if not unit or not UnitExists(unit) then
        return 0
    end
    local profile = self:GetOrCreateProfile(profileName)
    if not profile then
        return 0
    end
    local count = 0
    profile.slots = {}
    for _, sd in ipairs(SLOT_DEFINITIONS) do
        if sd.subSlots then
            local items = {}
            for _, sub in ipairs(sd.subSlots) do
                local itemID = GetInventoryItemID(unit, sub.slotID)
                if itemID then
                    items[#items + 1] = { itemID = itemID }
                end
            end
            if #items > 0 then
                profile.slots[sd.key] = items
                count = count + #items
            end
        elseif sd.slotID then
            local itemID = GetInventoryItemID(unit, sd.slotID)
            if itemID then
                profile.slots[sd.key] = { { itemID = itemID } }
                count = count + 1
            end
        end
    end
    if count > 0 then
        self.db.activeProfile = trim(profileName or "") ~= "" and trim(profileName) or self.db.activeProfile
        self:RefreshAll()
    end
    return count
end

function BisManager:CountEquippedItemsForUnit(unit)
    unit = self:GetInventoryUnit(unit)
    if not unit or not UnitExists(unit) then
        return 0
    end

    local count = 0
    for _, sd in ipairs(SLOT_DEFINITIONS) do
        if sd.subSlots then
            for _, sub in ipairs(sd.subSlots) do
                if GetInventoryItemID(unit, sub.slotID) then
                    count = count + 1
                end
            end
        elseif sd.slotID and GetInventoryItemID(unit, sd.slotID) then
            count = count + 1
        end
    end
    return count
end

------------------------------------------------------------------------
-- Character UI coordination
------------------------------------------------------------------------

function BisManager:InitializeCharacterUI()
    if self.uiReady then
        self:RefreshAll()
        return
    end
    if not CharacterFrame then
        return
    end

    self:InitializeBisUI()
    self:InitializeIlvlUI()
    if self.InitializeEnchantUI then
        self:InitializeEnchantUI()
    end

    CharacterFrame:HookScript("OnShow", function()
        BisManager:RefreshAll()
    end)
    if PaperDollFrame then
        PaperDollFrame:HookScript("OnShow", function()
            BisManager:RefreshAll()
        end)
    end

    self.uiReady = true
    self:RefreshAll()
end

------------------------------------------------------------------------
-- Refresh All
------------------------------------------------------------------------

function BisManager:RefreshAll()
    if not self.db or not self.uiReady then
        return
    end
    self:RefreshBisDisplay()
    self:RefreshIlvlDisplay()
    if self.RefreshEnchantDisplay then
        self:RefreshEnchantDisplay()
    end
    if self.RefreshEnchantInspectDisplay then
        self:RefreshEnchantInspectDisplay()
    end
    self:RefreshAllBagOverlays()
    if self.RefreshConfigUI then
        self:RefreshConfigUI()
    end
end

------------------------------------------------------------------------
-- Character panel helpers
------------------------------------------------------------------------

function BisManager:OpenCharacterPanel()
    if not CharacterFrame then
        local fn = (C_AddOns and C_AddOns.LoadAddOn) or UIParentLoadAddOn
        if fn then
            pcall(fn, "Blizzard_CharacterUI")
        end
    end
    if ToggleCharacter then
        if not CharacterFrame or not CharacterFrame:IsShown() then
            ToggleCharacter("PaperDollFrame")
        else
            self:RefreshAll()
        end
    elseif CharacterFrame and ShowUIPanel then
        ShowUIPanel(CharacterFrame)
    end
    self:RefreshAll()
end

function BisManager:CaptureSlot(sd)
    if sd.subSlots then
        local ids = {}
        for _, sub in ipairs(sd.subSlots) do
            local id = GetInventoryItemID("player", sub.slotID)
            if id then
                ids[#ids + 1] = id
            end
        end
        if #ids == 0 then
            return false
        end
        self:SetSlotItems(sd.key, ids)
        return true
    end
    local id = sd.slotID and GetInventoryItemID("player", sd.slotID) or nil
    if not id then
        return false
    end
    self:SetSlotItems(sd.key, { id })
    return true
end

function BisManager:SnapshotCurrentGear()
    local profile = self:GetOrCreateProfile(self:GetActiveProfileName())
    local count = 0
    profile.slots = {}
    for _, sd in ipairs(SLOT_DEFINITIONS) do
        if sd.subSlots then
            local ids = {}
            for _, sub in ipairs(sd.subSlots) do
                local id = GetInventoryItemID("player", sub.slotID)
                if id then
                    ids[#ids + 1] = { itemID = id }
                end
            end
            if #ids > 0 then
                profile.slots[sd.key] = ids;
                count = count + 1
            end
        else
            local id = sd.slotID and GetInventoryItemID("player", sd.slotID) or nil
            if id then
                profile.slots[sd.key] = { { itemID = id } };
                count = count + 1
            end
        end
    end
    if count > 0 then
        self:RefreshAll()
    end
    return count
end

------------------------------------------------------------------------
-- Print / Help
------------------------------------------------------------------------

function BisManager:PrintSlot(sd)
    local entries = self:GetEntries(sd.key)
    if not entries or #entries == 0 then
        chatPrint(sd.label .. " : " .. L["no_bis_slot"]);
        return
    end
    local parts = {}
    for i, e in ipairs(entries) do
        parts[#parts + 1] = ("%d=%s"):format(i, self:GetItemText(e.itemID))
    end
    chatPrint(sd.label .. " : " .. table.concat(parts, ", "))
end

function BisManager:PrintAllSlots()
    local c = 0
    for _, sd in ipairs(SLOT_DEFINITIONS) do
        local entries = self:GetEntries(sd.key)
        if entries and #entries > 0 then
            c = c + 1;
            self:PrintSlot(sd)
        end
    end
    if c == 0 then
        chatPrint(L["chat_no_bis"])
    end
end

function BisManager:PrintProfiles()
    local names = self:GetProfileNames()
    if #names == 0 then
        chatPrint(L["chat_profile_none"])
        return
    end
    chatPrint(L["chat_profile_list"]:format(table.concat(names, ", ")))
    chatPrint(L["chat_profile_active"]:format(self:GetActiveProfileName()))
end

function BisManager:PrintHelp()
    chatPrint(L["help_main"])
    chatPrint(L["help_open"])
    chatPrint(L["help_panel"])
    chatPrint(L["help_set"])
    chatPrint(L["help_add"])
    chatPrint(L["help_remove"])
    chatPrint(L["help_clear"])
    chatPrint(L["help_capture"])
    chatPrint(L["help_snapshot"])
    chatPrint(L["help_import"])
    chatPrint(L["help_export"])
    chatPrint(L["help_ilvl"])
    chatPrint(L["help_misc"])
end

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------

function BisManager:HandleSlashCommand(msg)
    msg = trim(msg)
    if msg == "" then
        if self.ToggleConfigUI then
            self:ToggleConfigUI()
        else
            self:OpenCharacterPanel()
        end
        return
    end
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = string.lower(cmd or "");
    rest = trim(rest)

    if cmd == "help" or cmd == "aide" then
        self:PrintHelp();
        return
    end
    if cmd == "panel" or cmd == "char" or cmd == "personnage" then
        self:OpenCharacterPanel();
        return
    end
    if cmd == "show" or cmd == "afficher" then
        self.db.display.enabled = true;
        self:RefreshAll();
        chatPrint(L["chat_display_on"]);
        return
    end
    if cmd == "hide" or cmd == "masquer" then
        self.db.display.enabled = false;
        self:RefreshAll();
        chatPrint(L["chat_display_off"]);
        return
    end
    if cmd == "toggle" or cmd == "bascule" then
        self.db.display.enabled = not self.db.display.enabled;
        self:RefreshAll()
        chatPrint(self.db.display.enabled and L["chat_display_on"] or L["chat_display_off"]);
        return
    end
    if cmd == "scale" or cmd == "taille" then
        local v = tonumber(rest)
        if not v then
            chatPrint(L["chat_bad_value"]:format("scale", "1.1"));
            return
        end
        self.db.display.scale = clamp(v, 0.7, 1.6);
        self:RefreshAll()
        chatPrint(L["chat_scale_set"]:format(self.db.display.scale));
        return
    end
    if cmd == "alpha" or cmd == "opacite" then
        local v = tonumber(rest)
        if not v then
            chatPrint(L["chat_bad_value"]:format("alpha", "0.85"));
            return
        end
        self.db.display.alpha = clamp(v, 0.3, 1);
        self:RefreshAll()
        chatPrint(L["chat_alpha_set"]:format(self.db.display.alpha));
        return
    end
    if cmd == "snapshot" then
        local c = self:SnapshotCurrentGear()
        chatPrint(c > 0 and L["chat_snapshot_ok"]:format(c, self:GetActiveProfileName()) or L["chat_snapshot_none"]);
        return
    end
    if cmd == "profile" or cmd == "profil" then
        if rest == "" or rest == "list" or rest == "liste" then
            self:PrintProfiles()
            return
        end
        if self:SetActiveProfile(rest) then
            chatPrint(L["chat_profile_switched"]:format(self:GetActiveProfileName()))
        end
        return
    end
    if cmd == "import" then
        if rest == "" then
            chatPrint(L["chat_import_hint"])
        else
            local c = self:ImportBiSString(rest)
            chatPrint(c > 0 and L["chat_import_ok"]:format(c, self:GetActiveProfileName()) or L["chat_import_none"])
        end
        return
    end
    if cmd == "importprofile" or cmd == "importprofil" then
        local profileName, text = rest:match("^(%S+)%s+(.+)$")
        if not profileName or not text then
            chatPrint(L["chat_import_profile_hint"])
            return
        end
        local c = self:ImportBiSString(text, profileName)
        if c > 0 then
            self.db.activeProfile = profileName
            self:RefreshAll()
            chatPrint(L["chat_import_profile_ok"]:format(c, profileName))
        else
            chatPrint(L["chat_import_none"])
        end
        return
    end
    if cmd == "export" then
        local s = self:ExportBiSString()
        if s ~= "" then
            chatPrint(L["chat_export_title"]:format(self:GetActiveProfileName()))
            for line in s:gmatch("[^\n]+") do
                chatPrint("  " .. line)
            end
        else
            chatPrint(L["chat_export_none"])
        end
        return
    end
    if cmd == "exportprofile" or cmd == "exportprofil" then
        local profileName = rest ~= "" and rest or self:GetActiveProfileName()
        local s = self:ExportBiSString(profileName)
        if s ~= "" then
            chatPrint(L["chat_export_title"]:format(profileName))
            for line in s:gmatch("[^\n]+") do
                chatPrint("  " .. line)
            end
        else
            chatPrint(L["chat_export_none"])
        end
        return
    end
    if cmd == "ilvl" then
        self.db.display.showIlvl = not self.db.display.showIlvl;
        self:RefreshAll()
        chatPrint(self.db.display.showIlvl and L["chat_ilvl_on"] or L["chat_ilvl_off"]);
        return
    end
    if cmd == "list" or cmd == "liste" then
        if rest == "" then
            self:PrintAllSlots();
            return
        end
        local sd = getSlotDefinition(rest)
        if not sd then
            chatPrint(L["chat_slot_unknown"]:format(rest));
            return
        end
        self:PrintSlot(sd);
        return
    end
    if cmd == "clear" or cmd == "effacer" then
        if rest == "" then
            chatPrint(L["chat_use_clear"]);
            return
        end
        local norm = normalizeToken(rest)
        if norm == "all" or norm == "tout" then
            self:ClearActiveProfile()
            self:RefreshAll();
            chatPrint(L["chat_all_cleared"]:format(self:GetActiveProfileName()));
            return
        end
        local sd = getSlotDefinition(rest)
        if not sd then
            chatPrint(L["chat_slot_unknown"]:format(rest));
            return
        end
        self:ClearSlot(sd.key);
        chatPrint(L["chat_slot_cleared"]:format(sd.label));
        return
    end
    if cmd == "capture" then
        local sd = getSlotDefinition(rest)
        if not sd then
            chatPrint(L["chat_use_capture"]);
            return
        end
        if self:CaptureSlot(sd) then
            chatPrint(L["chat_capture_ok"]:format(sd.label))
        else
            chatPrint(L["chat_no_equip"]:format(sd.label))
        end
        return
    end
    if cmd == "set" or cmd == "add" or cmd == "remove" or cmd == "del" then
        local st, it = rest:match("^(%S+)%s+(.+)$")
        if not st then
            chatPrint(L["chat_cmd_incomplete"]:format(cmd));
            return
        end
        local sd = getSlotDefinition(st)
        if not sd then
            chatPrint(L["chat_slot_unknown"]:format(st));
            return
        end
        if cmd == "remove" or cmd == "del" then
            if self:RemoveSlotItem(sd.key, trim(it)) then
                chatPrint(L["chat_removed"]:format(sd.label))
            else
                chatPrint(L["chat_remove_fail"]:format(sd.label))
            end
            return
        end
        local id, err = self:ResolveItemID(it)
        if not id then
            chatPrint(err);
            return
        end
        if cmd == "set" then
            self:SetSlotItems(sd.key, { id });
            chatPrint(L["chat_bis_set"]:format(sd.label, self:GetItemText(id)));
            return
        end
        if self:AddSlotItem(sd.key, id) then
            chatPrint(L["chat_bis_added"]:format(sd.label, self:GetItemText(id)))
        else
            chatPrint(L["chat_bis_exists"]:format(sd.label))
        end
        return
    end
    chatPrint(L["chat_unknown_cmd"]:format(cmd));
    self:PrintHelp()
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

function BisManager:ADDON_LOADED(name)
    if name == addonName then
        self:InitializeDatabase()
    end
    if self.db and CharacterFrame then
        self:InitializeCharacterUI()
    end
    if name == "Blizzard_InspectUI" then
        self:InitializeInspect()
        if self.InitializeEnchantInspect then
            self:InitializeEnchantInspect()
        end
    end
end

function BisManager:PLAYER_LOGIN()
    if CharacterFrame then
        self:InitializeCharacterUI()
    end
    if InspectFrame and self.InitializeEnchantInspect then
        self:InitializeEnchantInspect()
    end
    self:InitializeBags()
    if self.AutoCreateBiSProfiles then
        self:AutoCreateBiSProfiles()
    end
    if self.InitializeTooltipIlvl then
        self:InitializeTooltipIlvl()
    end
    if self.InitializeTooltipBiS then
        self:InitializeTooltipBiS()
    end
    if self.InitializeMinimapButton then
        self:InitializeMinimapButton()
    end
    self:RefreshAll()
end

function BisManager:PLAYER_EQUIPMENT_CHANGED()
    self:RefreshAll()
end

function BisManager:UNIT_INVENTORY_CHANGED(unit)
    if unit == "player" then
        self:RefreshAll()
    end
end

function BisManager:GET_ITEM_INFO_RECEIVED()
    self:RefreshAll()
end

function BisManager:INSPECT_READY(guid)
    if self.HandleTooltipInspectReady then
        self:HandleTooltipInspectReady(guid)
    end
    if self.HandleGroupReportInspectReady then
        self:HandleGroupReportInspectReady(guid)
    end
    if self.HandleInspectImportReady then
        self:HandleInspectImportReady(guid)
    end
    C_Timer.After(0.3, function()
        BisManager:RefreshInspect()
        if BisManager.RefreshEnchantInspectDisplay then
            BisManager:RefreshEnchantInspectDisplay()
        end
    end)
end

function BisManager:BAG_UPDATE_DELAYED()
    self:RefreshAllBagOverlays()
end

function BisManager:GROUP_ROSTER_UPDATE()
    if self.RefreshGroupReport then
        self:RefreshGroupReport()
    end
end

function BisManager:HandleCombatStateChanged(inCombat)
    if self.HandleIlvlCombatStateChanged then
        self:HandleIlvlCombatStateChanged(inCombat)
    end
    if self.HandleGroupReportCombatStateChanged then
        self:HandleGroupReportCombatStateChanged(inCombat)
    end
end

function BisManager:PLAYER_REGEN_DISABLED()
    if self.HandleCombatStateChanged then
        self:HandleCombatStateChanged(true)
    end
    self:RefreshAll()
    if self.RefreshInspect then
        self:RefreshInspect()
    end
end

function BisManager:PLAYER_REGEN_ENABLED()
    if self.HandleCombatStateChanged then
        self:HandleCombatStateChanged(false)
    end
    self:RefreshAll()
    if self.RefreshInspect then
        self:RefreshInspect()
    end
end

SLASH_BisManager1 = "/bis"
SLASH_BisManager2 = "/bm"
SLASH_BisManager3 = "/bismanager"
SlashCmdList.BisManager = function(msg)
    BisManager:HandleSlashCommand(msg)
end

BisManager:RegisterEvent("ADDON_LOADED")
BisManager:RegisterEvent("PLAYER_LOGIN")
BisManager:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
BisManager:RegisterEvent("UNIT_INVENTORY_CHANGED")
BisManager:RegisterEvent("GET_ITEM_INFO_RECEIVED")
BisManager:RegisterEvent("INSPECT_READY")
BisManager:RegisterEvent("BAG_UPDATE_DELAYED")
BisManager:RegisterEvent("GROUP_ROSTER_UPDATE")
BisManager:RegisterEvent("PLAYER_REGEN_DISABLED")
BisManager:RegisterEvent("PLAYER_REGEN_ENABLED")

