---@alias SavedInstances.Toon.WorldBuffs.Info {remainingDuration: number, isBooned: boolean, spellID: number}
---@alias SavedInstances.Toon.WorldBuffs {string: SavedInstances.Toon.WorldBuffs.Info, boonCooldownExpiry: number?}

---@type SavedInstances
local SI, L = unpack(select(2, ...))
---@class WorldBuffsModule : AceModule, AceEvent-3.0
local Module = SI:NewModule('WorldBuffs', "AceEvent-3.0")
local TooltipModule = SI:GetModule('Tooltip') --[[@as TooltipModule]]

if not SI.isClassicEra then return end

-- Global API
local GetContainerItemCooldown = C_Container.GetContainerItemCooldown
local RED = RED_FONT_COLOR ---@type ColorMixin
local GREEN = PURE_GREEN_COLOR ---@type ColorMixin
local YELLOW = NORMAL_FONT_COLOR ---@type ColorMixin
local READY = READY ---@type "Ready"

-- No API to get world buffs or distinguish between world buffs and other buffs
-- There are 2 spells for each buff, one is for the original buff gained from the npc on drop, and the other is for the buff gained from self when unbooning buffs.
-- This was added on 04/2021 i think SoM
local trackedBuffs = {
    -- Classic
    16609,  -- Warchief's Blessing (on drop)
    355366, -- Warchief's Blessing
    22888,  -- Rallying Cry of the Dragonslayer (on drop)
    355363, -- Rallying Cry of the Dragonslayer
    24425,  -- Spirit of Zandalar (on drop)
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
    431111, -- Boon of Blackfathom (from boon)
    430947, -- Boon of Blackfathom  (from drop)
    438537, -- Spark of Inspiration (from boon)
    438536, -- Spark of Inspiration (from drop)
    446698, -- Fervor of the Temple Explorer (from boon)
    446695, -- Fervor of the Temple Explorer (from drop)
    460939, -- Might of Stormwind (from drop)
    460940  -- Might of Stormwind (from boon)
}

---Maps localized buff names to spellIDs, and spellID to `true` for any associated spellIDs.
---@type {string: number[], number: boolean}
local WORLD_BUFF_LOOKUP = {}
for _, spellId in ipairs(trackedBuffs) do
    -- Name -> spellIDs
    local localizedName = GetSpellInfo(spellId)
    assert(localizedName, "GetSpellInfo returned `nil` for spellID", spellId)
    local existing = WORLD_BUFF_LOOKUP[localizedName]
    if not existing then 
        WORLD_BUFF_LOOKUP[localizedName] = { spellId }
    else
        ---@cast existing number[]
        tinsert(existing, spellId)
    end
    -- spellID -> isTracked
    WORLD_BUFF_LOOKUP[spellId] = true
end

-- see https://warcraft.wiki.gg/wiki/API_UnitAura#Details
-- note: any of the associated spellIDs can be used here, it's just used to pull localized data to display.
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
    [11] = 438537, -- Spark of Inspiration (SoD)
    [12] = 446695, -- Fervor of the Temple Explorer (SoD)
    [13] = 460939, -- Might of Stormwind (SoD)
}
local CHARGED_BOON_AURA = 349981
local UNCHARGED_BOON_ITEM_ID = SI.isSoD and 212160 or 184937 -- sod and era have different item ids

--- local reference to world buff saved var table for current player. This is assumed to be loaded on `OnEnable` and shouldn't `nil` when referenced in any execution after module initialization.
---@type SavedInstances.Toon.WorldBuffs
local playerBuffStore -- maps `{[spellName]: BuffInfo, [boonCD]: duration }`

---------------------------------------------------
-- Helper Functions
---------------------------------------------------

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

