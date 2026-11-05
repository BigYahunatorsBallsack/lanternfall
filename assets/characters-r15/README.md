# Lanternfall – zehn Charaktere mit R15-Rig

Dieses Paket enthält alle zehn aktuell spielbaren Charaktere aus GitHub-main
`f515df9082fa134f5cc5bdf179122aaee9f05563`. Blade Wardens freigegebene Optik ist die
Stilvorlage; die anderen Gesichter und Erkennungsmerkmale folgen den vorhandenen
Sprites. Lantern Keeper und Trapper sind laut aktuellem Katalog ausgemustert und
deshalb nicht enthalten. Die Blender-Dateien enthalten die editierbare Quelle. Der veraltete lokale Projektordner wurde nicht verändert.

## Dateien pro Charakter

- `<Name>_R15.fbx`: neutraler Import für Roblox, 15 benannte Körper-Meshes und
  Standard-R15-Bone-Hierarchie. Interne Segmente erhalten die kompakte Ei-Silhouette.
- `<Name>_R15.glb`: riggbarer Viewer-Export mit eingebetteten Texturen sowie Idle/Walk.
- `<Name>_R15.blend`: editierbare Quelle mit ursprünglichen Einzelmaterialien und
  4K-Texturen, Rig, zwei Animationen, Kameras und Vorschau-Beleuchtung.
- `<Name>_Game.blend`: optimierter Export mit einem gemeinsamen Materialatlas.
- `animations/Idle.fbx`, `animations/Walk.fbx`: je genau ein Animationsclip,
  24 Bilder/s, 48 Bilder pro Schleife. Es sind einfache Ausgangsanimationen für die
  kurzen Gliedmaßen; die vorhandenen Standardanimationen des Spiels sind nicht ersetzt.
- `textures/GameAtlas_*_2K.png`: Spieltexturen; die entsprechenden 4K-Dateien sowie
  ursprüngliche 4K-Gesichtstexturen liegen zur weiteren Bearbeitung daneben.
- `FourViews.png`: Front, Seite, Rücken und erhöhte Dreiviertelansicht.
- `renders/06_game_mesh.png`: Kontrollbild des endgültigen Materialatlas-Exports.
- `validation.json` und `animation-validation.json`: tatsächliche Dateiprüfungen.

Die Modelle sind Experience-Rigs. Waffen sind weiterhin separate Ausrüstung;
sie sind nicht fest in den Körper eingebaut. Eigene Details wie die Mütze,
das Fernrohr, die sechs Hände und das Kerzenbuch sind räumlich modelliert.

## Einbindung in Lanternfall

Alle zehn Modelle sind unter dem Experience-Besitzer hochgeladen und freigegeben.
`roblox-assets.json` dokumentiert die Modell- und Farbtextur-IDs;
`src/shared/Config/CharacterArt.luau` enthält die verwendete Laufzeit-Zuordnung.
Ein erneuter manueller Import ist zum Spielen nicht erforderlich.

`CharacterAppearanceService` hängt das serverseitig gewählte Modell bei Auswahl
und Respawn an den bestehenden R15-Spielcharakter. Kollisionen, Humanoid,
Waffen, Kamera und Klassenregeln verwenden weiterhin diesen Spielcharakter.
Jeder Client lädt Meshes und Farbtexturen vor und blendet den bisherigen Avatar
erst nach erfolgreichem Laden aus. Bei Ladefehlern bleibt er sichtbar; der
Ladevorgang wird begrenzt wiederholt. Die Spielmodelle verwenden den originalen
2K-Farbatlas direkt, damit nicht verfügbare importierte PBR-Komposittexturen
Gesicht und Körper nicht verdecken.

`CharacterAnimationController` bewegt die R15-Bones für Idle, Laufen und den
Down-Zustand anhand der tatsächlichen Bewegung. Die Pose wird nach dem nativen
Animator gesetzt. Dafür sind keine zusätzlich veröffentlichten Animations-IDs
erforderlich; die FBX-Clips bleiben als editierbare Künstlerdateien enthalten.

## Dein gemeinsamer Spieltest am Ende

1. Aktuellen `main` nach Studio synchronisieren und **Play** starten. In der
   Lobby die freigeschalteten Charaktere auswählen: passender Körper, Gesicht
   und eigene Details müssen erscheinen, ohne zweiten sichtbaren Roblox-Avatar.
2. Einen Run starten, laufen, drehen und stehen bleiben. Hände und Füße müssen
   sich bewegen; Körper und Gesicht bleiben geschlossen, die Füße am Boden.
   Waffen, Treffer, Kamera und Klassenwerte wie gewohnt prüfen.
