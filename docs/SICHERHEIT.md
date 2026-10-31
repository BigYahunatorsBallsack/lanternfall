# Sicherheits- und Code-Review (Paket 23, 31.10.2026)

Ergebnis zum Abnicken für den Owner. Geprüft wurde der Stand von `main` nach Paket 22 (PR #48) plus die Änderungen dieses Pakets. Grundsatz aus `CLAUDE.md`: Der Client schickt nur Wünsche, alles Wichtige rechnet der Server.

## Kurz gesagt

- **Kein schwerer Fehler gefunden.** Schaden, Kills, XP, Beute, Shards, Embers, Käufe und Ranglisten rechnet nur der Server; jede der 31 Client-Nachrichten hat ein Tempolimit und wird geprüft.
- **Die größte Lücke war die Bewegung:** Roblox lässt jeden Spieler seine eigene Figur bewegen. Ein Cheat konnte schneller laufen, sich teleportieren oder durch die Arena-Wand und die Ruinen-Säulen gehen (dort erreicht ihn kein Gegner = unverwundbar). Das ist jetzt geschlossen (Bewegungs-Check, unten).
- Dazu vier kleinere Härtungen. Nichts davon ändert das Spielgefühl für ehrliche Spieler.

## Was geprüft wurde (in Ordnung)

| Bereich | Ergebnis |
| --- | --- |
| Alle 31 Remotes Client → Server (`Net/Remotes.luau`) | Tempolimit pro Spieler, Typ- und Bereichsprüfung jedes Arguments, zu viele Argumente = verworfen. Die Dienste prüfen danach Phase (Shop offen, Lobby …), Besitz und Preis und nehmen nur IDs, die der Server selbst angeboten hat (Karten, Shop-Angebote, Waffen-`uid`). |
| Server-Autorität | Treffer, Krits, Kills, XP, Drops, Kisten, Truhen, HP, Wiederbeleben, Embers, Erfolge, Quests und Ranglistenwerte entstehen nur auf dem Server. Zufall nur über `RandomService` (Seed geht nicht an Clients). |
| Debug-Knöpfe | Rechte prüft nur der Server (`AdminService.isAdmin`): in Studio jeder, im veröffentlichten Spiel nur der Besitzer der Experience (eigener Account) und wer in `Config/Admin.luau` steht. |
| Käufe (Paket 16) | `ProcessReceipt` bucht jede Kauf-ID genau einmal, erst gespeichert, dann „granted". Der Client kann nur um einen Kaufdialog bitten. |
| Ember-Shop, Kosmetik, Quests | Preis, Embers, Besitz, VIP und Tausch-Zahl prüft der Server. |
| Speichern (Paket 12) | ProfileStore mit Session-Sperre, Migrationen, Kick bei Ladefehler. Der eingebettete ProfileStore enthält keine fremden Nachlade-Befehle (`loadstring`, `require(<Zahl>)`, Web-Aufrufe); `HttpService` nur für Zufalls-IDs. |
| Teleport-Tickets (Paket 15) | Reisen über den Client und könnten gefälscht sein; der Run-Place prüft sie wie Lobby-Eingaben (Charakter frei, Startwaffe passt, Gefahrenstufe gedeckelt). In reservierte Server kommt niemand ohne Server-Teleport. |
| Ranglisten (Paket 18) | Lesen mit Cache und Budget, Schreiben nur aus fertigen Runs des Servers. |
| Aufräumen | Jeder Dienst vergisst Spieler beim Verlassen (kein Speicher-Leck bei vielen Beitritten). |
| Fremder Code | Kein `loadstring`, kein `require` per Asset-ID, keine Textfelder, keine RemoteFunctions (der Server wartet nie auf einen Client). |

## Was geändert wurde

1. **Bewegungs-Check** (`MapService/MovementGuard`, Regeln in `MapService/MovementRules`, Werte in `Config/Security.luau`). Sobald der Server eine Figur in die Arena gestellt hat, vergleicht er jede Position mit der zuletzt erlaubten:
   - Laufen hat ein „Strecken-Konto": es füllt sich mit dem Lauftempo (das der Server selbst setzt) × 1,25 und fasst 2,5 s Laufen + 6 Studs (Lag-Spitzen). Ein vom Server erlaubter Dash zahlt seine 12 Studs (× 1,25) extra ein.
   - Zu weit, außerhalb der Arena-Wand oder mitten in einer Säule → die Figur wird auf die letzte erlaubte Stelle zurückgesetzt, und alle Dienste (Gegner, Waffen, Aufsammeln, Wiederbeleben) sehen nur diese Stelle.
   - Die Geschwindigkeit, die Gegner zum Vorhalten und Items für „im Stillstand" lesen, wird auf das Machbare gedeckelt.
   - Nach dem Hinstellen 1 s Ruhezeit (der Client meldet kurz noch die alte Stelle), nach dem Abbremsen (Shop, Level-up, gestürzt) zählt 1 s das alte Tempo.
   - Lobby und Hub werden nicht geprüft (dort gibt es nichts zu gewinnen).
   - Jede Korrektur steht im Server-Output („Movement check: … moved back") und geht als Analytics-Ereignis `MovementCorrected` an Roblox (Creator Hub → Analytics → Custom). Viele Korrekturen bei ehrlichen Spielern = zu streng → Werte in `Config/Security.luau` lockern.
   - **In Studio standardmäßig aus** (Tests verschieben Figuren frei), im veröffentlichten Spiel an. Debug-Knopf „MovementCheck" schaltet ihn für den Server um.
   - Nebeneffekt: Positionen sind jetzt immer innerhalb der Arena. Vorher hätte ein Cheat mit einer Position weit draußen den Server mit riesigen Suchbereichen ausbremsen können.
2. **Debug-Runs nicht auf die Ranglisten:** Nutzt ein Admin während eines Runs einen Debug-Knopf, der den Run verändert (alles außer Drucken, Profil, Embers, Fake-Kauf, Freischalten, Nächster Tag), oder startet ein Run mit noch gesetztem Debug-Schalter (Wellen-Timer gestoppt, Spawnen pausiert, Waffen aus, Fake-Passes, Bewegungs-Check aus), bekommt er keine Ranglisten-Wertung. Embers und Erfolge zählen weiter (sonst lässt sich in Studio nichts testen).
3. **Einladungs-Spam:** Dieselbe Person kann frühestens nach 10 s erneut eingeladen werden (`Config.Security.reinviteSeconds`).
4. **Fremde Remote-Aufrufe:** Ruft ein Cheat eine Server→Client-Remote beim Server auf, wird das sofort verworfen (vorher hätte Roblox die Aufrufe gesammelt und gewarnt).
5. **Ganzzahl-Prüfung** lehnt jetzt auch „unendlich" und „keine Zahl" ab.

## Bleibende Risiken (bewusst so gelassen)

- **Kein Kick, kein Bann:** Der Check setzt nur zurück. Bei Fehlalarmen wäre ein Kick viel schlimmer als ein Cheat im Koop-Spiel. Bannen kann der Owner später über Roblox' Ban-API, wenn es nötig wird.
- **„Im Stillstand"-Items** lassen sich mit winzigen Teleport-Schritten vortäuschen (wenig Nutzen).
- **Springen und Fliegen** werden nicht geprüft: Gegner und Geschosse rechnen nur am Boden (x/z), Höhe bringt keinen Vorteil.
- **Automatisches Spielen** (Karten-Wahl, Shop per Skript) lässt sich nicht verhindern; die Waffen schießen ohnehin selbst.
- **Clients sehen alles, was sie bekommen** (Werte, Items, Gegner der Mitspieler). Das ist nicht geheim.
- **Debug-Schalter aus früheren Runs** zählen nur, wenn sie beim Run-Start noch an sind.
- **Admin im veröffentlichten Spiel:** Zieht die Experience später in eine Gruppe um, gilt der Besitzer-Check nicht mehr; dann die eigene UserId in `Config/Admin.luau` → `userIds` eintragen.

## Owner muss

Nichts. Optional zum Ausprobieren in Studio: Debug-Knopf „MovementCheck" (Meldung „Movement check on"), Run starten, im Explorer der **Client**-Ansicht `Workspace → <eigene Figur> → Humanoid → WalkSpeed` auf 60 stellen und laufen: die Figur wird immer wieder zurückgezogen, im Output steht „Movement check: … moved back (Speed …)".