local function UpdatePlayerBoonCooldown()
    -- search bag for items
    local currentTime = GetTime()
    local currentTimestamp = GetServerTime()
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == UNCHARGED_BOON_ITEM_ID then
                -- when the bag item has no cooldown game will return 0, 0
                local lastCast, duration, _ = GetContainerItemCooldown(bag, slot)
                -- DevTools_Dump({GetContainerItemCooldown(bag, slot)})
                local timeSinceLastCast = currentTime - lastCast
                if lastCast > 0 then
                    local castTimestamp = currentTimestamp - timeSinceLastCast;
                    local expiry = castTimestamp + duration
                    SI:Debug("Remaining boon cooldown for %s - %s", SI.thisToon, secondsToMinutes(expiry - currentTimestamp))
                    if expiry > 0 then
                        playerBuffStore.boonCooldownExpiry = expiry -- update
                    else
                    -- if no cd and previous cd has expired, clear it
                    -- game might return 0, 0 falsely, verify if expired.
                        if playerBuffStore.boonCooldownExpiry and 
                        playerBuffStore.boonCooldownExpiry > currentTimestamp 
                        then
                            SI:Debug("Boon is still on cooldown until %s", date("%m/%d/%y %H:%M:%S", playerBuffStore.boonCooldownExpiry))
                            break; -- skip update
                        end
                        SI:Debug("Boon is off cooldown")
                        playerBuffStore.boonCooldownExpiry = 0 -- update
                    end
                end
                return;
            end
        end
    end
end

--- on `Enable`, the boon is checked before single wbuffs, so we cant assume is has up to date unbooned buff info.
---@return boolean isUpdate
local function UpdatePlayerChronoboonData()
    assert(playerBuffStore, "ensure saved variables are loaded before calling this function")
    UpdatePlayerBoonCooldown() -- update boon item cooldown
    local auraData = C_UnitAuras.GetPlayerAuraBySpellID(CHARGED_BOON_AURA)
    local isUpdate = false
    if not auraData then
        SI:Debug("No suspended world buffs for player.")
        -- assume nothing is booned. Sometimes the game does not return the aura data right away and this can be falsely empty.
        for buffName, _ in pairs(WORLD_BUFF_LOOKUP) do
            if type(buffName) == "string" 
                and playerBuffStore[buffName] 
            then
                playerBuffStore[buffName].isBooned = false
                isUpdate = true
            end
        end
    else
        local boonAuraDurations = auraData and auraData.points
        local dmfSpellIdx = 9
        for i = 1, #boonAuraDurations do
            local spellID = spellByBoonIdx[i] -- `0` for dmf entry @ index 8
            local spellName = GetSpellInfo(spellID)
            local timeLeft = boonAuraDurations[i]
            
            if i == dmfSpellIdx then -- dmf edge case
                spellID = boonAuraDurations[dmfSpellIdx]
                if spellID ~= 0 then -- if a dmf buff is found, its ID is non-zero
                    spellName = GetSpellInfo(spellID)
                    -- buff duration is stored in the previous index to the spellID
                    timeLeft = boonAuraDurations[dmfSpellIdx - 1]
                end
            end            
            if spellName then
                assert(spellID and spellID ~= 0, "GetSpellInfo returned `nil` for spellID", spellID, i, boonAuraDurations);
                if timeLeft <= 0 then
                    -- when no duration is found on the boon simply mark as unbooned
                    -- `updateCurrentPlayerBuffInfo` will cleanup the store entry-
                    -- when: the buff is not found on player and not seen as booned in the store.
                    if playerBuffStore[spellName] then
                        SI:Debug("No suspended data found for world buff: %s", GetSpellLink(spellID))
                        playerBuffStore[spellName].isBooned = false
                        isUpdate = true
                    end
                else
                    playerBuffStore[spellName] = { remainingDuration = timeLeft, isBooned = true, spellID = spellID }
                    SI:Debug("Suspended Buff Found: %s (%sm)", GetSpellLink(spellID), floor(SecondsToMinutes(timeLeft)))
                    isUpdate = true
                end
            end
        end
    end
    return isUpdate
end

---@param spellName string # localized spell name
---@return boolean isUpdate
local function UpdatePlayerBuffBySpell(spellName)
    assert(playerBuffStore, "ensure saved variables are loaded before calling this function")
    assert(type(spellName) == "string", "spellName must be a string")

    local spellIDs = WORLD_BUFF_LOOKUP[spellName] or {} 
    ---@cast spellIDs number[]
    local isUpdate = false
    for _, spellID in ipairs(spellIDs) do
        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        local timeLeft = auraData and (auraData.expirationTime - GetTime()) or 0
        if timeLeft <= 0 then
            -- clear store when buff is not found, iff its not booned
            if playerBuffStore[spellName] and not playerBuffStore[spellName].isBooned then
                playerBuffStore[spellName] = nil
                SI:Debug("No data found for world buff: %s", GetSpellLink(spellName))
                isUpdate = true
            end
        else
            SI:Debug("Unsuspended Buff Found: %s (%sm)", GetSpellLink(spellName), floor(SecondsToMinutes(timeLeft)))
            playerBuffStore[spellName] = { remainingDuration = timeLeft, isBooned = false }
            isUpdate = true
        end
        -- return on first match for spell (some spells have multiple spellIDs)
        if isUpdate then return true end
    end
    return false
