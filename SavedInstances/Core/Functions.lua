---@class SavedInstances
local SI, L = unpack((select(2, ...)))

-- Lua functions
local format, strmatch, strupper = format, strmatch, strupper

-- WoW API / Variables
local C_Map_GetBestMapForUnit = C_Map.GetBestMapForUnit
-- C_UnitAuras not in WotLK client
local C_UnitAuras_GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID 
-- Use `GetSpellInfo` and `AuraUtil.FindAuraByName` as an alternative 
local GetSpellInfo = GetSpellInfo
local AuraUtil_FindAuraByName = AuraUtil and AuraUtil.FindAuraByName 
local GetCurrentRegion = GetCurrentRegion
local GetCVar = GetCVar
local GetTime = GetTime

--- Get the expiration time of a player aura by spell ID.
---@param spellID number
---@return number? expirationTime Time the aura expires compared to GetTime()
function SI:GetPlayerAuraExpirationTime(spellID)
  if C_UnitAuras_GetPlayerAuraBySpellID then
    local info = C_UnitAuras_GetPlayerAuraBySpellID(spellID)
    return info and info.expirationTime
  elseif AuraUtil_FindAuraByName then -- alternative
    local name = GetSpellInfo(spellID)
    if name then
      local _, _, _, _, _, expirationTime = AuraUtil_FindAuraByName(name, 'player')
      return expirationTime
    end
  end
end

--- Adds a message to chat prefixed with the addon name.
---@param str string
---@param ... (string|number) format arguments, if any, for the string 
function SI:ChatMsg(str, ...)
  DEFAULT_CHAT_FRAME:AddMessage('|cFFFF0000SavedInstances|r: ' .. format(str, ...))
end

do
  local bugReported = {}
  function SI:BugReport(msg)
    local now = GetTime()
    if bugReported[msg] and now < bugReported[msg] + 60 then return end
    bugReported[msg] = now
    SI:ChatMsg(msg)

    if bugReported['url'] and now < bugReported['url'] + 5 then return end
    bugReported['url'] = now
    SI:ChatMsg("Please report this bug at: https://github.com/SavedInstances/SavedInstances/issues")
  end
end

-- Get Region
do
  local region
  function SI:GetRegion()
    if not region then
      local portal = GetCVar('portal')
      if portal == 'public-test' then
        -- PTR uses US region resets, despite the misleading realm name suffix
        portal = 'US'
      end
      if not portal or #portal ~= 2 then
        local regionID = GetCurrentRegion()
        portal = portal and ({'US', 'KR', 'EU', 'TW', 'CN'})[regionID]
      end
      if not portal or #portal ~= 2 then -- other test realms?
        portal = strmatch(SI.realmName or '', '%((%a%a)%)')
      end
      portal = portal and strupper(portal)
      if portal and #portal == 2 then
        region = portal
      end
    end
    return region
  end
end

-- Get Current uiMapID
function SI:GetCurrentMapAreaID()
  return C_Map_GetBestMapForUnit('player')
end

--- Wraps given text in a color string based on the class of the given toon.
--- if not text given uses the toon name.
function SI:ClassColorString(toon, str)
  if not str then
    str = toon
  end

  local class = SI.db.Toons[toon] and SI.db.Toons[toon].Class
  if not class then
    return str
  end

  local color = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or RAID_CLASS_COLORS[class]
  if color.WrapTextInColorCode then
    return color:WrapTextInColorCode(str)
  end
  
  if color.colorStr then
    return "|c" .. color.colorStr .. str .. FONT_COLOR_CODE_CLOSE
  end

  local r = color[1] or color.r
  local g = color[2] or color.g
  local b = color[3] or color.b
  local a = color[4] or color.a or 1

  return format(
    "|c%02x%02x%02x%02x%s%s",
    floor(a * 255), floor(r * 255), floor(g * 255), floor(b * 255),
    str, FONT_COLOR_CODE_CLOSE
  )
end

---@param toon string
function SI:ClassColorToon(toon)
  local str = SI.db.Tooltip.ShowServer and toon 
    or strsplit(' ', toon) --remove server name
  return SI:ClassColorString(toon, str)
end
