-- Forever Harvest: Liste der Neuerungen für die Seite „Neuigkeiten“.
local _, FG = ...
local L = FG.L

local DE = {
  "Hervorheben",
  "1. Nahe Vorkommen pulsieren auf der Minikarte.",
  "2. Leuchtrahmen um das nächste Vorkommen auf der Minikarte.",
  "3. Hinweis oben am Bildschirm mit Name, Entfernung und Richtung.",
  "4. Der Bildschirmrand leuchtet, wenn Seltenes in der Nähe ist.",
  "5. Farbe der Hervorhebung wählbar: Akzent, Farbe der Art oder Weiß.",
  "6. HUD: durchsichtige Kreiskarte in der Bildschirmmitte (/fg hud).",
  "7. Symbolgröße der Minikarte einstellbar.",
  "8. Reichweitenkreis im Kartenfenster.",
  "9. Auch im Kartenfenster pulsieren nahe Vorkommen.",
  "10. Punkt am Symbol, wenn das Vorkommen Fertigkeitspunkte bringt.",
  "11. Minikarte auf Wunsch nur bis zu einer Entfernung.",
  "12. Richtungspfeil am Minikartenrand zum nächsten Vorkommen.",
  "Fortschritt",
  "13. Planer: was gerade Punkte bringt und was als Nächstes kommt (/fg planer).",
  "14. Gegenden, in denen du gerade Punkte bekommst (/fg wohin).",
  "15. Fertigkeitsaufstiege der Sitzung werden gezählt.",
  "16. Hinweis auf den Lehrer bei 50, 125, 200 und 275.",
  "17. Warnung an der Fertigkeitsgrenze.",
  "18. Fertigkeitsziel mit Fortschritt (/fg fertigkeit 150 kraut).",
  "19. Meldung, wenn eine neue Sorte freigeschaltet ist.",
  "Chronik",
  "20. Die letzten 20 Sitzungen werden gespeichert.",
  "21. Rekorde: meiste Stück, meiste Stück pro Stunde, wertvollste Sitzung.",
  "22. Diese Woche und letzte Woche im Vergleich.",
  "23. Bester Tag und die meistgesammelten Materialien.",
  "24. Bericht der Sitzung zum Kopieren.",
  "25. Zusammenfassung, wenn du eine Sitzung beendest.",
  "26. Ertrag je Vorkommen: Stück pro Ernte im Tooltip.",
  "27. Zusatzbeute je Vorkommen mit Häufigkeit im Tooltip.",
  "Komfort",
  "28. Warnung, wenn die Taschen fast voll sind.",
  "29. Sammel-Timer mit Erinnerung (/fg timer 30).",
  "30. Ruhe in Städten und Gasthäusern.",
  "31. Ruhe im Kampf.",
  "32. Tipp des Tages nach dem Einloggen.",
  "33. Rückgängig für den zuletzt gelöschten Fundort.",
  "34. Notizen an Fundorten (Alt+Klick).",
  "35. Fundort für eine Stunde ausblenden (Alt+Rechtsklick).",
  "36. Funde bestimmter Spieler ignorieren (/fg sperren Name).",
  "37. Wegpunkt zum nächsten seltenen Vorkommen (/fg selten).",
  "38. Wegpunkt zum nächsten Vorkommen für ein Sammelziel (/fg zielort).",
  "39. Sammelkette: nach dem Sammeln gleich zum nächsten Vorkommen.",
  "40. Sicherung vor dem Aufräumen, mit Zurückholen.",
  "Routen, Lager, Teilen",
  "41. Routen überspringen gerade abgeerntete Punkte.",
  "42. Routen auf Wunsch nur durch abbaubare Vorkommen.",
  "43. Rangliste der Routen nach Stück pro Stunde.",
  "44. Routen pausieren im Kampf.",
  "45. Hinweis, wenn du weit von der Route weg bist.",
  "46. Wert aller Materialien im Lager.",
  "47. Veränderung des Lagers seit gestern.",
  "48. Sammelberufe aller Charaktere im Fortschritt.",
  "49. Wer wie viele Fundorte geteilt hat (/fg beitraege).",
  "50. Diese Seite mit allen Neuigkeiten.",
}

-- L"…" je Eintrag, damit die Liste der Spielsprache folgt
FG.NEUIGKEITEN_DE = DE
function FG:Neuigkeiten()
  local liste = {}
  for _, t in ipairs(DE) do liste[#liste + 1] = L(t) end
  return liste
end
