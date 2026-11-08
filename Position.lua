-- Forever Gather: Position des Spielers, Kartengrößen in Metern, Entfernung und Richtung.
-- Fundorte werden als Kartenkoordinaten (0..1) je Karte gespeichert. Für Entfernungen
-- rechnet das Addon die Kartengröße in Meter (eigentlich Yards, im Spiel als Meter gezeigt) um.
local _, FG = ...
local P = FG:Modul("Position")
local L = FG.L

local groessen = {}

local function vektor(x, y)
  if CreateVector2D then return CreateVector2D(x, y) end
  return { x = x, y = y, GetXY = function(s) return s.x, s.y end }
end

local function weltpunkt(karte, x, y)
  if not (C_Map and C_Map.GetWorldPosFromMapPos) then return end
  local ok, kontinent, pos = pcall(C_Map.GetWorldPosFromMapPos, karte, vektor(x, y))
  if not ok or not pos then return end
  local px, py
  if pos.GetXY then px, py = pos:GetXY() else px, py = pos.x, pos.y end
  return kontinent, px, py
end

-- Breite und Höhe einer Karte in Metern (nil, wenn das Spiel es nicht verrät).
function P:Groesse(karte)
  if not karte then return end
  local g = groessen[karte]
  if g == nil then
    g = false
    if C_Map and C_Map.GetMapWorldSize then
      local ok, b, h = pcall(C_Map.GetMapWorldSize, karte)
      if ok and b and h and b > 0 and h > 0 then g = { b, h } end
    end
    if not g then
      local k0, x0, y0 = weltpunkt(karte, 0, 0)
      local _, x1, y1 = weltpunkt(karte, 1, 0)
      local _, x2, y2 = weltpunkt(karte, 0, 1)
      if k0 and x1 and x2 then
        local b = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
        local h = math.sqrt((x2 - x0) ^ 2 + (y2 - y0) ^ 2)
        if b > 0 and h > 0 then g = { b, h } end
      end
    end
    groessen[karte] = g
  end
  if g then return g[1], g[2] end
end

-- Karte und Koordinaten des Spielers (nil in Instanzen ohne Karte).
function P:Spieler()
  if not (C_Map and C_Map.GetBestMapForUnit) then return end
  local karte = C_Map.GetBestMapForUnit("player")
  if not karte then return end
  local pos = C_Map.GetPlayerMapPosition(karte, "player")
  if not pos then return end
  local x, y
  if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
  if not x or (x == 0 and y == 0) then return end
  return karte, x, y
end

-- Abstand in Metern nach Osten und Süden zwischen zwei Punkten derselben Karte.
function P:Versatz(karte, x1, y1, x2, y2)
  local b, h = self:Groesse(karte)
  if not b then return end
  return (x2 - x1) * b, (y2 - y1) * h
end

function P:Entfernung(karte, x1, y1, x2, y2)
  local o, s = self:Versatz(karte, x1, y1, x2, y2)
  if not o then return end
  return math.sqrt(o * o + s * s)
end

-- Richtung als Uhrzeit (12 = geradeaus) aus Sicht des Spielers.
function P:Uhr(osten, sueden)
  local norden = -sueden
  local kurs = math.atan2 and math.atan2(osten, norden) or atan2(osten, norden) -- im Uhrzeigersinn ab Norden
  local blick = GetPlayerFacing and GetPlayerFacing() or 0                         -- gegen den Uhrzeigersinn
  if not blick then blick = 0 end
  local rel = (kurs + blick) % (2 * math.pi)
  local stunde = math.floor(rel / (2 * math.pi) * 12 + 0.5) % 12
  if stunde == 0 then stunde = 12 end
  return stunde
end

function P:MeterText(m)
  m = math.floor((m or 0) + 0.5)
  if m >= 1000 then return FG:KommaText(m / 1000, 1) .. " km" end
  return m .. " m"
end

-- „Silberblatt, 30 m, auf 2 Uhr“
function P:Beschreibung(name, karte, x, y, px, py)
  local o, s = self:Versatz(karte, px, py, x, y)
  if not o then return name end
  local m = math.sqrt(o * o + s * s)
  return L"%s, %s, auf %d Uhr":format(name, self:MeterText(m), self:Uhr(o, s))
end

function P:KartenName(karte)
  if not karte then return "?" end
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(karte)
  return info and info.name or tostring(karte)
end

-- Wegpunkt des Spiels setzen (mit Pfeil am Bildschirmrand).
function P:Wegpunkt(karte, x, y, titel)
  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    local ok = pcall(function()
      if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(karte) then error("Karte") end
      C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(karte, x, y))
      if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end)
    if ok then return true end
  end
  FG:Meldung(L"Ziel: %s bei %s, %s.", titel or "?", FG:KommaText(x * 100, 1), FG:KommaText(y * 100, 1))
  return false
end

function P:WegpunktLoeschen()
  if C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
end
