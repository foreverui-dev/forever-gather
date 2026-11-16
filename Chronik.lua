-- Forever Harvest: Chronik. Sitzungsverlauf, Rekorde, Wochenvergleich, beste Materialien,
-- Bericht zum Kopieren und Ertrag je Vorkommen (Stück pro Ernte, Zusatzbeute).
local _, FG = ...
local Ch = FG:Modul("Chronik")
local F, P = FG.Fundorte, FG.Position
local L = FG.L

local MAX_SITZUNGEN = 20

local function Stueck(s)
  local n = 0
  for _, m in pairs(s.items or {}) do n = n + m end
  return n
end

-- Laufende Sitzung in den Verlauf schreiben (nur, wenn etwas gesammelt wurde).
function Ch:Sichern()
  local s = FG.sitzung
  if not (s and s.funde and s.funde > 0) or s.gesichert then return end
  s.gesichert = true
  local dauer = F:SitzungDauer()
  local e = {
    datum = date("%Y-%m-%d %H:%M"), funde = s.funde, stueck = Stueck(s), wert = s.wert or 0,
    dauer = dauer, punkte = s.punkte or 0, karte = P:Spieler() and P:KartenName((P:Spieler())) or nil,
  }
  local liste = FG.root.sitzungen
  table.insert(liste, 1, e)
  while #liste > MAX_SITZUNGEN do table.remove(liste) end
  self:RekordePruefen(e)
  FG:Rufe("chronik")
  return e
end

