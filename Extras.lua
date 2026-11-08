-- Forever Gather: Fertigkeitspunkte, Sammelziele, Favoriten, seltene Vorkommen, Aufräumen,
-- Bericht, Berufe aller Charaktere und „Vorkommen merken“.
local _, FG = ...
local E = FG:Modul("Extras")
local F, P = FG.Fundorte, FG.Position
local L = FG.L

---------------------------------------------------------------------------
-- Fertigkeitspunkte: wie im Spiel orange, gelb, grün, grau – immer mit Wort dazu.
---------------------------------------------------------------------------
FG.FARBSTUFEN = {
  rot    = { 0.95, 0.25, 0.25, L"zu niedrig" },
  orange = { 1, 0.5, 0.25, L"Fertigkeitspunkt sicher" },
  gelb   = { 1, 0.9, 0.1, L"Fertigkeitspunkt wahrscheinlich" },
  gruen  = { 0.25, 0.8, 0.25, L"Fertigkeitspunkt selten" },
  grau   = { 0.6, 0.6, 0.6, L"keine Fertigkeitspunkte" },
}

function F:Farbstufe(typ, stufe)
  local art = self:Art(typ)
  local braucht = self:Stufe(typ)
  local hat = stufe or self:Fertigkeit(art)
  if art == "schatz" or not hat or not braucht then return end
  if hat < braucht then return "rot" end
  local d = hat - braucht
  if d < 25 then return "orange" elseif d < 50 then return "gelb" elseif d < 100 then return "gruen" end
  return "grau"
end

function FG:StufenFarbe(s)
  local c = FG.FARBSTUFEN[s]
  if not c then return 0.8, 0.8, 0.8, "" end
  if s == "gruen" and self.db.farbenblind then return 0.35, 0.65, 1, c[4] end
  return c[1], c[2], c[3], c[4]
end

---------------------------------------------------------------------------
-- Seltene Vorkommen
---------------------------------------------------------------------------
function F:Selten(typ) return FG.SELTEN[typ] and true or false end

function E:Alarm(text)
  FG:Meldung(text)
  if RaidNotice_AddMessage and RaidWarningFrame then
    pcall(RaidNotice_AddMessage, RaidWarningFrame, text, ChatTypeInfo and ChatTypeInfo.RAID_WARNING or { r = 1, g = 0.8, b = 0.2 })
  end
  if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959) end
  FG:Sprechen(text, true)
end

function E:Klang()
  if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.MAP_PING or 3175) end
end

---------------------------------------------------------------------------
-- Sammelziele: „40 Friedensblumen“. Gezählt wird, was dieser Charakter in Taschen und Bank hat.
---------------------------------------------------------------------------
E.erreicht = {}

function E:ItemSuchen(text)
  text = tostring(text or "")
  local id = tonumber(text:match("item:(%d+)")) or tonumber(text:match("^%s*(%d+)%s*$"))
  if id then return id end
  local such = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
  if such == "" then return end
  local treffer
  for item, m in pairs(FG.MATERIALIEN) do
    local de, en = m[2]:lower(), m[3]:lower()
    if de == such or en == such then return item end
    if not treffer and (de:find(such, 1, true) or en:find(such, 1, true)) then treffer = item end
  end
  return treffer
end

function E:Stand(item)
  local c = FG.root.charaktere[FG:CharKey()]
  if not c then return 0 end
  return ((c.taschen or {})[item] or 0) + ((c.bank or {})[item] or 0)
end

function E:ZielSetzen(item, anzahl)
  if not item then return end
  if not anzahl or anzahl <= 0 then
    FG.char.ziele[item] = nil
    FG:Ansage(L"Ziel für %s entfernt.", F:ItemName(item))
  else
    FG.char.ziele[item] = math.floor(anzahl)
    E.erreicht[item] = self:Stand(item) >= anzahl or nil
    FG:Ansage(L"Neues Ziel: %d %s (du hast %d).", anzahl, F:ItemName(item), self:Stand(item))
  end
  FG:Rufe("ziele")
end

