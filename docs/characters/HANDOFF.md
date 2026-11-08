# Auftrag an den nächsten Coding-Agenten

Implementiere alle noch fehlenden Brotato-Charaktere in Lanternfall vollständig. Ziel: stabile PC-Version 1.2.0.1 mit allen DLCs, insgesamt 74 Charaktere. Der Owner erwartet funktionierende Charaktere einschließlich ihrer benötigten Ausrüstung und Mechaniken, nicht nur Konfigurationsdatensätze. Sprich Deutsch mit ihm; Code, Kommentare und Spieltexte bleiben Englisch.

## Einstieg und Befugnisse

- Prüfe GitHub-main von BigYahunatorsBallsack/lanternfall und beginne davon. Lies AGENTS.md, CLAUDE.md, STATUS.md, docs/PARALLEL.md und docs/BROTATO-REQUIREMENTS.md. Der alte Ordner C:/Users/jonas/Documents/Roblox/lanternfall/lanternfall ist veraltet; dessen Änderungen erhalten.
- Du übernimmst Strang B. Die gezielten Charakter-Ergänzungen in Strang A sind ausdrücklich freigegeben. Keine fremden Umbauten. Arsenal bleibt unverändert; Server autoritativ; Zahlen in Config. Neue Waffen benötigen Config, Behavior und Visual.
- Arbeite am gesamten Restauftrag weiter. Liefere vollständige Charakterpakete in sinnvollen Gruppen. Nutze vorhandene Implementierungen, begrenze zusätzliche Grundsystem-/Dokumentationsarbeit auf tatsächlich benötigte Abhängigkeiten. Routinemäßige Entscheidungen selbst treffen. Bei parallelen Agenten eindeutigen Dateibesitz vergeben.
- 1:1 bedeutet Originalnamen, Texte, Werte, Formeln und Verhalten. HP-Faktor 1. Keine Ersatzmechaniken, erfundenen Zahlen oder bloßen Freigaben unvollständiger Pakete. Ungeklärte Punkte offen benennen.

## Tatsächlicher Stand

- Drei neue Pakete sind code-vorbereitet: Crazy, Brawler, Ghost. Neun ältere Pakete existieren, besitzen aber noch historische Namen/Startlisten und sind nicht vollständig nativ umgestellt. Die 74 Quelldatensätze sind keine 74 fertigen Charaktere.
- Alle 74 Originalsprites aus PR #88 wurden übernommen. tools/art2d/sprites.json ist verbunden; assets/characters/brotato/local-preparation.json enthält vorbereitete Bildgrenzen/Hashes. Alle 74 Roblox-Uploads fehlen. Owner wünscht zunächst lokale Vorbereitung. Keine erfundenen Asset-IDs. Die bestehenden neun Laufzeitbilder und die Verfügbarkeitsprüfung bleiben bis zum echten Upload erhalten. Erst dann native Grafik-/Roster-Tests erweitern.
- Bereits angebunden: native Heilungs-/Schadensregeln, Regenerationsticks, Bewegungseffekte/Soldier, Stat-Strikes/Lich/Lucky, persönliche Koop-XP und Materialrotation, LV.0, Captain-/Baby-Karten, Waffenlimits, native Itemverbotsgruppen/-Tags, Waffenfreischaltungen, Ghosts persönliche 60-Dodge-Freischaltung sowie normale/finale Wellenbelohnungen mit Retry-/Endlos-Isolation.
- Bull: Explosionsmechanik implementiert (30 Basis, dreifache Melee/Ranged/Elemental-Skalierung, additive Damage/Explosion-Boni, 3% Crit, x1.5, native Geometrie). Gesamtpaket bleibt gesperrt. Es fehlen Danger-1-Sieg-Freischaltung, waffenlose Menüfolge, originale Regeldarstellung und Prüfung gleichzeitiger tödlicher Bossinteraktionen.
- docs/characters/unfinished-changes.patch enthält separat gesicherte, nicht in den Laufzeitstand übernommene Ansätze: Bull-WinDanger-Zugriff, waffenlose Menüfolge sowie einen Inline-Statbild-Regelrenderer mit sechs Tests. Vor Übernahme prüfen; git apply --check verwenden. Renderer war isoliert getestet; gesamte Anbindung nicht abgeschlossen.

## Quellen wiederverwenden

