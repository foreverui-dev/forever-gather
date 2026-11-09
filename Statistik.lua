-- Forever Harvest: Tagesstatistik, Gesamtmengen, beste Sitzung und Rangliste der Gegenden.
local _, FG = ...
local St = FG:Modul("Statistik")
local F, P = FG.Fundorte, FG.Position
local L = FG.L

local function Heute() return date("%Y-%m-%d") end

function St:Zaehlen(typ, beute)
  local root = FG.root
  local tag = Heute()
  local t = root.tage[tag]
  if not t then t = { funde = 0, stueck = 0, wert = 0, items = {} }; root.tage[tag] = t end
  t.funde = t.funde + 1
  for _, b in ipairs(beute or {}) do
    t.stueck = t.stueck + b.menge
    t.items[b.item] = (t.items[b.item] or 0) + b.menge
    t.wert = t.wert + F:Preis(b.item) * b.menge
    root.gesamt[b.item] = (root.gesamt[b.item] or 0) + b.menge
  end
  -- höchstens 60 Tage aufheben
  local tage = {}
  for k in pairs(root.tage) do tage[#tage + 1] = k end
  if #tage > 60 then
    table.sort(tage)
    for i = 1, #tage - 60 do root.tage[tage[i]] = nil end
  end
  -- beste Sitzung
  local s = FG.sitzung
  local b = root.besteSitzung
  if s and (not b or s.funde > b.funde) then
    local stueck = 0
    for _, n in pairs(s.items) do stueck = stueck + n end
    root.besteSitzung = { funde = s.funde, stueck = stueck, wert = s.wert, dauer = F:SitzungDauer(), datum = tag }
  end
end

function St:Tage(anzahl)
  local liste = {}
  for tag, t in pairs(FG.root.tage) do liste[#liste + 1] = { tag = tag, t = t } end
  table.sort(liste, function(a, b) return a.tag > b.tag end)
  for i = #liste, (anzahl or 14) + 1, -1 do liste[i] = nil end
  return liste
end

function St:TagText(tag)
  local j, m, d = tag:match("^(%d+)%-(%d+)%-(%d+)$")
  if not j then return tag end
  if FG.englischUI then return ("%s-%s"):format(m, d) end
  return ("%s.%s."):format(d, m)
end

function St:Gesamt()
  local summe, liste = 0, {}
  for item, n in pairs(FG.root.gesamt) do
    summe = summe + n
    liste[#liste + 1] = { item = item, menge = n, name = F:ItemName(item) }
  end
  table.sort(liste, function(a, b) return a.menge > b.menge end)
  return summe, liste
end

-- Gegenden nach Nutzen für diesen Charakter: zuerst Fertigkeitspunkte, dann abbaubare Fundorte.
function St:Zonen()
  local liste = {}
  for karte, fundorte in pairs(FG.root.fundorte) do
    local e = { karte = karte, name = P:KartenName(karte), kraut = 0, erz = 0, schatz = 0, punkte = 0, abbaubar = 0, gesamt = #fundorte }
    for _, f in ipairs(fundorte) do
      local art = F:Art(f.t)
      e[art] = (e[art] or 0) + 1
      if F:Abbaubar(f.t) ~= false and (art == "schatz" or F:Fertigkeit(art)) then e.abbaubar = e.abbaubar + 1 end
      local s = F:Farbstufe(f.t)
      if s == "orange" or s == "gelb" or s == "gruen" then e.punkte = e.punkte + 1 end
    end
    liste[#liste + 1] = e
  end
  table.sort(liste, function(a, b)
    if a.punkte ~= b.punkte then return a.punkte > b.punkte end
    if a.abbaubar ~= b.abbaubar then return a.abbaubar > b.abbaubar end
    return a.name < b.name
  end)
  return liste
end

function St:ZonenText(e)
  return L"%d Kräuter, %d Erze, %d Schätze · %d bringen Punkte":format(e.kraut, e.erz, e.schatz, e.punkte)
end

-- Weltkarte auf eine Gegend öffnen
function St:KarteOeffnen(karte)
  if OpenWorldMap then pcall(OpenWorldMap, karte)
  elseif WorldMapFrame then
    if not WorldMapFrame:IsShown() and ToggleWorldMap then pcall(ToggleWorldMap) end
    if WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, karte) end
  end
end

function St:Start()
  FG:Haken("gesammelt", function(typ, beute) St:Zaehlen(typ, beute) end)
end

FG:Befehl({ "statistik", "stats" }, function()
  local summe = St:Gesamt()
  FG:Meldung(L"Insgesamt %d Stück gesammelt.", summe)
  for _, e in ipairs(St:Tage(7)) do
    DEFAULT_CHAT_FRAME:AddMessage(("  %s: %d %s, %d %s"):format(St:TagText(e.tag), e.t.funde, L"Funde", e.t.stueck, L"Stück"))
  end
  local zonen = St:Zonen()
  if zonen[1] then FG:Ansage(L"Beste Gegend für dich: %s (%s).", zonen[1].name, St:ZonenText(zonen[1])) end
end, L"/fg statistik – Tage, Gesamtmengen und beste Gegend")
