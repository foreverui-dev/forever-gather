-- Forever Gather: Fundorte und nächster Routenpunkt auf der Minikarte, Ansage naher Fundorte.
local _, FG = ...
local M = FG:Modul("Minikarte")
local F, P, W = FG.Fundorte, FG.Position, FG.Weltkarte
local L = FG.L

-- Sichtweite der Minikarte (Radius in Metern) je Zoomstufe
local DRAUSSEN = { [0] = 233.33, 200, 166.67, 133.33, 100, 66.67 }
local DRINNEN  = { [0] = 150, 120, 90, 60, 40, 25 }

local pins, routenPin = {}, nil
local rahmen
local angesagt = {}   -- [Fund] = true, solange er in Reichweite bleibt

function M:Radius()
  local zoom = Minimap.GetZoom and Minimap:GetZoom() or 0
  local drinnen = false
  if GetCVar then
    local aussen = tonumber(GetCVar("minimapZoom"))
    local innen = tonumber(GetCVar("minimapInsideZoom"))
    if aussen and innen and aussen ~= innen then drinnen = (innen == zoom) end
  end
  return (drinnen and DRINNEN or DRAUSSEN)[zoom] or 233.33
end

-- Bildschirmversatz (Pixel) eines Punkts gegenüber der Kartenmitte; nil, wenn außerhalb.
function M:Versatz(osten, sueden, radius, rand)
  local nord = -sueden
  local x, y = osten, nord
  if GetCVar and GetCVar("rotateMinimap") == "1" and GetPlayerFacing then
    local f = GetPlayerFacing() or 0
    x = osten * math.cos(f) + nord * math.sin(f)
    y = -osten * math.sin(f) + nord * math.cos(f)
  end
  local d = math.sqrt(x * x + y * y)
  local halb = (Minimap:GetWidth() or 140) / 2
  if d > radius then
    if not rand then return end
    x, y = x / d * radius, y / d * radius
    return x / radius * halb, y / radius * halb, true
  end
  return x / radius * halb, y / radius * halb, false
end

local function Takt()
  local karte, px, py = P:Spieler()
  local n = 0
  local kampf = FG.db.kampfAusblenden and UnitAffectingCombat and UnitAffectingCombat("player")
  if karte and P:Groesse(karte) then
    local radius = M:Radius()
    local zeigen = FG.db.minikarte and not kampf
    local groesse = (FG.db.minikartePinGroesse or 13) * FG:Groesse()
    for _, f in ipairs(F:Liste(karte)) do
      if F:FundSichtbar(f) then
        local o, s = P:Versatz(karte, px, py, f.x, f.y)
        local x, y, amRand = M:Versatz(o, s, radius, FG.db.minikarteRand)
        if x and zeigen then
          n = n + 1
          local p = W.NeuerPin(Minimap, n, pins)
          W:PinGestalten(p, f, amRand and groesse * 0.7 or groesse)
          if amRand then p:SetAlpha(0.6) end
          p:ClearAllPoints()
          p:SetPoint("CENTER", Minimap, "CENTER", x, y)
          p:SetScript("OnEnter", function(self) W:FundTooltip(self, karte, f) end)
          p:SetScript("OnLeave", function() GameTooltip:Hide() end)
          p:SetScript("OnClick", function(_, taste) W:FundKlick(karte, f, taste) end)
          p:Show()
        end
        -- Ansage, Klang und Alarm, wenn ein Fundort in Reichweite kommt
        local selten = FG.db.seltenAlarm and F:Selten(f.t)
        if FG.db.ansage or FG.db.klang or selten then
          local m = math.sqrt(o * o + s * s)
          local weite = (FG.db.ansageEntfernung or 40) * (selten and 2 or 1)
          if m <= weite then
            if not angesagt[f] and F:Abbaubar(f.t) ~= false and not F:Abgeerntet(f) then
              angesagt[f] = true
              local text = P:Beschreibung(F:Name(f.t), karte, f.x, f.y, px, py)
              if selten then
                FG.Extras:Alarm(L"Seltenes Vorkommen in der Nähe: %s":format(text))
              else
                if FG.db.ansage then FG:Meldung(text); FG:Sprechen(text, true) end
                if FG.db.klang then FG.Extras:Klang() end
              end
            end
          elseif angesagt[f] and m > weite * 1.5 then
            angesagt[f] = nil
          end
        end
      end
    end
  end
  for i = n + 1, #pins do pins[i]:Hide() end
  M.anzahl = n

  -- nächster Punkt der aktiven Route
  local R = FG.Routen
  local zeigeRoute = false
  if karte and R and R.aktiv and R.aktiv.karte == karte and FG.db.routeMinikarte then
    local pk, idx = R.aktiv.punkte, R.index or 1
    local o, s = P:Versatz(karte, px, py, pk[idx * 2 - 1], pk[idx * 2])
    if o then
      local x, y = M:Versatz(o, s, M:Radius(), true)
      if not routenPin then
        routenPin = Minimap:CreateTexture(nil, "OVERLAY")
        routenPin:SetTexture("Interface\\Minimap\\ObjectIcons")
        if routenPin.SetAtlas then pcall(routenPin.SetAtlas, routenPin, "Waypoint-MapPin-Tracked") end
      end
      routenPin:SetSize(18 * FG:Groesse(), 18 * FG:Groesse())
      routenPin:ClearAllPoints()
      routenPin:SetPoint("CENTER", Minimap, "CENTER", x, y)
      routenPin:Show()
      zeigeRoute = true
    end
  end
  if routenPin and not zeigeRoute then routenPin:Hide() end
end
M.Takt = Takt

function M:Anwenden()
  if rahmen then FG:Sicher("Minikarte", Takt) end
end

function M:Start()
  if not Minimap then return end
  rahmen = CreateFrame("Frame", nil, UIParent)
  M.rahmen = rahmen
  local zeit = 0
  rahmen:SetScript("OnUpdate", function(_, dt)
    zeit = zeit + (dt or 0)
    if zeit < 0.1 then return end
    zeit = 0
    FG:Sicher("Minikarte", Takt)
  end)
  FG:Haken("fundorte", function() wipe(angesagt) end)
end
