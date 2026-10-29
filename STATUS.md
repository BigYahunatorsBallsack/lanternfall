# STATUS – Lanternfall

Kurzer Projektstand für neue Sessions. **Zuerst lesen**, dann aus `DESIGN.md` nur die Abschnitte, die das Paket braucht. Jedes Paket aktualisiert diese Datei im eigenen PR.

## Stand (29.10.2026)

- **Gemerged:** WP1–WP9, 9b, 9d, B1 (Wellen + Shop), B2 (Werte, 46 Items, Werte-Karten), Plan B3–B12 (PR #16), B3 (Shop komplett: Sperren, Verkaufen, Waffen-Stufen I–IV + Verschmelzen, Gratis-Neuwurf, Handy-Layout, 20 Wellen; PR #17, vom Owner in Studio getestet).
- **Balance-Stand nach B3:** gute Bots gewinnen ca. 40 % der 20-Wellen-Runs, Wand bei Welle 13; Blade Warden schwächer als Spark Mage (Thema für B5/B10).
- **Bekannt und harmlos:** Output-Zeile „DataStoreService: StudioAccessToApisNotAllowed … HttpRequestsCache“ kommt von einem Studio-Plugin, nicht aus unserem Code.
- **Als Nächstes:** B4 Effekt-Maschine (**Extra high**). Danach B5 Kampf-Tiefe (XH), B6 Beute (High), B7 Waffen (Medium), B8 Items (Medium), B9 Gegner (XH), B10 Charaktere (High), WP10 Boss (High), B11 Gefahrenstufen (High), B12 Bauten (High). Tabelle: `DESIGN.md` Abschnitt 20.

## Feste Entscheidungen des Owners

- **Brotato-Richtung:** Mechaniken, Formeln und Zahlen so nah wie möglich an Brotato (Quelle: brotato.wiki.spellsandguns.com); Namen, Texte, Items, Charaktere und Look eigene (DMCA-Risiko).
- **20 Wellen** wie Brotato (20–60 s, Welle 20 = 90 s); bis WP10 zählt das Überleben von Welle 20 als Sieg.
- **Skalierung unbegrenzt:** Items stapeln, Werte wachsen; Grenzen nur Ausweichen 60 %, Krit 100 %.
- HP = Brotato × 10. Level-ups geben nur Werte-Karten; Waffen und Items nur aus Shop und Truhen.
- Waffen-Stufen I–IV, zwei gleiche verschmelzen; Evolutionen ab Stufe IV (unsere Ergänzung).
- Bleibt anders als Brotato: Online-Koop 1–4 mit Wiederbeleben, Dash, Team-Level, 3D-Schrägkamera, Gegner-Obergrenze 80 + 20/Spieler.
- Talente entfallen zugunsten von Freischaltungen per Erfolg (WP13); Elites nur in Elite-Wellen ab Gefahrenstufe 2 (B11).
- Art Direction „okkultes Art déco", keine kopierten Figuren.

## Owner und Ablauf

- Owner ist kein Entwickler, schreibt Deutsch, testet in Studio (neue UI, deutsch). Klick-für-Klick-Anleitungen; Multi-Client-Test läuft in **einem** Fenster („Client-Ansicht umschalten"), Output unter „Fenster".
- Code holt er per ZIP: `https://github.com/BigYahunatorsBallsack/lanternfall/archive/refs/heads/<branch>.zip` + `rojo serve` (kein git).
- PR nach `main`, Owner als Assignee (Review-Anfrage scheitert, weil er PR-Autor ist). Merge erst nach seinem OK.
- Roblox-Studio-MCP gibt es nicht: Owner testet selbst.

## Werkzeuge im Cloud-Container

- Rokit-Downloads sind blockiert: `cargo install stylua --features luau` und `cargo install selene` (je ~1–2 min), Test-Runner: `cd tools/luau-test-runner && cargo build --release`.
- Tests: `tools/luau-test-runner/target/release/luau-test-runner . tests/<Name>.spec.luau`, eine Datei pro Aufruf (RunDirector ist nicht reentrant). `tests/helpers/RobloxMock.luau` simuliert Roblox; prüft keine echten Property-Namen.
- Selene: `selene generate-roblox-std` scheitert. Nur `src` linten, aus einem Scratch-Ordner mit `selene.toml` (`std = "roblox-lite"`, `shadowing = "allow"`) und `roblox-lite.yml` (`base: luau`, Roblox-Globals inkl. `buffer` als `any: true`).
- Balance: `tests/balance/BalanceSim.luau` (lange Laufzeit). Varianten parallel aus Repo-Kopien im Scratchpad laufen lassen (4 Kerne); Streuung ist groß, für gute Bots 12+ Seeds.
- Falle: Eine Laufzeit-Instance darf nicht so heißen wie ein Rojo-ModuleScript daneben.

## Code-Landkarte

- `src/shared/Config/*` – alle Zahlen (Run/Wellen, Shop, Items, Stats, Weapons, Evolutions, Enemies, Player …).
- `src/shared/Net/Remotes.luau` – jede Remote mit Rate-Limit und Validierung; Payload-Typen in `Net/Types.luau`.
- Server `src/server/Services/`: `RunDirector` (Ablauf, Phasen), `SpawnDirector` + `EnemySim` (Gegner als Daten), `WeaponService/Arsenal` (Waffen, Stufen, Verschmelzen), `ShopService/ShopRules` (Shop-Formeln), `StatService` (Werte, Items), `UpgradeService` (Werte-Karten, Truhen-Inhalt), `LootService` (Truhen), `ExperienceService` (XP, Team-Level), `CombatService` (HP, Dash), `AdminService` (Debug-Knöpfe).
- Client `src/client/Controllers/`: `ShopController`, `LevelUpController`, `StatsController`, `HUDController`, `EnemyRenderer`, `WeaponRenderer` …
- Reine Regeln (Formeln) liegen in Untermodulen (`ShopRules`, `RunFlow`, `SpawnRules`, `WeaponStats`, `UpgradePool`, `Util/StatMath`, `Util/RunSchedule`) und haben Unit-Tests in `tests/`.
