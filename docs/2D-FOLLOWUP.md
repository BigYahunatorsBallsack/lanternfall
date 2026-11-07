# 2D-Nachkorrekturen: Tempo und Beutebilder

Grundlage: GitHub-main `620546d6196c09fdb8149338de6aac273a900703`, einschliesslich der ruhigeren Laufanimationen, des Spawn-Fixes aus PR #85 und der neuen UI aus PR #87. Das Startgeld bleibt bei 15 Shards.

## Bewegung

[Brotatos Grundtempo ist 450 Einheiten/s](https://brotato.wiki.spellsandguns.com/Speed). Die bereits vorhandene Waffen-Umrechnung verwendet 0,1 Studs je Einheit; beispielsweise entsprechen 400 Pistol-Reichweite 40 Studs. Der Spieler lief bisher mit Roblox-typischen 16 Studs/s. Er verwendet nun denselben Weltmassstab: **45 Studs/s**. Speed-Boni und -Abzuege bleiben Prozentwerte dieser Basis.

Normale Gegnergeschwindigkeiten werden bereits relativ zum Spieler umgerechnet. Die bisherigen festen Sturm-, Boss-Dash- und Geschossgeschwindigkeiten werden proportional zum Wechsel von 16 auf 45 mitskaliert, damit Sturmgegner beim Angreifen schneller bleiben als beim normalen Laufen. Diese Angriffswerte sind weiterhin die bestehenden Roblox-Anpassungen; es wird kein vollstaendig originalgetreues Brotato-Kampftiming behauptet.

Schnelle Sturmgegner pruefen den gesamten Weg zwischen zwei Simulationspunkten gegen Spieler, Hindernisse und Arenaraender. Sie stoppen beim ersten Hindernis oder Spieler. Boss-Dashes pruefen auch seitliche Streiftreffer entlang des Wegs und treffen jeden Spieler weiterhin hoechstens einmal pro Dash. Derselbe Segment-Kreis-Test wird fuer gegnerische Geschosse verwendet.

Die Gedraenge-Aufloesung verwendet fuenf statt drei Durchlaeufe. Die unveraenderten Grenzen fuer ruhige Gegnertrauben, Ueberlappung und das 4-ms-Schrittbudget gelten weiter.

## Vorhandene Bilder wiederhergestellt

Im frueheren, noch nicht abgegebenen Auftrag lagen bereits originale PNGs fuer Fruit, Crate, Legendary Crate und Material. Diese vier Quelldateien wurden anhand ihres vorhandenen SHA-256-Manifests bytegleich wiederhergestellt. Keine neue Illustration. Sie liegen unter `assets/loot/brotato/`; Quellen, Bild-IDs und der beobachtete erfolgreiche native Preload stehen in `roblox-assets.json`.

Der Importer polstert die eng beschnittenen Originale fuer die bestehenden quadratischen Welt-Sprites. Normale Kisten, legendaere Kisten und Fruechte verwenden die neuen Zuordnungen. Der alte Elite-Truhenpfad teilt das normale Kistenbild. Material-Drops und Shop-/HUD-Waehrungsanzeigen verwenden dasselbe gruene Originalbild; groessere Materialmengen werden nicht mehr blau oder rot eingefaerbt.

Der bereits auf main gemergte Gegner-Spawn-Fix bleibt unveraendert erhalten. Die neue Regression prueft sowohl neue Modelle als auch wiederverwendete Modelle am ersten sichtbaren Spawnpunkt.

## Owner-Test

1. [Branch-ZIP laden](https://github.com/BigYahunatorsBallsack/lanternfall/archive/refs/heads/wp-25-2d-followup.zip), in einen neuen Ordner entpacken, den bisherigen Rojo-Prozess beenden und dort `rojo serve default.project.json` starten. Studio neu synchronisieren und einen neuen Play-Test beginnen.
2. Mit Night Watch ohne Speed-Items laufen. Das Grundtempo muss deutlich hoeher sein. Die ruhigeren Animationen aus main sollen erhalten bleiben. Mit einem positiven und einem negativen Speed-Item erneut pruefen; mehrere normale Gegner und Sturmgegner muessen im passenden Verhaeltnis mitlaufen.
3. Normale und legendaere Kisten sowie Fruechte fallen lassen oder per Debug erzeugen. Die Kisten muessen die gruenen beziehungsweise roten Originalbilder zeigen. Materialien am Boden und das Waehrungssymbol im Shop muessen gruene Originalbilder zeigen, auch nach groesseren zusammengelegten Drops.
4. Gegner toeten und weitere derselben Art spawnen. Sie duerfen nicht am Ursprung oder am alten Todesort aufblitzen. Seitlich vor einem Sturmgegner und einem Boss ausweichen: Treffer waehrend des durchquerten Wegs, sichere Beinahe-Treffer und Hindernisse pruefen.
5. Danach mit zwei Clients und in Handy-Hoch-/Querformat testen. Besonders Tempo, Aufsammeln, Wiederbeleben und Lesbarkeit der Materialbilder pruefen; neue rote Output-Fehler melden.

## Nachweise und Grenzen

Die neuen Regressionen wurden vor den jeweiligen Laufzeitkorrekturen rot und danach gruen beobachtet. Pulse- und Sicherheitsfixtures halten ihre eigentlichen Ziele unabhaengig vom neuen Tempo: Bewegungen bleiben fuer die volle Testdauer innerhalb der Arena, faire Gesamtstrecke und dreifacher Cheat-Speed werden weiterhin geprueft. Der Hookfang-Test beobachtet Geschosse waehrend seines Zeitfensters, weil schnellere Geschosse am Ende schon verschwunden sein koennen. Keine Pruefgrenze wurde herabgesetzt und kein Test uebersprungen.

Vollstaendiger Vergleich und verbleibende Fehlschlaege: `2d-followup-validation.json`. Der Gesamtlauf ist nicht fehlerfrei: main hat 26 Fehlschlaege in Smoke/RunStats, der Branch 28 in denselben beiden Specs. Die bereits fehlerhafte, zustandsabhaengige Smoke-Sequenz reagiert auf das geaenderte Kampftempo; ihre zwei zusaetzlichen Netto-Fehlschlaege sind offen. Alle anderen Specs bestehen.

StyLua, Selene und Rojo-Build wurden geprueft. Native Bild-Preloads und die Unterstuetzung abgetrennter Parts durch BulkMoveTo wurden am 06.11.2026 beobachtet. Beim Abschluss war kein Studio verbunden; ein kompletter nativer Solo-/Zwei-Client-/Handy-Run dieses Branches steht aus. Der vorhandene Studio-Arbeitsstand wurde nicht ueberschrieben und keine Experience veroeffentlicht.

## Integration vor dem freigegebenen Merge

Der Owner hat den Merge trotz der dokumentierten Grenzen freigegeben. Der inzwischen gemergte UI-PR #87 wurde vollstaendig aufgenommen. Die Waehrungsanzeige behaelt den gemeinsamen ShardIcon-Frame-Vertrag; Preise, HUD und Level-up-Neuwuerfe verwenden das Original-Materialbild. Beide STATUS-Nachtraege bleiben erhalten. Unabhaengige Integrationspruefung ohne konkrete Befunde. Erneuter Gesamtlauf gegen aktuellen main: main 982/26 in 81 Specs, Integration 995/28 in 86 Specs; alle 15 neuen Regressionen bestehen. Lint: 0 Fehler, 0 Parsefehler, 11 bestehende Warnungen. Rojo-Build und Formatpruefung erneut bestanden.
