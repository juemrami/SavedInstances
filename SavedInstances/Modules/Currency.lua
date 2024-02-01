---@class SavedInstances
---@field logout boolean
local SI, L = unpack((select(2, ...)))
---@class CurrencyModule : AceModule , AceEvent-3.0, AceTimer-3.0, AceBucket-3.0
local Module = SI:NewModule('Currency', 'AceEvent-3.0', 'AceTimer-3.0', 'AceBucket-3.0')

-- Lua functions
local ipairs, pairs = ipairs, pairs

-- WoW API / Variables
local C_Covenants_GetActiveCovenantID = C_Covenants and C_Covenants.GetActiveCovenantID -- not in Wotlk client
local C_CurrencyInfo_GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
local C_QuestLog_IsQuestFlaggedCompleted = C_QuestLog.IsQuestFlaggedCompleted
local GetItemCount = GetItemCount
local GetMoney = GetMoney

local currency = {
  81, -- Epicurean Award
  515, -- Darkmoon Prize Ticket
  2588, -- Riders of Azeroth Badge

  -- Wrath of the Lich King
  61, -- Dalaran Jewelcrafter's Token
  81, -- Epicurean Award
  101, -- Emblem of Heroism
  102, -- Emblem of Valor
  126, -- Wintergrasp Mark of Honor
  161, -- Stone Keeper's Shard
  221, -- Emblem of Conquest
  241, -- Champion's Seal
  301, -- Emblem of Triumph
  341, -- Emblem of Frost
  1900, -- Arena Points
  1901, -- Honor Points
  2711, -- Defiler's Scourgestone
  2589, -- Sidereal Essence

  -- Cataclysm
  391, -- Tol Barad Commendation
  416, -- Mark of the World Tree

  -- Mists of Pandaria
  402, -- Ironpaw Token
  697, -- Elder Charm of Good Fortune
  738, -- Lesser Charm of Good Fortune
  752, -- Mogu Rune of Fate
  776, -- Warforged Seal
  777, -- Timeless Coin
  789, -- Bloody Coin

  -- Warlords of Draenor
  823, -- Apexis Crystal
  824, -- Garrison Resources
  994, -- Seal of Tempered Fate
  1101, -- Oil
  1129, -- Seal of Inevitable Fate
  1149, -- Sightless Eye
  1155, -- Ancient Mana
  1166, -- Timewarped Badge

  -- Legion
  1220, -- Order Resources
  1226, -- Nethershards
  1273, -- Seal of Broken Fate
  1275, -- Curious Coin
  1299, -- Brawler's Gold
  1314, -- Lingering Soul Fragment
  1342, -- Legionfall War Supplies
  1501, -- Writhing Essence
  1508, -- Veiled Argunite
  1533, -- Wakening Essence

  -- Battle for Azeroth
  1710, -- Seafarer's Dubloon
  1580, -- Seal of Wartorn Fate
  1560, -- War Resources
  1587, -- War Supplies
  1716, -- Honorbound Service Medal
  1717, -- 7th Legion Service Medal
  1718, -- Titan Residuum
  1721, -- Prismatic Manapearl
  1719, -- Corrupted Memento
  1755, -- Coalescing Visions
  1803, -- Echoes of Ny'alotha

  -- Shadowlands
  1754, -- Argent Commendation
  1191, -- Valor
  1602, -- Conquest
  1792, -- Honor
  1822, -- Renown
  1767, -- Stygia
  1828, -- Soul Ash
  1810, -- Redeemed Soul
  1813, -- Reservoir Anima
  1816, -- Sinstone Fragments
  1819, -- Medallion of Service
  1820, -- Infused Ruby
  1885, -- Grateful Offering
  1889, -- Adventure Campaign Progress
  1904, -- Tower Knowledge
  1906, -- Soul Cinders
  1931, -- Cataloged Research
  1977, -- Stygian Ember
  1979, -- Cyphers of the First Ones
  2009, -- Cosmic Flux
  2000, -- Motes of Fate

  -- Dragonflight
  2003, -- Dragon Isles Supplies
  2245, -- Flightstones
  2123, -- Bloody Tokens
  2797, -- Trophy of Strife
  2045, -- Dragon Glyph Embers
  2118, -- Elemental Overflow
  2122, -- Storm Sigil
  2409, -- Whelpling Crest Fragment Tracker [DNT]
  2410, -- Drake Crest Fragment Tracker [DNT]
  2411, -- Wyrm Crest Fragment Tracker [DNT]
  2412, -- Aspect Crest Fragment Tracker [DNT]
  2413, -- 10.1 Professions - Personal Tracker - S2 Spark Drops (Hidden)
  2533, -- Renascent Shadowflame
  2594, -- Paracausal Flakes
  2650, -- Emerald Dewdrop
  2651, -- Seedbloom
  2777, -- Dream Infusion
  2796, -- Renascent Dream
  2706, -- Whelpling's Dreaming Crest
  2707, -- Drake's Dreaming Crest
  2708, -- Wyrm's Dreaming Crest
  2709, -- Aspect's Dreaming Crest
  2774, -- 10.2 Professions - Personal Tracker - S3 Spark Drops (Hidden)
  2657, -- Mysterious Fragment
}
SI.currency = currency

