---@class SavedInstances
local SI, L = unpack((select(2, ...)))

---@class ConfigModule : AceModule
local Config = SI:NewModule('Config')

local Tooltip = SI:GetModule('Tooltip')
local Currency = SI:GetModule('Currency')
local Progress = SI:GetModule('Progress')
local Warfront = SI.isRetail and SI:GetModule('Warfront') or nil
---@cast Tooltip TooltipModule
---@cast Currency CurrencyModule
---@cast Progress ProgressModule.Wrath

-- Lua functions
local pairs, ipairs, tonumber, tostring, wipe, unpack, date, tinsert, sort
    = pairs, ipairs, tonumber, tostring, wipe, unpack, date, tinsert, sort
local _G = _G

-- WoW API / Variables
local C_CurrencyInfo_GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo
local GetBindingKey = GetBindingKey
local GetCurrentBindingSet = GetCurrentBindingSet
local GetRealmName = GetRealmName
local SaveBindings = SaveBindings
local SetBinding = SetBinding


local HideUIPanel = HideUIPanel
local Settings_OpenToCategory = Settings.OpenToCategory
local ADDON_NAME = "SavedInstances"
local StaticPopup_Show = StaticPopup_Show

local ALL = ALL
local CALLINGS_QUESTS = CALLINGS_QUESTS
local COLOR = COLOR
local CURRENCY = CURRENCY
local DELETE = DELETE
local EMBLEM_SYMBOL = EMBLEM_SYMBOL
local GREEN_FONT_COLOR_CODE = GREEN_FONT_COLOR_CODE
local LEVEL = LEVEL
local RED_FONT_COLOR_CODE = RED_FONT_COLOR_CODE

-- GLOBALS: LibStub, BINDING_NAME_SAVEDINSTANCES, BINDING_HEADER_SAVEDINSTANCES
local version = 1

-- 
SI.diff_strings = {
  D1 = DUNGEON_DIFFICULTY1, -- 5 man
  D2 = DUNGEON_DIFFICULTY2, -- 5 man (Heroic)
  R0 = EXPANSION_NAME0 .. " " .. LFG_TYPE_RAID,
  R1 = RAID_DIFFICULTY1, -- "10 man" 
  R2 = RAID_DIFFICULTY2, -- "25 man"
  R3 = RAID_DIFFICULTY3, -- "10 man (Heroic)"
  R4 = RAID_DIFFICULTY4, -- "25 man (Heroic)"
  -- https://warcraft.wiki.gg/wiki/DifficultyID
  R5 = GetDifficultyInfo(7), -- "Looking for Raid"
  R6 = GetDifficultyInfo(14), -- "Normal raid"
  R7 = GetDifficultyInfo(15), -- "Heroic raid"
  R8 = GetDifficultyInfo(16), -- "Mythic raid"
}

SI.difficultyStrings = SI.diff_strings 

local FONTEND = FONT_COLOR_CODE_CLOSE
local GOLDFONT = NORMAL_FONT_COLOR_CODE

-- config global functions

function Config:OnInitialize()
  Config:RegisterAddonSettingsPanel()
end

BINDING_NAME_SAVEDINSTANCES = L["Show/Hide the SavedInstances tooltip"]
BINDING_HEADER_SAVEDINSTANCES = "SavedInstances"

-- general helper functions

function SI:idtext(instance,diff,info)
  if instance.WorldBoss then
    return L["World Boss"]
  elseif info.ID < 0 then
    return "" -- ticket 144: could be RAID_FINDER or FLEX_RAID, but this is already shown in the instance name so it's redundant anyhow
  elseif not instance.Raid then
    if diff == 23 then
      return SI.diff_strings["D3"]
    else
      return SI.diff_strings["D"..diff]
    end
  elseif instance.Expansion == 0 then -- classic Raid
    return SI.diff_strings.R0
  elseif instance.Raid and diff >= 3 and diff <= 7 then -- pre-WoD raids
    return SI.diff_strings["R"..(diff-2)]
  elseif diff >= 14 and diff <= 16 then -- WoD raids
    return SI.diff_strings["R"..(diff-8)]
  elseif diff == 17 then -- Looking For Raid
    return SI.diff_strings.R5
  else
    return ""
  end
end

