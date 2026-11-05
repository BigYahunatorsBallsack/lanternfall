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

## Dein gemeinsamer Studio-Test am Ende

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
   Fuß-/Kollisionshöhe. Dieses Hilfsskript ist formatiert, aber noch nicht in Studio gelaufen.
4. Den **Animation Editor** öffnen und das Model wählen. Über **Import → From FBX**
   zuerst `animations/Idle.fbx`, danach separat `animations/Walk.fbx` laden.
   Abspielen: Körper bleibt geschlossen, Hände und Füße bewegen sich getrennt,
   Gesicht und charaktereigene Details bleiben auf ihrer Oberfläche beziehungsweise
   an ihrem vorgesehenen Rigteil. Die Bewegungen anschließend unter deinem
   Experience-/Gruppenbesitzer veröffentlichen, wenn sie im Spiel verwendet werden sollen.
5. Dasselbe für die übrigen neun Modelle durchführen. Besonders prüfen:
   sechs bewegte Hände bei Many Hands, nur ein sichtbarer Arm bei Sole Conductor,
   Mütze/Fernrohr/Kerzenbuch in Seiten- und Rückansicht und die breitere Form von Marble Host.
6. Nach dem Einbau in Lanternfall einmal solo und mit zwei Spielern testen:
   Laufen, Richtungswechsel, Waffenpositionen, Kamera und Fußkontakt. Auf dem Handy
   Lesbarkeit und Bildrate prüfen. Diese Spieltests stehen ausdrücklich noch aus.

## Bereits geprüft

Für jeden Charakter: Quelle und Game-Blender-Datei geöffnet, FBX und GLB erneut
importiert, 15 Meshes und die 17 Bones der Standardhierarchie kontrolliert,
geschlossene Geometrie/positive Volumen/normalisierte Gewichte geprüft und reale
Bewegung der sichtbaren Teile gemessen. Jeder GLB-Mesh hat genau ein Material;
die Texturen sind eingebettet. Zusätzlich wurden alle 20 einzelnen FBX-Clips
erneut importiert und auf genau einen animierten R15-Rig geprüft.

Studio-Import, Humanoid-Verhalten, Spielintegration und veröffentlichte
Animations-IDs sind noch nicht geprüft beziehungsweise eingerichtet. Es wurde
nichts in deine Experience hochgeladen oder in den Spielcode eingebaut.

Die Importbezeichnungen und Rigstruktur folgen der offiziellen Dokumentation:
[Importer](https://create.roblox.com/docs/studio/importer),
[R15-Struktur](https://create.roblox.com/docs/avatar/character-bodies/specifications),
[FBX-Export](https://create.roblox.com/docs/art/modeling/export-requirements).
