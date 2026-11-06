# Lanternfall: Übergabe des vollständigen Gegner-Sprite-Pakets

Der Owner hat Baby Alien, Charger und Spitter ausdrücklich freigegeben und die übrige Serie im gleichen Stil beauftragt. Dieses Paket liefert die komplette Basisspiel-Liste aus der Crash Zone: 21 normale Gegner, acht Elites und zwei Endbosse. Zwei zusätzliche Gobbler-Wachstumsformen und ein neutraler Baum ergeben insgesamt 34 PNGs. DLC-Gegner sind nicht enthalten.

## Dateien verwenden

- `sprites/regular/`: 21 normale Gegnertypen.
- `sprites/elites/`: acht Elites.
- `sprites/bosses/`: Predator und Invoker.
- `sprites/variants/`: GobblerMutation1 und GobblerMutation2; die kleinste Form liegt als Gobbler unter regular.
- `sprites/bonus/Tree.png`: neutraler Baum als Bonus.
- `Gallery.html`: Übersicht mit Größenregler, Hintergrundwechsel und Suche. Im Browser lokal öffnen.
- `manifest.json`: vollständige Zuordnung zur Wiki-Referenz, Dateipfade, Größen, sichtbare Bildgrenzen und SHA-256.
- `game-mapping.csv`: Zuordnung aller Dateien zu den bestehenden Lanternfall-IDs aus `docs/enemy-reference.json` auf main `e3157be`.
- `validation.json`: tatsächliche Alpha- und Randprüfung aller 34 Dateien.
- `prompts.json` und `approved-preview-prompts.json`: verwendete Imagegen-Prompts.

Alle PNGs sind unveränderte Imagegen-Ausgaben mit 1254 × 1254 Pixeln und echtem Alphakanal. Die ursprünglichen drei freigegebenen PNGs sind bytegleich übernommen. Es sind einzelne neutrale Ansichten, keine Animations-Sprite-Sheets.

## Einbindung

Die Dateinamen sind Zuordnungsnamen der Brotato-Referenzliste. `gameId` in manifest.json und game-mapping.csv verweist auf die bestehenden eigenen Lanternfall-IDs; diese beibehalten. Die Zuordnung wurde beim Einchecken mit dem neueren main `e3157be` abgeglichen. Alle 31 Gegnertypen plus Baum sind abgedeckt; die beiden zusätzlichen Gobbler-Formen teilen sich die bestehende ID Gobbler. Die Bilder selbst legen keine Werte, Spawnregeln oder Verhaltensmodule an.

Die PNGs nicht neu zeichnen oder durch 3D-Ansichten ersetzen. Für prozedurales Wippen, Neigen, Trefferblinken und Bewegung können die vorhandenen Renderer genutzt werden. Keine gefälschten Frame-Animationen voraussetzen.

`contentBounds` in manifest.json beschreibt sichtbare Pixel ab Alpha 16. `suggestedFootAnchor` ist ein berechneter Startwert im Bereich 0–1; bei schwebenden Gegnern wie Fly und Colossus ist die tatsächliche Höhe vom Renderer festzulegen. Größe und Bodenposition nach der sichtbaren Figur ausrichten, da die transparenten Innenränder je nach Silhouette variieren. Das Paket setzt keine Gameplay-Radien oder neuen Größenwerte fest.

Texturen vorladen, sichtbare Reihenfolge und Transparenz korrekt behandeln und die Sprite-Lesbarkeit bei realer Spielgröße prüfen. Horizontale Spiegelung nur dort einsetzen, wo Asymmetrie, Angriffsrichtung und Gameplay dazu passen. Bestehende Warnflächen und Trefferlogik separat erhalten.

Es wurde kein Bild nach Roblox hochgeladen, kein Asset-ID-Modul angelegt und kein Spielcode verändert. Die Einbindung erfolgt in Claudes laufender 2D-Umstellung. Den aktuellen GitHub-main prüfen; der alte lokale Projektordner bleibt unangetastet.

## Geprüft

- Alle 34 erwarteten Dateien vorhanden und eindeutig.
- Jede Datei hat einen transparenten Außenbereich und sichtbaren Inhalt.
- Kein sichtbarer Pixel ab Alpha 16 liegt auf einem äußeren Bildrand.
- Alle Ausgaben beim Erstellen visuell mit ihrer Referenz und dem freigegebenen Stil verglichen; Augen bei Spawner und Slasher gezielt korrigiert.
- Noch nicht in Roblox importiert oder im Spiel getestet.

Quelle der Roster-Zuordnung: https://brotato.wiki.spellsandguns.com/Enemies