function E:Ziele()
  local liste = {}
  for item, ziel in pairs(FG.char.ziele) do
    liste[#liste + 1] = { item = item, ziel = ziel, stand = self:Stand(item), name = F:ItemName(item) }
  end
  table.sort(liste, function(a, b) return a.name < b.name end)
  return liste
end

function E:ZieleText()
  local teile = {}
  for _, z in ipairs(self:Ziele()) do
    teile[#teile + 1] = ("%s %d/%d"):format(z.name, math.min(z.stand, z.ziel), z.ziel)
  end
  return table.concat(teile, " · ")
end

-- true, wenn das Material des Vorkommens ein offenes Ziel ist.
function F:IstZiel(typ)
  local item = self:Material(typ)
  local ziel = item and FG.char and FG.char.ziele[item]
  return ziel and E:Stand(item) < ziel or false
end

local function ZielePruefenNachLager()
  for item, ziel in pairs(FG.char.ziele) do
    if E:Stand(item) >= ziel and not E.erreicht[item] then
      E.erreicht[item] = true
      E:Alarm(L"Ziel erreicht: %d %s!":format(ziel, F:ItemName(item)))
    elseif E:Stand(item) < ziel then
      E.erreicht[item] = nil
    end
  end
end

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs.FOREVERGATHER_ZIEL = {
  text = L"Sammelziel für %s (Anzahl, 0 entfernt):",
  button1 = L"Übernehmen", button2 = L"Abbrechen",
  hasEditBox = true,
  OnShow = function(self)
    local box = self.editBox or self.EditBox
    if box and E.zielItem then box:SetText(tostring(FG.char.ziele[E.zielItem] or 20)); box:HighlightText() end
  end,
  OnAccept = function(self)
    local box = self.editBox or self.EditBox
    if box and E.zielItem then E:ZielSetzen(E.zielItem, tonumber(box:GetText()) or 0) end
  end,
  EditBoxOnEnterPressed = function(self)
    local eltern = self:GetParent()
    if E.zielItem then E:ZielSetzen(E.zielItem, tonumber(self:GetText()) or 0) end
    if eltern then eltern:Hide() end
  end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function E:ZielFragen(item)
  E.zielItem = item
  if StaticPopup_Show then StaticPopup_Show("FOREVERGATHER_ZIEL", F:ItemName(item)) end
end

FG:Befehl({ "ziel" }, function(rest)
  local anzahl, was = (rest or ""):match("^(%d+)%s+(.+)$")
  if not anzahl then
    local liste = E:Ziele()
    if #liste == 0 then FG:Meldung(L"Keine Sammelziele. Beispiel: /fg ziel 40 Friedensblume"); return end
    FG:Ansage(L"Ziele: %s", E:ZieleText())
    return
  end
  local item = E:ItemSuchen(was)
  if not item then FG:Ansage(L"Material „%s“ nicht gefunden.", was); return end
  E:ZielSetzen(item, tonumber(anzahl))
end, L"/fg ziel [Anzahl Material] – Sammelziel setzen oder anzeigen")

---------------------------------------------------------------------------
-- Favoriten (Strg+Klick auf einen Fundort)
---------------------------------------------------------------------------
function E:Favorit(karte, f)
  f.fav = not f.fav or nil
  FG:Ansage(f.fav and L"%s ist jetzt ein Favorit." or L"%s ist kein Favorit mehr.", F:Name(f.t))
  FG:Rufe("fundorte", karte)
end

---------------------------------------------------------------------------
-- Aufräumen: doppelte Fundorte zusammenlegen, alte geteilte entfernen.
---------------------------------------------------------------------------
function E:Aufraeumen(tage)
  tage = tage or 90
  local grenze = time() - tage * 86400
  local zusammen, alt = 0, 0
  local radius = FG.db.zusammenfassen or 15
  for karte, liste in pairs(FG.root.fundorte) do
    local b, h = P:Groesse(karte)
    for i = #liste, 1, -1 do
      local f = liste[i]
      if f.q and (f.n or 0) == 0 and not f.fav and (f.z or 0) < grenze then
        table.remove(liste, i); alt = alt + 1
      end
    end
    local i = 1
    while i <= #liste do
      local a = liste[i]
      local j = i + 1
      while j <= #liste do
        local c = liste[j]
        local nah
        if a.t == c.t then
          if b then nah = math.sqrt(((a.x - c.x) * b) ^ 2 + ((a.y - c.y) * h) ^ 2) <= radius
          else nah = math.abs(a.x - c.x) < 0.004 and math.abs(a.y - c.y) < 0.004 end
        end
        if nah then
          a.n = (a.n or 0) + (c.n or 0)
          a.z = math.max(a.z or 0, c.z or 0)
          a.fav = a.fav or c.fav
          if not c.q then a.q = nil end
          table.remove(liste, j); zusammen = zusammen + 1
        else
          j = j + 1
        end
      end
      i = i + 1
    end
    if #liste == 0 then FG.root.fundorte[karte] = nil end
  end
  FG:Rufe("fundorte")
  FG:Ansage(L"Aufgeräumt: %d doppelte zusammengelegt, %d alte geteilte Fundorte entfernt.", zusammen, alt)
  return zusammen, alt
end

FG:Befehl({ "aufraeumen", "aufräumen", "cleanup" }, function(rest) E:Aufraeumen(tonumber(rest)) end,
  L"/fg aufraeumen [Tage] – doppelte und alte geteilte Fundorte entfernen")

---------------------------------------------------------------------------
-- Bericht in den Chat
---------------------------------------------------------------------------
local KANAELE = { gruppe = "PARTY", party = "PARTY", raid = "RAID", gilde = "GUILD", guild = "GUILD", sagen = "SAY", say = "SAY" }
function E:Bericht(kanal)
  kanal = KANAELE[(kanal or ""):lower()] or (IsInRaid and IsInRaid() and "RAID") or (IsInGroup and IsInGroup() and "PARTY") or "SAY"
  local text = "Forever Gather: " .. F:SitzungText(true)
  if SendChatMessage then
    for teil in text:gmatch("[^\n]+") do
      while #teil > 250 do SendChatMessage(teil:sub(1, 250), kanal); teil = teil:sub(251) end
      SendChatMessage(teil, kanal)
    end
  end
end
FG:Befehl({ "bericht", "report" }, function(rest) E:Bericht(rest) end, L"/fg bericht [gruppe | gilde | sagen] – Sitzung in den Chat")

---------------------------------------------------------------------------
-- Berufe aller Charaktere
---------------------------------------------------------------------------
function E:AndereKoennen(typ)
  local art, braucht = F:Art(typ), F:Stufe(typ)
  local ich, liste = FG:CharKey(), {}
  if art == "schatz" then return liste end
  for key, c in pairs(FG.root.charaktere) do
    local stufe = c.berufe and c.berufe[art]
    if key ~= ich and stufe and (not braucht or stufe >= braucht) then
      liste[#liste + 1] = ("%s (%d)"):format(key:match("^[^-]+") or key, stufe)
    end
  end
  table.sort(liste)
  return liste
end

FG:Befehl({ "berufe" }, function()
  local any = false
  for key, c in pairs(FG.root.charaktere) do
    if c.berufe and (c.berufe.kraut or c.berufe.erz) then
      any = true
      local teile = {}
      if c.berufe.kraut then teile[#teile + 1] = L"Kräuterkunde" .. " " .. c.berufe.kraut end
      if c.berufe.erz then teile[#teile + 1] = L"Bergbau" .. " " .. c.berufe.erz end
      FG:Meldung("%s: %s", key, table.concat(teile, ", "))
    end
  end
  if not any then FG:Meldung(L"Noch kein Charakter mit Kräuterkunde oder Bergbau bekannt.") end
end, L"/fg berufe – Sammelberufe aller Charaktere")

---------------------------------------------------------------------------
-- Vorkommen merken: das zuletzt mit der Maus berührte Vorkommen an deiner Position eintragen,
-- z. B. wenn du es (noch) nicht abbauen kannst.
---------------------------------------------------------------------------
function E:Merken()
  local t = F.letzterTooltip
  if not t or GetTime() - t.zeit > 15 then
    FG:Ansage(L"Fahr zuerst mit der Maus über ein Vorkommen, dann noch einmal.")
    return
  end
  local karte, x, y = P:Spieler()
  if not karte then FG:Ansage(L"Deine Position ist hier nicht bekannt."); return end
  local f, neu = F:Hinzufuegen(karte, x, y, t.typ, nil, 0)
  if f then f.n = f.n or 0 end
  FG:Ansage(neu and L"%s gemerkt." or L"%s war schon bekannt.", F:Name(t.typ))
  if neu then FG:Rufe("neuerFund", karte, f) end
end
FG:Befehl({ "merken", "mark" }, function() E:Merken() end, L"/fg merken – Vorkommen unter der Maus an deiner Position merken")
FG.tasten.merken = function() E:Merken() end

function E:Start()
  FG:Haken("lager", ZielePruefenNachLager)
  for item, ziel in pairs(FG.char.ziele) do
    if self:Stand(item) >= ziel then E.erreicht[item] = true end
  end
end