3. Respawn sowie Down/Revive prüfen. Der ausgewählte Charakter muss wieder
   erscheinen. Besonders auf die sechs Hände, den einzelnen Arm, die Mütze,
   das Fernrohr und das Kerzenbuch achten.
4. Mit **Test → Clients and Servers** zwei Clients starten. Beide müssen auf
   beiden Bildschirmen mit ihrer jeweiligen Auswahl und Bewegung erscheinen.
   Danach Lesbarkeit und Bildrate auf dem Handy prüfen. Diese beiden Prüfungen
   stehen noch aus.

## Optional: Modelle künstlerisch bearbeiten und neu importieren

1. ZIP vollständig entpacken. In einer leeren Studio-Testdatei **File → Import**
   öffnen und zunächst `BladeWarden/BladeWarden_R15.fbx` auswählen.
2. Unter **Rig General**: **Rig Type = R15**, **Rig Scale = Default**.
   **Keep Zero Influence Bones** einschalten, **Merge Meshes** ausschalten.
   **Validate UGC Body** ausschalten, da diese Modelle für Lanternfall gedacht sind.
   Für den ersten lokalen Test kann **Upload to Roblox** ausgeschaltet bleiben.
   Die Vorschau sollte etwa 4,3 Studs hoch sein, Night Watch mit Mütze etwas höher.
   Falls Studio anders skaliert: **Scale Unit = Studs** prüfen und Vorschaugröße korrigieren.
3. Importieren. Das eingefügte Charakter-Model im Explorer auswählen, den gesamten
   Inhalt von `FinalizeImport.luau` in die Studio-Command-Bar kopieren und ausführen.
   Es prüft die 15 Teile, blendet interne Hilfsteile aus und setzt die passende
   Fuß-/Kollisionshöhe. Dieses optionale Hilfsskript ist kein Laufzeitdienst.
4. Den **Animation Editor** öffnen und das Model wählen. Über **Import → From FBX**
   zuerst `animations/Idle.fbx`, danach separat `animations/Walk.fbx` laden.
   Abspielen: Körper bleibt geschlossen, Hände und Füße bewegen sich getrennt,
   Gesicht und charaktereigene Details bleiben auf ihrer Oberfläche beziehungsweise
   an ihrem vorgesehenen Rigteil. Die Bewegungen anschließend unter deinem
   Experience-/Gruppenbesitzer veröffentlichen, wenn sie im Spiel verwendet werden sollen.
5. Dasselbe für die übrigen neun Modelle durchführen. Besonders prüfen:
   sechs bewegte Hände bei Many Hands, nur ein sichtbarer Arm bei Sole Conductor,
   Mütze/Fernrohr/Kerzenbuch in Seiten- und Rückansicht und die breitere Form von Marble Host.
6. Bei einem neuen Upload Modell- und Farbtextur-IDs in `CharacterArt.luau`
   aktualisieren und die Spieltests oben wiederholen.

## Bereits geprüft

Für jeden Charakter: Quelle und Game-Blender-Datei geöffnet, FBX und GLB erneut
importiert, 15 Meshes und die 17 Bones der Standardhierarchie kontrolliert,
geschlossene Geometrie/positive Volumen/normalisierte Gewichte geprüft und reale
Bewegung der sichtbaren Teile gemessen. Jeder GLB-Mesh hat genau ein Material;
die Texturen sind eingebettet. Zusätzlich wurden alle 20 einzelnen FBX-Clips
erneut importiert und auf genau einen animierten R15-Rig geprüft.

In der verbundenen Test-Experience wurden alle zehn Modelle über die echte
validierte Klassenwahl geladen; alle Farbtexturen erreichten `Success`.
Blade Warden wurde im Spiel visuell sowie auf Bodenhöhe, Idle, Laufen und
Respawn geprüft. Die neun Integrationstests bestehen. Der volle Testlauf hat
dieselben 31 Fehlschläge wie der unveränderte `main`, ohne zusätzliche
Fehlschläge. Details und Grenzen stehen in `integration-validation.json`.
Zwei-Client- und Handy-Tests führt der Owner am Ende durch. Die Test-Place wurde
durch dieses Paket nicht veröffentlicht.

Die Importbezeichnungen und Rigstruktur folgen der offiziellen Dokumentation:
[Importer](https://create.roblox.com/docs/studio/importer),
[R15-Struktur](https://create.roblox.com/docs/avatar/character-bodies/specifications),
[FBX-Export](https://create.roblox.com/docs/art/modeling/export-requirements).