--- Builds and returns the options table for the "Indicators" sub-section SavedInstances options.
---@return table<string, AceConfig.OptionsTable> args A table of valid AceConfig `args` for the option table.
local function GetIndicatorOptions()
  ---@type table<string, AceConfig.OptionsTable>
  local args = {
    Instructions = {
      order = 1,
      type = "description",
      name = L["You can combine icons and text in a single indicator if you wish. Simply choose an icon, and insert the word ICON into the text field. Anywhere the word ICON is found, the icon you chose will be substituted in."].." "..L["Similarly, the words KILLED and TOTAL will be substituted with the number of bosses killed and total in the lockout."],
    },
  }
  for category, displayName in pairs(SI.difficultyStrings) do
    local order = (tonumber(category:match("%d+")) or 0) + 10
    --- Position raid difficulties after dungeon difficulties
    if category:find("^R") then 
      order = order + 10
    end
    args[category] = {
      type = "group",
      name = displayName,
      order = order,
      args = {
        [category.."Indicator"] = {
          order = 1,
          type = "select",
          width = "half",
          name = EMBLEM_SYMBOL,
          values = SI.IndicatorIconTextures or SI.Indicators -- (old name)
        },
        [category.."Text"] = {
          order = 2,
          type = "input",
          name = L["Text"],
          multiline = false
        },
        [category.."Color"] = {
          order = 3,
          type = "color",
          width = "half",
          hasAlpha = false,
          name = COLOR,
          disabled = function()
            -- return false
            return not not SI.db.Indicators[category .. "ClassColor"]
          end,
          get = function(info)
            color = SI.db.Indicators[info[#info]]  or SI.defaultDB.Indicators[info[#info]]
            local r = color[1]
            local g = color[2]
            local b = color[3]
            --- will be using color mixin going forward. `nil` check required for backwards compatibility.
            if color.GetRGB or color.GetRGBA then
              r, g, b, a = (color.GetRGBA or color.GetRGB)(color)
              SI:Debug("Color picker returned a colorMixin | r: %s, g: %s, b: %s, a: %s", r, g, b, a)
            end
            return r, g, b, nil
          end,
          set = function(info, r, g, b, ...)
            assert(r and g and b, "Color picker returned nil values")
            local color = CreateColor(r, g, b, 1)
            SI.db.Indicators[info[#info]] = color

            --- for backwards comptaibility. this should be depracated in the future in favor of using a colormixin.
            SI.db.Indicators[info[#info]][1] = r
            SI.db.Indicators[info[#info]][2] = g
            SI.db.Indicators[info[#info]][3] = b
            SI:Debug("Color picker set with colorMixin | r: %s, g: %s, b: %s", r, g, b)
          end,
        },
        [category.."ClassColor1"] = {
          order = 4,
          type = "toggle",
          name = L["Use class color"],
          -- set = function(info, value)
          --   SI.db.Indicators[info[#info]] = value
          -- end,
          -- get = function(info)
          --   return SI.db.Indicators[info[#info]] or SI.defaultDB.Indicators[info[#info]]
          -- end,
        },
        [category.."TEST"] = {
          order = 6,
          type = "toggle",
          name = "this is a test",
        },
      },
    }
  end
  return args
end
-----------------------------------------------------------------------
---@type AceConfig.OptionsTable
local savedOptions = {}
--- Build the addon's option table used by AceConfig to generate the addon's settings panel in the blizzard settings frame. 
--- See [AceConfig3 options tables](https://www.wowace.com/projects/ace3/pages/ace-config-3-0-options-tables) for more info.
---@return AceConfig.OptionsTable options
function Config:BuildAceConfigOptions()
  ---@type AceConfig.OptionsTable
  local valuesList = { 
    ["always"] = GREEN_FONT_COLOR_CODE..L["Always show"]..FONTEND,
    ["saved"] = L["Show when saved"],
    ["never"] = RED_FONT_COLOR_CODE..L["Never show"]..FONTEND,
  }
  ---@class AceConfig.OptionsTable
  local options = {
    type = "group",
    name = "SavedInstances",
    handler = SI,
    get = function(info)
      return SI.db.Tooltip[info[#info]]
    end,
    set = function(info, value)
      SI:Debug(info[#info].." set to: "..tostring(value))
      SI.db.Tooltip[info[#info]] = value
      wipe(SI.scaleCache)
      wipe(SI.oi_cache)
      SI.oc_cache = nil
    end,
    --use info[#info] to get the leaf node name
    args = {
      config = {
        name = L["Open config"],
        guiHidden = true,
        type = "execute",
        func = function() Config:ShowConfig() end,
      },
      time = {
        name = L["Dump time debugging information"],
        guiHidden = true,
        type = "execute",
        func = function() SI:TimeDebug() end,
      },
      quest = {
        name = L["Dump quest debugging information"],
        guiHidden = true,
        type = "execute",
        func = function(...) SI:QuestDebug(...) end,
      },
      show = {
        name = L["Show/Hide the SavedInstances tooltip"],
        guiHidden = true,
        type = "execute",
        func = function() Tooltip:ToggleDetached() end,
      },
      General = {
        order = 1,
        type = "group",
        name = L["General settings"],
        args = {
          ver = {
            order = 0.5,
            type = "description",
            name = function() return "Version: SavedInstances "..SI.version end,
          },
          GeneralHeader = {
            order = 2,
            type = "header",
            name = L["General settings"],
          },
          MinimapIcon = {
            type = "toggle",
            name = L["Show minimap button"],
            desc = L["Show the SavedInstances minimap button"],
            order = 3,
            hidden = function() return not SI.Libs.LDBI end,
            get = function(info) return not SI.db.MinimapIcon.hide end,
            set = function(info, value)
              SI.db.MinimapIcon.hide = not value
              SI.Libs.LDBI:Refresh("SavedInstances", nil)
            end,
          },
          DisableMouseover = {
            type = "toggle",
            name = L["Disable mouseover"],
            desc = L["Disable tooltip display on icon mouseover"],
            order = 3.5,
          },
          ShowHints = {
            type = "toggle",
            name = L["Show tooltip hints"],
            order = 4,
          },
          ReportResets = {
            type = "toggle",
            name = L["Report instance resets to group"],
            order = 4.5,
          },
          LimitWarn = {
            type = "toggle",
            name = L["Warn about instance limit"],
            order = 4.7,
          },
          HistoryText = {
            type = "toggle",
            name = L["Instance limit in Broker"],
            order = 4.8,
          },
          AbbreviateKeystone = {
            type = "toggle",
            name = L["Abbreviate keystones"],
            desc = L["Abbreviate Mythic keystone dungeon names"],
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,  
            order = 4.85
          },
          KeystoneReportTarget = {
            type = "select",
            name = L["Keystone report target"],
            values = {
              ["PARTY"] = L["Party"],
              ["GUILD"] = L["Guild"],
              ["EXPORT"] = L["Export"]
            },
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,
            order = 4.86
          },
          DebugMode = {
            type = "toggle",
            name = L["Debug Mode"],
            order = 4.9,
          },
          CategoriesHeader = {
            order = 11,
            type = "header",
            name = L["Categories"],
          },
          ShowCategories = {
            type = "toggle",
            name = L["Show category names"],
            desc = L["Show category names in the tooltip"],
            order = 12,
          },
          ShowSoloCategory = {
            type = "toggle",
            name = L["Single category name"],
            desc = L["Show name for a category when all displayed instances belong only to that category"],
            order = 13,
            disabled = function()
              return not SI.db.Tooltip.ShowCategories
            end,
          },
          CategorySpaces = {
            type = "toggle",
            name = L["Space between categories"],
            desc = L["Display instances with space inserted between categories"],
            order = 14,
          },
          CategorySort = {
            order = 15,
            type = "select",
            name = L["Sort categories by"],
            values = {
              ["EXPANSION"] = L["Expansion"],
              ["TYPE"] = L["Type"],
            },
          },
          NewFirst = {
            type = "toggle",
            name = L["Most recent first"],
            desc = L["List categories from the current expansion pack first"],
            order = 16,
          },
          RaidsFirst = {
            type = "toggle",
            name = L["Raids before dungeons"],
            desc = L["List raid categories before dungeon categories"],
            order = 17,
          },
          FitToScreen = {
            type = "toggle",
            name = L["Fit to screen"],
            desc = L["Automatically shrink the tooltip to fit on the screen"],
            order = 4.81,
          },
          Scale = {
            type = "range",
            name = L["Tooltip Scale"],
            order = 4.82,
            min = 0.1,
            max = 5,
            bigStep = 0.05,
          },
          RowHighlight = {
            type = "range",
            name = L["Row Highlight"],
            desc = L["Opacity of the tooltip row highlighting"],
            order = 4.83,
            min = 0,
            max = 0.5,
            bigStep = 0.1,
            isPercent = true,
          },
          InstancesHeader = {
            order = 20,
            type = "header",
            name = L["Instances"],
          },
          ReverseInstances = {
            type = "toggle",
            name = L["Reverse ordering"],
            desc = L["Display instances in order of recommended level from lowest to highest"],
            order = 23,
          },
          ShowExpired = {
            type = "toggle",
            name = L["Show Expired"],
            desc = L["Show expired instance lockouts"],
            order = 23.5,
          },
          ShowHoliday = {
            type = "toggle",
            name = L["Show Holiday"],
            desc = L["Show holiday boss rewards"],
            order = 23.65,
          },
          ShowRandom = {
            type = "toggle",
            name = L["Show Random"],
            desc = L["Show random dungeon bonus reward"],
            order = 23.75,
          },
          CombineWorldBosses = {
            type = "toggle",
            name = L["Combine World Bosses"],
            desc = L["Combine World Bosses"],
            order = 23.85,
          },
          CombineLFR = {
            type = "toggle",
            name = L["Combine LFR"],
            desc = L["Combine LFR"],
            order = 23.95,
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,
          },
          WarfrontHeader = {
            order = 33,
            type = "header",
            name = L["Warfronts"],
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,
          },
          EmissaryHeader = {
            order = 36,
            type = "header",
            name = L["Emissary quests"],
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,
          },
          EmissaryFullName = {
            type = "toggle",
            order = 39.1,
            name = L["Show all emissary names"],
            desc = L["Show both factions' emissay name"],
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,
          },
          EmissaryShowCompleted = {
            type = "toggle",
            order = 39.2,
            name = L["Show when completed"],
            desc = L["Show emissary line when all quests completed"],
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,
          },
          CombineEmissary = {
            type = "toggle",
            order = 39.3,
            name = L["Combine Emissaries"],
            desc = L["Combine emissaries of same expansion"],
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,
          },
          MiscHeader = {
            order = 40,
            type = "header",
            name = L["Miscellaneous Tracking"],
          },
          TrackDailyQuests = {
            type = "toggle",
            order = 43,
            name = L["Daily Quests"],
          },
          TrackWeeklyQuests = {
            type = "toggle",
            order = 43.5,
            name = L["Weekly Quests"],
          },
          TrackSkills = {
            type = "toggle",
            order = 43.7,
            name = L["Trade skills"],
          },
          TrackBonus = {
            type = "toggle",
            order = 43.8,
            name = L["Bonus rolls"],
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,
          },
          AugmentBonus = {
            type = "toggle",
            order = 43.9,
            name = L["Bonus loot frame"],
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,
          },
          TrackLFG = {
            type = "toggle",
            order = 44,
            name = L["LFG cooldown"],
            desc = L["Show cooldown for characters to use LFG dungeon system"],
            disabled = SI.isClassicEra,
            hidden = SI.isClassicEra,
          },
          TrackDeserter = {
            type = "toggle",
            order = 45,
            name = L["Battleground Deserter"],
            desc = L["Show cooldown for characters to use battleground system"],
          },
          TrackPlayed = {
            type = "toggle",
            order = 46,
            name = L["Time /played"],
          },
          MythicKey = {
            type = "toggle",
            order = 47,
            name = L["Mythic Keystone"],
            desc = L["Track Mythic keystone acquisition"],
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,
          },
          TimewornMythicKey = {
            type = "toggle",
            order = 47.1,
            name = L["Timeworn Mythic Keystone"],
            desc = L["Track Timeworn Mythic keystone acquisition"],
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,
          },
          MythicKeyBest = {
            type = "toggle",
            order = 47.5,
            name = L["Mythic Best"],
            desc = L["Track Mythic keystone best run"],
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,
          },
          TrackParagon = {
            type = "toggle",
            order = 48,
            name = L["Paragon Chests"],
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,
          },
          Calling = {
            type = "toggle",
            order = 49,
            name = CALLINGS_QUESTS or "", -- nil in classic clients
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,
          },
          CallingShowCompleted = {
            type = "toggle",
            order = 49.1,
            name = L["Show when completed"],
            desc = L["Show calling line when all quests completed"],
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,
          },
          CombineCalling = {
            type = "toggle",
            order = 49.2,
            name = L["Combine Callings"],
            disabled = not SI.isRetail,
            hidden = not SI.isRetail,
          },
          BindHeader = {
            order = -0.6,
            type = "header",
            name = "",
            cmdHidden = true,
          },
          ToggleBind = {
            desc = L["Bind a key to toggle the SavedInstances tooltip"],
            type = "keybinding",
            name = L["Show/Hide the SavedInstances tooltip"],
            width = "double",
            cmdHidden = true,
            order = -0.5,
            set = function(info,val)
              local b1, b2 = GetBindingKey("SAVEDINSTANCES")
              if b1 then SetBinding(b1) end
              if b2 then SetBinding(b2) end
              SetBinding(val, "SAVEDINSTANCES")
              SaveBindings(GetCurrentBindingSet())
            end,
            get = function(info) return GetBindingKey("SAVEDINSTANCES") end
          },
        },
      },
      Currency = {
        order = 3,
        type = "group",
        name = L["Currency settings"],
        get = function(info)
          return SI.db.Tooltip[info[#info]]
        end,
        set = function(info, value)
          SI:Debug(info[#info].." set to: "..tostring(value))
          SI.db.Tooltip[info[#info]] = value
          wipe(SI.scaleCache)
          wipe(SI.oi_cache)
          SI.oc_cache = nil
        end,
        args = {
          CurrencyValueColor = {
            type = "toggle",
            order = 10,
            name = L["Color currency by cap"]
          },
          NumberFormat = {
            type = "toggle",
            order = 20,
            name = L["Format large numbers"]
          },
          CurrencyMax = {
            type = "toggle",
            order = 30,
            name = L["Show currency max"]
          },
          CurrencyEarned = {
            type = "toggle",
            order = 40,
            name = L["Show currency earned"]
          },
          CurrencySortName = {
            type = "toggle",
            order = 50,
            name = L["Sort by currency name"],
          },
          CurrencyHeader = {
            order = 60,
            type = "header",
            name = CURRENCY,
          },
        },
      },
      Indicators = { 
        order = 4,
        type = "group",
        name = L["Indicators"],
        get = function(info)
          -- if SI.db.Indicators[info[#info]] ~= nil then -- tri-state boolean logic
          --   return SI.db.Indicators[info[#info]]
          -- else
          --   return SI.defaultDB.Indicators[info[#info]]
          -- end
          return SI.db.Indicators[info[#info]] or SI.defaultDB.Indicators[info[#info]]
        end,
        set = function(info, value)
          SI:Debug("Config set: "..info[#info].." = "..(value and "true" or "false"))
          SI.db.Indicators[info[#info]] = value
        end,
        args = GetIndicatorOptions(),
      },
      Instances = {
        order = 5,
        type = "group",
        name = L["Instances"],
        childGroups = "select",
        width = "double",
        args = (function()
          local instancesArgs = {}
          for idx, category in ipairs(SI:OrderedCategories()) do
            instancesArgs[category] = {
              order = idx,
              type = "group",
              name = SI.Categories[category],
              childGroups = "tree",
              args = (function()
                local instanceCategoryArgs = {}
                local insts = SI:OrderedInstances(category)
                for j, inst in ipairs(insts) do
                  instanceCategoryArgs[inst] = {
                    order = j,
                    name = inst,
                    type = "select",
                    -- style = "radio",
                    values = valuesList,
                    get = function(info)
                      local val = SI.db.Instances[inst].Show
                      return (val and valuesList[val] and val) or "saved"
                    end,
                    set = function(info, value)
                      SI.db.Instances[inst].Show = value
                    end,
                  }
                end
                instanceCategoryArgs[ALL] = {
                  order = 0,
                  name = L["Set All"],
                  type = "select",
                  values = valuesList,
                  get = function(info) return "" end,
                  set = function(info, value)
                    for j, inst in ipairs(insts) do
                      SI.db.Instances[inst].Show = value
                    end
                  end,
                }
                instanceCategoryArgs.spacer = {
                  order = 0.5,
                  name = "",
                  type = "description",
                  width = "full",
                  cmdHidden = true,
                }
                return instanceCategoryArgs
              end)(),
            }
          end
          return instancesArgs
        end)(),
      },
      Characters = {
        order = 6,
        type = "group",
        name = L["Characters"],
        args = {
          Sorting = {
            name = L["Sorting"],
            type = "group",
            guiInline = true,
            order = 1,
            args = {
              SelfAlways = {
                type = "toggle",
                name = L["Show self always"],
                order = 2,
              },
              SelfFirst = {
                type = "toggle",
                name = L["Show self first"],
                order = 3,
              },
              ShowServer = {
                type = "toggle",
                name = L["Show server name"],
                order = 5,
              },
              ServerSort = {
                type = "toggle",
                name = L["Sort by server"],
                order = 6,
              },
              ServerOnly = {
                type = "toggle",
                name = L["Show only current server"],
                order = 7,
              },
              ConnectedRealms = {
                type = "select",
                name = L["Connected Realms"],
                order = 10,
                disabled = function()
                  return not (SI.db.Tooltip.ServerSort or SI.db.Tooltip.ServerOnly)
                end,
                values = {
                  ["ignore"] = L["Ignore"],
                  ["group"] = L["Group"],
                  ["interleave"] = L["Interleave"],
                },
              },
            }
          },
          Manage = {
            name = L["Manage"],
            type = "group",
            guiInline = true,
            order = 2,
            childGroups = "select",
            width = "double",
            args = (function ()
              local toons = {}
              for toon, _ in pairs(SI.db.Toons) do
                local tn, ts = toon:match('^(.*) [-] (.*)$')
                toons[ts] = toons[ts] or {}
                tinsert(toons[ts],tn)
              end
              local ret = {}
              ret.reset = {
                order = 0.1,
                name = L["Reset Characters"],
                type = "execute",
                func = function()
                  StaticPopup_Show("SAVEDINSTANCES_RESET")
                end
              }
              ret.recover = {
                order = 0.2,
                name = L["Recover Dailies"],
                desc = L["Attempt to recover completed daily quests for this character. Note this may recover some additional, linked daily quests that were not actually completed today."],
                type = "execute",
                func = function()
                  SI:Refresh(true)
                end
              }
              local deltoon = function(info)
                local toon, tinfo = unpack(info.arg)
                if not toon then return end
                local dialog = StaticPopup_Show("SAVEDINSTANCES_DELETE_CHARACTER", toon, tinfo, toon)
              end
              local toonfncache = {}
              local toonget = function(field, default)
                local key = field.."_get"
                local fn = toonfncache[key] or function(info)
                  return tostring(info.arg[field] or default)
                end
                toonfncache[key] = fn
                return fn
              end
              local toonset = function(field, isnum)
                local key = field.."_set"
                local fn = toonfncache[key] or function(info, value)
                  if isnum then
                    value = tonumber(value)
                  end
                  info.arg[field] = value
                end
                toonfncache[key] = fn
                return fn
              end
              local orderval = function(info, value)
                if value:find("^%s*[0-9]?[0-9]?[0-9]%s*$") then
                  return true
                else
                  local err = L["Order must be a number in [0 - 999]"]
                  SI:ChatMsg(err)
                  return err
                end
              end
              -- label line
              ret.newline1 = {
                order = 0.40,
                cmdHidden = true,
                name = "",
                type = "description",
                width = "full",
              }
              ret.cname = {
                order = 0.41,
                cmdHidden = true,
                name = " ",
                type = "description",
                width = "half",
              }
              ret.cshow = {
                order = 0.42,
                cmdHidden = true,
                fontSize = "medium",
                name = "  "..L["Show When"],
                type = "description",
                width = "normal",
              }
              ret.csort = {
                order = 0.43,
                cmdHidden = true,
                fontSize = "medium",
                name = "  "..L["Sort Order"],
                type = "description",
                width = "half",
              }

              for server, stoons in pairs(toons) do
                ret[server] = {
                  order = (server == GetRealmName() and 0.5 or 100),
                  type = "group",
                  name = server,
                  guiInline = false,
                  --childGroups = "tree",
                  args = (function()
                    local tret = {}
                    sort(stoons)
                    for ord, tn in pairs(stoons) do
                      local toon = tn.." - "..server
                      local t = SI.db.Toons[toon]
                      local tinfo = ""
                      if t and t.Level and t.LClass then
                        tinfo = tinfo.."\n"..LEVEL.." "..t.Level.." "..t.LClass
                      end
                      if t and t.LastSeen then
                        tinfo = tinfo.."\n"..L["Last updated"]..": "..date("%c",t.LastSeen)
                      end
                      tret[tn.."_desc"] = {
                        order = function(info) return t.Order*1000 + ord*10 + 0 end,
                        name = SI:ClassColorToon(toon),
                        desc = tn, -- unfortunately does nothing in dialog
                        descStyle = "tooltip",
                        type = "description",
                        width = "half",
                        cmdHidden = true,
                      }
                      tret[tn] = {
                        order = function(info) return t.Order*1000 + ord*10 + 1 end,
                        name = "",
                        type = "select",
                        width = "normal",
                        values = valuesList,
                        arg = t,
                        get = toonget("Show", "saved"),
                        set = toonset("Show"),
                      }
                      tret[tn.."_order"] = {
                        order = function(info) return t.Order*1000 + ord*10 + 4 end,
                        name = "",
                        type = "input",
                        width = "half",
                        desc = L["Sort Order"],
                        --descStyle = "tooltip",
                        arg = t,
                        get = toonget("Order", 50),
                        set = toonset("Order", true),
                        validate = orderval,
                      --pattern = "^%s*[0-9]?[0-9]?[0-9]%s*$",
                      --usage = L["Order must be a number in [0 - 999]"],
                      }
                      tret[tn.."_sp1"] = {
                        order = function(info) return t.Order*1000 + ord*10 + 6 end,
                        name = " ",
                        type = "description",
                        width = "half",
                        cmdHidden = true,
                      }
                      tret[tn.."_delete"] = {
                        order = function(info) return t.Order*1000 + ord*10 + 7 end,
                        name = DELETE,
                        desc = DELETE.." "..toon..tinfo,
                        type = "execute",
                        width = "half",
                        arg = { toon, tinfo },
                        func = deltoon,
                      }
                      tret[tn.."_nl"] = {
                        order = function(info) return t.Order*1000 + ord*10 + 9 end,
                        name = "",
                        type = "description",
                        width = "full",
                        cmdHidden = true,
                      }
                    end
                    return tret
                  end)(),
                }
              end
              return ret
            end)()
          },
        },
      },
      Progress = Progress:BuildOptions(2),
    },
  }
  -- Insert built options into the "cache"
  -- (im not sure what the point of this is, it was in the original code but i see no purpose for it)
  for k,v in pairs(options) do
    savedOptions[k] = v
  end

  if SI.isRetail then
    ---@diagnostic disable-next-line: undefined-field
    local warfront = Warfront:BuildOptions(34)
    for k, v in pairs(warfront) do
      savedOptions.args.General.args[k] = v
    end
    for expansion, _ in pairs(SI.Emissaries) do
      savedOptions.args.General.args["Emissary" .. expansion] = {
        type = "toggle",
        order = 37 + expansion * 0.1,
        name = _G["EXPANSION_NAME" .. expansion],
      }
    end  
  end
  
  local headerOffset = savedOptions.args.Currency.args.CurrencyHeader.order
  for idx, currencyID in ipairs(SI.validCurrencies) do 
    local name
    local icon ---@type string|number?
    if SI.isClassicEra then
      icon = GetItemIcon(currencyID)
      name = GetItemInfo(currencyID) or ("Item: "..currencyID)
      SI:Debug("Currency: %s, %s", name or "nil", icon or 'nil')
    else
      local data = C_CurrencyInfo_GetCurrencyInfo(currencyID)
      name = Currency.OverrideName[currencyID] or data.name
      icon = Currency.OverrideTexture[currencyID] or data.iconFileID
    end

    if name and icon then
      icon = "\124T"..icon..":0\124t "
      savedOptions.args.Currency.args["Currency"..currencyID] = {
        type = "toggle",
        order = headerOffset+idx,
        name = icon..name,
      }
    end
  end
  return savedOptions
end

-- global functions
-----------------------------------------------------------------------
-- Setup settings panel and util functions
---@type string?, string|number?
local addonSettingsCategoryID, characterSettingsElementID
function Config:RegisterAddonSettingsPanel()
  local namespace = ADDON_NAME
  local addonOptions = Config:BuildAceConfigOptions()
  
  ---@type AceConfig-3.0
  local AceConfig = LibStub("AceConfig-3.0")
  AceConfig:RegisterOptionsTable(namespace, addonOptions, { "si", "savedinstances" })

  ---@type AceConfigDialog-3.0
  local AceDialog = LibStub("AceConfigDialog-3.0")
  
  local _ = nil;
  _, addonSettingsCategoryID = AceDialog:AddToBlizOptions(namespace, nil, nil, "General")
  AceDialog:AddToBlizOptions(namespace, L["Quest progresses"], namespace, "Progress")
  AceDialog:AddToBlizOptions(namespace, CURRENCY, namespace, "Currency")
  AceDialog:AddToBlizOptions(namespace, L["Indicators"], namespace, "Indicators")
  AceDialog:AddToBlizOptions(namespace, L["Instances"], namespace, "Instances")
  _, charactersFrameElementID = AceDialog
          :AddToBlizOptions(namespace, L["Characters"], namespace, "Characters")
end
function Config:ReopenConfigDisplay(frame)
  assert(addonSettingsCategoryID, 
    "Config:ReopenConfigDisplay: `addonSettingsCategoryID` is `nil`. Addon settings not registered?"
  )
  if _G.SettingsPanel:IsShown() then
    HideUIPanel(_G.SettingsPanel)
    Settings_OpenToCategory(addonSettingsCategoryID)
    -- Settings.OpenToCategory(frame)
    -- Not possible due to lack of WoW feature
  end
end

function Config:ShowConfig()
  assert(addonSettingsCategoryID, 
    "Config:ShowConfig: `addonSettingsCategoryID` is `nil`. Addon settings not registered?"
  )
  if _G.SettingsPanel:IsShown() then
    HideUIPanel(_G.SettingsPanel)
  else
    Settings_OpenToCategory(addonSettingsCategoryID)
  end
end


local function ResetConfirmed()
  SI:Debug("Resetting characters")
  Tooltip:HideDetached()
  -- clear saves
  for instance, i in pairs(SI.db.Instances) do
    for toon, t in pairs(SI.db.Toons) do
      i[toon] = nil
    end
  end
  wipe(SI.db.Toons) -- clear toon db
  SI.PlayedTime = nil -- reset played cache
  SI:toonInit() -- rebuild SI.thisToon
  SI:Refresh()
  Config:BuildAceConfigOptions() -- refresh config table
  Config:ReopenConfigDisplay(characterSettingsElementID)
end

local function DeleteCharacter(toon)
  if toon == SI.thisToon or not SI.db.Toons[toon] then
    SI:ChatMsg("ERROR: Failed to delete " .. toon .. ". Character is active or does not exist.")
    return
  end
  SI:Debug("Deleting character: " .. toon)
  Tooltip:HideDetached()
  -- clear saves
  for instance, i in pairs(SI.db.Instances) do
    i[toon] = nil
  end
  SI.db.Toons[toon] = nil
  Config:BuildAceConfigOptions() -- refresh config table
  Config:ReopenConfigDisplay(characterSettingsElementID)
end

StaticPopupDialogs["SAVEDINSTANCES_RESET"] = {
  preferredIndex = STATICPOPUP_NUMDIALOGS, -- reduce the chance of UI taint
  text = L["Are you sure you want to reset the SavedInstances character database? Characters will be re-populated as you log into them."],
  button1 = OKAY,
  button2 = CANCEL,
  OnAccept = ResetConfirmed,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  enterClicksFirstButton = false,
  showAlert = true,
}

StaticPopupDialogs["SAVEDINSTANCES_DELETE_CHARACTER"] = {
  preferredIndex = STATICPOPUP_NUMDIALOGS, -- reduce the chance of UI taint
  text = string.format(L["Are you sure you want to remove %s from the SavedInstances character database?"],"\n\n%s%s\n\n").."\n\n"..
  L["This should only be used for characters who have been renamed or deleted, as characters will be re-populated when you log into them."],
  button1 = OKAY,
  button2 = CANCEL,
  OnAccept = function(self, data) DeleteCharacter(data) end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  enterClicksFirstButton = false,
  showAlert = true,
}
