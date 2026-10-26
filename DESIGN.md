# Lanternfall – Game Design Document

Stand: 26.10.2026 · Quelle: claude.ai-Doc „Lanternfall – Game Design Document" (Original mit Diagrammen). Diese Datei ist die Arbeitskopie im Repo; Änderungen am Design hier pflegen.

## 1. Überblick & Vision

Lanternfall ist ein Koop-Survivors für 1–4 Spieler: 12-Minuten-Runs gegen Schattenhorden, Waffen feuern automatisch, bei jedem Level-up wählst du 1 aus 3 Upgrades, am Ende wartet ein Boss.

| Punkt | Festlegung |
| --- | --- |
| Arbeitstitel | Lanternfall; Roblox-Titel beschreibend, z. B. „Lanternfall: Horde Survivors" |
| Genre | Koop-Survivors/Roguelite nach dem Prinzip von Vampire Survivors und Megabonk |
| Spieler | 1–4 pro Run, Hub-Lobby mit bis zu 24 |
| Session | Run 12 Min + Boss (≈ 14 Min), Ziel ≥ 20 Min pro Session |
| Zielgruppe | zuerst 16+ (so startet jedes neue Spiel), danach alle ab 9 |
| Plattform | Mobile first; PC und Konsole laufen mit |
| Content-Rating | Ziel „Mild": Fantasy-Gewalt ohne Blut |
| Sprache im Spiel | Englisch; Roblox übersetzt automatisch |

**Setting:** Die Welt versinkt im „Gloom". Die Spieler sind Laternenträger und müssen bis zum Morgengrauen durchhalten. Licht steht für Spieler, Dunkelheit für Gegner – so ist jedes Bild sofort lesbar.

**Was es anders macht**

- Koop statt Solo: Survivors-Gefühl mit Freunden, gegenseitiges Wiederbeleben, gemeinsame Bosse.
- Jeder Run ist anders: Waffen und Passive kombinieren sich zu Evolutionen.
- Mobile-tauglich: nur Bewegen und Dash, alles andere passiert automatisch.

**Designprinzipien**

1. In 30 Sekunden verstanden, ohne Text.
2. Jede Minute eine Entscheidung.
3. Alles, was Wert hat, entscheidet der Server.
4. Bezahlen kauft Komfort und Look, nie Vorteile gegen andere (es gibt kein PvP).
5. Erst Spaß beweisen, dann Content bauen.

**Bewusst nicht drin:** Brainrot-Memes, Rebirths, Trading, PvP, Social-Hangout-Features.

## 2. Warum dieses Spiel, warum jetzt

Das Genre ist außerhalb von Roblox bewiesen, auf Roblox kaum besetzt – und Roblox belohnt 2026 genau diese Art Spiel.

- **Nachfrage bewiesen:** Megabonk (Sept. 2025) verkaufte über 1 Mio. Kopien in zwei Wochen, Spitze 117.336 gleichzeitige Spieler auf Steam.
- **Lücke auf Roblox:** Robong: Megabonk steht nach knapp einem Jahr bei rund 1,0 Mio. Visits – Roblox-Hits haben Milliarden.
- **Das Fenster schließt sich:** Jollywise Media baut mit Förderung des UK Games Fund ein Koop-Survivors speziell für Roblox.
- **Plattform-Kurs:** Neue Spiele laufen zuerst nur für altersgeprüfte 16+; unter 16 erst nach 250 Unique Plays von „highly engaged" Spielern in 60 Tagen plus Safety Review.
- **Mehr Geld pro 18+-Spieler:** Ausgaben altersgeprüfter US-18+-Spieler bringen 0,54 $ statt 0,38 $ pro 100 Robux, wenn das Spiel R15-Avatare nutzt.
- **Discovery belohnt Retention:** Roblox will Langzeit-Retention stärker gewichten – Run-Spiele mit Meta-Progression sind dafür gebaut.
- **Gegenbeispiel Viral-Loop:** Steal A Car (Sept. 2026) peakte bei 31K Spielern und liegt jetzt bei rund 2K.

## 3. Core Loop & Run-Ablauf

Zwei Schleifen tragen das Spiel: im Run wird man jede Minute durch Level-ups stärker, zwischen den Runs dauerhaft durch Embers.

```text
Hub-Lobby → Run startet → Überleben & XP ⇄ Level-up: 1 aus 3
                              │ Minute 12          │ alle down (Scheitern)
                              ▼                    ▼
                        Boss bei 12:00 ──Sieg──→ Run-Ende (Embers, „Nochmal")
                                                   │
Hub-Lobby ←──── nächster Run ──── Talente & Klassen ←┘
```

Sind alle gleichzeitig down, endet der Run sofort – Embers gibt es trotzdem für die überlebte Zeit.

| Minute | Was passiert |
| --- | --- |
| 0:00 | Start mit der Klassen-Waffe, nur Shadelings, Level-ups alle paar Sekunden |
| 2:00 | Brutes kommen dazu, erste Elite mit Truhe (danach alle 2 Min) |
| 4:00 | Spitter kommen dazu, volle Gegnermischung |
| 5:00 | Swarm Rush: 30 s doppelte Spawnrate |
| 6:00–8:00 | Builds stehen, erste Evolutionen aus Elite-Truhen möglich |
| 9:00 | zweiter Swarm Rush |
| 10:00 | Gegner mit 2,5-facher HP, Level-ups etwa alle 15–20 s |
| 12:00 | Boss The Lantern Eater erscheint, normales Spawnen stoppt |
| ≈ 14:00 | Run-Ende: Statistik, Embers, „Nochmal" |

**Run-Ablauf im Prototyp** (Lobby und Arena im selben Server, Werte in `Config/Run.luau` → `flow`):

