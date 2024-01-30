local
---@type string
addon,
---@type {[1]: SavedInstances, [2]: table<string, string>}
Engine = ...

---@class SavedInstances : AceAddon, AceEvent-3.0, AceBucket-3.0, AceTimer-3.0
local SI = LibStub('AceAddon-3.0'):NewAddon(addon, 'AceEvent-3.0', 'AceTimer-3.0', 'AceBucket-3.0')


Engine[1] = SI
Engine[2] = {} -- locale table.
_G.SavedInstances = Engine

SI.Libs = {}
---@class QTip : LibQTip-1.0
---@field Acquire fun(self: QTip, name: string, columns: number, ...)
SI.Libs.QTip = LibStub('LibQTip-1.0')
SI.Libs.LDB = LibStub('LibDataBroker-1.1', true)
SI.Libs.LDBI = SI.Libs.LDB and LibStub('LibDBIcon-1.0', true)

---@class SavedInstances.ScanTooltip : GameTooltip
SI.ScanTooltip = CreateFrame('GameTooltip', 'SavedInstancesScanTooltip', _G.UIParent, 'GameTooltipTemplate')
SI.ScanTooltip:SetOwner(_G.UIParent, 'ANCHOR_NONE')


SI.playerName = UnitName('player')
SI.playerLevel = UnitLevel('player')
SI.realmName = GetRealmName()
SI.thisToon = SI.playerName .. ' - ' .. SI.realmName
SI.maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or GetEffectivePlayerMaxLevel()
SI.locale = GetLocale()

local build = floor(select(4, GetBuildInfo()) / 10000)
SI.isClassicEra = build == 1
SI.isWrath = build == 3
SI.isSoD = SI.isClassicEra
    and C_Seasons.HasActiveSeason()
    and C_Seasons.GetActiveSeason() == (Enum.SeasonID.SeasonOfDiscovery or Enum.SeasonID.Placeholder)
SI.isRetail = build >= 10
SI.questCheckMark = '\124A:UI-LFG-ReadyMark:14:14\124a'
SI.questTurnin = '\124A:QuestTurnin:14:14\124a'
SI.questNormal = '\124A:QuestNormal:14:14\124a'
