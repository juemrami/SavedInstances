---@class SavedInstances
local SI, L = unpack((select(2, ...)))

-- Lua functions
local date, floor, time, tonumber = date, floor, time, tonumber

-- WoW API / Variables
local C_DateAndTime_GetCurrentCalendarTime = C_DateAndTime.GetCurrentCalendarTime
local C_DateAndTime_GetSecondsUntilWeeklyReset = C_DateAndTime.GetSecondsUntilWeeklyReset
local C_DateAndTime_GetSecondsUntilDailyReset = C_DateAndTime.GetSecondsUntilDailyReset
local C_Calendar_GetMonthInfo = C_Calendar.GetMonthInfo
local C_Calendar_SetAbsMonth = C_Calendar.SetAbsMonth
local GetQuestResetTime = GetQuestResetTime

do
  --- Unix timestamp in seconds of the current time minus the player's computer system uptime.
  --- When added to `GetTime()` result in a unix timestamp in seconds.
  local gttOffset = time() - GetTime()

  --- Returns unix timestamp in seconds of the time after the passed `seconds` have elapsed.
  ---@param seconds number? A number of seconds from now.
  ---@return number? timeToTime Unix timestamp in seconds of the future time minus the player's computer system uptime. nil if futureTime is nil.
  function SI:GetTimeToTime(seconds)
    if not seconds then return end
    return gttOffset + seconds
  end
end

--- returns how many hours the server time is ahead of local time.
--- To convert local time -> server time: add this value
--- To convert server time -> local time: subtract this value
---@return number offset
function SI:GetServerOffset()
  local serverDate = C_DateAndTime_GetCurrentCalendarTime() -- 1-based starts on Sun
  local serverWeekday, serverMinute, serverHour = serverDate.weekday - 1, serverDate.minute, serverDate.hour
  -- #211: date('%w') is 0-based starts on Sun
  local localWeekday = tonumber(date('%w'))
  local localHour, localMinute = tonumber(date('%H')), tonumber(date('%M'))
  if serverWeekday == (localWeekday + 1) % 7 then -- server is a day ahead
    serverHour = serverHour + 24
  elseif localWeekday == (serverWeekday + 1) % 7 then -- local is a day ahead
    localHour = localHour + 24
  end
  local serverT = serverHour + serverMinute / 60
  local localT = localHour + localMinute / 60
  local offset = floor((serverT - localT) * 2 + 0.5) / 2
  return offset
end

--- Returns unix timestamp in seconds of the next daily reset time.
---@return number? resetTimestamp nil if the reset time cannot be determined.
function SI:GetNextDailyResetTime()
  local resetTime = GetQuestResetTime()
  resetTime = resetTime or C_DateAndTime_GetSecondsUntilDailyReset() -- try C API

  if not resetTime -- ticket 43: `GetQuestResetTime()` can fail during startup
    or resetTime <= 0 -- also right after a daylight savings rollover, when it returns negative values >.<
    or resetTime > 24 * 60 * 60 + 30 -- can also be wrong near reset in an instance
  then
    return 
  end

  return time() + resetTime
end

SI.GetNextDailySkillResetTime = SI.GetNextDailyResetTime

--- Returns unix timestamp in seconds for the next weekly reset.
---@return number resetTimestamp
function SI:GetNextWeeklyResetTime()
  return time() + C_DateAndTime_GetSecondsUntilWeeklyReset()
end

do
  local darkmoonEnd = { hour=23, min=59 }
  function SI:GetNextDarkmoonResetTime()
    -- Darkmoon faire runs from first Sunday of each month to following Saturday
    -- this function returns an approximate time after the end of the current month's faire
    local currentCalendarTime = C_DateAndTime_GetCurrentCalendarTime()
    C_Calendar_SetAbsMonth(currentCalendarTime.month, currentCalendarTime.year)
    local monthInfo = C_Calendar_GetMonthInfo()
    local firstWeekday = monthInfo.firstWeekday
    local firstSunday = ((firstWeekday == 1) and 1) or (9 - firstWeekday)
    darkmoonEnd.year = monthInfo.year
    darkmoonEnd.month = monthInfo.month
    darkmoonEnd.day = firstSunday + 7 -- 1 days of "slop"
    -- Unfortunately, DMF boundary ignores daylight savings, and the time of day varies across regions
    -- Report a reset well past end to make sure we don't drop quests early
    return time(darkmoonEnd) - SI:GetServerOffset() * 3600
  end
end
