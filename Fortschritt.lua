-- Forever Harvest: Fertigkeit voranbringen. Planer, Gegend-Empfehlung, Aufstiege der Sitzung,
-- Hinweise auf Lehrer und Grenzen, Fertigkeitsziel und neu freigeschaltete Sorten.
local _, FG = ...
local Fo = FG:Modul("Fortschritt")
local F, P = FG.Fundorte, FG.Position
local L = FG.L

local ART_NAME = { kraut = "Kräuterkunde", erz = "Bergbau" }
local function ArtName(art) return L(ART_NAME[art] or art) end

-- Ab dieser Stufe lohnt der Lehrer (nächste Stufe lernen), bei der zweiten ist die Grenze erreicht.
Fo.LEHRER = { [50] = 75, [125] = 150, [200] = 225, [275] = 300 }
Fo.GRENZEN = { [75] = true, [150] = true, [225] = true }

-- Planer: was bringt gerade Punkte, was kommt als Nächstes?
function Fo:Planer(art)
  local hat = F:Fertigkeit(art)
  local punkte, naechste = {}, nil
  if not hat then return { punkte = punkte, hat = nil } end
  for _, typ in ipairs(F:Typen(art)) do
    local stufe = F:Stufe(typ)
    local farbe = F:Farbstufe(typ)
    if farbe == "orange" or farbe == "gelb" or farbe == "gruen" then
      punkte[#punkte + 1] = { typ = typ, farbe = farbe, stufe = stufe }
    elseif farbe == "rot" and stufe and (not naechste or stufe < F:Stufe(naechste)) then
      naechste = typ
    end
  end
  return { punkte = punkte, naechste = naechste, hat = hat }
end

function Fo:PlanerText(art)
  local p = self:Planer(art)
  if not p.hat then return L"%s nicht erlernt":format(ArtName(art)) end
  local namen = {}
  for i, e in ipairs(p.punkte) do
    if i > 4 then break end
    local _, _, _, wort = FG:StufenFarbe(e.farbe)
    namen[#namen + 1] = ("%s (%s)"):format(F:Name(e.typ), wort)
  end
  local t = L"%s %d: Punkte bringen %s.":format(ArtName(art), p.hat, #namen > 0 and table.concat(namen, ", ") or L"keine bekannten Sorten")
  if p.naechste then
    t = t .. " " .. L"Als Nächstes: %s ab %d.":format(F:Name(p.naechste), F:Stufe(p.naechste))
  end
  return t
end

-- Gegenden mit den meisten bekannten Vorkommen, die jetzt Punkte bringen.
function Fo:Wohin(anzahl)
  local liste = {}
  for karte, funde in pairs(FG.root.fundorte) do
    local n = 0
    for _, f in ipairs(funde) do
      local farbe = F:Farbstufe(f.t)
      if farbe == "orange" or farbe == "gelb" then n = n + 2 elseif farbe == "gruen" then n = n + 1 end
    end
    if n > 0 then liste[#liste + 1] = { karte = karte, wert = n, name = P:KartenName(karte) } end
  end
  table.sort(liste, function(a, b) if a.wert ~= b.wert then return a.wert > b.wert end return a.name < b.name end)
  for i = #liste, (anzahl or 3) + 1, -1 do liste[i] = nil end
  return liste
end

-- Aufstiege erkennen (nach jedem Lesen der Berufe).
Fo.letzte = {}
function Fo:Pruefen()
  for _, art in ipairs({ "kraut", "erz" }) do
    local neu, alt = F:Fertigkeit(art), self.letzte[art]
    if neu and alt and neu > alt then
      local s = FG.sitzung
      if s then s.punkte = (s.punkte or 0) + (neu - alt) end
      self:Aufstieg(art, alt, neu)
    end
    self.letzte[art] = neu
  end
end

function Fo:Aufstieg(art, alt, neu)
  -- neu freigeschaltete Sorten
  if FG.db.neueSorten then
    for _, typ in ipairs(F:Typen(art)) do
      local st = F:Stufe(typ)
      if st and st > alt and st <= neu then
        FG:Ansage(L"Ab jetzt kannst du %s sammeln.", F:Name(typ))
      end
    end
  end
  -- Lehrer und Grenzen
  if FG.db.lehrerHinweis then
    for stufe = alt + 1, neu do
      if self.LEHRER[stufe] then
        FG:Ansage(L"%s %d: Beim Lehrer kannst du jetzt die nächste Stufe (bis %d) lernen.", ArtName(art), stufe, self.LEHRER[stufe])
      elseif self.GRENZEN[stufe] then
        FG.Extras:Alarm(L"%s %d: Grenze erreicht. Ohne Lehrer gibt es keine Punkte mehr.":format(ArtName(art), stufe))
      end
    end
  end
  -- Fertigkeitsziel
  local ziel = FG.char.fertigkeitZiel and FG.char.fertigkeitZiel[art]
  if ziel and alt < ziel and neu >= ziel then
    FG.Extras:Alarm(L"Fertigkeitsziel erreicht: %s %d!":format(ArtName(art), ziel))
    FG.char.fertigkeitZiel[art] = nil
  end
  FG:Rufe("sitzung")
end

function Fo:ZielSetzen(art, stufe)
  FG.char.fertigkeitZiel = FG.char.fertigkeitZiel or {}
  FG.char.fertigkeitZiel[art] = (stufe and stufe > 0) and stufe or nil
  if stufe and stufe > 0 then
    FG:Ansage(L"Fertigkeitsziel: %s %d (jetzt %s).", ArtName(art), stufe, tostring(F:Fertigkeit(art) or 0))
  else
    FG:Ansage(L"Fertigkeitsziel für %s entfernt.", ArtName(art))
  end
end

function Fo:ZielText(art)
  local ziel = FG.char.fertigkeitZiel and FG.char.fertigkeitZiel[art]
  if not ziel then return nil end
  return L"Ziel %s: %d / %d":format(ArtName(art), F:Fertigkeit(art) or 0, ziel)
end

-- Sammelberufe aller Charaktere für die Übersicht.
function Fo:Charaktere()
  local liste = {}
  for key, c in pairs(FG.root.charaktere) do
    if c.berufe and (c.berufe.kraut or c.berufe.erz) then
      liste[#liste + 1] = { key = key, kraut = c.berufe.kraut, erz = c.berufe.erz, klasse = c.klasse }
    end
  end
  table.sort(liste, function(a, b) return a.key < b.key end)
  return liste
end

function Fo:Start()
  for _, art in ipairs({ "kraut", "erz" }) do self.letzte[art] = F:Fertigkeit(art) end
  FG:Ereignis("SKILL_LINES_CHANGED", function() Fo:Pruefen() end)
  FG:Haken("gesammelt", function() C_Timer.After(0.5, function() FG:Sicher("Fortschritt", Fo.Pruefen, Fo) end) end)
end

FG:Befehl({ "wohin", "where" }, function()
  local liste = Fo:Wohin(3)
  if #liste == 0 then FG:Ansage(L"Noch keine Gegend bekannt, in der du gerade Punkte bekommst."); return end
  local namen = {}
  for _, e in ipairs(liste) do namen[#namen + 1] = e.name end
  FG:Ansage(L"Für Fertigkeitspunkte lohnen sich: %s.", table.concat(namen, ", "))
end, L"/fg wohin – Gegenden, in denen du gerade Fertigkeitspunkte bekommst")

FG:Befehl({ "planer", "plan" }, function()
  for _, art in ipairs({ "kraut", "erz" }) do FG:Meldung(Fo:PlanerText(art)) end
end, L"/fg planer – was gerade Punkte bringt und was als Nächstes kommt")

FG:Befehl({ "fertigkeit", "skill" }, function(rest)
  local stufe, art = (rest or ""):match("^(%d+)%s*(%a*)")
  art = (art == "erz" or art == "bergbau" or art == "ore") and "erz" or "kraut"
  if not stufe then
    for _, a in ipairs({ "kraut", "erz" }) do
      local t = Fo:ZielText(a)
      if t then FG:Meldung(t) end
    end
    FG:Meldung(L"Beispiel: /fg fertigkeit 150 kraut")
    return
  end
  Fo:ZielSetzen(art, tonumber(stufe))
end, L"/fg fertigkeit [Stufe] [kraut | erz] – Fertigkeitsziel setzen")
