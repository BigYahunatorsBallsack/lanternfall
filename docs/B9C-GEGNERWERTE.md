# B9c – Hauptspiel-Gegner und originale HP-Einheiten

Ausgangspunkt: GitHub `main` `d4df36046647bb2390cdb21740b8dc53d1bbdce5`, geprueft am 06.11.2026. Der veraltete lokale Projektordner blieb unangetastet; dieser Branch liegt in einem eigenen Checkout. Der Owner hat fuer dieses Paket die Gegnerdateien und die gemeinsame Brotato-Skala ausdruecklich beauftragt. Das ersetzt die alte Strang-Zuteilung fuer diese Arbeiten und die Regel HP ×10.

## Quellen und Umfang

- [Enemies](https://brotato.wiki.spellsandguns.com/Enemies): nur Crash Zone, kein Abyss-DLC. Alle 22 regulaeren Eintraege einschliesslich Baum, Looter, Gobbler und Lamprey; acht Elites; beide Bosse. Die zugehoerigen Zahlen stehen zusaetzlich in `enemy-reference.json`.
- [Max HP](https://brotato.wiki.spellsandguns.com/Max_HP), [Stats](https://brotato.wiki.spellsandguns.com/Stats), [Consumables](https://brotato.wiki.spellsandguns.com/Consumables): 10 Basis-HP, +1 pro Level, Heilung in Originaleinheiten, legendaere Kiste heilt 100 HP statt immer voll.
- [Weapons](https://brotato.wiki.spellsandguns.com/Weapons): originale Grundschaeden der neun nachtraeglich umbalancierten Referenzwaffen wiederhergestellt; Rattle Repeater skaliert wieder mit 50/60/70/80 % Ranged Damage. Die anderen Referenzwaffen waren bereits in diesen Einheiten. Die sechs eigenen urspruenglichen Waffen bleiben eigene Angriffe in derselben Schadenseinheit; ihre Formen werden nicht als Wiki-Kopien behauptet.
- [Bait](https://brotato.wiki.spellsandguns.com/Bait): neues eigenes Item Blood Lure, Uncommon, Grundpreis 25, +8 % Damage; jede neue Kopie bringt einmal 7–8 Hookfangs in der naechsten Welle.
- [Danger Levels](https://brotato.wiki.spellsandguns.com/Danger_Levels): die bestehenden Gefahrenmultiplikatoren und 75-%-HP-Regeln bleiben erhalten.

Alle Seiten am 06.11.2026 geprueft. Die Gegnerliste dokumentiert nicht jede Angriffsgroesse, jedes Tempo im Ansturm oder jede Spawn-Anzahl. Solche bestehenden Roblox-Anpassungen bleiben als Anpassungen erkennbar; fuer Gobbler-Mutationen werden keine unbelegten Zahlen erfunden. Das Paket ersetzt keine Sprite-Dateien und keine Grafikmodule. Vollstaendige Angriffsmuster der acht Champions bleiben die bereits vorhandenen eigenen Varianten.

## Zuordnung fuer die Sprite-Integration

Bestehende interne IDs und Snapshot-Bytes bleiben stabil. Vier neue IDs sind hinzugekommen. Die neuen Gegner verwenden vorlaeufig vorhandene einfache Ersatzmodelle, bis das getrennte Sprite-Paket integriert wird.

| Interne ID | Wiki-Vorbild | HP | +HP/Welle | Tempo (Wiki) | Kontakt | +Kontakt/Welle | Erste normale Welle |
| --- | --- | ---: | ---: | --- | ---: | ---: | --- |
| Shadeling | Baby Alien | 3 | 2 | 200–300 | 1 | 0.6 | 1 |
| AbyssShadeling | Chaser | 1 | 1 | 380 | 1 | 0.6 | 2 |
| Spitter | Spitter | 8 | 1 | 200 | 1 | 0.6 | 4 |
| Charger | Charger | 4 | 2.5 | 400 | 1 | 0.85 | 3 |
| Stalker | Pursuer | 10 | 24 | 150 bis 600 | 1 | 1.2 | 11 |
| Brute | Bruiser | 20 | 11 | 300 | 2 | 0.85 | 8 |
| Herald | Buffer | 20 | 3 | 150 | 1 | 0.6 | 16 |
| Thornback | Fly | 15 | 4 | 325–375 | 1 | 0.85 | D1+: 4 |
| Mender | Healer | 10 | 8 | 400 | 1 | 0.85 | D1+: 7 |
| Looter | Looter | 5 | 30 | 300–400 | 1 | 0.85 | ab 3, Sonderwurf |
| **IronHusk (29)** | Helmet Alien | 8 | 4 | 225–275 | 1 | 1 | D0: 13; D1+: 10; D4+: 4 |
| Splitling | Fin Alien | 12 | 2 | 400 | 1 | 1 | D0: 15; D1+: 9 |
| Splitter | Spawner | 10 | 1 | 120 | 1 | 0.85 | 14 |
| Skulker | Junkie | 5 | 5 | 350 | 1 | 1 | 14, auch aus Splittern |
| AbyssBrute | Horned Bruiser | 30 | 22 | 300 | 1 | 1.15 | D0: 13; D1+: 8 |
| **HornedRusher (30)** | Horned Charger | 12 | 5 | 425 | 1 | 1.1 | D0–3: 18; D4+: 5 |
| BroodEgg | Slasher Egg | 5 | 3 | 0 | 1 | 0.6 | D1+: 7 |
| Reaper | Slasher | 50 | 25 | 250–300 | 1 | 1.15 | D1+: 4 |
| **DreadTendril (31)** | Tentacle | 100 | 20 | 175 | 1 | 1 | D3+: 13 |
| **Hookfang (32)** | Lamprey | 30 | 15 | 350 | 1 | 0.75 | nur Blood Lure / Debug |
| Gobbler | Gobbler | 5 | 30 | 300–400 | 1 | 0.85 | ab 1, einmaliger 3-%-Wurf nach 10 s |
| Tree | Tree | 10 | 5 | 0 | 0 | 0 | jede Welle, Baum-Spawner |

Alle Bewegungswerte sind relativ zur Basisgeschwindigkeit des Spielers umgerechnet: 450 Wiki-Einheiten = 16 Studs/s. Ein Intervall wie 200–300 wird einmal beim Spawn ausgewuerfelt. Geschwindigkeit steigt nicht mit Welle oder Gefahrenstufe; Pursuers eigene Beschleunigung ist davon unabhaengig.

Geschoss-/Hiebschaden startet jeweils bei 1; Zuwachs pro Welle: Spitter/Hookfang 0.75, Thornback/Skulker/Reaper/DreadTendril 1. Der Server behandelt diese getrennt vom Kontaktschaden. Beispiel Welle 11: Spitter 18 HP, 7 Kontakt-, 8.5 Projektilschaden vor Gefahrenmodifikatoren. Ein Splitter erzeugt drei Skulker mit deren eigenen Wellenwerten; ein unzerstoertes Ei wird nach 5 s zu einem Reaper. Thornback kontert nur ueberlebte Fernkampf-Waffentreffer mit 50 % Chance. Mender heilt 100 + 10 × (Welle − 1) HP. Herald gibt +150 % Max HP, +25 % Schaden und +50 % Tempo.

| Champion-ID | Wiki-Vorbild | HP | +HP/Welle | Tempo (Wiki) |
| --- | --- | ---: | ---: | ---: |
| BrassRam | Rhino | 1 | 750 | 250 |
| Flayer | Butcher | 1 | 750 | 200 |
| Abbot | Monk | 1 | 700 | 350 |
| MireJaw | Croc | 1 | 750 | 350 |
| Monolith | Colossus | 1 | 750 | 300 |
| SickleWraith | Mantis | 1 | 750 | 250 |
| BroodMatron | Mother | 1 | 750 | 250 |
| StoneSeraph | Gargoyle | 1 | 750 | 350 |

Alle Champions: 1 Kontaktschaden +1.5 pro Welle nach Welle 1, 10 Materialien. Die beiden Bosse LanternEater/Predator und HollowSeer/Invoker haben je 29.250 HP, 30 Kontaktschaden und 23 Projektilschaden. Tempo 300 bzw. 200, Seer in der letzten Phase 500. Auf D5 ergeben 75 % × 140 % exakt 30.712,5 HP je Boss; die Wiki-Tabelle zeigt die abgerundete Zahl 30.712. Der Server behaelt die Rechengenauigkeit.

## Neue Schnittstellen

- `Config.Enemies`: optionale Felder `speedMax`, `firstWave`, `firstWaveByDanger`, `minDanger`, `specialSpawn`, `shotDamagePerWave`; `Pulse.healFlat/healPerWave`; seitliche Geschosse in `Charge`; `Retaliate.rangedOnly/chance`.
- `Util.EnemyStats`: gemeinsame reine Regeln fuer Wellenwachstum, Auftauchwellen, Basis-Geschossschaden und Zufallstempo. `Config.EnemyWaves` enthaelt die Spawn-Dichte; `SpawnRules` filtert diese fuer Welle und Gefahr. Gruppengroessen und Intervalle sind Roblox-Annahmen.
- `EnemySim.spawn(..., speedMultiplier?, wave?)`: der optionale letzte Wert wendet Wellenwachstum getrennt je Schadensart an; bisherige Aufrufer ohne ihn behalten ihre Bedeutung. Split-/Ei-Kinder uebernehmen externe Modifikatoren, berechnen aber ihre eigenen Wellenwerte.
- `SpawnRules.growth`: dritter Rueckgabewert fuer Geschosse/Hiebe. Die ersten beiden bleiben HP und Kontakt. `EnemySim.retaliate` wird vom vorhandenen `WeaponService.onHit` aufgerufen; `Arsenal` bleibt unveraendert.
- `Config.Items.Item.description`: optionaler Zusatztext, den `UpgradeText.itemLines` zeigt. Die Daten fuer den Erwerbseffekt stehen in `Config.Effects.lure`; SpawnDirector fuehrt das einmalige Blood-Lure-Ereignis und dessen Retry-Checkpoint.
- Keine neue Remote, kein geaendertes Netzwerkformat und kein neues gespeichertes Profilfeld. `Admin.newEnemies` enthaelt die vier neuen IDs; Debug-Trefferschaden ist an die kleineren HP-Zahlen angepasst.

## Testanleitung fuer den Owner

1. Den PR-Branch als ZIP laden oder den Branch in einem separaten Ordner auschecken. Darin Rojo starten und mit der Test-Place in Studio verbinden; alternativ die mit `rojo build` gebaute Testdatei oeffnen. Erst danach Play starten. Sprite- und 2D-PR werden getrennt integriert.
2. Blade Warden starten: 15 HP (10 Basis +5 Charakterbonus). Im Shop gibt Vitality +3 Max HP; normale HP-Karten zeigen +3/+6/+9/+12. Mit „Hurt self“ Schaden nehmen; Frucht/Kiste heilt 3 HP, legendaere Kiste 100 HP, jeweils zuzueglich vorhandener Heilboni.
3. Debug: Waffen und Spawns ausschalten, Wellentimer halten. „Spawn next new enemy“ durchgehen: auch Iron Husk, Horned Rusher, Dread Tendril und Hookfang erscheinen. Neue IDs haben bis zum Sprite-Paket Ersatzmodelle. Bei Brood Egg 5 s warten: genau ein Reaper; Ei vorher toeten: kein Reaper. Splitter toeten: drei Skulker.
4. Mit Standardreglern auf D0 erscheinen Charger ab Welle 3, Spitter ab 4, Brute ab 8, Stalker ab 11, Herald ab 16. Auf D1 kommen Thornback/Reaper ab 4, Mender/Eier ab 7 hinzu. Dread Tendril erst D3 ab 13; auf D4 Iron Husk ab 4 und Horned Rusher ab 5. Vorher erscheinen diese Typen nicht in normalen Gruppen.
5. Blood Lure im Shop nehmen: +8 % Damage; in der naechsten Welle kommen einmal 7–8 Hookfangs mit Seitengeschossen beim Ansturm. Ohne weitere neue Kopie kommen in der Folgewelle keine. Eine Niederlage und „Retry wave“ wiederholt die zugehoerige Begegnung.
6. Auf D2 eine Elite-Welle und auf D5 Welle 20 pruefen: Champions/Bosse greifen an, Phasen wechseln, HP-Leiste sinkt, Kiste erscheint beim Tod. Auf D5 kommen beide Bosse. Anschliessend mit zwei Clients pruefen, dass HP, Gegner, Projektiltreffer und Beute uebereinstimmen; Handy-Lesbarkeit zusammen mit dem Sprite-Paket pruefen.

Automatisierte Ergebnisse und verbleibende Studio-Grenzen stehen im letzten B9c-Eintrag von `STATUS.md`.
