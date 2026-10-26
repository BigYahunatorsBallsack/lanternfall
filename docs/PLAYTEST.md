# Playtest mit Freunden (Paket 7)

Ziel laut DESIGN.md: **Spaß-Check mit 3–5 Freunden.** Bestanden, wenn mindestens 3 von 5 freiwillig einen zweiten Run starten.

## 1. Vorbereiten (einmalig, ca. 15 Min)

1. Code aus dem Paket-7-Branch holen und wie gewohnt per Rojo in Studio laden.
2. In Studio: **Datei → Bei Roblox veröffentlichen** (bzw. „Publish to Roblox"). Beim ersten Mal ein neues Spiel anlegen, Name z. B. „Lanternfall Test". Das ist die **Test-Experience**, nicht das spätere Live-Spiel.
3. Freunde einladen (bis zu 10 „Early Testers", das Spiel braucht dafür noch keine Altersfreigabe):
   - in Studio **Datei → Invite early testers** (Frühe Tester einladen), Freunde suchen, **Invite**; oder
   - oben rechts **Collaborate** → Tab **Early testers** → Freunde hinzufügen → **Save**.
   - Die Freunde bekommen eine Benachrichtigung. Mit **Copy game link** kannst du ihnen den Link auch selbst schicken.
   - Kommt jemand nicht rein: meist fehlt der Alters-Check im Roblox-Konto, die Altersgruppen liegen zu weit auseinander (dann als „Trusted Friend" hinzufügen) oder die Einstellung „Preview" ist bei ihm aus.
4. Roblox stellt diese Menüs gerade um; heißen sie bei dir anders, findest du sie im Creator Hub unter **Configure → Permissions** bzw. **Manage access**.

Hinweis: Nach jeder Code-Änderung musst du in Studio erneut veröffentlichen, sonst spielen die Freunde die alte Version.

## 2. Der Testabend (ca. 1–2 Std)

1. Du startest das Spiel zuerst über die Roblox-App (nicht Studio). Die Freunde treten dir bei (Profil → **Beitreten**) oder nutzen den Link.
2. Höchstens 4 spielen gleichzeitig einen Run, ein fünfter wartet in der Lobby und ist beim nächsten Run dabei.
3. **Nichts erklären** außer „WASD/Stick laufen, Leertaste/Knopf = Dash". Genau beobachten, was unklar ist.
4. Mindestens: ein Run solo pro Person (wer will), dann Runs zu zweit bis zu viert. Beide Klassen ausprobieren lassen.
5. Du siehst als Besitzer das Debug-Panel. Bitte im Test **nicht** benutzen, sonst stimmen die Zahlen nicht.
6. Nach jedem Run: **F9** drücken (Developer Console) → oben **Server** wählen → den Block zwischen
   `===== Run summary` und `=====` markieren und in eine Textdatei kopieren. Er enthält Dauer, Team-Level pro Minute, Kills, Schaden, Waffen und Passive jedes Spielers.

Gut zu wissen für den Prototyp: Es gibt noch keinen Boss (12:00 zählt als Sieg), keine Elites, keinen Swarm Rush, Spitter schießen noch nicht, Wiederbeleben fehlt (wer down ist, bleibt down bis zum Run-Ende) und nichts wird gespeichert.

## 3. Fragebogen (direkt nach dem Spielen, 2 Minuten)

1. Wie viel Spaß hat es gemacht? (1–5)
2. Würdest du jetzt noch einen Run spielen? (ja/nein) – und hat die Person es *ohne Nachfrage* getan?
3. Wann war es zu leicht oder zu schwer? (Minute ungefähr)
4. Welche Waffe hat sich am besten angefühlt, welche am schlechtesten? Warum?
5. Orbit Blades: Reichen die Klingen weit genug? Drehen sie zu langsam/zu schnell?
6. Spark Bolt: Fliegen die Blitze zu langsam? Treffen sie, wo du es erwartest?
7. Shockwave: Ist der Rückstoß zu schwach, zu stark, genau richtig?
8. Waren die Level-up-Karten verständlich? Kam zu oft/zu selten eine Karte?
9. Was hat genervt oder war unklar?

Schick mir danach die Antworten und die kopierten Run-Zusammenfassungen, dann passe ich die Werte an.

## 4. Stellschrauben (wenn du selbst schnell etwas ändern willst)

Alle Zahlen stehen in `src/shared/Config/`. Datei in VS Code öffnen, Zahl ändern, speichern; Rojo überträgt sie sofort nach Studio. Danach neu veröffentlichen. Immer nur eine Sache auf einmal ändern.

| Problem | Datei → Wert | Jetzt | Richtung |
| --- | --- | --- | --- |
| Insgesamt zu schwer/zu leicht | `Run.luau` → `spawn.baseRate` | 1.5 | kleiner = weniger Gegner |
| Wird später zu schnell zu voll | `Run.luau` → `spawn.ratePerMinute` | 0.55 | kleiner = langsamer steigend |
| Gegner halten später zu viel aus | `Run.luau` → `spawn.hpPerMinute` | 0.15 | kleiner = weniger HP |
| Man stirbt zu schnell im Pulk | `Player.luau` → `hitInvulnerability` | 0.5 | größer = mehr Schutz nach Treffer |
| Level-ups zu selten | `Run.luau` → `xpCurve.coefficient` | 2.4 | kleiner = schneller Level |
| XP einsammeln nervt | `Player.luau` → `pickupRadius` | 8 | größer = weiter einsammeln |
| Klingen zu kurz | `Weapons.luau` → Orbit Blades `radius` | 7 | größer = längere Klingen |
| Klingen zu langsam | `Weapons.luau` → Orbit Blades `rotationSpeed` | 240 | größer = schneller |
| Blitze zu langsam | `Weapons.luau` → Spark Bolt `projectileSpeed` | 60 | größer = schneller |
| Rückstoß zu schwach | `Weapons.luau` → Shockwave `knockback` | 3 | größer = weiter weg |
| Brutes zu gefährlich | `Enemies.luau` → Brute `contactDamage` | 12 | kleiner = weniger Schaden |

## 5. Für Entwickler: Balance-Simulation

`tests/balance/BalanceSim.luau` spielt ganze Runs ohne Studio mit Computer-Spielern (stehen bleiben, ausweichen, im Kreis laufen, auf Abstand kämpfen) und druckt, wann sie sterben und welches Level sie erreichen:

```text
cargo run --release --manifest-path tools/luau-test-runner/Cargo.toml -- . tests/balance/BalanceSim.luau
```

Die Ergebnisse vom Stand Paket 7 stehen in DESIGN.md Abschnitt 9.
