-- Forever Gather: bekannte Vorkommen (Kräuter, Erzadern, Ablagerungen).
-- Schlüssel ist die Objektnummer des Spiels, damit Funde in jeder Sprache zusammenpassen.
-- { Art, deutscher Name, englischer Name, nötige Fertigkeit, Hauptmaterial }
-- Unbekannte Vorkommen lernt das Addon beim Sammeln selbst (Name aus dem Spiel).
local _, FG = ...

FG.KNOTEN = {
  -- Kräuter
  [1618]   = { "kraut", "Friedensblume", "Peacebloom", 1, 2447 },
  [1617]   = { "kraut", "Silberblatt", "Silverleaf", 1, 765 },
  [1619]   = { "kraut", "Erdwurzel", "Earthroot", 15, 2449 },
  [1620]   = { "kraut", "Maguskönigskraut", "Mageroyal", 50, 785 },
  [1621]   = { "kraut", "Wilddornrose", "Briarthorn", 70, 2450 },
  [2045]   = { "kraut", "Würgetang", "Stranglekelp", 85, 3820 },
  [1622]   = { "kraut", "Beulengras", "Bruiseweed", 100, 2453 },
  [1623]   = { "kraut", "Wildstahlblume", "Wild Steelbloom", 115, 3355 },
  [1628]   = { "kraut", "Grabmoos", "Grave Moss", 120, 3369 },
  [1624]   = { "kraut", "Königsblut", "Kingsblood", 125, 3356 },
  [2041]   = { "kraut", "Lebenswurz", "Liferoot", 150, 3357 },
  [2042]   = { "kraut", "Blassblatt", "Fadeleaf", 160, 3818 },
  [2046]   = { "kraut", "Golddorn", "Goldthorn", 170, 3821 },
  [2043]   = { "kraut", "Khadgars Schnurrbart", "Khadgar's Whisker", 185, 3358 },
  [2044]   = { "kraut", "Winterbiss", "Wintersbite", 195, 3819 },
  [2866]   = { "kraut", "Feuerblüte", "Firebloom", 205, 4625 },
  [142140] = { "kraut", "Lila Lotus", "Purple Lotus", 210, 8831 },
  [142141] = { "kraut", "Arthas' Tränen", "Arthas' Tears", 220, 8836 },
  [142142] = { "kraut", "Sonnengras", "Sungrass", 230, 8838 },
  [142143] = { "kraut", "Blindkraut", "Blindweed", 235, 8839 },
  [142144] = { "kraut", "Geisterpilz", "Ghost Mushroom", 245, 8845 },
  [142145] = { "kraut", "Gromsblut", "Gromsblood", 250, 8846 },
  [176583] = { "kraut", "Goldener Sansam", "Golden Sansam", 260, 13464 },
  [176584] = { "kraut", "Traumblatt", "Dreamfoil", 270, 13463 },
  [176586] = { "kraut", "Bergsilberweisling", "Mountain Silversage", 280, 13465 },
  [176587] = { "kraut", "Pestblüte", "Plaguebloom", 285, 13466 },
  [176588] = { "kraut", "Eiskappe", "Icecap", 290, 13467 },
  [176589] = { "kraut", "Schwarzer Lotus", "Black Lotus", 300, 13468 },
  -- Bergbau
  [1731]   = { "erz", "Kupferader", "Copper Vein", 1, 2770 },
  [1732]   = { "erz", "Zinnader", "Tin Vein", 65, 2771 },
  [1733]   = { "erz", "Silberader", "Silver Vein", 75, 2775 },
  [1735]   = { "erz", "Eisenvorkommen", "Iron Deposit", 125, 2772 },
  [1734]   = { "erz", "Goldader", "Gold Vein", 155, 2776 },
  [2040]   = { "erz", "Mithrilablagerung", "Mithril Deposit", 175, 3858 },
  [2047]   = { "erz", "Echtsilberablagerung", "Truesilver Deposit", 230, 7911 },
  [165658] = { "erz", "Dunkeleisenablagerung", "Dark Iron Deposit", 230, 11370 },
  [324]    = { "erz", "Kleine Thoriumader", "Small Thorium Vein", 245, 10620 },
  [175404] = { "erz", "Reiche Thoriumader", "Rich Thorium Vein", 275, 10620 },
}

-- Sammelzauber: Zaubernummer → Art. Namen werden zusätzlich zur Laufzeit aus dem Spiel gelesen,
-- damit auch spätere Ränge mit anderer Nummer erkannt werden.
FG.SAMMELZAUBER = {
  [2366] = "kraut", [2368] = "kraut", [3570] = "kraut", [11993] = "kraut",
  [2575] = "erz", [2576] = "erz", [3564] = "erz", [10248] = "erz",
  [3365] = "schatz", [6247] = "schatz", [6477] = "schatz", [21651] = "schatz",
}
FG.SAMMELNAMEN = {
  ["Kräutersammeln"] = "kraut", ["Herb Gathering"] = "kraut",
  ["Bergbau"] = "erz", ["Mining"] = "erz",
  ["Öffnen"] = "schatz", ["Opening"] = "schatz",
}

-- Fertigkeitslinien der Berufe
FG.BERUFE = {
  kraut = { linie = 182, namen = { "Kräuterkunde", "Herbalism" } },
  erz   = { linie = 186, namen = { "Bergbau", "Mining" } },
}

-- Arten mit Symbol und Farbe (Farbe nie allein: Symbol und Name tragen die Bedeutung)
FG.ARTEN = {
  kraut  = { symbol = 133939, farbe = { 0.45, 0.85, 0.45 }, farbenblind = { 0.35, 0.65, 1 } },
  erz    = { symbol = 134566, farbe = { 0.95, 0.65, 0.35 }, farbenblind = { 1, 0.6, 0.1 } },
  schatz = { symbol = 132594, farbe = { 0.95, 0.85, 0.35 }, farbenblind = { 0.95, 0.95, 0.95 } },
}
FG.ARTEN_REIHE = { "kraut", "erz", "schatz" }

-- Seltene Vorkommen: größer auf der Karte, Alarm in der Nähe
FG.SELTEN = {
  o176589 = true, -- Schwarzer Lotus
  o1733 = true,   -- Silberader
  o1734 = true,   -- Goldader
  o2047 = true,   -- Echtsilberablagerung
  o165658 = true, -- Dunkeleisenablagerung
  o175404 = true, -- Reiche Thoriumader
}
