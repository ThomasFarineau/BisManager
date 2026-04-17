local BisManager = _G.BisManager
if not BisManager then
    return
end

local L = BisManager.L
local SLOT_DEFINITIONS = BisManager.SLOT_DEFINITIONS
local SLOT_BY_KEY = BisManager.SLOT_BY_KEY
local DEFAULT_ICON = BisManager.DEFAULT_ICON or 134400

function BisManager:CreateEdge(parent)
    local edge = parent:CreateTexture(nil, "BORDER")
    edge:SetTexture("Interface/Buttons/WHITE8x8")
    return edge
end

function BisManager:CreateBadge(slotButton, slotKey, side)
    if not slotButton then
        return nil
    end

    local badge = CreateFrame("Button", nil, slotButton)
    badge:SetSize(28, 28)
    badge.slotKey = slotKey
    badge.side = side
    badge:SetFrameStrata(slotButton:GetFrameStrata())
    badge:SetFrameLevel(slotButton:GetFrameLevel() + 5)
    badge:RegisterForClicks("LeftButtonUp")

    if side == "LEFT" then
        badge:SetPoint("LEFT", slotButton, "RIGHT", 6, 0)
    elseif side == "RIGHT" then
        badge:SetPoint("RIGHT", slotButton, "LEFT", -6, 0)
    else
        badge:SetPoint("BOTTOM", slotButton, "TOP", 0, 6)
    end

    badge.background = badge:CreateTexture(nil, "BACKGROUND")
    badge.background:SetAllPoints()
    badge.background:SetColorTexture(0, 0, 0, 0.85)

    badge.icon = badge:CreateTexture(nil, "ARTWORK")
    badge.icon:SetPoint("TOPLEFT", 2, -2)
    badge.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    badge.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    badge.icon:SetTexture(DEFAULT_ICON)

    badge.topEdge = self:CreateEdge(badge)
    badge.topEdge:SetPoint("TOPLEFT")
    badge.topEdge:SetPoint("TOPRIGHT")
    badge.topEdge:SetHeight(2)

    badge.bottomEdge = self:CreateEdge(badge)
    badge.bottomEdge:SetPoint("BOTTOMLEFT")
    badge.bottomEdge:SetPoint("BOTTOMRIGHT")
    badge.bottomEdge:SetHeight(2)

    badge.leftEdge = self:CreateEdge(badge)
    badge.leftEdge:SetPoint("TOPLEFT")
    badge.leftEdge:SetPoint("BOTTOMLEFT")
    badge.leftEdge:SetWidth(2)

    badge.rightEdge = self:CreateEdge(badge)
    badge.rightEdge:SetPoint("TOPRIGHT")
    badge.rightEdge:SetPoint("BOTTOMRIGHT")
    badge.rightEdge:SetWidth(2)

    badge.status = badge:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    badge.status:SetPoint("BOTTOM", badge, "BOTTOM", 0, 2)
    badge.status:SetText(L["label_bis"])

    badge.count = badge:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    badge.count:SetPoint("TOPRIGHT", badge, "TOPRIGHT", 1, 4)
    badge.count:SetJustifyH("RIGHT")
    badge.count:SetText("")

    badge:SetScript("OnEnter", function(frame)
        BisManager:ShowBadgeTooltip(frame)
    end)
    badge:SetScript("OnLeave", GameTooltip_Hide)
    badge:SetScript("OnClick", function(frame)
        BisManager:ShowBadgeTooltip(frame)
    end)
    badge:Hide()
    return badge
end

function BisManager:SetBadgeBorderColor(badge, r, g, b, a)
    badge.topEdge:SetVertexColor(r, g, b, a)
    badge.bottomEdge:SetVertexColor(r, g, b, a)
    badge.leftEdge:SetVertexColor(r, g, b, a)
    badge.rightEdge:SetVertexColor(r, g, b, a)
end

function BisManager:ShowBadgeTooltip(badge)
    local slotDef = SLOT_BY_KEY[badge.slotKey]
    local entries = self:GetEntries(badge.slotKey)
    if not slotDef or not entries or #entries == 0 then
        return
    end

    local anchor = (badge.side == "LEFT") and "ANCHOR_RIGHT" or "ANCHOR_LEFT"
    GameTooltip:SetOwner(badge, anchor)
    GameTooltip:ClearLines()
    GameTooltip:AddLine("BisManager - " .. slotDef.label, 0.36, 0.78, 1)
    if slotDef.requiredCount then
        GameTooltip:AddLine(L["required_fmt"]:format(slotDef.requiredCount), 0.6, 0.6, 0.6)
    end

    local slotIDs = slotDef.subSlots and {} or { slotDef.slotID }
    if slotDef.subSlots then
        for _, subSlot in ipairs(slotDef.subSlots) do
            slotIDs[#slotIDs + 1] = subSlot.slotID
        end
    end

    for _, slotID in ipairs(slotIDs) do
        local equippedItemID = GetInventoryItemID("player", slotID)
        if equippedItemID then
            local prefix = self:HasConfiguredItem(slotDef.key, equippedItemID) and L["equipped_bis"] or L["equipped_not_bis"]
            local ilvl = self:GetItemLevel("player", slotID)
            local ilvlText = ilvl and (" |cffaaaaaa(ilvl " .. ilvl .. ")|r") or ""
            GameTooltip:AddLine(prefix .. " : " .. self:GetItemText(equippedItemID) .. ilvlText, 1, 1, 1, true)
        else
            GameTooltip:AddLine(L["no_item_slot"], 1, 0.82, 0.2)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["bis_configured"], 1, 1, 1)
    for index, entry in ipairs(entries) do
        local isEquipped = false
        for _, slotID in ipairs(slotIDs) do
            if GetInventoryItemID("player", slotID) == entry.itemID then
                isEquipped = true
                break
            end
        end
        local color = isEquipped and { 0.3, 1, 0.3 } or { 1, 1, 1 }
        GameTooltip:AddLine(("%d. %s"):format(index, self:GetBiSItemText(entry.itemID)), color[1], color[2], color[3], true)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["commands_hint"] .. string.lower(slotDef.key), 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

