-- CustomUI/Surface.lua
-- Panels, cards, and lightweight surface treatments.

local BisManager = _G.BisManager
local M = BisManager and BisManager.UI
if not M then
    return
end

local UI = M.colors
local PADDING = UI.layout.padding

function M.SkinPanel(frame, title)
    M.ApplyBackdrop(frame, UI.island, UI.line, UI.round.card)
    if title then
        frame.panelTitle = frame.panelTitle or frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        frame.panelTitle:ClearAllPoints()
        frame.panelTitle:SetPoint("TOPLEFT", PADDING, -PADDING)
        frame.panelTitle:SetText(title)
        frame.panelTitle:SetTextColor(0.96, 0.78, 0.35)
    end
    return frame
end

function M.CreateCard(parent, title, accent)
    local card = CreateFrame("Frame", nil, parent, M.BD_TEMPLATE)
    M.SkinPanel(card)
    card.bg = card.bg or card:CreateTexture(nil, "BACKGROUND", nil, -1)
    card.bg:ClearAllPoints()
    card.bg:SetPoint("TOPLEFT", UI.layout.radius, -UI.layout.radius)
    card.bg:SetPoint("BOTTOMRIGHT", -UI.layout.radius, UI.layout.radius)
    card.bg:SetColorTexture(UI.panel[1], UI.panel[2], UI.panel[3], 0.10)

    card.topGlow = card.topGlow or card:CreateTexture(nil, "BORDER")
    card.topGlow:SetColorTexture(0, 0, 0, 0)
    card.topGlow:Hide()

    if title then
        card.title = card.title or card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        card.title:ClearAllPoints()
        card.title:SetPoint("TOPLEFT", PADDING, -PADDING)
        card.title:SetText(title)
        local color = accent or UI.blue
        card.title:SetTextColor(color[1], color[2], color[3])
    end
    return card
end

M.CreateBentoCard = M.CreateCard
