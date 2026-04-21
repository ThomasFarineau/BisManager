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
    badge:RegisterForClicks("LeftButtonUp", "RightButtonUp")

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
    badge:SetScript("OnClick", function(frame, button)
        if button == "RightButton" then
            local entries = BisManager:GetEntries(frame.slotKey)
            if entries and #entries > 0 then
                local itemID = entries[1].itemID
                local wowheadUrl = "https://www.wowhead.com/item=" .. itemID
                BisManager:OpenExternalUrl(wowheadUrl, CharacterFrame, "Lien Wowhead")
            end
        else
            if BisManager.OpenConfigForSlot then
                BisManager:OpenConfigForSlot(frame.slotKey)
            end
        end
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

function BisManager:RefreshCharacterToggleButtonState()
    local button = self.charToggleBtn
    if not button or not self.db or not self.db.display then
        return
    end

    local enabled = self.db.display.enabled
    button.icon:SetDesaturated(not enabled)
    button.icon:SetAlpha(enabled and 1 or 0.4)
    button.bg:SetColorTexture(0, 0, 0, enabled and 0.8 or 0.45)
    local borderColor = enabled and { 0.36, 0.78, 1, 0.95 } or { 0.38, 0.38, 0.38, 0.8 }
    button.border.top:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    button.border.bottom:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    button.border.left:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    button.border.right:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
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
    GameTooltip:AddLine("BiS - " .. slotDef.label, 0.36, 0.78, 1)
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
    local profile = self:GetProfile()
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
        local displaySource = self:GetDisplayItemSource(entry, profile)
        if displaySource and displaySource ~= "" then
            GameTooltip:AddLine(L["badge_source_fmt"]:format(displaySource), 1, 1, 1, true)
        end
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["badge_click_config"], 0.6, 0.6, 0.6)
    GameTooltip:AddLine(L["badge_click_wowhead"], 0.6, 0.6, 0.6)
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
        local button = CreateFrame("Button", "BisManagerCharToggle", CharacterFrame)
        button:SetSize(20, 20)
        button:SetPoint("TOPLEFT", modelParent, "TOPLEFT", 0, 28)
        button:SetFrameStrata("HIGH")
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        button.bg = button:CreateTexture(nil, "BACKGROUND")
        button.bg:SetAllPoints()
        button.bg:SetColorTexture(0, 0, 0, 0.8)

        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        button.icon:SetTexture(BisManager.ADDON_ICON or "Interface\\Icons\\INV_Misc_QuestionMark")
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        button.border = CreateFrame("Frame", nil, button)
        button.border:SetAllPoints()
        button.border.top = button.border:CreateTexture(nil, "OVERLAY")
        button.border.top:SetPoint("TOPLEFT")
        button.border.top:SetPoint("TOPRIGHT")
        button.border.top:SetHeight(1)
        button.border.bottom = button.border:CreateTexture(nil, "OVERLAY")
        button.border.bottom:SetPoint("BOTTOMLEFT")
        button.border.bottom:SetPoint("BOTTOMRIGHT")
        button.border.bottom:SetHeight(1)
        button.border.left = button.border:CreateTexture(nil, "OVERLAY")
        button.border.left:SetPoint("TOPLEFT")
        button.border.left:SetPoint("BOTTOMLEFT")
        button.border.left:SetWidth(1)
        button.border.right = button.border:CreateTexture(nil, "OVERLAY")
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
            if BisManager.db then
                BisManager.db.display.enabled = not BisManager.db.display.enabled
                BisManager:RefreshAll()
            end
        end)
        button:SetScript("OnEnter", function(frame)
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            local enabled = BisManager.db and BisManager.db.display and BisManager.db.display.enabled
            GameTooltip:AddLine(enabled and L["bis_on"] or L["bis_off"], 0.36, 0.78, 1)
            GameTooltip:AddLine(L["toggle_desc"], 1, 1, 1, true)
            GameTooltip:AddLine(L["toggle_right_click"], 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        self.charToggleBtn = button
        self:RefreshCharacterToggleButtonState()
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

    self:RefreshCharacterToggleButtonState()
end
