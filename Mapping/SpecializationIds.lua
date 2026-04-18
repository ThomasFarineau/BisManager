-- Mapping/SpecializationIds.lua
-- SpecID → class/spec key mapping (locale-independent)

local BisManager = _G.BisManager
if not BisManager then return end

BisManager.SPEC_ID_MAP = {
    -- Death Knight
    [250] = { class = "DEATHKNIGHT", spec = "BLOOD" },
    [251] = { class = "DEATHKNIGHT", spec = "FROST" },
    [252] = { class = "DEATHKNIGHT", spec = "UNHOLY" },
    -- Demon Hunter
    [577] = { class = "DEMONHUNTER", spec = "HAVOC" },
    [581] = { class = "DEMONHUNTER", spec = "VENGEANCE" },
    [1480] = { class = "DEMONHUNTER", spec = "DEVOURER" },
    -- Druid
    [102] = { class = "DRUID", spec = "BALANCE" },
    [103] = { class = "DRUID", spec = "FERAL" },
    [104] = { class = "DRUID", spec = "GUARDIAN" },
    [105] = { class = "DRUID", spec = "RESTORATION" },
    -- Evoker
    [1467] = { class = "EVOKER", spec = "DEVASTATION" },
    [1468] = { class = "EVOKER", spec = "PRESERVATION" },
    [1473] = { class = "EVOKER", spec = "AUGMENTATION" },
    -- Hunter
    [253] = { class = "HUNTER", spec = "BEASTMASTERY" },
    [254] = { class = "HUNTER", spec = "MARKSMANSHIP" },
    [255] = { class = "HUNTER", spec = "SURVIVAL" },
    -- Mage
    [62]  = { class = "MAGE", spec = "ARCANE" },
    [63]  = { class = "MAGE", spec = "FIRE" },
    [64]  = { class = "MAGE", spec = "FROST" },
    -- Monk
    [268] = { class = "MONK", spec = "BREWMASTER" },
    [270] = { class = "MONK", spec = "MISTWEAVER" },
    [269] = { class = "MONK", spec = "WINDWALKER" },
    -- Paladin
    [65]  = { class = "PALADIN", spec = "HOLY" },
    [66]  = { class = "PALADIN", spec = "PROTECTION" },
    [70]  = { class = "PALADIN", spec = "RETRIBUTION" },
    -- Priest
    [256] = { class = "PRIEST", spec = "DISCIPLINE" },
    [257] = { class = "PRIEST", spec = "HOLY" },
    [258] = { class = "PRIEST", spec = "SHADOW" },
    -- Rogue
    [259] = { class = "ROGUE", spec = "ASSASSINATION" },
    [260] = { class = "ROGUE", spec = "OUTLAW" },
    [261] = { class = "ROGUE", spec = "SUBTLETY" },
    -- Shaman
    [262] = { class = "SHAMAN", spec = "ELEMENTAL" },
    [263] = { class = "SHAMAN", spec = "ENHANCEMENT" },
    [264] = { class = "SHAMAN", spec = "RESTORATION" },
    -- Warlock
    [265] = { class = "WARLOCK", spec = "AFFLICTION" },
    [266] = { class = "WARLOCK", spec = "DEMONOLOGY" },
    [267] = { class = "WARLOCK", spec = "DESTRUCTION" },
    -- Warrior
    [71]  = { class = "WARRIOR", spec = "ARMS" },
    [72]  = { class = "WARRIOR", spec = "FURY" },
    [73]  = { class = "WARRIOR", spec = "PROTECTION" },
}

