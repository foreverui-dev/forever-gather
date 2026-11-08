-- Forever Gather: Fundorte und Routen teilen.
-- 1) Teilen-Codes zum Kopieren (Discord, foreverui.de, Freunde): FG1R… für Routen, FG1F… für Fundorte.
-- 2) Direkt im Spiel über Addon-Nachrichten an Gruppe, Gilde oder einen Spieler.
local _, FG = ...
local T = FG:Modul("Teilen")
local F, P, R = FG.Fundorte, FG.Position, FG.Routen
local L = FG.L

local PRAEFIX = "FGather"
local ZEICHEN = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789()"
local WERT = {}
for i = 1, #ZEICHEN do WERT[ZEICHEN:sub(i, i)] = i - 1 end

-- Koordinate 0..1 als zwei Zeichen (4096 Stufen, auf einer Zone etwa 0,3 m genau)
local function Koord(v)
  local n = math.floor(math.max(0, math.min(1, v)) * 4095 + 0.5)
  local a, b = math.floor(n / 64), n % 64
  return ZEICHEN:sub(a + 1, a + 1) .. ZEICHEN:sub(b + 1, b + 1)
end
local function KoordLesen(s, i)
  local a, b = WERT[s:sub(i, i)], WERT[s:sub(i + 1, i + 1)]
  if not a or not b then return end
  return (a * 64 + b) / 4095
end
T.Koord, T.KoordLesen = Koord, KoordLesen

local function Pruefsumme(s)
  local summe = 0
  for i = 1, #s do summe = (summe * 31 + s:byte(i)) % 4096 end
  local a, b = math.floor(summe / 64), summe % 64
  return ZEICHEN:sub(a + 1, a + 1) .. ZEICHEN:sub(b + 1, b + 1)
end

-- Namen dürfen keine Trennzeichen und kein „|“ (Steuerzeichen im Spiel) enthalten.
local function Rein(s)
  return (tostring(s or ""):gsub("[~;,|\n\r]", " "):sub(1, 60))
end

---------------------------------------------------------------------------
-- Codes
---------------------------------------------------------------------------
function T:RoutenCode(r)
  local pk = {}
  for i = 1, #r.punkte do pk[#pk + 1] = Koord(r.punkte[i]) end
  local inhalt = table.concat({ "FG1R", Rein(r.name), r.karte, r.art or "alle", r.rund == false and "0" or "1",
    Rein(r.von or UnitName("player")), table.concat(pk) }, "~")
  return inhalt .. "~" .. Pruefsumme(inhalt)
end

