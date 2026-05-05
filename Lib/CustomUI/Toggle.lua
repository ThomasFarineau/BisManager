-- CustomUI/Toggle.lua
-- Switch-like check buttons.

local BisManager = _G.BisManager
local M = BisManager and BisManager.UI
if not M then
    return
end

local UI = M.colors

function M.SkinCheckButton(checkButton)
    if not checkButton then
        return checkButton
    end
    for _, region in ipairs({ checkButton:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:SetAlpha(0)
        end
    end
    checkButton:SetSize(44, 22)
    checkButton.track = checkButton.track or checkButton:CreateTexture(nil, "BACKGROUND")
    checkButton.track:SetPoint("TOPLEFT", 1, -3)
    checkButton.track:SetPoint("BOTTOMRIGHT", -1, 3)
    checkButton.knob = checkButton.knob or checkButton:CreateTexture(nil, "ARTWORK")
    checkButton.knob:SetSize(14, 14)
    checkButton.glow = checkButton.glow or checkButton:CreateTexture(nil, "HIGHLIGHT")
    checkButton.glow:SetPoint("TOPLEFT", 1, -3)
    checkButton.glow:SetPoint("BOTTOMRIGHT", -1, 3)
    checkButton.glow:SetColorTexture(UI.cyan[1], UI.cyan[2], UI.cyan[3], 0.12)

    local originalSetChecked = checkButton.SetChecked
    local function Refresh(self)
        if self:GetChecked() then
            self.track:SetColorTexture(UI.sky[1], UI.sky[2], UI.sky[3], 0.95)
            self.knob:SetColorTexture(0.88, 0.96, 1, 1)
            self.knob:ClearAllPoints()
            self.knob:SetPoint("RIGHT", self, "RIGHT", -6, 0)
        else
            self.track:SetColorTexture(UI.slate[1], UI.slate[2], UI.slate[3], 0.95)
            self.knob:SetColorTexture(0.58, 0.66, 0.74, 1)
            self.knob:ClearAllPoints()
            self.knob:SetPoint("LEFT", self, "LEFT", 6, 0)
        end
    end
    checkButton.RefreshVisual = Refresh
    checkButton.SetChecked = function(self, checked)
        originalSetChecked(self, checked)
        Refresh(self)
    end
    checkButton:HookScript("OnClick", Refresh)
    Refresh(checkButton)
    return checkButton
end
