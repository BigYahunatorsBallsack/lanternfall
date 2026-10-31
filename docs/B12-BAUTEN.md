# B12 – Bauten und Begleiter

Stand: 31.10.2026. Branch `wp-b12-structures`, auf `main` einschließlich B11, Wiederbeleben und Speichern (`15dd3e1`). Nur Vorbilder aus Brotatos Basisspiel; eigene Namen und einfache Art-déco-Laternenmodelle. B12 (Bauten) ist unabhängig von Paket 12 (Speichern).

## Inhalt und Quellen

| Im Spiel | Basisspiel-Vorbild | Umsetzung |
| --- | --- | --- |
| Brass Sentry | [Turret](https://brotato.wiki.spellsandguns.com/Turret) | 10 + 80 % Engineering, alle 0,73 s, 30 Studs |
| Cinder Sentry | [Incendiary Turret](https://brotato.wiki.spellsandguns.com/Incendiary_Turret) | 1 Kontaktschaden, 8 Brennticks mit 5 + 33 % Engineering, Feuer alle 0,28 s |
| Prism Sentry | [Laser Turret](https://brotato.wiki.spellsandguns.com/Laser_Turret) | 20 + 125 % Engineering, alle 0,87 s, durchdringt 3 Gegner |
| Mercy Sentry | [Medical Turret](https://brotato.wiki.spellsandguns.com/Medical_Turret) | heilt Besitzer alle 2,2 s um floor(3 + 5 % Engineering) × 10 HP |
| Siege Sentry | [Explosive Turret](https://brotato.wiki.spellsandguns.com/Explosive_Turret) | 25 + 150 % Engineering, Flächenschaden alle 0,87 s |
| Rune Mine | [Landmines](https://brotato.wiki.spellsandguns.com/Landmines) | bei Wellenbeginn und alle 12 s; 10 + 100 % Engineering; explodiert, wenn Gegner sie verlassen |
| Moon Garden | [Garden](https://brotato.wiki.spellsandguns.com/Garden) | eine echte Frucht sofort und alle 15 s |
| Orbit Wisp | [Wandering Bot](https://brotato.wiki.spellsandguns.com/Wandering_Bot) | umkreist Besitzer und verlangsamt Gegner in seiner Nähe, auch Elites |
| Storm Familiar | [Tyler](https://brotato.wiki.spellsandguns.com/Tyler) | stationärer Begleiter mit 10 radialen Strahlen, 12 + 90 % Engineering + 90 % Elemental, alle 2,2 s |
| Calibrated Tools | [Improved Tools](https://brotato.wiki.spellsandguns.com/Improved_Tools) | +10 % Attack Speed; Bauten nutzen 50 % Attack Speed, maximal 1 Kopie |
| Foundry Key | [Wrench](https://brotato.wiki.spellsandguns.com/Wrench) | Nahkampf-Schwung, baut Brass/Cinder/Prism/Siege entsprechend Waffenstufe I–IV |
| Rune Awl | [Screwdriver](https://brotato.wiki.spellsandguns.com/Screwdriver) | Nahkampf-Stich; Minen alle 12/9/6/3 s entsprechend Stufe |

Engineering ist jetzt ein primärer Wert mit Level-up-Karten (+2/+3/+4/+6). Die neue Waffenklasse Artisan entspricht [Tool](https://brotato.wiki.spellsandguns.com/Tool): +1 bis +5 Engineering bei 2 bis 6 Waffen. Beide Werkzeugwaffen haben die Basisspiel-Stufenwerte und -preise. Keine neuen DLC-Waffen oder DLC-Items.

## Regeln und Schnittstellen

- `Config.Structures` enthält Baukatalog, Zahlen und Budgets; `Config.Items` übernimmt dessen neun Bau-Items in Shop und Truhen. Items stapeln regulär.
- `StructureService` setzt alle gekauften Quellen bei jedem Wellenbeginn neu. Shop und Run-Ende entfernen Bauten. Niedergeschlagene/ausgeschiedene Besitzer pausieren ihre Bauten; Verlassen des Servers entfernt sie. Bestehende Brände folgen dem gemeinsamen Waffen-Brennsystem.
- Nach [Structures](https://brotato.wiki.spellsandguns.com/Structures) wirken normale Damage-, Range-, Crit-, Life-Steal- und Attack-Speed-Werte nicht auf Bauten. Ausnahmen: Engineering, Elemental beim Storm Familiar und Attack Speed mit Calibrated Tools. Durchbohren, Abprallen, Explosionsgröße/-schaden, Brenntempo/-ausbreitung und Treffer-/Kill-Itemeffekte wirken über die vorhandenen Systeme.
- Ein gemeinsamer Brand pro Gegner: Waffen-, Item- und Turmbrände konkurrieren im bestehenden `Afflictions`-Register. Der stärkere Brand gewinnt; Wiederanzünden setzt den laufenden Tick nicht zurück.
- `WeaponService.structureHit(player, enemyId, amount, source?)` meldet bereits skalierten Schaden, Schadenszahlen und Itemeffekte. `structureBurn(player, enemyId, damage, ticks, sheet)` zündet ohne primären Damage-Multiplikator an. Das Arsenal-Framework bleibt unverändert.
- Waffen können `structureKinds` und `structureIntervals` pro Stufe angeben. Items können `structure` angeben. Neue Server→Client-Remotes `Structures` (vollständiger Stand, auch RequestSync) und `StructureBeams` (Kosmetik), Typen in `Net/Types`. Kein Client kann einen Bau oder Treffer anfordern.
- Admin-Knopf `GiveStructureKit`: je ein Bau-Item und Calibrated Tools, wirksam ab nächster Welle. Bestehende Rechteprüfung und Rate-Limits gelten.

## Bewusste Anpassungen und Grenzen

- 100 aktive Bauten **insgesamt pro Server**, gleichmäßig auf Teilnehmer verteilt (solo 100, zu zweit 50 je Spieler). Überschuss ersetzt zufällig einen eigenen Bau. Auch Minen-Timer sind begrenzt und fair verteilt. Brotato nennt 100 je Spieler; das globale Budget ist unsere Koop-Anpassung. Item-Besitz bleibt unbegrenzt.
- Turmgeschosse sind serverseitige Soforttreffer mit sichtbaren kurzen Strahlen. Keine physischen Geschosse; Reichweiten in Studs, Platzierung um den Besitzer, Minen-/Explosionsradius und Bot-Umlauf sind 3D-Annahmen in der Config.
- Beim Abprallen wird der nächste noch nicht getroffene Gegner im 25-Studs-Radius gewählt. Durchbohren folgt anschließendem Strahlkontakt; die Reihenfolge ist eine vereinfachte Anpassung gegenüber Brotatos Geschossflug.
- Laser-/Explosivturm und Tyler: aktuelle Wiki-Infoboxwerte verwendet, da ältere Fließtexte abweichende Skalierungen nennen.
- Darstellung: gepoolte farbige Laternen und Sockel, maximal 32 Angriffsstrahlen je 0,2-s-Netzpaket. Mehr Treffer werden trotzdem berechnet. Kein Echtgeld-/Profil-Schemawechsel.
- Der bestehende Ergebnisbericht zählt Schaden pro getragener Waffe; Bau-/Itemschaden erhält dort noch keine eigene Zeile. Kill-/Beute-Zurechnung an den Besitzer funktioniert. Erweiterung der Ergebnisstatistik bleibt bei Strang A / HUD-Paket.
- Neue B12-Items sind die oben genannten zehn. Andere noch fehlende Engineering-Items oder Charaktere sind keine stillschweigende Ergänzung dieses Pakets.

## Testanleitung für den Owner

1. Nach Merge [main als ZIP herunterladen](https://github.com/BigYahunatorsBallsack/lanternfall/archive/refs/heads/main.zip), entpacken, im neuen Ordner `rojo serve` starten und Studio verbinden/synchronisieren. Vor Merge kann derselbe Ablauf mit [B12-ZIP](https://github.com/BigYahunatorsBallsack/lanternfall/archive/refs/heads/wp-b12-structures.zip) erfolgen.
2. In Studio **Spielen** starten, Figur auswählen und **READY** klicken. Im DEBUG-Menü **GiveStructureKit** anklicken, danach **End this wave**. Im Shop **READY**: fünf verschiedenfarbige Türme, Mine, Garten, umkreisendes Licht und stationärer Begleiter erscheinen. Der Garten erzeugt eine aufhebbare Frucht.
3. Gegner zu den Bauten locken. Türme treffen automatisch; der umkreisende Begleiter verlangsamt. Zum Brenntest **Spawn next champion** benutzen, weil frühe Gegner zu schnell sterben. **Hurt me** klicken und zum grünen Mercy Sentry gehen: HP steigt. Mine betreten/verlassen lassen: sie verschwindet und schädigt nahe Gegner.
4. **Only the next weapon** wiederholt anklicken, bis **Foundry Key** beziehungsweise **Rune Awl** erscheint. **Weapons +1 tier** erhöht die Stufe. Nach **End this wave** und Shop-**READY** baut Foundry Key den passenden Turm; Rune Awl legt auf Stufe IV etwa alle drei Sekunden eine Mine (mit Calibrated Tools entsprechend schneller).
5. **Team +1 level** mehrfach nutzen und Engineering-Karten wählen, sobald angeboten. Bau-Schaden beziehungsweise Heilung steigt. Reguläre Damage-/Range-Karten ändern Bauten nicht. Im Shop verschwinden alle Bauten; nächste Welle setzt sie neu. Nach Run-Ende darf nichts übrig bleiben.
6. Mit zwei Clients starten. Je Client das Bau-Kit geben und nächste Welle starten. Jeder sieht beide Sets; Mercy heilt nur seinen Besitzer. **Knock me down**: dessen Bauten pausieren; nach Wiederbeleben laufen sie weiter. Einen Client trennen: dessen Bauten verschwinden.
7. Unter **Fenster → Ausgabe** auf rote Fehler achten. Auf Handy zusätzlich Sichtbarkeit und flüssigen Bot-Umlauf prüfen.

## Prüfstand

452 Tests in 39 Dateien bestanden. StyLua sauber; Selene: 0 Fehler, 8 bereits vorhandene UI-Stilwarnungen. Rojo-Build erfolgreich; Git-Diff ohne Whitespace-Fehler.

Automatisierte Tests: gesamtes Repository plus `StructuresB12.spec.luau` (Formeln, echte Server-/Client-Bootstraps, alle Quellen, Werkzeuge, Früchte/Heilung/Schaden, Brenn-Refresh, Minenauslöser, Wellen-/Run-Reset, 100er-Limit, zwei Spieler, Down/Revive und Disconnect). Lokaler Lune-Adapter für den bestehenden Test-Prelude; keine lange Balance-Simulation.

Studio-Verbindung am 31.10.2026 geprüft: dort fehlt noch `StructureService`. Deshalb kein behaupteter B12-Studio-, Geräte- oder echter Netzwerk-Playtest. Die obige Sicht-/Spielprüfung steht noch aus.
