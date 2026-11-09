-- Forever Harvest: Knopf am Rand der Minikarte.
local _, FG = ...
local MK = FG:Modul("MinimapKnopf")
local L = FG.L
local knopf

local function Platzieren()
  local w = math.rad(FG.db.minimapWinkel or 200)
  local r = (Minimap:GetWidth() / 2) + 6
  knopf:ClearAllPoints()
  knopf:SetPoint("CENTER", Minimap, "CENTER", math.cos(w) * r, math.sin(w) * r)
end

function MK:Anwenden()
  if not knopf then return end
  knopf:SetShown(FG.db.minimapKnopf)
  Platzieren()
end

function MK:Start()
  if not Minimap then return end
  knopf = CreateFrame("Button", "ForeverGatherMinimapKnopf", Minimap)
  knopf:SetSize(31, 31)
  knopf:SetFrameStrata("MEDIUM")
  knopf:SetFrameLevel(8)
  knopf:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
  knopf:RegisterForDrag("LeftButton")
  local icon = knopf:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Flower_02")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local rand = knopf:CreateTexture(nil, "OVERLAY")
  rand:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  rand:SetSize(53, 53)
  rand:SetPoint("TOPLEFT")
  knopf:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  knopf:SetScript("OnClick", function(_, taste)
    if taste == "RightButton" then
      FG.Fenster:Oeffnen("einstellungen")
    elseif taste == "MiddleButton" then
      FG.befehle.naechster("")
    elseif IsShiftKeyDown() then
      FG.befehle.zeigen("")
    else
      FG.Fenster:Umschalten()
    end
  end)
  knopf:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      FG.db.minimapWinkel = math.deg(math.atan2 and math.atan2(cy / s - my, cx / s - mx) or atan2(cy / s - my, cx / s - mx))
      Platzieren()
    end)
  end)
  knopf:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  knopf:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Forever Harvest", unpack(FG.farben.gold))
    GameTooltip:AddLine(L"Klick: Fenster öffnen oder schließen", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L"Umschalt+Klick: Fundorte ein oder aus", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L"Mittelklick: Wegpunkt zum nächsten Fundort", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L"Rechtsklick: Einstellungen", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L"Ziehen: Knopf verschieben", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  knopf:SetScript("OnLeave", function() GameTooltip:Hide() end)
  MK:Anwenden()
end
