# Forever Gather

Kräuter, Erze und Schätze auf Welt- und Minikarte für WoW Forever. Teil der ForeverUI-Reihe, mehr auf [foreverui.de](https://foreverui.de/).

## Was es kann

- **Fundorte merken:** Jedes Mal, wenn du ein Kraut pflückst, eine Ader abbaust oder eine Truhe öffnest, merkt sich das Addon den Ort. Kontoweit für alle Charaktere, nahe Funde derselben Sorte werden zusammengelegt.
- **Welt- und Minikarte:** Symbole mit dem Bild des Materials. Klick setzt einen Wegpunkt, Rechtsklick löscht einen Fundort, Umschalt+Rechtsklick blendet die Sorte aus. Vorkommen über deiner Fertigkeit erscheinen blass.
- **Filter:** Kräuter, Erze und Schätze getrennt ein- und ausschalten, jede Sorte einzeln, nur eigene Berufe, nur abbaubare.
- **Fertigkeit im Tooltip:** Am Vorkommen in der Welt siehst du die nötige Stufe und ob du es schon abbauen kannst.
- **Lager aller Charaktere:** Kräuter, Erze, Leder und Elementares aus Taschen und Bank aller Charaktere, im Fenster und im Gegenstands-Tooltip.
- **Farmrouten:** Route aus allen Fundorten einer Gegend (kürzester Rundweg) oder eigene Runde aufnehmen. Beim Abfahren springt der Wegpunkt automatisch zum nächsten Punkt.
- **Teilen:** Neue Funde gehen live an Gruppe oder Gilde. Routen und Fundorte als Code zum Kopieren (Discord, foreverui.de) oder direkt an Gruppe, Gilde oder einen Spieler.
- **Sitzung:** Was du gesammelt hast, Stück pro Stunde und Wert (Händlerpreis oder Auktionspreis, wenn ein Preisaddon installiert ist).
- **Barrierefreiheit:** Vorlesen, nahe Fundorte mit Entfernung und Richtung ansagen, hoher Kontrast, Farbenblind-Modus, alles größer, weniger Bewegung, Tastenkürzel für alle Funktionen.

## Befehle

`/fg` öffnet das Fenster, `/fg hilfe` zeigt alle Befehle. Die wichtigsten:

| Befehl | Wirkung |
| --- | --- |
| `/fg naechster` | Wegpunkt zum nächsten Fundort |
| `/fg route neu` | Route aus den Fundorten dieser Gegend |
| `/fg route` | Route starten oder anhalten |
| `/fg aufnahme` | eigene Runde aufnehmen |
| `/fg teilen [route] [gilde \| Name]` | Fundorte oder Route senden |
| `/fg lager [Suche]` | Materialien aller Charaktere |
| `/fg vorlesen` | nahe Fundorte vorlesen |
| `/fg diagnose` | technische Infos für Fehlerberichte |

## Entwicklung

- Test ohne Spiel: `lua5.1 tests/simulation.lua`
- Materialliste neu erzeugen: `node scripts/daten.mjs ../foreverui-web`
- Veröffentlichen: Tag `vX.Y.Z` pushen, der Release-Workflow baut das Paket.

Lizenz: MIT
