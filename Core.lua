-- Forever Harvest: Grundgerüst, Einstellungen, Fehlerprotokoll, Ereignisse, Befehle.
local ADDON, FG = ...
_G.ForeverGather = FG
local L = FG.L

local metadaten = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
FG.version = (metadaten and metadaten(ADDON, "Version")) or "dev"
if FG.version:find("@") then FG.version = "dev" end

FG.farben = {
  gold  = { 0.95, 0.77, 0.35 },
  hell  = { 0.93, 0.91, 0.86 },
  grau  = { 0.55, 0.55, 0.55 },
  gruen = { 0.45, 0.85, 0.45 },
  rot   = { 0.90, 0.35, 0.30 },
}
FG.gold = "|cfff2c45a"

FG.STANDARD = {
  eingerichtet = false,
  -- Was angezeigt wird
  zeigen = { kraut = true, erz = true, schatz = true },
  ausgeblendet = {},        -- [Typ] = true: einzelne Vorkommen ausblenden
  nurAbbaubar = false,      -- nur Vorkommen zeigen, die der Charakter schon abbauen kann
  nurEigenerBeruf = true,   -- Kräuter nur mit Kräuterkunde, Erze nur mit Bergbau
  weltkarte = true,
  minikarte = true,
  pinGroesse = 16,
  minikartePinGroesse = 13,
  minikarteRand = false,    -- entfernte Fundorte am Rand der Minikarte zeigen
  -- Erfassen
  zusammenfassen = 15,      -- Meter: so nah beieinander gilt als derselbe Fundort
  teilenGruppe = true,      -- neue Funde an die Gruppe senden (nur andere Forever-Gather-Nutzer)
  teilenGilde = false,      -- neue Funde an die Gilde senden
  empfangen = true,         -- Funde anderer annehmen
  routenAnnehmen = "fragen",-- fragen | immer | nie
  -- Hilfen
  ansage = false,           -- nahe Fundorte ansagen
  ansageEntfernung = 40,
  sitzungsAnzeige = false,  -- kleines Feld mit gesammelter Menge
  sitzungsPos = nil,
  wert = true,              -- Händlerpreis (oder Auktionspreis, falls ein Preisaddon da ist)
  materialTooltip = true,   -- Bestand aller Charaktere im Gegenstands-Tooltip
  vorkommenTooltip = true,  -- Fertigkeit im Tooltip eines Vorkommens
  -- Routen
  routeLinien = true,
  routeMinikarte = true,
  aufnahmeAbstand = 30,     -- Meter zwischen zwei Punkten bei der Aufnahme
  wegpunktAbstand = 25,     -- Meter, ab denen der nächste Punkt der Route dran ist
  -- 0.2
  abgeerntetMinuten = 5,    -- so lange gilt ein Fundort nach dem Ernten als leer (0 = aus)
  nurSkillpunkte = false,   -- nur Vorkommen, die noch Fertigkeitspunkte bringen
  radar = false,            -- Radar-Fenster mit den nächsten Fundorten
  radarPos = nil,
  radarZeilen = 5,
  klang = false,            -- Klang, wenn ein Fundort in Reichweite kommt
  kampfAusblenden = true,   -- im Kampf keine Symbole auf der Minikarte
  seltenHervorheben = true, -- seltene Vorkommen größer
  seltenAlarm = true,       -- Alarm, wenn ein seltenes Vorkommen in der Nähe ist
  kontinent = true,         -- Fundorte auch auf der Kontinentkarte
  zieleHervorheben = true,  -- Vorkommen mit offenem Sammelziel größer
  rundenAnsage = true,      -- Ansage, wenn eine Runde der Route geschafft ist
  -- Allgemein
  minimapKnopf = true,
  minimapWinkel = 200,
  fensterPos = nil,
  -- Barrierefreiheit
  vorlesen = false,
  kontrast = false,
  farbenblind = false,
  allesGroesser = false,
  wenigerBewegung = false,
  sprache = "auto",
}

