-- Mapping/EnchantableSlots.lua
-- Inventory slot IDs that are expected to carry a permanent enchantment.
-- Keep this list in one place so every module (enchant badges, group reports, ...)
-- shares the same definition.

local BisManager = _G.BisManager
if not BisManager then
    return
end

BisManager.ENCHANTABLE_SLOT_IDS = {
    [INVSLOT_HEAD] = true,
    [INVSLOT_NECK] = false,
    [INVSLOT_SHOULDER] = true,
    [INVSLOT_BODY] = false,
    [INVSLOT_CHEST] = true,
    [INVSLOT_WAIST] = false,
    [INVSLOT_LEGS] = true,
    [INVSLOT_FEET] = true,
    [INVSLOT_WRIST] = false,
    [INVSLOT_HAND] = false,
    [INVSLOT_FINGER1] = true,
    [INVSLOT_FINGER2] = true,
    [INVSLOT_TRINKET1] = false,
    [INVSLOT_TRINKET2] = false,
    [INVSLOT_BACK] = false,
    [INVSLOT_MAINHAND] = true,
    [INVSLOT_OFFHAND] = false,
    [INVSLOT_RANGED] = false,
    [INVSLOT_TABARD] = false,
}

function BisManager:IsEnchantableSlot(slotID)
    return slotID ~= nil and BisManager.ENCHANTABLE_SLOT_IDS[slotID] == true
end
