local BisManager = _G.BisManager
if not BisManager then
    return
end

local BIS_ICON = "Interface/AddOns/BisManager/Assets/GameIcon"

local function ParseItemIDFromLink(link)
    if type(link) ~= "string" then
        return nil
    end
    return tonumber(link:match("item:(%d+)"))
end

local function GetTooltipItemID(tooltip, tooltipData)
    if tooltipData then
        local itemID = tonumber(tooltipData.id)
        if itemID then
            return itemID
        end

        itemID = ParseItemIDFromLink(tooltipData.hyperlink)
        if itemID then
            return itemID
        end
    end

    if tooltip and tooltip.GetItem then
        local _, itemLink = tooltip:GetItem()
        return ParseItemIDFromLink(itemLink)
    end

    return nil
end

function BisManager:EnsureTooltipBiSWidget(tooltip)
    if not tooltip then
        return nil
    end
    if tooltip._bmBisWidget then
        return tooltip._bmBisWidget
    end

    local widget = CreateFrame("Frame", nil, tooltip, BackdropTemplateMixin and "BackdropTemplate" or nil)
    widget:SetFrameStrata("TOOLTIP")
    widget:SetFrameLevel((tooltip:GetFrameLevel() or 1) + 10)
    widget:SetClampedToScreen(true)

    if widget.SetBackdrop then
        widget:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        widget:SetBackdropColor(0.08, 0.08, 0.1, 0.96)
        widget:SetBackdropBorderColor(0.36, 0.78, 1, 1)
    end

    widget.icon = widget:CreateTexture(nil, "ARTWORK")
    widget.icon:SetSize(16, 16)
    widget.icon:SetPoint("LEFT", 8, 0)
    widget.icon:SetTexture(BIS_ICON)

    widget.text = widget:CreateFontString(nil, "ARTWORK", "GameTooltipText")
    widget.text:SetPoint("LEFT", widget.icon, "RIGHT", 6, 0)
    widget.text:SetPoint("BOTTOMRIGHT", -8, 6)
    widget.text:SetJustifyH("LEFT")
    widget.text:SetJustifyV("MIDDLE")
    widget.text:SetTextColor(0.36, 0.78, 1)

    widget:Hide()
    tooltip._bmBisWidget = widget
    return widget
end

function BisManager:ShowTooltipBiS(tooltip)
    if not tooltip or not tooltip:IsShown() then
        return
    end

    local widget = self:EnsureTooltipBiSWidget(tooltip)
    if not widget then
        return
    end

    widget.text:SetText(self.L["tooltip_bis_profile_fmt"]:format(self:GetActiveProfileName()))

    local okH, strH = pcall(widget.text.GetStringHeight, widget.text)
    local height = 24
    if okH and type(strH) == "number" then
        height = math.max(height, strH + 12)
    end

    widget:SetHeight(height)
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", tooltip, "BOTTOMLEFT", 0, -2)
    widget:SetPoint("TOPRIGHT", tooltip, "BOTTOMRIGHT", 0, -2)
    widget:Show()
end

function BisManager:HideTooltipBiS(tooltip)
    if tooltip and tooltip._bmBisWidget then
        tooltip._bmBisWidget:Hide()
    end
end

function BisManager:HandleTooltipBiS(tooltip, tooltipData)
    if not tooltip then
        return
    end

    local itemID = GetTooltipItemID(tooltip, tooltipData)
    if itemID and self:FindConfiguredItem(itemID) then
        self:ShowTooltipBiS(tooltip)
    else
        self:HideTooltipBiS(tooltip)
    end
end

function BisManager:InitializeTooltipBiS()
    if self.tooltipBiSInitialized then
        return
    end

    local tooltips = { GameTooltip, ItemRefTooltip, ItemRefShoppingTooltip1, ItemRefShoppingTooltip2, ShoppingTooltip1, ShoppingTooltip2, EmbeddedItemTooltip }
    for _, tooltip in ipairs(tooltips) do
        if tooltip then
            tooltip:HookScript("OnHide", function(frame)
                BisManager:HideTooltipBiS(frame)
            end)
        end
    end

    local hasTooltipDataProcessor = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
    if hasTooltipDataProcessor then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(frame, tooltipData)
            BisManager:HandleTooltipBiS(frame, tooltipData)
        end)
    elseif GameTooltip then
        GameTooltip:HookScript("OnTooltipSetItem", function(frame)
            BisManager:HandleTooltipBiS(frame)
        end)
    end

    self.tooltipBiSInitialized = true
end