local currencySorted = {}
local validCurrencies = {}
for _, currencyID in ipairs(currency) do
  -- check for nil currencies 
  if C_CurrencyInfo_GetCurrencyInfo(currencyID) then
    table.insert(currencySorted, currencyID)
    table.insert(validCurrencies, currencyID)
  end
end
table.sort(currencySorted, function (c1, c2)
  local c1_name = C_CurrencyInfo_GetCurrencyInfo(c1).name
  local c2_name = C_CurrencyInfo_GetCurrencyInfo(c2).name
  return c1_name < c2_name
end)
SI.currencySorted = currencySorted
SI.validCurrencies = validCurrencies

local hiddenCurrency = {
}

local specialCurrency = {
  [1129] = { -- WoD - Seal of Tempered Fate
    weeklyMax = 3,
    earnByQuest = {
      36058,  -- Seal of Dwarven Bunker
      -- Seal of Ashran quests
      36054,
      37454,
      37455,
      36056,
      37456,
      37457,
      36057,
      37458,
      37459,
      36055,
      37452,
      37453,
    },
  },
  [1273] = { -- LEG - Seal of Broken Fate
    weeklyMax = 3,
    earnByQuest = {
      43895,
      43896,
      43897,
      43892,
      43893,
      43894,
      43510, -- Order Hall
      47851, -- Mark of Honor x5
      47864, -- Mark of Honor x10
      47865, -- Mark of Honor x20
    },
  },
  [1580] = { -- BfA - Seal of Wartorn Fate
    weeklyMax = 2,
    earnByQuest = {
      52834, -- Gold
      52838, -- Piles of Gold
      52835, -- Marks of Honor
      52839, -- Additional Marks of Honor
      52837, -- War Resources
      52840, -- Stashed War Resources
    },
  },
  [1755] = { -- BfA - Coalescing Visions
    relatedItem = {
      id = 173363, -- Vessel of Horrific Visions
    },
  },
}
SI.specialCurrency = specialCurrency

for _, tbl in pairs(specialCurrency) do
  if tbl.earnByQuest then
    for _, questID in ipairs(tbl.earnByQuest) do
      SI.QuestExceptions[questID] = "Regular" -- not show in Weekly Quest
    end
  end
end

Module.OverrideName = {
  [2409] = L["Loot Whelpling Crest Fragment"], -- Whelpling Crest Fragment Tracker [DNT]
  [2410] = L["Loot Drake Crest Fragment"], -- Drake Crest Fragment Tracker [DNT]
  [2411] = L["Loot Wyrm Crest Fragment"], -- Wyrm Crest Fragment Tracker [DNT]
  [2412] = L["Loot Aspect Crest Fragment"], -- Aspect Crest Fragment Tracker [DNT]
  [2413] = L["Loot Spark of Shadowflame"], -- 10.1 Professions - Personal Tracker - S2 Spark Drops (Hidden)
  [2774] = L["Loot Spark of Dreams"], -- 10.2 Professions - Personal Tracker - S3 Spark Drops (Hidden)
}

