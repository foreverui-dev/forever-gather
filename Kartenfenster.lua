-- Forever Harvest: Kartenfenster – kleine, verschiebbare Karte der Gegend mit deiner Position,
-- den Fundorten und der laufenden Route. Norden ist immer oben, das Mausrad zoomt.
-- Liefert das Spiel kein Kartenbild, zeigt das Fenster dieselbe Ansicht ohne Bild (wie ein Radar).
local _, FG = ...
local Kf = FG:Modul("Kartenfenster")
local F, P = FG.Fundorte, FG.Position
local L = FG.L

local rahmen, flaeche
local kacheln, pins, linien = {}, {}, {}
local kachelKarte                       -- Karte, deren Bild gerade geladen ist
local MIN_ZOOM, MAX_ZOOM = 60, 2000     -- halbe Breite der Ansicht in Metern

-- Kacheln des Kartenbilds: { datei, u0, v0, u1, v1 } in Kartenkoordinaten (0..1).
function Kf:Kacheln(karte)
  if not (C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures) then return {} end
  local ok, ebenen = pcall(C_Map.GetMapArtLayers, karte)
  local e = ok and type(ebenen) == "table" and ebenen[1]
  if not e or not e.layerWidth or not e.tileWidth or e.layerWidth <= 0 or e.tileWidth <= 0 then return {} end
  local ok2, dateien = pcall(C_Map.GetMapArtLayerTextures, karte, 1)
  if not ok2 or type(dateien) ~= "table" or #dateien == 0 then return {} end
  local spalten = math.ceil(e.layerWidth / e.tileWidth)
  local liste = {}
  for i, datei in ipairs(dateien) do
    local sp, ze = (i - 1) % spalten, math.floor((i - 1) / spalten)
    local u0, v0 = sp * e.tileWidth / e.layerWidth, ze * e.tileHeight / e.layerHeight
    local u1, v1 = (sp + 1) * e.tileWidth / e.layerWidth, (ze + 1) * e.tileHeight / e.layerHeight
    liste[#liste + 1] = { datei, u0, v0, u1, v1 }
  end
  return liste
end

-- Bildschirmpunkt (relativ zur Mitte, y nach unten) für Kartenkoordinaten.
function Kf:Punkt(karte, px, py, x, y, groesse)
  local b, h = P:Groesse(karte)
  if not b then return end
  local k = groesse / (2 * (FG.db.kartenfensterZoom or 250))   -- Bildpunkte je Meter
  return (x - px) * b * k, (y - py) * h * k, k
end

function Kf:Zoomen(richtung)
  local z = FG.db.kartenfensterZoom or 250
  z = richtung > 0 and z / 1.25 or z * 1.25
  FG.db.kartenfensterZoom = math.max(MIN_ZOOM, math.min(MAX_ZOOM, math.floor(z + 0.5)))
  self:Auffrischen()
end

local function Bauen()
  rahmen = CreateFrame("Frame", "ForeverGatherKartenfenster", UIParent)
  rahmen:SetMovable(true)
  rahmen:EnableMouse(true)
  rahmen:SetClampedToScreen(true)
  rahmen:RegisterForDrag("LeftButton")
  rahmen:SetScript("OnDragStart", rahmen.StartMoving)
  rahmen:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    FG.db.kartenfensterPos = { p, rp, x, y }
  end)
  if rahmen.EnableMouseWheel then rahmen:EnableMouseWheel(true) end
  rahmen:SetScript("OnMouseWheel", function(_, d) Kf:Zoomen(d) end)

  rahmen.rand = rahmen:CreateTexture(nil, "BACKGROUND")
  rahmen.rand:SetAllPoints()
  flaeche = CreateFrame("Frame", nil, rahmen)
  flaeche:SetPoint("TOPLEFT", 2, -2)
  flaeche:SetPoint("BOTTOMRIGHT", -2, 18)
  if flaeche.SetClipsChildren then flaeche:SetClipsChildren(true) end
  flaeche.hg = flaeche:CreateTexture(nil, "BACKGROUND", nil, -8)
  flaeche.hg:SetAllPoints()

  rahmen.pfeil = flaeche:CreateTexture(nil, "OVERLAY", nil, 7)
  rahmen.pfeil:SetSize(22, 22)
  rahmen.pfeil:SetPoint("CENTER")
  rahmen.pfeil:SetTexture("Interface\\Minimap\\MinimapArrow")

  rahmen.name = rahmen:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  rahmen.name:SetPoint("BOTTOMLEFT", 5, 3)
  rahmen.name:SetPoint("BOTTOMRIGHT", -40, 3)
  rahmen.name:SetJustifyH("LEFT")
  rahmen.zoom = rahmen:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  rahmen.zoom:SetPoint("BOTTOMRIGHT", -18, 3)

  local zu = CreateFrame("Button", nil, rahmen)
  zu:SetSize(14, 14)
  zu:SetPoint("BOTTOMRIGHT", -2, 2)
  zu.t = zu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  zu.t:SetPoint("CENTER")
  zu.t:SetText("x")
  zu:SetScript("OnClick", function() Kf:Umschalten() end)
  zu:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L"Kartenfenster schließen")
    GameTooltip:Show()
  end)
  zu:SetScript("OnLeave", function() GameTooltip:Hide() end)

  rahmen:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L"Kartenfenster")
    GameTooltip:AddLine(L"Mausrad: zoomen · Ziehen: verschieben", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L"Klick auf einen Fundort: Wegpunkt", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  rahmen:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local p = FG.db.kartenfensterPos
  if p then rahmen:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else rahmen:SetPoint("TOPRIGHT", -200, -220) end
  local zeit = 0
  rahmen:SetScript("OnUpdate", function(_, dt)
    zeit = zeit + (dt or 0)
    if zeit < 0.1 then return end
    zeit = 0
    FG:Sicher("Kartenfenster", Kf.Auffrischen, Kf)
  end)
  Kf.rahmen = rahmen
end

local function KachelnLaden(karte)
  for _, t in ipairs(kacheln) do t:Hide() end
  kachelKarte = karte
  Kf.kachelDaten = karte and Kf:Kacheln(karte) or {}
  for i, d in ipairs(Kf.kachelDaten) do
    local t = kacheln[i]
    if not t then t = flaeche:CreateTexture(nil, "BACKGROUND", nil, -7); kacheln[i] = t end
    t:SetTexture(d[1])
  end
end

local function Linie(i)
  local ln = linien[i]
  if not ln and flaeche.CreateLine then ln = flaeche:CreateLine(nil, "ARTWORK"); linien[i] = ln end
  return ln
end

function Kf:Auffrischen()
  if not rahmen or not rahmen:IsShown() then return end
  local groesse = (FG.db.kartenfensterGroesse or 200)
  rahmen:SetSize(groesse + 4, groesse + 20)
  rahmen:SetScale(FG:Groesse())
  local kampf = FG.db.kampfAusblenden and UnitAffectingCombat and UnitAffectingCombat("player")
  rahmen:SetAlpha(kampf and 0.3 or 1)
  local k = FG.db.kontrast and 1 or 0.8
  rahmen.rand:SetColorTexture(0.3 * k, 0.25 * k, 0.1 * k, 1)
  flaeche.hg:SetColorTexture(0.06, 0.06, 0.08, FG:Deckkraft(0.85))
  rahmen.zoom:SetText(P:MeterText(2 * (FG.db.kartenfensterZoom or 250)))

  local karte, px, py = P:Spieler()
  if karte ~= kachelKarte then KachelnLaden(karte) end
  local blick = FG.Frei(GetPlayerFacing and GetPlayerFacing())
  rahmen.pfeil:SetShown(karte ~= nil)
  if blick and rahmen.pfeil.SetRotation then rahmen.pfeil:SetRotation(blick) end

  if not karte or not P:Groesse(karte) then
    rahmen.name:SetText(L"Keine Karte hier")
    for _, t in ipairs(kacheln) do t:Hide() end
    for _, p in ipairs(pins) do p:Hide() end
    for _, ln in ipairs(linien) do ln:Hide() end
    return
  end
  rahmen.name:SetText(P:KartenName(karte))

  -- Kartenbild
  local halb = groesse / 2
  for i, d in ipairs(self.kachelDaten or {}) do
    local t = kacheln[i]
    local x0, y0 = self:Punkt(karte, px, py, d[2], d[3], groesse)
    local x1, y1 = self:Punkt(karte, px, py, d[4], d[5], groesse)
    if x1 < -halb or x0 > halb or y1 < -halb or y0 > halb then
      t:Hide()
    else
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", flaeche, "CENTER", x0, -y0)
      t:SetSize(x1 - x0, y1 - y0)
      t:Show()
    end
  end

  -- Fundorte
  local n = 0
  local pinGroesse = math.max(10, (FG.db.pinGroesse or 16) - 2)
  for _, f in ipairs(F:Liste(karte)) do
    if F:FundSichtbar(f) then
      local x, y = self:Punkt(karte, px, py, f.x, f.y, groesse)
      if x and math.abs(x) <= halb + 8 and math.abs(y) <= halb + 8 then
        n = n + 1
        local p = FG.Weltkarte.NeuerPin(flaeche, n, pins)
        FG.Weltkarte:PinGestalten(p, f, pinGroesse)
        p:ClearAllPoints()
        p:SetPoint("CENTER", flaeche, "CENTER", x, -y)
        p:SetScript("OnEnter", function(self) FG.Weltkarte:FundTooltip(self, karte, f) end)
        p:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p:SetScript("OnClick", function(_, taste) FG.Weltkarte:FundKlick(karte, f, taste) end)
        p:Show()
      end
    end
  end
  for i = n + 1, #pins do pins[i]:Hide() end
  self.anzahl = n

  -- Routen
  local nl = 0
  if FG.Routen and FG.db.routeLinien then
    for _, r in ipairs(FG.Routen:AufKarte(karte)) do
      local aktiv = FG.Routen.aktiv == r
      local c = aktiv and FG.farben.gold or { 0.85, 0.85, 0.85 }
      local pk, anz = r.punkte, #r.punkte / 2
      for i = 1, anz do
        local j = (i % anz) + 1
        if anz > 1 and (j ~= 1 or r.rund ~= false) then
          local ln = Linie(nl + 1)
          if not ln then break end
          nl = nl + 1
          local x0, y0 = self:Punkt(karte, px, py, pk[i * 2 - 1], pk[i * 2], groesse)
          local x1, y1 = self:Punkt(karte, px, py, pk[j * 2 - 1], pk[j * 2], groesse)
          ln:SetThickness(aktiv and 3 or 2)
          ln:SetColorTexture(c[1], c[2], c[3], aktiv and 0.95 or 0.6)
          ln:SetStartPoint("CENTER", flaeche, x0, -y0)
          ln:SetEndPoint("CENTER", flaeche, x1, -y1)
          ln:Show()
        end
      end
    end
  end
  for i = nl + 1, #linien do linien[i]:Hide() end
  self.linien = nl
end

function Kf:Anwenden()
  if FG.db.kartenfenster then
    if not rahmen then Bauen() end
    rahmen:Show()
    self:Auffrischen()
  elseif rahmen then
    rahmen:Hide()
  end
end

function Kf:Umschalten()
  FG.db.kartenfenster = not FG.db.kartenfenster
  self:Anwenden()
  FG:Sprechen(L"Kartenfenster" .. ": " .. (FG.db.kartenfenster and L"an" or L"aus"))
end

FG:Befehl({ "kartenfenster", "karte", "map" }, function(rest)
  local z = tonumber(rest)
  if z then
    FG.db.kartenfenster = true
    FG.db.kartenfensterGroesse = math.max(120, math.min(400, z))
    Kf:Anwenden()
    return
  end
  Kf:Umschalten()
end, L"/fg karte [Größe] – Kartenfenster mit Fundorten und Route")
FG.tasten.kartenfenster = function() Kf:Umschalten() end
