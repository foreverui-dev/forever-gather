-- Forever Harvest: Farmrouten erstellen (aus Fundorten oder per Aufnahme), anzeigen und abfahren.
-- Eine Route: { id, name, karte, art, punkte = { x1, y1, x2, y2, ... }, rund, von, zeit }
local _, FG = ...
local R = FG:Modul("Routen")
local F, P = FG.Fundorte, FG.Position
local L = FG.L

R.aktiv, R.index, R.aufnahme = nil, nil, nil

function R:Liste() return FG.root.routen end

function R:AufKarte(karte)
  local liste = {}
  for _, r in ipairs(FG.root.routen) do
    if r.karte == karte and (not r.versteckt or r == self.aktiv) then liste[#liste + 1] = r end
  end
  return liste
end

local function NeueId()
  return ("%x%04x"):format(time(), math.random(0, 65535))
end

function R:Speichern(r)
  r.id = r.id or NeueId()
  r.zeit = r.zeit or time()
  for i, alt in ipairs(FG.root.routen) do
    if alt.id == r.id then FG.root.routen[i] = r; FG:Rufe("routen"); return r end
  end
  table.insert(FG.root.routen, r)
  FG:Rufe("routen")
  return r
end

function R:Loeschen(r)
  for i, alt in ipairs(FG.root.routen) do
    if alt == r then
      table.remove(FG.root.routen, i)
      if self.aktiv == r then self:Anhalten(true) end
      FG:Rufe("routen")
      return true
    end
  end
end

-- Länge in Metern (als Rundweg, wenn rund).
function R:Laenge(r)
  local pk, summe = r.punkte, 0
  local n = #pk / 2
  if n < 2 then return 0 end
  for i = 1, n do
    local j = i % n + 1
    if j ~= 1 or r.rund ~= false then
      summe = summe + (P:Entfernung(r.karte, pk[i * 2 - 1], pk[i * 2], pk[j * 2 - 1], pk[j * 2]) or 0)
    end
  end
  return summe
end

-- Geschätzte Dauer einer Runde: zu Fuß (7 m/s) und reitend (11,2 m/s).
function R:Dauer(r)
  local m = self:Laenge(r)
  return m / 7, m / 11.2
end

function R:DauerText(r)
  local fuss, reiten = self:Dauer(r)
  return L"ca. %s zu Fuß, %s reitend":format(FG:ZeitText(fuss), FG:ZeitText(reiten))
end

---------------------------------------------------------------------------
-- Route aus Fundorten: kürzester Rundweg (nächster Nachbar, dann 2-opt).
---------------------------------------------------------------------------
function R:Rundweg(karte, punkte)
  local n = #punkte
  if n < 3 then return punkte end
  local b, h = P:Groesse(karte)
  b, h = b or 1, h or 1
  local function d(a, c) return math.sqrt(((a[1] - c[1]) * b) ^ 2 + ((a[2] - c[2]) * h) ^ 2) end
  -- nächster Nachbar
  local frei, weg = {}, { punkte[1] }
  for i = 2, n do frei[#frei + 1] = punkte[i] end
  while #frei > 0 do
    local letzter, best, bi = weg[#weg], nil, nil
    for i, p in ipairs(frei) do
      local e = d(letzter, p)
      if not best or e < best then best, bi = e, i end
    end
    weg[#weg + 1] = table.remove(frei, bi)
  end
  -- 2-opt: Kreuzungen auflösen, bis nichts mehr besser wird (begrenzt)
  local besser, runden = true, 0
  while besser and runden < 30 do
    besser, runden = false, runden + 1
    for i = 1, n - 2 do
      for j = i + 2, n do
        local a, b1 = weg[i], weg[i + 1]
        local c, e = weg[j], weg[j % n + 1]
        if j % n + 1 ~= i then
          local vorher = d(a, b1) + d(c, e)
          local nachher = d(a, c) + d(b1, e)
          if nachher < vorher - 0.01 then
            local lo, hi = i + 1, j
            while lo < hi do weg[lo], weg[hi] = weg[hi], weg[lo]; lo, hi = lo + 1, hi - 1 end
            besser = true
          end
        end
      end
    end
  end
  return weg
end

-- Erstellt eine Route durch alle sichtbaren Fundorte einer Karte (optional nur einer Art).
function R:AusFundorten(karte, art, name)
  local punkte = {}
  for _, f in ipairs(F:Liste(karte)) do
    if F:FundSichtbar(f) and (not art or F:Art(f.t) == art) then punkte[#punkte + 1] = { f.x, f.y } end
  end
  if #punkte < 3 then return nil, L"Für eine Route braucht es mindestens drei sichtbare Fundorte in dieser Gegend." end
  local weg = self:Rundweg(karte, punkte)
  local flach = {}
  for _, p in ipairs(weg) do flach[#flach + 1] = p[1]; flach[#flach + 1] = p[2] end
  local artName = ({ kraut = L"Kräuter", erz = L"Erze", schatz = L"Schätze" })[art] or L"Alles"
  return self:Speichern({
    name = name or ("%s: %s"):format(P:KartenName(karte), artName),
    karte = karte, art = art or "alle", punkte = flach, rund = true, von = UnitName("player"),
  })
end

---------------------------------------------------------------------------
-- Aufnahme: läuft mit, setzt alle paar Meter einen Punkt.
---------------------------------------------------------------------------
function R:AufnahmeStarten()
  local karte, x, y = P:Spieler()
  if not karte then FG:Ansage(L"Hier lässt sich keine Route aufnehmen."); return end
  self.aufnahme = { karte = karte, punkte = { x, y } }
  FG:Ansage(L"Aufnahme läuft. Lauf deine Runde und beende sie mit /fg aufnahme.")
  FG:Rufe("routen")
end

function R:AufnahmeTakt()
  local a = self.aufnahme
  if not a then return end
  local karte, x, y = P:Spieler()
  if karte ~= a.karte then return end
  local pk = a.punkte
  local m = P:Entfernung(karte, pk[#pk - 1], pk[#pk], x, y)
  if m and m >= (FG.db.aufnahmeAbstand or 30) then
    pk[#pk + 1] = x; pk[#pk + 1] = y
    FG:Rufe("routen")
  end
end

function R:AufnahmeBeenden(name)
  local a = self.aufnahme
  self.aufnahme = nil
  if not a then return end
  if #a.punkte < 6 then
    FG:Ansage(L"Aufnahme verworfen: zu wenige Punkte.")
    FG:Rufe("routen")
    return
  end
  local r = self:Speichern({
    name = name or L"%s: eigene Runde":format(P:KartenName(a.karte)),
    karte = a.karte, art = "alle", punkte = a.punkte, rund = true, von = UnitName("player"),
  })
  FG:Ansage(L"Route „%s“ gespeichert, %d Punkte, %s.", r.name, #r.punkte / 2, P:MeterText(self:Laenge(r)))
  return r
end

---------------------------------------------------------------------------
-- Abfahren: Wegpunkt auf den nächsten Punkt, weiter, sobald man nah genug ist.
---------------------------------------------------------------------------
local function PunktSetzen(r, i)
  R.index = i
  P:Wegpunkt(r.karte, r.punkte[i * 2 - 1], r.punkte[i * 2], r.name)
  FG:Rufe("routen")
end

function R:Starten(r)
  if not r then return end
  self.aktiv = r
  -- beim nächstgelegenen Punkt einsteigen
  local karte, x, y = P:Spieler()
  local start = 1
  if karte == r.karte then
    local best
    for i = 1, #r.punkte / 2 do
      local m = P:Entfernung(karte, x, y, r.punkte[i * 2 - 1], r.punkte[i * 2]) or 0
      if not best or m < best then best, start = m, i end
    end
  end
  PunktSetzen(r, start)
  self.runde = { start = GetTime(), stueck = 0, besucht = 0 }
  FG:Ansage(L"Route „%s“ gestartet: Punkt %d von %d.", r.name, start, #r.punkte / 2)
end

function R:Anhalten(still)
  if not self.aktiv then return end
  self.aktiv, self.index, self.runde = nil, nil, nil
  P:WegpunktLoeschen()
  if not still then FG:Ansage(L"Route angehalten.") end
  FG:Rufe("routen")
end

function R:Weiter(rueckwaerts)
  local r = self.aktiv
  if not r then return end
  local n = #r.punkte / 2
  local i = (self.index or 1) + (rueckwaerts and -1 or 1)
  if i > n then i = 1 elseif i < 1 then i = n end
  PunktSetzen(r, i)
  FG:Sprechen(L"Punkt %d von %d":format(i, n))
  -- Runde geschafft, wenn alle Punkte einmal dran waren
  local rd = self.runde
  if rd and not rueckwaerts then
    rd.besucht = rd.besucht + 1
    if rd.besucht >= n then
      local dauer = GetTime() - rd.start
      r.runden = (r.runden or 0) + 1
      if not r.bestzeit or dauer < r.bestzeit then r.bestzeit = dauer end
      r.ertrag = rd.stueck
      r.ertragGesamt = (r.ertragGesamt or 0) + rd.stueck
      if FG.db.rundenAnsage then
        FG:Ansage(L"Runde %d geschafft: %s, %d Stück.", r.runden, FG:ZeitText(dauer), rd.stueck)
      end
      self.runde = { start = GetTime(), stueck = 0, besucht = 0 }
    end
  end
end

function R:Umkehren(r)
  local alt, neu = r.punkte, {}
  for i = #alt / 2, 1, -1 do neu[#neu + 1] = alt[i * 2 - 1]; neu[#neu + 1] = alt[i * 2] end
  r.punkte = neu
  if self.aktiv == r and self.index then self.index = #neu / 2 - self.index + 1 end
  FG:Rufe("routen")
end

function R:Takt()
  self:AufnahmeTakt()
  local r = self.aktiv
  if not r then return end
  local karte, x, y = P:Spieler()
  if karte ~= r.karte then return end
  local i = self.index or 1
  local m = P:Entfernung(karte, x, y, r.punkte[i * 2 - 1], r.punkte[i * 2])
  if m and m <= (FG.db.wegpunktAbstand or 25) then self:Weiter() end
end

function R:Start()
  FG:Haken("gesammelt", function(_, beute)
    if not (R.aktiv and R.runde) then return end
    for _, b in ipairs(beute or {}) do R.runde.stueck = R.runde.stueck + (b.menge or 1) end
  end)
  local rahmen = CreateFrame("Frame", nil, UIParent)
  local zeit = 0
  rahmen:SetScript("OnUpdate", function(_, dt)
    zeit = zeit + (dt or 0)
    if zeit < 0.5 then return end
    zeit = 0
    FG:Sicher("Routen", R.Takt, R)
  end)
  R.rahmen = rahmen
end

-- Befehle und Tasten
FG:Befehl({ "route" }, function(rest)
  rest = (rest or ""):lower()
  if rest == "weiter" or rest == "next" then R:Weiter(); return end
  if rest == "stopp" or rest == "stop" then R:Anhalten(); return end
  if rest == "neu" or rest == "new" or rest == "kraut" or rest == "erz" then
    local karte = P:Spieler()
    local r, fehler = R:AusFundorten(karte, (rest == "kraut" or rest == "erz") and rest or nil)
    if r then FG:Ansage(L"Route „%s“ erstellt: %d Punkte, %s.", r.name, #r.punkte / 2, P:MeterText(R:Laenge(r)))
    else FG:Ansage(fehler or "?") end
    return
  end
  if R.aktiv then R:Anhalten(); return end
  -- sonst: erste Route dieser Karte starten
  local karte = P:Spieler()
  local liste = R:AufKarte(karte)
  if liste[1] then R:Starten(liste[1]) else FG:Ansage(L"Für diese Gegend gibt es noch keine Route. /fg route neu erstellt eine.") end
end, L"/fg route [neu | kraut | erz | weiter | stopp] – Farmroute erstellen oder abfahren")

FG:Befehl({ "aufnahme" }, function()
  if R.aufnahme then R:AufnahmeBeenden() else R:AufnahmeStarten() end
end, L"/fg aufnahme – eigene Route aufnehmen (starten und beenden)")

FG.tasten.route = function() FG.befehle.route("") end
FG.tasten.weiter = function() R:Weiter() end
FG.tasten.aufnahme = function() FG.befehle.aufnahme("") end