Module.OverrideTexture = {
  [2413] = 5088829, -- 10.1 Professions - Personal Tracker - S2 Spark Drops (Hidden)
  [2774] = 5341573, -- 10.2 Professions - Personal Tracker - S3 Spark Drops (Hidden)
}

function Module:OnEnable()
  self:RegisterEvent("PLAYER_MONEY", "UpdateCurrency")
  self:RegisterBucketEvent("CURRENCY_DISPLAY_UPDATE", 0.25, "UpdateCurrency")
  self:RegisterEvent("BAG_UPDATE", "UpdateCurrencyItem")
end

function Module:UpdateCurrency()
  if SI.logout then return end -- currency is unreliable during logout

  local playerStore = SI.db.Toons[SI.thisToon]
  playerStore.Money = GetMoney()
  playerStore.currency = playerStore.currency or {}

  local covenantID = C_Covenants_GetActiveCovenantID and C_Covenants_GetActiveCovenantID()
  for _,currencyID in ipairs(currency) do
    local data = C_CurrencyInfo_GetCurrencyInfo(currencyID)
    if not data or (not data.discovered and not hiddenCurrency[currencyID]) then
      playerStore.currency[currencyID] = nil
    else
      local currencyInfo = playerStore.currency[currencyID] or {}
      currencyInfo.amount = data.quantity
      currencyInfo.totalMax = data.maxQuantity
      currencyInfo.earnedThisWeek = data.quantityEarnedThisWeek
      currencyInfo.weeklyMax = data.maxWeeklyQuantity
      if data.useTotalEarnedForMaxQty then
        currencyInfo.totalEarned = data.totalEarned
      end
      -- handle special currency
      if specialCurrency[currencyID] then
        local tbl = specialCurrency[currencyID]
        if tbl.weeklyMax then currencyInfo.weeklyMax = tbl.weeklyMax end
        if tbl.earnByQuest then
          currencyInfo.earnedThisWeek = 0
          for _, questID in ipairs(tbl.earnByQuest) do
            if C_QuestLog_IsQuestFlaggedCompleted(questID) then
              currencyInfo.earnedThisWeek = currencyInfo.earnedThisWeek + 1
            end
          end
        end
        if tbl.relatedItem then
          currencyInfo.relatedItemCount = GetItemCount(tbl.relatedItem.id)
        end
      elseif covenantID and currencyID == 1822 then -- Renown
        -- plus one to amount and totalMax
        currencyInfo.amount = currencyInfo.amount + 1
        currencyInfo.totalMax = currencyInfo.totalMax + 1
        if covenantID > 0 then
          currencyInfo.covenant = currencyInfo.covenant or {}
          currencyInfo.covenant[covenantID] = currencyInfo.amount
        end
      elseif covenantID and (currencyID == 1810 or currencyID == 1813) then -- Redeemed Soul and Reservoir Anima
        if covenantID > 0 then
          currencyInfo.covenant = currencyInfo.covenant or {}
          currencyInfo.covenant[covenantID] = currencyInfo.amount
        end
      elseif currencyID == 2774 then -- 10.2 Professions - Personal Tracker - S3 Spark Drops (Hidden)
        local duration = SI:GetNextWeeklyResetTime() - 1699365600 -- 2023-11-07T14:00:00+00:00
        currencyInfo.totalMax = floor(duration / 604800) -- 7 days
      end
      -- don't store useless info
      if currencyInfo.weeklyMax == 0 then currencyInfo.weeklyMax = nil end
      if currencyInfo.totalMax == 0 then currencyInfo.totalMax = nil end
      if currencyInfo.earnedThisWeek == 0 then currencyInfo.earnedThisWeek = nil end
      if currencyInfo.totalEarned == 0 then currencyInfo.totalEarned = nil end
      playerStore.currency[currencyID] = currencyInfo
    end
  end