end

-- update all tracked buffs in and out of chronoboon
-- as well as the boon cooldown.
-- and reflected all info in the playerBuffStore
local function UpdatePlayerWorldBuffs()
    -- checking the boon checks the boon cd as well
    UpdatePlayerChronoboonData()
    for spellName, _ in pairs(WORLD_BUFF_LOOKUP) do
        if type(spellName) == "string" then
            UpdatePlayerBuffBySpell(spellName)
        end
    end
end

---------------------------------------------------
-- Module Functions
---------------------------------------------------

function Module:OnEnable()
    assert(SavedInstancesDB) -- ensure saved variables are loaded
    local characterDB = SavedInstancesDB.Toons
    playerBuffStore = characterDB[SI.thisToon].WorldBuffs
    if not playerBuffStore then
        playerBuffStore = {}
        characterDB[SI.thisToon].WorldBuffs = playerBuffStore
    end
    -- validate saved buffs from different locales
    for localizedName, buff in pairs(playerBuffStore) do
        local saved = playerBuffStore[localizedName] 
        -- note: were also tracking boon cooldown (number) in playerBuffStore as `boonCooldownExpiry`
        if type(buff) == "table" then
            if buff.spellID then
                playerBuffStore[localizedName] = nil
                localizedName = GetSpellInfo(buff.spellID)
                playerBuffStore[localizedName] = saved
            else
                local name = GetSpellInfo(localizedName)
                if not (name) then
                    SI:Debug("Removing buff %s from %s as it is not localized", localizedName, SI.thisToon)
                    playerBuffStore[localizedName] = nil
                end
            end
        end
        -- hack: previously used spellID as key. Cleanup any old entries, remove this in a future release (0.1.2)
        if type(localizedName) == "number" then playerBuffStore[localizedName] = nil end
    end
    self:RegisterEvent("UNIT_AURA")
    ---cache results used by `GetCharacterWorldBuffs` (name and icon)
    ---@type table<string, WorldBuffsModule.CachedBuffs>
    self.characterWorldBuffCache = {}
    UpdatePlayerWorldBuffs()
end

-- when UNIT_AURA fires for an aura that has been removed
-- querying the aura data with `GetAuraDataByAuraInstanceID` return nil 
-- likely because the player no longer has the aura. Which make sense-
-- but this means we cant get the spellID from the auraData, so we have to track it ourselves.
---@type table<number, number> `instanceID => spellID`
local trackedAuraInstanceIDs = {}

---Processes aura data, updates player buff store if valid aura is found. Returns true if the aura data was valid.
---@param auraData table|{spellId: number}?
---@return boolean isValid
local ValidateAuraData = function(auraData)
    local spellID = auraData and auraData.spellId
    local isValid = false
    local isUpdate = false
    if spellID == CHARGED_BOON_AURA then
        isUpdate = UpdatePlayerChronoboonData()
        isValid = true
    elseif spellID and WORLD_BUFF_LOOKUP[spellID] then
        isUpdate = UpdatePlayerBuffBySpell(GetSpellInfo(spellID))
        isValid = true
    end
    if isUpdate then
        -- invalidate `characterWorldBuffCache` for player
        Module.characterWorldBuffCache[SI.thisToon] = nil
    end
    return isValid
end

function Module:UNIT_AURA(event, unit, info)
    if unit == "player" then
        local addedAuraData = info.addedAuras or {}
        local updatedIDs = info.updatedAuraInstanceIDs or {}
        local removedIDs = info.removedAuraInstanceIDs or {}
        local isUpdate = false

        for _, auraData in ipairs(addedAuraData) do
            if ValidateAuraData(auraData) then
                ---@cast auraData AuraData
                trackedAuraInstanceIDs[auraData.auraInstanceID] = auraData.spellId
            end
        end
        
        for _, instanceID in ipairs(updatedIDs) do
            local auraData = C_UnitAuras.GetAuraDataByAuraInstanceID("player", instanceID)
            if ValidateAuraData(auraData) then
                ---@cast auraData AuraData
                trackedAuraInstanceIDs[instanceID] = auraData.spellId
            end
        end
        for _, instanceID in ipairs(removedIDs) do
            local spellID = trackedAuraInstanceIDs[instanceID]
            if spellID then
                ValidateAuraData({ spellId = spellID })
                trackedAuraInstanceIDs[instanceID] = nil
            end
        end
        -- DevTools_Dump(info)
    end