---------------------------------------------------------------------------
-- Barrierefreiheit (Muster aus Questkompass)
---------------------------------------------------------------------------
local BASIS = {
  hell  = { 0.93, 0.91, 0.86 },
  grau  = { 0.55, 0.55, 0.55 },
  gruen = { 0.45, 0.85, 0.45 },
  rot   = { 0.90, 0.35, 0.30 },
}
local function setze(ziel, quelle) ziel[1], ziel[2], ziel[3] = quelle[1], quelle[2], quelle[3] end

function FG:BarrierefreiAnwenden()
  local db, f = self.db or {}, self.farben
  setze(f.hell, db.kontrast and { 1, 1, 1 } or BASIS.hell)
  setze(f.grau, db.kontrast and { 0.82, 0.82, 0.82 } or BASIS.grau)
  setze(f.gruen, db.farbenblind and { 0.35, 0.65, 1 } or BASIS.gruen)
  setze(f.rot, db.farbenblind and { 1, 0.6, 0.1 } or BASIS.rot)
end

function FG:Groesse() return (self.db and self.db.allesGroesser) and 1.25 or 1 end
function FG:Deckkraft(normal)
  return (self.db and self.db.kontrast) and math.max(normal, 0.92) or normal
end
function FG:ArtFarbe(art)
  local a = self.ARTEN[art] or self.ARTEN.kraut
  return (self.db and self.db.farbenblind) and a.farbenblind or a.farbe
end

local function sauber(text)
  text = tostring(text or "")
  text = text:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("%[(.-)%]", "%1")
  return (text:gsub("%s+", " "):gsub("^%s+", ""))
end
FG.Sauber = sauber

local stimme
local function Stimme()
  if stimme ~= nil then return stimme end
  stimme = false
  if C_TTSSettings and C_TTSSettings.GetVoiceOptionID and Enum and Enum.TtsVoiceType then
    local ok, id = pcall(C_TTSSettings.GetVoiceOptionID, Enum.TtsVoiceType.Standard)
    if ok and id then stimme = id end
  end
  if not stimme and C_VoiceChat and C_VoiceChat.GetTtsVoices then
    local ok, liste = pcall(C_VoiceChat.GetTtsVoices)
    if ok and liste and liste[1] then stimme = liste[1].voiceID end
  end
  return stimme
end

-- Liest einen Text mit der Sprachausgabe des Spiels vor. Gibt true zurück, wenn es geklappt hat.
function FG:Sprechen(text, immer)
  if not immer and not (self.db and self.db.vorlesen) then return false end
  text = sauber(text)
  if text == "" then return false end
  if TextToSpeech_Speak and TextToSpeech_GetSelectedVoice and Enum and Enum.TtsVoiceType then
    local ok = pcall(TextToSpeech_Speak, text, TextToSpeech_GetSelectedVoice(Enum.TtsVoiceType.Standard))
    if ok then return true end
  end
  if C_VoiceChat and C_VoiceChat.SpeakText then
    local id = Stimme()
    if id then
      local ziel = Enum and Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.LocalPlayback or 1
      if pcall(C_VoiceChat.SpeakText, id, text, ziel, 0, 100) then return true end
      if pcall(C_VoiceChat.SpeakText, id, text, 0, 100) then return true end
    end
  end
  return false
end

---------------------------------------------------------------------------
-- Geschützte Werte: Der Client von WoW Forever gibt manche Texte und Zahlen (z. B. in
-- Tooltips) als „geheime“ Werte heraus. Mit ihnen darf ein Addon weder vergleichen noch
-- sie als Tabellenschlüssel benutzen. FG.Frei liefert den Wert nur, wenn er benutzbar ist.
---------------------------------------------------------------------------
local function vergleichbar(v) return v == v end
function FG.Geheim(v)
  if v == nil then return false end
  if issecretvalue then
    local ok, geheim = pcall(issecretvalue, v)
    if not ok or geheim then return true end
  end
  return not pcall(vergleichbar, v)
