# Verbindliche Anforderungen: Brotato 1:1

Owner-Entscheidung vom 06.11.2026, vor Beginn der fehlenden Charaktere festgehalten.

- [ ] Originale Charaktere, Waffen und Items vollstaendig fuer den beauftragten Umfang.
- [ ] Originalnamen, Texte und Darstellung; Sprites im aktuellen Auftrag durch einen anderen Agenten.
- [ ] Originale Startwerte, Boni, Nachteile, Startausruestung und Freischaltbedingungen.
- [ ] Originale Mechaniken, Formeln, Rundung, Limits, Preise und zeitliche Ablaeufe.
- [x] Originale HP-Einheit in den geprueften gemeinsamen HP-/Heilungsregeln: Faktor 1, keine x10-Skalierung.
- [ ] Jede Abweichung und jede nicht belegte Quellinformation offen dokumentieren. Eine gruene Projekt-Spec ist kein Nachweis vollstaendiger Originaltreue.
- [ ] Neue Regeln mit Quellenvergleich und Verhaltenstests pruefen; Solo/Koop/Handy-Abnahme getrennt ausweisen.

Die offenen Kaestchen beschreiben Anforderungen, keine abgeschlossene Implementierung. Diese Vorgaben ersetzen aeltere Regeln zu eigenen Namen/Inhalten, HP x10 und bewusst nur angenaeherten Mechaniken. Dateibesitz, Server-Autoritaet, Profil-Kompatibilitaet und Owner-Merge bleiben verbindlich. Bestehende Systeme nicht ohne zugehoerigen Auftrag pauschal umbauen.

## Vorpruefung vor der Charakter-Erweiterung

Basis: GitHub-main `34df95bf0a11450bccd6d63b99ac19a99843456f`, abgerufen am 06.11.2026. Der veraltete lokale Checkout und fremde Studio-Aenderungen wurden nicht als Quelle benutzt. Ergebnis: **Der aktuelle Gesamtstand ist nicht vollstaendig 1:1.**

| Bereich | Beleg im aktuellen Code | Ergebnis |
| --- | --- | --- |
| HP und Heilung | `Config/Player.maxHp = 10`, `Config/Stats.hpScale = 1`, `maxHpPerLevel = 1`, Karten +3/+6/+9/+12, Lebensraub 1 HP je 0,1 s, Frucht/Kiste 3 HP, legendaere Kiste 100 HP | Gepruefte gemeinsame Einheiten entsprechen dem Original. Historische x10-Angaben sind veraltet. |
| Hauptspiel-Gegnerwerte | `tests/MainGameEnemyStats.spec.luau`, `tests/MainGameEnemyRuntime.spec.luau` | 29 + 9 Tests bestanden; das bestaetigt die geprueften Daten/Verhalten, nicht saemtliche Angriffsmuster. |
| Waffen | 62 Hauptspiel-Eintraege; `tests/BrotatoWeapons.spec.luau` | 69 Tests bestanden. Geometrie, Projektile und Cooldown-Rundung weiterhin dokumentierte Abweichungen (`BROTATO-BASE-WEAPONS.md`). |
| Items | 125 Eintraege, siehe `docs/item-parity/README.md` | 136 Tests bestanden. Der bestehende Auftrag ersetzte nur vorhandene Eintraege; das Wiki nennt 208 Hauptspiel-Items. Der Gesamtkatalog ist unvollstaendig. |
| Upgrade-Karten | `tests/UpgradeReference.spec.luau` | 17 Tests bestanden fuer alle 16 Arten und 64 Kartenwerte. |
| Werte und Shopregeln | `tests/StatMath.spec.luau`, `tests/ShopRules.spec.luau` | 8 + 14 bestehende Tests bestanden; kein vollstaendiger Quellenbeweis fuer diese Systeme. |
| Charaktere | `Config/Classes.luau`, `tests/CharactersB10.spec.luau` | Neun spielbare Pakete, eigene Anzeigenamen; 13 vorhandene Tests bestanden. Fehlende Charaktere sind der anschliessende Auftrag. |
| Gegnerobergrenze | `Config/Run.spawn.cap`: solo 80, Koop bis 140; Spawn-Gruppen warten bei vollem Budget | Abweichung: Wiki beschreibt 100 und Entfernen eines zufaelligen gewoehnlichen Gegners bei neuem Spawn. |
| Baum-Leben | `Config/Enemies.Tree`: 20 HP + 10 pro Welle | Gewollte Abweichung (Owner, 08.11.2026): doppelt so viel wie Brotatos 10 + 5. |
| Elite-Angriffe und Spawn-Gruppen | `docs/B9C-GEGNERWERTE.md`, `Config/EnemyWaves`, `BossService` | Eigene Angriffsmuster und angepasste Gruppendichte sind im Bestand ausdruecklich dokumentiert. Noch keine 1:1-Abnahme. |
| Angriffstempo | `Config/Stats.attackSpeed.negativeFactor = 0.5`, `StatMath.cooldownFactor`, `Config/Combat.originalWeapons` | Einheitliche Ersatzformel bei negativem Tempo und begrenztes Nachholen; das Original hat waffen-/animationsabhaengige Effekte. |
| Weitere Systeme | Team-Level, Meta-Embers/Kaeufe, Bauten, Beute, Endlos, Freischaltungen, UI/Animationen | Vollstaendige Originaltreue nicht bewiesen; vorhandene Unterschiede nicht durch die HP-Umstellung als erledigt behandeln. |

