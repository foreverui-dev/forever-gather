-- Forever Harvest: Hauptfenster im ForeverUI-Stil (Seitenleiste mit Gruppen, Inhaltskasten, Suche)
-- und die kleine Sitzungsanzeige.
local _, FG = ...
local Fe = FG:Modul("Fenster")
local F, P, R, La, T = FG.Fundorte, FG.Position, FG.Routen, FG.Lager, FG.Teilen
local L = FG.L

local BREITE = 640                    -- Breite, mit der die Seiten rechnen (Inhalt = BREITE - 40)
local FB, FH = 840, 590              -- Hauptfenster (kleinste Größe)
local SEITENLEISTE = 168
local fenster, reiterKnoepfe, seiten = nil, {}, {}
local aktuell = "start"
local elemente = {}   -- alles mit Auffrischen()
local suchListe = {}  -- { Titel, Seite } aller Schalter für die Suche
local bautSeite       -- Seite, die gerade gebaut wird

-- Seitenleiste im ForeverUI-Stil: Gruppen mit Einträgen.
local GRUPPEN = {
  { L"Sammeln", { { "start", L"Übersicht" }, { "karte", L"Karte" }, { "routen", L"Routen" },
    { "lager", L"Lager" }, { "fortschritt", L"Fortschritt" }, { "statistik", L"Statistik" }, { "chronik", L"Chronik" } } },
  { L"Funktionen", { { "teilen", L"Teilen" }, { "hilfen", L"Hilfen" }, { "komfort", L"Komfort und Routen" } } },
  { L"Darstellung", { { "darstellung", L"Anzeige und Farben" }, { "hervorheben", L"Hervorheben" } } },
  { L"Zugang", { { "zugang", L"Barrierefreiheit und Profil" } } },
  { L"Hilfe", { { "neuigkeiten", L"Neuigkeiten" }, { "bedienung", L"Bedienung" }, { "fehler", L"Fehler melden" } } },
}
local REITER = {}
for _, g in ipairs(GRUPPEN) do for _, r in ipairs(g[2]) do REITER[#REITER + 1] = r end end
local ALIAS = { einstellungen = "darstellung", einrichten = "start", hilfe = "bedienung" }

---------------------------------------------------------------------------
-- Bausteine
---------------------------------------------------------------------------
local function Hintergrund(f, alpha)
  f.hg = f.hg or f:CreateTexture(nil, "BACKGROUND")
  f.hg:SetAllPoints()
  f.hg:SetColorTexture(0.06, 0.06, 0.08, alpha)
end

local function Text(eltern, schrift, text, breite)
  local t = eltern:CreateFontString(nil, "OVERLAY", schrift or "GameFontHighlight")
  t:SetJustifyH("LEFT")
  t:SetJustifyV("TOP")
  if breite then t:SetWidth(breite) end
  t:SetText(text or "")
  return t
end

local function Knopf(eltern, text, breite, fn)
  local k = FG.FlachKnopf(eltern)
  k:SetSize(breite or 140, 22)
  k:SetText(text)
  k:SetScript("OnClick", function() FG:Sicher("Knopf", fn) end)
  return k
end

local function merke(e) elemente[#elemente + 1] = e; return e end

-- Schalter mit Beschriftung, gebunden an einen Einstellungswert (lesen/schreiben als Funktionen).
-- Schalter im ForeverUI-Stil „Klar“ (statt Häkchen): Spur in Akzentfarbe, wenn an, weißer Knopf wandert
-- nach rechts. Verhält sich wie ein CheckButton (SetChecked, GetChecked, OnClick schaltet vorher um).
local function Umschalter(eltern)
  local c = CreateFrame("Button", nil, eltern)
  c:SetSize(34, 18)
  local spur = c:CreateTexture(nil, "BACKGROUND")
  spur:SetAllPoints()
  local knopf = c:CreateTexture(nil, "ARTWORK")
  knopf:SetSize(14, 14)
  knopf:SetColorTexture(1, 1, 1, 1)
  local hl = c:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.08)
  c.an = false
  c.SetChecked = function(self, an)
    self.an = an and true or false
    knopf:ClearAllPoints()
    if self.an then
      local a = FG.farben.akzent
      spur:SetColorTexture(a[1], a[2], a[3], 1)
      knopf:SetPoint("RIGHT", -2, 0)
    else
      spur:SetColorTexture(1, 1, 1, 0.18)
      knopf:SetPoint("LEFT", 2, 0)
    end
  end
  c.GetChecked = function(self) return self.an end
  local setze = c.SetScript
  c.SetScript = function(self, name, fn)
    if name == "OnClick" and fn then
      return setze(self, name, function(s, ...) s:SetChecked(not s.an); return fn(s, ...) end)
    end
    return setze(self, name, fn)
  end
  c:SetChecked(false)
  return c
end

local function Schalter(eltern, titel, hilfe, lesen, schreiben)
  local f = CreateFrame("Frame", nil, eltern)
  f:SetSize(260, 36)
  local c = Umschalter(f)
  c:SetPoint("TOPLEFT", 0, -2)
  local l = Text(f, "GameFontHighlight", titel, 214)
  l:SetPoint("TOPLEFT", 42, -3)
  local d = Text(f, "GameFontDisableSmall", hilfe or "", 214)
  d:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -1)
  c:SetScript("OnClick", function(self)
    schreiben(self:GetChecked() and true or false)
    FG:Anwenden()
    Fe:Auffrischen()
    FG:Sprechen(titel .. ": " .. (self:GetChecked() and L"an" or L"aus"))
  end)
  f.Auffrischen = function() c:SetChecked(lesen() and true or false) end
  f.knopf = c
  if bautSeite then suchListe[#suchListe + 1] = { titel, bautSeite, f } end
  return merke(f)
end

local function DbSchalter(eltern, titel, hilfe, schluessel)
  return Schalter(eltern, titel, hilfe, function() return FG.db[schluessel] end,
    function(v) FG.db[schluessel] = v end)
end

-- Auswahlkarte (gold umrandet, wenn gewählt); Wort „an“/„aus“ zusätzlich zur Farbe.
local function Karte(eltern, breite, hoehe, titel, istAn, klick)
  local k = CreateFrame("Button", nil, eltern)
  k:SetSize(breite, hoehe)
  Hintergrund(k, 0.6)
  k.titel = Text(k, "GameFontNormal", titel, breite - 16)
  k.titel:SetPoint("TOPLEFT", 8, -7)
  k.unter = Text(k, "GameFontHighlightSmall", "", breite - 16)
  k.unter:SetPoint("TOPLEFT", k.titel, "BOTTOMLEFT", 0, -3)
  k.rand = k:CreateTexture(nil, "BORDER")
  k.rand:SetPoint("BOTTOMLEFT"); k.rand:SetPoint("BOTTOMRIGHT"); k.rand:SetHeight(2)
  local hl = k:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.05)
  k:SetScript("OnClick", function() FG:Sicher("Karte", klick); FG:Anwenden(); Fe:Auffrischen() end)
  k.Auffrischen = function()
    local an = istAn()
    local g = FG.farben.akzent
    k.rand:SetColorTexture(g[1], g[2], g[3], an and 1 or 0)
    k.hg:SetColorTexture(an and 0.16 or 0.06, an and 0.13 or 0.06, an and 0.07 or 0.08, FG:Deckkraft(0.7))
  end
  return merke(k)
end