function Ch:RekordePruefen(e)
  local r = FG.root.rekorde
  local proStunde = e.dauer > 0 and e.stueck * 3600 / e.dauer or 0
  local neu = {}
  if e.stueck > (r.stueck or 0) then r.stueck = e.stueck; r.stueckDatum = e.datum; neu[#neu + 1] = L"meiste Stück in einer Sitzung" end
  if e.dauer >= 600 and proStunde > (r.proStunde or 0) then r.proStunde = proStunde; r.proStundeDatum = e.datum; neu[#neu + 1] = L"meiste Stück pro Stunde" end
  if e.wert > (r.wert or 0) then r.wert = e.wert; r.wertDatum = e.datum; neu[#neu + 1] = L"wertvollste Sitzung" end
  if #neu > 0 and FG.db.rekordAnsage then FG:Ansage(L"Neuer Rekord: %s!", table.concat(neu, ", ")) end
  return neu
end

-- Tagesrekord (meiste Funde an einem Tag) aus der Tagesstatistik.
function Ch:BesterTag()
  local best
  for tag, t in pairs(FG.root.tage) do
    if not best or t.funde > best.funde then best = { tag = tag, funde = t.funde, stueck = t.stueck } end
  end
  return best
end

-- Diese und letzte Woche (je 7 Tage) im Vergleich.
function Ch:Woche()
  local jetzt = time()
  local diese, letzte = { funde = 0, stueck = 0, wert = 0 }, { funde = 0, stueck = 0, wert = 0 }
  for i = 0, 13 do
    local tag = date("%Y-%m-%d", jetzt - i * 86400)
    local t = FG.root.tage[tag]
    if t then
      local z = i < 7 and diese or letzte
      z.funde, z.stueck, z.wert = z.funde + t.funde, z.stueck + t.stueck, z.wert + (t.wert or 0)
    end
  end
  return diese, letzte
end

function Ch:WocheText()
  local d, l = self:Woche()
  local diff = d.stueck - l.stueck
  return L"Diese Woche %d Stück, letzte Woche %d (%s%d).":format(d.stueck, l.stueck, diff >= 0 and "+" or "", diff)
end

-- Die meistgesammelten Materialien.
function Ch:TopMaterialien(anzahl)
  local _, liste = FG.Statistik:Gesamt()
  for i = #liste, (anzahl or 10) + 1, -1 do liste[i] = nil end
  return liste
end

-- Bericht der laufenden Sitzung als Text zum Kopieren.
function Ch:BerichtText()
  local s = FG.sitzung
  local zeilen = { L"Forever Harvest · Sitzung %s":format(FG:ZeitText(F:SitzungDauer())) }
  zeilen[#zeilen + 1] = FG.Einzahl(L"%d Funde · %d Stück · %s pro Stunde":format(s.funde, Stueck(s), FG:ZahlText(F:ProStunde(Stueck(s)))))
  if (s.punkte or 0) > 0 then zeilen[#zeilen + 1] = L"Fertigkeit: +%d":format(s.punkte) end
  if (s.wert or 0) > 0 then zeilen[#zeilen + 1] = L"Wert: %s":format(FG:GeldText(s.wert, true)) end
  for _, item in ipairs(s.reihe or {}) do
    zeilen[#zeilen + 1] = ("- %s × %d"):format(F:ItemName(item), s.items[item])
  end
  return table.concat(zeilen, "\n")
end

function Ch:Zusammenfassung()
  local s = FG.sitzung
  if not (s and s.funde > 0) then return end
  return FG.Einzahl(L"Sitzung beendet: %d Funde, %d Stück in %s.":format(s.funde, Stueck(s), FG:ZeitText(F:SitzungDauer())))
end

---------------------------------------------------------------------------
-- Ertrag je Vorkommen
---------------------------------------------------------------------------
function Ch:ErtragZaehlen(typ, beute)
  if not typ or not beute or #beute == 0 then return end
  local e = FG.root.ertrag[typ]
  if not e then e = { e = 0, s = 0, x = {} }; FG.root.ertrag[typ] = e end
  e.e = e.e + 1
  local haupt = F:Material(typ) or beute[1].item
  for _, b in ipairs(beute) do
    if b.item == haupt then e.s = e.s + (b.menge or 1)
    else e.x[b.item] = (e.x[b.item] or 0) + 1 end
  end
end

function Ch:Ertrag(typ)
  local e = FG.root.ertrag[typ]
  if not e or e.e == 0 then return end
  local extra = {}
  for item, n in pairs(e.x) do extra[#extra + 1] = { item = item, anteil = n / e.e } end
  table.sort(extra, function(a, b) return a.anteil > b.anteil end)
  return e.s / e.e, extra, e.e
end

function Ch:TooltipZeilen(tt, typ)
  local schnitt, extra, ernten = self:Ertrag(typ)
  if not schnitt then return end
  tt:AddLine(L"Im Schnitt %s Stück pro Ernte (%d Ernten)":format(FG:KommaText(schnitt, 1), ernten), 0.8, 0.8, 0.8)
  for i, x in ipairs(extra) do
    if i > 3 then break end
    tt:AddLine(L"Zusatzbeute: %s (%d %%)":format(F:ItemName(x.item), math.floor(x.anteil * 100 + 0.5)), 0.6, 0.8, 1)
  end
end

function Ch:Start()
  FG.root.sitzungen = FG.root.sitzungen or {}
  FG.root.rekorde = FG.root.rekorde or {}
  FG.root.ertrag = FG.root.ertrag or {}
  FG:Haken("gesammelt", function(typ, beute) Ch:ErtragZaehlen(typ, beute) end)
  FG:Ereignis("PLAYER_LOGOUT", function() Ch:Sichern() end)
  -- Sitzung neu: vorher sichern und zusammenfassen
  local alt = F.SitzungNeu
  F.SitzungNeu = function(self, ...)
    local text = Ch:Zusammenfassung()
    if Ch:Sichern() and text and FG.db.sitzungsEnde then FG:Ansage(text) end
    return alt(self, ...)
  end
end

FG:Befehl({ "chronik", "verlauf", "history" }, function()
  local liste = FG.root.sitzungen
  if #liste == 0 then FG:Meldung(L"Noch keine gespeicherte Sitzung."); return end
  FG:Meldung(Ch:WocheText())
  for i, e in ipairs(liste) do
    if i > 5 then break end
    DEFAULT_CHAT_FRAME:AddMessage(FG.Einzahl(("  %s: %d %s, %d %s, %s"):format(e.datum, e.funde, L"Funde", e.stueck, L"Stück", FG:ZeitText(e.dauer))))
  end
end, L"/fg chronik – letzte Sitzungen und Wochenvergleich")
