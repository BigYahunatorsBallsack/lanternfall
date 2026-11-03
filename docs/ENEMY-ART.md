# Gegner-Redesign – normale Gegner, Bosse und Champions

Stand: 02.11.2026. Der Owner hat den kompakten violetten Shadeling mit schwarzen Konturen als Stilrichtung bestätigt. Größere Gegner sollen innerhalb dieses Stils zusätzliche Formen und Details erhalten. Referenz: [Brotato-Gegnerübersicht des Owners](https://justgameguides.com/game/brotato/enemies).

![Die ersten vier Modelle in der Studio-Vorschau](images/enemy-art-first-four.jpg)

## Umfang

| Gegner | Ausarbeitung | Teile, inklusive Schatten/Vorwarnung | Mesh-Dreiecke |
| --- | --- | ---: | ---: |
| Shadeling | Kompakter Körper, schwarzes Auge, Konturen, Rückenflossen, getrennt bewegliche Arme | 5 | 2.984 |
| Brute | Breiterer und schwererer Körper derselben Spezies, vergrößerte Arme/Flossen, eingefasste Schulterplatten und Stacheln | 13 | 2.984 plus primitive Platten/Stacheln |
| Spitter | Breites Schussmaul, Giftdrüsen, Kiemen/Flossen, pendelnde Arme | 4 | 3.498 |
| Charger | Segmentierter Hornpanzer, tiefer Kopf, vier getrennte Beine und erhaltene Sturmvorwarnung | 9 | 4.322 |

Alle 27 Gegnertypen sind eingebunden: 17 normale Arten einschließlich der beiden Abyss-Varianten, zwei Bosse und acht Champions. Die normalen Arten haben weiterhin ihre Gloom-Elites. Der erntbare Baum bleibt unverändert.

## Zweite Serie: weitere 13 Typen

| Gegner | Ausarbeitung | Teile | Mesh-Dreiecke |
| --- | --- | ---: | ---: |
| Splitter | Breiter gegliederter Körper, helle Panzerstreifen, dunkle Kopfkappe | 4 | 3.990 |
| Splitling | Gedrungener kleiner Verwandter mit seitlichen Schalenfragmenten | 8 | 2.636 |
| Looter | Grüner flinker Träger mit ockerfarbenem Tragbeutel und Fühlern | 3 | 3.392 |
| Gobbler | Breiter Körper, getrennte Gliedmaßen, große dunkle Saugöffnung | 9 | 4.024 |
| Stalker | Schmale hohe Gestalt und zusätzliche nach hinten gerichtete Flossen | 9 | 2.984 |
| Skulker | Längerer engerer Schusskanal und seitliche Flossen | 8 | 3.498 |
| Thornback | Roter schwerer Panzer mit sechs eingefassten Rückenstacheln | 19 | 3.904 |
| Herald | Helle Halsplatten und amberfarbene Signalkugel zwischen Fühlern | 5 | 3.484 |
| Mender | Türkise Drüsen, dunkler Blattpanzer und schlichte Gesichtsplatte mit Sehschlitz | 8 | 3.500 |
| Brood Egg | Aufgebrochene helle Eischale mit violettem Kern und organischem Sockel | 4 | 2.500 |
| Reaper | Segmentierte Sichelarme, Rückenpanzer, kleinere Kopfklinge und getrennte Füße | 10 | 4.152 |
| Abyss Shadeling | Dunklere Färbung und zusätzliche Kopfstacheln | 9 | 2.984 |
| Abyss Brute | Größerer schwerer Körper mit zusätzlichen Kopfstacheln | 17 | 2.984 |

Teile enthalten Schatten und gegebenenfalls Warnfläche. Mesh-Dreiecke enthalten keine ergänzenden primitiven Platten/Stacheln. Am meisten Teile hat Thornback: 19 normal, 24 als Gloom-Elite, innerhalb der Limits von 20/25.

![Splitter, Splitling, Looter und Gobbler](images/enemy-art-carriers.jpg)
![Stalker, Skulker, Thornback und Abyss Brute](images/enemy-art-hunters.jpg)
![Herald, Mender, Reaper und Brood Egg](images/enemy-art-combat.jpg)
![Vergleich der normalen und Abyss-Varianten](images/enemy-art-brood.jpg)

## Dritte Serie: zwei Bosse und acht Champions

| Gegner | Ausarbeitung | Teile | Mesh-Dreiecke |
| --- | --- | ---: | ---: |
| Lantern Eater | Breiter violetter Körper, Hornschultern, große helle Ofenöffnung, getrennte Arme und kurze Beine | 8 | 5.978 |
| Hollow Seer | Türkise schwere Gestalt, heller Halo, dunkle Augenplatte, Brustdrüse und lange Arme | 4 | 5.458 |
| Brass Ram | Vier Beine, vergrößerte goldene Hörner, eingefasste Rückenplatten und Hornbeschläge | 18 | 4.322 |
| Flayer | Schwerer Verwandter des Brute mit breitem Hackbeil und gebogener Hakenklinge | 18 | 3.366 |
| Abbot | Gegliederter violetter Körper, helle Kopfkrone, dunkle Gesichtsöffnung und erhobene Signalkugel | 4 | 4.976 |
| Mire Jaw | Gedrungener Körper mit großem Zahnmaul, grünlichen Schultern, getrennten Armen und Füßen | 8 | 5.500 |
| Monolith | Gedrungener Felskörper mit Rissen, kleinen schwarzen Sehschlitzen, Kristallrücken und matter Steinoberfläche | 8 | 6.000 |
| Sickle Wraith | Schmalerer Reaper-Verwandter mit langen, breiten Sicheln und zusätzlichem Rückenkamm | 13 | 4.152 |
| Brood Matron | Breiter Panzerkörper, sechs Beine, drei aufgesetzte Bruteier mit dunklen Fassungen und seitlichen Dornen | 20 | 10.922 |
| Stone Seraph | Kompakter gehörnter Steingegner mit breiten segmentierten Fledermausflügeln | 4 | 5.478 |

Auch diese Zahlen enthalten Schatten, aber keine separat von `BossController` verwalteten Angriffswarnungen. Brood Matron hat wegen der drei Eischalen die höchste Dreieckszahl; alle zehn Modelle bleiben unter 25 Parts. Die Handy-Messung bleibt offen. Bei Hollow Seer und Abbot schwingt das gemeinsame Armmesh, bei Stone Seraph das gemeinsame Flügelmesh. Monolith, Lantern Eater und Mire Jaw haben getrennte Arm-/Beinsegmente.

![Lantern Eater und Hollow Seer vorne, Abbot und Mire Jaw hinten](images/enemy-art-bosses.jpg)
![Brass Ram und Flayer vorne, Sickle Wraith und Brood Matron hinten](images/enemy-art-champions.jpg)
![Monolith und Stone Seraph](images/enemy-art-stone.jpg)

## Einbindung

- `MeshCatalog.luau` enthält Mesh-/Textur-IDs, bearbeitete Proportionen, Positionen und Gelenkpunkte. Die Modelle werden ausdrücklich über ihre eigene Gegner-ID ausgewählt; andere Arten erben nicht versehentlich einen ungeprüften Look.
- `Models.luau` baut gepoolte, verankerte Parts mit `SpecialMesh`. Größen folgen weiterhin dem vorhandenen Kollisionsradius. Animationen nutzen die vorhandenen Gelenke und `BulkMoveTo`; es gibt keine neue Gegner-KI, Humanoids, Remotes oder Balancewerte.
- `EnemyRenderer.init` lädt die Artwork-Inhalte im Hintergrund während der Lobby vor. Die Auflösung über `EnemyKinds.get` umfasst auch Bosse und Champions. `PreloadAsync` bekommt Instanzen, damit Geometrie als Mesh und nicht als Bild angefragt wird.
- Treffer blitzen weiß; dafür wird die Textur kurz entfernt und danach wiederhergestellt. Brennen, Verlangsamen und Buffs färben auch die Texturen. Armored ändert die Panzerfarbe und das Material, Swift und Summoning bleiben erhalten. Pool-Reset stellt die Texturen wieder her.
- Die bisherigen Limits bleiben bestehen: maximal 20 Teile normal, 25 als Elite. Kleine Flossen/Horn-Einsätze können durch den vorhandenen Detailmodus ausgeblendet werden; wesentliche Körper und Gesichter bleiben erhalten.

Der Monolith behält sein mattes Steinmaterial auch nach Treffern und Pool-Reset. Die vorhandenen roten Bosslichter bleiben als schwächerer Akzent erhalten (Helligkeit 0,65, Reichweite 14), damit sie die Modellfarben nicht überstrahlen. Boss-Angriffe und Bodenwarnungen bleiben unverändert.

## Herkunft

Die Meshes wurden über den Roblox-Studio-Generator für dieses Projekt erstellt, anschließend proportional bearbeitet und an das vorhandene Rig angepasst. Es wurden keine Bilddateien oder Spiel-Assets von Brotato ins Repo kopiert. Die Roblox-Inhalte sind bereits hochgeladen; das Spiel selbst wurde nicht veröffentlicht.

| Ausgangsmodell | Roblox-Modell-ID | Weitere Bearbeitung |
| --- | --- | --- |
| Bestätigter Shadeling | `129131458877749` | Arme getrennt, Gelenke gesetzt; Basis für den manuell breiter ausgearbeiteten Brute |
| Spitter | `105000492232715` | Schussmaul gekürzt und verbreitert |
| Charger | `113557863847473` | Körper und vier Beine für den Gang getrennt |

Weitere ursprüngliche Roblox-Modell-IDs: Splitter `99658228849027`, Looter `131708596826531`, Herald `71366442585330`, Mender `129319117741511`, Reaper `121159822400279`, Gobbler `131547563447190`, Brood Egg `96453350435303`. Reaper und Gobbler wurden weiter segmentiert. Looter behält das vollständige Körpermesh mit eigener Wippbewegung, weil die Segmentierung die saubere Darstellung des Tragbeutels verschlechterte. Die Mender-Texturversuche wurden verworfen; das Originalmesh mit passender Originaltextur und einer manuell aufgebauten dunklen Gesichtsplatte wird verwendet. Ein Baum-Prototyp gehört nicht zu diesem Gegner-Auftrag und ist nicht eingebunden.

Ausgangsmodelle der dritten Serie: Lantern Eater `140428240994360`, Hollow Seer `89158399112594`, Abbot `104135697173464`, Mire Jaw `131487295599875`, Monolith `88961293389120`, Stone Seraph `86636902006156`. Monolith wurde anschließend in Körper, Arme und Füße segmentiert, verbreitert, gestaucht und mit mattem Material/Sehschlitzen ergänzt. Die humanoiden Vorentwürfe für Monolith und vier weitere Champions wurden verworfen. Brass Ram und Brood Matron verwenden überarbeitete Charger-Geometrie, Flayer kombiniert Brute und eine Reaper-Hakenklinge, Sickle Wraith erweitert den Reaper. Brood Matron trägt drei verkleinerte Brood-Egg-Schalen. Temporäre Modelle und verworfene Entwürfe wurden aus Studio entfernt.

Die endgültigen einzelnen Mesh- und Textur-IDs stehen vollständig im Katalog. Die Dreieckszahlen wurden in Studio mit `EditableMesh:GetFaces()` nach der Segmentierung gemessen. Die realistischeren frühen Entwürfe gehören nicht zur ausgelieferten Serie. Der separate neue Brute-Generierungsversuch wurde von Roblox mit `Moderation failed` abgelehnt; der Brute wurde deshalb aus dem bestätigten Shadeling weitergebaut.

## Geprüft und offen

- 69 Testdateien: **729 Tests erfolgreich**, darunter Budget, Gelenkzuordnung, Mesh-Proportionen, Textur-/Status-/Material-Reset und Armored nach Treffern. Der zusätzliche Preload-Test umfasst alle 27 Typen und die Bereinigung temporärer Modelle bei einem Ladefehler.
- StyLua, Selene (0 Fehler; 11 vorhandene Warnungen außerhalb dieses Umbaus) und Rojo-Build erfolgreich.
- Studio Edit: Formen einzeln, Vergleich mit den alten Modellen, Treffer-/Statusfarben und Modellreihe geprüft.
- Studio Play, Client, 02.11.: alle **124** unterschiedlichen Mesh-/Texturinhalte erfolgreich geladen. 140 animierte Modelle aus allen 27 Typen (zehn Bosse/Champions und 130 normale/Elite-Modelle) über den echten `Models.pose`-/`BulkMoveTo`-Pfad bewegt: **1.251 volle / 1.037 reduzierte Teile** pro Pose. 32 Warnflächen erscheinen und verschwinden korrekt; alle zehn Bosslichter vorhanden. Trefferblitz, Textur-/Material-Reset, Armored und anschließender Affixwechsel wurden geprüft. Der erste Prüfskriptlauf erwartete fälschlich, dass Pool-Reset den aktiven Affix entfernt; der korrigierte Test berücksichtigt den separaten Affixwechsel wie der Renderer und besteht.
- Aktuellen `main` bis `9833229` aufgenommen: neue Kamera-/Capture-Schnittstelle und Spielablauf bleiben erhalten. Gesamte Testsuite und Build danach erneut geprüft; die native Studio-Prüfung galt den Modellmodulen. Der strengere API-Mock enthält jetzt auch `CornerWedgePart` und `ContentProvider`.
- Der 140-Modell-Test ist ein **Funktionstest, kein FPS-Benchmark**. Ein vollständiger Run, 2 Clients, Handy-FPS/Texture-Memory und das Laden im veröffentlichten Run-Place wurden nicht geprüft. Die vorhandene Warnung zu Asset `203785492` stammt nicht aus diesem Artwork-Katalog; ebenso sind die gemeldeten fehlenden Badge-IDs bestehende Konfigurationsthemen. Studio ist wieder im Bearbeitungsmodus, die Produktionsmodule stimmen mit diesem Branch überein und die Vorschauobjekte sind entfernt.

## In Studio ansehen

1. Branch synchronisieren und Studio im Bearbeitungsmodus öffnen.
2. Im Werkzeug oben `page` auf 1–8 setzen (1: erste vier, 2: Splitter/Beute, 3: Jäger, 4: Unterstützer/Reaper, 5: Abyss-Vergleich, 6: Bosse/Abbot/Mire Jaw, 7: Waffen-/Brut-Champions, 8: Monolith/Stone Seraph). Für die isolierte Modellreihe den Inhalt von `tools/PreviewEnemyArt.luau` in der Studio-Befehlsleiste ausführen. Das Werkzeug klont die aktuellen Module neu, damit ältere `require`-Caches keine alten Modelle zeigen.
3. Dasselbe Werkzeug erneut ausführen: Die temporäre Bühne verschwindet und die ursprüngliche Kamera wird wiederhergestellt. **Die Bühne vor dem Veröffentlichen entfernen.**
4. Im normalen Spiel die ersten Wellen und eine Charger-Sturmvorwarnung ansehen; zusätzlich Elites mit Swift, Armored und Summoning prüfen. Bosse über Debug → **Spawn next boss**, Champions über **Spawn next champion** ansehen; auf Klingen, Eier, Flügel und die roten Angriffswarnungen achten.
