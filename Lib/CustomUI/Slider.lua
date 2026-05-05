-- CustomUI/Slider.lua
-- Compact horizontal sliders.

local BisManager = _G.BisManager
local M = BisManager and BisManager.UI
if not M then
    return
end

local UI = M.colors

function M.CreateSlider(parent, label, minVal, maxVal, step, defaultVal)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(420, 48)

    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetText(label)

    local valueText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("LEFT", text, "RIGHT", 6, 0)

    local slider = CreateFrame("Slider", nil, container, M.BD_TEMPLATE)
    slider:SetSize(280, 17)
    slider:SetPoint("TOPLEFT", 0, -20)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(defaultVal or minVal)
    M.ApplyBackdrop(slider, UI.input, UI.line, UI.round.pill)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetVertexColor(UI.cyan[1], UI.cyan[2], UI.cyan[3], 1)
    end

    local minText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    minText:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 2, -1)
    minText:SetText(tostring(minVal))
    local maxText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    maxText:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", -2, -1)
    maxText:SetText(tostring(maxVal))

    container.slider = slider
    container.valueText = valueText
    return container
end

M.CreateSimpleSlider = M.CreateSlider
