# Auftrag an den nächsten Coding-Agenten

Implementiere alle noch fehlenden Brotato-Charaktere in Lanternfall vollständig. Ziel: stabile PC-Version 1.2.0.1 mit allen DLCs, insgesamt 74 Charaktere. Der Owner erwartet funktionierende Charaktere einschließlich ihrer benötigten Ausrüstung und Mechaniken, nicht nur Konfigurationsdatensätze. Sprich Deutsch mit ihm; Code, Kommentare und Spieltexte bleiben Englisch.

## Aktuell: Pacifist (09.11.2026)

Pacifist ist als sechstes neues Codepaket vorbereitet: alle drei Originalstarts, garantierter Lumberjack Shirt, Originalstats/-texte und Freischaltung durch insgesamt 10.000 physisch aufgesammelte Materialobjekte. Schema v10 ergänzt einen persönlichen, gespeicherten Zähler samt Migration; Verdopplung/Währungsrotation beeinflussen ihn nicht. Shirt tötet Bäume nach gültigen Besitzer-Hitboxen, ohne den gemeldeten Schaden zu erhöhen; Brennen/Stat-Strikes bleiben getrennt. Auswahl und Zufallspools bleiben ohne echte Bilder gesperrt. Shirt-Originalbild lokal vorbereitet; nichts hochgeladen.

Noch elf Waffenfamilien und neun Item-/Petfamilien. Sechs code-vorbereitete Pakete (Crazy/Brawler/Ghost/Bull/Doctor/Pacifist) sind keine native 1:1-Abnahme; allgemeine Formel-/Physik-/Grafiklücken sowie Studio/Koop/Handy bleiben offen. Vergleich main 607524e: 1230 bestanden, unverändert 34 vorhandene Fehler in 143 Specs; Vollvergleich plus betroffene Nachprüfungen nach Main-Integration. Quellen/Prüfung: pacifist-source.json und pacifist-validation.json. Der bereits integrierte Patch weiter unten darf nicht erneut angewendet werden.

## Aktuell: Projektil-Startausrüstung (09.11.2026)

Von GitHub-main b518842 vier weitere Originalfamilien ergänzt: Blunderbuss, Javelin, Tranq Rifle, Harpoon Gun. Materialaufnahme setzt die längste nicht schießende Blunderbuss-Abklingzeit des Sammlers zurück; Javelin zählt Salven; Tranq verlangsamt im Trefferbereich; Harpoon besitzt feste Mindestreichweite, Zug und einmalige Verlangsamung pro Projektil/Ziel. Native additive Geschwindigkeitsabzüge besitzen Haltezeit und Erholung. Client-Zielwahl und Reichweitentext berücksichtigen die Mindestreichweite. Arsenal unverändert.

80 konfigurierte Waffen: 62 öffentlich, 18 wegen echter Bild-Uploads gesperrt. Die 18 Originalbilder sind lokal vorbereitet. Noch elf Startwaffenfamilien und zehn Item-/Petfamilien; weiterhin fünf code-vorbereitete Charakterpakete, keine neue vollständige Charakterabnahme. Gesamtvergleich: 1220 bestanden, dieselben 34 vorhandenen Main-Fehler, 141 Specs. Zwei ältere Universaltests benötigten gültigen Zielabstand für Harpoon; Schadensprüfungen bleiben erhalten. Quelle: weapon-source.json; Grenzen und Prüfnachweis: projectile-starts-validation.json. Keine Studio-/Zwei-Client-/Handy-Abnahme, keine Uploads. Allgemeine native Physik-/Formel-/Darstellungsabweichungen bleiben offen.

## Aktuell: weitere Startausrüstung (08.11.2026)

