# Änderungen

## 0.4.0

Englische Übersetzung: Das Addon folgt der Spielsprache, umschalten mit `/fg sprache en` oder `/fg sprache de`.

50 neue Funktionen:

**Hervorheben**

1. Nahe Vorkommen pulsieren auf der Minikarte.
2. Leuchtrahmen um das nächste Vorkommen auf der Minikarte.
3. Hinweis oben am Bildschirm mit Name, Entfernung und Richtung.
4. Der Bildschirmrand leuchtet, wenn Seltenes in der Nähe ist.
5. Farbe der Hervorhebung wählbar: Akzent, Farbe der Art oder Weiß.
6. HUD: durchsichtige Kreiskarte in der Bildschirmmitte (/fg hud).
7. Symbolgröße der Minikarte einstellbar.
8. Reichweitenkreis im Kartenfenster.
9. Auch im Kartenfenster pulsieren nahe Vorkommen.
10. Punkt am Symbol, wenn das Vorkommen Fertigkeitspunkte bringt.
11. Minikarte auf Wunsch nur bis zu einer Entfernung.
12. Richtungspfeil am Minikartenrand zum nächsten Vorkommen.

**Fortschritt**

13. Planer: was gerade Punkte bringt und was als Nächstes kommt (/fg planer).
14. Gegenden, in denen du gerade Punkte bekommst (/fg wohin).
15. Fertigkeitsaufstiege der Sitzung werden gezählt.
16. Hinweis auf den Lehrer bei 50, 125, 200 und 275.
17. Warnung an der Fertigkeitsgrenze.
18. Fertigkeitsziel mit Fortschritt (/fg fertigkeit 150 kraut).
19. Meldung, wenn eine neue Sorte freigeschaltet ist.

**Chronik**

20. Die letzten 20 Sitzungen werden gespeichert.
21. Rekorde: meiste Stück, meiste Stück pro Stunde, wertvollste Sitzung.
22. Diese Woche und letzte Woche im Vergleich.
23. Bester Tag und die meistgesammelten Materialien.
24. Bericht der Sitzung zum Kopieren.
25. Zusammenfassung, wenn du eine Sitzung beendest.
26. Ertrag je Vorkommen: Stück pro Ernte im Tooltip.
27. Zusatzbeute je Vorkommen mit Häufigkeit im Tooltip.

**Komfort**

28. Warnung, wenn die Taschen fast voll sind.
29. Sammel-Timer mit Erinnerung (/fg timer 30).
30. Ruhe in Städten und Gasthäusern.
31. Ruhe im Kampf.
32. Tipp des Tages nach dem Einloggen.
33. Rückgängig für den zuletzt gelöschten Fundort.
34. Notizen an Fundorten (Alt+Klick).
35. Fundort für eine Stunde ausblenden (Alt+Rechtsklick).
36. Funde bestimmter Spieler ignorieren (/fg sperren Name).
37. Wegpunkt zum nächsten seltenen Vorkommen (/fg selten).
38. Wegpunkt zum nächsten Vorkommen für ein Sammelziel (/fg zielort).
39. Sammelkette: nach dem Sammeln gleich zum nächsten Vorkommen.
40. Sicherung vor dem Aufräumen, mit Zurückholen.

**Routen, Lager, Teilen**

41. Routen überspringen gerade abgeerntete Punkte.
42. Routen auf Wunsch nur durch abbaubare Vorkommen.
43. Rangliste der Routen nach Stück pro Stunde.
44. Routen pausieren im Kampf.
45. Hinweis, wenn du weit von der Route weg bist.
46. Wert aller Materialien im Lager.
47. Veränderung des Lagers seit gestern.
48. Sammelberufe aller Charaktere im Fortschritt.
49. Wer wie viele Fundorte geteilt hat (/fg beitraege).
50. Diese Seite mit allen Neuigkeiten.

Außerdem (bisher unveröffentlicht als 0.3.0):
- Neues Aussehen im einheitlichen ForeverUI-Stil: Seitenleiste mit Gruppen (Sammeln, Funktionen, Darstellung, Zugang, Hilfe), Inhaltskasten, Suche „Einstellung suchen …“, Fenster in der Größe veränderbar.
- Akzentfarbe wählbar: Gold, Klasse, Eis, Glut, Wald, Silber, wirkt sofort.
- Neue Seiten „Bedienung“ (Befehle und Discord-Link zum Kopieren) und „Fehler melden“ (Fehlerprotokoll zum Kopieren, Diagnose).
- Jede Einstellungsseite hat „Seite zurücksetzen“.
- Das Fehlerprotokoll beginnt mit jeder neuen Version leer. Alte, längst behobene Einträge (z. B. der Tooltip-Fehler „secret keys“ aus 0.1) tauchen nicht mehr als aktuelle Fehler auf. `/fg fehler leeren` leert es von Hand.
- Neues Kartenfenster: eine kleine Karte der Gegend in einem eigenen, verschiebbaren Fenster. Sie zeigt deine Position mit Blickrichtung, alle Fundorte und Routen als Linien. Mit dem Mausrad zoomst du, ein Klick auf einen Fundort setzt einen Wegpunkt. Öffnen mit `/fg karte`, dem Knopf in der Übersicht oder einem Tastenkürzel. Liefert das Spiel kein Kartenbild, zeigt das Fenster Fundorte und Route ohne Bild.

