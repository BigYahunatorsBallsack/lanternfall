# B7 – Waffen und Testanleitung

18 neue Waffen, insgesamt 24. Alle neuen Waffen haben ein konkretes Vorbild aus dem Brotato-Basisspiel; Namen und Darstellung sind eigene. Die sechs bisherigen Waffen behalten ihre Daten.

## Zuordnung und Quelle

[Brotato Wiki – Weapons](https://brotato.wiki.spellsandguns.com/Weapons), abgerufen am 30.10.2026, Tabelle beschriftet mit Patch 1.1.6.3. Übernommen: Stufenschäden, Skalierungen, Cooldowns, Krit, Lebensraub, Rückstoß, Reichweiten, Preise und Mindeststufen. Community-Dokumentation, keine Garantie für jede aktuelle Spielversion.

| Lanternfall | Brotato | Ab Stufe |
| --- | --- | --- |
| Brass Knuckles | Fist | I |
| Ritual Dirk | Knife | I |
| Lamplighter Pike | Spear | I |
| Dusk Sabre | Sword | II |
| Gravestone | Rock | I |
| Tithe Palm | Hand | I |
| Wraith Hatchet | Ghost Axe | I |
| Spirit Flint | Ghost Flint | I |
| Watchman Pistol | Pistol | I |
| Rattle Repeater | SMG | I |
| Scatter Bell | Double Barrel Shotgun | I |
| Shrapnel Organ | Shredder | I |
| Cinder Breath | Flamethrower | II |
| Galvanic Fork | Taser | I |
| Leech Carbine | Medical Gun | I |
| Cathedral Engine | Chain Gun | IV |
| Mortar Lantern | Rocket Launcher | II |
| Winter Needle | Icicle | I |

Bei Konflikten mit der PDF folgt B7 der konkreten Waffentabelle: Medical Gun heilt über Lebensraub, nicht über Heilprojektile. Icicle durchschlägt einen Gegner, ohne erfundenen Slow. Knife ist Precise. Chain Gun skaliert mit Ranged Damage und Engineering. Engineering ist dafür reserviert, bleibt bis B12 aber ohne neue Erwerbsquellen oder primäre Upgrade-Karten.

## Verhalten und Grenzen

- Stöße treffen entlang einer Linie, Schwünge im vorderen Sektor; Dusk Sabre wechselt beides. Treffer werden beim Angreifen ausgewertet, die kurze Animation ist visuell.
- Scatter Bell: 4/4/4/6 Pellets im Fächer. Shrapnel Organ: Explosionschance pro Treffer. Mortar Lantern: Explosion bei jedem Treffer, ohne doppelten Schaden am direkten Ziel.
- Cinder Breath: Brennen; Galvanic Fork: Slow um die Projektilflugbahn; Winter Needle: Durchschlag. Leech Carbine nutzt das bestehende Lebensraub-Limit.
- Wraith Hatchet und Spirit Flint geben je 20/18/16/12 eigene Kills dauerhaft +1 Damage bzw. Attack Speed. Teilzähler verfallen am Wellenende; verdiente Werte bleiben nach Verkauf.
- Gravestone/Tithe Palm geben Werte nur solange getragen. Kopien, Verschmelzen und Verkauf rechnen neu.
- Cathedral Engine: drei Projektile pro Salve, nach 100 Salven 2,04 s Nachladen. Das bestehende Limit von 12 Angriffen/s gilt weiterhin.
- Dread bildet Legendary ab: ab zwei Waffen −200 HP, dann weitere −200 bis sechs. Tool/Bauten bleiben B12; Choir erhält keine DLC-Waffe.

**Roblox-Annahmen:** bestehende Umrechnung von 0,1 Studs pro Reichweitenpunkt; Projektiltempo 60 Studs/s, Radius 0,5, Fächerabstand 8°, Stoßbreite 1,2, Schwenkwinkel 120°, Visualdauer 0,18 s. Taser-Aura: 2 Studs, 30% Slow für 1 s. Explosionen verwenden den vorhandenen Basisradius von 6 Studs (Rocket 120%, Shredder 50%). Diese Raum-/Animationswerte sind keine behaupteten Brotato-Messwerte. Die zusätzliche Nahkampf-Verlangsamung durch mehr Reichweite ist wie im bisherigen Framework noch nicht abgebildet. Alle Spielwerte stehen in Config.

## Studio-Test

1. Branch `wp-b7-weapons` als ZIP herunterladen, entpacken und darin `rojo serve` starten. Test-Place in Studio öffnen, Rojo verbinden, Play starten, Klasse wählen und Ready drücken.
2. Im Debug-Menü den Wellentimer anhalten (`Hold waves`). Mit `Next weapon` alle 24 Waffen einzeln durchschalten; kurz zwischen Klicks warten. `Spawn wave` erzeugt Ziele, `Tier up weapons` erhöht die Stufe. Cathedral Engine startet auf IV; Dusk Sabre, Cinder Breath und Mortar Lantern auf II.
3. Nahkampf gegen Ziele vor und hinter dir prüfen: Stöße entlang einer Linie, Schwünge gegen mehrere Ziele vorn. Dusk Sabre wechselt die Angriffsform. Scatter Bell muss einen Fächer schießen.
4. Explosionen und Slow prüfen. Brennen an einem Elite oder späteren Gegner testen, der den ersten Treffer überlebt. Bei verletztem Spieler muss Leech Carbine per Lebensraub heilen, ohne volle HP zu überschreiten.
5. Cathedral Engine länger als zehn Sekunden feuern lassen: nach 100 Salven kurze Pause, dann weiter. Ohne Ziele darf das Magazin nicht verbraucht werden.
6. Gravestone/Tithe Palm im Shop kaufen, verschmelzen und verkaufen: Werte müssen steigen und wieder verschwinden. Wraith Hatchet/Spirit Flint: nach genügend Kills muss der gewonnene Damage-/Attack-Speed-Punkt auch nach Verkauf bleiben.
7. Frühe Shops dürfen keine Waffen unter Mindeststufe anbieten. Sperren, Verkaufen, Verschmelzen sowie Stufenpreise mit den neuen Waffen prüfen.
8. Mit zwei Clients wiederholen: eigene Käufe und Kill-Boni dürfen nicht dem anderen gehören, beide sehen Angriffe. Handy auf Lesbarkeit und Ruckler prüfen; Output unter „Fenster“ auf Fehler prüfen.

## Automatisierte Prüfung

25 Spec-Dateien / 320 Tests bestanden (inklusive gemergtem B6). Neue Fälle stehen in `WeaponsB7.spec.luau` und `WeaponsB7Integration.spec.luau`; alte Erwartungen an exakt sechs Waffen wurden aktualisiert. Der vorhandene Rust-Runner führt jede Datei separat aus. Lokal lief derselbe Prelude über einen Lune-Adapter, weil Rust fehlt. StyLua bestanden; Selene `src`: keine Fehler, acht bestehende UI-Warnungen. Studio, reale Geräte und Netzwerk noch nicht geprüft. Keine Balance-Simulation durchgeführt.