-- Einfache Liste mit festen Zeilen, Mausrad blättert.
local function Liste(eltern, breite, zeilen, hoehe, daten, fuellen, klick, tooltip)
  local l = CreateFrame("Frame", nil, eltern)
  l:SetSize(breite, zeilen * hoehe)
  Hintergrund(l, 0.35)
  l.versatz = 0
  l.zeilen = {}
  for i = 1, zeilen do
    local z = CreateFrame("Button", nil, l)
    z:SetSize(breite, hoehe)
    z:SetPoint("TOPLEFT", 0, -(i - 1) * hoehe)
    z.icon = z:CreateTexture(nil, "ARTWORK")
    z.icon:SetSize(hoehe - 4, hoehe - 4)
    z.icon:SetPoint("LEFT", 4, 0)
    z.links = Text(z, "GameFontHighlight", "", breite * 0.55)
    z.links:SetPoint("LEFT", hoehe + 4, 0)
    z.rechts = Text(z, "GameFontHighlightSmall", "", breite * 0.4)
    z.rechts:SetJustifyH("RIGHT")
    z.rechts:SetPoint("RIGHT", -8, 0)
    z.wahl = z:CreateTexture(nil, "BACKGROUND")
    z.wahl:SetAllPoints()
    local hl = z:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)
    z:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    z:SetScript("OnClick", function(self, taste)
      if self.eintrag then FG:Sicher("Liste", klick, self.eintrag, taste); Fe:Auffrischen() end
    end)
    if tooltip then
      z:SetScript("OnEnter", function(self) if self.eintrag then FG:Sicher("Liste", tooltip, self, self.eintrag) end end)
      z:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    l.zeilen[i] = z
  end
  l:EnableMouseWheel(true)
  l:SetScript("OnMouseWheel", function(self, d)
    self.versatz = math.max(0, math.min((self.anzahl or 0) - zeilen, self.versatz - d))
    self.Auffrischen()
  end)
  l.Auffrischen = function()
    local liste = daten()
    l.anzahl = #liste
    l.versatz = math.max(0, math.min(l.versatz, #liste - zeilen))
    for i, z in ipairs(l.zeilen) do
      local e = liste[i + l.versatz]
      z.eintrag = e
      if e then
        fuellen(z, e)
        z:Show()
      else
        z:Hide()
      end
    end
    l.liste = liste
  end
  return merke(l)
end
Fe.Liste = Liste

---------------------------------------------------------------------------
-- Seiten
---------------------------------------------------------------------------
local bauen = {}

bauen.start = function(s)
  local gruss = Text(s, "GameFontHighlight", "", BREITE - 40)
  gruss:SetPoint("TOPLEFT", 0, 0)
  gruss:SetSpacing(2)
  merke({ Auffrischen = function()
    if not FG.db.eingerichtet then
      gruss:SetText(L"Willkommen! Forever Harvest merkt sich jeden Fundort, an dem du sammelst, und zeigt ihn auf Welt- und Minikarte. "
        .. L"Du musst nichts einrichten: einfach losziehen und sammeln. Funde aus deiner Gruppe kommen automatisch dazu.")
    else
      local teile = {}
      for _, art in ipairs({ "kraut", "erz" }) do
        local stufe = F:Fertigkeit(art)
        local name = art == "kraut" and L"Kräuterkunde" or L"Bergbau"
        teile[#teile + 1] = stufe and ("%s %d"):format(name, stufe) or (name .. " " .. L"nicht erlernt")
      end
      local karte = P:Spieler()
      gruss:SetText(FG.Einzahl(L"%s · %d Fundorte hier, %d insgesamt":format(table.concat(teile, " · "),
        karte and #F:Liste(karte) or 0, F:Anzahl())))
    end
  end })

  local namen = { kraut = L"Kräuter", erz = L"Erze", schatz = L"Schätze" }
  for i, art in ipairs(FG.ARTEN_REIHE) do
    local k = Karte(s, 172, 48, namen[art], function() return FG.db.zeigen[art] end,
      function() FG.db.zeigen[art] = not FG.db.zeigen[art] end)
    k:SetPoint("TOPLEFT", (i - 1) * 182, -44)
    local alt = k.Auffrischen
    k.Auffrischen = function()
      alt()
      k.unter:SetText(L"%s · %d bekannt":format(FG.db.zeigen[art] and L"wird angezeigt" or L"ausgeblendet", F:AnzahlArt(art)))
    end
  end

  local titel = Text(s, "GameFontNormal", L"Diese Sitzung")
  titel:SetPoint("TOPLEFT", 0, -112)
  local sitzung = Liste(s, BREITE - 40, 5, 22, function()
    local liste = {}
    for _, item in ipairs(FG.sitzung.reihe) do liste[#liste + 1] = item end
    table.sort(liste, function(a, b) return FG.sitzung.items[a] > FG.sitzung.items[b] end)
    return liste
  end, function(z, item)
    local n = FG.sitzung.items[item]
    z.icon:SetTexture(F:ItemSymbol(item))
    z.links:SetText(("%s × %d"):format(F:ItemName(item), n))
    z.rechts:SetText(L"%s pro Stunde":format(FG:ZahlText(F:ProStunde(n))))
  end, function(item) FG:Sprechen(L"%s: %d":format(F:ItemName(item), FG.sitzung.items[item]), true) end)
  sitzung:SetPoint("TOPLEFT", 0, -130)
  local zeile = Text(s, "GameFontHighlightSmall", "", BREITE - 40)
  zeile:SetPoint("TOPLEFT", 0, -244)
  local ziele = Text(s, "GameFontHighlightSmall", "", BREITE - 40)
  ziele:SetPoint("TOPLEFT", 0, -260)
  merke({ Auffrischen = function()
    local t = FG.Extras:ZieleText()
    ziele:SetText(t ~= "" and (L"Ziele: %s":format(t)) or L"Kein Sammelziel. Rechtsklick auf ein Material im Lager setzt eins.")
  end })
  merke({ Auffrischen = function()
    local st = FG.sitzung
    if st.funde == 0 then zeile:SetText(L"Noch nichts gesammelt in dieser Sitzung.")
    else
      local t = FG.Einzahl(L"%d Funde in %s":format(st.funde, FG:ZeitText(F:SitzungDauer())))
      if FG.db.wert and st.wert > 0 then t = t .. " · " .. L"Wert %s":format(FG:GeldText(st.wert)) end
      zeile:SetText(t)
    end
  end })

  local k1 = Knopf(s, L"Nächster Fundort", 170, function() FG.befehle.naechster("") end)
  k1:SetPoint("TOPLEFT", 0, -284)
  local k2 = Knopf(s, L"Route für diese Gegend", 170, function() FG.befehle.route("neu") end)
  k2:SetPoint("LEFT", k1, "RIGHT", 10, 0)
  local k3 = Knopf(s, L"Umgebung vorlesen", 170, function() FG.befehle.vorlesen("") end)
  k3:SetPoint("LEFT", k2, "RIGHT", 10, 0)
  local k4 = Knopf(s, L"Sitzung neu", 170, function() F:SitzungNeu() end)
  k4:SetPoint("TOPLEFT", 0, -312)
  local k5 = Knopf(s, L"Sitzungsanzeige", 170, function() Fe:SitzungsAnzeigeUmschalten() end)
  k5:SetPoint("LEFT", k4, "RIGHT", 10, 0)
  local k6 = Knopf(s, L"Radar", 170, function() FG.Radar:Umschalten() end)
  k6:SetPoint("LEFT", k5, "RIGHT", 10, 0)
  local k7 = Knopf(s, L"Bericht in den Chat", 170, function() FG.Extras:Bericht() end)
  k7:SetPoint("TOPLEFT", 0, -340)
  local k8 = Knopf(s, L"Vorkommen merken", 170, function() FG.Extras:Merken() end)
  k8:SetPoint("LEFT", k7, "RIGHT", 10, 0)
  local k9 = Knopf(s, L"Kartenfenster", 170, function() FG.Kartenfenster:Umschalten() end)
  k9:SetPoint("LEFT", k8, "RIGHT", 10, 0)
  local tipp = Text(s, "GameFontDisableSmall", L"Tipp: Klick auf einen Fundort auf der Karte setzt einen Wegpunkt, Rechtsklick löscht ihn. "
    .. L"Alle Funktionen haben Tastenkürzel (Tastaturbelegung › AddOns).", BREITE - 40)
  tipp:SetPoint("TOPLEFT", 0, -372)
end

bauen.karte = function(s)
  local liste = {
    { L"Auf der Weltkarte", L"Symbole auf der großen Karte (M).", "weltkarte" },
    { L"Auf der Minikarte", L"Symbole in der Nähe auf der Minikarte.", "minikarte" },
    { L"Nur eigene Berufe", L"Kräuter nur mit Kräuterkunde, Erze nur mit Bergbau.", "nurEigenerBeruf" },
    { L"Nur abbaubare", L"Vorkommen über deiner Fertigkeit ausblenden.", "nurAbbaubar" },
    { L"Entfernte am Rand", L"Fundorte außerhalb der Minikarte am Rand zeigen.", "minikarteRand" },
    { L"Nur mit Fertigkeitspunkten", L"Graue Vorkommen ausblenden, die nichts mehr bringen.", "nurSkillpunkte" },
    { L"Auf der Kontinentkarte", L"Fundorte aller Gegenden auch auf der Übersichtskarte.", "kontinent" },
  }
  for i, e in ipairs(liste) do
    local f = DbSchalter(s, e[1], e[2], e[3])
    f:SetPoint("TOPLEFT", ((i - 1) % 2) * 300, -math.floor((i - 1) / 2) * 40)
  end
  local groesse = Text(s, "GameFontNormal", "")
  groesse:SetPoint("TOPLEFT", 300, -126)
  merke({ Auffrischen = function() groesse:SetText(L"Symbolgröße: %d":format(FG.db.pinGroesse)) end })
  local minus = Knopf(s, "–", 26, function() FG.db.pinGroesse = math.max(10, FG.db.pinGroesse - 2); FG.db.minikartePinGroesse = math.max(8, FG.db.minikartePinGroesse - 1); FG:Anwenden() end)
  minus:SetPoint("TOPLEFT", 430, -122)
  local plus = Knopf(s, "+", 26, function() FG.db.pinGroesse = math.min(32, FG.db.pinGroesse + 2); FG.db.minikartePinGroesse = math.min(24, FG.db.minikartePinGroesse + 1); FG:Anwenden() end)
  plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)

  Fe.kartenArt = Fe.kartenArt or "kraut"
  local namen = { kraut = L"Kräuter", erz = L"Erze", schatz = L"Schätze" }
  for i, art in ipairs(FG.ARTEN_REIHE) do
    local k = Karte(s, 120, 26, namen[art], function() return Fe.kartenArt == art end, function() Fe.kartenArt = art end)
    k:SetPoint("TOPLEFT", (i - 1) * 126, -164)
  end
  local auf = Knopf(s, L"Aufräumen", 120, function() FG.Extras:Aufraeumen() end)
  auf:SetPoint("TOPLEFT", BREITE - 160, -166)
  local l = Liste(s, BREITE - 40, 8, 22, function() return F:Typen(Fe.kartenArt) end, function(z, typ)
    z.icon:SetTexture(F:Symbol(typ))
    local stufe = F:Stufe(typ)
    z.links:SetText(stufe and ("%s (%d)"):format(F:Name(typ), stufe) or F:Name(typ))
    local fs = F:Farbstufe(typ)
    if fs then
      local r, g, b, wort = FG:StufenFarbe(fs)
      z.links:SetTextColor(r, g, b)
      z.links:SetText(z.links:GetText() .. " · " .. wort)
    else
      z.links:SetTextColor(1, 1, 1)
    end
    local aus = FG.db.ausgeblendet[typ]
    z.rechts:SetText(FG.Einzahl(L"%d Fundorte · %s":format(F:Anzahl(typ), aus and L"aus" or L"an")))
    z.icon:SetAlpha(aus and 0.35 or 1)
    if z.icon.SetDesaturated then z.icon:SetDesaturated(aus and true or false) end
  end, function(typ, taste)
    if taste == "RightButton" then
      Fe.typLoeschen = typ
      if StaticPopup_Show then StaticPopup_Show("FOREVERGATHER_TYP_LOESCHEN", F:Anzahl(typ), F:Name(typ)) end
      return
    end
    FG.db.ausgeblendet[typ] = not FG.db.ausgeblendet[typ] or nil
    FG:Sprechen(F:Name(typ) .. ": " .. (FG.db.ausgeblendet[typ] and L"aus" or L"an"))
    FG:Anwenden()
  end, function(z, typ)
    GameTooltip:SetOwner(z, "ANCHOR_RIGHT")
    GameTooltip:AddLine(F:Name(typ))
    GameTooltip:AddLine(L"Klick: ein- oder ausblenden", 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L"Rechtsklick: alle Fundorte dieser Sorte löschen", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  l:SetPoint("TOPLEFT", 0, -198)
end

StaticPopupDialogs.FOREVERGATHER_TYP_LOESCHEN = {
  text = L"Alle %d Fundorte von „%s“ löschen?",
  button1 = L"Löschen", button2 = L"Abbrechen",
  OnAccept = function() if Fe.typLoeschen then F:TypLoeschen(Fe.typLoeschen); Fe:Auffrischen() end end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

bauen.routen = function(s)
  local k1 = Knopf(s, L"Neue Route: Kräuter", 170, function() FG.befehle.route("kraut") end)
  k1:SetPoint("TOPLEFT", 0, 0)
  local k2 = Knopf(s, L"Neue Route: Erze", 170, function() FG.befehle.route("erz") end)
  k2:SetPoint("LEFT", k1, "RIGHT", 10, 0)
  local k3 = Knopf(s, "", 170, function() FG.befehle.aufnahme("") end)
  k3:SetPoint("LEFT", k2, "RIGHT", 10, 0)
  merke({ Auffrischen = function() k3:SetText(R.aufnahme and L"Aufnahme beenden" or L"Route aufnehmen") end })

  local l = Liste(s, BREITE - 40, 7, 24, function()
    local karte = P:Spieler()
    local liste = {}
    for _, r in ipairs(R:Liste()) do liste[#liste + 1] = r end
    table.sort(liste, function(a, b)
      if (a.karte == karte) ~= (b.karte == karte) then return a.karte == karte end
      return (a.zeit or 0) > (b.zeit or 0)
    end)
    return liste
  end, function(z, r)
    z.icon:SetTexture(r.art == "erz" and FG.ARTEN.erz.symbol or FG.ARTEN.kraut.symbol)
    local zeichen = R.aktiv == r and "» " or ""
    z.links:SetText(zeichen .. r.name .. (r.versteckt and (" (" .. L"versteckt" .. ")") or ""))
    z.rechts:SetText(FG.Einzahl(L"%s · %d Punkte · %s":format(P:KartenName(r.karte), #r.punkte / 2, P:MeterText(R:Laenge(r)))))
    local g = FG.farben.akzent
    z.wahl:SetColorTexture(g[1], g[2], g[3], Fe.route == r and 0.18 or 0)
  end, function(r)
    Fe.route = r
    FG:Sprechen(r.name)
  end, function(z, r)
    GameTooltip:SetOwner(z, "ANCHOR_RIGHT")
    GameTooltip:AddLine(r.name)
    if r.von then GameTooltip:AddLine(L"Von %s":format(r.von), 0.8, 0.8, 0.8) end
    GameTooltip:AddLine(R:DauerText(r), 0.8, 0.8, 0.8)
    if r.runden then
      GameTooltip:AddLine(FG.Einzahl(L"%d Runden, beste %s, zuletzt %d Stück":format(r.runden, FG:ZeitText(r.bestzeit or 0), r.ertrag or 0)), 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine(L"Klick: auswählen", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  l:SetPoint("TOPLEFT", 0, -32)

  local function gewaehlt(fn) return function() if Fe.route then fn(Fe.route) else FG:Ansage(L"Wähle zuerst eine Route aus.") end end end
  local reihe = {
    { "", function(r) if R.aktiv == r then R:Anhalten() else R:Starten(r) end end, "start" },
    { L"Nächster Punkt", function() R:Weiter() end },
    { L"Umkehren", function(r) R:Umkehren(r) end },
    { "", function(r) r.versteckt = not r.versteckt or nil; FG:Rufe("routen") end, "versteckt" },
    { L"An Gruppe", function(r) T:RouteSenden(r, T:GruppenKanal()) end },
    { L"An Gilde", function(r) if IsInGuild and IsInGuild() then T:RouteSenden(r, "GUILD") else FG:Ansage(L"Du bist in keiner Gilde.") end end },
    { L"Code zeigen", function(r) Fe:Oeffnen("teilen"); Fe:CodeZeigen(T:RoutenCode(r)) end },
    { L"Löschen", function(r) R:Loeschen(r); Fe.route = nil end },
  }
  for i, e in ipairs(reihe) do
    local k = Knopf(s, e[1], 128, gewaehlt(e[2]))
    k:SetPoint("TOPLEFT", ((i - 1) % 4) * 134, -208 - math.floor((i - 1) / 4) * 28)
    if e[3] == "start" then
      merke({ Auffrischen = function() k:SetText(Fe.route and R.aktiv == Fe.route and L"Anhalten" or L"Abfahren") end })
    elseif e[3] == "versteckt" then
      merke({ Auffrischen = function() k:SetText(Fe.route and Fe.route.versteckt and L"Einblenden" or L"Ausblenden") end })
    end
  end
  local name = CreateFrame("EditBox", nil, s, "InputBoxTemplate")
  name:SetSize(300, 22)
  name:SetAutoFocus(false)
  name:SetPoint("TOPLEFT", 6, -272)
  name:SetScript("OnEnterPressed", function(self)
    if Fe.route and self:GetText() ~= "" then Fe.route.name = self:GetText(); FG:Rufe("routen"); Fe:Auffrischen() end
    self:ClearFocus()
  end)
  name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local hinweis = Text(s, "GameFontDisableSmall", L"Name ändern: eintippen und Eingabetaste drücken.", 240)
  hinweis:SetPoint("LEFT", name, "RIGHT", 12, 0)
  merke({ Auffrischen = function() if not name:HasFocus() then name:SetText(Fe.route and Fe.route.name or "") end end })
  local tipp = Text(s, "GameFontDisableSmall", L"Eine Route aus Fundorten führt als kürzester Rundweg durch alle sichtbaren Fundorte der Gegend. "
    .. L"Beim Abfahren springt der Wegpunkt weiter, sobald du nah genug bist. Mit „Route aufnehmen“ läufst du deine eigene Runde ab.", BREITE - 40)
  tipp:SetPoint("TOPLEFT", 0, -306)
end

bauen.lager = function(s)
  Fe.lagerArt = Fe.lagerArt or "alle"
  local arten = { { "alle", L"Alle" }, { "kraut", L"Kräuter" }, { "erz", L"Bergbau" }, { "leder", L"Leder" }, { "element", L"Elementar" } }
  for i, a in ipairs(arten) do
    local k = Karte(s, 100, 26, a[2], function() return Fe.lagerArt == a[1] end, function() Fe.lagerArt = a[1] end)
    k:SetPoint("TOPLEFT", (i - 1) * 106, 0)
  end
  local suche = CreateFrame("EditBox", nil, s, "InputBoxTemplate")
  suche:SetSize(200, 22)
  suche:SetAutoFocus(false)
  suche:SetPoint("TOPLEFT", 6, -34)
  suche:SetScript("OnTextChanged", function() Fe:Auffrischen() end)
  suche:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local such = Text(s, "GameFontDisableSmall", L"Suchen", 100)
  such:SetPoint("LEFT", suche, "RIGHT", 10, 0)
  local l = Liste(s, BREITE - 40, 10, 22, function() return La:Alle(Fe.lagerArt, suche:GetText()) end, function(z, e)
    z.icon:SetTexture(F:ItemSymbol(e.item))
    z.links:SetText(e.name)
    local _, liste = La:Bestand(e.item)
    local ziel = FG.char.ziele[e.item]
    local d = La:Veraenderung(e.item, e.menge)
    z.rechts:SetText(FG.Einzahl(L"%d auf %d Charakteren":format(e.menge, #liste))
      .. ((d and d ~= 0) and (" · " .. L"seit gestern %s%d":format(d > 0 and "+" or "", d)) or "")
      .. (ziel and (" · " .. L"Ziel %d/%d":format(math.min(FG.Extras:Stand(e.item), ziel), ziel)) or ""))
  end, function(e, taste)
    if taste == "RightButton" then FG.Extras:ZielFragen(e.item); return end
    local summe, liste = La:Bestand(e.item)
    local teile = {}
    for _, c in ipairs(liste) do teile[#teile + 1] = ("%s %d"):format(c.name, c.taschen + c.bank) end
    FG:Sprechen(("%s: %d. %s"):format(e.name, summe, table.concat(teile, ", ")), true)
  end, function(z, e)
    GameTooltip:SetOwner(z, "ANCHOR_RIGHT")
    GameTooltip:AddLine(e.name)
    La:TooltipItem(GameTooltip, e.item)
    GameTooltip:AddLine(L"Rechtsklick: Sammelziel setzen", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  l:SetPoint("TOPLEFT", 0, -64)
  local hinweis = Text(s, "GameFontDisableSmall", L"Taschen werden immer gezählt, die Bank, sobald du sie öffnest. "
    .. L"Jeder Charakter erscheint, nachdem du dich einmal mit ihm eingeloggt hast.", BREITE - 40)
  hinweis:SetPoint("TOPLEFT", 0, -292)
  local wert = Text(s, "GameFontHighlight", "", BREITE - 40)
  wert:SetPoint("TOPLEFT", 0, -326)
  merke({ Auffrischen = function()
    local w = La:Gesamtwert()
    wert:SetText(w > 0 and L"Wert aller Materialien: %s":format(FG:GeldText(w)) or "")
  end })
end

bauen.teilen = function(s)
  local rahmen = CreateFrame("ScrollFrame", nil, s, "UIPanelScrollFrameTemplate")
  rahmen:SetSize(BREITE - 70, 110)
  rahmen:SetPoint("TOPLEFT", 0, 0)
  Hintergrund(rahmen, 0.5)
  local box = CreateFrame("EditBox", nil, rahmen)
  box:SetMultiLine(true)
  box:SetAutoFocus(false)
  box:SetFontObject("ChatFontNormal")
  box:SetWidth(BREITE - 80)
  box:SetMaxLetters(0)
  box:SetHeight(108)
  rahmen:EnableMouse(true)
  rahmen:SetScript("OnMouseDown", function() box:SetFocus() end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  rahmen:SetScrollChild(box)
  Fe.codeBox = box

  local reihe = {
    { L"Code: diese Gegend", function()
      local code, n = T:FundortCode(P:Spieler())
      if code then Fe:CodeZeigen(code); FG:Ansage(L"Code mit %d Fundorten erstellt. Strg+C zum Kopieren.", n)
      else FG:Ansage(L"Keine Fundorte zum Teilen.") end
    end },
    { L"Code: alle Fundorte", function()
      local code, n = T:FundortCode()
      if code then Fe:CodeZeigen(code); FG:Ansage(L"Code mit %d Fundorten erstellt. Strg+C zum Kopieren.", n)
      else FG:Ansage(L"Keine Fundorte zum Teilen.") end
    end },
    { L"Code übernehmen", function() T:Importieren(box:GetText()); Fe:Auffrischen() end },
    { L"Leeren", function() box:SetText(""); box:SetFocus() end },
    { L"Gegend an Gruppe", function() T:FundorteSenden(P:Spieler(), T:GruppenKanal()) end },
    { L"Gegend an Gilde", function() if IsInGuild and IsInGuild() then T:FundorteSenden(P:Spieler(), "GUILD") else FG:Ansage(L"Du bist in keiner Gilde.") end end },
  }
  for i, e in ipairs(reihe) do
    local k = Knopf(s, e[1], 170, e[2])
    k:SetPoint("TOPLEFT", ((i - 1) % 3) * 178, -118 - math.floor((i - 1) / 3) * 28)
  end
  local liste = {
    { L"Funde mit Gruppe teilen", L"Neue Fundorte gehen an Mitspieler mit Forever Harvest.", "teilenGruppe" },
    { L"Funde mit Gilde teilen", L"Neue Fundorte gehen an die Gilde.", "teilenGilde" },
    { L"Funde anderer annehmen", L"Fundorte von Gruppe und Gilde übernehmen.", "empfangen" },
  }
  for i, e in ipairs(liste) do
    local f = DbSchalter(s, e[1], e[2], e[3])
    f:SetPoint("TOPLEFT", ((i - 1) % 2) * 300, -180 - math.floor((i - 1) / 2) * 40)
  end
  local t = Text(s, "GameFontNormal", L"Geschickte Routen")
  t:SetPoint("TOPLEFT", 0, -266)
  for i, o in ipairs({ { "fragen", L"Nachfragen" }, { "immer", L"Immer annehmen" }, { "nie", L"Ablehnen" } }) do
    local k = Karte(s, 130, 26, o[2], function() return FG.db.routenAnnehmen == o[1] end, function() FG.db.routenAnnehmen = o[1] end)
    k:SetPoint("TOPLEFT", 140 + (i - 1) * 136, -260)
  end
  local tipp = Text(s, "GameFontDisableSmall", L"Codes kannst du überall teilen, zum Beispiel im ForeverUI-Discord oder auf foreverui.de. "
    .. L"Wer den Code bei sich einfügt und „Code übernehmen“ klickt, bekommt die Fundorte oder die Route dazu. Doppelte Fundorte werden zusammengelegt.", BREITE - 40)
  tipp:SetPoint("TOPLEFT", 0, -300)
end

bauen.statistik = function(s)
  local St = FG.Statistik
  local kopf = Text(s, "GameFontHighlight", "", BREITE - 40)
  kopf:SetPoint("TOPLEFT", 0, 0)
  merke({ Auffrischen = function()
    local summe = St:Gesamt()
    local b = FG.root.besteSitzung
    local t = L"Insgesamt %d Stück gesammelt.":format(summe)
    if b then t = t .. " " .. FG.Einzahl(L"Beste Sitzung: %d Funde am %s":format(b.funde, St:TagText(b.datum))) end
    kopf:SetText(t)
  end })
  local t1 = Text(s, "GameFontNormal", L"Letzte Tage")
  t1:SetPoint("TOPLEFT", 0, -24)
  local tage = Liste(s, BREITE - 40, 5, 22, function() return St:Tage(14) end, function(z, e)
    z.icon:SetTexture(134939)
    z.links:SetText(St:TagText(e.tag))
    local r = FG.Einzahl(L"%d Funde · %d Stück":format(e.t.funde, e.t.stueck))
    if FG.db.wert and e.t.wert > 0 then r = r .. " · " .. FG:GeldText(e.t.wert) end
    z.rechts:SetText(r)
  end, function(e) FG:Sprechen(("%s: %d %s"):format(St:TagText(e.tag), e.t.stueck, L"Stück"), true) end)
  tage:SetPoint("TOPLEFT", 0, -42)
  local t2 = Text(s, "GameFontNormal", L"Beste Gegenden für dich")
  t2:SetPoint("TOPLEFT", 0, -162)
  local zonen = Liste(s, BREITE - 40, 8, 22, function() return St:Zonen() end, function(z, e)
    z.icon:SetTexture(e.erz > e.kraut and FG.ARTEN.erz.symbol or FG.ARTEN.kraut.symbol)
    z.links:SetText(e.name)
    z.rechts:SetText(St:ZonenText(e))
  end, function(e)
    St:KarteOeffnen(e.karte)
    FG:Sprechen(e.name .. ": " .. St:ZonenText(e))
  end, function(z, e)
    GameTooltip:SetOwner(z, "ANCHOR_RIGHT")
    GameTooltip:AddLine(e.name)
    GameTooltip:AddLine(FG.Einzahl(L"%d Fundorte, %d davon kannst du abbauen.":format(e.gesamt, e.abbaubar)), 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L"Klick: Karte öffnen", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  zonen:SetPoint("TOPLEFT", 0, -180)
end

bauen.hilfen = function(s)
  local liste = {
    { L"Radar", L"Fenster mit den nächsten Fundorten, Pfeil und Entfernung.", "radar" },
    { L"Nahe Fundorte ansagen", L"Name, Entfernung und Richtung als Uhrzeit.", "ansage" },
    { L"Klang in der Nähe", L"Kurzer Ton, wenn ein Fundort in Reichweite kommt.", "klang" },
    { L"Alarm bei Seltenem", L"Schwarzer Lotus, Echtsilber und Co. in der Nähe melden.", "seltenAlarm" },
    { L"Seltenes hervorheben", L"Seltene Vorkommen größer und gold umrandet.", "seltenHervorheben" },
    { L"Sammelziele hervorheben", L"Vorkommen für offene Ziele größer.", "zieleHervorheben" },
    { L"Im Kampf ausblenden", L"Keine Symbole auf der Minikarte während eines Kampfs.", "kampfAusblenden" },
    { L"Runden ansagen", L"Zeit und Ertrag nach jeder Runde einer Route.", "rundenAnsage" },
  }
  for i, e in ipairs(liste) do
    local f = DbSchalter(s, e[1], e[2], e[3])
    f:SetPoint("TOPLEFT", ((i - 1) % 2) * 300, -math.floor((i - 1) / 2) * 40)
  end
  local leer = Text(s, "GameFontNormal", "")
  leer:SetPoint("TOPLEFT", 0, -172)
  merke({ Auffrischen = function()
    local m = FG.db.abgeerntetMinuten or 0
    leer:SetText(m > 0 and L"Nach dem Ernten %d Min. als leer zeigen":format(m) or L"Abgeerntete Fundorte nicht markieren")
  end })
  local minus = Knopf(s, "–", 26, function() FG.db.abgeerntetMinuten = math.max(0, (FG.db.abgeerntetMinuten or 0) - 1); FG:Anwenden() end)
  minus:SetPoint("TOPLEFT", 330, -168)
  local plus = Knopf(s, "+", 26, function() FG.db.abgeerntetMinuten = math.min(30, (FG.db.abgeerntetMinuten or 0) + 1); FG:Anwenden() end)
  plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)
  local t = Text(s, "GameFontNormal", L"Sammelziele")
  t:SetPoint("TOPLEFT", 0, -204)
  local ziele = Liste(s, BREITE - 40, 5, 22, function() return FG.Extras:Ziele() end, function(z, e)
    z.icon:SetTexture(F:ItemSymbol(e.item))
    z.links:SetText(e.name)
    z.rechts:SetText(("%d / %d"):format(math.min(e.stand, e.ziel), e.ziel) .. (e.stand >= e.ziel and (" · " .. L"erreicht") or ""))
  end, function(e, taste)
    if taste == "RightButton" then FG.Extras:ZielSetzen(e.item, 0) else FG.Extras:ZielFragen(e.item) end
  end, function(z, e)
    GameTooltip:SetOwner(z, "ANCHOR_RIGHT")
    GameTooltip:AddLine(e.name)
    GameTooltip:AddLine(L"Klick: ändern · Rechtsklick: entfernen", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  ziele:SetPoint("TOPLEFT", 0, -222)
  local tipp = Text(s, "GameFontDisableSmall", L"Ziele setzt du per Rechtsklick im Lager oder mit /fg ziel 40 Friedensblume. "
    .. L"Gezählt wird, was dieser Charakter in Taschen und Bank hat.", BREITE - 40)
  tipp:SetPoint("TOPLEFT", 0, -340)
end

bauen.zugang = function(s)
  local t1 = Text(s, "GameFontNormal", L"Barrierefreiheit")
  t1:SetPoint("TOPLEFT", 0, 0)
  local liste = {
    { L"Vorlesen", L"Ansagen, Wegpunkte und Listen per Sprachausgabe.", "vorlesen" },
    { L"Hoher Kontrast", L"Undurchsichtige Fenster, weiße Schrift, kräftige Ränder.", "kontrast" },
    { L"Farbenblind-Modus", L"Blau und Orange statt Grün und Rot.", "farbenblind" },
    { L"Alles größer", L"Fenster und Kartensymbole ein Viertel größer.", "allesGroesser" },
    { L"Weniger Bewegung", L"Keine Einblendeffekte.", "wenigerBewegung" },
  }
  for i, e in ipairs(liste) do
    local f = DbSchalter(s, e[1], e[2], e[3])
    f:SetPoint("TOPLEFT", ((i - 1) % 2) * 300, -20 - math.floor((i - 1) / 2) * 38)
  end
  local test = Knopf(s, L"Vorlesen testen", 150, function()
    if not FG:Sprechen(L"Hallo! So klingt Forever Harvest.", true) then
      FG:Meldung(L"die Sprachausgabe ist nicht verfügbar. In den Spieleinstellungen unter Barrierefreiheit › Text-zu-Sprache lässt sie sich einrichten.")
    end
  end)
  test:SetPoint("TOPLEFT", 300, -100)

  local t2 = Text(s, "GameFontNormal", L"Profil")
  t2:SetPoint("TOPLEFT", 0, -150)
  local profil = Schalter(s, L"Eigene Einstellungen für diesen Charakter", L"Sonst gelten sie für alle Charaktere.",
    function() return FG.char.profil == "eigen" end,
    function(v) FG:ProfilWechseln(v and "eigen" or "konto") end)
  profil:SetPoint("TOPLEFT", 0, -170)

  local t3 = Text(s, "GameFontNormal", L"Sprache")
  t3:SetPoint("TOPLEFT", 0, -224)
  for i, o in ipairs({ { "auto", L"Auto" }, { "de", "Deutsch" }, { "en", "English" } }) do
    local k = Karte(s, 120, 26, o[2], function() return FG.db.sprache == o[1] end, function()
      FG.db.sprache = o[1]; FG:SpracheAnwenden(); FG:Meldung(L"Sprache geändert. Ganz wirkt sie nach /reload.")
    end)
    k:SetPoint("TOPLEFT", (i - 1) * 128, -244)
  end
  local zurueck = Knopf(s, L"Seite zurücksetzen", 160, function()
    for _, e in ipairs(liste) do FG.db[e[3]] = FG.STANDARD[e[3]] end
    FG:Anwenden()
  end)
  zurueck:SetPoint("TOPLEFT", 0, -300)
end

bauen.darstellung = function(s)
  local t1 = Text(s, "GameFontNormal", L"Akzentfarbe")
  t1:SetPoint("TOPLEFT", 0, 0)
  local namen = { gold = L"Gold", klasse = L"Klasse", eis = L"Eis", glut = L"Glut", wald = L"Wald", silber = L"Silber" }
  for i, a in ipairs(FG.AKZENTE) do
    local k = Karte(s, 92, 26, namen[a[1]] or a[2], function() return (FG.db.akzent or "gold") == a[1] end,
      function() FG.db.akzent = a[1]; FG:AkzentAnwenden() end)
    k:SetPoint("TOPLEFT", (i - 1) * 98, -20)
  end

  local t2 = Text(s, "GameFontNormal", L"Anzeige")
  t2:SetPoint("TOPLEFT", 0, -62)
  local liste = {
    { L"Bestand im Tooltip", L"Materialien aller Charaktere am Gegenstand.", "materialTooltip" },
    { L"Fertigkeit im Tooltip", L"Am Vorkommen: nötige Stufe und ob es klappt.", "vorkommenTooltip" },
    { L"Wert anzeigen", L"Wert der Sitzung (Händler- oder Auktionspreis).", "wert" },
    { L"Routen auf der Weltkarte", L"Linien der Routen dieser Gegend.", "routeLinien" },
    { L"Routenpunkt auf der Minikarte", L"Nächster Punkt der laufenden Route.", "routeMinikarte" },
    { L"Knopf an der Minikarte", L"Zum Öffnen des Fensters.", "minimapKnopf" },
    { L"Radar", L"Fenster mit den nächsten Fundorten, Pfeil und Entfernung.", "radar" },
    { L"Kartenfenster", L"Kleine Karte der Gegend mit Fundorten und Route.", "kartenfenster" },
    { L"Sitzungsanzeige", L"Kleines Feld mit Funden, Stück pro Stunde und Wert.", "sitzungsAnzeige" },
  }
  for i, e in ipairs(liste) do
    local f = DbSchalter(s, e[1], e[2], e[3])
    f:SetPoint("TOPLEFT", ((i - 1) % 2) * 300, -82 - math.floor((i - 1) / 2) * 38)
  end
  local zurueck = Knopf(s, L"Seite zurücksetzen", 160, function()
    FG.db.akzent = FG.STANDARD.akzent
    for _, e in ipairs(liste) do FG.db[e[3]] = FG.STANDARD[e[3]] end
    FG:Anwenden()
  end)
  zurueck:SetPoint("TOPLEFT", 0, -280)
end

-- Schreibgeschütztes Textfeld zum Kopieren (Strg+C).
local function KopierFeld(eltern, breite, hoehe)
  local rahmen = CreateFrame("ScrollFrame", nil, eltern, "UIPanelScrollFrameTemplate")
  rahmen:SetSize(breite, hoehe)
  Hintergrund(rahmen, 0.35)
  local box = CreateFrame("EditBox", nil, rahmen)
  box:SetMultiLine(true)
  box:SetAutoFocus(false)
  box:SetFontObject(ChatFontNormal or "GameFontHighlightSmall")
  box:SetWidth(breite - 10)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnTextChanged", function(self, vonHand) if vonHand and self.fest then self:SetText(self.fest) end end)
  box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  rahmen:SetScrollChild(box)
  rahmen.box = box
  rahmen.Setzen = function(text) box.fest = text; box:SetText(text) end
  return rahmen
end

bauen.bedienung = function(s)
  local t1 = Text(s, "GameFontNormal", L"So geht's")
  t1:SetPoint("TOPLEFT", 0, 0)
  local text = Text(s, "GameFontHighlightSmall", L"Sammle einfach wie immer: Jeder Fundort wird gemerkt und erscheint auf Welt- und Minikarte. "
    .. L"Klick auf einen Fundort setzt einen Wegpunkt, Rechtsklick löscht ihn, Strg+Klick macht ihn zum Favoriten. "
    .. L"Alle Funktionen haben Tastenkürzel (Tastaturbelegung › AddOns).", BREITE - 40)
  text:SetPoint("TOPLEFT", 0, -20)
  text:SetSpacing(2)
  local t2 = Text(s, "GameFontNormal", L"Befehle")
  t2:SetPoint("TOPLEFT", 0, -78)
  local befehle = KopierFeld(s, BREITE - 60, 170)
  befehle:SetPoint("TOPLEFT", 0, -98)
  merke({ Auffrischen = function() befehle.Setzen(table.concat(FG.HILFE, "\n")) end })
  local t3 = Text(s, "GameFontNormal", L"Discord und Feedback")
  t3:SetPoint("TOPLEFT", 0, -284)
  local link = KopierFeld(s, 300, 24)
  link:SetPoint("TOPLEFT", 0, -304)
  link.Setzen(FG.DISCORD or "https://foreverui.de/")
  local hinweis = Text(s, "GameFontDisableSmall", L"Fragen, Ideen und Fundort-Codes sind dort willkommen. Strg+C kopiert den Link.", 280)
  hinweis:SetPoint("TOPLEFT", 310, -304)
end

bauen.fehler = function(s)
  local t1 = Text(s, "GameFontNormal", L"Fehler melden")
  t1:SetPoint("TOPLEFT", 0, 0)
  local text = Text(s, "GameFontHighlightSmall", L"Läuft etwas schief, kopiere den Text unten (Strg+A, Strg+C) und schick ihn uns im Discord. "
    .. L"Das Protokoll beginnt mit jeder neuen Version leer.", BREITE - 40)
  text:SetPoint("TOPLEFT", 0, -20)
  local feld = KopierFeld(s, BREITE - 60, 230)
  feld:SetPoint("TOPLEFT", 0, -60)
  merke({ Auffrischen = function()
    local zeilen = { ("Forever Harvest %s · %s"):format(FG.version, select(4, GetBuildInfo()) or "?") }
    local liste = FG.root and FG.root.fehler or {}
    if #liste == 0 then zeilen[#zeilen + 1] = L"keine Fehler aufgezeichnet." end
    for _, f in ipairs(liste) do zeilen[#zeilen + 1] = f end
    feld.Setzen(table.concat(zeilen, "\n"))
  end })
  local leeren = Knopf(s, L"Protokoll leeren", 160, function() FG.root.fehler = {} end)
  leeren:SetPoint("TOPLEFT", 0, -304)
  local diag = Knopf(s, L"Diagnose schreiben", 160, function() FG:Diagnose(true) end)
  diag:SetPoint("LEFT", leeren, "RIGHT", 10, 0)
end

---------------------------------------------------------------------------
-- Fenster
---------------------------------------------------------------------------
-- Zahl mit – und + einstellen
local function Stellen(eltern, titelFn, minus, plus)
  local t = Text(eltern, "GameFontHighlight", "", 230)
  local m = Knopf(eltern, "–", 26, function() minus(); FG:Anwenden() end)
  local p = Knopf(eltern, "+", 26, function() plus(); FG:Anwenden() end)
  m:SetPoint("LEFT", t, "RIGHT", 6, 0)
  p:SetPoint("LEFT", m, "RIGHT", 4, 0)
  merke({ Auffrischen = function() t:SetText(titelFn()) end })
  return t
end
local function Begrenzt(schluessel, schritt, min, max)
  return function() FG.db[schluessel] = math.max(min, math.min(max, (FG.db[schluessel] or 0) + schritt)) end
end

bauen.hervorheben = function(s)
  local liste = {
    { L"Nahe Vorkommen pulsieren", L"Symbole in Reichweite werden größer und kleiner.", "puls" },
    { L"Leuchtrahmen", L"Rahmen um das nächste Vorkommen auf der Minikarte.", "leuchtring" },
    { L"Richtungspfeil", L"Pfeil am Minikartenrand zum nächsten Vorkommen.", "richtungspfeil" },
    { L"Hinweis am Bildschirm", L"Name, Entfernung und Richtung oben in der Mitte.", "nahHinweis" },
    { L"Rand bei Seltenem", L"Der Bildschirmrand leuchtet, wenn Seltenes in der Nähe ist.", "seltenRand" },
    { L"HUD", L"Durchsichtige Kreiskarte in der Bildschirmmitte, vorne ist oben.", "hud" },
    { L"Punkte-Markierung", L"Kleiner Punkt am Symbol, wenn es Fertigkeitspunkte bringt.", "punkteMarke" },
    { L"Reichweitenkreis", L"Kreis im Kartenfenster für die Pulsweite.", "reichweitenKreis" },
  }
  for i, e in ipairs(liste) do
    local f = DbSchalter(s, e[1], e[2], e[3])
    f:SetPoint("TOPLEFT", ((i - 1) % 2) * 300, -math.floor((i - 1) / 2) * 38)
  end
  local t = Text(s, "GameFontNormal", L"Farbe der Hervorhebung")
  t:SetPoint("TOPLEFT", 0, -160)
  for i, o in ipairs({ { "akzent", L"Akzent" }, { "art", L"Farbe der Art" }, { "weiss", L"Weiß" } }) do
    local k = Karte(s, 120, 26, o[2], function() return (FG.db.hervorFarbe or "akzent") == o[1] end,
      function() FG.db.hervorFarbe = o[1] end)
    k:SetPoint("TOPLEFT", (i - 1) * 128, -180)
  end
  local a = Stellen(s, function() return L"Pulsweite: %d m":format(FG.db.pulsWeite or 60) end,
    Begrenzt("pulsWeite", -10, 20, 200), Begrenzt("pulsWeite", 10, 20, 200))
  a:SetPoint("TOPLEFT", 0, -222)
  local b = Stellen(s, function() return L"Symbole Minikarte: %d":format(FG.db.minikartePinGroesse or 13) end,
    Begrenzt("minikartePinGroesse", -1, 8, 24), Begrenzt("minikartePinGroesse", 1, 8, 24))
  b:SetPoint("TOPLEFT", 300, -222)
  local c = Stellen(s, function()
    local w = FG.db.minikarteMaxWeite or 0
    return w > 0 and L"Minikarte bis %d m":format(w) or L"Minikarte: alle Entfernungen"
  end, Begrenzt("minikarteMaxWeite", -50, 0, 500), Begrenzt("minikarteMaxWeite", 50, 0, 500))
  c:SetPoint("TOPLEFT", 0, -254)
  local d = Stellen(s, function() return L"HUD-Größe: %d":format(FG.db.hudGroesse or 320) end,
    Begrenzt("hudGroesse", -40, 160, 600), Begrenzt("hudGroesse", 40, 160, 600))
  d:SetPoint("TOPLEFT", 300, -254)
  local e = Stellen(s, function() return L"HUD-Weite: %d m":format(FG.db.hudWeite or 120) end,
    Begrenzt("hudWeite", -20, 40, 400), Begrenzt("hudWeite", 20, 40, 400))
  e:SetPoint("TOPLEFT", 0, -286)
  local hinweis = Text(s, "GameFontDisableSmall", L"Vorkommen direkt in der 3D-Welt leuchten zu lassen, erlaubt das Spiel Addons nicht. "
    .. L"Alles hier läuft über Karten und Bildschirm und ist erlaubt.", BREITE - 40)
  hinweis:SetPoint("TOPLEFT", 0, -324)
  local zurueck = Knopf(s, L"Seite zurücksetzen", 160, function()
    for _, k in ipairs({ "pulsWeite", "minikartePinGroesse", "minikarteMaxWeite", "hudGroesse", "hudWeite", "hervorFarbe" }) do FG.db[k] = FG.STANDARD[k] end
    for _, x in ipairs(liste) do FG.db[x[3]] = FG.STANDARD[x[3]] end
    FG:Anwenden()
  end)
  zurueck:SetPoint("TOPLEFT", 0, -362)
end

bauen.fortschritt = function(s)
  local Fo = FG.Fortschritt
  local plan = Text(s, "GameFontHighlight", "", BREITE - 40)
  plan:SetPoint("TOPLEFT", 0, 0)
  plan:SetSpacing(3)
  merke({ Auffrischen = function()
    local zeilen = {}
    for _, art in ipairs({ "kraut", "erz" }) do
      zeilen[#zeilen + 1] = Fo:PlanerText(art)
      local z = Fo:ZielText(art)
      if z then zeilen[#zeilen + 1] = "   " .. z end
    end
    plan:SetText(table.concat(zeilen, "\n"))
  end })
  local t = Text(s, "GameFontNormal", L"Hier bekommst du gerade Punkte")
  t:SetPoint("TOPLEFT", 0, -96)
  local wohin = Liste(s, BREITE - 40, 3, 22, function() return Fo:Wohin(3) end, function(z, e)
    z.icon:SetTexture(FG.ARTEN.kraut.symbol)
    z.links:SetText(e.name)
    z.rechts:SetText(L"Klick: Karte öffnen")
  end, function(e) FG.Statistik:KarteOeffnen(e.karte) end)
  wohin:SetPoint("TOPLEFT", 0, -114)
  local t2 = Text(s, "GameFontNormal", L"Sammelberufe deiner Charaktere")
  t2:SetPoint("TOPLEFT", 0, -192)
  local chars = Liste(s, BREITE - 40, 5, 22, function() return Fo:Charaktere() end, function(z, e)
    z.icon:SetTexture(e.kraut and FG.ARTEN.kraut.symbol or FG.ARTEN.erz.symbol)
    z.links:SetText(e.key)
    local teile = {}
    if e.kraut then teile[#teile + 1] = L"Kräuterkunde" .. " " .. e.kraut end
    if e.erz then teile[#teile + 1] = L"Bergbau" .. " " .. e.erz end
    z.rechts:SetText(table.concat(teile, " · "))
  end, function() end)
  chars:SetPoint("TOPLEFT", 0, -210)
  local tipp = Text(s, "GameFontDisableSmall", L"Fertigkeitsziel setzen: /fg fertigkeit 150 kraut. Bei den Stufen 50, 125, 200 und 275 erinnert dich das Addon an den Lehrer.", BREITE - 40)
  tipp:SetPoint("TOPLEFT", 0, -332)
end

bauen.chronik = function(s)
  local Ch = FG.Chronik
  local kopf = Text(s, "GameFontHighlight", "", BREITE - 40)
  kopf:SetPoint("TOPLEFT", 0, 0)
  kopf:SetSpacing(3)
  merke({ Auffrischen = function()
    local r = FG.root.rekorde or {}
    local zeilen = { Ch:WocheText() }
    local tag = Ch:BesterTag()
    if tag then zeilen[#zeilen + 1] = FG.Einzahl(L"Bester Tag: %s mit %d Funden":format(FG.Statistik:TagText(tag.tag), tag.funde)) end
    if r.proStunde then zeilen[#zeilen + 1] = L"Rekord: %s Stück pro Stunde":format(FG:ZahlText(r.proStunde)) end
    if r.wert then zeilen[#zeilen + 1] = L"Wertvollste Sitzung: %s":format(FG:GeldText(r.wert)) end
    local top = {}
    for i, e in ipairs(Ch:TopMaterialien(3)) do top[i] = e.name end
    if top[1] then zeilen[#zeilen + 1] = L"Am meisten gesammelt: %s":format(table.concat(top, ", ")) end
    local rl = FG.Routen:Rangliste()
    if rl[1] then zeilen[#zeilen + 1] = L"Beste Route: %s (%s Stück pro Stunde)":format(rl[1].r.name, FG:ZahlText(rl[1].proStunde)) end
    local b = FG.Teilen:Beitraege()
    if b[1] then zeilen[#zeilen + 1] = FG.Einzahl(L"Am meisten geteilt: %s (%d Fundorte)":format(b[1].name, b[1].anzahl)) end
    kopf:SetText(table.concat(zeilen, "\n"))
  end })
  local t = Text(s, "GameFontNormal", L"Letzte Sitzungen")
  t:SetPoint("TOPLEFT", 0, -122)
  local l = Liste(s, BREITE - 40, 5, 22, function() return FG.root.sitzungen or {} end, function(z, e)
    z.icon:SetTexture(FG.ARTEN.kraut.symbol)
    z.links:SetText(e.datum .. (e.karte and (" · " .. e.karte) or ""))
    z.rechts:SetText(FG.Einzahl(L"%d Funde · %d Stück · %s":format(e.funde, e.stueck, FG:ZeitText(e.dauer))))
  end, function() end)
  l:SetPoint("TOPLEFT", 0, -140)
  local t2 = Text(s, "GameFontNormal", L"Bericht der Sitzung zum Kopieren")
  t2:SetPoint("TOPLEFT", 0, -258)
  local feld = KopierFeld(s, BREITE - 60, 90)
  feld:SetPoint("TOPLEFT", 0, -276)
  merke({ Auffrischen = function() feld.Setzen(Ch:BerichtText()) end })
end

bauen.komfort = function(s)
  local liste = {
    { L"Sammelkette", L"Nach dem Sammeln Wegpunkt zum nächsten Vorkommen.", "kette" },
    { L"Ruhe in Städten", L"Keine Ansagen in Städten und Gasthäusern.", "ruheInStaedten" },
    { L"Ruhe im Kampf", L"Keine Ansagen während eines Kampfs.", "kampfRuhe" },
    { L"Tipp des Tages", L"Ein Tipp zur Bedienung nach dem Einloggen.", "tipps" },
    { L"Neue Sorten melden", L"Wenn deine Fertigkeit eine neue Sorte freischaltet.", "neueSorten" },
    { L"Lehrer-Hinweise", L"Bei 50, 125, 200 und 275 und an der Grenze.", "lehrerHinweis" },
    { L"Leere Punkte überspringen", L"Routen springen über gerade abgeerntete Punkte.", "routeLeerUeberspringen" },
    { L"Routen nur abbaubar", L"Neue Routen nur durch Vorkommen, die du abbauen kannst.", "routeNurAbbaubar" },
    { L"Route im Kampf pausieren", L"Die Rundenzeit läuft im Kampf nicht weiter.", "routeKampfPause" },
    { L"Rekorde ansagen", L"Meldung bei einem neuen Sitzungsrekord.", "rekordAnsage" },
  }
  for i, e in ipairs(liste) do
    local f = DbSchalter(s, e[1], e[2], e[3])
    f:SetPoint("TOPLEFT", ((i - 1) % 2) * 300, -math.floor((i - 1) / 2) * 38)
  end
  local a = Stellen(s, function()
    local n = FG.db.taschenWarnung or 0
    return n > 0 and L"Taschen-Warnung ab %d freien Plätzen":format(n) or L"Taschen-Warnung aus"
  end, Begrenzt("taschenWarnung", -1, 0, 10), Begrenzt("taschenWarnung", 1, 0, 10))
  a:SetPoint("TOPLEFT", 0, -200)
  local b = Stellen(s, function()
    local n = FG.db.abseitsWeite or 0
    return n > 0 and L"Hinweis abseits der Route ab %d m":format(n) or L"Hinweis abseits der Route aus"
  end, Begrenzt("abseitsWeite", -100, 0, 1000), Begrenzt("abseitsWeite", 100, 0, 1000))
  b:SetPoint("TOPLEFT", 0, -232)
  local timer = Text(s, "GameFontHighlight", "", 300)
  timer:SetPoint("TOPLEFT", 0, -270)
  merke({ Auffrischen = function()
    local rest = FG.Komfort:TimerRest()
    timer:SetText(rest and L"Sammel-Timer: noch %s":format(FG:ZeitText(rest)) or L"Sammel-Timer aus")
  end })
  local k1 = Knopf(s, L"Timer 30 Min.", 140, function() FG.Komfort:TimerStarten(30) end)
  k1:SetPoint("TOPLEFT", 300, -266)
  local k2 = Knopf(s, L"Timer aus", 120, function() FG.Komfort:TimerStarten(0) end)
  k2:SetPoint("LEFT", k1, "RIGHT", 6, 0)
  local k3 = Knopf(s, L"Rückgängig", 140, function() FG.Komfort:Rueckgaengig() end)
  k3:SetPoint("TOPLEFT", 0, -304)
  local k4 = Knopf(s, L"Sicherung zurückholen", 180, function() FG.Komfort:Wiederherstellen() end)
  k4:SetPoint("LEFT", k3, "RIGHT", 6, 0)
  local tipp = Text(s, "GameFontDisableSmall", L"Rückgängig holt den zuletzt gelöschten Fundort zurück. Vor dem Aufräumen und vor dem Löschen einer ganzen Sorte legt das Addon eine Sicherung an. "
    .. L"Funde bestimmter Spieler ignorierst du mit /fg sperren Name.", BREITE - 40)
  tipp:SetPoint("TOPLEFT", 0, -338)
end

bauen.neuigkeiten = function(s)
  local t = Text(s, "GameFontNormal", L"Neu in Version 0.4")
  t:SetPoint("TOPLEFT", 0, 0)
  local feld = KopierFeld(s, BREITE - 60, 330)
  feld:SetPoint("TOPLEFT", 0, -20)
  merke({ Auffrischen = function() feld.Setzen(table.concat(FG:Neuigkeiten(), "\n")) end })
end

local function Flaeche(f, ebene, r, g, b, a)
  local t = f:CreateTexture(nil, ebene or "BACKGROUND")
  t:SetColorTexture(r, g, b, a)
  return t
end

-- Vier 1-px-Kanten als Rand.
local function Rand(f, r, g, b, a)
  f.kanten = {}
  local function kante(p1, p2, breit)
    local t = f:CreateTexture(nil, "BORDER")
    t:SetPoint(p1); t:SetPoint(p2)
    if breit then t:SetHeight(1) else t:SetWidth(1) end
    t:SetColorTexture(r, g, b, a)
    f.kanten[#f.kanten + 1] = t
  end
  kante("TOPLEFT", "TOPRIGHT", true); kante("BOTTOMLEFT", "BOTTOMRIGHT", true)
  kante("TOPLEFT", "BOTTOMLEFT"); kante("TOPRIGHT", "BOTTOMRIGHT")
end

local function Suchen(text)
  text = (text or ""):lower()
  if #text < 2 then return end
  for _, e in ipairs(suchListe) do
    if e[1]:lower():find(text, 1, true) then
      Fe:Oeffnen(e[2])
      if e[3].knopf and e[3].knopf.LockHighlight then e[3].knopf:LockHighlight() end
      Fe.gefunden = e
      return e
    end
  end
end
Fe.Suchen = Suchen

local function Bauen()
  fenster = CreateFrame("Frame", "ForeverGatherFenster", UIParent)
  local gr = FG.db.fensterGroesse
  fenster:SetSize(gr and gr[1] or FB, gr and gr[2] or FH)
  fenster:SetFrameStrata("DIALOG")
  fenster:SetToplevel(true)
  fenster:SetClampedToScreen(true)
  fenster:EnableMouse(true)
  fenster:SetMovable(true)
  if fenster.SetResizable then fenster:SetResizable(true) end
  if fenster.SetResizeBounds then fenster:SetResizeBounds(FB, FH, 1400, 1000)
  elseif fenster.SetMinResize then fenster:SetMinResize(FB, FH) end
  fenster:RegisterForDrag("LeftButton")
  fenster:SetScript("OnDragStart", fenster.StartMoving)
  fenster:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    FG.db.fensterPos = { p, rp, x, y }
  end)
  Hintergrund(fenster, 0.99)
  local a = FG.farben.akzent
  Rand(fenster, a[1], a[2], a[3], 0.45)
  fenster.band = Flaeche(fenster, "BORDER", a[1], a[2], a[3], 0.08)
  fenster.band:SetPoint("TOPLEFT", 1, -1); fenster.band:SetPoint("TOPRIGHT", -1, -1); fenster.band:SetHeight(64)

  fenster.name = Text(fenster, "GameFontNormalSmall", "FOREVER HARVEST")
  fenster.name:SetPoint("TOPLEFT", 24, -16)
  fenster.titel = Text(fenster, "GameFontHighlightLarge", "")
  fenster.titel:SetPoint("TOPLEFT", 24, -34)
  local zu = CreateFrame("Button", nil, fenster, "UIPanelCloseButton")
  zu:SetPoint("TOPRIGHT", -4, -4)
  zu:SetScript("OnClick", function() Fe:Schliessen() end)
  tinsert(UISpecialFrames, "ForeverGatherFenster")

  -- Suche oben rechts
  local suche = CreateFrame("EditBox", nil, fenster, "InputBoxTemplate")
  suche:SetSize(200, 20)
  suche:SetPoint("TOPRIGHT", -44, -24)
  suche:SetAutoFocus(false)
  suche.leer = Text(suche, "GameFontDisableSmall", L"Einstellung suchen …")
  suche.leer:SetPoint("LEFT", 2, 0)
  suche:SetScript("OnTextChanged", function(self)
    local t = self:GetText()
    suche.leer:SetShown(t == "")
    FG:Sicher("Suche", Suchen, t)
  end)
  suche:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  suche:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  Fe.suche = suche

  -- Seitenleiste
  local leiste = CreateFrame("Frame", nil, fenster)
  leiste:SetPoint("TOPLEFT", 1, -65)
  leiste:SetPoint("BOTTOMLEFT", 1, 1)
  leiste:SetWidth(SEITENLEISTE)
  Hintergrund(leiste, 0.5)
  fenster.leiste = leiste
  fenster.gruppen = {}
  local y = -14
  for _, g in ipairs(GRUPPEN) do
    local kopf = Text(leiste, "GameFontNormalSmall", g[1])
    kopf:SetPoint("TOPLEFT", 16, y)
    fenster.gruppen[#fenster.gruppen + 1] = kopf
    y = y - 18
    for _, r in ipairs(g[2]) do
      local k = CreateFrame("Button", nil, leiste)
      k:SetSize(SEITENLEISTE, 18)
      k:SetPoint("TOPLEFT", 0, y)
      k.wahl = Flaeche(k, "BACKGROUND", 1, 1, 1, 0)
      k.wahl:SetAllPoints()
      k.strich = Flaeche(k, "BORDER", 1, 1, 1, 0)
      k.strich:SetPoint("TOPLEFT"); k.strich:SetPoint("BOTTOMLEFT"); k.strich:SetWidth(2)
      local hl = k:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      hl:SetColorTexture(1, 1, 1, 0.05)
      k.text = Text(k, "GameFontHighlightSmall", r[2], SEITENLEISTE - 32)
      k.text:SetPoint("LEFT", 24, 0)
      k:SetScript("OnClick", function() Fe:Oeffnen(r[1]) end)
      reiterKnoepfe[r[1]] = k
      y = y - 18
    end
    y = y - 10
  end
  local version = Text(leiste, "GameFontDisableSmall", L"Version %s":format(FG.version))
  version:SetPoint("BOTTOMLEFT", 16, 12)

  -- Inhaltskasten
  local kasten = CreateFrame("Frame", nil, fenster)
  kasten:SetPoint("TOPLEFT", SEITENLEISTE + 12, -76)
  kasten:SetPoint("BOTTOMRIGHT", -12, 44)
  Hintergrund(kasten, 0.35)
  Rand(kasten, 1, 1, 1, 0.08)
  fenster.kasten = kasten

  local schliessen = Knopf(fenster, L"Schließen", 120, function() Fe:Schliessen() end)
  schliessen:SetPoint("BOTTOMRIGHT", -12, 12)

  -- Griff zum Vergrößern
  local griff = CreateFrame("Button", nil, fenster)
  griff:SetSize(16, 16)
  griff:SetPoint("BOTTOMRIGHT", -2, 2)
  griff:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  griff:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  griff:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  griff:SetScript("OnMouseDown", function() if fenster.StartSizing then fenster:StartSizing("BOTTOMRIGHT") end end)
  griff:SetScript("OnMouseUp", function()
    fenster:StopMovingOrSizing()
    FG.db.fensterGroesse = { math.floor(fenster:GetWidth() + 0.5), math.floor(fenster:GetHeight() + 0.5) }
  end)

  fenster:SetScript("OnHide", function()
    if not FG.db.eingerichtet then FG.db.eingerichtet = true end
  end)
  Fe.rahmen = fenster
  fenster:Hide()
end

local function Seite(name)
  if not seiten[name] then
    local s = CreateFrame("Frame", nil, fenster.kasten)
    s:SetPoint("TOPLEFT", 16, -14)
    s:SetPoint("BOTTOMRIGHT", -16, 10)
    seiten[name] = s
    bautSeite = name
    bauen[name](s)
    bautSeite = nil
  end
  return seiten[name]
end

local function TitelVon(name)
  for _, r in ipairs(REITER) do if r[1] == name then return r[2] end end
  return ""
end

function Fe:Auffrischen()
  if not fenster or not fenster:IsShown() then return end
  fenster:SetScale(FG:Groesse())
  fenster.hg:SetColorTexture(0.06, 0.06, 0.08, FG:Deckkraft(0.99))
  local a = FG.farben.akzent
  for _, t in ipairs(fenster.kanten) do t:SetColorTexture(a[1], a[2], a[3], FG.db.kontrast and 0.9 or 0.45) end
  fenster.band:SetColorTexture(a[1], a[2], a[3], 0.08)
  fenster.name:SetTextColor(a[1], a[2], a[3])
  fenster.titel:SetText(TitelVon(aktuell))
  for _, k in ipairs(fenster.gruppen) do k:SetTextColor(a[1], a[2], a[3]) end
  for name, k in pairs(reiterKnoepfe) do
    local an = name == aktuell
    k.wahl:SetColorTexture(a[1], a[2], a[3], an and 0.14 or 0)
    k.strich:SetColorTexture(a[1], a[2], a[3], an and 1 or 0)
    local h = FG.farben.hell
    if an then k.text:SetTextColor(1, 1, 1) else k.text:SetTextColor(h[1], h[2], h[3]) end
  end
  for _, e in ipairs(elemente) do FG:Sicher("Fenster", e.Auffrischen) end
end

function Fe:Oeffnen(name)
  if not fenster then
    Bauen()
    for _, r in ipairs(REITER) do Seite(r[1]):Hide() end   -- alle Seiten bauen, damit die Suche alles findet
  end
  name = ALIAS[name] or name
  aktuell = (name and bauen[name]) and name or aktuell
  for n, s in pairs(seiten) do if n ~= aktuell then s:Hide() end end
  Seite(aktuell):Show()
  if not fenster:IsShown() then
    fenster:ClearAllPoints()
    local p = FG.db.fensterPos
    if p then fenster:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else fenster:SetPoint("CENTER", 0, 40) end
    fenster:Show()
  end
  self:Auffrischen()
  FG:Sprechen("Forever Harvest: " .. TitelVon(aktuell))
end

function Fe:Schliessen() if fenster then fenster:Hide() end end

function Fe:Umschalten()
  if fenster and fenster:IsShown() then self:Schliessen() else self:Oeffnen() end
end

function Fe:CodeZeigen(code)
  if not Fe.codeBox then return end
  Fe.codeBox:SetText(code)
  Fe.codeBox:SetFocus()
  Fe.codeBox:HighlightText()
end

function Fe:Anwenden() self:Auffrischen(); self:SitzungsAnzeigeAuffrischen() end

---------------------------------------------------------------------------
-- Sitzungsanzeige: kleines Feld mit dem, was gerade gesammelt wird.
---------------------------------------------------------------------------
local anzeige
function Fe:SitzungsAnzeigeAuffrischen()
  if not FG.db.sitzungsAnzeige then if anzeige then anzeige:Hide() end return end
  if not anzeige then
    anzeige = CreateFrame("Frame", "ForeverGatherSitzung", UIParent)
    anzeige:SetSize(230, 40)
    anzeige:SetMovable(true)
    anzeige:EnableMouse(true)
    anzeige:RegisterForDrag("LeftButton")
    anzeige:SetScript("OnDragStart", anzeige.StartMoving)
    anzeige:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local p, _, rp, x, y = self:GetPoint()
      FG.db.sitzungsPos = { p, rp, x, y }
    end)
    anzeige:SetScript("OnMouseUp", function(_, taste) if taste == "RightButton" then Fe:Oeffnen("start") end end)
    Hintergrund(anzeige, 0.7)
    anzeige.oben = Text(anzeige, "GameFontNormalSmall", "", 220)
    anzeige.oben:SetPoint("TOPLEFT", 6, -5)
    anzeige.unten = Text(anzeige, "GameFontHighlightSmall", "", 220)
    anzeige.unten:SetPoint("TOPLEFT", 6, -21)
    anzeige.ziele = Text(anzeige, "GameFontHighlightSmall", "", 220)
    anzeige.ziele:SetPoint("TOPLEFT", 6, -37)
    local p = FG.db.sitzungsPos
    if p then anzeige:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else anzeige:SetPoint("TOP", 0, -120) end
    local zeit = 0
    anzeige:SetScript("OnUpdate", function(_, dt)
      zeit = zeit + (dt or 0)
      if zeit >= 1 then zeit = 0; Fe:SitzungsAnzeigeAuffrischen() end
    end)
  end
  anzeige:SetScale(FG:Groesse())
  anzeige.hg:SetColorTexture(0.06, 0.06, 0.08, FG:Deckkraft(0.7))
  local s = FG.sitzung
  anzeige.oben:SetText(FG.Einzahl(L"Forever Harvest · %s · %d Funde":format(FG:ZeitText(F:SitzungDauer()), s.funde)))
  local menge = 0
  for _, n in pairs(s.items) do menge = menge + n end
  local unten = L"%d Stück · %s pro Stunde":format(menge, FG:ZahlText(F:ProStunde(menge)))
  if FG.db.wert and s.wert > 0 then unten = unten .. " · " .. FG:GeldText(s.wert) end
  anzeige.unten:SetText(unten)
  local ziele = FG.Extras:ZieleText()
  anzeige.ziele:SetText(ziele ~= "" and (L"Ziele: %s":format(ziele)) or "")
  anzeige:SetHeight(ziele ~= "" and 56 or 40)
  anzeige:Show()
end

function Fe:SitzungsAnzeigeUmschalten()
  FG.db.sitzungsAnzeige = not FG.db.sitzungsAnzeige
  self:SitzungsAnzeigeAuffrischen()
end

function Fe:Start()
  FG:Haken("sitzung", function() Fe:Auffrischen() end)
  FG:Haken("routen", function() Fe:Auffrischen() end)
  FG:Haken("lager", function() Fe:Auffrischen() end)
  FG:Haken("fundorte", function() Fe:Auffrischen() end)
  FG:Haken("ziele", function() Fe:Auffrischen(); Fe:SitzungsAnzeigeAuffrischen() end)
end

FG.tasten.fenster = function() Fe:Umschalten() end
FG.tasten.einstellungen = function() Fe:Oeffnen("einstellungen") end
FG.tasten.sitzung = function() Fe:SitzungsAnzeigeUmschalten() end
