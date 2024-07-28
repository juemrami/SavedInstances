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
---@field Acquire fun(self: QTip, name: string, columns: number, ...): QTip
SI.Libs.QTip = LibStub('LibQTip-1.0')
SI.Libs.LDB = LibStub('LibDataBroker-1.1', true)
SI.Libs.LDBI = SI.Libs.LDB and LibStub('LibDBIcon-1.0', true)

-- In classic some popular addons add stuff into the "GameTooltipTemplate" which we might accidentally scan so we use "SharedTooltipTemplate".
-- However, "SharedTooltipTemplate" doesn't have SetHyperlink method in retail
local tooltipTemplate = SI.isRetail and 'GameTooltipTemplate' or 'SharedTooltipTemplate, GameTooltipTemplate'
---@class SavedInstances.ScanTooltip : GameTooltip
SI.ScanTooltip = CreateFrame('GameTooltip', 'SavedInstancesScanTooltip', nil, tooltipTemplate)
local setHyperlink = SI.ScanTooltip.SetHyperlink

assert(setHyperlink, 'Failed to create ScanTooltip, missing `SetHyperlink` method on inherited tooltip')
---@param link string?
function SI.ScanTooltip:SetHyperlink(link)
    if not link then return end
    self:SetOwner(WorldFrame, 'ANCHOR_NONE')
    -- self:ClearAllPoints()
	-- self:SetPoint("BOTTOMLEFT", WorldFrame, "BOTTOMLEFT", 0, 0);
    setHyperlink(self, link)
    -- self:Show()
end
SI.ScanTooltip:SetOwner(WorldFrame, 'ANCHOR_NONE')


SI.playerName = UnitName('player')
SI.playerLevel = UnitLevel('player')
SI.realmName = GetRealmName()
SI.thisToon = SI.playerName .. ' - ' .. SI.realmName
SI.maxLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or GetEffectivePlayerMaxLevel()
SI.locale = GetLocale()

local build = floor(select(4, GetBuildInfo()) / 10000)
SI.isRetail = build >= 10
SI.isClassicEra = build == 1
SI.isWrath = build == 3
SI.isCataclysm = build == 4
SI.isSoD = SI.isClassicEra
    and C_Seasons.HasActiveSeason()
    and C_Seasons.GetActiveSeason() == Enum.SeasonID.SeasonOfDiscovery;

SI.questCheckMark = '\124A:UI-LFG-ReadyMark:14:14\124a'
SI.questTurnin = '\124A:QuestTurnin:14:14\124a'
SI.questNormal = '\124A:QuestNormal:14:14\124a'