end
function FG.Frei(v)
  if v == nil or FG.Geheim(v) then return nil end
  return v
end

---------------------------------------------------------------------------
-- Hilfen
---------------------------------------------------------------------------
local function kopie(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, w in pairs(v) do t[k] = kopie(w) end
  return t
end
FG.Kopie = kopie

local function ergaenze(ziel, vorlage)
  for k, v in pairs(vorlage) do
    if ziel[k] == nil then ziel[k] = kopie(v)
    elseif type(v) == "table" and type(ziel[k]) == "table" then ergaenze(ziel[k], v) end
  end
end
function FG:Standardwerte(ziel) ergaenze(ziel, self.STANDARD) end

function FG:Meldung(text, ...)
  DEFAULT_CHAT_FRAME:AddMessage(FG.gold .. "Forever Harvest:|r " .. FG.Einzahl(select("#", ...) > 0 and text:format(...) or text))
end

-- Meldung im Chat und, wenn eingeschaltet, vorlesen.
function FG:Ansage(text, ...)
  if select("#", ...) > 0 then text = text:format(...) end
  self:Meldung(text)
  self:Sprechen(text)
end

local function tausender(n, trenner)
  local s = tostring(math.floor(math.abs(n) + 0.5))
  local vorne = #s % 3
  if vorne == 0 then vorne = 3 end
  return (n < 0 and "-" or "") .. s:sub(1, vorne) .. s:sub(vorne + 1):gsub("(%d%d%d)", trenner .. "%1")
end
function FG:ZahlText(n)
  return tausender(tonumber(n) or 0, self.englischUI and "," or ".")
end

function FG:KommaText(n, stellen)
  local s = ("%." .. (stellen or 1) .. "f"):format(tonumber(n) or 0)
  if not self.englischUI then s = s:gsub("%.", ",") end
  return s
end

-- Geld in Gold/Silber/Kupfer, ohne Symbole (vorlesbar) oder mit Münzsymbolen.
function FG:GeldText(kupfer, schlicht)
  kupfer = math.floor(tonumber(kupfer) or 0)
  local g, s, k = math.floor(kupfer / 10000), math.floor(kupfer / 100) % 100, kupfer % 100
  local teile = {}
  if schlicht then
    if g > 0 then teile[#teile + 1] = g .. " " .. L"Gold" end
    if s > 0 then teile[#teile + 1] = s .. " " .. L"Silber" end
    if k > 0 or #teile == 0 then teile[#teile + 1] = k .. " " .. L"Kupfer" end
    return table.concat(teile, " ")
  end
  if g > 0 then teile[#teile + 1] = self:ZahlText(g) .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t" end
  if s > 0 then teile[#teile + 1] = s .. "|TInterface\\MoneyFrame\\UI-SilverIcon:0|t" end
  if k > 0 or #teile == 0 then teile[#teile + 1] = k .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0|t" end
  return table.concat(teile, " ")
end

function FG:ZeitText(sek)
  sek = math.max(0, math.floor((tonumber(sek) or 0) + 0.5))
  local h, m = math.floor(sek / 3600), math.floor(sek / 60) % 60
  if h > 0 then return ("%d:%02d:%02d"):format(h, m, sek % 60) end
  return ("%d:%02d"):format(m, sek % 60)
end

-- „vor 3 Tagen“ usw.
function FG:AlterText(zeitpunkt)
  if not zeitpunkt then return L"unbekannt" end
  local d = math.max(0, time() - zeitpunkt)
  if d < 3600 then return L"vor kurzem" end
  if d < 86400 then return L"vor %d Std.":format(math.floor(d / 3600)) end
  return FG.Einzahl(L"vor %d Tagen":format(math.floor(d / 86400)))
end

function FG:CharKey()
  return (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "?")
end

function FG:SpielZauberName(id)
  if C_Spell and C_Spell.GetSpellName then
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and n then return n end
  end
  if GetSpellInfo then
    local ok, n = pcall(GetSpellInfo, id)
    if ok and n then return n end
  end
end

---------------------------------------------------------------------------
-- Fehlerprotokoll: Fehler im Addon sollen nie die Oberfläche lahmlegen.
---------------------------------------------------------------------------
local gemeldet = false
function FG:Sicher(name, fn, ...)
  local ok, fehler = pcall(fn, ...)
  if not ok then
    local db = ForeverGatherDB
    if db then
      db.fehler = db.fehler or {}
      local eintrag = ("%s: %s"):format(name, tostring(fehler))
      if db.fehler[#db.fehler] ~= eintrag then
        table.insert(db.fehler, eintrag)
        while #db.fehler > 20 do table.remove(db.fehler, 1) end
      end
    end
    if not gemeldet then
      gemeldet = true
      FG:Meldung(L"|cffe05a4dEin Fehler ist aufgetreten (%s).|r /fg fehler zeigt Details.", name)
    end
  end
  return ok, fehler
end

---------------------------------------------------------------------------
-- Ereignisse, Module, Haken
---------------------------------------------------------------------------
local verteiler = CreateFrame("Frame")
local empfaenger = {}
FG.verteiler = verteiler
function FG:Ereignis(ereignis, fn)
  if not empfaenger[ereignis] then
    empfaenger[ereignis] = {}
    pcall(verteiler.RegisterEvent, verteiler, ereignis)
  end
  table.insert(empfaenger[ereignis], fn)
end
verteiler:SetScript("OnEvent", function(_, ereignis, ...)
  for _, fn in ipairs(empfaenger[ereignis] or {}) do
    FG:Sicher(ereignis, fn, ...)
  end
end)

FG.module = {}
function FG:Modul(name)
  local m = { name = name }
  self.module[#self.module + 1] = m
  FG[name] = m
  return m
end

-- Haken: andere Teile melden sich für Änderungen an (z. B. „fundorte“, „routen“).
local haken = {}
function FG:Haken(name, fn)
  haken[name] = haken[name] or {}
  table.insert(haken[name], fn)
end
function FG:Rufe(name, ...)
  for _, fn in ipairs(haken[name] or {}) do
    local ok, f = pcall(fn, ...)
    if not ok then FG:Sicher(name, error, f, 0) end
  end
end

function FG:Anwenden()
  self:BarrierefreiAnwenden()
  for _, m in ipairs(self.module) do
    if m.Anwenden then FG:Sicher(m.name, m.Anwenden, m) end
  end
end

---------------------------------------------------------------------------
-- Profile: Einstellungen für alle Charaktere („konto“) oder nur für diesen („eigen“).
---------------------------------------------------------------------------
function FG:ProfilLaden()
  local root, char = ForeverGatherDB, ForeverGatherCharDB
  root.konto = root.konto or {}
  if char.profil == "eigen" then
    char.einstellungen = char.einstellungen or kopie(root.konto)
    self.db = char.einstellungen
  else
    self.db = root.konto
  end
  self:Standardwerte(self.db)
  self:BarrierefreiAnwenden()
end

function FG:ProfilWechseln(art)
  ForeverGatherCharDB.profil = art
  if art == "eigen" and not ForeverGatherCharDB.einstellungen then
    ForeverGatherCharDB.einstellungen = kopie(self.db)
  end
  self:ProfilLaden()
  self:Anwenden()
end

function FG:SpracheAnwenden()
  local s = self.db and self.db.sprache
  if s == "de" then self.englischUI = false
  elseif s == "en" then self.englischUI = true
  else self.englischUI = GetLocale() ~= "deDE" end
end

FG:Ereignis("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  ForeverGatherDB = ForeverGatherDB or {}
  ForeverGatherCharDB = ForeverGatherCharDB or {}
  local root = ForeverGatherDB
  root.fundorte = root.fundorte or {}     -- [Karte] = { { x, y, t = Typ, n = Anzahl, z = Zeit, q = Quelle } }
  root.typen = root.typen or {}           -- gelernte Vorkommen: [Typ] = { art, name, item }
  root.routen = root.routen or {}         -- siehe Routen.lua
  root.charaktere = root.charaktere or {} -- siehe Lager.lua
  root.tage = root.tage or {}             -- Tagesstatistik [JJJJ-MM-TT] (Statistik.lua)
  root.gesamt = root.gesamt or {}         -- [Gegenstand] = Menge insgesamt
  ForeverGatherCharDB.ziele = ForeverGatherCharDB.ziele or {} -- [Gegenstand] = Zielmenge
  root.version = 1
  FG.root, FG.char = root, ForeverGatherCharDB
  FG:ProfilLaden()
  FG:SpracheAnwenden()
end)

FG:Ereignis("PLAYER_LOGIN", function()
  for _, m in ipairs(FG.module) do
    if m.Start then FG:Sicher(m.name, m.Start, m) end
  end
  FG:Anwenden()
  if not FG.db.eingerichtet and FG.Fenster then
    C_Timer.After(3, function() FG:Sicher("Willkommen", FG.Fenster.Oeffnen, FG.Fenster, "start") end)
  end
end)

---------------------------------------------------------------------------
-- Befehle
---------------------------------------------------------------------------
local HILFE = {
  L"/fg – Fenster öffnen oder schließen",
  L"/fg einstellungen – alle Einstellungen",
  L"/fg diagnose | fehler – technische Infos für Fehlerberichte",
}

local ALIAS = {
  settings = "einstellungen", options = "einstellungen", errors = "fehler", language = "sprache",
  help = "hilfe", ["?"] = "hilfe", nearest = "naechster", ["nächster"] = "naechster", route = "route",
  routes = "route", stock = "lager", session = "sitzung", share = "teilen", import = "import",
  record = "aufnahme", read = "vorlesen", show = "zeigen", hide = "zeigen", factory = "werkseinstellung",
}

FG.befehle = {}
function FG:Befehl(namen, fn, hilfe)
  for _, n in ipairs(namen) do FG.befehle[n] = fn end
  if hilfe then table.insert(HILFE, #HILFE, hilfe) end
end

SLASH_FOREVERGATHER1 = "/fg"
SLASH_FOREVERGATHER2 = "/forevergather"
SlashCmdList.FOREVERGATHER = function(eingabe)
  local befehl, rest = (eingabe or ""):match("^%s*(%S*)%s*(.-)%s*$")
  befehl = befehl:lower()
  befehl = ALIAS[befehl] or befehl
  FG:Sicher("Befehl", function()
    if befehl == "" then
      FG.Fenster:Umschalten()
    elseif befehl == "hilfe" then
      FG:Meldung(L"Version %s", FG.version)
      for _, zeile in ipairs(HILFE) do DEFAULT_CHAT_FRAME:AddMessage("  " .. zeile) end
    elseif befehl == "einstellungen" or befehl == "optionen" or befehl == "config" then
      FG.Fenster:Oeffnen("einstellungen")
    elseif befehl == "werkseinstellung" then
      wipe(FG.db)
      FG:Standardwerte(FG.db)
      FG.db.eingerichtet = true
      FG:Anwenden()
      FG:Meldung(L"Einstellungen zurückgesetzt.")
    elseif befehl == "diagnose" then
      FG:Diagnose(true)
    elseif befehl == "fehler" then
      local liste = FG.root.fehler
      if not liste or #liste == 0 then
        FG:Meldung(L"keine Fehler aufgezeichnet.")
      else
        FG:Meldung(L"die letzten %d Fehler:", #liste)
        for _, f in ipairs(liste) do DEFAULT_CHAT_FRAME:AddMessage("  " .. f) end
      end
    elseif FG.befehle[befehl] then
      FG.befehle[befehl](rest)
    else
      FG:Meldung(L"unbekannter Befehl. /fg hilfe zeigt alle Befehle.")
    end
  end)
end

FG:Befehl({ "sprache" }, function(rest)
  rest = (rest or ""):lower()
  if rest ~= "de" and rest ~= "en" and rest ~= "auto" then
    FG:Meldung("/fg sprache de | en | auto")
    return
  end
  FG.db.sprache = rest
  FG:SpracheAnwenden()
  FG:Meldung(L"Sprache geändert. Ganz wirkt sie nach /reload.")
end, L"/fg sprache de | en | auto – Sprache der Oberfläche")

-- Diagnose: schreibt, welche Schnittstellen das Spiel anbietet, in ForeverGatherDB.diagnose.
function FG:Diagnose(zeigen)
  local d = {
    version = self.version,
    build = GetBuildInfo and select(4, GetBuildInfo()) or nil,
    karte = C_Map and C_Map.GetBestMapForUnit and true or false,
    weltpos = C_Map and C_Map.GetWorldPosFromMapPos and true or false,
    weltkarte = WorldMapFrame and WorldMapFrame.ScrollContainer and true or false,
    wegpunkt = C_Map and C_Map.SetUserWaypoint and true or false,
    supertrack = C_SuperTrack and true or false,
    container = C_Container and true or false,
    berufe = GetProfessions and true or false,
    sprache = GetLocale and GetLocale() or "?",
    zauber = {},
  }
  for id, art in pairs(self.SAMMELZAUBER) do
    local n = self:SpielZauberName(id)
    if n then d.zauber[#d.zauber + 1] = id .. "=" .. n .. " (" .. art .. ")" end
  end
  table.sort(d.zauber)
  local anzahl, karten = 0, 0
  for _, liste in pairs(self.root.fundorte) do karten = karten + 1; anzahl = anzahl + #liste end
  d.fundorte, d.karten = anzahl, karten
  self.root.diagnose = d
  if zeigen then
    self:Meldung(L"Version %s, Spiel %s, %d Fundorte auf %d Karten.", tostring(d.version), tostring(d.build), anzahl, karten)
    self:Meldung(L"Karte %s, Weltposition %s, Weltkarte %s, Wegpunkte %s, Berufe %s.",
      tostring(d.karte), tostring(d.weltpos), tostring(d.weltkarte), tostring(d.wegpunkt), tostring(d.berufe))
    self:Meldung(L"Gespeichert in ForeverGatherDB.diagnose (nach /reload in der Datei).")
  end
  return d
end

---------------------------------------------------------------------------
-- Tastenkürzel (Bindings.xml)
---------------------------------------------------------------------------
BINDING_HEADER_FOREVERGATHER = "Forever Harvest"
BINDING_NAME_FOREVERGATHER_FENSTER = L"Fenster öffnen oder schließen"
BINDING_NAME_FOREVERGATHER_ANZEIGE = L"Fundorte auf den Karten ein oder aus"
BINDING_NAME_FOREVERGATHER_NAECHSTER = L"Wegpunkt zum nächsten Fundort"
BINDING_NAME_FOREVERGATHER_ROUTE = L"Route starten oder anhalten"
BINDING_NAME_FOREVERGATHER_WEITER = L"Nächster Punkt der Route"
BINDING_NAME_FOREVERGATHER_AUFNAHME = L"Routenaufnahme starten oder beenden"
BINDING_NAME_FOREVERGATHER_VORLESEN = L"Umgebung vorlesen"
BINDING_NAME_FOREVERGATHER_SITZUNG = L"Sitzungsanzeige ein oder aus"
BINDING_NAME_FOREVERGATHER_EINSTELLUNGEN = L"Einstellungen öffnen"
BINDING_NAME_FOREVERGATHER_RADAR = L"Radar ein oder aus"
BINDING_NAME_FOREVERGATHER_MERKEN = L"Vorkommen unter der Maus merken"

FG.tasten = {}
function FG:Taste(was)
  FG:Sicher("Taste", function()
    if FG.tasten[was] then FG.tasten[was]() end
  end)
end
