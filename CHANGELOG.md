# Änderungen

## 0.3.0

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
