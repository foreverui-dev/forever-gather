-- Forever Harvest: Fundorte erfassen, speichern, filtern und die Sammelsitzung zählen.
local _, FG = ...
local F = FG:Modul("Fundorte")
local P = FG.Position
local L = FG.L

---------------------------------------------------------------------------
-- Vorkommen („Typen“): „o1618“ für bekannte Objektnummern, „n:Name“ für gelernte Namen.
---------------------------------------------------------------------------
local namenIndex   -- [Name in beliebiger Sprache] = Typ

local function IndexBauen()
  namenIndex = {}
  for id, k in pairs(FG.KNOTEN) do
    namenIndex[k[2]] = "o" .. id
    namenIndex[k[3]] = "o" .. id
  end
  for typ, t in pairs(FG.root and FG.root.typen or {}) do
    if t.name and not namenIndex[t.name] then namenIndex[t.name] = typ end
  end
end

function F:Knoten(typ)
  local id = type(typ) == "string" and tonumber(typ:match("^o(%d+)$"))
  return id and FG.KNOTEN[id], id
end

-- Typ aus Objektnummer, Name und Art bestimmen (und unbekannte Vorkommen lernen).
function F:TypVon(objekt, name, art)
  if objekt and FG.KNOTEN[objekt] then return "o" .. objekt end
  name = FG.Frei(name)
  if type(name) ~= "string" then name = nil end
  if not namenIndex then IndexBauen() end
  if name and namenIndex[name] then return namenIndex[name] end
  local typ
  if objekt then typ = "o" .. objekt
  elseif name and name ~= "" then typ = "n:" .. name
  else return end
  local t = FG.root.typen[typ]
  if not t then
    FG.root.typen[typ] = { art = art or "kraut", name = name }
    if name then namenIndex[name] = typ end
  elseif name and not t.name then
    t.name = name
  end
  return typ
end

function F:TypNachName(name)
  name = FG.Frei(name)
  if type(name) ~= "string" then return end
  if not namenIndex then IndexBauen() end
  return namenIndex[name]
end

-- Letzter Ausweg, wenn weder Objekt noch Name bekannt sind: Vorkommen über das Material.
function F:TypNachItem(item, art)
  local best
  for id, k in pairs(FG.KNOTEN) do
    if k[5] == item and (not art or k[1] == art) and (not best or id < best) then best = id end
  end
  return best and ("o" .. best) or nil
end

function F:Art(typ)
  local k = self:Knoten(typ)
  if k then return k[1] end
  local t = FG.root.typen[typ]
  return t and t.art or "kraut"
end

function F:Name(typ)
  local k = self:Knoten(typ)
  if k then return FG.englischUI and k[3] or k[2] end
  local t = FG.root.typen[typ]
  return (t and t.name) or (type(typ) == "string" and typ:match("^n:(.+)$")) or L"Unbekanntes Vorkommen"
end

function F:Stufe(typ)
  local k = self:Knoten(typ)
  return k and k[4] or (FG.root.typen[typ] and FG.root.typen[typ].stufe) or nil
end

function F:Material(typ)
  local k = self:Knoten(typ)
  return k and k[5] or (FG.root.typen[typ] and FG.root.typen[typ].item) or nil
end

function F:Symbol(typ)
  local item = self:Material(typ)
  local m = item and FG.MATERIALIEN[item]
  if m then return m[4] end
  if item and C_Item and C_Item.GetItemIconByID then
    local ok, s = pcall(C_Item.GetItemIconByID, item)
    if ok and s then return s end
  end
  return FG.ARTEN[self:Art(typ)].symbol
end

