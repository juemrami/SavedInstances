---@type SavedInstances
local SI, L = unpack(select(2, ...))
---@class TooltipModule : AceModule , AceEvent-3.0
local Module = SI:NewModule('Tooltip', 'AceEvent-3.0')
local QTip = SI.Libs.QTip

local tooltip
local indicatorTip
local detachframe

local function clearTooltip()
  if tooltip then
    tooltip.elapsed = nil
    tooltip.anchorframe = nil
  end
  tooltip = nil
end

local function clearIndicatorTip()
  indicatorTip = nil
end

--- Setup tooltip default fonts. Might be useful to add an option for this on the settings ui.
local basePath, baseSize = GameTooltipHeaderText:GetFont()
baseSize = baseSize * 0.9 -- slightly smaller than default

local headerFont = CreateFont('SavedInstancesHeaderFont')
headerFont:SetFont(basePath, baseSize, "OUTLINE, THICK, MONO");

local cellFont = CreateFont('SavedInstancesCellFont')
cellFont:SetFont(basePath, (baseSize * 0.85) , "");
cellFont:SetShadowOffset(2.5, -1);
cellFont:SetShadowColor(0.1, 0.1, 0.1, .65);
--- outline looks better but can change the alpha on it

---@return QTip tooltip
function Module:AcquireTooltip()
  if tooltip then
    QTip:Release(tooltip)
  end

  tooltip = QTip:Acquire('SavedInstancesTooltip', 1, 'LEFT')
  tooltip:SetFont(cellFont)
  tooltip:SetHeaderFont(headerFont)
  tooltip.OnRelease = clearTooltip -- extra-safety: update our variable on auto-release
  return tooltip
end


---@param ... any args to pass to QTip:Acquire
---@return QTip tooltip
function Module:AcquireIndicatorTip(...)
  ---@class QTip : LibQTip.Tooltip
  indicatorTip = QTip:Acquire('SavedInstancesIndicatorTooltip', ...)
  -- This is not the best place to instantiate this method. It should be moved out of the AquiereIndicatorTip method.
  indicatorTip.AddQuestDescription = indicatorTip.AddQuestDescription
    or function(questLink)
      SI.ScanTooltip:SetHyperlink(questLink)
      local getLineProps = function(lineName) 
        local fontString = _G[SI.ScanTooltip:GetName()..lineName] ---@type FontString?
        if fontString then
          assert(
            fontString.GetText, 
            "Object does not have a `GetText` method. Failed parsing tooltip for quest"
          )
          return fontString:GetText(), fontString:GetFontObject(), fontString:GetTextColor()
        end 
      end
      -- Get Quest Description from Tooltip
      for lineIdx = 1, SI.ScanTooltip:NumLines() do
        local text = getLineProps("TextLeft"..lineIdx)
        if text and text:gsub("%s", "") == "" then
          -- quest description (always?) comes after first line break
          local text, font, colorR, colorG, colorB = getLineProps("TextLeft"..(lineIdx + 1))
          local line = indicatorTip:AddLine()
          indicatorTip:SetCell(line, 1, text, font , nil, nil, nil, nil, nil, 300)
          indicatorTip:SetLineTextColor(line, colorR, colorG, colorB)
          break
        end
      end
      -- make sure to hide the Helper tooltip after we're done with it
      SI.ScanTooltip:Hide()
    end
  indicatorTip.anchorframe = nil
  indicatorTip:Clear()
  indicatorTip:SetHeaderFont(headerFont)
  indicatorTip:SetScale(SI.db.Tooltip.Scale)
  indicatorTip.OnRelease = clearIndicatorTip -- extra-safety: update our variable on auto-release

  if tooltip then
    indicatorTip:SetAutoHideDelay(0.1, tooltip)
    indicatorTip:SmartAnchorTo(tooltip)
  end
  indicatorTip:SetFrameLevel(150) -- ensure visibility when forced to overlap main tooltip

  SI:SkinFrame(indicatorTip, 'SavedInstancesIndicatorTooltip')

  return indicatorTip
end

function Module:ReleaseTooltip()
  if tooltip then
    QTip:Release(tooltip)
    tooltip = nil
  end
end

---@return boolean?
function Module:IsTooltipShown()
  return tooltip and tooltip:IsShown()
end

function Module.CloseIndicatorTip()
  _G.GameTooltip:Hide()
  if indicatorTip then
    indicatorTip:Hide()
  end
end

---@return boolean?
function Module:IsDetached()
  return detachframe and detachframe:IsShown()
end

function Module:HideDetached()
  if detachframe then
    detachframe:Hide()
  end
end

function Module:ToggleDetached()
  if Module:IsDetached() then
    Module:HideDetached()
  else
    Module:ShowDetached()
  end
end

function Module:ShowDetached()
  if not detachframe then
    ---@class SavedInstances.DetachedTooltip: Frame, BackdropTemplate
    local frame = CreateFrame('Frame', 'SavedInstancesDetachHeader', UIParent, 'BasicFrameTemplate, BackdropTemplate')
    frame:SetMovable(true)
    frame:SetFrameStrata('TOOLTIP')
    frame:SetFrameLevel(100) -- prevent weird interlacings with other tooltips
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetUserPlaced(true)
    frame:SetAlpha(0.5)
    if SI.db.Tooltip.posx and SI.db.Tooltip.posy then
      frame:SetPoint('TOPLEFT', SI.db.Tooltip.posx, -SI.db.Tooltip.posy)
    else
      frame:SetPoint('CENTER')
    end
    frame:SetScript('OnMouseDown', function(self)
      self:StartMoving()
    end)
    frame:SetScript('OnMouseUp', function(self)
      self:StopMovingOrSizing()

      ---@diagnostic disable-next-line: inject-field
      SI.db.Tooltip.posx = self:GetLeft()

      ---@diagnostic disable-next-line: inject-field
      SI.db.Tooltip.posy = UIParent:GetTop() - (self:GetTop() * self:GetScale())
    end)
    frame:SetScript('OnHide', Module.ReleaseTooltip)
    frame:SetScript('OnUpdate', function(self)
      if not tooltip then
        self:Hide()
        return
      end
      local w,h = tooltip:GetSize()
	    self:SetSize(
        w * tooltip:GetEffectiveScale() / UIParent:GetEffectiveScale(),
        h * tooltip:GetEffectiveScale() / UIParent:GetEffectiveScale() + 20
      )
    end)
    frame:SetScript('OnKeyDown', function(self, key)
      if key == 'ESCAPE' then
        self:SetPropagateKeyboardInput(false)
        self:Hide()
      end
    end)
    frame:EnableKeyboard(true)
    SI:SkinFrame(frame, 'SavedInstancesDetachHeader')
    detachframe = frame
  end

  if tooltip then
    tooltip:Hide()
  end

  detachframe:Show()
  detachframe:SetPropagateKeyboardInput(true)
  SI:ShowTooltip(detachframe)
end

function Module:GetDetachedFrame()
  return detachframe
end
