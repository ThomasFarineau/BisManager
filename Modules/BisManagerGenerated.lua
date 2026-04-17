-- BisManagerGenerated.lua
-- Provides API to load generated BiS presets into profiles
-- DB structure: BisManagerBiSDB[CLASS][SPEC][presetLabel] = { HEAD = {...}, ... }

local BisManager = _G.BisManager
if not BisManager then return end

------------------------------------------------------------------------
-- SpecID → spec key mapping (locale-independent)
------------------------------------------------------------------------

local SPEC_ID_MAP = {
    -- Death Knight
    [250] = { class = "DEATHKNIGHT", spec = "BLOOD" },
    [251] = { class = "DEATHKNIGHT", spec = "FROST" },
    [252] = { class = "DEATHKNIGHT", spec = "UNHOLY" },
    -- Demon Hunter
    [577] = { class = "DEMONHUNTER", spec = "HAVOC" },
    [581] = { class = "DEMONHUNTER", spec = "VENGEANCE" },
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

------------------------------------------------------------------------
-- Detect current player class/spec
------------------------------------------------------------------------

function BisManager:GetPlayerClassSpecKey()
    local specIndex = GetSpecialization()
    if not specIndex then return nil, nil end

    local specID = GetSpecializationInfo(specIndex)
    if not specID then return nil, nil end

    local entry = SPEC_ID_MAP[specID]
    if entry then
        return entry.class, entry.spec
    end

    -- Fallback: use classFile token (always English) + localized spec name
    local _, classFile = UnitClass("player")
    local classKey = classFile and classFile:upper():gsub(" ", "") or nil
    return classKey, nil
end

------------------------------------------------------------------------
-- Get the player's preset table: BisManagerBiSDB[class][spec]
------------------------------------------------------------------------

function BisManager:GetPlayerPresets()
    if type(BisManagerBiSDB) ~= "table" then return nil end
    local classKey, specKey = self:GetPlayerClassSpecKey()
    if not classKey or not specKey then return nil end
    local classData = BisManagerBiSDB[classKey]
    if type(classData) ~= "table" then return nil end
    return classData[specKey]
end

------------------------------------------------------------------------
-- API: list / get / load presets
------------------------------------------------------------------------

function BisManager:GetGeneratedBiSKeys()
    local keys = {}
    local presets = self:GetPlayerPresets()
    if not presets then return keys end
    for k in pairs(presets) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return keys
end

function BisManager:GetGeneratedBiS(presetKey)
    local presets = self:GetPlayerPresets()
    if not presets then return nil end
    return presets[presetKey]
end

function BisManager:GetGeneratedBiSSourceUrl(presetKey)
    local data = self:GetGeneratedBiS(presetKey)
    if data then return data._sourceUrl end
    return nil
end

function BisManager:LoadGeneratedBiS(presetKey, profileName)
    local data = self:GetGeneratedBiS(presetKey)
    if not data then return 0 end

    profileName = profileName or presetKey
    local profile = self:GetOrCreateProfile(profileName)
    if not profile then return 0 end

    profile.slots = {}
    profile.autoGenerated = true
    profile.sourceUrl = data._sourceUrl
    local count = 0
    for slotKey, itemIDs in pairs(data) do
        if slotKey ~= "_sourceUrl" and type(itemIDs) == "table" and #itemIDs > 0 then
            profile.slots[slotKey] = {}
            for _, id in ipairs(itemIDs) do
                profile.slots[slotKey][#profile.slots[slotKey] + 1] = { itemID = tonumber(id) }
                count = count + 1
            end
        end
    end

    if count > 0 then
        self:SetActiveProfile(profileName)
        self:RefreshAll()
    end
    return count
end

------------------------------------------------------------------------
-- Auto-create profiles from BiS presets on login
------------------------------------------------------------------------

function BisManager:AutoCreateBiSProfiles()
    local presets = self:GetPlayerPresets()
    if not presets then return end

    for presetKey, data in pairs(presets) do
        local profile = self:GetOrCreateProfile(presetKey)
        if profile then
            profile.slots = {}
            profile.autoGenerated = true
            profile.sourceUrl = data._sourceUrl
            for slotKey, itemIDs in pairs(data) do
                if slotKey ~= "_sourceUrl" and type(itemIDs) == "table" and #itemIDs > 0 then
                    profile.slots[slotKey] = {}
                    for _, id in ipairs(itemIDs) do
                        profile.slots[slotKey][#profile.slots[slotKey] + 1] = { itemID = tonumber(id) }
                    end
                end
            end
        end
    end
end

------------------------------------------------------------------------
-- Slash command: /bis preset [key]
------------------------------------------------------------------------

local origHandleSlash = BisManager.HandleSlashCommand
function BisManager:HandleSlashCommand(msg)
    local cmd, rest = (msg or ""):match("^(%S+)%s*(.-)$")
    cmd = string.lower(cmd or "")

    if cmd == "preset" or cmd == "wowhead" or cmd == "wh" then
        rest = (rest or ""):match("^%s*(.-)%s*$")
        if rest == "" or rest == "list" then
            local keys = self:GetGeneratedBiSKeys()
            if #keys == 0 then
                DEFAULT_CHAT_FRAME:AddMessage("|cff5cc8ffBisManager|r: No BiS presets found for your class/spec.")
                return
            end
            DEFAULT_CHAT_FRAME:AddMessage("|cff5cc8ffBisManager|r: BiS presets:")
            for _, k in ipairs(keys) do
                DEFAULT_CHAT_FRAME:AddMessage("  |cff4cff4c" .. k .. "|r")
            end
            return
        end

        local count = self:LoadGeneratedBiS(rest, rest)
        if count > 0 then
            DEFAULT_CHAT_FRAME:AddMessage(("|cff5cc8ffBisManager|r: Loaded %d items from |cffffffff%s|r."):format(count, rest))
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cff5cc8ffBisManager|r: Preset not found: " .. rest)
        end
        return
    end

    origHandleSlash(self, msg)
end
