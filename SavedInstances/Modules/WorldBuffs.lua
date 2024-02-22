---@alias SavedInstances.Toon.WorldBuffInfo {remainingDuration: number, isBooned: boolean}

---@type SavedInstances
local SI, L = unpack(select(2, ...))
---@class WorldBuffsModule : AceModule, AceEvent-3.0
local Module = SI:NewModule('WorldBuffs', "AceEvent-3.0")
local TooltipModule = SI:GetModule('Tooltip') --[[@as TooltipModule]]

local trackedBuffs = {
    -- Legacy
    16609,  -- Warchief's Blessing (unused after 04/2021 [tbc])
    22888,  -- Rallying Cry of the Dragonslayer (unused after 04/2021)
    24425,  -- Spirit of Zandalar (unused after 04/2021)
    -- Classic
    355366, -- Warchief's Blessing
    355363, -- Rallying Cry of the Dragonslayer
    355365, -- Spirit of Zandalar
    23768,  -- Sayge's Dark Fortune of Damage
    23769,  -- Sayge's Dark Fortune of Resistance
    23767,  -- Sayge's Dark Fortune of Armor
    23766,  -- Sayge's Dark Fortune of Intelligence
    23738,  -- Sayge's Dark Fortune of Spirit
    23737,  -- Sayge's Dark Fortune of Stamina
    23735,  -- Sayge's Dark Fortune of Strength
    23736,  -- Sayge's Dark Fortune of Agility
    22818,  -- "Mol'dar's Moxie",
    22817,  -- "Fengus' Ferocity",
    22820,  -- "Slip'kik's Savvy",
    15366,  -- Songflower Serenade
    -- SoD Exclusive
    431111, -- Boon of Blackfathom (unused after P1)
    438537, -- Spark of Inspiration (unused. maybe its for after P2)
    430947, -- Boon of Blackfathom 
    438536  -- Spark of Inspiration
}

local TRACKED_BUFFS_LOOKUP = {}
for _, spellId in ipairs(trackedBuffs) do
    TRACKED_BUFFS_LOOKUP[spellId] = true
end

-- see https://warcraft.wiki.gg/wiki/API_UnitAura#Details
local spellByBoonIdx = {
    [1] = 22817, -- Fengus' Ferocity
    [2] = 22818, -- Mol'dar's Moxie
    [3] = 22820, -- Slip'kik's Savvy
    [4] = 355363, -- Rallying Cry of the Dragonslayer
    [5] = 355366, -- Warchief's Blessing
    [6] = 355365, -- Spirit of Zandalar
    [7] = 15366, -- Songflower Serenade
    [8] = 0, -- Duration of Sayges Fortune Buff
    [9] = 0, -- SpellID of Sayges Fortune Buff
    [10] = 430947, -- Boon of Blackfathom (SoD)
    [11] = 438536 -- Spark of Inspiration (SoD)
}
local CHARGED_BOON_AURA = 349981
-- maps `{[spellID]: BuffInfo}`
---@type table<number, SavedInstances.Toon.WorldBuffInfo>
local playerBuffStore

--- on load, boon is always checked before other buffs so we cant assume is has up to date unbooned buff info.
---@return boolean isUpdate
local function updatePlayerSuspendedBuffs()
    assert(playerBuffStore, "ensure saved variables are loaded before calling this function")
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(CHARGED_BOON_AURA)
    local isUpdate = false
    if not auraData then
        SI:Debug("No aura data found for Charged Chrono Boon")
        -- assume nothing is booned. Sometimes the game does not return the aura data right away and this can be falsely empty.
        for _, spellID in pairs(trackedBuffs) do
            if playerBuffStore[spellID] then
                playerBuffStore[spellID].isBooned = false
                isUpdate = true
            end
        end
    else
        local boonAuraDurations = auraData and auraData.points or {}
        for i = 1, #boonAuraDurations do
            -- workaround for dmf spellId/duration entries
            local spellID = i ~= 8 
                and spellByBoonIdx[i]
                or boonAuraDurations[9];

            local timeLeft = boonAuraDurations[i]
                
            if spellID and spellID ~= 0 then
                if timeLeft <= 0 then
                    -- when no duration is found on the boon simply mark as unbooned
                    -- `updateCurrentPlayerBuffInfo` will cleanup the store entry-
                    -- when: the buff is not found on player and not seen as booned in the store.
                    if playerBuffStore[spellID] then
                        SI:Debug("No suspended data found for world buff: %s", GetSpellLink(spellID))
                        playerBuffStore[spellID].isBooned = false
                        isUpdate = true
                    end
                else
                    playerBuffStore[spellID] = { remainingDuration = timeLeft, isBooned = true }
                    SI:Debug("Suspended Buff Found: %s (%sm)", GetSpellLink(spellID), floor(SecondsToMinutes(timeLeft)))
                    isUpdate = true
                end
            end
        end
    end
    return isUpdate
