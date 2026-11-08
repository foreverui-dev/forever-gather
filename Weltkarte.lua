-- Forever Gather: Fundorte und Routen auf der großen Weltkarte.
local _, FG = ...
local W = FG:Modul("Weltkarte")
local F, P = FG.Fundorte, FG.Position
local L = FG.L

local leinwand, waechter
local pins, linien, punkte = {}, {}, {}
local gezeigt = { karte = nil, skala = nil, stand = 0 }
local stand = 0

local function Leinwand()
  if leinwand then return leinwand end
  if not WorldMapFrame then return end
  leinwand = (WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas())
    or (WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
  return leinwand
end

local function Skala()
  local sc = WorldMapFrame and WorldMapFrame.ScrollContainer
  if sc and sc.GetCanvasScale then
    local ok, s = pcall(sc.GetCanvasScale, sc)
    if ok and s and s > 0 then return s end
  end
  return (leinwand and leinwand:GetScale()) or 1
end

local function KarteJetzt()
  return WorldMapFrame and WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
end

---------------------------------------------------------------------------
-- Tooltip eines Fundorts (auch von der Minikarte genutzt)
---------------------------------------------------------------------------
function W:FundTooltip(besitzer, karte, f)
  GameTooltip:SetOwner(besitzer, "ANCHOR_RIGHT")
  local art = F:Art(f.t)
  local c = FG:ArtFarbe(art)
  GameTooltip:AddLine(F:Name(f.t), c[1], c[2], c[3])
  local stufe, hat = F:Stufe(f.t), F:Fertigkeit(art)
  local artName = ({ kraut = L"Kraut", erz = L"Erz", schatz = L"Schatz" })[art]
  if stufe and art ~= "schatz" then
    local g, r = FG.farben.gruen, FG.farben.rot
    if hat and hat >= stufe then
      GameTooltip:AddLine(L"%s · Fertigkeit %d · du: %d (abbaubar)":format(artName, stufe, hat), g[1], g[2], g[3])
    elseif hat then
      GameTooltip:AddLine(L"%s · Fertigkeit %d · du: %d (zu niedrig)":format(artName, stufe, hat), r[1], r[2], r[3])
    else
      GameTooltip:AddLine(L"%s · Fertigkeit %d · Beruf fehlt":format(artName, stufe), r[1], r[2], r[3])
    end
  else
    GameTooltip:AddLine(artName, 0.8, 0.8, 0.8)
  end
  if f.n and f.n > 0 then GameTooltip:AddLine(L"%d-mal gesammelt, zuletzt %s":format(f.n, FG:AlterText(f.z)), 0.8, 0.8, 0.8) end
  if f.q then GameTooltip:AddLine(L"Geteilt von %s":format(f.q), 0.6, 0.75, 1) end
  local pk, px, py = P:Spieler()
  if pk == karte then
    local m = P:Entfernung(karte, px, py, f.x, f.y)
    if m then GameTooltip:AddLine(L"Entfernung: %s":format(P:MeterText(m)), 0.8, 0.8, 0.8) end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(L"Klick: Wegpunkt setzen", 0.6, 0.6, 0.6)
  GameTooltip:AddLine(L"Rechtsklick: Fundort löschen", 0.6, 0.6, 0.6)
  GameTooltip:AddLine(L"Umschalt+Rechtsklick: diese Sorte ausblenden", 0.6, 0.6, 0.6)
  GameTooltip:Show()
end

function W:FundKlick(karte, f, taste)
  if taste == "RightButton" then
    if IsShiftKeyDown() then
      FG.db.ausgeblendet[f.t] = true
      FG:Ansage(L"%s ausgeblendet. Im Fenster unter „Karte“ wieder einblenden.", F:Name(f.t))
      FG:Anwenden()
    else
      W.loeschen = { karte = karte, f = f }
      if StaticPopup_Show then StaticPopup_Show("FOREVERGATHER_LOESCHEN", F:Name(f.t)) end
    end
  else
    P:Wegpunkt(karte, f.x, f.y, F:Name(f.t))
    FG:Sprechen(L"Wegpunkt gesetzt: %s":format(F:Name(f.t)))
  end
end

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs.FOREVERGATHER_LOESCHEN = {
  text = L"Fundort „%s“ löschen?",
  button1 = L"Löschen",
  button2 = L"Abbrechen",
  OnAccept = function()
    local l = W.loeschen
    if l then F:Entfernen(l.karte, l.f) end
    W.loeschen = nil
  end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

---------------------------------------------------------------------------
-- Pins
---------------------------------------------------------------------------
local function NeuerPin(eltern, i, liste)
  local p = liste[i]
  if p then return p end
  p = CreateFrame("Button", nil, eltern)
  p:SetFrameLevel((eltern.GetFrameLevel and eltern:GetFrameLevel() or 1) + 20)
  p.rand = p:CreateTexture(nil, "BACKGROUND")
  p.rand:SetPoint("TOPLEFT", -1, 1)
  p.rand:SetPoint("BOTTOMRIGHT", 1, -1)
  p.icon = p:CreateTexture(nil, "ARTWORK")
  p.icon:SetAllPoints()
  p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  p:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  liste[i] = p
  return p
end
W.NeuerPin = NeuerPin

-- Gemeinsames Aussehen für Welt- und Minikarte. Status liegt nie nur in der Farbe:
-- nicht abbaubare Vorkommen sind zusätzlich entsättigt und halb durchsichtig.
function W:PinGestalten(p, f, groesse)
  local art = F:Art(f.t)
  local c = FG:ArtFarbe(art)
  p:SetSize(groesse, groesse)
  p.icon:SetTexture(F:Symbol(f.t))
  p.rand:SetColorTexture(c[1], c[2], c[3], FG.db.kontrast and 1 or 0.85)
  local geht = F:Abbaubar(f.t) ~= false
  if p.icon.SetDesaturated then p.icon:SetDesaturated(not geht) end
  p:SetAlpha(geht and 1 or 0.55)
end

local function Zeichnen()
  local lw = Leinwand()
  if not lw then return end
  local karte = KarteJetzt()
  local skala = Skala()
  gezeigt.karte, gezeigt.skala, gezeigt.stand = karte, skala, stand
  local b, h = lw:GetWidth(), lw:GetHeight()
  local n = 0
  if FG.db.weltkarte and karte then
    local groesse = (FG.db.pinGroesse or 16) * FG:Groesse() / skala
    for _, f in ipairs(F:Liste(karte)) do
      if F:Sichtbar(f.t) then
        n = n + 1
        local p = NeuerPin(lw, n, pins)
        W:PinGestalten(p, f, groesse)
        p:ClearAllPoints()
        p:SetPoint("CENTER", lw, "TOPLEFT", f.x * b, -f.y * h)
        p:SetScript("OnEnter", function(self) W:FundTooltip(self, karte, f) end)
        p:SetScript("OnLeave", function() GameTooltip:Hide() end)
        p:SetScript("OnClick", function(_, taste) W:FundKlick(karte, f, taste) end)
        p:Show()
      end
    end
  end
  for i = n + 1, #pins do pins[i]:Hide() end
  W.anzahl = n

  -- Routen als Linien
  local nl, np = 0, 0
  if FG.db.routeLinien and karte and lw.CreateLine and FG.Routen then
    for _, r in ipairs(FG.Routen:AufKarte(karte)) do
      local aktiv = FG.Routen.aktiv == r
      local c = aktiv and FG.farben.gold or { 0.85, 0.85, 0.85 }
      local pk = r.punkte
      local anz = #pk / 2
      for i = 1, anz do
        local j = (i % anz) + 1
        if j ~= 1 or r.rund ~= false then
          nl = nl + 1
          local ln = linien[nl]
          if not ln then ln = lw:CreateLine(nil, "OVERLAY"); linien[nl] = ln end
          ln:SetThickness((aktiv and 4 or 2.5) / skala)
          ln:SetColorTexture(c[1], c[2], c[3], aktiv and 0.95 or 0.6)
          ln:SetStartPoint("TOPLEFT", lw, pk[i * 2 - 1] * b, -pk[i * 2] * h)
          ln:SetEndPoint("TOPLEFT", lw, pk[j * 2 - 1] * b, -pk[j * 2] * h)
          ln:Show()
        end
      end
      if aktiv then
        local idx = FG.Routen.index or 1
        np = np + 1
        local p = punkte[np]
        if not p then p = lw:CreateTexture(nil, "OVERLAY"); punkte[np] = p end
        p:SetTexture("Interface\\Minimap\\ObjectIcons")
        if p.SetAtlas then pcall(p.SetAtlas, p, "Waypoint-MapPin-Untracked") end
        p:SetSize(18 / skala, 18 / skala)
        p:ClearAllPoints()
        p:SetPoint("CENTER", lw, "TOPLEFT", pk[idx * 2 - 1] * b, -pk[idx * 2] * h)
        p:Show()
      end
    end
  end
  for i = nl + 1, #linien do linien[i]:Hide() end
  for i = np + 1, #punkte do punkte[i]:Hide() end
end

function W:Auffrischen() stand = stand + 1 end

function W:Anwenden()
  stand = stand + 1
  if WorldMapFrame and WorldMapFrame:IsShown() then FG:Sicher("Weltkarte", Zeichnen) end
end

function W:Start()
  if not WorldMapFrame then return end
  FG:Haken("fundorte", function() stand = stand + 1 end)
  FG:Haken("routen", function() stand = stand + 1 end)
  -- Der Wächter läuft nur, solange die Karte offen ist, und zeichnet neu, wenn sich
  -- Karte, Zoom oder Daten geändert haben.
  waechter = CreateFrame("Frame", nil, WorldMapFrame)
  local takt = 0
  waechter:SetScript("OnUpdate", function(_, dt)
    takt = takt + (dt or 0)
    if takt < 0.1 then return end
    takt = 0
    if KarteJetzt() ~= gezeigt.karte or Skala() ~= gezeigt.skala or stand ~= gezeigt.stand then
      FG:Sicher("Weltkarte", Zeichnen)
    end
  end)
  W.waechter = waechter
  if WorldMapFrame.HookScript then
    WorldMapFrame:HookScript("OnShow", function() FG:Sicher("Weltkarte", Zeichnen) end)
  end
end
