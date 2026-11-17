-- Forever Harvest als Plugin in ForeverUI: die wichtigsten Einstellungen erscheinen im
-- ForeverUI-Fenster unter „Plugins“, und mit eingeschaltetem Interface übernimmt Forever Harvest
-- dessen Akzentfarbe. Ohne ForeverUI passiert hier nichts.
local _, FG = ...
local L = FG.L

local function db() return FG.db end

local plugin = {
  id = "harvest",
  titel = "Forever Harvest",
  einstellungen = {
    { id = "interfaceAussehen", art = "schalter", titel = L"Aussehen von ForeverUI übernehmen", standard = true,
      text = L"Akzentfarbe wie im ForeverUI-Interface, solange es eingeschaltet ist." },
    { id = "weltkarte", art = "schalter", titel = L"Auf der Weltkarte", text = L"Symbole auf der großen Karte (M).", standard = true },
    { id = "minikarte", art = "schalter", titel = L"Auf der Minikarte", text = L"Symbole in der Nähe auf der Minikarte.", standard = true },
    { id = "pinGroesse", art = "regler", titel = L"Symbolgröße auf der Weltkarte", min = 10, max = 32, schritt = 2, standard = 16 },
    { id = "minikartePinGroesse", art = "regler", titel = L"Symbolgröße auf der Minikarte", min = 8, max = 24, schritt = 1, standard = 13 },
    { id = "nurEigenerBeruf", art = "schalter", titel = L"Nur eigene Berufe", text = L"Kräuter nur mit Kräuterkunde, Erze nur mit Bergbau.", standard = true },
    { id = "nurAbbaubar", art = "schalter", titel = L"Nur abbaubare", text = L"Vorkommen über deiner Fertigkeit ausblenden.", standard = false },
    { id = "minikarteRand", art = "schalter", titel = L"Entfernte am Rand", text = L"Fundorte außerhalb der Minikarte am Rand zeigen.", standard = false },
    { id = "kampfAusblenden", art = "schalter", titel = L"Im Kampf ausblenden", text = L"Keine Symbole auf der Minikarte während eines Kampfs.", standard = true },
    { id = "puls", art = "schalter", titel = L"Nahe Vorkommen pulsieren", text = L"Symbole in Reichweite werden größer und kleiner.", standard = true },
    { id = "richtungspfeil", art = "schalter", titel = L"Richtungspfeil", text = L"Pfeil am Minikartenrand zum nächsten Vorkommen.", standard = true },
    { id = "seltenAlarm", art = "schalter", titel = L"Alarm bei Seltenem", text = L"Schwarzer Lotus, Echtsilber und Co. in der Nähe melden.", standard = true },
    { id = "abgeerntetMinuten", art = "regler", titel = L"Abgeerntet markieren (Minuten)", min = 0, max = 30, schritt = 1, standard = 5 },
    { id = "radar", art = "schalter", titel = L"Radar", text = L"Fenster mit den nächsten Fundorten, Pfeil und Entfernung.", standard = false },
    { id = "kartenfenster", art = "schalter", titel = L"Kartenfenster", text = L"Kleine Karte der Gegend mit Fundorten und Route.", standard = false },
    { id = "materialTooltip", art = "schalter", titel = L"Bestand im Tooltip", text = L"Materialien aller Charaktere am Gegenstand.", standard = true },
    { id = "vorkommenTooltip", art = "schalter", titel = L"Fertigkeit im Tooltip", text = L"Am Vorkommen: nötige Stufe und ob es klappt.", standard = true },
    { id = "teilenGruppe", art = "schalter", titel = L"Funde mit Gruppe teilen", text = L"Neue Fundorte gehen an Mitspieler mit Forever Harvest.", standard = true, stufe = "profi" },
    { id = "teilenGilde", art = "schalter", titel = L"Funde mit Gilde teilen", text = L"Neue Fundorte gehen an die Gilde.", standard = false, stufe = "profi" },
    { id = "empfangen", art = "schalter", titel = L"Funde anderer annehmen", text = L"Fundorte von Gruppe und Gilde übernehmen.", standard = true, stufe = "profi" },
  },
  lesen = function(id) local d = db(); return d and d[id] end,
  schreiben = function(id, wert)
    local d = db()
    if d then d[id] = wert end
    if id == "interfaceAussehen" then FG:InterfaceAussehen() end
  end,
  anwenden = function() FG:Anwenden() end,
}

-- Aussehen des Interface übernehmen (nur wenn ForeverUI das Interface an hat und der Spieler es will)
function FG:InterfaceAussehen(a)
  if a then self.fuiAussehen = a end
  a = self.fuiAussehen
  local an = a and a.an and (not self.db or self.db.interfaceAussehen ~= false)
  self.fuiAkzent = an and a.akzent or nil
  self:AkzentAnwenden()
  if self.db then self:Anwenden() end
end
plugin.aussehen = function(a) FG:InterfaceAussehen(a) end

FG.plugin = plugin
local fui = _G.ForeverUI
if type(fui) == "table" and fui.PluginAnmelden then
  fui:PluginAnmelden(plugin)
else
  _G.ForeverUIPlugins = _G.ForeverUIPlugins or {}
  table.insert(_G.ForeverUIPlugins, plugin)
end