end
---@param spellID number
---@return boolean isUpdate
local function updatePlayerBuffBySpell(spellID)
    assert(playerBuffStore, "ensure saved variables are loaded before calling this function")
        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        local timeLeft = auraData and (auraData.expirationTime - GetTime()) or 0
        if timeLeft <= 0 then
            -- clear store when buff is not found, iff its not booned
            if playerBuffStore[spellID] and not playerBuffStore[spellID].isBooned then
                playerBuffStore[spellID] = nil
                SI:Debug("No data found for world buff: %s", GetSpellLink(spellID))
            end
        else
        SI:Debug("Unsuspended Buff Found: %s (%sm)", GetSpellLink(spellID), floor(SecondsToMinutes(timeLeft)))
        playerBuffStore[spellID] = { 
            remainingDuration = timeLeft, 
            isBooned = false 
        }
    end
    return true
end
-- update all tracked buffs in and out of chronoboon
-- (reflected in the store)
local function UpdateAllCurrentPlayerBuffs()
    updatePlayerSuspendedBuffs()
    for _, spellID in ipairs(trackedBuffs) do
       updatePlayerBuffBySpell(spellID)
    end
end
function Module:OnEnable()
    assert(SavedInstancesDB) -- ensure saved variables are loaded
    local characterDB = SavedInstancesDB.Toons
    playerBuffStore = characterDB[SI.thisToon].WorldBuffs
    if not playerBuffStore then
        playerBuffStore = {}
        characterDB[SI.thisToon].WorldBuffs = playerBuffStore
    end
    self:RegisterEvent("UNIT_AURA")
    
    ---cache results used by `GetCharacterWorldBuffs` (name and icon)
    ---@type table<string, WorldBuffsModule.CachedBuffs>
    self.characterWorldBuffCache = {}
    
    UpdateAllCurrentPlayerBuffs()
end

-- when UNIT_AURA fires for an aura that has been removed
-- querying the aura data with `GetAuraDataByAuraInstanceID` return nil 
-- likely because the player no longer has the aura. Whic make sense-
-- but this means we cant get the spellID from the auraData, so we have to track it ourselves.
---@type table<number, number> `instanceID => spellID`
local trackedAuraInstanceIDs = {}

function Module:UNIT_AURA(event, unit, info)
    if unit == "player" then
        local addedAuraData = info.addedAuras or {}
        local updatedIDs = info.updatedAuraInstanceIDs or {}
        local removedIDs = info.removedAuraInstanceIDs or {}
        local isUpdate = false

        local updateAuraIfValid = function(auraData)
            local spellID = auraData and auraData.spellId
            local isValid = false
            if spellID == CHARGED_BOON_AURA then
                isUpdate = updatePlayerSuspendedBuffs()
                isValid = true
            elseif TRACKED_BUFFS_LOOKUP[spellID] then
                isUpdate = updatePlayerBuffBySpell(spellID)
                isValid = true
            end
            if isUpdate then
                -- invalidate `characterWorldBuffCache` for player
                self.characterWorldBuffCache[SI.thisToon] = nil
            end
            return isValid
        end
        for _, auraData in ipairs(addedAuraData) do
            if updateAuraIfValid(auraData) then
                ---@cast auraData AuraData
                trackedAuraInstanceIDs[auraData.auraInstanceID] = auraData.spellId
            end
        end
        
        for _, instanceID in ipairs(updatedIDs) do
            local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID("player", instanceID)
            if updateAuraIfValid(auraData) then
                ---@cast auraData {}
                trackedAuraInstanceIDs[instanceID] = auraData.spellId
            end
        end
        for _, instanceID in ipairs(removedIDs) do
            local spellID = trackedAuraInstanceIDs[instanceID]
            if spellID then
                updateAuraIfValid({ spellId = spellID })
                trackedAuraInstanceIDs[instanceID] = nil
            end
        end
        -- DevTools_Dump(info)
    end
end

