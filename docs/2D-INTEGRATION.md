# 2D und aktueller main

Der Integrationsbranch `wp-25-integrate-2d-main` verbindet GitHub-main `fbf5ec58212ef15d073dd9d214be5cd38aaf3429` mit allen sieben vorhandenen 2D-Commits bis `32ebacc2dacbfa19f2b593afcac5a031635e12c9`. Der vorherige main-ZIP enthielt den 2D-Zweig noch nicht.

## Enthalten

- Kamera mit 89,5 Grad und 115 Studs Abstand, flache Welt, animierte Charakter- und Gegnersprites, 2D-Beute, Bauten und Lobby aus Paket 25.
- Aktuelle 62 Waffen,125 Items, Stat-Bilder und freigegebene Shop-Komposition aus main. Die Konflikte uebernehmen keine alten Waffenangriffe oder HP-x 10-Werte.
- Alle 34 vorhandenen Gegner-PNGs anhand ihrer SHA-256 unveraendert verifiziert.32 eindeutige Spiel-IDs, darunter Baum, acht Champions und beide Endbosse, mit hochgeladenen Bildern verbunden.32 native Roblox-Preloads erfolgreich. Quellen, IDs und Hashes: [roblox-assets.json](../assets/enemies/base-game/roblox-assets.json).
- Zwei zusaetzliche Gobbler-Mutationsbilder bleiben im Repository erhalten. Das vorhandene Serverprotokoll uebermittelt keine Mutationsstufe; eine neue Mutationsmechanik ist hier nicht enthalten.
- Neun Charaktere, Night Watch als Standard und die bestehende Schema-9-Migration des 2D-Zweigs.

Weitere Weltgrafiken wie Boden, Beute und Lobby behalten den Stand des 2D-Zweigs und sind teilweise generische Platzhalter. Es wurden keine neuen Illustrationen erstellt.

## Testanleitung fuer den Owner

1. Studio-Test stoppen und den bisherigen Place-Arbeitsstand speichern. Den [Integrationsbranch als ZIP](https://github.com/BigYahunatorsBallsack/lanternfall/archive/refs/heads/wp-25-integrate-2d-main.zip) in einen neuen Ordner entpacken. Nach dem Merge kann stattdessen wieder der main-ZIP verwendet werden.
2. Den bisherigen Rojo-Prozess mit `Ctrl+C` beenden. Im neu entpackten Ordner `rojo serve default.project.json` starten, Studio neu verbinden und die Synchronisierung uebernehmen. Einen neuen Play-Test starten.
3. Die Kamera muss fast senkrecht von oben schauen. Night Watch ist der Standard, Charaktere laufen als Bilder mit bewegten Fuessen, Blade Warden ist nicht mehr waehlbar. Charakterwahl, Respawn und Rueckkehr in die Lobby testen.
4. Im Debug-Menue Gegner, Champions und beide Bosse ansehen. Besonders Iron Husk, Horned Rusher, Dread Tendril und Hookfang pruefen: eigene Bilder, keine unsichtbaren Gegner und keine Namens-Platzhalter. Auf Trefferblitz, Bewegungsrichtung und rote Angriffsmarkierungen achten.
5. Nach Welle 1 den Shop pruefen: vier hohe Angebote, Werte rechts, aktuelle Originalbilder und Namen. Kaufen, Sperren, Reroll und GO testen. Bauten/Garten/Begleiter muessen ihre aktuellen Itembilder vollstaendig zeigen. Danach mit zwei Clients Wiederbeleben sowie Handy-Hoch-/Querformat pruefen und neue rote Output-Fehler melden.

Alternativ liegt im Integrations-Worktree nach `rojo build default.project.json -o build/lanternfall-integrated-2d.rbxl` eine separat oeffenbare Testdatei.

## Pruefung und Grenzen

Alle Specs werden einzeln ueber den vorhandenen Lune-Adapter ausgefuehrt. Der unveraenderte main wird als Quell-Snapshot mit demselben Zufallsstart 1234 verglichen. Der vollstaendige Bericht steht in [2d-integration-validation.json](2d-integration-validation.json); bereits auf main vorhandene Fehler bleiben dort einzeln sichtbar und wurden nicht uebersprungen.

Zwei beim Review gefundene Fehler haben Regressionen: aktuelle 96-Pixel-Baubilder mit passendem Ausschnitt/Bodenanker sowie erfolgreicher Charakterwechsel nach erschoepftem Ladebudget eines anderen Bildes. Beide Tests schlagen ohne die jeweilige Korrektur fehl.

StyLua, Selene und Rojo-Build geprueft; Selene behaelt 11 vorhandene Stilwarnungen. Studio wurde nur zum getrennten Bild-Preload genutzt. Kein kompletter nativer Branch-Run, Zwei-Client-, physischer Handy- oder veroeffentlichter Run-Place-Test. Die offene Studio-Place-Datei und die lokalen alten Aenderungen wurden nicht ueberschrieben; keine Experience veroeffentlicht.
