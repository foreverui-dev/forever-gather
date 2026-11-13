-- Forever Harvest: Radar – kleines Fenster mit den nächsten Fundorten, Pfeil, Entfernung und Uhrzeit-Richtung.
local _, FG = ...
local Ra = FG:Modul("Radar")
local F, P = FG.Fundorte, FG.Position
local L = FG.L

local rahmen, zeilen = nil, {}

function Ra:Liste(anzahl)
  local karte, px, py = P:Spieler()
  if not karte or not P:Groesse(karte) then return {}, karte end
  local liste = {}
  for _, f in ipairs(F:Liste(karte)) do
    if F:FundSichtbar(f) then
      local o, s = P:Versatz(karte, px, py, f.x, f.y)
      liste[#liste + 1] = { f = f, o = o, s = s, m = math.sqrt(o * o + s * s), leer = F:Abgeerntet(f) }
    end
  end
  table.sort(liste, function(a, b)
    if (a.leer and true or false) ~= (b.leer and true or false) then return not a.leer end
    return a.m < b.m
  end)
  for i = #liste, (anzahl or 5) + 1, -1 do liste[i] = nil end
  return liste, karte
end

local function Bauen()
  rahmen = CreateFrame("Frame", "ForeverGatherRadar", UIParent)
  rahmen:SetSize(230, 24 + 20 * 8)
  rahmen:SetMovable(true)
  rahmen:EnableMouse(true)
  rahmen:SetClampedToScreen(true)
  rahmen:RegisterForDrag("LeftButton")
  rahmen:SetScript("OnDragStart", rahmen.StartMoving)
  rahmen:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    FG.db.radarPos = { p, rp, x, y }
  end)
  rahmen.hg = rahmen:CreateTexture(nil, "BACKGROUND")
  rahmen.hg:SetAllPoints()
  rahmen.leiste = rahmen:CreateTexture(nil, "BORDER")
  rahmen.leiste:SetPoint("TOPLEFT"); rahmen.leiste:SetPoint("TOPRIGHT"); rahmen.leiste:SetHeight(18)
  rahmen.leiste:SetColorTexture(0.10, 0.10, 0.12, 0.85)
  rahmen.titel = rahmen:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  rahmen.titel:SetPoint("TOPLEFT", 6, -5)
  rahmen.titel:SetText(L"Radar")
  for i = 1, 8 do
    local z = CreateFrame("Button", nil, rahmen)
    z:SetSize(220, 20)
    z:SetPoint("TOPLEFT", 4, -20 - (i - 1) * 20)
    z.pfeil = z:CreateTexture(nil, "ARTWORK")
    z.pfeil:SetSize(16, 16)
    z.pfeil:SetPoint("LEFT", 0, 0)
    z.pfeil:SetTexture("Interface\\Minimap\\MinimapArrow")
    z.icon = z:CreateTexture(nil, "ARTWORK")
    z.icon:SetSize(16, 16)
    z.icon:SetPoint("LEFT", 20, 0)
    z.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    z.name = z:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    z.name:SetPoint("LEFT", 40, 0)
    z.name:SetWidth(110)
    z.name:SetJustifyH("LEFT")
    z.weite = z:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    z.weite:SetPoint("RIGHT", -2, 0)
    z.weite:SetJustifyH("RIGHT")
    z:RegisterForClicks("LeftButtonUp")
    z:SetScript("OnClick", function(self)
      if self.eintrag then FG.Weltkarte:FundKlick(self.karte, self.eintrag.f, "LeftButton") end
    end)
    zeilen[i] = z
  end
  local p = FG.db.radarPos
  if p then rahmen:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else rahmen:SetPoint("RIGHT", -220, 80) end
  local zeit = 0
  rahmen:SetScript("OnUpdate", function(_, dt)
    zeit = zeit + (dt or 0)
    if zeit < 0.2 then return end
    zeit = 0
    FG:Sicher("Radar", Ra.Auffrischen, Ra)
  end)
  Ra.rahmen = rahmen
end

function Ra:Auffrischen()
  if not rahmen then return end
  local kampf = FG.db.kampfAusblenden and UnitAffectingCombat and UnitAffectingCombat("player")
  rahmen:SetAlpha(kampf and 0.3 or 1)
  rahmen:SetScale(FG:Groesse())
  rahmen.hg:SetColorTexture(0.06, 0.06, 0.08, FG:Deckkraft(0.7))
  local a = FG.farben.akzent
  rahmen.titel:SetTextColor(a[1], a[2], a[3])
  local anzahl = math.min(8, FG.db.radarZeilen or 5)
  local liste, karte = self:Liste(anzahl)
  rahmen:SetHeight(26 + 20 * math.max(1, #liste))
  for i, z in ipairs(zeilen) do
    local e = liste[i]
    z.eintrag, z.karte = e, karte
    if e and i <= anzahl then
      z.icon:SetTexture(F:Symbol(e.f.t))
      z.name:SetText(F:Name(e.f.t))
      local uhr = P:Uhr(e.o, e.s)
      z.weite:SetText(L"%s · %d Uhr":format(P:MeterText(e.m), uhr) .. (e.leer and (" · " .. L"leer") or ""))
      if z.pfeil.SetRotation then z.pfeil:SetRotation(-P:Winkel(e.o, e.s)) end
      z:SetAlpha(e.leer and 0.45 or 1)
      z:Show()
    else
      z:Hide()
    end
  end
  if #liste == 0 then
    zeilen[1].eintrag = nil
    zeilen[1].icon:SetTexture(nil)
    zeilen[1].name:SetText(L"Keine Fundorte in dieser Gegend")
    zeilen[1].weite:SetText("")
    zeilen[1]:Show()
  end
  self.liste = liste
end

function Ra:Anwenden()
  if FG.db.radar then
    if not rahmen then Bauen() end
    rahmen:Show()
    self:Auffrischen()
  elseif rahmen then
    rahmen:Hide()
  end
end

function Ra:Umschalten()
  FG.db.radar = not FG.db.radar
  self:Anwenden()
  FG:Sprechen(L"Radar" .. ": " .. (FG.db.radar and L"an" or L"aus"))
end

FG:Befehl({ "radar" }, function() Ra:Umschalten() end, L"/fg radar – Radar mit den nächsten Fundorten")
FG.tasten.radar = function() Ra:Umschalten() end
