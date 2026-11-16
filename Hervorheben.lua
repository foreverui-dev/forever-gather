-- Forever Harvest: Vorkommen sichtbar hervorheben, ohne in die Spielwelt einzugreifen.
-- Alles läuft über die Oberfläche: pulsierende Symbole, Leuchtrahmen um das nächste Vorkommen,
-- Richtungspfeil am Minikartenrand, Hinweis am Bildschirm, leuchtender Rand bei Seltenem und ein HUD.
local _, FG = ...
local H = FG:Modul("Hervorheben")
local F, P = FG.Fundorte, FG.Position
local L = FG.L

local ring, pfeil, hinweis, rand, hud
local hudPins = {}

-- Farbe der Hervorhebung: Akzent, Farbe der Art oder Weiß.
function H:Farbe(f)
  local wahl = FG.db.hervorFarbe or "akzent"
  if wahl == "art" and f then return FG:ArtFarbe(F:Art(f.t)) end
  if wahl == "weiss" then return { 1, 1, 1 } end
  return FG.farben.akzent
end

-- Größenfaktor für ein Symbol: Vorkommen in Pulsweite pulsieren (bei „weniger Bewegung“ nur größer).
function H:Puls(f, m)
  if not FG.db.puls or not m or m > (FG.db.pulsWeite or 60) then return 1 end
  if F:Abbaubar(f.t) == false or F:Abgeerntet(f) then return 1 end
  if FG.db.wenigerBewegung then return 1.25 end
  return 1 + 0.25 * (0.5 + 0.5 * math.sin((GetTime() or 0) * 6))
end

local function Blinken()
  if FG.db.wenigerBewegung then return 1 end
  return 0.55 + 0.45 * math.abs(math.sin((GetTime() or 0) * 3))
end

---------------------------------------------------------------------------
-- Minikarte: Leuchtrahmen um das nächste Vorkommen, Pfeil am Rand
---------------------------------------------------------------------------
local function RingSetzen(M)
  local f, o, s = M.naechster, M.naechsterO, M.naechsterS
  if not (FG.db.leuchtring and f and FG.db.minikarte) then if ring then ring:Hide() end return end
  local x, y = M:Versatz(o, s, M:Radius(), false)
  if not x then if ring then ring:Hide() end return end
  if not ring then
    ring = Minimap:CreateTexture(nil, "OVERLAY", nil, 7)
    ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    if ring.SetBlendMode then ring:SetBlendMode("ADD") end
    H.ring = ring
  end
  local c = H:Farbe(f)
  local g = (FG.db.minikartePinGroesse or 13) * FG:Groesse() * 2.6
  ring:SetSize(g, g)
  ring:SetVertexColor(c[1], c[2], c[3], Blinken())
  ring:ClearAllPoints()
  ring:SetPoint("CENTER", Minimap, "CENTER", x, y)
  ring:Show()
end

local function PfeilSetzen(M)
  local f, o, s = M.naechster, M.naechsterO, M.naechsterS
  local radius = M:Radius()
  if not (FG.db.richtungspfeil and f and M.naechsterM and M.naechsterM > radius) then if pfeil then pfeil:Hide() end return end
  local x, y = M:Versatz(o, s, radius, true)
  if not x then if pfeil then pfeil:Hide() end return end
  if not pfeil then
    pfeil = Minimap:CreateTexture(nil, "OVERLAY", nil, 6)
    pfeil:SetTexture("Interface\\Minimap\\MinimapArrow")
    H.pfeil = pfeil
  end
  local c = H:Farbe(f)
  pfeil:SetSize(22 * FG:Groesse(), 22 * FG:Groesse())
  pfeil:SetVertexColor(c[1], c[2], c[3], 1)
  if pfeil.SetRotation then pfeil:SetRotation(math.atan2(-x, y)) end
  pfeil:ClearAllPoints()
  pfeil:SetPoint("CENTER", Minimap, "CENTER", x * 0.88, y * 0.88)
  pfeil:Show()
end
H.PfeilWinkel = function(x, y) return math.atan2(-x, y) end

---------------------------------------------------------------------------
-- Hinweis am Bildschirm und leuchtender Rand bei Seltenem
---------------------------------------------------------------------------
local function HinweisSetzen(M, karte, px, py)
  local f, m = M.naechster, M.naechsterM
  local an = FG.db.nahHinweis and f and m and m <= (FG.db.nahWeite or 60)
  if not an then if hinweis then hinweis:Hide() end H.hinweisText = nil return end
  if not hinweis then
    hinweis = CreateFrame("Frame", "ForeverGatherHinweis", UIParent)
    hinweis:SetSize(400, 24)
    hinweis:SetPoint("TOP", 0, -140)
    hinweis.text = hinweis:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    hinweis.text:SetPoint("CENTER")
    hinweis:EnableMouse(false)
  end
  local c = H:Farbe(f)
  local text = P:Beschreibung(F:Name(f.t), karte, f.x, f.y, px, py)
  hinweis.text:SetText(text)
  hinweis.text:SetTextColor(c[1], c[2], c[3])
  hinweis:SetScale(FG:Groesse())
  hinweis:Show()
  H.hinweisText = text
end