-- todo move to time.lua
local timeFormatter = CreateFromMixins(SecondsFormatterMixin)
timeFormatter:Init(nil, nil, true)
timeFormatter:SetDesiredUnitCount(1)
timeFormatter:SetStripIntervalWhitespace(true)
---@diagnostic disable-next-line: duplicate-set-field
function timeFormatter:GetMaxInterval()
    return SecondsFormatter.Interval.Minutes
end
local secondsToMinutes = function(seconds)
     return timeFormatter
        :Format(seconds, SecondsFormatter.Abbreviation.OneLetter)
end

local lastTooltipUpdate = 0
local refreshWindow = 60 -- 1min
---@param characterKey string
function Module:ShowCharacterTooltip(characterKey)
    assert(SI.db, "private reference SavedInstancesDB is not found. Make sure this functions is called after Core.lua has been loaded.")
    local buffStore = SI.db.Toons[characterKey] and SI.db.Toons[characterKey].WorldBuffs
    if not buffStore then return end

    -- hack to update tooltip when hovering over the current player's cell to keep duration up to date
    if characterKey == SI.thisToon 
    and GetTime() - lastTooltipUpdate > refreshWindow 
    then
        UpdateAllCurrentPlayerBuffs()
        lastTooltipUpdate = GetTime()
    end

    ---@type QTip create the tooltip when hovering over a character cell
    local hovertip = TooltipModule:AcquireIndicatorTip(3, "LEFT","RIGHT","RIGHT") 
    local linesToAdd = {} ---@type string[]
    local count = 0
    local boonIndicator = "\124TInterface\\COMMON\\Indicator-Green:0:0:0:2\124t"
    for spellID, buff in pairs(buffStore) do
        local remaining = buff.remainingDuration
        assert(remaining > 0, "World buffs with no remaining duration should be removed from the characters saved variable store")
        local name, _, icon = GetSpellInfo(spellID)
        local displayStr = "\124T%s:14:14\124t %s %s";
        local remainingStr = (buff.isBooned 
            and PURE_GREEN_COLOR 
            or NORMAL_FONT_COLOR):WrapTextInColorCode(
                ("(%s)"):format(secondsToMinutes(remaining)));
        local line = displayStr
            :format(icon, name, remainingStr)

        tinsert(linesToAdd, line)
        count = count + 1
    end
    if #linesToAdd > 0 then
        local coloredName = SI:ClassColorString(characterKey)
        local headerLine = hovertip:AddHeader()
        hovertip:SetCell(headerLine, 1, coloredName, nil, "LEFT")
        hovertip:SetCell(headerLine, 2, (L["World Buffs"]..': '..count), nil, "RIGHT")
        hovertip:AddLine() -- spacer
        for _, lineText in ipairs(linesToAdd) do
            hovertip:SetCell(hovertip:AddLine(), 1, lineText, nil,"LEFT", 3)
        end
        -- add hint for booned indicator
        if SI.db.Tooltip.ShowHints then
            hovertip:AddSeparator(5,0,0,0,0)
            local atlasLine = hovertip:AddLine()
            hovertip:SetCell(atlasLine, 1, boonIndicator..GetSpellInfo(CHARGED_BOON_AURA),"GameTooltipTextSmall", "LEFT", hovertip:GetColumnCount())
        end
        hovertip:Show()
    end
end

---@alias WorldBuffsModule.CachedBuffs {spellID: number, name: string, icon: number|string, remaining: number, isBooned: boolean}[]

---@param characterKey string
---@return WorldBuffsModule.CachedBuffs?
function Module:GetCharacterWorldBuffs(characterKey)
    assert(SI.db, "private reference SavedInstancesDB is not found. Make sure this functions is called after Core.lua has been loaded.")
    if not characterKey or SI.db.Toons[characterKey] then return end
    -- update cache if not present
    if not self.characterWorldBuffCache[characterKey] then
        SI:Debug("(re)Building world buff cache for %s", characterKey)
        local buffStore = SI.db.Toons[characterKey].WorldBuffs or {}
        local buffArray = {}
        for spellID, buff in ipairs(buffStore) do
            tinsert(buffArray, {
                spellID = spellID,
                name = GetSpellInfo(spellID),
                icon = GetSpellTexture(spellID),
                remaining = buff.remainingDuration,
                isBooned = buff.isBooned
            }) 
        end
        self.characterWorldBuffCache[characterKey] = buffArray
    end
    return self.characterWorldBuffCache[characterKey]
end
