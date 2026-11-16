-- Forever Harvest: Komfort. Taschen-Warnung, Sammel-Timer, Ruhe in Städten und im Kampf,
-- Tipp des Tages, Rückgängig, Notizen, Fundorte kurz ausblenden, Sperrliste, Wegpunkte zu
-- Seltenem und Zielen, Sammelkette und Sicherung der Fundorte.
local _, FG = ...
local Ko = FG:Modul("Komfort")
local F, P = FG.Fundorte, FG.Position
local L = FG.L

---------------------------------------------------------------------------
-- Ruhe: keine Ansagen in Städten/Gasthäusern und auf Wunsch im Kampf
---------------------------------------------------------------------------
function Ko:Ruhig()
  if FG.db.ruheInStaedten and IsResting and IsResting() then return true end
  if FG.db.kampfRuhe and UnitAffectingCombat and UnitAffectingCombat("player") then return true end
  return false
end

---------------------------------------------------------------------------
-- Taschen-Warnung
---------------------------------------------------------------------------
function Ko:FreiePlaetze()
  local frei = 0
  for tasche = 0, 4 do
    local n
    if C_Container and C_Container.GetContainerNumFreeSlots then n = C_Container.GetContainerNumFreeSlots(tasche)
    elseif GetContainerNumFreeSlots then n = GetContainerNumFreeSlots(tasche) end
    frei = frei + (tonumber(FG.Frei(n)) or 0)
  end
  return frei
end

function Ko:TaschenPruefen()
  local grenze = FG.db.taschenWarnung or 0
  if grenze <= 0 then return end
  local frei = self:FreiePlaetze()
  if frei <= grenze and not self.taschenGewarnt then
    self.taschenGewarnt = true
    FG.Extras:Alarm(FG.Einzahl(L"Nur noch %d freie Taschenplätze!":format(frei)))
  elseif frei > grenze then
    self.taschenGewarnt = nil
  end
  return frei
end

---------------------------------------------------------------------------
-- Sammel-Timer
---------------------------------------------------------------------------
function Ko:TimerStarten(minuten)
  if not minuten or minuten <= 0 then
    self.timerEnde = nil
    FG:Ansage(L"Sammel-Timer aus.")
    return
  end
  self.timerEnde = GetTime() + minuten * 60
  FG:Ansage(L"Sammel-Timer: %d Minuten.", minuten)
end

function Ko:TimerTakt()
  if self.timerEnde and GetTime() >= self.timerEnde then
    self.timerEnde = nil
    local text = FG.Chronik and FG.Chronik:Zusammenfassung()
    FG.Extras:Alarm(L"Sammelzeit vorbei!" .. (text and (" " .. text) or ""))
  end
end

function Ko:TimerRest()
  if not self.timerEnde then return end
  return math.max(0, self.timerEnde - GetTime())
end

---------------------------------------------------------------------------
-- Tipp des Tages
---------------------------------------------------------------------------
Ko.TIPPS = {
  L"Strg+Klick auf einen Fundort macht ihn zum Favoriten, er bleibt dann immer sichtbar.",
  L"Alt+Klick auf einen Fundort schreibt eine Notiz dazu.",
  L"Alt+Rechtsklick blendet einen Fundort für eine Stunde aus.",
  L"/fg wohin zeigt Gegenden, in denen du gerade Fertigkeitspunkte bekommst.",
  L"/fg hud zeigt eine durchsichtige Kreiskarte in der Bildschirmmitte.",
  L"/fg timer 30 erinnert dich nach 30 Minuten Sammeln.",
  L"Mit /fg selten läufst du zum nächsten seltenen Vorkommen.",
  L"Routen überspringen abgeerntete Punkte, wenn du das unter Funktionen einschaltest.",
  L"Im Lager siehst du den Wert aller Materialien und was sich seit gestern geändert hat.",
  L"Codes für Fundorte und Routen kannst du im ForeverUI-Discord teilen.",
}