end

local lastTooltipUpdate = 0
local refreshWindow = 30 -- 30sec
---@param characterKey string
function Module:ShowCharacterTooltip(characterKey)
    assert(SI.db, "`SI.db` ref to `SavedInstancesDB` is not found. Make sure `ShowCharacterTooltip` is only called after Core.lua.")
    local buffStore = SI.db.Toons[characterKey] and SI.db.Toons[characterKey].WorldBuffs
    if not buffStore then return end

    -- hack to update tooltip when hovering over the current player's cell to keep duration up to date
    if characterKey == SI.thisToon then
        UpdatePlayerBoonCooldown()
        if GetTime() - lastTooltipUpdate > refreshWindow then
            UpdatePlayerWorldBuffs()
            lastTooltipUpdate = GetTime()
        end
    end

    ---@type QTip create the tooltip when hovering over a character cell
    local hovertip = TooltipModule:AcquireIndicatorTip(3, "LEFT","RIGHT","RIGHT") 
    local linesToAdd = {} ---@type string[]
    local count = 0
    local boonIndicator = "\124TInterface\\COMMON\\Indicator-Green:0:0:0:2\124t"
    -- local _ = "\124TInterface\\COMMON\\Indicator-Red:0:0:0:2\124t"
    -- local _ = "\124TInterface\\COMMON\\Indicator-Yellow:0:0:0:2\124t"

    for localizedSpellName, buff in pairs(buffStore) do
        if type(buff) == "table" then
            local remaining = buff.remainingDuration
            assert(remaining > 0, "World buffs with no remaining duration should be removed from the characters saved variable store")
            
            -- using spellName for GetSpellInfo returns nil sometimes.
            local name, _, icon = GetSpellInfo(localizedSpellName) 
            if not (name and icon) then
                -- if a user saved a buff under a certain locale, opening the game with a different locale-
                -- will causes a lua error when trying to view world buff data from the tooltip.
                
                name, _, icon = GetSpellInfo(WORLD_BUFF_LOOKUP[localizedSpellName][1]) 
            end
            assert(name or type(localizedSpellName) == "number", "GetSpellInfo returned `nil` for spellName", localizedSpellName, WORLD_BUFF_LOOKUP)
            
            local displayStr = "\124T%s:14:14\124t %s: %s%s";
            local remainingStr = (buff.isBooned 
                and GREEN
                or YELLOW):WrapTextInColorCode(
                    ("(%s)"):format(secondsToMinutes(remaining)));
            local boonIndicator = buff.isBooned and boonIndicator or ""
            local line = displayStr
                :format(icon, name, remainingStr, boonIndicator)

            tinsert(linesToAdd, line)
            count = count + 1
        end
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

        local timeLeft = buffStore.boonCooldownExpiry 
        and buffStore.boonCooldownExpiry - GetServerTime();
        local boonCdStr = C_Item.GetItemInfo(UNCHARGED_BOON_ITEM_ID) 
            or L["Chronoboon Cooldown"]; -- non localized fallback
        local cooldownText
        if timeLeft and timeLeft > 0 then
            cooldownText = WrapTextInColorCode(
                secondsToMinutes(timeLeft), YELLOW:GenerateHexColor()
            );
        elseif timeLeft then 
            cooldownText = WrapTextInColorCode(
                READY, GREEN:GenerateHexColor()
            );
        end

        if cooldownText then
            local displayText = ("%s: %s")
                :format(boonCdStr, cooldownText);
            hovertip:AddSeparator(2,0,0,0,0)
            local cooldownLine = hovertip:AddLine()
            hovertip:SetCell(cooldownLine, 1, displayText, "GameTooltipText", "LEFT", hovertip:GetColumnCount())
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
        for spellID, buff in pairs(buffStore) do
            if type(spellID) == "number" then 
                tinsert(buffArray, {
                    spellID = spellID,
                    name = GetSpellInfo(spellID),
                    icon = GetSpellTexture(spellID),
                    remaining = buff.remainingDuration,
                    isBooned = buff.isBooned
                })
            end
        end
        self.characterWorldBuffCache[characterKey] = buffArray
    end
    return self.characterWorldBuffCache[characterKey]
end