1. **Lobby:** Klasse wählen, „Ready" drücken. Wer bereit ist, kommt in den nächsten Run (max. 4).
2. **Countdown:** startet mit dem ersten bereiten Spieler, 10 s; sind alle im Server bereit, sofort auf 3 s verkürzt. Bricht ab, wenn niemand mehr bereit ist.
3. **Run:** alle Bereiten werden in die Arena gesetzt, Timer zählt ab 0:00 hoch. Wer später kommt oder nicht bereit war, wartet in der Lobby und kann sich schon für den nächsten Run bereit melden.
4. **12:00 = Boss-Phase.** Bis der Boss da ist (Paket 10), zählt das Erreichen von 12:00 als Sieg.
5. **Ende:** Sieg (Boss besiegt), Niederlage (niemand mehr „Alive", also alle down) oder abgebrochen (alle haben den Server verlassen, dann direkt zurück in die Lobby).
6. **Ergebnis:** 15 s Ergebnis-Bildschirm mit „Play again"; drücken alle Teilnehmer „Play again", geht es sofort weiter. Danach zurück in die Lobby, wer „Play again" gedrückt hat, startet direkt den nächsten Countdown.

## 4. Steuerung & Spieler-Grundwerte

Spieler steuern nur Bewegung und einen Dash; Angreifen, Zielen und Aufsammeln passiert automatisch.

- **Mobile:** virtueller Stick links, Dash-Button rechts. **PC:** WASD + Leertaste. **Konsole:** linker Stick + A.
- **Kamera:** feste Top-down-Kamera (etwa 60° schräg, fester Zoom). Bewusst nicht wie Megabonk (Third-Person hinter der Figur, drehbar): Waffen zielen automatisch, man soll die Traube rundherum sehen, und am Handy reicht ein Daumen (Entscheidung des Owners, Paket 4). Die Kamera steht südlich der Figur und schaut nach Norden, W/Stick nach oben läuft also immer bildschirm-aufwärts.
- **Zielen:** jede Waffe hat eine feste Zielregel (nächster Gegner, zufälliger Gegner, um den Spieler herum).
- **Charakter:** Roblox-R15-Avatar mit Klassen-Kostüm darüber (Abschnitt 14).

| Wert | Startwert | Anmerkung |
| --- | --- | --- |
| Leben (HP) | 100 | Klassen und Passive erhöhen es |
| Lauftempo | 16 Studs/s | Roblox-Standard |
| Dash | 12 Studs, 6 s Cooldown | 0,3 s unverwundbar |
| Aufsammelradius | 8 Studs | XP-Orbs, Heilung, Embers |
| Rüstung | 0 | zieht pro Treffer flach ab, mindestens 1 Schaden |
| Regeneration | 0 HP/s | nur über spätere Passive |
| Schutz nach Treffer | 0,5 s | verhindert Sofort-Tod im Pulk |
| Krit-Chance | 5 % | Krit = doppelter Schaden |

Seit Paket 4 umgesetzt (Werte in `Config/Player.luau` und `Config/Camera.luau`): Kamera 60° Neigung, 70 Studs Abstand, Sichtfeld 40°, folgt weich. Springen ist aus; Leertaste, Gamepad-A und ein runder Dash-Knopf unten rechts lösen den Dash aus (am Handy größer). Der Dash schiebt die Figur in 0,15 s 12 Studs in Laufrichtung (im Stand in Blickrichtung); Wände und Ruinen stoppen ihn. Der Knopf zeigt den Cooldown als dunkle Füllung. Wer „down" ist, kann nicht laufen und nicht dashen. Klassenbonus auf HP wird beim Run-Start eingerechnet (Blade Warden 120 HP). Im HUD unten Mitte die eigene HP-Leiste (rot unter 30 %), kurzer roter Bildschirm-Blitz bei Treffern, HP der Mitspieler in der Team-Liste.

Alle Werte stehen in Config-Modulen, nicht im Code.

## 5. Klassen

v1 startet mit zwei kostenlosen Klassen; ab Live-Ops kommt alle 3–4 Wochen eine neue, freischaltbar mit Embers oder per Game Pass.

| Klasse | Startwaffe | Klassen-Bonus | Spielgefühl | Verfügbar |
| --- | --- | --- | --- | --- |
| Blade Warden | Orbit Blades | +20 % max. HP | Nahkampf, mitten rein | v1, gratis |
| Spark Mage | Spark Bolt | −10 % Waffen-Cooldown | Fernkampf, ausweichen | v1, gratis |
| Lantern Keeper | Lantern Pulse (heilt Team im Radius) | +25 % Wiederbelebungstempo | Support im Koop | Live-Ops, 2.500 Embers oder Pass |
| Trapper | Thorn Trail | +15 % Wirkungsfläche | Zonen kontrollieren | Live-Ops, 2.500 Embers oder Pass |

Jede Klasse: eine Startwaffe, ein passiver Bonus, ein eigenes Kostüm. Keine eigenen Skill-Bäume in v1.

## 6. Waffen, Passive & Evolutionen

v1 hat 6 Waffen, 6 Passive und 2 Evolutionen; jeder Spieler trägt bis zu 4 Waffen und 4 Passive, jedes Item steigt bis Level 5.

**Waffen (Startwerte Level 1)**

| Waffe | Verhalten | Schaden | Cooldown | Pro Level bis L5 |
| --- | --- | --- | --- | --- |
| Orbit Blades | 2 Klingen kreisen um dich, Radius 7 Studs | 12 pro Treffer | dauerhaft, 0,5 s pro Gegner | +1 Klinge auf L3 und L5, sonst +15 % Schaden |
| Spark Bolt | Projektil auf nächsten Gegner, durchbohrt 1 | 15 | 0,9 s | +1 Projektil auf L2 und L4, sonst +20 % Schaden |
| Shockwave | Druckwelle um dich, Radius 10 Studs | 20 | 3,0 s | +2 Studs Radius und −0,3 s |
| Chain Lightning | Blitz springt über 3 Gegner | 18 | 2,0 s | +1 Sprung und +15 % Schaden |
| Thorn Trail | Dornenspur hinter dir, liegt 2 s | 8 pro 0,5 s | dauerhaft | +0,5 s Dauer und +20 % Schaden |
| Boomerang Axe | fliegt raus und zurück, durchbohrt alles | 25 | 1,6 s | +1 Axt auf L3 und L5, sonst +15 % Schaden |

**Passive**

| Passiv | Effekt pro Level |
| --- | --- |
| Vitality | +15 % max. HP |
| Haste | +8 % Lauftempo |
| Focus | −8 % Cooldown aller Waffen |
| Magnet | +30 % Aufsammelradius |
| Might | +10 % Schaden |
| Armor | +1 Rüstung |

**Evolutionen** – nur aus Elite- oder Boss-Truhen, wenn die Voraussetzung erfüllt ist:

| Evolution | Voraussetzung | Effekt |
| --- | --- | --- |
| Blade Storm | Orbit Blades L5 + Armor (beliebiges Level) | 8 Klingen, Radius 10, doppelter Schaden |
| Starfire | Spark Bolt L5 + Focus (beliebiges Level) | Projektile explodieren mit Radius 6 Studs |

Werte, die hier noch fehlen (Projektil-Tempo und Reichweite von Spark Bolt und Boomerang Axe, Sprungweite von Chain Lightning, Drehtempo der Orbit Blades), stehen als Annahme in `Config` und werden in Arbeitspaket 5 eingestellt. Kollisionsradius und Masse der Gegner stehen seit Paket 3 als Annahme in `Config/Enemies.luau`.

Jede Waffe = ein Datensatz im Config-Modul + ein kleines Verhaltens-Modul. Neue Waffe = neuer Datensatz + Verhalten, Framework bleibt unangetastet.

## 7. Gegner, Elites & Boss

| Gegner | Rolle | HP | Tempo (Studs/s) | Schaden | XP | Ab Minute |
| --- | --- | --- | --- | --- | --- | --- |
| Shadeling | Schwarm, läuft direkt auf dich zu | 10 | 14 | 5 pro Kontakt | 1 | 0 |
| Brute | Tank, langsam, schiebt den Pulk | 60 | 8 | 12 pro Kontakt | 4 | 2 |
| Spitter | hält 30 Studs Abstand, schießt alle 2,5 s | 20 | 10 | 8 pro Projektil | 2 | 4 |
| Gloom Elite | beliebiger Typ, leuchtet, 1,5× so groß | 8× | 0,9× | 1,5× | 25 + Truhe | alle 2 Min |
| The Lantern Eater | Boss | 4.000 × Spielerfaktor | 9 | siehe unten | – | 12:00 |

**Boss: The Lantern Eater**

1. **Bodenschlag:** roter Kreis, Radius 14 Studs, 1,2 s Vorwarnung, 35 Schaden.
2. **Ansturm:** rennt geradeaus; Linie 0,8 s vorher sichtbar, 30 Schaden.
3. **Schatten rufen:** beschwört alle 25 s 20 Shadelings.
4. **Phase 2 ab 50 % HP:** alle Angriffe 25 % schneller.

Sieg = Boss-Truhe (3 Upgrades für jeden Spieler) + 150 Embers, danach Run-Ende-Screen.

**Spawn-Director**

```text
Spawnrate (Gegner/s) = (1.5 + 0.55 · t) · fSpieler      t = Spielminute
fSpieler             = 1 + 0.6 · (n − 1)                 n = Spieler im Run → 1 / 1.6 / 2.2 / 2.8
Gegner-HP-Faktor     = 1 + 0.15 · t                      (Minute 10: 2.5×)
```

- Gleichzeitig maximal 80 Gegner + 20 pro weiterem Spieler (höchstens 140); beim Limit pausiert das Spawnen.
- Spawn-Ort: Ring 45–60 Studs um einen zufälligen Spieler, außerhalb der Sicht, nie in Hindernissen.
- Mischung: Minute 0–2 nur Shadelings; 2–4 zusätzlich 20 % Brutes; ab Minute 4 60 % Shadeling, 20 % Brute, 20 % Spitter.
- „Swarm Rush" bei Minute 5 und 9: 30 s doppelte Spawnrate, nur Shadelings.

**Stand im Code (seit Paket 3):** Der SpawnDirector kann Rate, Spielerfaktor, Obergrenze, Spawn-Ring, Mischung nach Minute und HP-Faktor (mal Schwierigkeit). Er spawnt nur in der Phase „Running", um einen zufälligen lebenden Teilnehmer, und rechnet n aus den Teilnehmern, die noch im Server sind. Swarm Rush, Elites und die Schüsse der Spitter folgen in Paket 9; Spitter halten aber schon ihren Abstand von 30 Studs.

## 8. Koop-Regeln

- **XP:** Jedes Orb zählt fürs ganze Team. XP-Bedarf pro Level × Spielerfaktor.
- **Level-up ohne Pause:** jeder Spieler eigene 3 Karten; während der Wahl unverwundbar und bewegungslos, Waffen feuern weiter; nach 10 s wird die erste Karte automatisch gewählt.
- **Truhen:** Elite-Truhe gibt jedem Spieler im Umkreis von 20 Studs eine eigene Belohnung.
- **Down & Wiederbeleben:** bei 0 HP „down" (30-s-Timer); Teammate steht 3 s daneben → Wiederbelebung mit 40 % HP. Timer abgelaufen → Zuschauer bis Run-Ende, Embers anteilig.
- **Run-Ende:** alle gleichzeitig down = Run vorbei.
- **Revive-Token (Kauf):** höchstens 1 pro Spieler und Run.
- **Ein-/Aussteigen:** kein Beitritt in laufende Runs (v1); wer geht, fällt raus, Spawn-Director rechnet ab nächstem Tick neu.
- **Solo:** jederzeit, Spielerfaktor 1. **Kein Friendly Fire, kein PvP.**

## 9. XP-Kurve, Level-ups & Balancing-Startwerte

```text
XP für Level L → L+1 = round((5 + 2.4 · L^1.3) · fSpieler)
```

Solo: L1→2 = 7 XP, L10→11 = 53 XP, L30→31 = 205 XP; bis Level 35 zusammen rund 3.800 XP. Ein Solo-Run spawnt bis Minute 12 rund 3.400 Gegner (Ø 1,4–1,6 XP); bei ~85 % eingesammelten Orbs reicht das für Level 34–36.

**Level-up-Karten:** 3 Karten aus allen Waffen/Passiven; vorhandene Items doppelt so wahrscheinlich; volle Slots → nur Upgrades; alles auf L5 → „+25 Embers" oder „30 % heilen"; 1 kostenloser Neuwurf pro Run.

| Balancing-Ziel | Wert |
| --- | --- |
| Spark Bolt tötet einen Shadeling | mit 1 Treffer |
| Erst-Runs, die Minute 8 erreichen | ≈ 60 % |
| Bosssieg in den ersten 3 Runs (Normal) | 25–35 % |
| Ohne Ausweichen tot ab Minute 3 | in unter 20 s |
| Run-Dauer inkl. Boss | ≈ 14 Min |

## 10. Meta-Progression & Schwierigkeitsgrade

**Embers verdienen** (ein Run bringt je nach Dauer etwa 100–350)

| Quelle | Embers |
| --- | --- |
| pro überlebter Minute | 10 |
| pro Elite | 15 |
| Boss besiegt | 150 |
| tägliche Quest | 50–100 |

**Talente** (alle zusammen ≈ 12.650 Embers, also 50–70 Runs)

| Talent | Effekt pro Rang | Ränge | Kosten pro Rang (Embers) |
| --- | --- | --- | --- |
| Toughness | +3 % max. HP | 5 | 100 / 200 / 400 / 700 / 1.000 |
| Power | +2 % Schaden | 5 | 100 / 200 / 400 / 700 / 1.000 |
| Reach | +5 % Aufsammelradius | 5 | 100 / 200 / 400 / 700 / 1.000 |
| Greed | +5 % Embers | 5 | 100 / 200 / 400 / 700 / 1.000 |
| Rescuer | +10 % Wiederbelebungstempo | 3 | 150 / 300 / 600 |
| Second Thoughts | +1 Neuwurf pro Run | 2 | 500 / 1.500 |

**Schwierigkeitsgrade**

| Stufe | Freischaltung | Gegner-HP | Gegner-Schaden | Embers |
| --- | --- | --- | --- | --- |
| Normal | von Anfang an | 1× | 1× | 1× |
| Hard | Boss auf Normal besiegt | 1,6× | 1,25× | 1,5× |
| Nightmare | Boss auf Hard besiegt | 2,5× | 1,5× | 2,2× |

Party spielt auf der Stufe des Party-Leiters; Mitspieler dürfen mit, auch ohne eigene Freischaltung.

## 11. Retention-Systeme

| System | Rhythmus | Inhalt | Phase |
| --- | --- | --- | --- |
| Tägliche Quests | täglich, 3 Stück | z. B. „800 Gegner töten", „10 Min mit Spark Mage überleben", „2 Teammates wiederbeleben" – je 50–100 Embers | MVP |
| Login-Serie | 7 Tage | Tag 7 = Kosmetik; verpasster Tag setzt nur 2 Tage zurück | MVP |
| Party-Bonus | jeder Run | +10 % Embers mit Freunden | MVP |
| Badges | dauerhaft | erster Bosssieg, 10.000 Kills, alle Evolutionen | MVP |
| Ranglisten | wöchentlich | pro Schwierigkeitsgrad: längste Zeit / meiste Kills; Freundesrangliste | MVP |
| Weekly Challenge | wöchentlich | fester Seed + Modifikator, eigene Rangliste | Live-Ops |
| Lantern Pass | 6-Wochen-Saison | Gratis- und Premium-Spur | Live-Ops |
| Gruppe & Codes | laufend | Gruppe beitreten = +5 % Embers; Codes bei Like-Meilensteinen | Soft Launch |

Bewusst nicht: harte Countdown-Angebote oder Serien, die bei einem verpassten Tag alles löschen.

## 12. Monetarisierung

| Produkt | Typ | Preis (Robux) | Inhalt | Phase |
| --- | --- | --- | --- | --- |
| VIP | Game Pass | 249 | VIP-Tag, exklusive Laterne und Trail, +1 Neuwurf pro Run, +10 % Embers | MVP |
| Double Embers | Game Pass | 399 | dauerhaft doppelte Embers | MVP |
| Klasse sofort | Game Pass je Klasse | 199 | Abkürzung zu 2.500 Embers | Live-Ops |
| Revive | Developer Product | 49 | sofort aufstehen, max. 1 pro Run | MVP |
| Reroll ×3 | Developer Product | 25 | 3 Neuwürfe | MVP |
| Embers-Pakete | Developer Product | 79 / 349 / 899 | 1.000 / 5.000 / 15.000 Embers | MVP |
| Server Ember Boost | Developer Product | 149 | 30 Min +50 % Embers für alle im Server, Käufer-Name angezeigt | MVP |
| Lantern Pass Premium | Developer Product pro Saison | 399 | Premium-Spur | Live-Ops |
| Kosmetik-Shop | Developer Products | 49–299 | Skins, Laternen, Trails, Kill-Effekte, Emotes; Direktkauf | Live-Ops |
| Private Server | Roblox-Funktion | z. B. 100/Monat | eigener Server | Soft Launch |
| Abo „Keeper+" | Robux-Abo | offen | tägliche Embers + monatlicher Skin | später |

**Regeln:** keine Lootboxen in v1; spätere Kisten mit Odds in % vor dem Kauf (Summe 100 %) und Behandlung von `ArePaidRandomItemsRestricted`; Avatar-Einstellung „R15 only" (18+-Rate gilt für Passes, Products, Abos, Private Server); keine Belohnung fürs Anschauen von Video-Feeds; Kaufknöpfe nie dort, wo man im Kampf versehentlich tippt.

## 13. UX/UI & Onboarding

- **Hub-Lobby:** Spawn, Run-Portale (Solo, Party, Quick Join), Talent-Altar, Klassen-Statuen, Shop-Stand, Ranglisten-Tafel.
- **HUD:** oben Team-XP-Leiste mit Level, Timer Mitte, Kills rechts; unten links HP, unten rechts Dash; Waffen/Passive oben links; Teammates außer Sicht als Randpfeile.
- **Level-up:** 3 große Karten (Icon, Name, eine Zeile Effekt, „NEW"/„LV 3"), daumentauglich.
- **Run-Ende:** Zeit, Kills, Schaden pro Waffe, Embers inkl. Boni, großer „Nochmal"-Knopf.
- **Shop, Talente, Pass:** je ein Fenster, max. 2 Taps bis Kauf.

**Erster Start (FTUE):** Erst-Join landet direkt in „First Night" (3-Min-Solo-Run, leichter) → Pfeil „Move" → erstes Level-up nach ~5 s mit „Pick one" → Minute 2 Mini-Elite mit Truhe → Minute 3 Run-Ende, dann Lobby mit Hinweis auf den Talent-Altar.

**Barrierefreiheit:** Bildschirmwackeln und Schadenszahlen abschaltbar; Gefahrzonen mit Farbe und Muster; Musik/Effekte getrennt regelbar.

## 14. Art-Direction & Audio

- Low-Poly, flache Materialien, wenige Texturen; Spieler/Laternen warm-gelb, Gegner violett-schwarz.
- Eigene Silhouette pro Gegnertyp; Gefahrzonen rot mit Streifenmuster.
- Avatare R15; Klassen = Kostüme über dem Avatar.
- Gegner ohne Humanoids: Meshes aus 2–4 Teilen, Bewegung per Code.
- Assets: Roblox-KI-Generierung und Creator Store, nur mit erlaubter Nutzung; keine fremden Marken/Figuren/Memes.
- VFX sparsam und gepoolt; Audio aus der Roblox-Bibliothek, eigener Boss-Track.
- **Map 1 „The Ruined City":** 300 × 300 Studs, flacher Boden, wenige große Ruinen, Nebelwand als Rand.

## 15. Technische Architektur

Der Server simuliert Gegner, Treffer und Belohnungen als reine Daten; Clients bekommen kompakte Snapshots und zeichnen nur.

```text
CLIENT (je Spieler)          NETZWERK                       SERVER (Run-Place)
InputController   ───────→  RemoteEvents (Absichten) ────→ RunDirector
EnemyRenderer     ←───────  Snapshots (unreliable, 15 Hz) ← EnemySim (Spatial Hash, 15 Hz)
HUD & UI          ←───────  State-Events (XP, HP, Karten) ← CombatService
VFX & Audio                                                 PlayerDataService (ProfileStore)
            ↑                                                        ↑
            └──────── Shared: Config-Module (Waffen, Gegner, Upgrades, Klassen) ────┘
```

**Places:** Prototyp = eine Place, max. 4 Spieler, Lobby + Arena im selben Server. Ab MVP = Hub-Place (bis 24) + Run-Place (max. 4), Wechsel per TeleportService mit reservierten Servern; Party und Schwierigkeit als Teleport-Daten.

**Ordnerstruktur (Rojo, `src/` → Studio)**

```text
src/shared/          → ReplicatedStorage.Shared
  Config/            Player, Weapons, Passives, Evolutions, Enemies, Classes, Run, Talents,
                     Economy, Difficulty, Simulation, Map, Admin, Camera
  Net/               Definition aller RemoteEvents und Snapshot-Format
  Util/              SpatialHash, Signal, Loader, Format
src/server/          → ServerScriptService.Server
  Services/          RunDirector, SpawnDirector (+ SpawnRules), EnemySim (+ World), CombatService, UpgradeService,
                     LootService, ReviveService, PlayerDataService, MonetizationService, AnalyticsService,
                     MapService (Platzhalter-Karte), AdminService (Test-Befehle)
src/client/          → StarterPlayer.StarterPlayerScripts.Client
  Controllers/       InputController, CameraController, PlayerStateController, EnemyRenderer (+ SnapshotBuffer, Models), HUDController, VFXController,
                     RunStateController, LobbyController, ResultsController, NotifyController, DebugController
  UI/                Theme, Widgets (UI im Code gebaut)
tests/               Unit-Tests für reine Module (Runner in tools/luau-test-runner)
```

**Gerüst (seit Arbeitspaket 2)**

- **Lebenszyklus:** Server- und Client-Bootstrap laden jedes Modul in `Services` bzw. `Controllers` über `Util/Loader`, alphabetisch. Oberste Ebene legt nur Zustand und Signals an, `init()` verbindet Remotes und Events (ohne zu warten), danach läuft `start()` je Modul in eigenem Thread. Module requiren sich direkt; RunDirector hängt nur von MapService und PlayerDataService ab, alle anderen hängen sich an RunDirector.
- **RunDirector** besitzt den Run-Ablauf (Regeln als reine Zustandsmaschine in `RunDirector/RunFlow.luau`, mit Unit-Tests). Signals für spätere Pakete: `RunStarted(players)`, `RunEnded(results)`, `PhaseChanged(phase, previous)`, `ParticipantStateChanged(player, state)`. Befehle: `setParticipantState` (ReviveService), `endRun("Victory")` und `setBossEncounter` (Boss), `getElapsed()` (SpawnDirector).
- **RunState:** Der Server schickt bei jeder Änderung den vollständigen, kleinen Zustand (`Net/Types.luau`) an alle; Timer laufen auf dem Client über `workspace:GetServerTimeNow()`, also kein Senden pro Sekunde. Ein neuer Client holt sich den Stand mit `RequestSync`.
- **Phasen:** Lobby → Countdown → Running → Boss → Ended → Lobby. Teilnehmer-Zustände: Alive, Down, Out.
- **Platzhalter-Karte:** MapService baut Lobby (80 × 80) und Arena (300 × 300, violette Nebelwand, 5 runde Platzhalter-Ruinen) beim Serverstart aus `Config/Map.luau`, auf Höhe 100 und abseits vom Standard-Baseplate. Die echte Karte folgt in Paket 21.

**Gegner-Engine** (seit Paket 3; Werte in `Config/Simulation.luau`)

- Server hält Gegner als Daten-Arrays (Position, HP, Typ), Schritt mit 15 Hz (`EnemySim/World.luau`, ohne Roblox-Objekte, mit Unit-Tests). Pro Schritt:
  1. Gegner, die seit dem letzten Schritt gestorben sind, entfernen.
  2. Auf den nächsten lebenden Spieler zusteuern (Spitter halten Abstand). Vor Hindernissen seitlich ausweichen; vor Nachbarn, die mindestens gleich schwer sind, höchstens bis zur Berührung vorrücken. So bildet sich eine ruhige Traube statt eines Knäuels; Brutes (Masse 6) schieben Shadelings (Masse 1) beiseite.
  3. Überlappungen in 3 Durchgängen auflösen, nach Masse verteilt.
  4. Gegner aus Hindernissen und Spielern schieben und in der Arena halten.
  5. Kontakte melden: pro Spieler und Schritt höchstens ein Signal mit dem höchsten Kontaktschaden.
     Geprüft wird dort, wo der Spieler auf seinem Bildschirm schon ist: Position + Geschwindigkeit × (0,15 s + Ping), höchstens 5 Studs voraus. Sonst treffen Gegner, die man noch gar nicht berührt sieht, weil der Client Gegner leicht verzögert zeigt und der Server den Spieler leicht verzögert sieht (Feedback des Owners, Paket 4). Spieler-Kreis 1,2 Studs, Kontakt-Zugabe 0,3 Studs.
- Spatial Hash (Rastergröße 8 Studs, `Util/SpatialHash.luau`) für Nachbarn und Treffer – keine Roblox-Physik, keine Raycasts pro Gegner.
- Hindernisse sind Kreise (`Config/Map.luau` → `arena.obstacles`); MapService baut dazu runde Säulen, an denen auch Spieler hängen bleiben.
- Gemessen im Test-Runner: 140 Gegner mit 4 Spielern ≈ 1–1,6 ms pro Schritt (Budget 4 ms).
- Waffentreffer und Projektile serverseitig als Daten gegen dasselbe Raster.
- Snapshots gebündelt per UnreliableRemoteEvent: 8 Byte pro Gegner (ID, Position, Typ, HP-Anteil) in einem `buffer`; bei 140 Gegnern und 15 Hz ≈ 17 KB/s pro Spieler. Gesendet wird nur an die Teilnehmer des Runs.
- Ein UnreliableRemoteEvent-Paket darf höchstens ~900 Byte haben: ein Tick wird gleichmäßig auf Pakete mit max. 90 Gegnern verteilt (8 Byte Kopf mit Tick, Teil, Teilanzahl und Gegnerzahl + 8 Byte pro Gegner, also höchstens 728 Byte). Der Client nutzt einen Tick erst, wenn alle Teile da sind; geht ein Paket verloren, fällt nur dieser Tick aus. Format in `src/shared/Net/Snapshot.luau`.
- Gegner-IDs (1–65535) werden reihum vergeben, eine frei gewordene ID kommt also erst nach Zehntausenden Spawns wieder.
- Clients (`EnemyRenderer`): Modell-Pool pro Gegnertyp, Interpolation zwischen zwei Ticks (~100 ms hinter dem neuesten; die Uhr gleicht unregelmäßige Ankunft weich aus), Positionen gesammelt per `workspace:BulkMoveTo`, kurzes weißes Aufblitzen bei Treffern. Platzhalter-Modelle aus 3–4 Teilen in der Größe des Kollisionskreises (`EnemyRenderer/Models.luau`), echte Modelle in Paket 21.
- Gegner-Teile verankert, ohne Kollision, ohne Schatten.

**Schnittstellen der Gegner-Engine für spätere Pakete**

- `EnemySim.spawn(enemyId, x, z, hpMultiplier, damageMultiplier)` – SpawnDirector, Boss (Paket 10).
- `EnemySim.damage(id, amount, player)`, `queryRadius(position, radius, out)`, `nearest(position, maxRange)`, `getPosition(id)`, `killAll()` – Waffen (Paket 5), Debug.
- Signal `EnemySim.EnemyKilled(info)` mit Typ, Position, XP und Killer – XP-Orbs (Paket 6), Truhen (Paket 9), Statistik.
- Signal `EnemySim.Contact(player, damage)` – Spieler-HP mit 0,5 s Schutz nach Treffer (seit Paket 4 über CombatService).

**Spieler** (seit Paket 4)

- **CombatService** (Server) hält HP, Rüstung, Schutzfenster und Dash-Cooldown pro Spieler; die Regeln stehen als reines Modul in `CombatService/Vitals.luau` (mit Unit-Tests). Kontaktschaden kommt von `EnemySim.Contact`; bei 0 HP setzt der Service den Spieler über `RunDirector.setParticipantState` auf Down. Wieder Alive (Debug-Knopf, später Paket 11) → 40 % HP. Bei Countdown und Lobby volle HP.
- Schnittstellen für spätere Pakete: `CombatService.damagePlayer(player, damage)` (Projektile, Boss), `healPlayer(player, amount)` (Heilung, Passive), `protect(player, seconds)` (Level-up-Wahl, Paket 6), `getHp(player)`.
- Dash: Der Client bewegt die eigene Figur sofort (LinearVelocity entlang des Bodens) und schickt `RequestDash`; der Server prüft den Cooldown (0,25 s Kulanz für Ping) und gibt 0,3 s Unverwundbarkeit. Die Bewegung selbst ist wie bei jeder Roblox-Figur Sache des Clients; der Plausibilitätscheck für Bewegung folgt im Sicherheits-Paket 23.
- `PlayerState` geht bei jeder Änderung an alle Clients (`Net/Types.PlayerVitals`: HP, Max-HP, Dash bereit ab, unverwundbar bis). Ein neuer Client bekommt alle Stände mit `RequestSync` (Signal `RunDirector.SyncRequested`).
- Client: `InputController` (Dash, Springen aus, Roblox-Lebensanzeige aus), `CameraController`, `PlayerStateController` (Stände + vorhergesagter Cooldown).

**Performance-Budgets**

| Budget | Ziel |
| --- | --- |
| Gegner gleichzeitig | 80 + 20 pro weiterem Spieler, max. 140 |
| Server-Simulation | 15 Hz, unter 4 ms pro Schritt |
| Client-FPS Mittelklasse-Handy | ≥ 30 |
| Netzwerk pro Client | < 50 KB/s |
| Partikel-Emitter | so wenige wie möglich, gepoolt |

## 16. Datenspeicherung & Sicherheit

**Datenschema v1**

```lua
{
  schemaVersion = 1,
  embers = 0,
  talents = { toughness = 0, power = 0, reach = 0, greed = 0, rescuer = 0, rerolls = 0 },
  classes = { "BladeWarden", "SparkMage" },
  difficultyUnlocked = "Normal",
  cosmetics = { owned = {}, equipped = {} },
  stats = { runs = 0, kills = 0, bossKills = 0, bestTime = 0 },
  quests = { day = "", list = {} },
  streak = { lastLogin = 0, count = 0 },
  pass = { season = 1, xp = 0, premium = false, claimed = {} },
  receipts = {}, -- bereits verarbeitete PurchaseIds
}
```

- ProfileStore mit Session-Locking; laden beim Join, speichern beim Verlassen, nach Käufen, Autosave.
- Schema-Änderung = `schemaVersion` +1 + Migrationsfunktion; nie Felder ohne Migration löschen.
- `ProcessReceipt` speichert die PurchaseId im Profil und meldet erst danach „granted".
- Game Passes beim Join prüfen und cachen, Käufe in der Sitzung sofort freischalten.
- Entwicklung in einer separaten Test-Experience.

**Sicherheit:** Client schickt nur Absichten (Bewegung, Dash, Level-up-Wahl, Kaufwunsch). Server berechnet Schaden, Kills, XP, Drops, Embers, Truhen, Ranglistenwerte. Jede Remote mit Rate-Limit und Validierung (nur angebotene Karten-IDs, Dash nur nach Cooldown). Bewegungs-Plausibilitätscheck. Admin-Befehle nur für die UserId des Owners, serverseitig geprüft: Admin ist, wer in Studio testet, der Besitzer einer Experience im eigenen Account (`game.CreatorId`) und wer in `Config/Admin.luau` steht. Test-Befehle seit Paket 2: Timer +1 Minute, zu 11:50 springen, sich selbst umhauen/aufstehen, Run gewinnen. Seit Paket 3: 40 Gegner um sich spawnen (Obergrenze gilt), Gegner in 20 Studs Umkreis treffen (5 Schaden), alle Gegner töten, Spawnen pausieren/fortsetzen. Seit Paket 4: sich selbst 25 Schaden geben (Rüstung und Schutz gelten), sich voll heilen; dazu eine Messanzeige unten links (Gegnerzahl, Spawnrate, Serverzeit pro Schritt, Gegnerdaten in KB/s, FPS; rot, wenn ein Budget überschritten ist).

## 17. Compliance & Plattform-Regeln

- [ ] Creator-Account altersgeprüft.
- [ ] Für unter 16: Ausweis-Verifizierung, 2FA, 2 Monate Roblox Plus/Premium oder rückzahlbare Gebühr.
- [ ] Maturity & Compliance Questionnaire komplett, Ziel „Mild".
- [ ] Testphase: erst 16+; Freigabe U16 nach 250 „highly engaged" Plays in 60 Tagen + Safety Review.
- [ ] Keine Social-Hangout-Features, kein freies Zeichnen.
- [ ] Keine Belohnung fürs Anschauen von Video-Feeds.
- [ ] Kisten (falls später): Odds in % vor dem Kauf, `PolicyService:GetPolicyInfoForPlayerAsync()` auswerten.
- [ ] Avatar-Einstellung „R15 only".
- [ ] Optional `Player:PromptAgeCheck()` an einer bewussten Stelle, max. 1× pro 15 Min, nie beim Spawn, nicht auf Konsole.
- [ ] Steuern DE: vor der ersten DevEx-Auszahlung mit Steuerberatung/Finanzamt klären (Gewerbeanmeldung?).

## 18. Analytics & KPIs

Eigene Events (AnalyticsService): Funnel „Erster Start" (gejoint → bewegt → erster Kill → erstes Level-up → Minute 3 → Run-Ende → Lobby → zweiter Run); Economy (Embers-Quellen/Senken); Progression (Schwierigkeit, Bosssiege); Custom (Todesursache, Karten-Pickrate, Run-Länge, Spieler pro Run).

| KPI | Startziel Soft Launch | Hebel, wenn zu niedrig |
| --- | --- | --- |
| D1-Retention | ≥ 20 % | ersten Run kürzer/leichter, mehr Feedback beim ersten Level-up |
| D7-Retention | ≥ 6 % | Quests, Talente, Hard-Modus früher zeigen |
| Ø Session-Länge | ≥ 20 Min | „Nochmal"-Knopf, Party-Bonus |
| Runs pro Session | ≥ 1,5 | Run-Ende-Screen, Bonus für zweiten Run |
| Zahler-Quote | ≥ 1,5 % | Shop-Platzierung, Starter-Angebot |
| Bosssieg in Run 1–3 | 25–35 % | Balancing |

## 19. Roadmap & Content-Umfang

```text
Prototyp (Wo 1–2) ─◆ Spaß-Check: 3 von 5 Testern starten freiwillig Run 2
Vertical Slice (Wo 3–4) ─◆ Stabil: Boss schaffbar, Speichern fehlerfrei
MVP (Wo 5–7) ─◆ Launchfähig: ≥ 30 FPS am Handy, Käufe getestet
Soft Launch (Wo 8) ─◆ Skalieren: D1 ≥ 20 %, D7 ≥ 6 %
Live-Ops (ab Wo 9)
```

Gate nicht geschafft → erst nachbauen; Spaß-Check durchgefallen → Kern-Loop umbauen oder stoppen.

| Phase | Inhalt | Ergebnis |
| --- | --- | --- |
| Prototyp | eine Place, Blade Warden, 3 Waffen, 1–2 Gegnertypen, Level-up-Karten, kein Speichern | spielbarer 5-Min-Run |
| Vertical Slice | Spark Mage, alle 6 Waffen, 6 Passive, 2 Evolutionen, 3 Gegnertypen + Elites, Boss, Wiederbeleben, Speichern, Embers + Talente, HUD | kompletter Run auf Normal |
| MVP | Hub + Teleport, Hard/Nightmare, Shop und Käufe, Quests, Ranglisten, Badges, FTUE, Analytics, Look und Sound, Performance | launchfähiges Spiel |
| Soft Launch | Launch-Paket, Closed Test, öffentlich 16+, Ads-Test | erste echte KPIs |
| Live-Ops | wöchentliche Updates, neue Klassen/Maps, Lantern Pass, Weekly Challenge, Endlos-Modus | Wachstum nach Daten |

## 20. Effort-Plan (Opus 5.5) & Zeitaufwand

Bis zum Soft Launch rund 40–50 Sessions und 50–60 Stunden Zeit des Owners (6–8 h/Woche über 8 Wochen). In Claude Code per `/effort` einstellen.

| # | Arbeitspaket | Phase | Effort | Sessions | Zeit Owner | Owner tut |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Projekt-Setup: Rojo, Git, Ordner, Config, Net | Prototyp | Medium | 1 | 0,5 h | Installationen abnicken, Studio + Rojo-Plugin verbinden |
| 2 | Architektur-Gerüst: Services, Netzwerk-Schicht, Run-Ablauf | Prototyp | Extra high | 1–2 | 1 h | prüfen, dass ein Run startet und endet |
| 3 | Gegner-Engine: Simulation, Raster, Snapshots, Renderer | Prototyp | Extra high | 2–3 | 2 h | mit 1–4 Test-Clients und am Handy testen |
| 4 | Spieler: Kamera, Steuerung, Dash, HP | Prototyp | Medium | 1 | 1 h | Spielgefühl beurteilen |
| 5 | Waffen-Framework + 3 Waffen | Prototyp | Extra high (Framework), Medium (Waffen) | 2 | 1,5 h | Waffengefühl beurteilen |
| 6 | XP, Level-up-Karten, Upgrade-Pool | Prototyp | Medium | 1 | 1 h | Karten am Handy prüfen |
| 7 | Prototyp-Playtest + Balancing | Prototyp | Medium | 1 | 3 h | Spaß-Check mit 3–5 Freunden |
| 8 | Restliche Waffen, Passive, Evolutionen, Spark Mage | Vertical Slice | Medium | 2 | 1,5 h | Balancing-Feedback |
| 9 | Gegnertypen, Elites, Spawn-Director | Vertical Slice | Medium | 1–2 | 1 h | Schwierigkeit beurteilen |
| 10 | Boss mit Vorwarnungen und 2 Phasen | Vertical Slice | High | 2 | 1,5 h | Boss 3× spielen |
| 11 | Down & Wiederbeleben | Vertical Slice | High | 1 | 1 h | mit 2 Clients testen |
| 12 | Datenspeicherung: ProfileStore, Schema, Migration | Vertical Slice | Extra high | 1–2 | 1 h | Test-Experience anlegen, Join/Leave testen |
| 13 | Embers, Talente, Schwierigkeitsgrade | Vertical Slice | Medium | 1–2 | 1 h | Werte abnicken |
| 14 | HUD, Run-Ende, mobiles Layout | Vertical Slice | Medium | 2–3 | 2 h | Handy-Screenshots |
| 15 | Hub-Lobby, Teleport, Party, Quick Join | MVP | Extra high | 2–3 | 2 h | Party-Teleport testen |
| 16 | Käufe: Passes, Products, ProcessReceipt | MVP | Extra high | 1–2 | 1 h | Produkte im Creator Hub anlegen, IDs liefern, Testkäufe |
| 17 | Shop-, Talent- und Pass-UI | MVP | Medium | 2 | 1 h | Look abnicken |
| 18 | Quests, Login-Serie, Ranglisten, Badges | MVP | Medium | 2 | 1 h | Badges im Creator Hub anlegen |
| 19 | Erster Start (FTUE) | MVP | Medium | 1 | 1 h | neue Tester beobachten |
| 20 | Analytics-Events | MVP | Medium | 1 | 0,5 h | Dashboard ansehen |
| 21 | VFX, Sounds, Musik, Map-Feinschliff | MVP | Medium (Low fürs Platzieren) | 2 | 2 h | auswählen |
| 22 | Performance-Pass Mobile + Netzwerk | MVP | Extra high | 1–2 | 1,5 h | Handy-Tests, Mikroprofiler-Screenshots |
| 23 | Sicherheits- und Code-Review | MVP | Extra high | 1–2 | 0,5 h | Ergebnis abnicken |
| 24 | Launch-Paket: Icon, Thumbnails, Beschreibung, Clips | Soft Launch | Medium | 1 | 3 h | Clips, Fragebogen, Ads |
| 25 | Bugfixing (laufend) | alle | Medium, nach 2 Fehlversuchen Extra high | – | – | Bug-Report |
| 26 | Live-Ops-Update | Live-Ops | Medium | 1–2/Woche | 3–5 h/Woche | Feedback, Prioritäten, Tests |

**Effort-Regeln:** Medium = Standard. High = Spiellogik mit vielen Sonderfällen. Extra high = Architektur, Gegner-Engine, Waffen-Framework, Speichern, Käufe, Teleport, Performance, Sicherheit. Low = Texte, Preise, Zahlen. Max = nicht nutzen (langsamer, frisst Nutzungslimit). Bug zweimal ungelöst → neue Session auf Extra high mit Bug-Report.

## 21. Workflow mit Claude Code & Rolle des Owners

Der Owner ist Produzent und Tester; Claude Code schreibt den Code im Repo, Rojo synchronisiert ihn nach Studio.

**Ablauf jeder Session**

1. Studio öffnen, Rojo-Plugin verbinden (`rojo serve` läuft).
2. Effort per `/effort` laut Abschnitt 20 einstellen.
3. Auftrag, z. B.: „Lies DESIGN.md Abschnitt 7 und baue Arbeitspaket 9."
4. Claude Code baut auf einem eigenen Branch, testet, committet.
5. Owner spielt: solo, „Test → Clients and Servers" (2–4 Spieler), Handy.
6. Passt es → Merge; passt es nicht → Feedback oder Rollback auf den letzten Commit.
7. Paket in Abschnitt 20 bzw. im Fortschritt abhaken.

**Bug-Report-Vorlage**

```markdown
**Was ich gemacht habe:** …
**Was passieren sollte:** …
**Was passiert ist:** …
**Fehler aus dem Output-Fenster:** (kopieren)
**Screenshot/Clip:** …
```

**Nur der Owner:** Spielgefühl beurteilen, Entscheidungen; Creator Hub (Einstellungen, Passes/Products, Preise, Icons, Badges, Fragebogen, Veröffentlichen); Tests auf echten Geräten; Marketing und Community.

## 22. Launch, Marketing & Live-Ops

1. **Closed Test** (Ende MVP): 10–20 Tester, private Server.
2. **Soft Launch** (Woche 8): öffentlich 16+, Fragebogen komplett, Roblox Ads mit kleinem Testbudget (Vorschlag 50–100 €), 2–3 Icon-Varianten.
3. **U16-Freigabe** nach 250 „highly engaged" Plays + Safety Review.
4. **Skalieren** nur bei D1/D7 im Ziel.

Marketing: beschreibender Titel, klares Icon (Laterne gegen Horde); 15–30-s-Clips für TikTok/Shorts (Blade-Storm-Evolution, 4-Spieler-Boss, Rettung in letzter Sekunde); Roblox-Gruppe + Discord ab Tag 1; kleinere Roblox-Survival-YouTuber anschreiben.

| Rhythmus | Inhalt |
| --- | --- |
| wöchentlich, fester Tag (Vorschlag Sa 18:00 MEZ) | Bugfixes, Balancing, 1 neue Waffe/Gegner, neue Weekly Challenge |
| alle 3–4 Wochen | neue Klasse oder Map |
| alle 6 Wochen | neue Saison mit Lantern Pass |
| Feiertage | Event mit eigener Kosmetik |

## 23. Risiken & Gegenmaßnahmen

| Risiko | Wahrscheinlichkeit | Gegenmaßnahme |
| --- | --- | --- |
| Kern-Loop macht keinen Spaß | mittel | Spaß-Check nach 2 Wochen, sonst umbauen/stoppen |
| Performance auf Handys | mittel | keine Humanoids, Obergrenze 140, ab Woche 1 am Handy testen |
| Codebasis wird unübersichtlich | mittel | ein Paket pro Session, Werte in Config, Git, CLAUDE.md, Code-Review vor Launch |
| Datenverlust | niedrig | ProfileStore, Migrationen, Test-Experience |
| Exploits | mittel | Server-Autorität, Rate-Limits, Sicherheits-Review |
| Monetarisierung zu schwach | mittel | Server-Boost, VIP, Pass früh testen; Preise nach Daten |
| Kopien nach Erfolg | hoch, falls es läuft | Update-Tempo, Community, Saisons |
| Zu wenig Zeit neben dem Studium | mittel | Scope v1 fix, realistischer Live-Ops-Rhythmus |
| KI-Nutzungslimit | mittel | Medium als Standard, Extra high gezielt |
| Plattform-Regeln ändern sich | mittel | Compliance-Liste bei jedem großen Update prüfen |

## 24. Offene Entscheidungen

- [ ] Finaler Name: „Lanternfall" behalten oder Alternativen testen?
- [ ] Look: Low-Poly-Fantasy oder anderer Stil?
- [ ] Eigentümer: Veröffentlichung unter einer Roblox-Gruppe?
- [ ] Beitritt in laufende Runs (v1: nein)?
- [ ] Endlos-Modus nach dem Boss (Vorschlag: erste Live-Ops-Phase)?
- [ ] Kosmetische Kisten ja/nein (frühestens Live-Ops)?
- [ ] Ad-Budget für den Soft Launch.

## 25. Quellen

- [Megabonk – Wikipedia](https://en.wikipedia.org/wiki/Megabonk)
- [Robong Megabonk – game.guide](https://www.game.guide/roblox-codes/robong-megabonk)
- [Roblox Survivor (working title) – UK Games Fund](https://www.ukgamesfund.com/funded-project/roblox-survivor-working-title/)
- [Steal A Car – RoWatcher](https://rowatcher.com/games/10765153945/steal-a-car)
- [Roblox Kids and Select – Creator Hub](https://create.roblox.com/docs/en-us/production/publishing/kids-and-select)
- [Paid random items policy – Creator Hub](https://create.roblox.com/docs/production/monetization/paid-random-items)
- [US 18+ DevEx Rate – DevForum](https://devforum.roblox.com/t/introducing-the-us-18-devex-rate-earn-42-more-on-spend-from-18-us-players/4607091)
- [Roblox Newsroom – 18+ DevEx Rate](https://about.roblox.com/newsroom/2026/04/roblox-fuels-high-fidelity-games-over-18-players-increases-qualifying-devex-rate-42)
- [TechSpot – Roblox und belohnte Video-Feeds](https://www.techspot.com/news/113630-roblox-cracking-down-games-reward-kids-doomscrolling.html)
- [Claude Help Center – Effort-Einstellungen](https://support.claude.com/en/articles/8664678-change-the-model-effort-and-thinking-settings)