local function RandSetzen(karte, px, py)
  local selten
  if FG.db.seltenRand and karte then
    local weite = FG.db.seltenWeite or 100
    for _, f in ipairs(F:Liste(karte)) do
      if F:Selten(f.t) and F:FundSichtbar(f) and not F:Abgeerntet(f) then
        local m = P:Entfernung(karte, px, py, f.x, f.y)
        if m and m <= weite then selten = f; break end
      end
    end
  end
  H.seltenNah = selten
  if not selten then if rand then rand:Hide() end return end
  if not rand then
    rand = CreateFrame("Frame", "ForeverGatherRand", UIParent)
    rand:SetAllPoints()
    rand:EnableMouse(false)
    rand:SetFrameStrata("BACKGROUND")
    rand.kanten = {}
    local function kante(p1, p2, waagrecht)
      local t = rand:CreateTexture(nil, "BACKGROUND")
      t:SetPoint(p1); t:SetPoint(p2)
      if waagrecht then t:SetHeight(10) else t:SetWidth(10) end
      rand.kanten[#rand.kanten + 1] = t
    end
    kante("TOPLEFT", "TOPRIGHT", true); kante("BOTTOMLEFT", "BOTTOMRIGHT", true)
    kante("TOPLEFT", "BOTTOMLEFT"); kante("TOPRIGHT", "BOTTOMRIGHT")
  end
  local c = FG.farben.akzent
  local a = 0.45 * Blinken()
  for _, t in ipairs(rand.kanten) do t:SetColorTexture(c[1], c[2], c[3], a) end
  rand:Show()
end

---------------------------------------------------------------------------
-- HUD: durchsichtige Kreiskarte in der Bildschirmmitte, vorne ist oben.
---------------------------------------------------------------------------
local function HudBauen()
  hud = CreateFrame("Frame", "ForeverGatherHUD", UIParent)
  hud:SetPoint("CENTER", 0, 0)
  hud:EnableMouse(false)
  hud:SetFrameStrata("BACKGROUND")
  hud.mitte = hud:CreateTexture(nil, "OVERLAY")
  hud.mitte:SetSize(16, 16)
  hud.mitte:SetPoint("CENTER")
  hud.mitte:SetTexture("Interface\\Minimap\\MinimapArrow")
  hud.text = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hud.text:SetPoint("TOP", hud, "BOTTOM", 0, -4)
end

function H:HudPunkt(o, s, weite, groesse, blick)
  -- in Blickrichtung drehen: vorne ist oben
  local nord = -s
  local x = o * math.cos(blick) + nord * math.sin(blick)
  local y = -o * math.sin(blick) + nord * math.cos(blick)
  local d = math.sqrt(x * x + y * y)
  if d > weite then return end
  local k = (groesse / 2) / weite
  return x * k, y * k
end

local function HudSetzen(karte, px, py)
  local kampf = UnitAffectingCombat and UnitAffectingCombat("player")
  if not (FG.db.hud and karte and P:Groesse(karte)) or (kampf and FG.db.kampfAusblenden) then
    if hud then hud:Hide() end
    return
  end
  if not hud then HudBauen() end
  local groesse = FG.db.hudGroesse or 320
  local weite = FG.db.hudWeite or 120
  hud:SetSize(groesse, groesse)
  hud:SetAlpha(FG.db.hudDeckkraft or 0.7)
  hud:SetScale(FG:Groesse())
  local blick = FG.Frei(GetPlayerFacing and GetPlayerFacing()) or 0
  local n = 0
  local pinGroesse = (FG.db.minikartePinGroesse or 13) * 1.3
  for _, f in ipairs(F:Liste(karte)) do
    if F:FundSichtbar(f) then
      local o, s = P:Versatz(karte, px, py, f.x, f.y)
      local x, y = H:HudPunkt(o, s, weite, groesse, blick)
      if x then
        n = n + 1
        local p = hudPins[n]
        if not p then
          p = hud:CreateTexture(nil, "ARTWORK")
          p:SetTexCoord(0.08, 0.92, 0.08, 0.92)
          hudPins[n] = p
        end
        local faktor = H:Puls(f, math.sqrt(o * o + s * s))
        p:SetTexture(F:Symbol(f.t))
        p:SetSize(pinGroesse * faktor, pinGroesse * faktor)
        p:SetAlpha(F:Abgeerntet(f) and 0.3 or 1)
        p:ClearAllPoints()
        p:SetPoint("CENTER", hud, "CENTER", x, y)
        p:Show()
      end
    end
  end
  for i = n + 1, #hudPins do hudPins[i]:Hide() end
  hud.text:SetText(n > 0 and FG.Einzahl(L"%d Fundorte im HUD":format(n)) or "")
  H.hudAnzahl = n
  hud:Show()
end

-- Wird von der Minikarte bei jedem Takt aufgerufen.
function H:Takt(karte, px, py)
  local M = FG.Minikarte
  RingSetzen(M)
  PfeilSetzen(M)
  HinweisSetzen(M, karte, px, py)
  RandSetzen(karte, px, py)
  HudSetzen(karte, px, py)
end

function H:HudUmschalten()
  FG.db.hud = not FG.db.hud
  FG:Anwenden()
  FG:Sprechen(L"HUD" .. ": " .. (FG.db.hud and L"an" or L"aus"))
end

FG:Befehl({ "hud" }, function() H:HudUmschalten() end, L"/fg hud – durchsichtige Kreiskarte in der Bildschirmmitte")
FG.tasten.hud = function() H:HudUmschalten() end
