-- CustomUI/Input.lua
-- EditBox styling.

local BisManager = _G.BisManager
local M = BisManager and BisManager.UI
if not M then
    return
end

local UI = M.colors
local RADIUS = UI.layout.radius

function M.SkinEditBox(editBox)
    if not editBox then
        return editBox
    end
    for _, region in ipairs({ editBox:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:SetAlpha(0)
        end
    end
    M.ApplyBackdrop(editBox, UI.input, UI.line, UI.round.input)
    if editBox.SetTextInsets then
        editBox:SetTextInsets(10, 10, 0, 0)
    end
    editBox.focusGlow = editBox.focusGlow or editBox:CreateTexture(nil, "HIGHLIGHT")
    editBox.focusGlow:SetPoint("TOPLEFT", RADIUS, -RADIUS)
    editBox.focusGlow:SetPoint("BOTTOMRIGHT", -RADIUS, RADIUS)
    editBox.focusGlow:SetColorTexture(UI.cyan[1], UI.cyan[2], UI.cyan[3], 0.10)
    return editBox
end
