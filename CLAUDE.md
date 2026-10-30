# CLAUDE.md – Lanternfall

Koop-Survivors für Roblox (1–4 Spieler, 12-Min-Runs, Boss bei 12:00). Das vollständige Design steht in `DESIGN.md` – vor jedem Arbeitspaket den passenden Abschnitt lesen.

## Owner & Kommunikation

- Der Owner ist kein Entwickler. Er testet, entscheidet und pflegt den Creator Hub; den Code schreibst du.
- Mit dem Owner auf **Deutsch** schreiben, kurz und konkret, ohne Fachjargon, der nicht erklärt wird.
- Code, Bezeichner und Kommentare auf **Englisch**; Spieltexte (UI, Namen) ebenfalls Englisch.
- Am Ende jedes Pakets: 2–4 Sätze, was gebaut wurde, plus eine nummerierte **Testanleitung** für den Owner (was klicken, was er sehen sollte).
- Brauchst du etwas, das nur der Owner kann (Creator-Hub-IDs, Einstellungen, Geräte-Tests), sag es klar und Schritt für Schritt.

## Arbeitsweise

- **Einstieg in ein neues Paket:** zuerst `STATUS.md` lesen (Stand, Entscheidungen, Werkzeuge, Code-Landkarte), dann aus `DESIGN.md` nur die Abschnitte, die das Paket berührt. Nicht das ganze Design-Dokument und keine alten Thread-Verläufe lesen.
- **Jedes Paket aktualisiert `STATUS.md` im eigenen PR** (Stand, nächstes Paket mit Effort, neue Entscheidungen oder Werkzeug-Tricks).
- **Ein Arbeitspaket pro Session** (Tabelle in `DESIGN.md`, Abschnitt 20). Kein Paket anfangen, das nicht genannt wurde.
- Pro Paket ein Branch `wp-<nr>-<kurzname>`, kleine Commits, Commit-Text auf Englisch im Imperativ. Nie auf `main` force-pushen; Merge erst nach OK des Owners.
- Vor größeren Umbauten kurz den Plan nennen (3–5 Punkte), dann umsetzen.
- Ändert sich das Design, `DESIGN.md` im selben Branch aktualisieren.
- **Parallel-Arbeit mit ChatGPT:** Claude ist **Strang A** (Gegner, Beute, Ablauf). Dateibesitz, geteilte Dateien (nur anhängen), Runden, Merge-Regeln und Übergabe-Vorlage stehen in `docs/PARALLEL.md`; ChatGPT liest dieselben Regeln über `AGENTS.md`. PR-Titel beginnt mit `[Claude]`, PR-Text nach `.github/pull_request_template.md`.
- Ein Bug, der nach zwei Versuchen nicht gelöst ist: stoppen, Ursache und Optionen beschreiben, nicht weiter raten.

## Toolchain

- Rojo synchronisiert `src/` nach Studio; Projektdatei `default.project.json` nach der Struktur in `DESIGN.md` Abschnitt 15:
  - `src/shared` → `ReplicatedStorage.Shared`
  - `src/server` → `ServerScriptService.Server`
  - `src/client` → `StarterPlayer.StarterPlayerScripts.Client`
- Tools über Rokit verwalten (rojo, wally, stylua, selene); Pakete über Wally oder vendored in `src/shared/Packages`.
- Vor jedem Commit: StyLua formatieren, Selene ohne Fehler.
- Ist die Roblox-Studio-Verbindung (MCP) verfügbar: Playtests darüber starten, Output lesen, Fehler selbst beheben. Sonst den Owner bitten, den Output zu kopieren.

## Architektur-Regeln (nicht verhandelbar)

1. **Server-Autorität:** Der Client sendet nur Absichten (Bewegung, Dash, Level-up-Wahl, Kaufwunsch). Schaden, Kills, XP, Drops, Embers, Truhen und Ranglistenwerte berechnet ausschließlich der Server.
2. **Jede Remote** wird in `src/shared/Net` definiert, hat ein Rate-Limit und wird serverseitig validiert (Typen, Bereiche, nur vom Server angebotene IDs).
3. **Keine Balancing-Zahl im Code.** Alle Werte in `src/shared/Config/*` – Waffen, Passive, Gegner, Klassen, Talente, Economy, Difficulty.
4. **Gegner sind Daten**, keine Humanoids: Server-Simulation mit 15 Hz und Spatial Hash (8 Studs), Snapshots per UnreliableRemoteEvent in einem `buffer`, Client rendert gepoolte Modelle mit Interpolation und `workspace:BulkMoveTo`. Obergrenze 80 + 20 pro weiterem Spieler, max. 140.
5. **Ein ModuleScript pro Service/Controller**, `--!strict` wo möglich, oben eine Kommentarzeile: Zweck und Aufrufer.
6. **Neue Waffe = Config-Datensatz + Verhaltensmodul**, das Framework bleibt unverändert.
7. **Performance-Budgets** (`DESIGN.md` Abschnitt 15) bei jeder Änderung an Gegnern, Projektilen oder VFX beachten.

## Daten & Käufe

- Spielerdaten nur über ProfileStore mit Session-Locking; Schema siehe `DESIGN.md` Abschnitt 16.
- Schema-Änderung = `schemaVersion` +1 + Migrationsfunktion. Felder nie ohne Migration entfernen.
- `ProcessReceipt` idempotent: PurchaseId im Profil speichern, erst danach `PurchaseGranted` zurückgeben.
- Entwickelt und getestet wird gegen die **Test-Experience**, nie gegen Live-Daten.
- Keine Lootboxen ohne Odds-Anzeige in % vor dem Kauf; `PolicyService` für eingeschränkte Spieler auswerten.
- Avatar-Einstellung bleibt „R15 only".
- Keine Secrets, Cookies oder API-Keys ins Repo.

## Definition of Done (pro Arbeitspaket)

- [ ] Läuft in Studio ohne Fehler im Output.
- [ ] Getestet solo und mit 2 Clients („Test → Clients and Servers").
- [ ] Keine hartkodierten Balancing-Werte, Remotes validiert.
- [ ] StyLua + Selene sauber.
- [ ] `DESIGN.md` aktualisiert, falls sich Design oder Werte geändert haben.
- [ ] Commit(s) auf dem Paket-Branch, deutsche Zusammenfassung + Testanleitung für den Owner.

## Effort-Hinweis

Medium als Standard. Extra high nur für: Architektur, Gegner-Engine, Waffen-Framework, Speichern, Käufe, Teleport, Performance, Sicherheit. Max nicht verwenden. Steht ein Paket auf Extra high und läuft gerade Medium, kurz darauf hinweisen.