-- Fundorte als Code: Karte;Typ,XXYY,XXYY;Typ,…|nächste Karte (Trenner „~“ zwischen Karten)
function T:FundortCode(nurKarte)
  local bloecke = {}
  local karten = {}
  for karte in pairs(FG.root.fundorte) do
    if not nurKarte or karte == nurKarte then karten[#karten + 1] = karte end
  end
  table.sort(karten)
  local anzahl = 0
  for _, karte in ipairs(karten) do
    local jeTyp, reihe = {}, {}
    for _, f in ipairs(FG.root.fundorte[karte]) do
      local typ = f.t
      if typ:sub(1, 2) == "n:" then typ = "n:" .. Rein(typ:sub(3)) end
      if not jeTyp[typ] then jeTyp[typ] = {}; reihe[#reihe + 1] = typ end
      table.insert(jeTyp[typ], Koord(f.x) .. Koord(f.y))
      anzahl = anzahl + 1
    end
    local teile = { tostring(karte) }
    for _, typ in ipairs(reihe) do
      local art = F:Art(typ)
      teile[#teile + 1] = typ .. "," .. art:sub(1, 1) .. "," .. table.concat(jeTyp[typ])
    end
    bloecke[#bloecke + 1] = table.concat(teile, ";")
  end
  if anzahl == 0 then return nil, 0 end
  local inhalt = "FG1F~" .. table.concat(bloecke, "~")
  return inhalt .. "~" .. Pruefsumme(inhalt), anzahl
end

local ARTKURZ = { k = "kraut", e = "erz", s = "schatz" }

-- Liest einen Code. Gibt Art („route“/„fundorte“), Ergebnis und Anzahl zurück – oder nil, Fehlertext.
function T:CodeLesen(code, quelle)
  code = tostring(code or ""):gsub("[\r\n]", ""):gsub("^%s+", ""):gsub("%s+$", "")
  local inhalt, summe = code:match("^(.*)~([^~]+)$")
  if not inhalt or not inhalt:match("^FG1[RF]~") then return nil, L"Das ist kein Forever-Gather-Code." end
  if Pruefsumme(inhalt) ~= summe then return nil, L"Der Code ist unvollständig oder beschädigt." end
  local teile = {}
  for t in (inhalt .. "~"):gmatch("([^~]*)~") do teile[#teile + 1] = t end
  if teile[1] == "FG1R" then
    local name, karte, art, rund, von, pk = teile[2], tonumber(teile[3]), teile[4], teile[5], teile[6], teile[7] or ""
    if not karte or #pk < 12 or #pk % 4 ~= 0 then return nil, L"Der Code ist unvollständig oder beschädigt." end
    local punkte = {}
    for i = 1, #pk, 2 do
      local v = KoordLesen(pk, i)
      if not v then return nil, L"Der Code ist unvollständig oder beschädigt." end
      punkte[#punkte + 1] = v
    end
    return "route", { name = name, karte = karte, art = art, rund = rund ~= "0", von = von ~= "" and von or quelle, punkte = punkte }
  end
  -- Fundorte
  local neu, gesamt = 0, 0
  for i = 2, #teile do
    local felder = {}
    for t in (teile[i] .. ";"):gmatch("([^;]*);") do felder[#felder + 1] = t end
    local karte = tonumber(felder[1])
    if karte then
      for j = 2, #felder do
        local typ, a, pos = felder[j]:match("^([^,]+),(%a),(.*)$")
        if typ and #pos % 4 == 0 then
          local art = ARTKURZ[a] or "kraut"
          if typ:sub(1, 2) == "n:" then typ = F:TypVon(nil, typ:sub(3), art)
          elseif not F:Knoten(typ) and not FG.root.typen[typ] then FG.root.typen[typ] = { art = art } end
          for k = 1, #pos, 4 do
            local x, y = KoordLesen(pos, k), KoordLesen(pos, k + 2)
            if x and y then
              gesamt = gesamt + 1
              local _, istNeu = F:Hinzufuegen(karte, x, y, typ, quelle or L"Import")
              if istNeu then neu = neu + 1 end
            end
          end
        end
      end
    end
  end
  return "fundorte", neu, gesamt
end

function T:Importieren(code, quelle)
  local art, a, b = self:CodeLesen(code, quelle)
  if not art then FG:Ansage(a); return false end
  if art == "route" then
    a.zeit = nil
    local r = R:Speichern(a)
    FG:Ansage(L"Route „%s“ übernommen (%d Punkte, %s).", r.name, #r.punkte / 2, P:MeterText(R:Laenge(r)))
    return r
  end
  FG:Ansage(L"%d neue Fundorte übernommen (%d im Code).", a, b)
  return true
end

---------------------------------------------------------------------------
-- Im Spiel senden: Warteschlange, damit der Server nicht drosselt.
---------------------------------------------------------------------------
local schlange, laeuft = {}, false
local function Senden(text, kanal, ziel)
  if C_ChatInfo and C_ChatInfo.SendAddonMessage then
    C_ChatInfo.SendAddonMessage(PRAEFIX, text, kanal, ziel)
  elseif SendAddonMessage then
    SendAddonMessage(PRAEFIX, text, kanal, ziel)
  end
end
local function Abarbeiten()
  local n = table.remove(schlange, 1)
  if not n then laeuft = false; return end
  FG:Sicher("Senden", Senden, n[1], n[2], n[3])
  C_Timer.After(0.25, Abarbeiten)
end
function T:Einreihen(text, kanal, ziel)
  schlange[#schlange + 1] = { text, kanal, ziel }
  if not laeuft then laeuft = true; C_Timer.After(0, Abarbeiten) end
end
T.schlange = schlange

function T:GruppenKanal()
  if IsInRaid and IsInRaid() then return "RAID" end
  if IsInGroup and IsInGroup() then return "PARTY" end
end

-- Neue eigene Funde live an Gruppe/Gilde
local function FundSenden(karte, f)
  local zeile = ("F~%d~%s~%s~%s%s"):format(karte, f.t:sub(1, 2) == "n:" and ("n:" .. Rein(f.t:sub(3))) or f.t,
    F:Art(f.t):sub(1, 1), Koord(f.x), Koord(f.y))
  if FG.db.teilenGruppe and T:GruppenKanal() then T:Einreihen(zeile, T:GruppenKanal()) end
  if FG.db.teilenGilde and IsInGuild and IsInGuild() then T:Einreihen(zeile, "GUILD") end
end

-- Einen langen Code in Stücken senden: C~id~nr~gesamt~stück
function T:CodeSenden(code, kanal, ziel)
  if not kanal then FG:Ansage(L"Du bist in keiner Gruppe."); return end
  local id = ("%x"):format(math.random(0, 0xFFFFFF))
  local stueck = 200
  local gesamt = math.ceil(#code / stueck)
  for i = 1, gesamt do
    self:Einreihen(("C~%s~%d~%d~%s"):format(id, i, gesamt, code:sub((i - 1) * stueck + 1, i * stueck)), kanal, ziel)
  end
  return gesamt
end

function T:RouteSenden(r, kanal, ziel)
  if self:CodeSenden(self:RoutenCode(r), kanal, ziel) then
    FG:Ansage(L"Route „%s“ gesendet.", r.name)
  end
end

function T:FundorteSenden(karte, kanal, ziel)
  local code, n = self:FundortCode(karte)
  if not code then FG:Ansage(L"Keine Fundorte zum Senden."); return end
  if self:CodeSenden(code, kanal, ziel) then FG:Ansage(L"%d Fundorte werden gesendet.", n) end
end

-- Empfang
local puffer = {}
local function Empfangen(text, kanal, absender)
  local name = Ambiguate and Ambiguate(absender, "short") or absender
  if name == UnitName("player") then return end
  local art = text:sub(1, 2)
  if art == "F~" then
    if not FG.db.empfangen then return end
    local karte, typ, a, pos = text:match("^F~(%d+)~([^~]+)~(%a)~(....)$")
    karte = tonumber(karte)
    if not karte or not pos then return end
    local x, y = KoordLesen(pos, 1), KoordLesen(pos, 3)
    if not (x and y) then return end
    local artLang = ARTKURZ[a] or "kraut"
    if typ:sub(1, 2) == "n:" then typ = F:TypVon(nil, typ:sub(3), artLang)
    elseif not F:Knoten(typ) and not FG.root.typen[typ] then FG.root.typen[typ] = { art = artLang } end
    local _, neu = F:Hinzufuegen(karte, x, y, typ, name)
    if neu and FG.db.seltenAlarm and F:Selten(typ) and F:Abbaubar(typ) ~= false then
      FG.Extras:Alarm(L"%s hat %s gefunden (%s).":format(name, F:Name(typ), P:KartenName(karte)))
    end
  elseif art == "C~" then
    local id, nr, gesamt, stueck = text:match("^C~(%w+)~(%d+)~(%d+)~(.*)$")
    nr, gesamt = tonumber(nr), tonumber(gesamt)
    if not id or not nr or not gesamt or gesamt > 500 then return end
    local key = name .. ":" .. id
    local p = puffer[key] or { teile = {}, n = 0, zeit = GetTime() }
    puffer[key] = p
    if not p.teile[nr] then p.teile[nr] = stueck; p.n = p.n + 1 end
    if p.n < gesamt then return end
    puffer[key] = nil
    local code = table.concat(p.teile)
    T:Erhalten(code, name)
  end
end
T.Empfangen = Empfangen

-- Ein vollständiger Code ist angekommen: Fundorte gleich übernehmen, Routen je nach Einstellung.
function T:Erhalten(code, von)
  if code:sub(1, 4) == "FG1F" then
    if FG.db.empfangen then self:Importieren(code, von) end
    return
  end
  local wahl = FG.db.routenAnnehmen
  if wahl == "nie" then return end
  local art, r = self:CodeLesen(code, von)
  if art ~= "route" then return end
  if wahl == "immer" then self:Importieren(code, von); return end
  T.angebot = { code = code, von = von }
  if StaticPopup_Show then
    StaticPopup_Show("FOREVERGATHER_ROUTE", von, r.name)
  end
  FG:Sprechen(L"%s möchte dir die Route %s schicken.":format(von, r.name))
end

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs.FOREVERGATHER_ROUTE = {
  text = L"%s schickt dir die Farmroute „%s“. Übernehmen?",
  button1 = L"Übernehmen",
  button2 = L"Ablehnen",
  OnAccept = function()
    if T.angebot then T:Importieren(T.angebot.code, T.angebot.von) end
    T.angebot = nil
  end,
  OnCancel = function() T.angebot = nil end,
  timeout = 60, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function T:Start()
  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PRAEFIX)
  elseif RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(PRAEFIX) end
  FG:Ereignis("CHAT_MSG_ADDON", function(praefix, text, kanal, absender)
    praefix, text, absender = FG.Frei(praefix), FG.Frei(text), FG.Frei(absender)
    if praefix == PRAEFIX and type(text) == "string" and type(absender) == "string" then Empfangen(text, kanal, absender) end
  end)
  FG:Haken("neuerFund", FundSenden)
end

FG:Befehl({ "teilen" }, function(rest)
  local was, ziel = (rest or ""):match("^(%S*)%s*(.-)$")
  was = was:lower()
  local kanal, wem = T:GruppenKanal(), nil
  if ziel == "gilde" or ziel == "guild" then kanal = "GUILD"
  elseif ziel ~= "" then kanal, wem = "WHISPER", ziel end
  if was == "route" then
    local r = R.aktiv or R:AufKarte(P:Spieler())[1]
    if not r then FG:Ansage(L"Keine Route zum Teilen."); return end
    T:RouteSenden(r, kanal, wem)
  else
    T:FundorteSenden(P:Spieler(), kanal, wem)
  end
end, L"/fg teilen [route] [gilde | Name] – Fundorte dieser Gegend oder Route senden")

FG:Befehl({ "import" }, function(rest)
  if rest and rest ~= "" then T:Importieren(rest) else FG.Fenster:Oeffnen("teilen") end
end, L"/fg import [Code] – geteilten Code übernehmen")