- docs/characters/source.json und CharacterCatalog enthalten alle 74 stabilen Quellen samt Hashes. remainingRules sind explizite Laufzeit-Eingaben, keine verlässliche Restanzahl; viele besitzen bereits Handler.
- Die installierte Originalkopie liegt in C:/Program Files (x86)/Steam/steamapps/common/Brotato/Brotato.pck, Version 1.2.0.1, Build 26406319. tools/character-source.py liest den unverschlüsselten PCK; nicht erneut die gesamte Quellenrecherche beginnen. tools/build-character-catalog.py --check nennt fehlende Ausrüstung.
- build/character-source enthält lokale, ignorierte Inspektionen des Originalcodes und das vorhandene GDRE-Werkzeug. Keine extrahierten Originalskripte oder Spielarchive committen. Vorhandene neutrale Daten und eigene Implementierungen verwenden.

## Konkrete Restarbeiten

1. Fehlende Startausrüstung: 29 Waffenfamilien, zehn Item-/Petfamilien. Der Compiler nennt die vollständige Liste. Acht weitgehend bestehende Verhaltenswege: Anchor, Mace, Meat Tenderizer, Whip, Machinegun, Pan Flute, Combat Shotgun, Grenade Launcher. Native Tier-/Effektressourcen im PCK prüfen. Machinegun benötigt Schießen ohne Ziel, Whip zeitliche Treffergeometrie; Pan-Flute-Spread ist in Radian. Vorhandene BrotatoMelee/Projectile/Runtime nutzen, ohne Spezialeffekte wegzulassen.
2. Economy: Arms Dealer Waffenrabatt/Mindestwaffe/Zerstören; Demon HP-Währung/Materialumwandlung; Gangster Stehlen/Elitefolgen; Fisherman Baits und wiederkehrende Gruppen; Entrepreneur Recycling/Wallet-Reset; Curious Loot Aliens. Native Material-Drop-Modifikatoren und Farmers Erntewachstum fehlen ebenfalls.
3. Arena/Gefahr: Old/Explorer Kartengröße, Explorer-Bäume, Jack/Gangster/Ogre/Veteran Hordenregeln. Weitere Waffen-/Charaktereffekte: Renegade Projektilzahl/Accuracy, One Armed zusätzliche Set-Zählung, Vagabond alle Waffen für Sets, Cyborg Halbzeit-Umwandlung, Hiker echte Schritte, Chef/Glutton Verbrauchsexplosionen, Ogre Overkill, Diver Verwundbarkeit, Dwarf Mehrfachkills desselben Angriffs.
4. Curse/Charm sowie Strukturen/Pets: verfluchte Gegner/Gegenstände, Sailor/Creature/Romantic; Engineer gruppierte Bauten; Builder-Turm und Orb-Umwandlung; Technomage Structure Attack Speed/Range; Beast Master echte Pet-Startwahl, Verhalten, Zählung und Skalierungen.
5. Primal Dread: Ausgrabungen, Feuerpfad/-flächen, Caveman Nebel/Waffenverbrennen, Droid Materialgesundheit/Mecha-System, native Evolution/Mutation, Poacher Fangzone, Survivor Kistenwaffen, Time Shifter Zeitversatz, Veteran Wellenend-Früchte. Die alten eigenen Waffen-Evolutionen sind kein Ersatz.
6. Alle originalen Charakterfreischaltungen und die vollständige native Übernahme der neun Alt-IDs. Anschließend Auswahl, Starts, Reset/Retry und persönliche Isolation aller 74 prüfen. Originalbilder allein lösen keine dieser Code-Abhängigkeiten.

## Prüfung und Abschluss

- Letzter vollständiger geprüfter Codestand: 1110 bestanden / 30 fehlgeschlagen in 110 Specs, Seed 1234, jede Spec separat. Main-Vergleich 5f52293: 994/29 in 86 Specs. Zwei zusätzliche Smoke-Fehler erwarten LV mit Leerzeichen statt nativem LV.; weitere Smoke-/RunStats-Fehler bestehen schon auf main. Der 4-ms-Gesamtleistungstest schwankt. Baseline beim neuen Einstieg neu vergleichen; keine Tests schwächen, überspringen oder Fehler verschweigen.
- Tests mit Lune: C:/Users/jonas/.rokit/tool-storage/lune-org/lune/0.11.1/lune.exe run tools/luau-test-runner/lune-runner.luau tests/NAME.spec.luau. Je Datei ein Prozess. StyLua, Selene und Rojo passend ausführen; bei API-Downloadfehlern vorhandenen Selene-Cache nutzen.
- Native Studio-/Zwei-Client-/Handy-Abnahme ist nicht erfolgt. Produktionsmodul-Tests im Roblox-Mock als solche bezeichnen.
- Berichte kurz, welche Charaktere jetzt tatsächlich vollständig angebunden sind und welche Abhängigkeiten verbleiben. Schließe den Auftrag erst ab, wenn alle 74 Regeln samt Ausrüstung funktionieren. PR nach Projektvorlage; zukünftige Merges nur mit erneuter Owner-Freigabe.
