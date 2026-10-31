# UI-Redesign – Übergabe an die nächste Instanz

Stand: 31.10.2026. **Bewusst ein Zwischenstand, kein fertig abgenommenes Redesign.**

## Auftrag und Abbruchpunkt

Owner: „Schau dir mal den aktuellen stand des projekts an, ich hätte gerne ein großes UI redesign im Style von Brotato, damit alles endlich übersichtlich ist. Mach das bitte, hör aber auf, bevor das limit aufgebraucht ist, damit ich es an eine andere instanz zum finishen weitergeben kann.“

Dieser Auftrag erlaubt Änderungen an den betroffenen Client-UI-Dateien einschließlich der früher zwischen A/B geteilten bzw. A gehörenden Lobby-/Debug-Dateien. Server, Spielregeln, Kaufabläufe und Speicherformat bleiben unangetastet. Kein Merge-Auftrag für dieses neue Redesign. Als Draft übergeben.

## Wo weiterarbeiten

- Repo: `BigYahunatorsBallsack/lanternfall`
- Branch: `wp-ui-redesign`
- Basis: `d7152ca` (aktuelles main beim Start; beinhaltet B12 und Pakete bis 21 einschließlich Shop/Käufe, Party/Hub, Quests und HUD).
- Lokaler Arbeitsordner: `C:/Users/jonas/Documents/Roblox/lanternfall/lanternfall/.work-b7`
- **Nicht den übergeordneten Ordner benutzen:** dort liegen viele ältere, fremde uncommittete Änderungen.
- `.b7-tools/` ist unversionierter lokaler Werkzeug-/Build-Scratch, nicht committen.
- `git fetch origin main` vor Fortsetzung; ggf. neuen main aufnehmen und Konflikte sorgfältig lösen.

## Befund und Gestaltungsrichtung

Live-Screenshot des alten Stands im laufenden Studio geprüft: Status oben, Charakterwahl unten mittig, Party/Rekord/Shop/Quests links übereinander, Schwierigkeit rechts von offenem Debug verdeckt. Unabhängig skalierte Panels konkurrieren um Platz. Der Shop reserviert rechts Platz für Stats und unnötigerweise denselben Platz links; Karten werden dadurch sehr klein.

Brotato als **Informationsarchitektur**, mit eigenem Look: klare, fast rechteckige Karten, hoher Kontrast, Seltenheitsfarbe als Kennzeichnung, grüne/rote Werte, Aktionen deutlich getrennt. Anthrazit/Olive, Pergamenttext, Laternen-Gold statt der bisherigen durchsichtigen violetten Flächen. Keine kopierten Assets.