Ausgefuehrt: jede der acht genannten Specs separat mit dem vorhandenen Lune-Runner, **295 bestanden, 0 fehlgeschlagen**. Dies war eine gezielte Code-/Quellen-Vorpruefung, kein kompletter Studio-Run und keine vollstaendige Gesamtspiel-Zertifizierung. Es wurden dabei keine Spielwerte geaendert.

## Quellen und Quellenluecken

- [Stats](https://brotato.wiki.spellsandguns.com/Stats): gemeinsame HP-/Heilungsregeln und Werte.
- [Items](https://brotato.wiki.spellsandguns.com/Items): 208 Hauptspiel-Items, 33 Abyssal-Terrors-Items; Seite nennt Version 1.1.15.4.
- [Enemies](https://brotato.wiki.spellsandguns.com/Enemies#Enemy_Maximum): Gegnerlimit und Verdrängung.
- [Attack Speed](https://brotato.wiki.spellsandguns.com/Attack_Speed): waffenabhaengiges negatives Angriffstempo und Animationsgrenzen.
- [Characters](https://brotato.wiki.spellsandguns.com/Characters): 74 gelistete Namen, davon 50 Hauptspiel und 14 mit dokumentierten Abyssal-Regeln. Zehn Primal-Dread-Eintraege liefern derzeit „Character name not found“ statt Regeln; zum Beispiel [Veteran](https://brotato.wiki.spellsandguns.com/Veteran) und [Archaeologist](https://brotato.wiki.spellsandguns.com/Archaeologist). Fuer diese fehlenden Daten keine Werte erfinden.

Alle Quellen am 06.11.2026 abgerufen. Fuer den neuen Charakterauftrag benoetigte Erweiterungen muessen den bestehenden Dateibesitz beachten; ein 1:1-Ziel allein ist keine pauschale Erlaubnis fuer fremde Dateien.

## Versionskonflikt aus der erweiterten Pruefung

Das offizielle [Update 1.2 vom 02.11.2026](https://steamcommunity.com/games/1942280/announcements/detail/719046160957835975) bringt Primal Dread und aendert auch aeltere Charaktere. [Patch 1.2.0.1 vom 03.11.2026](https://steamcommunity.com/ogg/1942280/announcements/detail/719046730650222971) folgt darauf. Die [Entwickler-Nachrichten](https://steamcommunity.com/app/1942280/homecontent/) kennzeichnen 1.2.0.2.beta-0 am 06.11.2026 ausdruecklich als offene Beta, nicht als stabile Version.

Die bestehende Waffenquelle nennt 1.1.6.3, die Itemquelle 1.1.15.4; das Wiki liefert nicht fuer alle 74 Charaktere gueltige Daten. Der Testvergleich oben prueft die gespeicherten Referenzen und darf deshalb auch bei 295 gruenen Tests nicht als bestaetigte Originaltreue zum aktuellen Patch ausgegeben werden. **Owner bestaetigt: stabile PC-Version 1.2.0.1 einschliesslich aller DLCs**, keine Beta. Keine stillschweigende Mischung verschiedener Patches.

## Fuer vollstaendige Charakterregeln benoetigte Schnittstellen

**Owner-Freigabe vom 06.11.2026:** Die gezielten Charakter-Ergaenzungen in den folgenden A-Diensten sind fuer diesen Auftrag erlaubt. Sonstiger Dateibesitz und fremde parallele Aenderungen bleiben geschuetzt:

| Dienste | Benoetigte Charakterfaehigkeit |
| --- | --- |
| `CombatService` / `Vitals` | Golem: Heilungsverbot; Lich: Ereignis fuer tatsaechliche Heilung einschliesslich Regeneration; Wounded: ein gueltiger Treffer toedlich nach Schutz-/Ausweichpruefung. |
| `ExperienceService` / `Progression`, `UpgradeService` | Eigene XP-Kosten fuer Mutant/Baby/Technomage/Captain; Baby ohne Wertekarte, Captain mit staerkeren Karten. XP Gain allein ist kein mathematisch korrekter Ersatz. Gemeinsames Team-Level benoetigt belegte Koop-Regeln. |
| `EnemySim`, `SpawnDirector`, `RunDirector` | Pacifist/Cryptid: verbindliche Wellenend-Zaehlung vor Entfernen der Gegner/Baeume; Fisherman: wiederkehrende Bait-Gegner statt nur einmal nach Kauf. |
| `MapService` und Nutzer der Arena-Grenzen | Old/Explorer: Kartengroesse pro Run; bisher werden feste Grenzen zwischengespeichert. |
| `DangerService` / `DangerRules` | Jack: Elite-Wellen anstelle von Horden. |

Fuer DLC-Charaktere fehlen ausserdem gemeinsame Systeme wie Curse, verfluchte Gegner/Angebote und bezauberte Gegner. Keine dieser Regeln darf durch einen blossen Datensatz oder eine ungefaehre Ersatzmechanik als erledigt gelten. Sprites sind hiervon getrennt.

## Verifizierte stabile Quelle und laufende Umsetzung (07.11.2026)

- Die installierte Steam-Version ist 1.2.0.1, Build 26406319 vom 03.11.2026. Alle 74 Charaktere und ihre Quelleffekte sind einschliesslich Ressourcen-Hashes in `docs/characters/source.json` erfasst; der reproduzierbare Compiler erzeugt `Config/CharacterCatalog.luau`. Die fruehere Quellenluecke der zehn Primal-Dread-Charaktere ist damit geschlossen. Herkunft und Grenzen: `docs/characters/README.md`.
- Neue Datensaetze bleiben bis zur vollstaendigen Umsetzung ihrer Abhaengigkeiten nicht auswaehlbar. Insbesondere fehlen 29 benoetigte Waffenfamilien, zehn Startitems/Pets, originale Freischaltungen und mehrere DLC-Systeme. Vorhandene neun Pakete haben weiterhin historische Anzeigenamen und noch nicht vollstaendig umgestellte Startauswahlen. **74 Quelldatensaetze sind keine 74 fertigen Charaktere.**
- Crazy, Brawler und Ghost sind die ersten drei zusaetzlichen code-fertigen Pakete: originale Startalternativen, garantierte Ausruestung, Werte/Nachteile und Boni nur fuer die jeweilige Waffenklasse. Ghost wird bei +60 % Dodge fuer das betreffende Profil dauerhaft freigeschaltet, hat +10 flachen Schaden fuer Ethereal-Waffen und eine tatsaechlich im Kampf gepruefte 90-%-Ausweichgrenze. Beschreibungen und Freischalttext sind anhand der stabilen englischen Sprachressource samt Formatierungsregeln belegt. Alle drei sind mit `nativeCodeReady` markiert und werden erst mit vorhandenen Originalsprites samt Bildgrenzen auswaehlbar; diese liefert der andere Agent. Die uebrigen 62 neuen Pakete bleiben bis zur vollstaendigen Code-Integration gesperrt. Gemeinsame offene Systeme wie vollstaendige Shop-Verteilung und DLC-Waffenveraenderungen bleiben fuer die Gesamt-1:1-Abnahme erforderlich.
- Originale Waffenfreischaltungen sind fuer 91 bestehende/benoetigte Waffenfamilien erfasst und ersetzen bei diesen Waffen die alten eigenen Sperren. Die Auswahl prueft gesperrte Startalternativen auf Client und Server, Hand ist frei, Claw braucht einen Cryptid-Sieg und Vorpal Sword dauerhaft 100 Crit Chance. 13 originale Itemverbotsgruppen und die Identitaeten aller aktuellen Items steuern Shop- und Kistenpools; der originale Backup-Pool darf bei leerem Normalpool gesperrte Items wieder enthalten. Shovel-/Flail-Ereignisfreischaltungen bleiben mit den noch offenen DLC-Mechaniken verbunden.
- Implementiert und am echten Server-Service-Verbund im Luau-Mock geprueft: Heilungsverbot/ein toedlicher Treffer, erfolgreiche Heilungsereignisse, Regenerationsuhr, Golem-Grenze, Vampire-Prozentrundung, Lich-Statangriff, Sick-Selbstschaden, temporaere Hurt-/Dodge-Boni, volle-HP-Verbrauchseffekte, Soldier-Bewegungssperre mit laufendem Cooldown/Projektilen, Streamer-Stillstandsuhr und Inventar-/Weltzaehlungen. Originale Link-Boni kuerzen den gesamten Ausdruck gegen null und wenden danach den Zielstat-Gewinnfaktor an.
- Bulls Explosion bei tatsaechlichem HP-Verlust ist angebunden: 30 Grundschaden, dreifache Nah-/Fernkampf-/Elementarskalierung, additive Schadens-/Explosionsboni, eigene 3-%-/1,5x-Kritwerte und originale Kollisionsgeometrie. Fuenf Service-Szenarien pruefen unter anderem Selbstschaden, Abwehr, Reichweite, fehlenden Lebensraub und toedlichen Schaden; vier reine Rechentests sichern die Reihenfolge. Bull bleibt bis zur Danger-1-Freischaltung, zur waffenlosen Menuefolge, zur originalen Regeldarstellung und zur Pruefung gleichzeitiger toedlicher Bossinteraktionen gesperrt.
- Koop: Materialien und XP rotieren pro ganzzahliger Einheit unabhaengig vom Sammler. Jeder Empfaenger hat eigene XP, Stufen, XP-Gewinne, Karten und HP-Zuwachs. `LevelGained(level, player)` nennt den Empfaenger; die historische Remote `TeamProgress` liefert nur noch dessen persoenlichen Stand. Mutants erste Schwelle bleibt 5,44 XP. Wiederholung stellt persoenliche Fortschritte und Verteilungszeiger wieder her.
- `RunDirector.WaveEnding(wave)` laeuft vor dem Entfernen der Welt. Pacifist/Cryptid-Boni werden dort erfasst; anschliessend loest `WaveRewards(wave)` die Wellenboni und die Verrechnung mit eigener Ernte aus, auch bei direktem Sieg ohne Shop. Nur eine positive Gesamtsumme gibt XP. Horden halbieren Pacifist erst nach der Rundung. Eine Endlos-Abstimmung zahlt dieselbe Welle nicht erneut aus; eine verlorene Endloswelle erhaelt trotz spaeterem Gesamtergebnis Victory keine Auszahlung. Der aktuelle Simulator entfernt keine Gegner zur Leistungsbegrenzung, sondern teleportiert sie; deren zusaetzlicher Pacifist-Zaehler bleibt deshalb null, bis die originale Verdrängungsregel umgesetzt ist.
- Grundbestand beim Start wieder 0 Materialien; die vorherigen 15 waren eigenes Balancing. DLC-Statfelder sind serverseitig bekannt, ihre Anzeige und Originalsymbole bleiben Teil der noch gesperrten DLC-Pakete.
- Kartenregeln integriert: Captain-Wertmodifikation mit ganzzahligem Abschneiden vor Stat-Gewinnfaktoren, Charakter-Ausschluesse vor Welle 20 und Babys echte Waffenplatz-Karte bis 24 Plaetzen. Native `item_service.get_upgrades` bietet Baby genau eine Platz-Karte an, solange das Platzlimit nicht erreicht ist; der Platz wird erst bei der Auswahl gewaehrt und bei Wiederholung korrekt wiederhergestellt. Danach folgen normale Werte-Karten. Droid unterdrueckt Werte-Karten mit `no_level_upgrades`. Die Originalabbildung der Platz-Karte bleibt eine Grafik-Abhaengigkeit.
- Direkt gepruefte UI-/XP-Referenz: Native `PlayerRunData.current_level` startet bei 0; `player_ui_elements.update_level_label` zeigt diesen Wert unveraendert als `LV.0`. Progression, HUD, Kartenstufen, Max-HP-Ereignisse und waffenbezogene Level-Skalierung sind auf diesen Zaehler ausgerichtet. Die erste Schwelle bleibt 16 XP bzw. 5,44 fuer Mutant; Stufe 5 ist die erste garantierte ungewoehnliche Karte.
- Studio-, Zwei-Client- und Handy-Abnahme bleiben offen. Es wurden keine Sprites erstellt oder veraendert und nichts gemerged.


## Aktuelles Versionsziel (Owner, 13.11.2026)

Der Owner hat den Wechsel auf die installierte stabile PC-Version **1.2.0.2**, Steam-Build26615634, einschließlich aller DLCs freigegeben. Frühere Versionsbindungen an1.2.0.1 sind historische Nachweise. Vorhandene48 code-vorbereitete Pakete müssen gegen die Änderungen geprüft werden; die Prüfung ist noch nicht abgeschlossen. Referenzidentität steht in `docs/characters/reference.json`, Änderungsprüfung in `docs/characters/version-1.2.0.2-audit.json`. Alte Quellen bleiben erhalten; keine pauschale Umbenennung historischer Nachweise.

## Fortsetzung unter eingefrorener1.2.0.2-Referenz (13.11.2026)

Die Versionsänderungen an den48 zuvor code-vorbereiteten Paketen sind inzwischen geprüft (reference.json und version-1.2.0.2-audit.json); dies ist keine native Komplettabnahme. Steam hat danach1.2.0.3 installiert, die nicht freigegeben wurde. Allgemeine Quellcompiler bleiben auf1.2.0.2 geschützt. Einzelne Ressourcen wurden nur nach nachgewiesener Bytegleichheit mit bereits gesicherten1.2.0.2-Hashes gelesen; neue Regeln aus1.2.0.3 wurden nicht übernommen. Weitere Charakter-Ready-Markierungen gab es durch die Jungle-/Trefferflächen-Grundmechaniken nicht. Aktueller Stand und konkrete Restarbeit: docs/characters/HANDOFF.md.

## Aktuelles Versionsziel und Audit (Owner,14.11.2026)

StabilePC-Version1.2.0.3/Build26642464 mit allenDLCs ist ausdrücklich freigegeben und ersetzt1.2.0.2. AlteQuellen bleiben erhalten. Sieben geänderte Skriptdateien geprüft; der Katalog ändert nur Cavemans Startauswahl (Boomerang entfällt). Audit der48bereitscodevorbereitetenPakete abgeschlossen, keine zusätzlichenfertigenCharaktere und keine nativeGesamtabnahme. VerbindlicheIdentität: reference.json; Einzelbewertung/Tests: version-1.2.0.3-audit.json. Jungle-Boss-/Snowball-/UI-/Physik-/Grafik-/Studio-Lücken bleiben offeneArbeit.