-- Alle bekannten Typen einer Art, sortiert nach Fertigkeit, dann Name.
function F:Typen(art)
  local liste, gesehen = {}, {}
  for id, k in pairs(FG.KNOTEN) do
    if not art or k[1] == art then liste[#liste + 1] = "o" .. id; gesehen["o" .. id] = true end
  end
  for typ, t in pairs(FG.root.typen) do
    if not gesehen[typ] and (not art or t.art == art) then liste[#liste + 1] = typ end
  end
  table.sort(liste, function(a, b)
    local sa, sb = self:Stufe(a) or 999, self:Stufe(b) or 999
    if sa ~= sb then return sa < sb end
    return self:Name(a) < self:Name(b)
  end)
  return liste
end

---------------------------------------------------------------------------
-- Berufe und Fertigkeit
---------------------------------------------------------------------------
local fertigkeit = {}   -- [Art] = Stufe (nil = Beruf nicht erlernt)

function F:BerufeLesen()
  wipe(fertigkeit)
  local gefunden = false
  -- Nur wenn das Spiel überhaupt Berufe verrät, wird danach gefiltert.
  F.berufeBekannt = (GetProfessions and GetProfessionInfo or (GetNumSkillLines and GetSkillLineInfo)) and true or false
  if GetProfessions and GetProfessionInfo then
    local liste = { GetProfessions() }
    for i = 1, 2 do
      local idx = liste[i]
      if idx then
        local name, _, stufe, _, _, _, linie = GetProfessionInfo(idx)
        for art, b in pairs(FG.BERUFE) do
          if linie == b.linie or name == b.namen[1] or name == b.namen[2] then fertigkeit[art] = stufe; gefunden = true end
        end
      end
    end
  end
  if not gefunden and GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name, kopf, _, stufe = GetSkillLineInfo(i)
      if not kopf then
        for art, b in pairs(FG.BERUFE) do
          if name == b.namen[1] or name == b.namen[2] then fertigkeit[art] = stufe end
        end
      end
    end
  end
  local c = FG.root and FG.root.charaktere
  if c then
    local key = FG:CharKey()
    c[key] = c[key] or { taschen = {}, bank = {} }
    c[key].berufe = { kraut = fertigkeit.kraut, erz = fertigkeit.erz }
  end
  FG:Rufe("fundorte")
end

-- Stufe des Berufs zur Art (Schätze brauchen keinen Beruf → 999).
function F:Fertigkeit(art)
  if art == "schatz" then return 999 end
  return fertigkeit[art]
end

-- true, wenn der Charakter das Vorkommen abbauen kann; false, wenn nicht; nil, wenn unklar.
function F:Abbaubar(typ)
  local art = self:Art(typ)
  local hat = self:Fertigkeit(art)
  if not hat then
    if not self.berufeBekannt then return nil end
    return false
  end
  local braucht = self:Stufe(typ)
  if not braucht then return nil end
  return hat >= braucht
end

---------------------------------------------------------------------------
-- Speicher
---------------------------------------------------------------------------
function F:Liste(karte)
  return FG.root.fundorte[karte] or {}
end

function F:Sichtbar(typ)
  local db = FG.db
  local art = self:Art(typ)
  if not db.zeigen[art] or db.ausgeblendet[typ] then return false end
  if db.nurEigenerBeruf and self.berufeBekannt and art ~= "schatz" and not self:Fertigkeit(art) then return false end
  if db.nurAbbaubar and self:Abbaubar(typ) == false then return false end
  if db.nurSkillpunkte and self.Farbstufe then
    local s = self:Farbstufe(typ)
    if s == "grau" or s == "rot" then return false end
  end
  return true
end

-- Einzelner Fundort: Favoriten sind immer sichtbar.
function F:FundSichtbar(f)
  return f.fav or self:Sichtbar(f.t)
end

-- Restzeit in Sekunden, solange ein selbst abgeernteter Fundort vermutlich noch leer ist.
function F:Abgeerntet(f)
  local min = FG.db.abgeerntetMinuten or 0
  if min <= 0 or not f.g then return end
  local rest = f.g + min * 60 - time()
  if rest > 0 then return rest end
end

-- Fügt einen Fund hinzu oder zählt einen nahen gleichen Fund hoch. Gibt Fund, neu zurück.
function F:Hinzufuegen(karte, x, y, typ, quelle, anzahl, zeit)
  if not (karte and x and y and typ) then return end
  if x <= 0 or x >= 1 or y <= 0 or y >= 1 then return end
  local liste = FG.root.fundorte[karte]
  if not liste then liste = {}; FG.root.fundorte[karte] = liste end
  local grenze = FG.db.zusammenfassen or 15
  local b, h = P:Groesse(karte)
  for _, f in ipairs(liste) do
    if f.t == typ then
      local nah
      if b then nah = math.sqrt(((f.x - x) * b) ^ 2 + ((f.y - y) * h) ^ 2) <= grenze
      else nah = math.abs(f.x - x) < 0.004 and math.abs(f.y - y) < 0.004 end
      if nah then
        if not quelle then
          -- eigener Fund: Mittelpunkt leicht nachziehen und zählen
          local n = f.n or 1
          f.x, f.y = (f.x * n + x) / (n + 1), (f.y * n + y) / (n + 1)
          f.n = n + (anzahl or 1)
          f.q = nil
        end
        f.z = math.max(f.z or 0, zeit or time())
        return f, false
      end
    end
  end
  local f = { x = x, y = y, t = typ, n = quelle and 0 or (anzahl or 1), z = zeit or time(), q = quelle }
  liste[#liste + 1] = f
  FG:Rufe("fundorte", karte)
  return f, true
end

function F:Entfernen(karte, fund)
  local liste = FG.root.fundorte[karte]
  if not liste then return end
  for i, f in ipairs(liste) do
    if f == fund then
      table.remove(liste, i)
      if #liste == 0 then FG.root.fundorte[karte] = nil end
      FG:Rufe("fundorte", karte)
      return true
    end
  end
end

-- Löscht alle Fundorte eines Typs (optional nur auf einer Karte). Gibt die Anzahl zurück.
function F:TypLoeschen(typ, karte)
  local n = 0
  for k, liste in pairs(FG.root.fundorte) do
    if not karte or k == karte then
      for i = #liste, 1, -1 do
        if liste[i].t == typ then table.remove(liste, i); n = n + 1 end
      end
      if #liste == 0 then FG.root.fundorte[k] = nil end
    end
  end
  FG:Rufe("fundorte", karte)
  return n
end

function F:Anzahl(typ, karte)
  local n = 0
  for k, liste in pairs(FG.root.fundorte) do
    if not karte or k == karte then
      for _, f in ipairs(liste) do if not typ or f.t == typ then n = n + 1 end end
    end
  end
  return n
end

function F:AnzahlArt(art)
  local n = 0
  for _, liste in pairs(FG.root.fundorte) do
    for _, f in ipairs(liste) do if self:Art(f.t) == art then n = n + 1 end end
  end
  return n
end

-- Nächster sichtbarer Fundort auf der Karte des Spielers.
function F:Naechster(nurAbbaubar)
  local karte, px, py = P:Spieler()
  if not karte then return end
  local best, bestM
  for _, f in ipairs(self:Liste(karte)) do
    if self:FundSichtbar(f) and not self:Abgeerntet(f) and (not nurAbbaubar or self:Abbaubar(f.t) ~= false) then
      local m = P:Entfernung(karte, px, py, f.x, f.y) or ((f.x - px) ^ 2 + (f.y - py) ^ 2)
      if not bestM or m < bestM then best, bestM = f, m end
    end
  end
  return best, karte, bestM
end

---------------------------------------------------------------------------
-- Erfassen: Sammelzauber merken, beim Plündern Objekt und Beute auswerten.
---------------------------------------------------------------------------
local zauberNamen   -- [Name des Zaubers] = Art
local offen         -- laufender Sammelversuch

local function ZauberArt(id)
  id = FG.Frei(id)
  if not id then return end
  if FG.SAMMELZAUBER[id] then return FG.SAMMELZAUBER[id] end
  if not zauberNamen then
    zauberNamen = {}
    for n, art in pairs(FG.SAMMELNAMEN) do zauberNamen[n] = art end
    for zid, art in pairs(FG.SAMMELZAUBER) do
      local n = FG:SpielZauberName(zid)
      if n then zauberNamen[n] = art end
    end
  end
  local n = FG:SpielZauberName(id)
  return n and zauberNamen[n]
end
F.ZauberArt = ZauberArt

local function ObjektAusGUID(guid)
  guid = FG.Frei(guid)
  if type(guid) ~= "string" then return end
  return tonumber(guid:match("^GameObject%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)"))
end
F.ObjektAusGUID = ObjektAusGUID

local function Aufzeichnen(objekt, beute)
  local o = offen
  offen = nil
  if not o or o.fertig then return end
  o.fertig = true
  local typ = F:TypVon(objekt, o.ziel, o.art)
  if not typ and beute and beute[1] then typ = F:TypNachItem(beute[1].item, o.art) end
  if typ and beute and beute[1] then
    local t = FG.root.typen[typ]
    if t and not t.item then t.item = beute[1].item end
  end
  local fund, neu
  if typ and o.karte then
    fund, neu = F:Hinzufuegen(o.karte, o.x, o.y, typ, nil, 1)
    if fund then fund.g = time() end
    if neu then FG:Rufe("neuerFund", o.karte, fund) end
  end
  F:SitzungZaehlen(o.art, beute)
  FG:Rufe("gesammelt", typ, beute, neu)
end

function F:Start()
  self:BerufeLesen()
  self:SitzungNeu()
  FG:Ereignis("SKILL_LINES_CHANGED", function() F:BerufeLesen() end)
  FG:Ereignis("LEARNED_SPELL_IN_TAB", function() F:BerufeLesen() end)
  FG:Ereignis("UNIT_SPELLCAST_SENT", function(einheit, ziel, guid, zauber)
    if einheit ~= "player" then return end
    local art = ZauberArt(zauber)
    if not art then return end
    local karte, x, y = P:Spieler()
    ziel, guid = FG.Frei(ziel), FG.Frei(guid)
    if type(ziel) ~= "string" or ziel == "" then ziel = nil end
    offen = { art = art, ziel = ziel, guid = guid, zeit = GetTime(), karte = karte, x = x, y = y }
  end)
  local function Abbruch(einheit, guid)
    guid = FG.Frei(guid)
    if einheit == "player" and offen and (not offen.guid or offen.guid == guid) and not offen.ok then offen = nil end
  end
  FG:Ereignis("UNIT_SPELLCAST_FAILED", Abbruch)
  FG:Ereignis("UNIT_SPELLCAST_INTERRUPTED", Abbruch)
  FG:Ereignis("UNIT_SPELLCAST_SUCCEEDED", function(einheit, guid)
    guid = FG.Frei(guid)
    if einheit ~= "player" or not offen or (offen.guid and guid and offen.guid ~= guid) then return end
    offen.ok = true
    local o = offen
    -- Falls kein Beutefenster kommt (z. B. volle Taschen), trotzdem den Ort merken.
    C_Timer.After(2, function() if offen == o then Aufzeichnen(nil, nil) end end)
  end)
  FG:Ereignis("LOOT_OPENED", function()
    if not offen or GetTime() - offen.zeit > 10 then return end
    local objekt
    local beute = {}
    local anzahl = GetNumLootItems and GetNumLootItems() or 0
    for i = 1, anzahl do
      if not objekt and GetLootSourceInfo then objekt = ObjektAusGUID((GetLootSourceInfo(i))) end
      local link = FG.Frei(GetLootSlotLink and GetLootSlotLink(i))
      local item = type(link) == "string" and tonumber(link:match("item:(%d+)"))
      if item then
        local _, _, menge = GetLootSlotInfo(i)
        beute[#beute + 1] = { item = item, menge = tonumber(FG.Frei(menge)) or 1 }
      end
    end
    Aufzeichnen(objekt, beute)
  end)
end

---------------------------------------------------------------------------
-- Sammelsitzung
---------------------------------------------------------------------------
function F:SitzungNeu()
  FG.sitzung = { start = GetTime(), erster = nil, letzter = nil, items = {}, reihe = {}, funde = 0, wert = 0, arten = {} }
  FG:Rufe("sitzung")
end

-- Preis je Stück: Auktionspreis, wenn ein Preisaddon ihn kennt, sonst Händlerpreis.
function F:Preis(item)
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if api and api.GetAuctionPriceByItemID then
    local ok, p = pcall(api.GetAuctionPriceByItemID, "ForeverGather", item)
    if ok and p and p > 0 then return p, "auktion" end
  end
  local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if info then
    local ok, _, _, _, _, _, _, _, _, _, _, verkauf = pcall(info, item)
    if ok and verkauf and verkauf > 0 then return verkauf, "haendler" end
  end
  return 0
end

function F:SitzungZaehlen(art, beute)
  local s = FG.sitzung
  local jetzt = GetTime()
  s.erster = s.erster or jetzt
  s.letzter = jetzt
  s.funde = s.funde + 1
  s.arten[art] = (s.arten[art] or 0) + 1
  for _, b in ipairs(beute or {}) do
    if not s.items[b.item] then s.reihe[#s.reihe + 1] = b.item end
    s.items[b.item] = (s.items[b.item] or 0) + b.menge
    s.wert = s.wert + F:Preis(b.item) * b.menge
  end
  FG:Rufe("sitzung")
end

-- Sammeldauer der Sitzung in Sekunden (ab dem ersten Fund).
function F:SitzungDauer()
  local s = FG.sitzung
  if not s.erster then return 0 end
  return math.max(60, GetTime() - s.erster)
end

function F:ProStunde(menge)
  local d = self:SitzungDauer()
  if d <= 0 then return 0 end
  return menge * 3600 / d
end

function F:ItemName(item)
  local m = FG.MATERIALIEN[item]
  if m then return FG.englischUI and m[3] or m[2] end
  local info = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if info then
    local ok, n = pcall(info, item)
    if ok and n then return n end
  end
  return "#" .. item
end

function F:ItemSymbol(item)
  local m = FG.MATERIALIEN[item]
  if m then return m[4] end
  if C_Item and C_Item.GetItemIconByID then
    local ok, s = pcall(C_Item.GetItemIconByID, item)
    if ok and s then return s end
  end
  return 134400
end

function F:SitzungText(schlicht)
  local s = FG.sitzung
  if s.funde == 0 then return L"Noch nichts gesammelt in dieser Sitzung." end
  local teile = {}
  for _, item in ipairs(s.reihe) do
    teile[#teile + 1] = ("%d %s"):format(s.items[item], self:ItemName(item))
  end
  local text = L"%d Funde in %s: %s.":format(s.funde, FG:ZeitText(self:SitzungDauer()), table.concat(teile, ", "))
  if FG.db.wert and s.wert > 0 then text = text .. " " .. L"Wert: %s.":format(FG:GeldText(s.wert, schlicht)) end
  return text
end

FG:Befehl({ "sitzung" }, function(rest)
  if rest == "neu" or rest == "reset" then
    F:SitzungNeu()
    FG:Meldung(L"Sitzung zurückgesetzt.")
    return
  end
  FG:Ansage(F:SitzungText(true))
end, L"/fg sitzung [neu] – was du gesammelt hast")

FG:Befehl({ "naechster" }, function()
  local f, karte, m = F:Naechster(true)
  if not f then FG:Ansage(L"Hier ist noch kein passender Fundort bekannt."); return end
  P:Wegpunkt(karte, f.x, f.y, F:Name(f.t))
  local _, px, py = P:Spieler()
  FG:Ansage(L"Wegpunkt gesetzt: %s", P:Beschreibung(F:Name(f.t), karte, f.x, f.y, px, py))
end, L"/fg naechster – Wegpunkt zum nächsten Fundort")
FG.tasten.naechster = function() FG.befehle.naechster("") end

FG:Befehl({ "zeigen" }, function()
  local alle = FG.db.weltkarte or FG.db.minikarte
  FG.db.weltkarte, FG.db.minikarte = not alle, not alle
  FG:Anwenden()
  FG:Ansage(alle and L"Fundorte ausgeblendet." or L"Fundorte eingeblendet.")
end, L"/fg zeigen – Fundorte auf den Karten ein oder aus")
FG.tasten.anzeige = function() FG.befehle.zeigen("") end

-- Umgebung vorlesen: die drei nächsten sichtbaren Fundorte mit Entfernung und Richtung.
function F:Umgebung()
  local karte, px, py = P:Spieler()
  if not karte then return L"Deine Position ist hier nicht bekannt." end
  local liste = {}
  for _, f in ipairs(self:Liste(karte)) do
    if self:FundSichtbar(f) then
      liste[#liste + 1] = { f = f, m = P:Entfernung(karte, px, py, f.x, f.y) or 0 }
    end
  end
  if #liste == 0 then return L"In dieser Gegend kennt Forever Harvest noch keine Fundorte." end
  table.sort(liste, function(a, b) return a.m < b.m end)
  local teile = {}
  for i = 1, math.min(3, #liste) do
    local f = liste[i].f
    teile[#teile + 1] = P:Beschreibung(self:Name(f.t), karte, f.x, f.y, px, py)
  end
  return L"%d Fundorte in %s. Am nächsten: %s.":format(#liste, P:KartenName(karte), table.concat(teile, "; "))
end

FG:Befehl({ "vorlesen" }, function() FG:Meldung(F:Umgebung()); FG:Sprechen(F:Umgebung(), true) end,
  L"/fg vorlesen – nahe Fundorte vorlesen")
FG.tasten.vorlesen = function() FG.befehle.vorlesen("") end