function BisManager:RefreshBadgeForSlot(badge, slotKey, slotID)
    local entries = self:GetEntries(slotKey)
    if not badge or not self.db or not self.db.display.enabled or not entries or #entries == 0 then
        if badge then
            badge:Hide()
        end
        return
    end

    local equippedItemID = slotID and GetInventoryItemID("player", slotID) or nil
    local isBis = equippedItemID and self:HasConfiguredItem(slotKey, equippedItemID) or false
    local primaryItemID = isBis and equippedItemID or entries[1].itemID
    local borderColor
    if isBis then
        borderColor = { 0.25, 0.92, 0.35, 1 }
    elseif equippedItemID then
        borderColor = { 0.95, 0.25, 0.25, 1 }
    else
        borderColor = { 0.95, 0.75, 0.25, 1 }
    end

    badge:SetScale(self.db.display.scale or 1)
    badge:SetAlpha(self.db.display.alpha or 1)
    badge.icon:SetTexture(self:GetItemIcon(primaryItemID))
    badge.status:SetText(isBis and L["label_ok"] or L["label_bis"])
    badge.count:SetText(#entries > 1 and tostring(#entries) or "")
    self:SetBadgeBorderColor(badge, borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    badge:Show()
end

function BisManager:InitializeBisUI()
    if self.bisUiReady or not CharacterFrame then
        return
    end

    for _, slotDef in ipairs(SLOT_DEFINITIONS) do
        if slotDef.subSlots then
            self.badges[slotDef.key] = self.badges[slotDef.key] or {}
            for index, subSlot in ipairs(slotDef.subSlots) do
                local button = _G[subSlot.button]
                if button and not self.badges[slotDef.key][index] then
                    self.badges[slotDef.key][index] = self:CreateBadge(button, slotDef.key, slotDef.side)
                end
            end
        else
            local button = _G[slotDef.button]
            if button and not self.badges[slotDef.key] then
                self.badges[slotDef.key] = self:CreateBadge(button, slotDef.key, slotDef.side)
            end
        end
    end

    if not self.charToggleBtn then
        local modelParent = CharacterModelScene or CharacterModelFrame or CharacterFrame
        local button = CreateFrame("Button", "BisManagerCharToggle", CharacterFrame, "UIPanelButtonTemplate")
        button:SetSize(65, 20)
        button:SetPoint("TOPLEFT", modelParent, "TOPLEFT", 0, 28)
        button:SetFrameStrata("HIGH")
        button:SetText(L["bis_on"])
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(_, mouseButton)
            if mouseButton == "RightButton" then
                if BisManager.ToggleConfigUI then
                    BisManager:ToggleConfigUI()
                else
                    BisManager:HandleSlashCommand("")
                end
                return
            end
            if BisManager.db then
                BisManager.db.display.enabled = not BisManager.db.display.enabled
                BisManager:RefreshAll()
            end
        end)
        button:SetScript("OnEnter", function(frame)
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:AddLine(L["toggle_title"])
            GameTooltip:AddLine(L["toggle_desc"], 1, 1, 1, true)
            GameTooltip:AddLine(L["toggle_right_click"], 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        self.charToggleBtn = button
    end

    self.bisUiReady = true
end

function BisManager:RefreshBisDisplay()
    if not self.db then
        return
    end

    for _, slotDef in ipairs(SLOT_DEFINITIONS) do
        if slotDef.subSlots then
            local badges = self.badges[slotDef.key]
            if badges then
                for index, subSlot in ipairs(slotDef.subSlots) do
                    if badges[index] then
                        self:RefreshBadgeForSlot(badges[index], slotDef.key, subSlot.slotID)
                    end
                end
            end
        elseif self.badges[slotDef.key] then
            self:RefreshBadgeForSlot(self.badges[slotDef.key], slotDef.key, slotDef.slotID)
        end
    end

    if self.charToggleBtn then
        self.charToggleBtn:SetText(self.db.display.enabled and L["bis_on"] or L["bis_off"])
    end
end
