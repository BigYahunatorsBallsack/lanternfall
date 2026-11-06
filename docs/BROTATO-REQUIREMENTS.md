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
