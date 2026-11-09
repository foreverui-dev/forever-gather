-- Testlauf ohne Spiel: stellt die benötigten WoW-Funktionen nach, lädt das Addon in
-- TOC-Reihenfolge und spielt Sammeln, Karten, Routen, Teilen, Lager und Fenster durch.
-- Aufruf aus dem Addon-Ordner: lua5.1 tests/simulation.lua
local fehler, geprueft = 0, 0
local function pruefe(bed, text)
  geprueft = geprueft + 1
  if bed then print("  ok    " .. text) else print("  FEHLER " .. text); fehler = fehler + 1 end
end

local toc = {}
for zeile in io.lines("ForeverGather.toc") do
  if not zeile:match("^##") and zeile:match("%S") then toc[#toc + 1] = (zeile:gsub("\\", "/")) end
end

---------------------------------------------------------------------------
-- Spielwelt nachbauen
---------------------------------------------------------------------------
local chat, gesendet, gesprochen, popups = {}, {}, {}, {}
local function NeuesObjekt(typ)
  local o = { art = typ, gezeigt = typ ~= "Frame" or true, skripte = {}, ereignisse = {}, text = "" }
  return setmetatable(o, { __index = function(t, k)
    local f = ({
      SetText = function(s, x) s.text = x end,
      GetText = function(s) return s.text end,
      SetFormattedText = function(s, fmt, ...) s.text = fmt:format(...) end,
      SetScript = function(s, n, fn) s.skripte[n] = fn end,
      GetScript = function(s, n) return s.skripte[n] end,
      HookScript = function(s, n, fn) local alt = s.skripte[n]; s.skripte[n] = function(...) if alt then alt(...) end fn(...) end end,
      Show = function(s) local war = s.gezeigt; s.gezeigt = true; if s.skripte.OnShow and not war then s.skripte.OnShow(s) end end,
      Hide = function(s) local war = s.gezeigt; s.gezeigt = false; if war and s.skripte.OnHide then s.skripte.OnHide(s) end end,
      IsShown = function(s) return s.gezeigt end,
      SetShown = function(s, v) if v then s:Show() else s:Hide() end end,
      CreateFontString = function() return NeuesObjekt("FontString") end,
      CreateTexture = function() return NeuesObjekt("Texture") end,
      CreateLine = function() return NeuesObjekt("Line") end,
      RegisterEvent = function(s, e) s.ereignisse[e] = true end,
      SetChecked = function(s, v) s.an = v end,
      GetChecked = function(s) return s.an end,
      Click = function(s, taste) if s.skripte.OnClick then s.skripte.OnClick(s, taste or "LeftButton") end end,
      GetWidth = function(s) return s.breite or 200 end,
      SetWidth = function(s, v) s.breite = v end,
      SetSize = function(s, b, h) s.breite, s.hoehe = b, h end,
      GetHeight = function(s) return s.hoehe or 200 end,
      GetScale = function() return 1 end,
      GetEffectiveScale = function() return 1 end,
      GetFrameLevel = function() return 1 end,
      GetCenter = function() return 500, 500 end,
      GetPoint = function() return "CENTER", nil, "CENTER", 10, 20 end,
      SetPoint = function(s, ...) s.punkt = { ... } end,
      GetName = function() return "GameTooltip" end,
      HasFocus = function() return false end,
      GetZoom = function() return 0 end,
      AddLine = function(s, x) s.zeilen = s.zeilen or {}; s.zeilen[#s.zeilen + 1] = x end,
      AddDoubleLine = function(s, a, b) s.zeilen = s.zeilen or {}; s.zeilen[#s.zeilen + 1] = a .. " | " .. b end,
      SetOwner = function(s) s.zeilen = {} end,
    })[k]
    if f then return f end
    if type(k) == "string" and k:match("^%u") then return function() end end
  end })
end
CreateFrame = function(typ, name)
  local f = NeuesObjekt(typ)
  if name then _G[name] = f end
  return f
end
UIParent = NeuesObjekt("Frame")
Minimap = NeuesObjekt("Frame"); Minimap.breite = 140
GameTooltip = NeuesObjekt("GameTooltip")
GameTooltipTextLeft1 = NeuesObjekt("FontString")
ItemRefTooltip = NeuesObjekt("GameTooltip")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
UISpecialFrames, SlashCmdList, StaticPopupDialogs = {}, {}, {}
StaticPopup_Show = function(name, a, b) popups[#popups + 1] = { name, a, b } end
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
local timer = {}
C_Timer = { After = function(_, fn) timer[#timer + 1] = fn end }
local function Timer() local n = 0; while #timer > 0 and n < 500 do n = n + 1; table.remove(timer, 1)() end end
C_AddOns = { GetAddOnMetadata = function() return "@project-version@" end }
local jetzt = 1000
GetTime = function() return jetzt end
local uhrVersatz = 0
date = os.date
time = function() return os.time() + uhrVersatz end
hooksecurefunc = function() end
GetLocale = function() return "deDE" end
GetRealmName = function() return "Forever" end
UnitName = function(e) return e == "player" and "Baumkuschler" or nil end
UnitClass = function() return "Druide", "DRUID", 11 end
UnitFactionGroup = function() return "Horde" end
IsInGroup = function() return true end
IsInRaid = function() return false end
IsInGuild = function() return true end
IsShiftKeyDown = function() return false end
local strg = false
IsControlKeyDown = function() return strg end
local imKampf = false
UnitAffectingCombat = function() return imKampf end
local alarme, chatGesendet, karteGeoeffnet = {}, {}, nil
RaidNotice_AddMessage = function(_, t) alarme[#alarme + 1] = t end
RaidWarningFrame = {}
PlaySound = function() end
SendChatMessage = function(t, k) chatGesendet[#chatGesendet + 1] = k .. ":" .. t end
OpenWorldMap = function(k) karteGeoeffnet = k end
Ambiguate = function(n) return (n:match("^[^-]+")) end
GetBuildInfo = function() return "1.60.1", "70399", "Nov 1 2026", 16001 end
RAID_CLASS_COLORS = { DRUID = { r = 1, g = 0.49, b = 0.04 } }
Enum = { TtsVoiceType = { Standard = 0 }, TooltipDataType = { Item = 0 } }
TextToSpeech_Speak = function(t) gesprochen[#gesprochen + 1] = t end
TextToSpeech_GetSelectedVoice = function() return 1 end
local cvars = { rotateMinimap = "0", minimapZoom = "0", minimapInsideZoom = "2" }
GetCVar = function(n) return cvars[n] end
local blick = 0
GetPlayerFacing = function() return blick end

-- Karte: Durotar 1411, 5000 × 3000 Meter
local KARTE = 1411
local spieler = { karte = KARTE, x = 0.5, y = 0.5 }
CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(s) return s.x, s.y end } end
local wegpunkt
C_Map = {
  GetBestMapForUnit = function() return spieler.karte end,
  GetPlayerMapPosition = function() return CreateVector2D(spieler.x, spieler.y) end,
  GetMapWorldSize = function(k) if k == KARTE then return 5000, 3000 end end,
  GetWorldPosFromMapPos = function(k, v) return 1, CreateVector2D(-v.y * 3000, -v.x * 5000) end,
  GetMapInfo = function(k) return { name = (k == KARTE and "Durotar") or (k == 12 and "Kalimdor") or "Brachland", mapType = k == 12 and 2 or 3 } end,
  GetMapRectOnMap = function(k, eltern) if eltern == 12 and k == KARTE then return 0.5, 0.6, 0.4, 0.5 end end,
  CanSetUserWaypointOnMap = function() return true end,
  SetUserWaypoint = function(p) wegpunkt = p end,
  ClearUserWaypoint = function() wegpunkt = nil end,
}
UiMapPoint = { CreateFromCoordinates = function(k, x, y) return { karte = k, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
local function Gehe(x, y) spieler.x, spieler.y = x, y end
local function Meter(dx, dy) Gehe(spieler.x + dx / 5000, spieler.y + dy / 3000) end

-- Weltkarte
local leinwand = NeuesObjekt("Frame"); leinwand.breite, leinwand.hoehe = 1000, 667
WorldMapFrame = NeuesObjekt("Frame")
WorldMapFrame.gezeigt = false
WorldMapFrame.ScrollContainer = { Child = leinwand, GetCanvasScale = function() return 1 end }
local kartenId = KARTE
WorldMapFrame.GetMapID = function() return kartenId end

-- Berufe
local berufe = { { "Kräuterkunde", 60, 182 } }
GetProfessions = function() return berufe[1] and 1 or nil, berufe[2] and 2 or nil end
GetProfessionInfo = function(i) local b = berufe[i]; return b[1], 0, b[2], 300, 0, 0, b[3] end

-- Zauber und Beute
local ZAUBER = { [2366] = "Kräutersammeln", [2575] = "Bergbau", [3365] = "Öffnen", [133] = "Feuerball" }
C_Spell = { GetSpellName = function(id) return ZAUBER[id] end }
local beute = {}
GetNumLootItems = function() return #beute end
GetLootSourceInfo = function(i) return beute[i] and beute[i].guid end
GetLootSlotLink = function(i) return beute[i] and ("|cffffffff|Hitem:%d::::|h[x]|h|r"):format(beute[i].item) end
GetLootSlotInfo = function(i) return 0, "x", beute[i].menge end
GetItemInfo = function(item) return "Gegenstand " .. item, nil, 1, 1, 1, "", "", 20, "", 0, item == 2447 and 10 or 25 end

-- Taschen und Bank
local taschen = { [0] = { { 2447, 10 }, { 765, 4 } }, [-1] = { { 2770, 20 } } }
C_Container = {
  GetContainerNumSlots = function(t) return taschen[t] and #taschen[t] or 0 end,
  GetContainerItemInfo = function(t, p) local e = taschen[t] and taschen[t][p]; if e then return { itemID = e[1], stackCount = e[2] } end end,
}
local tooltipRuf
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) tooltipRuf = fn end }

-- Addon-Nachrichten
C_ChatInfo = {
  RegisterAddonMessagePrefix = function() end,
  SendAddonMessage = function(p, t, k, z) gesendet[#gesendet + 1] = { p, t, k, z } end,
}

---------------------------------------------------------------------------
-- Addon laden
---------------------------------------------------------------------------
local ns = {}
for _, datei in ipairs(toc) do assert(loadfile(datei))("ForeverGather", ns) end
local FG = ForeverGather
pruefe(FG ~= nil and FG.Fundorte and FG.Routen and FG.Teilen, "Addon geladen (" .. #toc .. " Dateien)")
local V = FG.verteiler
local function Ereignis(name, ...) V.skripte.OnEvent(V, name, ...) end
Ereignis("ADDON_LOADED", "ForeverGather")
Ereignis("PLAYER_LOGIN")
Timer()
local F, R, T, La, M, W, P = FG.Fundorte, FG.Routen, FG.Teilen, FG.Lager, FG.Minikarte, FG.Weltkarte, FG.Position
pruefe(ForeverGatherFenster and ForeverGatherFenster:IsShown(), "Willkommensfenster beim ersten Start")
FG.Fenster:Schliessen()
pruefe(FG.db.eingerichtet == true, "nach dem Schließen als eingerichtet markiert")

print("-- Position")
local b, h = P:Groesse(KARTE)
pruefe(b == 5000 and h == 3000, "Kartengröße")
pruefe(math.floor(P:Entfernung(KARTE, 0.5, 0.5, 0.51, 0.5) + 0.5) == 50, "Entfernung 50 m")
pruefe(P:Uhr(100, 0) == 3, "Osten bei Blick nach Norden ist 3 Uhr")
blick = math.pi / 2  -- Blick nach Westen
pruefe(P:Uhr(0, -100) == 3, "Norden bei Blick nach Westen ist 3 Uhr")
blick = 0

---------------------------------------------------------------------------
print("-- Sammeln")
local function Sammeln(zauber, ziel, objekt, items, fehlschlag)
  jetzt = jetzt + 5
  Ereignis("UNIT_SPELLCAST_SENT", "player", ziel, "Cast-" .. jetzt, zauber)
  if fehlschlag then Ereignis("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-" .. jetzt, zauber); Timer(); return end
  Ereignis("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. jetzt, zauber)
  beute = {}
  for _, it in ipairs(items or {}) do
    beute[#beute + 1] = { item = it[1], menge = it[2], guid = objekt and ("GameObject-0-3299-0-16540-%d-0000AF%04d"):format(objekt, jetzt % 10000) }
  end
  if #beute > 0 then Ereignis("LOOT_OPENED") end
  Timer()
end

Gehe(0.40, 0.40)
Sammeln(2366, "Friedensblume", 1618, { { 2447, 3 } })
local liste = F:Liste(KARTE)
pruefe(#liste == 1 and liste[1].t == "o1618" and liste[1].n == 1, "Friedensblume erfasst")
pruefe(FG.sitzung.items[2447] == 3 and FG.sitzung.funde == 1, "Sitzung zählt 3 Friedensblumen")
pruefe(FG.sitzung.wert == 30, "Wert aus Händlerpreis: " .. FG.sitzung.wert)
local f1 = gesendet[#gesendet]
pruefe(f1 and f1[3] == "PARTY" and f1[2]:match("^F~1411~o1618~k~"), "Fund an die Gruppe gesendet")

Meter(5, 0)
Sammeln(2366, "Friedensblume", 1618, { { 2447, 2 } })
pruefe(#F:Liste(KARTE) == 1 and F:Liste(KARTE)[1].n == 2, "naher Fund zusammengelegt")
Meter(100, 0)
Sammeln(2366, "Silberblatt", 1617, { { 765, 1 } })
Meter(0, 120)
Sammeln(2366, "Friedensblume", nil, { { 2447, 1 } })  -- ohne Objektnummer: über den Namen erkannt
pruefe(F:Liste(KARTE)[3].t == "o1618", "Typ über Namen erkannt")
Meter(-150, 40)
Sammeln(2366, "Seltsames Kraut", 999001, { { 777001, 1 } })
local unbekannt = F:Liste(KARTE)[4]
pruefe(unbekannt and unbekannt.t == "o999001" and F:Name("o999001") == "Seltsames Kraut", "unbekanntes Vorkommen gelernt")
pruefe(FG.root.typen.o999001.item == 777001, "Material des unbekannten Vorkommens gemerkt")
Meter(30, 30)
Sammeln(2366, "Erdwurzel", 1619, nil, true)
pruefe(#F:Liste(KARTE) == 4, "abgebrochener Versuch wird nicht gespeichert")
Sammeln(133, "Hogger", nil, {})
pruefe(#F:Liste(KARTE) == 4, "andere Zauber werden ignoriert")
-- Erfolg ohne Beutefenster (volle Taschen): Ort trotzdem merken
Meter(200, 0)
jetzt = jetzt + 5
Ereignis("UNIT_SPELLCAST_SENT", "player", "Silberblatt", "Cast-x", 2366)
Ereignis("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-x", 2366)
Timer()
pruefe(#F:Liste(KARTE) == 5, "Fund ohne Beutefenster gemerkt")
Meter(50, 50)
Sammeln(2575, "Kupferader", 1731, { { 2770, 2 }, { 2835, 1 } })
pruefe(#F:Liste(KARTE) == 6 and F:Art("o1731") == "erz", "Kupferader erfasst")
pruefe(not F:Sichtbar("o1731"), "ohne Bergbau ausgeblendet (nur eigene Berufe)")
berufe[2] = { "Bergbau", 1, 186 }
Ereignis("SKILL_LINES_CHANGED")
pruefe(F:Sichtbar("o1731"), "mit Bergbau sichtbar")
pruefe(F:Abbaubar("o1620") == true and F:Abbaubar("o1621") == false, "Fertigkeit 60: Maguskönigskraut ja, Wilddornrose nein")
FG.db.nurAbbaubar = true
pruefe(not F:Sichtbar("o1621") and F:Sichtbar("o1618"), "nur abbaubare")
FG.db.nurAbbaubar = false
FG.db.zeigen.erz = false
pruefe(not F:Sichtbar("o1731"), "Erze ausgeschaltet")
FG.db.zeigen.erz = true
Sammeln(3365, "Ramponierte Truhe", 2843, { { 2447, 1 } })
pruefe(F:Art(F:Liste(KARTE)[7].t) == "schatz", "Schatztruhe als Schatz erfasst")

---------------------------------------------------------------------------
print("-- Minikarte")
Gehe(0.40, 0.40)
M.Takt()
pruefe(M.anzahl and M.anzahl >= 1 and M.anzahl < 7, "nahe Fundorte auf der Minikarte: " .. tostring(M.anzahl))
local vorher = M.anzahl
FG.db.minikarteRand = true
M.Takt()
pruefe(M.anzahl == 7, "mit Rand alle sieben: " .. M.anzahl)
FG.db.minikarteRand = false
cvars.rotateMinimap = "1"; blick = 1
M.Takt()
pruefe(M.anzahl == vorher, "drehende Minikarte zeigt dieselben Fundorte")
cvars.rotateMinimap = "0"; blick = 0
local x, y = M:Versatz(100, 0, 200, false)
pruefe(math.abs(x - 35) < 0.01 and math.abs(y) < 0.01, "Osten liegt rechts")
x, y = M:Versatz(0, -100, 200, false)
pruefe(math.abs(y - 35) < 0.01, "Norden liegt oben")
pruefe(F:Abgeerntet(F:Liste(KARTE)[1]), "frisch geerntet gilt als leer")
uhrVersatz = uhrVersatz + 600
pruefe(not F:Abgeerntet(F:Liste(KARTE)[1]), "nach 10 Minuten nachgewachsen")
FG.db.ansage = true; FG.db.vorlesen = true
local vorherGesprochen = #gesprochen
M.Takt()
pruefe(#gesprochen > vorherGesprochen and gesprochen[#gesprochen]:find("Friedensblume"), "naher Fundort angesagt: " .. tostring(gesprochen[#gesprochen]))
local n = #gesprochen
M.Takt()
pruefe(#gesprochen == n, "nicht doppelt angesagt")
FG.db.ansage = false

print("-- Weltkarte")
WorldMapFrame:Show()
V.skripte.OnEvent(V, "X")
WorldMapFrame.skripte.OnShow(WorldMapFrame)
pruefe(W.anzahl == 7, "Weltkarte zeigt 7 Fundorte")
kartenId = 1413
W.waechter.skripte.OnUpdate(W.waechter, 0.2)
pruefe(W.anzahl == 0, "andere Karte: keine Fundorte")
kartenId = KARTE
W.waechter.skripte.OnUpdate(W.waechter, 0.2)
pruefe(W.anzahl == 7, "zurück auf Durotar")
local fund = F:Liste(KARTE)[1]
W:FundTooltip(GameTooltip, KARTE, fund)
pruefe(GameTooltip.zeilen[1] == "Friedensblume" and GameTooltip.zeilen[2]:find("abbaubar"), "Tooltip mit Fertigkeit")
W:FundKlick(KARTE, fund, "LeftButton")
pruefe(wegpunkt and wegpunkt.karte == KARTE and wegpunkt.x == fund.x, "Klick setzt Wegpunkt")
W:FundKlick(KARTE, F:Liste(KARTE)[4], "RightButton")
pruefe(popups[#popups][1] == "FOREVERGATHER_LOESCHEN", "Rechtsklick fragt nach dem Löschen")
StaticPopupDialogs.FOREVERGATHER_LOESCHEN.OnAccept()
pruefe(#F:Liste(KARTE) == 6, "Fundort gelöscht")
IsShiftKeyDown = function() return true end
W:FundKlick(KARTE, F:Liste(KARTE)[1], "RightButton")
IsShiftKeyDown = function() return false end
pruefe(FG.db.ausgeblendet.o1618 and not F:Sichtbar("o1618"), "Umschalt+Rechtsklick blendet Sorte aus")
FG.db.ausgeblendet.o1618 = nil

---------------------------------------------------------------------------
print("-- Routen")
-- vier Ecken über Kreuz: der Rundweg muss das Quadrat ergeben (Umfang 4 × 300 m)
local quadrat = R:Rundweg(KARTE, { { 0.1, 0.1 }, { 0.16, 0.2 }, { 0.16, 0.1 }, { 0.1, 0.2 } })
local r0 = { karte = KARTE, punkte = {}, rund = true }
for _, p in ipairs(quadrat) do r0.punkte[#r0.punkte + 1] = p[1]; r0.punkte[#r0.punkte + 1] = p[2] end
pruefe(math.floor(R:Laenge(r0) + 0.5) == 1200, "kürzester Rundweg ohne Kreuzung: " .. R:Laenge(r0))
-- zufällige Punkte: 2-opt darf nie länger sein als die Reihenfolge der Eingabe
math.randomseed(7)
local zufall = {}
for i = 1, 40 do zufall[i] = { math.random(), math.random() } end
local roh = { karte = KARTE, punkte = {}, rund = true }
for _, p in ipairs(zufall) do roh.punkte[#roh.punkte + 1] = p[1]; roh.punkte[#roh.punkte + 1] = p[2] end
local weg = R:Rundweg(KARTE, zufall)
local opt = { karte = KARTE, punkte = {}, rund = true }
for _, p in ipairs(weg) do opt.punkte[#opt.punkte + 1] = p[1]; opt.punkte[#opt.punkte + 1] = p[2] end
pruefe(#weg == 40 and R:Laenge(opt) < R:Laenge(roh) * 0.5, ("40 Punkte: %d m statt %d m"):format(R:Laenge(opt), R:Laenge(roh)))

local route = R:AusFundorten(KARTE, "kraut")
pruefe(route and #route.punkte / 2 == 4 and route.name:find("Durotar"), "Route aus Kräuter-Fundorten")
local fehlt, grund = R:AusFundorten(1413)
pruefe(not fehlt and grund, "zu wenige Fundorte: Hinweis")
Gehe(route.punkte[1], route.punkte[2])
R:Starten(route)
pruefe(R.aktiv == route and R.index == 1 and wegpunkt.x == route.punkte[1], "Route gestartet beim nächsten Punkt")
R:Takt()
pruefe(R.index == 2, "Punkt erreicht: weiter zu Punkt 2")
R:Weiter()
pruefe(R.index == 3, "Nächster Punkt per Taste")
R:Weiter(); R:Weiter()
pruefe(R.index == 1, "Rundweg beginnt von vorn")
WorldMapFrame.skripte.OnShow(WorldMapFrame)
R:Umkehren(route)
pruefe(R.index == 4, "Umkehren behält den Punkt")
R:Anhalten()
pruefe(not R.aktiv and not wegpunkt, "Route angehalten")

Gehe(0.6, 0.6)
R:AufnahmeStarten()
for _ = 1, 10 do Meter(20, 0); R:Takt() end
for _ = 1, 10 do Meter(0, 20); R:Takt() end
local aufgenommen = R:AufnahmeBeenden()
pruefe(aufgenommen and #aufgenommen.punkte / 2 >= 10 and #aufgenommen.punkte / 2 <= 15, "Aufnahme mit Punkten alle 30 m: " .. (aufgenommen and #aufgenommen.punkte / 2 or 0))
R:AufnahmeStarten(); R:AufnahmeBeenden()
pruefe(#R:Liste() == 2, "zu kurze Aufnahme verworfen")

---------------------------------------------------------------------------
print("-- Teilen")
local code = T:RoutenCode(route)
local art, gelesen = T:CodeLesen(code)
pruefe(art == "route" and gelesen.name == route.name and #gelesen.punkte == #route.punkte, "Routencode gelesen")
local abw = 0
for i = 1, #route.punkte do abw = math.max(abw, math.abs(gelesen.punkte[i] - route.punkte[i])) end
pruefe(abw < 0.0002, "Koordinaten genau genug")
pruefe(not T:CodeLesen(code:sub(1, -8) .. "AAAA" .. code:sub(-3)), "beschädigter Code wird erkannt")
pruefe(not T:CodeLesen("hallo"), "fremder Text wird erkannt")

local fcode, anzahl = T:FundortCode()
pruefe(fcode and anzahl == 6, "Fundort-Code mit 6 Fundorten")
local sicher = FG.Kopie(FG.root.fundorte)
wipe(FG.root.fundorte)
T:Importieren(fcode, "Freund")
pruefe(F:Anzahl() == 6 and F:Liste(KARTE)[1].q == "Freund", "Fundorte importiert")
T:Importieren(fcode, "Freund")
pruefe(F:Anzahl() == 6, "doppelter Import legt zusammen")
FG.root.fundorte = sicher

-- live geteilter Fund
Ereignis("CHAT_MSG_ADDON", "FGather", "F~1411~o1733~e~" .. T.Koord(0.7) .. T.Koord(0.3), "PARTY", "Kumpel-Forever")
local neu = F:Liste(KARTE)[#F:Liste(KARTE)]
pruefe(neu.t == "o1733" and neu.q == "Kumpel" and math.abs(neu.x - 0.7) < 0.001, "Fund aus der Gruppe übernommen")
Ereignis("CHAT_MSG_ADDON", "FGather", "F~kaputt", "PARTY", "Kumpel-Forever")
Ereignis("CHAT_MSG_ADDON", "FGather", "F~1411~o1733~e~" .. T.Koord(0.2) .. T.Koord(0.2), "PARTY", "Baumkuschler-Forever")
pruefe(F:Anzahl("o1733") == 1, "eigene und kaputte Nachrichten ignoriert")

-- Route in Stücken senden und empfangen
local n0 = #gesendet
T:RouteSenden(aufgenommen, "PARTY")
Timer()
local stuecke = {}
for i = n0 + 1, #gesendet do stuecke[#stuecke + 1] = gesendet[i][2] end
pruefe(#stuecke >= 1 and stuecke[1]:match("^C~"), ("Route in %d Stück(en) gesendet"):format(#stuecke))
local routenVorher = #R:Liste()
for i = #stuecke, 1, -1 do Ereignis("CHAT_MSG_ADDON", "FGather", stuecke[i], "PARTY", "Kumpel-Forever") end
pruefe(popups[#popups][1] == "FOREVERGATHER_ROUTE" and popups[#popups][2] == "Kumpel", "Nachfrage bei geschickter Route")
StaticPopupDialogs.FOREVERGATHER_ROUTE.OnAccept()
pruefe(#R:Liste() == routenVorher + 1 and R:Liste()[#R:Liste()].von == "Baumkuschler", "Route übernommen")
FG.db.routenAnnehmen = "nie"
for _, s in ipairs(stuecke) do Ereignis("CHAT_MSG_ADDON", "FGather", s:gsub("^C~%w+", "C~abc"), "PARTY", "Kumpel-Forever") end
pruefe(#R:Liste() == routenVorher + 1, "„Ablehnen“ nimmt nichts an")
FG.db.routenAnnehmen = "fragen"

-- lange Codes werden gestückelt
local langerCode = T:FundortCode()
local m0 = #gesendet
T:CodeSenden(langerCode .. string.rep("A", 500), "GUILD")
Timer()
local maxLaenge = 0
for i = m0 + 1, #gesendet do maxLaenge = math.max(maxLaenge, #gesendet[i][2]) end
pruefe(#gesendet - m0 >= 3 and maxLaenge <= 255, "lange Codes in Stücken unter 255 Zeichen")

---------------------------------------------------------------------------
print("-- Lager")
Ereignis("BAG_UPDATE_DELAYED")
Ereignis("BANKFRAME_OPENED")
FG.root.charaktere["Twink-Forever"] = { klasse = "DRUID", taschen = { [2447] = 7 }, bank = { [2770] = 5 } }
local summe, wer = La:Bestand(2447)
pruefe(summe == 17 and #wer == 2 and wer[1].eigener, "Friedensblume auf zwei Charakteren: " .. summe)
pruefe(La:Bestand(2770) == 25, "Kupfererz mit Bank")
pruefe(#La:Alle("erz") == 1 and #La:Alle("kraut") == 2 and #La:Alle(nil, "silber") == 1, "Lager filtert nach Art und Suche")
tooltipRuf(GameTooltip, { id = 2447 })
local tt = table.concat(GameTooltip.zeilen or {}, "\n")
pruefe(tt:find("Gesamt: 17") and tt:find("Twink"), "Bestand im Gegenstands-Tooltip")
GameTooltip.zeilen = {}
GameTooltipTextLeft1:SetText("Wilddornrose")
GameTooltip.skripte.OnShow(GameTooltip)
pruefe(GameTooltip.zeilen[1] and GameTooltip.zeilen[1]:find("zu niedrig"), "Fertigkeit im Tooltip eines Vorkommens: " .. tostring(GameTooltip.zeilen[1]))

---------------------------------------------------------------------------
print("-- Geschützte Werte")
local GEHEIM = setmetatable({}, { __eq = function() error("geheim") end })
issecretvalue = function(v) return v == nil and false or rawequal(v, GEHEIM) end
pruefe(FG.Geheim(GEHEIM) and FG.Frei(GEHEIM) == nil and FG.Frei("x") == "x", "geheime Werte erkannt")
GameTooltipTextLeft1.text = GEHEIM
GameTooltip.zeilen = {}
GameTooltip.skripte.OnShow(GameTooltip)
pruefe(#GameTooltip.zeilen == 0, "geheimer Tooltip-Text wird übersprungen")
pruefe(F:TypNachName(GEHEIM) == nil, "geheimer Name ist kein Schlüssel")
Gehe(0.3, 0.7)
Sammeln(2575, GEHEIM, nil, { { 2771, 2 } })
local letzter = F:Liste(KARTE)[#F:Liste(KARTE)]
pruefe(letzter.t == "o1732" and math.abs(letzter.x - 0.3) < 0.001, "geheimer Zielname: Zinnader über das Material erkannt")
local fl0 = ForeverGatherDB.fehler
pruefe(not fl0 or #fl0 == 0, "keine Fehler durch geheime Werte" .. (fl0 and fl0[1] and (": " .. fl0[1]) or ""))
issecretvalue = nil

print("-- Fertigkeitspunkte und Filter")
pruefe(F:Farbstufe("o1620") == "orange" and F:Farbstufe("o1619") == "gelb" and F:Farbstufe("o1618") == "gruen", "orange, gelb, grün bei Fertigkeit 60")
pruefe(F:Farbstufe("o1618", 150) == "grau" and F:Farbstufe("o1621") == "rot", "grau und zu niedrig")
berufe[1][2] = 150
Ereignis("SKILL_LINES_CHANGED")
FG.db.nurSkillpunkte = true
pruefe(not F:Sichtbar("o1618") and F:Sichtbar("o1621"), "nur Vorkommen mit Fertigkeitspunkten")
FG.db.nurSkillpunkte = false
berufe[1][2] = 60
Ereignis("SKILL_LINES_CHANGED")

print("-- Favoriten, Aufräumen, Merken")
local fav = F:Liste(KARTE)[1]
strg = true
W:FundKlick(KARTE, fav, "LeftButton")
strg = false
pruefe(fav.fav, "Strg+Klick macht einen Favoriten")
FG.db.ausgeblendet[fav.t] = true
pruefe(F:FundSichtbar(fav) and not F:Sichtbar(fav.t), "Favorit bleibt sichtbar, auch wenn die Sorte aus ist")
FG.db.ausgeblendet[fav.t] = nil
local vorAuf = F:Anzahl()
F:Hinzufuegen(KARTE, 0.81, 0.81, "o1617", "Freund", nil, time() - 200 * 86400)
local vorbild = F:Liste(KARTE)[2]
local dop = { x = vorbild.x + 0.0005, y = vorbild.y, t = vorbild.t, n = 0, z = time(), q = "Freund2" }
table.insert(FG.root.fundorte[KARTE], dop)
FG.Extras:Aufraeumen(90)
pruefe(F:Anzahl() == vorAuf, "Aufräumen: doppelt und alt entfernt (" .. F:Anzahl() .. ")")
GameTooltipTextLeft1:SetText("Wilddornrose")
GameTooltip.skripte.OnShow(GameTooltip)
GameTooltip.skripte.OnHide(GameTooltip)
Gehe(0.9, 0.9)
FG.Extras:Merken()
local gemerkt = F:Liste(KARTE)[#F:Liste(KARTE)]
pruefe(gemerkt.t == "o1621" and gemerkt.x == 0.9 and gemerkt.n == 0, "Vorkommen unter der Maus gemerkt")

print("-- Sammelziele")
SlashCmdList.FOREVERGATHER("ziel 40 friedensblume")
pruefe(FG.char.ziele[2447] == 40 and F:IstZiel("o1618"), "Ziel gesetzt: 40 Friedensblumen")
taschen[0][1][2] = 45
Ereignis("BAG_UPDATE_DELAYED")
pruefe(alarme[#alarme] and alarme[#alarme]:find("Ziel erreicht"), "Ziel erreicht gemeldet")
pruefe(not F:IstZiel("o1618"), "erreichtes Ziel nicht mehr hervorgehoben")
FG.Extras:ZielSetzen(2447, 0)
pruefe(not FG.char.ziele[2447], "Ziel entfernt")
FG.Extras:ZielSetzen(2770, 100)

print("-- Seltenes")
berufe[2][2] = 160
Ereignis("SKILL_LINES_CHANGED")
Gehe(0.2, 0.2)
F:Hinzufuegen(KARTE, 0.205, 0.2, "o1733", "Freund")
local a0 = #alarme
M.Takt()
pruefe(#alarme == a0 + 1 and alarme[#alarme]:find("Silberader"), "Alarm bei Silberader in der Nähe")
Ereignis("CHAT_MSG_ADDON", "FGather", "F~1411~o1734~e~" .. T.Koord(0.25) .. T.Koord(0.25), "PARTY", "Kumpel-Forever")
pruefe(#alarme == a0 + 2 and alarme[#alarme]:find("Kumpel hat Goldader"), "Alarm bei geteiltem seltenem Fund")
imKampf = true
M.Takt()
pruefe(M.anzahl == 0, "im Kampf keine Symbole auf der Minikarte")
imKampf = false

print("-- Radar, Statistik, Kontinent, Berufe, Bericht")
FG.Radar:Umschalten()
pruefe(ForeverGatherRadar and ForeverGatherRadar:IsShown() and #FG.Radar.liste >= 1, "Radar zeigt die nächsten Fundorte")
pruefe(FG.Radar.liste[1].m <= (FG.Radar.liste[2] and FG.Radar.liste[2].m or math.huge), "Radar nach Entfernung sortiert")
FG.Radar:Umschalten()
local heute = FG.root.tage[os.date("%Y-%m-%d")]
pruefe(heute and heute.funde >= 5 and heute.stueck >= 5, "Tagesstatistik gezählt")
pruefe(FG.root.besteSitzung and FG.root.besteSitzung.funde >= 1, "beste Sitzung gemerkt")
local zonen = FG.Statistik:Zonen()
pruefe(zonen[1] and zonen[1].name == "Durotar" and zonen[1].punkte > 0, "beste Gegend: Durotar")
FG.Statistik:KarteOeffnen(KARTE)
pruefe(karteGeoeffnet == KARTE, "Gegend auf der Karte öffnen")
kartenId = 12
W.waechter.skripte.OnUpdate(W.waechter, 0.2)
pruefe(W.anzahl > 0, "Fundorte auf der Kontinentkarte: " .. tostring(W.anzahl))
kartenId = KARTE
FG.root.charaktere["Twink-Forever"].berufe = { erz = 200 }
local andere = FG.Extras:AndereKoennen("o2040")
pruefe(andere[1] == "Twink (200)", "Twink kann Mithril abbauen")
FG.Extras:Bericht("gilde")
pruefe(chatGesendet[#chatGesendet] and chatGesendet[#chatGesendet]:match("^GUILD:Forever Harvest"), "Bericht in den Gildenchat")

print("-- Runden")
local rr = R:AusFundorten(KARTE, "kraut")
R:Starten(rr)
local npkt = #rr.punkte / 2
for _ = 1, npkt do R:Weiter() end
pruefe(rr.runden == 1 and rr.bestzeit, "Runde gezählt")
pruefe(R:DauerText(rr):find("zu Fuß"), "Dauer geschätzt: " .. R:DauerText(rr))
R:Anhalten()

---------------------------------------------------------------------------
print("-- Befehle, Tasten, Fenster")
local befehle = { "", "", "hilfe", "einstellungen", "naechster", "zeigen", "zeigen", "vorlesen", "sitzung", "lager", "lager kupfer",
  "route neu", "route", "route weiter", "route stopp", "route kraut", "aufnahme", "aufnahme", "teilen", "teilen route gilde",
  "import", "import kaputt", "radar", "radar", "ziel", "berufe", "statistik", "bericht", "merken", "aufraeumen", "diagnose", "fehler", "sprache", "sprache de", "unsinn", "sitzung neu" }
for _, b in ipairs(befehle) do SlashCmdList.FOREVERGATHER(b) end
Timer()
pruefe(FG.root.diagnose and FG.root.diagnose.karte == true and #FG.root.diagnose.zauber >= 3, "Diagnose gespeichert")
pruefe(FG.sitzung.funde == 0, "Sitzung zurückgesetzt")
for _, t in ipairs({ "fenster", "fenster", "anzeige", "anzeige", "naechster", "route", "weiter", "route", "aufnahme", "aufnahme", "vorlesen", "sitzung", "sitzung", "radar", "radar", "merken", "einstellungen" }) do FG:Taste(t) end
local Fe = FG.Fenster
for _, s in ipairs({ "start", "karte", "routen", "lager", "statistik", "teilen", "hilfen", "einstellungen" }) do Fe:Oeffnen(s) end
pruefe(ForeverGatherFenster:IsShown(), "alle Reiter geöffnet")
-- Listen bedienen
Fe:Oeffnen("karte")
Fe.kartenArt = "kraut"; Fe:Auffrischen()
FG.db.sitzungsAnzeige = true; FG:Anwenden()
pruefe(ForeverGatherSitzung and ForeverGatherSitzung:IsShown(), "Sitzungsanzeige sichtbar")
Fe:Oeffnen("teilen")
Fe:CodeZeigen(code)
pruefe(Fe.codeBox:GetText() == code, "Code im Teilen-Feld")
FG.db.kontrast, FG.db.farbenblind, FG.db.allesGroesser = true, true, true
FG:Anwenden()
pruefe(FG.farben.gruen[3] == 1 and FG:ArtFarbe("kraut")[3] == 1, "Farbenblind: Blau statt Grün")
FG:ProfilWechseln("eigen")
pruefe(FG.char.einstellungen and FG.db == FG.char.einstellungen, "eigenes Profil")
FG:ProfilWechseln("konto")
ForeverGatherMinimapKnopf.skripte.OnClick(ForeverGatherMinimapKnopf, "LeftButton")
ForeverGatherMinimapKnopf.skripte.OnClick(ForeverGatherMinimapKnopf, "RightButton")
ForeverGatherMinimapKnopf.skripte.OnClick(ForeverGatherMinimapKnopf, "MiddleButton")
ForeverGatherMinimapKnopf.skripte.OnEnter(ForeverGatherMinimapKnopf)

---------------------------------------------------------------------------
print("-- Texte")
local fehlend, falsch = {}, {}
for _, datei in ipairs(toc) do
  local inhalt = io.open(datei):read("*a"):gsub("%-%-[^\n]*", "")
  for text in inhalt:gmatch('[^%w_]L"(.-[^\\])"') do
    local en = FG.EN[text]
    if not en then fehlend[#fehlend + 1] = text
    else
      local _, a = text:gsub("%%[ds]", "")
      local _, b = en:gsub("%%[ds]", "")
      if a ~= b then falsch[#falsch + 1] = text end
    end
  end
end
pruefe(#fehlend == 0, "alle Texte haben eine englische Fassung" .. (fehlend[1] and (": " .. #fehlend .. " fehlen, z. B. " .. fehlend[1]) or ""))
pruefe(#falsch == 0, "Platzhalter stimmen überein" .. (falsch[1] and (": " .. falsch[1]) or ""))
if os.getenv("FEHLENDE") then for _, t in ipairs(fehlend) do print(t) end end

local fl = ForeverGatherDB.fehler
pruefe(not fl or #fl == 0, "keine Fehler im Protokoll" .. (fl and fl[1] and (": " .. fl[1]) or ""))
if fl then for _, f in ipairs(fl) do print("         " .. f) end end

print(("\n%d Prüfungen, %d Fehler"):format(geprueft, fehler))
os.exit(fehler == 0 and 0 or 1)