end
--- There is no designated currency api in classic. all currencies are treated as items. 
local classicCurrencies = {
  -- Holiday Currency
  19182, -- Darkmoon Faire Prize Ticket
  21100, -- Coin of Ancestry

  -- ZG Bijous + Coins
  19698, -- Zulian Coin
  19699, -- Razzashi Coin
  19700, -- Hakkari Coin
  19701, -- Gurubashi Coin
  19702, -- Vilebranch Coin
  19703, -- Witherbark Coin
  19704, -- Sandfury Coin
  19705, -- Skullsplitter Coin
  19706, -- Bloodscalp Coin
  19707, -- Red Hakkari Bijou
  19708, -- Blue Hakkari Bijou
  19709, -- Yellow Hakkari Bijou
  19710, -- Orange Hakkari Bijou
  19711, -- Green Hakkari Bijou
  19712, -- Purple Hakkari Bijou
  19713, -- Bronze Hakkari Bijou
  19714, -- Silver Hakkari Bijou
  19715, -- Gold Hakkari Bijou

  -- Battleground Rewards
  19322, -- Warsong Mark of Honor
  20558, -- Warsong Gulch Mark of Honor
  20559, -- Arathi Basin Mark of Honor
  20560, -- Alterac Valley Mark of Honor

  -- AQ Scarabs + Idols
  20858, -- Stone Scarab
  20859, -- Gold Scarab
  20860, -- Silver Scarab
  20861, -- Bronze Scarab
  20862, -- Crystal Scarab
  20863, -- Clay Scarab
  20864, -- Bone Scarab
  20865, -- Ivory Scarab
  20866, -- Azure Idol
  20867, -- Onyx Idol
  20868, -- Lambent Idol
  20869, -- Amber Idol
  20870, -- Jasper Idol
  20871, -- Obsidian Idol
  20872, -- Vermillion Idol
  20873, -- Alabaster Idol
  20874, -- Idol of the Sun
  20875, -- Idol of Night
  20876, -- Idol of Death
  20877, -- Idol of the Sage
  20878, -- Idol of Rebirth
  20879, -- Idol of Life
  20881, -- Idol of Strife
  20882, -- Idol of War

  -- Naxx Gear Reagents
  22373, -- Wartorn Leather Scrap
  22374, -- Wartorn Chain Scrap
  22375, -- Wartorn Plate Scrap
  22376, -- Wartorn Cloth Scrap

  -- Argent Dawn Related
  12840, -- Minion's Scourgestone
  12841, -- Invader's Scourgestone
  12843, -- Corruptor's Scourgestone
  12844, -- Argent Dawn Valor Token
  22523, -- Insignia of the Dawn
  22524, -- Insignia of the Crusade

  -- Silithus Quests
  20800, -- Cenarion Logistics Badge
  20801, -- Cenarion Tactical Badge
  20802, -- Cenarion Combat Badge

  -- MC
  17333, -- Aqual Quintessence
  22754, -- Eternal Quintessence
}

function Module:UpdateCurrencyItem()
  if not SI.db.Toons[SI.thisToon].currency then return end

  for currencyID, tbl in pairs(specialCurrency) do
    if tbl.relatedItem and SI.db.Toons[SI.thisToon].currency[currencyID] then
      SI.db.Toons[SI.thisToon].currency[currencyID].relatedItemCount = GetItemCount(tbl.relatedItem.id)
    end
  end
  if SI.isClassicEra then
    for _, currencyID in ipairs(classicCurrencies) do
      local currencyInfo = SI.db.Toons[SI.thisToon].currency[currencyID] or {}
      currencyInfo.relatedItemCount = GetItemCount(currencyID)
      SI.db.Toons[SI.thisToon].currency[currencyID] = currencyInfo
    end
  end
end

