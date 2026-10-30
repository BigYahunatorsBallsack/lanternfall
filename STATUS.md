# STATUS – Lanternfall

Kurzer Projektstand für neue Sessions. **Zuerst lesen**, dann aus `DESIGN.md` nur die Abschnitte, die das Paket braucht. Jedes Paket aktualisiert diese Datei im eigenen PR.

## Stand (30.10.2026)

- **Gemerged:** WP1–WP9, 9b, 9d, B1 (Wellen + Shop), B2 (Werte, 46 Items, Werte-Karten), Plan B3–B12 (PR #16), B3 (Shop komplett: Sperren, Verkaufen, Waffen-Stufen I–IV + Verschmelzen, Gratis-Neuwurf, Handy-Layout, 20 Wellen; PR #17), B4 (Effekt-Maschine, Neben-Werte, Zufalls-Ströme, 32 Items mit Effekten; PR #18) und B5 (Kampf-Tiefe: Krit pro Waffe, Rückstoß + Resistenz, Brennen, Explosionen, Durchbohren/Abprallen, Verlangsamen sichtbar, 14 Waffenklassen, 12 Kampf-Items; PR #19). B4 und B5 hat der Owner am 30.10.2026 zusammen in Studio getestet (`/mnt/project-files/lanternfall-b5/TESTANLEITUNG.md`).
- **Test-Falle Brennen:** Spark Bolt (15) tötet Welle-1-Gegner (10 HP) mit einem Treffer, die fangen also nie Feuer (wie in Brotato). Brennen in Testanleitungen immer an einem Elite oder in späteren Wellen zeigen.
- **Balance-Stand:** nach B3 gewannen gute Bots ca. 40 % der 20-Wellen-Runs (Wand bei Welle 13); eine Messung nach B4 (24 Runs) 15 von 24, Gegnerkurven unverändert. Blade Warden schwächer als Spark Mage (Thema für B5/B10).
- **Bekannt und harmlos:** Output-Zeile „DataStoreService: StudioAccessToApisNotAllowed … HttpRequestsCache“ kommt von einem Studio-Plugin, nicht aus unserem Code.
- **Als Nächstes:** Ab B6 arbeiten Claude und ChatGPT parallel in zwei Strängen (Regeln, Dateibesitz, Runden: `docs/PARALLEL.md`; ChatGPT liest `AGENTS.md`). Runde 1: B6 Beute (Claude, **High**) und B7 Waffen (ChatGPT, Medium), jeweils wenn der Owner es sagt. Tabelle: `DESIGN.md` Abschnitt 20.
- **B6 Beute (Strang A, 30.10.2026):** PR `[Claude] B6 Beute` von Branch `wp-b6-loot`, wartet auf Test und OK des Owners (`/mnt/project-files/lanternfall-b6/TESTANLEITUNG.md`). Drop-Chance ab Welle 5, Beutel, höchstens 50 Orbs, Früchte und Kisten (Item nehmen oder verkaufen vor den Level-up-Karten), Plünderer, Bäume. Legendäre Kiste kommt mit Paket 10/B11. Danach für Strang A: B9 Gegner (**Extra high**); B8 (Strang B) darf erst nach dem Merge von B6 starten.
- **B8 Items (30.10.2026, von Claude statt ChatGPT):** PR `[Claude] B8 Items` von Branch `wp-b8-items`, wartet auf Test und OK des Owners (`/mnt/project-files/lanternfall-b8/TESTANLEITUNG.md`). 24 neue Items (jetzt 114) nach Brotato-Vorbildern, dazu Effekt-Aktionen „Strike" (Schaden an zufälligem/getroffenem Gegner, auch % seiner HP) und „Drain" (HP verlieren, nie unter 1), Bedingung „volle HP" bei Frucht/Kiste, „pro X" mit negativem Schritt und Untergrenze, Quellen „lebende Gegner" und „verschiedene Items einer Stufe". Angefasst außerhalb der Item-Dateien (nur angehängt): `Arsenal.queueStrike`, `WeaponService.strikeEnemy`, `CombatService.drainPlayer`, `EnemySim.getHealth`, `LootService.ConsumableCollected` (drittes Argument `wasFull`). Wiki-Liste kam nur bis „I" an (Seite zu lang); weitere Items mit I–Z-Vorbildern später.

## Stränge

Jeder Strang ändert nur **seine** Zeile (Regeln: `docs/PARALLEL.md`).

| Strang | KI | Aktuelles Paket | Branch / PR | Stand | Danach |
| --- | --- | --- | --- | --- | --- |
| A – Engine und Ablauf | Claude | B6 Beute (High) | `wp-b6-loot` / PR `[Claude] B6 Beute` | fertig, wartet auf Test und Merge | B9 Gegner (XH) |
| B – Inhalte und Spieler-Regeln | ChatGPT | B7 Waffen (Medium) | – | wartet auf Start durch den Owner | B8 Items (Medium, erst nach Merge von B6) |

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
- B5 (30.10.2026): Brotatos Waffen-Sets heißen bei uns **Waffenklassen** mit eigenen Namen (Edge, Bludgeon, Arcane, Spectral, Volatile, Longshot, Colossal, Remedy, Knightly, Choir, Keen, Primal, Steward, Brawl); Boni ab 2 Waffen, Kopien zählen, Maximum bei 6. Jede Waffe hat 1–2 Klassen und ist Melee oder Ranged.
- Annahmen (Wiki schweigt, im Test prüfen): Brennen springt pro Tick auf den nächsten nicht brennenden Gegner in 8 Studs; Abprall-Ziel zufällig in 25 Studs; Rückstoß 0,1 Studs pro Punkt; Elites sind immun gegen Rückstoß.
- B6 (30.10.2026, Annahmen im Test prüfen): Kisten sind 25 % der Früchte/Kisten-Drops (Brotato nennt keinen Grundwert), Brute/Abyss Brute 3 %, Charger 2 % statt 1 %; Plünderer verschwindet nach 12 s; 1 Baum pro Welle mit 30 HP; Kisten öffnen sich vor den Level-up-Karten, nach 10 s wird genommen; liegengebliebene Kisten gehen an den nächsten Spieler. Elite-Truhen bleiben bis Paket 10/B11 wie sie sind (sonst 13 legendäre Items pro Run).

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
- Effekte testen: Debug-Knopf „Next effect item" gibt der Reihe nach jedes Item mit Effekt oder Neben-Wert, „Next combat item" jedes Kampf-Item (Brennen, Explodieren, Durchbohren, Abprallen, Rückstoß). Ende-zu-Ende-Tests für Effekte und Kampf in `tests/Smoke.spec.luau` (Helfer `give`, `bonusText`); `EnemyRenderer.getStatus(id)` liefert brennt/verlangsamt auf dem Client.
- Kampf-Falle: Item-Brände und -Explosionen (EffectService → `WeaponService.burnEnemy/explodeAt`) laufen über eine Warteschlange am Ende von `Arsenal.step`, sonst würden Explosion → Kill → Explosion rekursiv laufen und die Scratch-Arrays überschreiben. StatService rechnet Klassen-Boni nur neu, wenn sie sich ändern (sonst Schleife mit `WeaponService.Changed`).
- Beute testen (B6): Debug-Knöpfe „Spawn a looter", „Spawn a tree", „Drop a crate". Ende-zu-Ende-Tests in `tests/Loot.spec.luau`, Formeln in `tests/LootRules.spec.luau`. `tests/Smoke.spec.luau` schaltet zufällige Früchte/Kisten mit `LootService.setDropsPaused(true)` ab, sonst öffnen sich Kisten vor den Level-up-Karten und die Smoke-Tests werden zufällig rot.
- Items testen (B8): Ende-zu-Ende-Tests und Regeln in `tests/ItemsB8.spec.luau`; Debug-Knopf „Next new item" gibt die Items des neuesten Item-Pakets der Reihe nach (`Config/Admin.luau` → `newItems`). Brotatos Item-Wiki (`brotato.wiki.spellsandguns.com/Items`) ist zu lang für einen Abruf: der Text bricht bei „Incendiary Turret" ab, Items ab „I" einzeln abrufen.

## Code-Landkarte

- `src/shared/Config/*` – alle Zahlen (Run/Wellen, Shop, Items, Stats, Weapons, WeaponClasses, Combat, Evolutions, Enemies, Player …).
- `src/shared/Net/Remotes.luau` – jede Remote mit Rate-Limit und Validierung; Payload-Typen in `Net/Types.luau`.
- Server `src/server/Services/`: `RunDirector` (Ablauf, Phasen), `SpawnDirector` + `EnemySim` (Gegner als Daten), `WeaponService/Arsenal` (Waffen, Stufen, Verschmelzen, Explosionen, Abprallen), `WeaponService/WeaponStats` (Waffenwerte aus Spielerwerten), `WeaponService/Afflictions` (Brennen), `ShopService/ShopRules` (Shop-Formeln), `StatService` (Werte, Items; dauerhafte + bedingte Werte), `EffectService/EffectRules` (Item-Effekte, Ereignisse), `RandomService/Streams` (Seed, Zufalls-Ströme), `UpgradeService` (Werte-Karten, Truhen-Inhalt), `LootService` (Truhen), `ExperienceService` (XP, Team-Level), `CombatService` (HP, Dash), `AdminService` (Debug-Knöpfe).
- Client `src/client/Controllers/`: `ShopController`, `LevelUpController`, `StatsController`, `HUDController` (auch Bonus-Zeilen über der HP), `ProcTextController` (schwebende Effekt-Texte), `EnemyRenderer`, `WeaponRenderer` …
- Texte aus der Config: `Util/UpgradeText` (Karten, Items, Waffen-Schaden), `Util/EffectText` (Effekt-Zeilen, Bonus- und Auszahlungs-Texte), `Util/WeaponClasses` (Klassen zählen, Boni, Namen).
- Gegner-Snapshot: 10 Bytes pro Gegner, Byte 9 = Status (brennt/verlangsamt) für die Färbung im `EnemyRenderer`.
- Reine Regeln (Formeln) liegen in Untermodulen (`ShopRules`, `RunFlow`, `SpawnRules`, `WeaponStats`, `Afflictions`, `Util/WeaponClasses`, `UpgradePool`, `EffectRules`, `Streams`, `Util/StatMath`, `Util/RunSchedule`) und haben Unit-Tests in `tests/`.
- Beute (B6): `Config/Loot.luau` (alle Zahlen), `Util/LootRules` (Formeln), `ExperienceService` (Drop-Chance der Orbs, Beutel, Remote `OrbBag`), `LootService` (Elite-Truhen, Früchte und Kisten am Boden, Remote `Pickups`), `UpgradeService` (Kisten-Wahl vor den Karten, Remotes `CrateOffer`/`ChooseCrate`), `SpawnDirector` (Plünderer, Bäume), `EnemySim/World` (`flee`, `anchored`, `remove`). Client: `PickupRenderer` (Früchte, Kisten, Beutel-Anzeige), `LevelUpController` (Kisten-Panel).