function Ko:Tipp(nr)
  nr = nr or (tonumber(date("%j")) or 1)
  return L(self.TIPPS[(nr - 1) % #self.TIPPS + 1])
end

---------------------------------------------------------------------------
-- Rückgängig und Sicherung
---------------------------------------------------------------------------
function Ko:Rueckgaengig()
  local l = self.geloescht
  if not l then FG:Meldung(L"Nichts zum Rückgängigmachen."); return end
  self.geloescht = nil
  local liste = FG.root.fundorte[l.karte]
  if not liste then liste = {}; FG.root.fundorte[l.karte] = liste end
  liste[#liste + 1] = l.f
  FG:Rufe("fundorte", l.karte)
  FG:Ansage(L"%s wiederhergestellt.", F:Name(l.f.t))
  return true
end

local function Kopie(t)
  if type(t) ~= "table" then return t end
  local k = {}
  for a, b in pairs(t) do k[a] = Kopie(b) end
  return k
end

function Ko:Sichern(grund)
  FG.root.sicherung = { zeit = time(), grund = grund, daten = Kopie(FG.root.fundorte), anzahl = F:Anzahl() }
end

function Ko:Wiederherstellen()
  local s = FG.root.sicherung
  if not s then FG:Meldung(L"Keine Sicherung vorhanden."); return end
  FG.root.fundorte = Kopie(s.daten)
  FG:Rufe("fundorte")
  FG:Ansage(FG.Einzahl(L"Sicherung vom %s wiederhergestellt: %d Fundorte.":format(date("%d.%m. %H:%M", s.zeit), s.anzahl or 0)))
  return true
end

---------------------------------------------------------------------------
-- Notiz an einem Fundort
---------------------------------------------------------------------------
StaticPopupDialogs.FOREVERGATHER_NOTIZ = {
  text = L"Notiz für %s (leer löscht sie):",
  button1 = L"Übernehmen", button2 = L"Abbrechen",
  hasEditBox = true,
  OnShow = function(self)
    local box = self.editBox or self.EditBox
    if box and Ko.notizFund then box:SetText(Ko.notizFund.notiz or ""); box:HighlightText() end
  end,
  OnAccept = function(self)
    local box = self.editBox or self.EditBox
    if box then Ko:NotizSetzen(Ko.notizFund, box:GetText()) end
  end,
  EditBoxOnEnterPressed = function(self)
    Ko:NotizSetzen(Ko.notizFund, self:GetText())
    local eltern = self:GetParent()
    if eltern then eltern:Hide() end
  end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function Ko:NotizFragen(f)
  self.notizFund = f
  if StaticPopup_Show then StaticPopup_Show("FOREVERGATHER_NOTIZ", F:Name(f.t)) end
end

function Ko:NotizSetzen(f, text)
  if not f then return end
  text = FG.Frei(text)
  if type(text) ~= "string" then return end
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  f.notiz = text ~= "" and text:sub(1, 120) or nil
  FG:Rufe("fundorte")
end

-- Fundort für eine Stunde ausblenden
function Ko:Ausblenden(f, sekunden)
  f.bis = time() + (sekunden or 3600)
  FG:Ansage(L"%s für eine Stunde ausgeblendet.", F:Name(f.t))
  FG:Rufe("fundorte")
end

---------------------------------------------------------------------------
-- Sperrliste für geteilte Funde
---------------------------------------------------------------------------
function Ko:Gesperrt(name) return name and FG.root.sperre[name] and true or false end

function Ko:Sperren(name)
  if not name or name == "" then
    local namen = {}
    for n in pairs(FG.root.sperre) do namen[#namen + 1] = n end
    table.sort(namen)
    FG:Meldung(#namen > 0 and L"Gesperrt: %s":format(table.concat(namen, ", ")) or L"Niemand gesperrt. Beispiel: /fg sperren Name")
    return
  end
  name = name:sub(1, 1):upper() .. name:sub(2)
  if FG.root.sperre[name] then
    FG.root.sperre[name] = nil
    FG:Ansage(L"Funde von %s werden wieder angenommen.", name)
  else
    FG.root.sperre[name] = true
    FG:Ansage(L"Funde von %s werden ignoriert.", name)
  end
end

---------------------------------------------------------------------------
-- Wegpunkte: nächstes Seltenes, nächstes Vorkommen für ein Ziel, Sammelkette
---------------------------------------------------------------------------
function Ko:NaechsterWo(pruefen)
  local karte, px, py = P:Spieler()
  if not karte then return end
  local best, bestM
  for _, f in ipairs(F:Liste(karte)) do
    if F:FundSichtbar(f) and not F:Abgeerntet(f) and pruefen(f) then
      local m = P:Entfernung(karte, px, py, f.x, f.y) or 0
      if not bestM or m < bestM then best, bestM = f, m end
    end
  end
  return best, karte, bestM
end

function Ko:ZuSeltenem()
  local f, karte = self:NaechsterWo(function(f) return F:Selten(f.t) end)
  if not f then FG:Ansage(L"Kein seltenes Vorkommen in dieser Gegend bekannt."); return end
  P:Wegpunkt(karte, f.x, f.y, F:Name(f.t))
  FG:Ansage(L"Wegpunkt: %s", F:Name(f.t))
  return f
end

function Ko:ZuZiel()
  local f, karte = self:NaechsterWo(function(f) return F:IstZiel(f.t) end)
  if not f then FG:Ansage(L"Kein Vorkommen für deine Sammelziele in dieser Gegend bekannt."); return end
  P:Wegpunkt(karte, f.x, f.y, F:Name(f.t))
  FG:Ansage(L"Wegpunkt: %s", F:Name(f.t))
  return f
end

function Ko:Kette()
  if not FG.db.kette or (FG.Routen and FG.Routen.aktiv) then return end
  local f, karte = F:Naechster(true)
  if f then
    P:Wegpunkt(karte, f.x, f.y, F:Name(f.t))
    FG:Sprechen(L"Weiter zu %s":format(F:Name(f.t)))
  end
  return f
end

function Ko:Start()
  FG.root.sperre = FG.root.sperre or {}
  FG:Haken("gesammelt", function()
    Ko:TaschenPruefen()
    C_Timer.After(0.3, function() FG:Sicher("Kette", Ko.Kette, Ko) end)
  end)
  -- Rückgängig: zuletzt gelöschten Fundort merken
  local entfernen = F.Entfernen
  F.Entfernen = function(self, karte, fund)
    local ok = entfernen(self, karte, fund)
    if ok then Ko.geloescht = { karte = karte, f = fund } end
    return ok
  end
  -- Sicherung vor großen Löschaktionen
  local typLoeschen = F.TypLoeschen
  F.TypLoeschen = function(self, ...) Ko:Sichern("typ"); return typLoeschen(self, ...) end
  local aufraeumen = FG.Extras.Aufraeumen
  FG.Extras.Aufraeumen = function(self, ...) Ko:Sichern("aufraeumen"); return aufraeumen(self, ...) end
  -- Timer
  local rahmen = CreateFrame("Frame", nil, UIParent)
  local zeit = 0
  rahmen:SetScript("OnUpdate", function(_, dt)
    zeit = zeit + (dt or 0)
    if zeit < 1 then return end
    zeit = 0
    FG:Sicher("Timer", Ko.TimerTakt, Ko)
  end)
  -- Tipp des Tages
  if FG.db.tipps and FG.db.eingerichtet then
    C_Timer.After(8, function() FG:Meldung(L"Tipp: %s", Ko:Tipp()) end)
  end
end

FG:Befehl({ "timer" }, function(rest) Ko:TimerStarten(tonumber(rest) or 0) end, L"/fg timer [Minuten] – Erinnerung nach so vielen Minuten Sammeln (0 = aus)")
FG:Befehl({ "rueckgaengig", "rückgängig", "undo" }, function() Ko:Rueckgaengig() end, L"/fg rueckgaengig – zuletzt gelöschten Fundort zurückholen")
FG:Befehl({ "wiederherstellen", "restore" }, function() Ko:Wiederherstellen() end, L"/fg wiederherstellen – Fundorte vor dem letzten Aufräumen zurückholen")
FG:Befehl({ "sperren", "block" }, function(rest) Ko:Sperren(rest) end, L"/fg sperren [Name] – geteilte Funde eines Spielers ignorieren oder wieder annehmen")
FG:Befehl({ "selten", "rare" }, function() Ko:ZuSeltenem() end, L"/fg selten – Wegpunkt zum nächsten seltenen Vorkommen")
FG:Befehl({ "zielort" }, function() Ko:ZuZiel() end, L"/fg zielort – Wegpunkt zum nächsten Vorkommen für ein Sammelziel")
FG:Befehl({ "tipp", "tip" }, function() FG:Meldung(L"Tipp: %s", Ko:Tipp(math.random and math.random(1, #Ko.TIPPS) or 1)) end, L"/fg tipp – ein Tipp zur Bedienung")
FG.tasten.selten = function() Ko:ZuSeltenem() end
FG.tasten.zielort = function() Ko:ZuZiel() end
