# Parallel-Arbeit: Claude und ChatGPT

Stand 30.10.2026. Ab B6 arbeiten zwei KIs gleichzeitig am Repo: **Claude (Strang A)** und **ChatGPT (Strang B)**. Diese Datei regelt, wer was baut, welche Dateien wem gehören und wie gemerged wird, damit es keine Konflikte gibt. Sie gilt für beide KIs zusätzlich zu `CLAUDE.md` (bzw. `AGENTS.md`).

## 1. Wer macht was (Empfehlung nach Stärken)

Beide schreiben guten Luau-Code. Der echte Unterschied in diesem Projekt ist der **Kontext**:

- **Claude** kennt das Projekt seit WP1 (Projekt-Gedächtnis, alle Pakete B1–B5 gebaut) und ist stark bei großen, zusammenhängenden Umbauten über viele Dateien, bei Server-Simulation, Netzwerk-Format und Performance. → **Strang A: Engine und Ablauf** – Beute, Gegner, Boss, Gefahrenstufen. Später auch alle Extra-high-Pakete (Speichern, Teleport, Käufe, Performance, Sicherheit).
- **ChatGPT** startet jede Session nur mit dem Repo, ohne Projekt-Gedächtnis. Am besten passen klar umrissene Pakete, die einem vorhandenen Muster folgen und viele Daten brauchen: neue Waffen (Config-Datensatz + Verhaltensmodul nach Vorbild), Items (Config-Datensätze, Zahlen aus dem Brotato-Wiki), danach Charaktere und Bauten. → **Strang B: Inhalte und Spieler-Regeln.**
- **Gegenseitiges Review:** Bevor der Owner einen PR merged, kann er die andere KI kurz drüberschauen lassen („Prüfe PR #X gegen CLAUDE.md und docs/PARALLEL.md"). Kostet wenig, fängt Regelverstöße (Server-Autorität, Zahlen im Code, fremde Dateien).

## 2. Reihenfolge in Runden

Pro Runde baut jeder Strang **ein** Paket. Eine Runde ist vorbei, wenn beide PRs gemerged sind (oder einer bewusst wartet).

| Runde | Strang A – Claude | Strang B – ChatGPT | Abhängigkeit |
| --- | --- | --- | --- |
| 1 | **B6** Beute (High) | **B7** Waffen (Medium) | keine, kann sofort parallel |
| 2 | **B9** Gegner (Extra high) **und B8** Items (Medium) | – | B8 startet erst, wenn B6 gemerged ist (Items für Früchte, Kisten, Beutel brauchen dessen Ereignisse). Items, die B9-Gegner brauchen, kommen in Runde 3 nach. **Owner 30.10.2026:** B8 macht Claude (Strang A), weil ChatGPT wenig Limit hat. |
| 3 | **WP10** Boss + Elite-Phasen (High) | **B10** Charaktere (High) | WP10 braucht B9. B10 braucht B7 (Startwaffen) und B8. |
| 4 | **B11** Gefahrenstufen (High) | **B12** Bauten + Begleiter (High) | B11 startet erst, wenn B10 gemerged ist (beide ändern die Lobby). |

Danach (Pakete 11–26): Extra-high-Pakete an Claude (12 Speichern, 15 Teleport, 16 Käufe, 22 Performance, 23 Sicherheit), Medium-Pakete mit klarem Umfang an ChatGPT (13 Fortschritt, 14 HUD/Tooltips, 17 Shop-UI, 18 Quests, 20 Analytics). Die Zuteilung legt der Owner pro Runde fest und trägt sie hier ein.

**Owner 31.10.2026:** Claude baut alle Pakete ab 13 (auch die oben ChatGPT zugedachten), nur B12 bleibt bei ChatGPT. Reihenfolge und Effort: `STATUS.md` → „Plan bis zum Launch“. Ist Claudes Limit leer, übernimmt ChatGPT das nächste offene Paket dieser Liste.

## 3. Wem welche Dateien gehören

Jede Datei hat **einen** Besitzer-Strang. Nur der Besitzer ändert sie. Braucht der andere Strang dort etwas, schreibt er es unter „Wunsch an den anderen Strang" in seinen PR, statt die Datei anzufassen.

**Strang A – Claude** (Gegner, Beute, Ablauf, Spieler-HP)

- Server: `EnemySim/*`, `SpawnDirector/*`, `LootService`, `ExperienceService/*`, `RunDirector/*`, `RandomService/*`, `CombatService/*`, `UpgradeService/*`, `MapService`, `RunStatsService/*`, `PlayerDataService/*`, neue Dienste für Beute, Boss und Gefahrenstufen
- Client: `EnemyRenderer/*`, `EnemyShotRenderer`, `XpOrbRenderer`, `ChestController`, `LevelUpController`, `RunStateController`, `ResultsController`, `CameraController`, `InputController`, `PlayerStateController`, neue Beute-/Boss-Renderer
- Shared: `Config/Enemies`, `Run`, `Economy`, `Difficulty`, `Simulation`, `Map`, `Player`, `Camera`; `Net/Snapshot`, `Net/HitNumbers`; `Util/EnemyKinds`, `RunSchedule`, `SpatialHash`
- Tests: die Specs zu diesen Modulen, `tests/balance/*`

**Strang B – ChatGPT** (Waffen, Items, Werte, Shop, Charaktere, Bauten)

- Server: `WeaponService/*` (inkl. `Behaviors/*`), `StatService`, `ShopService/*`, `EffectService/*`, neuer `StructureService` (B12)
- Client: `WeaponRenderer/*` (inkl. `Visuals/*`), `ShopController`, `StatsController`, `LoadoutController`, `ProcTextController`, `DamageNumberController`, neue Bau-/Pet-Renderer
- Shared: `Config/Weapons`, `WeaponClasses`, `Evolutions`, `Combat`, `Items`, `Effects`, `Classes` (wird in B10 zu den Charakteren), `Shop`, `Talents`, `Stats`; `Util/UpgradeText`, `EffectText`, `WeaponClasses`, `StatMath`, `Orbit`
- Tests: die Specs zu diesen Modulen

**Geteilt – nur anhängen** (beide dürfen, aber nur **am Ende** des passenden Blocks etwas ergänzen; nichts umsortieren, umbenennen, umformatieren oder löschen):

- `Config/Stats.luau` (neue Werte-Ids, z. B. Frucht-Heilung in B6; Besitzer B, A darf anhängen)
- `Config/Effects.luau` + `EffectService` (neue Ereignisse, z. B. „Frucht aufgehoben" in B6; Besitzer B, A darf ein Ereignis anhängen und es im Dienst auslösen)
- `Net/Remotes.luau`, `Net/Types.luau`, `Net/DebugCommands.luau`, `Config/Admin.luau`, `AdminService` (neue Remotes und Debug-Knöpfe)
- `Config/init.luau`, `server/ConfigCheck.luau`, `server/init.server.luau`, `client/init.client.luau` (neue Module eintragen)
- `HUDController`, `LobbyController` (B10 Charakterwahl, B11 Gefahrenstufe), `UI/*`, `Vfx/*`, `tests/helpers/RobloxMock.luau`
- `STATUS.md`, `DESIGN.md` (siehe Abschnitt 5)

**Ausnahme B8 (30.10.2026):** B8 hat Claude statt ChatGPT gebaut (PR #22, gemerged). Die Item-Dateien gehören weiter Strang B.

**Ausnahme B10:** Die Charaktere ersetzen die Klassen. B10 darf deshalb in `RunDirector`, `RunStatsService` und `PlayerDataService` genau die Stellen anpassen, die `Config.Classes` lesen, und nennt sie im PR unter „Neue Schnittstellen".

**Tests:** Neue Ende-zu-Ende-Tests kommen in **eigene** Dateien (`tests/Loot.spec.luau`, `tests/WeaponsB7.spec.luau` …), nicht in `tests/Smoke.spec.luau`.

**Verboten für beide:** Dateien des anderen Strangs ändern, Dateien verschieben oder umbenennen, StyLua über das ganze Repo laufen lassen und dabei fremde Dateien ändern (nur eigene geänderte Dateien formatieren), Formate ändern, die der andere liest (Snapshot-Bytes, Remote-Argumente, Config-Felder), ohne es im PR als Schnittstelle zu nennen.

## 4. Branches, PRs und Merge

1. **Start:** immer vom aktuellen `main`. Branch `wp-<nr>-<kurzname>` (z. B. `wp-b6-loot`, `wp-b7-weapons`).
2. **PR-Titel** beginnt mit dem Strang: `[Claude] B6 Beute`, `[ChatGPT] B7 Waffen`. Pro Strang höchstens **ein** offener PR.
3. **PR-Text** = Übergabe-Vorlage (Abschnitt 6, auch in `.github/pull_request_template.md`).
4. **Nur der Owner merged**, und immer nur einen PR auf einmal.
5. **Nach jedem Merge** muss der andere offene PR `main` aufnehmen: Owner klickt auf GitHub im PR „Update branch", oder bittet die KI: „Nimm main in deinen Branch auf und lass die Tests laufen." Erst danach merge-bereit.
6. **Konflikt?** Löst die KI, deren PR später gemerged wird. In geteilten Dateien bleiben beide Seiten erhalten. Nie `main` force-pushen, nie den Branch des anderen Strangs ändern.
7. **Testen:** Der Owner testet einen Branch nach dem anderen (ZIP-Link pro Branch). Wer zusammen testen will: zuerst einen PR mergen, dann den anderen nach „Update branch".

## 5. STATUS.md und DESIGN.md ohne Konflikte

- `STATUS.md` hat oben die Tabelle **„Stränge"** mit einer Zeile pro Strang. Jeder ändert nur **seine** Zeile und hängt in den übrigen Abschnitten (Entscheidungen, Werkzeuge, Code-Landkarte) nur neue Punkte unten an.
- `DESIGN.md`: Jeder ändert nur die Abschnitte seines Pakets (Strang A: 3, 7, 9, 10; Strang B: 4, 5, 6) und in Abschnitt 20 nur die Zeilen seiner Pakete.

## 6. Übergabe-Vorlage (PR-Text, Pflicht für beide)

```markdown
## [Strang] Paket – Kurzname

**Was gebaut wurde (2–4 Sätze, Deutsch):** …

**Geteilte Dateien, die ich angefasst habe (nur angehängt):** `Config/Stats.luau` (+ `fruitHeal`) …

**Neue Schnittstellen für den anderen Strang:** neue Ereignisse, Werte-Ids, Config-Felder, Funktionen, Remotes – mit Datei und einem Satz Bedeutung. „Keine", wenn keine.

**Wunsch an den anderen Strang:** Was dort geändert werden müsste (Datei, was, warum). „Keiner", wenn keiner.

**Checks:** StyLua ✅/❌ · Selene ✅/❌ · Tests (`tests/…spec.luau`) ✅/❌ · Was ich nicht prüfen konnte: …

**Testanleitung für den Owner (Deutsch, nummeriert, Klick für Klick):**
1. …

**Offene Punkte / Annahmen:** …
```

## 7. Start-Text für eine neue Session

Der Owner kopiert das in eine neue Claude- bzw. ChatGPT-Session (Paket und Strang anpassen):

> Lies `AGENTS.md` (ChatGPT) bzw. `CLAUDE.md` (Claude), dann `STATUS.md` und `docs/PARALLEL.md`. Du bist **Strang B** und baust **Paket B7** aus `DESIGN.md` Abschnitt 20. Ändere nur Dateien deines Strangs, geteilte Dateien nur anhängen. Branch `wp-b7-weapons` von `main`, PR nach `main` mit der Übergabe-Vorlage. Antworte mir auf Deutsch, kurz.
