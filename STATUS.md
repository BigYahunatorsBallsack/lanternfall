# STATUS – Lanternfall

Kurzer Projektstand für neue Sessions. **Zuerst lesen**, dann aus `DESIGN.md` nur die Abschnitte, die das Paket braucht. Jedes Paket aktualisiert diese Datei im eigenen PR.

## Stand (30.10.2026)

- **Gemerged:** WP1–WP9, 9b, 9d, B1 (Wellen + Shop), B2 (Werte, 46 Items, Werte-Karten), Plan B3–B12 (PR #16), B3 (Shop komplett: Sperren, Verkaufen, Waffen-Stufen I–IV + Verschmelzen, Gratis-Neuwurf, Handy-Layout, 20 Wellen; PR #17, vom Owner in Studio getestet).
- **B4 fertig, wartet auf Test:** Effekt-Maschine, Neben-Werte, Zufalls-Ströme, 32 Items mit Effekten (Branch `wp-b4-effect-engine`). Der Owner testet B4 und B5 zusammen; B5 baut auf dem B4-Branch auf, nicht auf `main`.
- **Balance-Stand:** nach B3 gewannen gute Bots ca. 40 % der 20-Wellen-Runs (Wand bei Welle 13); eine Messung nach B4 (24 Runs) 15 von 24, Gegnerkurven unverändert. Blade Warden schwächer als Spark Mage (Thema für B5/B10).
- **Bekannt und harmlos:** Output-Zeile „DataStoreService: StudioAccessToApisNotAllowed … HttpRequestsCache“ kommt von einem Studio-Plugin, nicht aus unserem Code.
- **Als Nächstes:** B5 Kampf-Tiefe (**Extra high**). Danach B6 Beute (High), B7 Waffen (Medium), B8 Items (Medium), B9 Gegner (XH), B10 Charaktere (High), WP10 Boss (High), B11 Gefahrenstufen (High), B12 Bauten (High). Tabelle: `DESIGN.md` Abschnitt 20.

## Feste Entscheidungen des Owners

- **Brotato-Richtung:** Mechaniken, Formeln und Zahlen so nah wie möglich an Brotato (Quelle: brotato.wiki.spellsandguns.com); Namen, Texte, Items, Charaktere und Look eigene (DMCA-Risiko).
- **20 Wellen** wie Brotato (20–60 s, Welle 20 = 90 s); bis WP10 zählt das Überleben von Welle 20 als Sieg.
- **Skalierung unbegrenzt:** Items stapeln, Werte wachsen; Grenzen nur Ausweichen 60 %, Krit 100 %.
- HP = Brotato × 10. Level-ups geben nur Werte-Karten; Waffen und Items nur aus Shop und Truhen.
- Waffen-Stufen I–IV, zwei gleiche verschmelzen; Evolutionen ab Stufe IV (unsere Ergänzung).
- Bleibt anders als Brotato: Online-Koop 1–4 mit Wiederbeleben, Dash, Team-Level, 3D-Schrägkamera, Gegner-Obergrenze 80 + 20/Spieler.
- Talente entfallen zugunsten von Freischaltungen per Erfolg (WP13); Elites nur in Elite-Wellen ab Gefahrenstufe 2 (B11).
- Art Direction „okkultes Art déco", keine kopierten Figuren.
- Owner (29.10.2026): keine ausführlichen Balance-Simulationen mehr pro Paket, er testet selbst; Pakete dürfen ohne seinen Test aufeinander aufbauen, wenn er das sagt.

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
- Zufall: Server würfelt nur über `RandomService` (Ströme Shop, Upgrades, Loot, Spawns, Combat, Effects). Der Seed steht beim Run-Start im Output; `Config/Run.luau` → `seed` spielt ihn nach. In reinen Specs gibt es kein `Random`; der Mock (`RobloxMock`) hat ein deterministisches `Random.new(seed)`.
- Effekte testen: Debug-Knopf „Next effect item" gibt der Reihe nach jedes Item mit Effekt oder Neben-Wert. Ende-zu-Ende-Tests für Effekte in `tests/Smoke.spec.luau` (Helfer `give`, `bonusText`).

## Code-Landkarte

- `src/shared/Config/*` – alle Zahlen (Run/Wellen, Shop, Items, Stats, Weapons, Evolutions, Enemies, Player …).
- `src/shared/Net/Remotes.luau` – jede Remote mit Rate-Limit und Validierung; Payload-Typen in `Net/Types.luau`.
- Server `src/server/Services/`: `RunDirector` (Ablauf, Phasen), `SpawnDirector` + `EnemySim` (Gegner als Daten), `WeaponService/Arsenal` (Waffen, Stufen, Verschmelzen), `ShopService/ShopRules` (Shop-Formeln), `StatService` (Werte, Items; dauerhafte + bedingte Werte), `EffectService/EffectRules` (Item-Effekte, Ereignisse), `RandomService/Streams` (Seed, Zufalls-Ströme), `UpgradeService` (Werte-Karten, Truhen-Inhalt), `LootService` (Truhen), `ExperienceService` (XP, Team-Level), `CombatService` (HP, Dash), `AdminService` (Debug-Knöpfe).
- Client `src/client/Controllers/`: `ShopController`, `LevelUpController`, `StatsController`, `HUDController` (auch Bonus-Zeilen über der HP), `ProcTextController` (schwebende Effekt-Texte), `EnemyRenderer`, `WeaponRenderer` …
- Texte aus der Config: `Util/UpgradeText` (Karten, Items), `Util/EffectText` (Effekt-Zeilen, Bonus- und Auszahlungs-Texte).
- Reine Regeln (Formeln) liegen in Untermodulen (`ShopRules`, `RunFlow`, `SpawnRules`, `WeaponStats`, `UpgradePool`, `EffectRules`, `Streams`, `Util/StatMath`, `Util/RunSchedule`) und haben Unit-Tests in `tests/`.