Visuelle Referenz: [Brotato-Shop-Screenshot](https://www.mobygames.com/game/192086/brotato/screenshots/windows/1131022/) – vier Angebote, Waffen darunter, Werte rechts. Die Referenz wurde zum Strukturvergleich gesucht; keine Assets übernommen.

## Bereits umgesetzt

1. **Theme.luau:** deckende dunkle Flächen, ruhigere Kontrastfarben, 5-px-Ecken, gemeinsame `canvas`, `surface`, `shards`-Farben. Vorhandene Controller übernehmen die Palette automatisch.
2. **UI/LobbyLayout.luau:** eigener Hintergrund, Marken-/Statuskopf, Tabs PLAY / DIFFICULTY / PARTY / COLLECTION. Nur ein Inhaltsbereich sichtbar. Vertikaler Scrollbereich statt Panels, die aus dem Bildschirm wachsen. Bestehende Controls werden umgehängt; ihre Remote-/Kauf-/Party-Handler bleiben erhalten. Tabs schließen offene Profilfenster über das vorhandene `ProfileCard.closeWindows`.
3. **LobbyController:** Profil mit Erfolgen, Stores und Quests in separate Collection-Fläche verlagert. Layout nach Montage aller Erweiterungen eingebunden.
4. **CharacterChoice.resize:** zwei Charakterspalten auf schmalen Screens, fünf auf breiten; Startwaffen als umbruchfähiges Raster; Beschreibung kann wachsen; READY/Back-to-hub passen in die verfügbare Breite.
5. **Widgets.unscaled:** verhindert doppelte UIScale-Verkleinerung innerhalb des responsiven Lobby-Layouts; entfernt die Skala auch aus Widgets' Beobachtungsliste.
6. **DebugController:** standardmäßig kleiner DEBUG-Knopf unten rechts, Diagnosewerte ebenfalls zu. Aufgeklappt scrollen die zahlreichen Befehle in einer begrenzten Fläche.
7. **ShopController:** nutzt freie Fläche links der Stats, breitere/höhere Karten, größere Details und Sperrknöpfe; keine Verkleinerung der Detailtexte bis auf 9 px. Waffenplätze bis zur höchsten Charakterkapazität gebaut, Höhe nach aktueller Kapazität (vorher nur sechs trotz Many Hands mit zwölf). Bestehende Kauf-/Verkauf-/Merge-/Lock-/Reroll-Handler unverändert.
8. **UiRedesign.spec.luau:** echte Bootstrap-Tests für Tab-Sichtbarkeit, Collection-Trennung, Profilfenster-Schließen, 390×844-Reflow, Debug, Auswahl/READY und zwölften Waffenplatz.

## Prüfergebnis und Grenzen

- Gesamte Suite: **60 Spec-Dateien, 650 Tests bestanden, 1 fehlgeschlagen**.
- Fehler: `StructuresB12.spec.luau`, „arms mines on contact and detonates after an enemy leaves“, Zeile 211: erwartet 0 Bauten, bekommt 1. STATUS nennt bereits auf main sporadische B12-Minenfehler. B12 und Server nicht verändert. **Nicht als vollständig grüne Suite ausgeben.** Kein Versuch, diesen separaten Simulationsfehler im UI-PR zu verstecken.
- Neue UI-Spec: 4/4 bestanden; HubStudio-Spec 10/10. Nach dem letzten Debug-Scroll-Feinschliff UI-Spec erneut 4/4.
- Selene src: 0 Fehler, 11 vorhandene UDim2-Stilwarnungen in alten UI-Zeilen. StyLua für geänderte Dateien, `git diff --check` und Rojo-Build geprüft.
- Lune verwendet den existierenden Test-Prelude plus RobloxMock. **Es prüft keine echten Roblox-Layouts/AbsoluteSize/Schriftumbrüche.**
- Verbundenes Studio: „Main Lobby“, Place 107221182628232, laufender Client. Nur alten Stand als Screenshot angesehen. Neue Quellen wurden dort nicht synchronisiert; **noch kein visueller Nachher-Test, keine Behauptung eines fertigen Looks.** Offenen Playtest nicht als neue Version interpretieren.
- Einrichtungs-/Restprobleme aus alten STATUS-Einträgen (Musik-IDs, Badges usw.) nicht Teil dieses UI-Auftrags.

## Nächste Arbeit – in dieser Reihenfolge

### 1. Visuell in Studio abnehmen

Branch synchronisieren, Play neu starten, Screenshots 1280×720 und 1920×1080 sowie 390×844 und 844×390 machen. Zuerst prüfen: Lobby-Hintergrund/ZIndex gegenüber Dialogen, AutomaticSize + ScrollingFrame, Locked-Charakter-Texte, Charakterwechsel mit unterschiedlich vielen Startwaffen, alle Tabs, Einladungspopup und Settings über Tabs. Collection-Fenster behalten noch ihre alten Größen und Positionen.

Neue Layout-Verantwortung liegt in `UI/LobbyLayout.luau`; nicht wieder einzelne Controller frei auf dem Bildschirm verteilen. Kaufbestätigungen, echte Robux-Preise, Sperren und Sichtbarkeit unbedingt erhalten.

### 2. Kampf-HUD neu ordnen

`HUDController`: kompakte HP/XP/Wellenleiste, Teamstatus am Rand, Waffen als übersichtliche Leiste, Items in ein einklappbares Inventar mit Tooltips. Zwischen Wellen keine doppelte Inventarliste hinter dem Shop. Down/Revive, Boss-Leiste, WavePreview, Settings und Handysteuerung berücksichtigen. `ReviveController`, `BossController`, `FirstNightController` visuell auf Überlagerungen prüfen, ihre Spielregeln nicht ändern.

### 3. Shop auf das endgültige Layout bringen

Desktop: Angebote, Waffen/Items, Stats als zusammenhängende Oberfläche statt unabhängiger Panels. Seltenheitsleiste und nachvollziehbare Platzhalter/Icons ergänzen; Lesbarkeit vor Dekoration. **Handy-Shop aktuell noch überwiegend alter Scale-Ansatz:** auf 2×2-Angebote oder Scrollbereich umbauen, Footer und Rerolls mit gut tippbaren Flächen, Stats als eigene Ansicht. Many Hands mit zwölf Waffen und sehr lange Itemeffekte testen. `StatsController` bei vielen sekundären Werten/Waffenklassen scrollbar begrenzen.

### 4. Auswahl- und Ergebnisbildschirme

`LevelUpController` und `ResultsController` in dieselbe klare Karten-/Spaltenstruktur übernehmen. Lange Texte, Truhe + Level-ups nacheinander, Sieg/Niederlage, Retry und Bonuszeilen prüfen. Bestehende Zahlen/Belohnungen bleiben serverbestimmt.

### 5. Meta-Fenster und Feinschliff

Settings, Store, Ember Shop, Achievements, Quests, Leaderboards: einheitliche Titel-/Schließen-Zeile, Scrollbereich, Footer, Touch-Ziele. Collection sollte später nach Records / Unlocks / Cosmetics / Store gegliedert werden; die heutigen Knöpfe bleiben erreichbar. Keine Echtgeld-Aktionen bei automatisierten visuellen Tests auslösen.

### 6. Abschließen

Gezielte UI-Integrationstests + gesamte Suite, Format/Lint/Build. Separaten B12-Flake sauber dokumentieren oder als eigenen Fix behandeln. STATUS/Design/Handoff aktualisieren, Draft in fertigen PR umwandeln. **Erst nach neuem Owner-OK mergen.**

## Werkzeuge und Befehle (Windows)

PowerShell im Arbeitsordner. Direkte Tool-Binaries, Rokit-Shims funktionierten hier nicht:

```powershell
& 'C:/Users/jonas/.rokit/tool-storage/johnnymorganz/stylua/2.6.0/stylua.exe' <geänderte Dateien>
& 'C:/Users/jonas/.rokit/tool-storage/kampfkarren/selene/0.31.0/selene.exe' src
& 'C:/Users/jonas/.rokit/tool-storage/rojo-rbx/rojo/7.4.4/rojo.exe' build -o .b7-tools/ui-redesign.rbxlx
.b7-tools/lune.exe run .b7-tools/run.luau tests/UiRedesign.spec.luau
```

Eine Spec je Lune-Aufruf. `run.luau` ist ein lokaler Adapter: liest src/tests, lädt `tools/luau-test-runner/prelude.luau` und reicht die Spec weiter. Wenn auf anderer Maschine Rust vorhanden: den regulären Runner nach AGENTS nutzen. Bei Python immer UTF-8; keine Dateien mit PowerShell-Standardencoding überschreiben.

## Kurzer Starttext für die nächste Instanz

> Setze das große UI-Redesign auf Branch `wp-ui-redesign` fort. Lies AGENTS.md, STATUS.md und docs/UI-REDESIGN-HANDOFF.md. Der Zwischenstand ist absichtlich noch nicht fertig oder visuell abgenommen. Beginne mit dem Studio-Layoutcheck, danach HUD, mobiler Shop, Level-up/Ergebnis und Meta-Fenster. Serverregeln und Kaufbestätigungen erhalten. Nicht ungefragt mergen.