Von GitHub-main 181502a sechs weitere Familien implementiert: Spoon, Cestus, Sickle, Trident, Lute, Blowgun. Alle gültigen Tiers greifen in Produktionsmodultests an; Bedingungsregeln, gemeinsame Verwundbarkeitsstapel/-dauer, Krit-/Zielbonus-Reihenfolge und Tiertexte geprüft. Neue Originalbilder nur lokal vorbereitet. Noch 15 Waffen- und zehn Item-/Petfamilien; Zahl code-vorbereiteter Charakterpakete bleibt fünf. Native blaue Verwundbarkeitskontur und allgemeine Physik-/Waffen-/Itemformel-Abweichungen bleiben offen. Quelle: weapon-source.json; Prüfung: starting-gear-validation.json (1201 bestanden/34 vorhandene Main-Fehler in 135 Specs, Seed 1234).

## Aktuelle Fortsetzung: Chef und Doctor (08.11.2026)

PR #90 und #98 sind gemergt. Glutton-Verbrauchsexplosionen sind angebunden. Chef hat jetzt Verbrauchsexplosion/Brennen und den Bonus gegen brennende Ziele bei nativen Waffen-, Itemexplosions- und Strukturtreffern; er bleibt wegen fehlender Startausrüstung, Freischaltung und Regelanzeige unvollständig. Quellen: chef-source.json, consumable-source.json.

Doctor ist als fünftes neues Codepaket vorbereitet: alle drei Startwaffen, originale Stats/Modifikatoren und Texte, persönliche 200-HP-Heilungsfreischaltung mit Wellen-/Retry-Reset. Quelle: doctor-source.json. Heilungszählung verwendet native akzeptierte Heilung vor dem HP-Limit; Lich bleibt beim getrennten Ereignis für tatsächlich gewonnene HP. Negative Attack Speed bei nativen Waffen verwendet die volle Originalverlangsamung. Echte Charakter-/Meat-Tenderizer-Uploads sowie native Studio-/Zwei-Client-/Handy-Abnahme fehlen. Code-vorbereitet ist keine vollständige 1:1-Abnahme.

## Fortsetzung vom 08.11.2026 (PR #90)

Diese Ergänzung aktualisiert die historischen Restangaben unten: Bull ist jetzt als viertes neues Paket code-vorbereitet (Zugriff, waffenlose Menüfolge und Regeldarstellung getestet). Der gesicherte Patch wurde integriert und darf nicht erneut angewendet werden. Crazy/Brawler/Ghost/Bull benötigen weiterhin echte Bild-Uploads; neun historische Charaktere bleiben öffentlich verfügbar, keine vollständige native Abnahme behauptet.

Acht Startwaffenfamilien sind implementiert und lokal mit Originalbildern vorbereitet: Anchor, Mace, Meat Tenderizer, Whip, Machine Gun, Pan Flute, Combat Shotgun, Grenade Launcher. Bis echte Bilder eingebunden sind, bleiben sie gesperrt. Noch 21 Waffen- und zehn Item-/Petfamilien laut Katalogprüfung. Materialmodifikatoren, Farmer-Ernte, Entrepreneur-Recycling/Wallet-Reset, One-Armed-/Vagabond-Setzählung und Cyborg-Halbzeitumwandlung sind angebunden; diese Einzelmechaniken machen die betreffenden Charakterpakete nicht vollständig. Quellen und Einzelheiten stehen in weapon-source.json, economy-source.json, half-wave-source.json und STATUS.md.

Owner: vorerst nur Code und lokale Bildvorbereitung. Keine Uploads/Veröffentlichung. Künftige Merges brauchen keine zusätzliche Freigabe. Chef-/Glutton-Reproduktionstests sind lokal angefangen und noch nicht Teil dieses geprüften Zwischenstands.

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
- Berichte kurz, welche Charaktere jetzt tatsächlich vollständig angebunden sind und welche Abhängigkeiten verbleiben. Schließe den Auftrag erst ab, wenn alle 74 Regeln samt Ausrüstung funktionieren. PR nach Projektvorlage; der Owner hat zukünftige Merges ausdrücklich ohne erneute Freigabe autorisiert.
