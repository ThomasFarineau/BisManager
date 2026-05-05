-- CustomUI/ScrollFrame.lua
-- Minimal scrollbar treatment.

local BisManager = _G.BisManager
local M = BisManager and BisManager.UI
if not M then
    return
end

local UI = M.colors

function M.SkinScrollFrame(scrollFrame)
    if not scrollFrame then
        return scrollFrame
    end
    if scrollFrame.EnableMouseWheel then
        scrollFrame:EnableMouseWheel(true)
    end
    if scrollFrame.GetScript and scrollFrame.SetScript and not scrollFrame:GetScript("OnMouseWheel") then
        scrollFrame:SetScript("OnMouseWheel", function(self, delta)
            local current = self:GetVerticalScroll() or 0
            local range = self:GetVerticalScrollRange() or 0
            self:SetVerticalScroll(math.max(0, math.min(current - (delta * 40), range)))
        end)
    end

    local name = scrollFrame.GetName and scrollFrame:GetName()
    local scrollBar = scrollFrame.ScrollBar or (name and _G[name .. "ScrollBar"])
    if not scrollBar then
        return scrollFrame
    end

    for _, region in ipairs({ scrollBar:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:SetAlpha(0)
        end
    end

    local scrollName = scrollBar.GetName and scrollBar:GetName() or ""
    local upButton = scrollBar.ScrollUpButton or _G[scrollName .. "ScrollUpButton"]
    local downButton = scrollBar.ScrollDownButton or _G[scrollName .. "ScrollDownButton"]
    if upButton then upButton:Hide() end
    if downButton then downButton:Hide() end
    if scrollBar.SetWidth then
        scrollBar:SetWidth(7)
    end

    scrollBar.track = scrollBar.track or scrollBar:CreateTexture(nil, "BACKGROUND")
    scrollBar.track:SetPoint("TOP", 0, -2)
    scrollBar.track:SetPoint("BOTTOM", 0, 2)
    scrollBar.track:SetWidth(3)
    scrollBar.track:SetColorTexture(1, 1, 1, 0.07)

    local thumb = scrollBar.GetThumbTexture and scrollBar:GetThumbTexture()
    if thumb then
        thumb:SetColorTexture(UI.cyan[1], UI.cyan[2], UI.cyan[3], 0.55)
        thumb:SetWidth(4)
    end
    return scrollFrame
end
