-- CustomUI/Core.lua
-- Shared visual foundation for BisManager UI elements.

local BisManager = _G.BisManager
if not BisManager then
    return
end

local M = BisManager.UI or {}
BisManager.UI = M

M.BD_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
M.EDITBOX_TEMPLATE = M.BD_TEMPLATE and "InputBoxTemplate,BackdropTemplate" or "InputBoxTemplate"

M.colors = {
    bg = { 0.060, 0.068, 0.082, 0.985 },
    header = { 0.078, 0.088, 0.108, 0.98 },
    island = { 0.092, 0.106, 0.130, 0.96 },
    islandHover = { 0.120, 0.140, 0.174, 0.98 },
    panel = { 0.104, 0.120, 0.148, 0.93 },
    panelAlt = { 0.122, 0.142, 0.176, 0.95 },
    input = { 0.052, 0.062, 0.080, 0.98 },
    line = { 0.150, 0.215, 0.280, 0.92 },
    lineStrong = { 0.230, 0.365, 0.470, 1 },
    lineSoft = { 0.115, 0.160, 0.205, 0.85 },
    buttonLine = { 0.175, 0.190, 0.215, 0.82 },
    layout = {
        padding = 8,
        gap = 8,
        radius = 4,
        border = 1,
    },
    blue = { 0.26, 0.66, 0.96 },
    cyan = { 0.25, 0.82, 0.92 },
    gold = { 1, 0.72, 0.22 },
    green = { 0.28, 0.82, 0.50 },
    red = { 0.94, 0.22, 0.34 },
    slate = { 0.105, 0.120, 0.145, 0.90 },
    slateHover = { 0.145, 0.168, 0.205, 0.95 },
    sky = { 0.055, 0.270, 0.440, 0.96 },
    skyHover = { 0.065, 0.350, 0.555, 0.98 },
    success = { 0.085, 0.500, 0.330, 0.96 },
    successHover = { 0.105, 0.620, 0.420, 0.98 },
    emerald = { 0.045, 0.350, 0.245, 0.96 },
    emeraldHover = { 0.055, 0.445, 0.315, 0.98 },
    amber = { 0.580, 0.355, 0.065, 0.96 },
    amberHover = { 0.700, 0.455, 0.085, 0.98 },
    danger = { 0.500, 0.075, 0.135, 0.96 },
    dangerHover = { 0.690, 0.105, 0.180, 0.98 },
    round = {
        frame = { bgInset = 1, borderSize = 1 },
        card = { bgInset = 1, borderSize = 1 },
        button = { bgInset = 1, borderSize = 1 },
        pill = { bgInset = 1, borderSize = 1 },
        input = { bgInset = 1, borderSize = 1 },
        row = { bgInset = 1, borderSize = 1 },
    },
}

local UI = M.colors
UI.twSky = UI.sky
UI.twSkyHover = UI.skyHover
UI.twEmerald = UI.emerald
UI.twEmeraldHover = UI.emeraldHover
UI.twAmber = UI.amber
UI.twAmberHover = UI.amberHover
UI.twRed = UI.danger
UI.twRedHover = UI.dangerHover
UI.twSlate = UI.slate
UI.twSlateHover = UI.slateHover

function M.ApplyBackdrop(frame, bg, border, style)
    if not frame or not frame.SetBackdrop then
        return
    end
    style = style or UI.round.card
    local borderSize = style.borderSize or 0
    local inset = style.bgInset or 1
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = math.max(borderSize, 1),
        insets = { left = inset, right = inset, top = inset, bottom = inset },
    })
    frame:SetBackdropColor(unpack(bg or UI.panel))
    if borderSize > 0 and border then
        frame:SetBackdropBorderColor(unpack(border))
    else
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    end
    if frame.borderTop then
        frame.borderTop:Hide()
    end
end

function M.SetTextureColor(texture, color)
    if texture and color then
        texture:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    end
end

function M.AddTopSheen(frame, color, alpha)
    if not frame then
        return
    end
    frame.topSheen = frame.topSheen or frame:CreateTexture(nil, "BORDER")
    frame.topSheen:SetColorTexture(0, 0, 0, 0)
    frame.topSheen:Hide()
end

function M.AddSoftShadow(frame)
    if frame and frame.shadow then
        frame.shadow:Hide()
    end
end
