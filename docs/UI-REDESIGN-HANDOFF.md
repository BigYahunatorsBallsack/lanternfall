# UI-Redesign – Implementierung und Abnahme

Stand: 31.10.2026. Der Owner hat den geplanten Instanzwechsel aufgehoben und die Fortsetzung beauftragt. **Die geplanten UI-Bereiche sind implementiert; der echte Studio-Sichttest steht aus.**

## Branch und Umfang

- PR: https://github.com/BigYahunatorsBallsack/lanternfall/pull/46
- Branch: `wp-ui-redesign`, ursprüngliche Basis main `d7152ca`; vor Merge auf main `c37cc78` einschließlich Paket 22/23 aktualisiert.
- Arbeitsordner: `C:/Users/jonas/Documents/Roblox/lanternfall/lanternfall/.work-b7`.
- Nicht den übergeordneten Arbeitsordner benutzen: dort liegen ältere, fremde Änderungen. `.b7-tools/` enthält ausschließlich unversionierte Werkzeuge und Builds.
- Der UI-Auftrag umfasst auch ehemals A zugeordnete Client-Dateien. Keine Änderung an Server, Balancing, Remotes, Speicherformat oder Kaufbestätigungen. Der Owner hat am 31.10.2026 die Konfliktauflösung und den Merge ausdrücklich beauftragt.

## Umgesetzt

Brotato dient als Vorbild für klare Karten, Seltenheitsfarben und getrennte Aktionen. Eigene Palette aus Anthrazit/Olive, Pergamenttext und Laternen-Gold; keine übernommenen Assets.

| Bereich | Verhalten / Dateien |
| --- | --- |
| Grundlage | `UI/Theme`, `Widgets.unscaled`, neue `UI/Dialog`: responsive Breite, vertikaler Scrollbereich, dauerhaft erreichbares Schließen. |
| Lobby | `UI/LobbyLayout`, `LobbyController`, `CharacterChoice`: PLAY / DIFFICULTY / PARTY / COLLECTION; nur ein sichtbarer Bereich; Charaktere und Startwaffen als Raster. |
| Kampf | `HUDController`: kompaktere Anzeigen; BUILD öffnet alle Waffen und Items mit Tooltips. Im Shop keine doppelte Inventar-/HP-Anzeige. Boss-/Revive-Anzeigen an schmale Screens angepasst. |
| Shop | `ShopController`: vier Desktop-Angebote, zwei mobile Spalten, eine bei sehr schmalem Fenster. Scrollender Inhalt, fester Reroll-/READY-Footer, scrollbare Effektdetails, bis zu zwölf Waffenplätze. |
| Werte | `StatsController`: scrollbare Primary-/Secondary-Werte und Waffenklassen; rechts auf Desktop, über STATS und Back to Shop auf kleinen Screens. |
| Auswahl / Ergebnis | `LevelUpController`, `ResultsController`: umbruchfähige Karten, scrollbare Truhen/Ergebnisse, relative Aktionsbreiten, kein Abschneiden nach sechs Waffen. |
| Meta | `ProfileCard`, Achievements/Stores/Quests: gemeinsame Dialoge, lange Zeilen wachsen, Listen beginnen oben. Settings und Party-Einladung passen sich ebenfalls an. |
| Tutorial / Debug | First Night: GOT IT klappt die Hilfe ein, HELP öffnet sie erneut, Skip bleibt verfügbar. Debug beginnt eingeklappt und scrollt nach Öffnen. |

Die bestehenden Auswahl-, Kauf-, Lock-, Verkaufs-, Merge-, Reroll-, Ready-, Party- und Einstellungs-Handler bleiben erhalten.

## Automatische Prüfung

