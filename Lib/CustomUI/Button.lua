-- CustomUI/Button.lua
-- Flat buttons and compact icon buttons.

local BisManager = _G.BisManager
local M = BisManager and BisManager.UI
if not M then
    return
end

local UI = M.colors
local RADIUS = UI.layout.radius

function M.GetButtonColors(accentColor, danger)
    if danger then
        return UI.danger, UI.dangerHover, { 1, 0.92, 0.94 }
    end
    if accentColor == UI.green then
        return UI.success, UI.successHover, { 0.94, 1, 0.96 }
    end
    if accentColor == UI.gold then
        return UI.amber, UI.amberHover, { 1, 0.96, 0.86 }
    end
    if accentColor == UI.blue then
        return UI.sky, UI.skyHover, { 0.92, 0.98, 1 }
    end
    return UI.slate, UI.slateHover, { 0.92, 0.96, 1 }
end

local function ClearButtonTextures(button)
    if button.SetNormalTexture then
        button:SetNormalTexture("")
        button:SetPushedTexture("")
        button:SetDisabledTexture("")
        button:SetHighlightTexture("")
    end
    for _, region in ipairs({ button:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:Hide()
        end
    end
end

function M.SkinButton(button, variant)
    if not button then
        return button
    end
    ClearButtonTextures(button)
    local bgColor, hoverColor, textColor = M.GetButtonColors(nil, variant == "danger")
    M.ApplyBackdrop(button, bgColor, UI.buttonLine, UI.round.button)
    button.hl = button.hl or button:CreateTexture(nil, "HIGHLIGHT")
    button.hl:ClearAllPoints()
    button.hl:SetPoint("TOPLEFT", RADIUS, -RADIUS)
    button.hl:SetPoint("BOTTOMRIGHT", -RADIUS, RADIUS)
    M.SetTextureColor(button.hl, hoverColor)
    button.hl:SetAlpha(0.42)
    button.hl:Show()
    if button.text then
        button.text:SetTextColor(textColor[1], textColor[2], textColor[3])
    end
    return button
end

function M.CreateButton(parent, text, width, height, accentColor, danger)
    local button = CreateFrame("Button", nil, parent, M.BD_TEMPLATE)
    button:SetSize(width or 120, height or 30)
    local bgColor, hoverColor, textColor = M.GetButtonColors(accentColor or UI.blue, danger)
    M.ApplyBackdrop(button, bgColor, UI.buttonLine, UI.round.button)

    button.fill = button:CreateTexture(nil, "BACKGROUND")
    button.fill:SetPoint("TOPLEFT", RADIUS, -RADIUS)
    button.fill:SetPoint("BOTTOMRIGHT", -RADIUS, RADIUS)
    button.fill:SetColorTexture(1, 1, 1, 0.055)

    button.hover = button:CreateTexture(nil, "HIGHLIGHT")
    button.hover:SetPoint("TOPLEFT", RADIUS, -RADIUS)
    button.hover:SetPoint("BOTTOMRIGHT", -RADIUS, RADIUS)
    M.SetTextureColor(button.hover, hoverColor)
    button.hover:SetAlpha(0.44)

    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.label:SetPoint("LEFT", 10, 0)
    button.label:SetPoint("RIGHT", -10, 0)
    button.label:SetJustifyH("CENTER")
    button.label:SetText(text or "")
    button.label:SetTextColor(textColor[1], textColor[2], textColor[3])

    button.SetButtonText = function(self, value)
        self.label:SetText(value or "")
    end
    button:SetScript("OnMouseDown", function(self)
        self.fill:SetColorTexture(0, 0, 0, 0.16)
        self.label:SetPoint("LEFT", 10, -1)
        self.label:SetPoint("RIGHT", -10, -1)
    end)
    button:SetScript("OnMouseUp", function(self)
        self.fill:SetColorTexture(1, 1, 1, 0.055)
        self.label:SetPoint("LEFT", 10, 0)
        self.label:SetPoint("RIGHT", -10, 0)
    end)
    button:SetScript("OnLeave", function(self)
        self.fill:SetColorTexture(1, 1, 1, 0.055)
        self.label:SetPoint("LEFT", 10, 0)
        self.label:SetPoint("RIGHT", -10, 0)
    end)
    button:SetScript("OnDisable", function(self)
        M.ApplyBackdrop(self, { 0.08, 0.09, 0.10, 0.55 }, UI.buttonLine, UI.round.button)
        self.label:SetTextColor(0.44, 0.48, 0.52)
    end)
    button:SetScript("OnEnable", function(self)
        M.ApplyBackdrop(self, bgColor, UI.buttonLine, UI.round.button)
        self.label:SetTextColor(textColor[1], textColor[2], textColor[3])
    end)
    return button
end

M.CreateCustomButton = M.CreateButton

function M.SuccessBtn(parent, text, width, height)
    return M.CreateButton(parent, text, width, height, UI.green)
end

function M.InfoBtn(parent, text, width, height)
    return M.CreateButton(parent, text, width, height, UI.blue)
end

function M.WarningBtn(parent, text, width, height)
    return M.CreateButton(parent, text, width, height, UI.gold)
end

function M.DangerBtn(parent, text, width, height)
    return M.CreateButton(parent, text, width, height, UI.red, true)
end

function M.NeutralBtn(parent, text, width, height)
    return M.CreateButton(parent, text, width, height)
end

M.CreateSuccessButton = M.SuccessBtn
M.CreateInfoButton = M.InfoBtn
M.CreateWarningButton = M.WarningBtn
M.CreateDangerButton = M.DangerBtn
M.CreateNeutralButton = M.NeutralBtn
