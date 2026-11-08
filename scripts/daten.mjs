// Erzeugt Daten/Materialien.lua aus den Gegenstandsdaten der Webseite.
// Aufruf: node scripts/daten.mjs ../foreverui-web
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const web = process.argv[2] || "../foreverui-web";
const { fetchedAt, items } = JSON.parse(readFileSync(join(web, "src/data/items.json"), "utf8"));

const ARTEN = { "Kräuter": "kraut", "Metall & Stein": "erz", "Leder": "leder", "Elementar": "element" };
const lua = (s) => '"' + String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';

const zeilen = items
  .filter((i) => i.c === 7 && ARTEN[i.sc])
  .sort((a, b) => a.id - b.id)
  .map((i) => `  [${i.id}] = { ${lua(ARTEN[i.sc])}, ${lua(i.n)}, ${lua(i.en)}, ${i.ic || 134400}, ${i.q ?? 1} },`);

const kopf = `-- Forever Gather: Sammelmaterialien (automatisch erzeugt mit scripts/daten.mjs, nicht von Hand ändern).
-- Stand der Daten: ${String(fetchedAt || "").slice(0, 10)}
-- [Gegenstand] = { Art, deutscher Name, englischer Name, Symbol, Qualität }
local _, FG = ...
FG.MATERIALIEN = {
`;
writeFileSync("Daten/Materialien.lua", kopf + zeilen.join("\n") + "\n}\n");
console.log(`${zeilen.length} Materialien geschrieben.`);