- 67 Spec-Dateien, 705 Tests bestanden nach Integration des aktuellen main; neue UI-Spec 9/9.
- UI-Spec: Tabwechsel, Meta-Fenster, mobile Breiten, Settings-Schließen, echte Charakter-/Ready-/Upgrade-Abläufe, vollständiges Inventar, Shop-Footer und Stats-Wechsel bei 390×844 / 844×390, zwölf Ergebniswaffen.
- FirstNight-Spec prüft zusätzlich GOT IT und HELP, ohne den Tutoriallauf zu beenden.
- StyLua, `git diff --check`, Rojo-Build erfolgreich; Selene 0 Fehler / 11 bestehende UDim2-Stilwarnungen, mit gecachter Roblox-API.
- Ein früherer Lauf des ersten Zwischenstands hatte den bereits in STATUS genannten sporadischen B12-Minenfehler (Zeile 211). Paket 22 auf main enthält inzwischen dessen Korrektur; diese bleibt erhalten. Der aktuelle zusammengeführte Lauf ist grün.
- Lune führt die bestehenden Specs mit dem vorhandenen Test-Prelude und RobloxMock aus. **Der Mock berechnet keine echten Pixelpositionen, Schriftumbrüche oder Scrollgesten.**

## Noch nötige Studio-Abnahme

Während der Fortsetzung liefert Studio MCP keine verbundenen Instanzen. Es gibt daher keinen Screenshot oder Playtest der neuen Darstellung. Die frühere Aufnahme zeigte ausschließlich den alten Stand.

1. Branch `wp-ui-redesign` aus dem oben genannten Arbeitsordner per Rojo synchronisieren. Alternativ den lokalen Build `.b7-tools/ui-redesign.rbxlx` in Studio öffnen. Play neu starten; ein bereits laufender Client hat die neuen Module noch nicht geladen.
2. Desktop 1280×720 und 1920×1080: alle vier Lobby-Tabs anklicken. Charakter und Startwaffe ändern, Gefahr einstellen, Collection-Fenster und Settings öffnen/schließen. Dialoge sollen über der Lobby liegen; lange Listen müssen bis zum letzten Eintrag erreichbar sein.
3. Geräteemulator 390×844 und 844×390: dieselben Wege wiederholen. Lesbare Texte ohne globale Verkleinerung, kein horizontaler Überlauf. Auch lange gesperrte Charaktertexte und viele Startwaffen prüfen.
4. Run starten: HP/XP/Wellenzeit und Teamstatus kontrollieren, BUILD öffnen/schließen, alle Itemzeilen und Tooltips prüfen. Mit Debug GainLevel und SkipWave Level-up und Shop erreichen. First Night separat starten; GOT IT und HELP testen.
5. Shop: Angebote kaufen, sperren, neu würfeln, Waffen auswählen/verkaufen/zusammenführen, READY. Lange Effekte innerhalb einer Karte scrollen. Auf Handy bleibt der Footer erreichbar, STATS öffnet eine eigene Ansicht, Back to Shop kehrt zurück. Many Hands mit zwölf Waffen prüfen.
6. Truhe, Sieg/Niederlage und Retry prüfen: Texte und komplette Waffenstatistik müssen erreichbar sein. Mit zwei Clients Party-Einladung, Ready/Waiting, Teamstatus und Down/Revive kontrollieren. Studio-Output auf Fehler prüfen.

Keine echten Robux-Käufe für die Layoutabnahme nötig. Preise, Sperren und Bestätigungen bleiben bestehen. Der Merge ist vom Owner freigegeben; die beschriebenen Studio-Prüfungen stehen weiterhin aus.

## Lokale Werkzeuge

PowerShell im Arbeitsordner; Rokit-Binaries direkt:

```powershell
& 'C:/Users/jonas/.rokit/tool-storage/johnnymorganz/stylua/2.6.0/stylua.exe' <geänderte Dateien>
& 'C:/Users/jonas/.rokit/tool-storage/kampfkarren/selene/0.31.0/selene.exe' src
& 'C:/Users/jonas/.rokit/tool-storage/rojo-rbx/rojo/7.4.4/rojo.exe' build -o .b7-tools/ui-redesign.rbxlx
.b7-tools/lune.exe run .b7-tools/run.luau tests/UiRedesign.spec.luau
```

Eine Spec pro Prozess. Der lokale Lune-Adapter nutzt `tools/luau-test-runner/prelude.luau`; alternativ den regulären Rust-Runner nach AGENTS bauen. Dateien immer als UTF-8 schreiben.