## 0.2.1

- Richtige Einzahl in Texten: „1 Fundort“ statt „1 Fundorte“, „1 Charakter“ statt „1 Charakteren“, kein doppelter Punkt mehr hinter dem Datum.
- Neuer Name in der Addonliste: Forever Harvest. Ordner, Befehl /fg und Einstellungen bleiben gleich.
- Behebt die Meldung „Aktion blockiert, Blizzard vorbehalten“ (z. B. beim Schließen des Händlerfensters): Forever Harvest überschreibt die globale Tabelle der Bestätigungsfenster nicht mehr.

## 0.2.0

Fehler behoben:
- Tooltip-Fehler „secret keys“: Geschützte Texte des Spiels werden jetzt erkannt und übersprungen. Dasselbe gilt für Zielnamen, Beute und Addon-Nachrichten.
- Kennt das Spiel den Namen eines Vorkommens nicht, erkennt Forever Harvest es über das gesammelte Material.
- Das Code-Feld im Reiter „Teilen“ lässt sich jetzt überall anklicken.

20 neue Funktionen:
1. Abgeerntete Fundorte werden blass gezeigt, bis sie vermutlich nachgewachsen sind (Minuten einstellbar).
2. Radar: kleines Fenster mit den nächsten Fundorten, Pfeil, Entfernung und Richtung als Uhrzeit.
3. Sammelziele wie „40 Friedensblumen“ mit Fortschritt und Meldung, wenn das Ziel erreicht ist.
4. Vorkommen für offene Sammelziele werden auf den Karten hervorgehoben.
5. Fertigkeitspunkte wie im Spiel: orange, gelb, grün oder grau, immer mit Wort dazu.
6. Filter „Nur mit Fertigkeitspunkten“.
7. Rangliste der besten Gegenden für deinen Charakter, ein Klick öffnet die Karte.
8. Statistik je Gegend: Kräuter, Erze, Schätze und wie viele davon Punkte bringen.
9. Favoriten per Strg+Klick: größer, gold umrandet und immer sichtbar.
10. Aufräumen: doppelte Fundorte zusammenlegen, alte geteilte entfernen.
11. Geschätzte Rundenzeit für Routen, zu Fuß und reitend.
12. Routen zählen Runden, Bestzeit und Ertrag und sagen jede geschaffte Runde an.
13. Klang, wenn ein Fundort in Reichweite kommt.
14. Symbole auf der Minikarte im Kampf ausblenden.
15. Neuer Reiter „Statistik“: letzte Tage, Gesamtmenge und beste Sitzung.
16. Bericht der Sitzung in Gruppe, Gilde oder Sagen (/fg bericht).
17. Seltene Vorkommen (Schwarzer Lotus, Silber, Gold, Echtsilber, Dunkeleisen, Reiches Thorium) werden hervorgehoben, mit Alarm in der Nähe oder wenn die Gruppe eins findet.
18. Fundorte auf der Kontinentkarte.
19. Sammelberufe aller Charaktere: Der Tooltip zeigt, welcher Twink ein Vorkommen abbauen kann (/fg berufe).
20. „Vorkommen merken“: Ein Vorkommen, das du (noch) nicht abbauen kannst, trägst du per Taste an deiner Position ein.

Dazu der neue Reiter „Hilfen“ und Tastenkürzel für Radar und Merken.

## 0.1.0

- Erste Version: Fundorte von Kräutern, Erzen und Schätzen werden beim Sammeln gemerkt und auf Welt- und Minikarte gezeigt.
- Filter nach Art, Sorte, eigenem Beruf und Fertigkeit; Fertigkeit im Tooltip der Vorkommen.
- Lager mit den Sammelmaterialien aller Charaktere (Taschen und Bank), auch im Gegenstands-Tooltip.
- Farmrouten aus Fundorten oder per Aufnahme, mit automatischem Wegpunkt.
- Teilen per Code und direkt mit Gruppe, Gilde oder Spielern; neue Funde live an die Gruppe.
- Sitzungsanzeige mit Menge, Stück pro Stunde und Wert.
- Barrierefreiheit: Vorlesen, Ansage naher Fundorte, hoher Kontrast, Farbenblind-Modus, alles größer, Tastenkürzel.
