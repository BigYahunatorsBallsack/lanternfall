# Lanternfall – Game Design Document

Stand: 29.10.2026 · Quelle: claude.ai-Doc „Lanternfall – Game Design Document" (Original mit Diagrammen). Diese Datei ist die Arbeitskopie im Repo; Änderungen am Design hier pflegen.

## 1. Überblick & Vision

Lanternfall ist ein Koop-Survivors für 1–4 Spieler: Runs aus 12 kurzen Wellen gegen Schattenhorden, Waffen feuern automatisch, nach jeder Welle wählst du deine Level-ups und kaufst im Shop ein, am Ende wartet ein Boss.

| Punkt | Festlegung |
| --- | --- |
| Arbeitstitel | Lanternfall; Roblox-Titel beschreibend, z. B. „Lanternfall: Horde Survivors" |
| Genre | Koop-Survivors/Roguelite; seit Paket B1 nach dem Prinzip von Brotato (Wellen mit Shop dazwischen, feste Arena), vorher Vampire Survivors/Megabonk |
| Spieler | 1–4 pro Run, Hub-Lobby mit bis zu 24 |
| Session | heute Run 12 Wellen (9 Min Kampf + Shop-Pausen) + Boss (≈ 14–16 Min); ab Paket B3 20 Wellen wie Brotato mit Boss in Welle 20 (≈ 17,5 Min Kampf, mit Shops ≈ 25–30 Min, Owner-Entscheidung 29.10.2026). Ziel ≥ 20 Min pro Session |
| Zielgruppe | zuerst 16+ (so startet jedes neue Spiel), danach alle ab 9 |
| Plattform | Mobile first; PC und Konsole laufen mit |
| Content-Rating | Ziel „Mild": Fantasy-Gewalt ohne Blut |
| Sprache im Spiel | Englisch; Roblox übersetzt automatisch |

**Setting:** Die Welt versinkt im „Gloom". Die Spieler sind Laternenträger und müssen bis zum Morgengrauen durchhalten. Licht steht für Spieler, Dunkelheit für Gegner – so ist jedes Bild sofort lesbar.

**Was es anders macht**

- Koop statt Solo: Survivors-Gefühl mit Freunden, gegenseitiges Wiederbeleben, gemeinsame Bosse.
- Jeder Run ist anders: Waffen und Items (seit B2, vorher Passive) kombinieren sich zu Builds und Evolutionen.
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

Zwei Schleifen tragen das Spiel: im Run wird man nach jeder Welle durch Level-ups und den Shop stärker, zwischen den Runs dauerhaft durch Embers.

**Richtung Brotato (Entscheidung des Owners am 27.10.2026, umgesetzt ab Paket B1):** Das Spiel fühlte sich nach dem Spaß-Paket schon wie Brotato an (feste Arena, feste Kamera, Wellen). Deshalb gehen wir gezielt dorthin: kurze Wellen, danach eine Shop-Phase. Mechaniken, Formeln und Zahlen orientieren sich eng an Brotato; Namen, Texte, Items, Charaktere und Look sind unsere eigenen (keine Kopie von geschütztem Inhalt). Plan: B1 Wellen mit Shop, B2 Werte-System und Items mit Vor- und Nachteilen, B3 Shop-Feinschliff (Sperren, Verkaufen, Verschmelzen), B4 Charaktere mit Trade-offs (Abschnitt 20).

**Plan nach der Brotato-Referenz (29.10.2026):** Der Owner hat eine Referenz aller Brotato-Mechaniken (Basisspiel ohne DLC, Zahlen aus dem Community-Wiki) geliefert; alles daraus soll so gut wie möglich ins Spiel. Der Abgleich mit dem Stand nach B2 und die neuen Pakete B3–B12 stehen in Abschnitt 20. Entscheidung des Owners: Ein Run bekommt **20 Wellen wie Brotato** (20, 25, 30 … 55 s, Wellen 9–19 je 60 s, Welle 20 = Boss-Welle mit 90 s, endet sofort, wenn der Boss stirbt); umgestellt wird in B3. Bis dahin beschreibt dieser Abschnitt den Stand mit 12 Wellen.

```text
Welle (20–60 s kämpfen, XP-Orbs = Shards sammeln)
   │ Timer abgelaufen
   ▼
Wellenende: Gegner verschwinden, liegende Orbs gehen ans Team, Truhen öffnen sich,
            Harvesting zahlt aus, alle voll geheilt, wer down ist, steht auf
   ▼
Werte-Karten (eine Wahl pro Level dieser Welle) → Shop (max. 40 s, „Ready")
   │ alle bereit oder Zeit um                      │ nach Welle 12
   ▼                                               ▼
nächste Welle                               Boss → Run-Ende (Embers, „Nochmal")
```

```text
Hub-Lobby → Run startet → Welle ⇄ Level-ups & Shop
                              │ nach Welle 12      │ alle down (Scheitern)
                              ▼                    ▼
                        Boss nach Welle 12 ──Sieg──→ Run-Ende (Embers, „Nochmal")
                                                   │
Hub-Lobby ←──── nächster Run ──── Talente & Klassen ←┘
```

Sind alle gleichzeitig down, endet der Run sofort – Embers gibt es trotzdem für die überlebte Zeit.

Wellenlängen wie in Brotato: Welle 1 dauert 20 s, jede weitere 5 s mehr, ab Welle 9 je 60 s (20, 25, 30 … 60, 60, 60, 60 = 540 s Kampf). Die Konfiguration rechnet in „Plan-Minuten": Welle n läuft von Minute n − 1 bis n, egal wie lang sie in Sekunden ist. So gelten alle Kurven und die Mischung weiter pro Welle.

| Welle | Was passiert |
| --- | --- |
| 1 | ruhiger Start mit der Klassen-Waffe, wenige Shadelings |
| jede | Banner „WAVE n"; die Spawnrate steigt in der Welle von 0,7× auf 1,2×; danach Shop |
| 3 | Brutes kommen dazu, erste Gloom Elite mit Truhe |
| 4 | Charger (laden auf und stürmen geradeaus) |
| 5 | Spitter, zweite Elite |
| 6 | Swarm Rush: 60 % der Welle doppelte Spawnrate |
| 7 | Abyss Shadelings, 2 Elites, ab jetzt mit Eigenschaft (Swift, Armored, Summoning) |
| 8 | Splitter (zerfallen in 3 Splitlings) |
| 9 | Abyss Brutes, Elite; Builds stehen, erste Evolutionen aus Elite-Truhen möglich |
| 10 | zweiter Swarm Rush |
| 11 | nur noch die starken Gegnerarten, 2 Elites, Gegner mit 3-facher HP |
| 12 | letzte Welle, 1,4-fache Spawnrate |
| danach | Boss The Lantern Eater erscheint, normales Spawnen stoppt |
| ≈ 14–16 Min | Run-Ende: Statistik, Embers, „Nochmal" |

**Wellenende und Shop (seit Paket B1, seit B2 mit Items und Werten; Werte in `Config/Shop.luau` und `Config/Items.luau`):**

| Was | Umsetzung |
| --- | --- |
| Uhr | Die Kampfzeit stoppt genau am Wellenende und läuft erst mit der nächsten Welle weiter. Timer oben zeigt die Restzeit der Welle bzw. des Shops. |
| Wellenende | Restliche Gegner und Geschosse verschwinden. Liegende XP-Orbs gehen ans Team, ihre Shards werden gleichmäßig auf alle verteilt, die nicht „Out" sind (Brotato legt sie in einen „Beutel" für später; das kann B3 nachholen). Liegende Elite-Truhen öffnen sich für alle. Alle werden voll geheilt, wer down ist, steht mit voller HP auf. Seit B2 zahlt danach Harvesting aus (Abschnitt 4). |
| Level-ups | XP sammelt sich in der Welle; die Kartenwahl (seit B2 1 aus 4 Werte-Karten, Abschnitt 9) kommt erst am Wellenende, eine pro gewonnenem Level. Im HUD steht so lange „LV 5 · +2 at wave end". Was beim Start der nächsten Welle noch offen ist, wird automatisch gewählt. |
| Shards | Geld im Run (Brotatos „Materialien"): jeder XP-Punkt eines Orbs, den man selbst aufsammelt, gibt 1 Shard. Getrennt von den Embers (Meta-Währung). |
| Angebote | Pro Spieler 4 eigene Angebote, nie zweimal dasselbe: eine Waffe (neu oder +1 Level einer eigenen, bis Level 5, höchstens 6 Waffen; eigene doppelt so wahrscheinlich) oder ein Item (Abschnitt 6). Nach Welle 1–2 mindestens 2 Waffen, nach Welle 3–5 mindestens 1, sonst je Platz 35 % Waffe, 65 % Item. Items kann man unbegrenzt oft kaufen und stapeln (einzelne mit Obergrenze, z. B. Iron Shackle 1×); die Karte zeigt „x3" = so viele hat man nach dem Kauf. |
| Seltenheit (seit B2) | Jedes Item hat eine Stufe: Common (grau), Uncommon (blau), Rare (violett), Legendary (rot). Pro Item-Platz wird die Stufe gewürfelt wie in Brotato: Chance = (pro Welle · (Welle − Startwelle + 1) + Grundwert) · (1 + Luck/100), höchstens Obergrenze; seltenste zuerst. Uncommon ab Welle 2 (6 %/Welle, max. 60 %), Rare ab Welle 4 (2 %/Welle, max. 25 %), Legendary ab Welle 8 (0,23 %/Welle, max. 8 %). Ist eine Stufe leer (alles an der Obergrenze), kommt eine niedrigere, sonst eine höhere. |
| Preise | wie Brotato: Preis = ⌊Grundpreis + Welle + 10 % · Grundpreis · Welle⌋, mindestens 1 (Welle = die gerade beendete). Grundpreise: Waffen 18–25, Items 15–30 (Common), 35–65 (Uncommon), 55–80 (Rare), 90–120 (Legendary). |
| Neu würfeln | erster Wurf ⌊0,75 · Welle⌋ + Aufschlag, jeder weitere + Aufschlag, Aufschlag = max(1, ⌊0,4 · Welle⌋) (nach Welle 5: 5, 7, 9 …). Seit B2 kostet auch das Neu-Würfeln der Werte-Karten so viele Shards (eigener Zähler pro Kartenwahl). |
| Werte-Anzeige (seit B2) | Während Kartenwahl und Shop steht rechts eine Liste aller Werte (grün = besser als am Start, rot = schlechter); Ausweichen zeigt „(max 60%)". |
| Ready | Der Shop schließt nach 40 s oder sobald alle, die nicht „Out" sind, „Ready" gedrückt haben. In der Team-Liste steht „shopping" bzw. „ready". Im Shop gibt es keine Gegner. |
| Eigener Bildschirm | Level-up-Karten und Shop liegen auf einem eigenen, dunklen Bildschirm mit „WAVE n CLEARED" (darunter „Pick your level-ups" bzw. „Spend your Shards"); die Arena ist nicht zu sehen. Timer, XP-Leiste, Build und Team-Liste bleiben sichtbar. Wie in Brotato steht die Figur still: kein Laufen, kein Dash, bis die nächste Welle startet (Owner-Wunsch nach B1). |
| Noch nicht (B3) | Sperren, Verkaufen, Verschmelzen gleicher Waffen, Waffen-Stufen, Shop-Rabatte. |

**Run-Ablauf im Prototyp** (Lobby und Arena im selben Server, Werte in `Config/Run.luau` → `flow`):

1. **Lobby:** Klasse wählen, „Ready" drücken. Wer bereit ist, kommt in den nächsten Run (max. 4).
2. **Countdown:** startet mit dem ersten bereiten Spieler, 10 s; sind alle im Server bereit, sofort auf 3 s verkürzt. Bricht ab, wenn niemand mehr bereit ist.
3. **Run:** alle Bereiten werden in die Arena gesetzt, Welle 1 beginnt; nach jeder Welle kommt die Shop-Phase (Phase „Shop"). Wer später kommt oder nicht bereit war, wartet in der Lobby und kann sich schon für den nächsten Run bereit melden.
4. **Nach Welle 12 = Boss-Phase.** Bis der Boss da ist (Paket 10), zählt das Erreichen der Boss-Phase als Sieg.
5. **Ende:** Sieg (Boss besiegt), Niederlage (niemand mehr „Alive", also alle down) oder abgebrochen (alle haben den Server verlassen, dann direkt zurück in die Lobby).
6. **Ergebnis:** 15 s Ergebnis-Bildschirm mit „Play again"; drücken alle Teilnehmer „Play again", geht es sofort weiter. Danach zurück in die Lobby, wer „Play again" gedrückt hat, startet direkt den nächsten Countdown.

## 4. Steuerung & Spieler-Grundwerte

Spieler steuern nur Bewegung und einen Dash; Angreifen, Zielen und Aufsammeln passiert automatisch.

- **Mobile:** virtueller Stick links, Dash-Button rechts. **PC:** WASD + Leertaste. **Konsole:** linker Stick + A.
- **Kamera:** feste Schräg-Kamera (etwa 50° Neigung, fester Zoom; seit dem Feedback nach Paket 9 flacher, vorher 60°). Bewusst nicht wie Megabonk (Third-Person hinter der Figur, drehbar): Waffen zielen automatisch, man soll die Traube rundherum sehen, und am Handy reicht ein Daumen (Entscheidung des Owners, Paket 4). Die Kamera steht südlich der Figur und schaut nach Norden, W/Stick nach oben läuft also immer bildschirm-aufwärts.
- **Zielen:** jede Waffe hat eine feste Zielregel (nächster Gegner, zufälliger Gegner, um den Spieler herum).
- **Charakter:** Roblox-R15-Avatar mit Klassen-Kostüm darüber (Abschnitt 14).

| Wert | Startwert | Anmerkung |
| --- | --- | --- |
| Leben (HP) | 100 | Brotatos 10 HP mal 10; Klassen, Items, Werte-Karten und jedes Team-Level erhöhen es |
| Lauftempo | 16 Studs/s | Roblox-Standard; der Wert „Speed" ändert es in Prozent |
| Dash | 12 Studs, 6 s Cooldown | 0,3 s unverwundbar |
| Aufsammelradius | 8 Studs | XP-Orbs, Heilung, Embers; „Pickup Range" in Prozent |
| Rüstung | 0 | seit B2 prozentual wie Brotato (Tabelle unten) |
| Regeneration | 0 | seit B2 der Wert „HP Regeneration" |
| Schutz nach Treffer | 0,5 s | verhindert Sofort-Tod im Pulk |
| Krit-Chance | 5 % | Krit = doppelter Schaden; „Crit Chance" kommt dazu |

**Werte wie in Brotato (seit Paket B2, Zahlen in `Config/Stats.luau`, Formeln in `Util/StatMath.luau`):** Jeder Spieler hat im Run 17 Werte. Sie starten bei 0 (außer Max HP) und kommen aus Klasse, Items, Werte-Karten und Team-Level zusammen. Es gibt keine Obergrenze außer bei Ausweichen (60 %) und Krit-Chance (100 %); Items stapeln unbegrenzt (Owner-Entscheidung „Unbegrenzt wie Brotato"). Negative Werte sind möglich und schaden.

| Wert | Wirkung |
| --- | --- |
| Max HP | Leben; +10 pro Team-Level (Brotato +1) |
| HP Regeneration | heilt 10 HP alle 5 s / (1 + (Wert − 1) / 2,25): Wert 1 = alle 5 s, Wert 10 = jede Sekunde (umgesetzt als gleichmäßige HP pro Sekunde) |
| Life Steal (%) | Chance pro Waffentreffer, 10 HP zu heilen, höchstens 10-mal pro Sekunde |
| Damage (%) | Schaden aller Waffen × (1 + Wert/100), mindestens 1 |
| Melee / Ranged / Elemental Damage | flacher Zusatzschaden für Waffen dieser Art, mal deren Skalierung (seit B2 1,0; Abschnitt 6), vor Damage % |
| Attack Speed (%) | Cooldowns und Trefferpausen / (1 + Wert/100); negativ: × (1 + 0,5 · Betrag/100) (Annahme, Brotato nennt keine Formel); nie unter 0,2 s |
| Crit Chance (%) | kommt zu den 5 % Grund-Krit dazu |
| Range | Brotato-Punkte, 0,1 Studs pro Punkt (Nahkampf die Hälfte): verlängert Reichweite bzw. Radius jeder Waffe, nie unter 2,5 Studs |
| Armor | erlittener Schaden × 1 / (1 + Rüstung/15) (5 Rüstung = −25 %, 15 = −50 %); negativ: × (15 − 2·Rüstung)/(15 − Rüstung); auf ganze HP gerundet, mindestens 1 |
| Dodge (%) | Chance, einem Treffer ganz auszuweichen, höchstens 60 %; ein ausgewichener Treffer gibt keinen Schutz danach |
| Speed (%) | Lauftempo × (1 + Wert/100) |
| Luck | erhöht die Chancen auf seltene Items und Karten (× (1 + Luck/100)) |
| Harvesting | am Wellenende so viele Shards und Team-XP, danach wächst es um 5 % (aufgerundet); negativ nimmt es Shards |
| XP Gain (%) | eingesammelte XP × (1 + Wert/100) (nur aus Items) |
| Pickup Range (%) | Aufsammelradius × (1 + Wert/100) (nur aus Items) |

Engineering und Knockback aus Brotato fehlen bewusst (keine Bauten, kein Rückstoß-Wert).

Seit Paket 4 umgesetzt (Werte in `Config/Player.luau` und `Config/Camera.luau`): Kamera 50° Neigung (seit Feedback zu Paket 9, vorher 60°), 70 Studs Abstand, Sichtfeld 40°, folgt weich. Springen ist aus; Leertaste, Gamepad-A und ein runder Dash-Knopf unten rechts lösen den Dash aus (am Handy größer). Der Dash schiebt die Figur in 0,15 s 12 Studs in Laufrichtung (im Stand in Blickrichtung); Wände und Ruinen stoppen ihn. Der Knopf zeigt den Cooldown als dunkle Füllung. Wer „down" ist, kann nicht laufen und nicht dashen. Klassenbonus auf HP wird beim Run-Start eingerechnet (Blade Warden 120 HP; seit B2 als +20 Max HP). Im HUD unten Mitte die eigene HP-Leiste (rot unter 30 %), kurzer roter Bildschirm-Blitz bei Treffern, HP der Mitspieler in der Team-Liste.

Alle Werte stehen in Config-Modulen, nicht im Code.

## 5. Klassen

v1 startet mit zwei kostenlosen Klassen; ab Live-Ops kommt alle 3–4 Wochen eine neue, freischaltbar mit Embers oder per Game Pass.

| Klasse | Startwaffe | Klassen-Bonus | Spielgefühl | Verfügbar |
| --- | --- | --- | --- | --- |
| Blade Warden | Orbit Blades | +20 Max HP (seit B2; vorher +20 %) | Nahkampf, mitten rein | v1, gratis |
| Spark Mage | Spark Bolt | +10 % Attack Speed (seit B2; vorher −10 % Cooldown) | Fernkampf, ausweichen | v1, gratis |
| Lantern Keeper | Lantern Pulse (heilt Team im Radius) | +25 % Wiederbelebungstempo | Support im Koop | Live-Ops, 2.500 Embers oder Pass |
| Trapper | Thorn Trail | +15 Range (seit B2; vorher +15 % Fläche) | Zonen kontrollieren | Live-Ops, 2.500 Embers oder Pass |

Jede Klasse: eine Startwaffe, ein passiver Bonus, ein eigenes Kostüm. Keine eigenen Skill-Bäume in v1. Seit B2 sind die Klassen-Boni normale Werte (`Config/Classes.luau` → `stats`, Abschnitt 4); Charaktere mit Plus und Minus wie in Brotato folgen in B4.

## 6. Waffen, Items & Evolutionen

v1 hat 6 Waffen, 46 Items und 2 Evolutionen. Seit B2 trägt jeder Spieler bis zu 6 Waffen (vorher 4), jede steigt bis Level 5 (Waffen-Stufen und Verschmelzen kommen in B3). Items ersetzen seit B2 die 6 Passive: Man kann sie beliebig oft kaufen, sie stapeln ohne Grenze.

**Waffen (Startwerte Level 1)**

| Waffe | Verhalten | Schaden | Cooldown | Pro Level bis L5 |
| --- | --- | --- | --- | --- |
| Orbit Blades | 2 Klingen kreisen um dich, Radius 7 Studs | 15 pro Treffer (Paket 7, vorher 12) | dauerhaft, 0,5 s pro Gegner | +1 Klinge auf L3 und L5, sonst +15 % Schaden |
| Spark Bolt | Projektil auf nächsten Gegner, durchbohrt 1 | 15 | 0,9 s | +1 Projektil auf L2 und L4, sonst +20 % Schaden |
| Shockwave | Druckwelle um dich, Radius 10 Studs | 20 | 3,0 s | +2 Studs Radius und −0,3 s |
| Chain Lightning | Blitz springt über 3 Gegner | 18 | 2,0 s | +1 Sprung und +15 % Schaden |
| Thorn Trail | Dornenspur hinter dir, liegt 2 s | 8 pro 0,5 s | dauerhaft | +0,5 s Dauer und +20 % Schaden |
| Boomerang Axe | fliegt raus und zurück, durchbohrt alles | 25 | 1,6 s | +1 Axt auf L3 und L5, sonst +15 % Schaden |

**Items (seit B2, Werte in `Config/Items.luau`)**

Jedes Item ändert Werte (Abschnitt 4), die meisten mit einem Nachteil, wie in Brotato. Die Werte-Pakete orientieren sich an Brotatos Items (HP mal 10), Namen und Ideen sind unsere eigenen. Vitality, Haste, Focus, Magnet, Might und Armor Plate behalten die IDs der alten Passive, damit die Evolutionen sie finden. Preis = Grundpreis, im Shop steigt er pro Welle (Abschnitt 3). „max. 1" = höchstens einmal kaufbar.

| Item | Stufe | Grundpreis | Werte |
| --- | --- | --- | --- |
| Vitality | Common | 15 | +30 Max HP, -1% Damage |
| Haste | Common | 20 | -6 Range, +4% Speed |
| Focus | Common | 20 | -2% Damage, +10% Attack Speed |
| Magnet | Common | 20 | +30% Pickup Range |
| Might | Common | 18 | -10 Max HP, +5% Damage |
| Armor Plate | Common | 18 | -10 Max HP, +1 Armor |
| Wax Heart | Common | 18 | +20 Max HP, +2 HP Regeneration, -1% Speed |
| Cracked Lens | Common | 20 | +20 Range |
| Bone Knuckles | Common | 15 | +1 Melee Damage |
| Tallow Candle | Common | 20 | +2 Melee Damage, +1 Elemental Damage, -2 Harvesting |
| Moth Wing | Common | 30 | +2% Life Steal, -1 Elemental Damage |
| Grave Spade | Common | 15 | -1 Melee Damage, +8 Harvesting |
| Cat Claw | Common | 20 | -10 Max HP, +1 Melee Damage, +3% Crit Chance |
| Rusted Coin | Common | 15 | -1% Damage, +8 Luck |
| Flint Shard | Common | 15 | -1 Melee Damage, +1 Ranged Damage |
| Ward Rune | Common | 20 | -10 Max HP, +3% Dodge |
| Leech Jar | Uncommon | 45 | +2 HP Regeneration, +2% Life Steal, -3 Harvesting |
| Ash Blindfold | Uncommon | 45 | +5% Crit Chance, -15 Range, +5% Dodge |
| Signal Banner | Uncommon | 55 | +10% Attack Speed, +20 Range |
| Brazier | Uncommon | 40 | +2 HP Regeneration, +2 Elemental Damage, -2% Speed |
| Oil Flask | Uncommon | 45 | -1 Melee Damage, -1 Ranged Damage, +4 Elemental Damage |
| Loaded Dice | Uncommon | 50 | -1 Armor, +8% Dodge |
| Narrow Scope | Uncommon | 45 | +12% Damage, -12 Range |
| Whetstone | Uncommon | 35 | +3 Melee Damage, -3% Attack Speed |
| Acid Vial | Uncommon | 65 | +80 Max HP, -2% Dodge |
| Static Bracelet | Uncommon | 55 | -2 Ranged Damage, +2 Elemental Damage, +4% Crit Chance |
| Powder Pouch | Uncommon | 45 | +2 Ranged Damage, +5% Attack Speed, -1 Armor |
| Lantern Oil | Uncommon | 45 | -2% Damage, +2% Speed, +15 Luck |
| Glass Lantern | Rare | 75 | +25% Damage, -3 Armor |
| Four-Leaf Charm | Rare | 65 | -2% Life Steal, +6% Dodge, +20 Luck |
| Eel Fin | Rare | 65 | +3% Life Steal, +10% Speed, -8 Luck |
| Blood Offering | Rare | 55 | -20 Max HP, +40 Harvesting |
| Iron Shackle | Rare | 75 | +15% Damage, +3 Armor, -3% Speed (max. 1) |
| Clockwork Gears | Rare | 70 | +10% Attack Speed, +5% Crit Chance, -10 Range |
| Tome of Echoes | Rare | 70 | -2% Life Steal, +50% XP Gain |
| Smoke Mantle | Rare | 80 | -3 Armor, +10% Dodge, -5% Speed |
| Silver Rounds | Rare | 70 | +3 Ranged Damage, +5% Crit Chance, -3% Speed |
| Thorn Crown | Rare | 70 | +4 Melee Damage, +4 Elemental Damage, -5% Attack Speed |
| Titan Arms | Legendary | 105 | +12 Melee Damage, +6 Ranged Damage, -3% Attack Speed, -3% Speed |
| Shadow Cloak | Legendary | 110 | +5% Life Steal, -2 Melee Damage, -2 Ranged Damage, -2 Elemental Damage, +20% Dodge |
| Heavy Rounds | Legendary | 100 | +10% Damage, +5 Ranged Damage, -5% Attack Speed, -5% Crit Chance, +10 Range |
| Colossus Heart | Legendary | 110 | +150 Max HP, +5 HP Regeneration, -10% Speed |
| Brass Harness | Legendary | 90 | -2 HP Regeneration, -2% Life Steal, +5% Crit Chance, +3 Armor, +5% Speed |
| Witch's Mortar | Legendary | 100 | +10 Melee Damage, +10 Elemental Damage, -20 Range, -20% Pickup Range |
| Lantern Codex | Legendary | 90 | -30 Max HP, +10 Luck, +50% XP Gain |
| Eternal Flame | Legendary | 120 | +20% Damage, +20% Attack Speed, -2 Armor |

**Evolutionen** – nur aus Elite- oder Boss-Truhen, wenn die Voraussetzung erfüllt ist:

| Evolution | Voraussetzung | Effekt |
| --- | --- | --- |
| Blade Storm | Orbit Blades L5 + mindestens 1 Armor Plate | 8 Klingen, Radius 10, doppelter Schaden |
| Starfire | Spark Bolt L5 + mindestens 1 Focus | Projektile explodieren mit Radius 6 Studs |

Werte, die hier noch fehlen (Projektil-Tempo und Reichweite von Spark Bolt und Boomerang Axe, Sprungweite von Chain Lightning, Drehtempo der Orbit Blades), stehen als Annahme in `Config/Weapons.luau`. Kollisionsradius und Masse der Gegner stehen seit Paket 3 als Annahme in `Config/Enemies.luau`.

Jede Waffe = ein Datensatz im Config-Modul + ein kleines Verhaltens-Modul. Neue Waffe = neuer Datensatz + Verhalten, Framework bleibt unangetastet.

**Stand im Code (seit Paket 8):** Alle sechs Waffen sind spielbar (Orbit Blades, Spark Bolt und Shockwave seit Paket 5, Chain Lightning, Thorn Trail und Boomerang Axe seit Paket 8) und kommen seit B1 aus dem Shop (vorher Level-up-Karten). Jeder Spieler startet den Run mit der Waffe seiner Klasse auf Level 1. Annahmen fürs Spielgefühl (Werte in `Config/Weapons.luau`, Urteil des Owners steht noch aus):

| Waffe | Annahme |
| --- | --- |
| Orbit Blades | Die Klingen sind lange Schwerter, die von 2 Studs bis zum Radius (7) reichen, 1 Stud breit, 240°/s (Paket 7, vorher 180°/s). So treffen sie auch Gegner, die direkt am Spieler stehen (Blade Warden = „mitten rein"). Jeder Gegner höchstens alle 0,5 s; mit 2 Klingen wird jeder Punkt etwa 1,3-mal pro Sekunde überstrichen. Ruhen, solange der Spieler down ist. |
| Spark Bolt | 60 Studs/s, Reichweite 40 Studs (etwa der sichtbare Bereich), Trefferradius 0,5. Schießt nur, wenn ein Gegner in Reichweite ist. Mehrere Bolts gehen an verschiedene nächste Gegner; gibt es zu wenige, fächern die übrigen um 12° um den nächsten auf. Durchbohrt 1 heißt: fliegt durch den ersten Gegner und stoppt am zweiten. Hindernisse halten Bolts nicht auf. |
| Shockwave | Löst erst aus, wenn ein Gegner im Radius steht. Schubst überlebende Gegner 3 Studs vom Spieler weg, geteilt durch ihre Masse über 1 (Brute 0,5 Studs). Der Schubs ist neu gegenüber dem ursprünglichen Design. |
| Chain Lightning (Paket 8) | „Springt über 3 Gegner" heißt: trifft 3 Gegner insgesamt (jedes Level einer mehr). Der erste muss höchstens 25 Studs entfernt sein, jeder weitere höchstens 12 Studs vom vorigen; nie zweimal derselbe. Alle Treffer sofort. Wartet auf einen Gegner in Reichweite. |
| Thorn Trail (Paket 8) | Alle 2 Studs Weg legt der Spieler ein Dornenfeld mit 2,5 Studs Radius ab (Fläche-Bonus vergrößert es); steht er still, liegt immer eins unter ihm. Alle 0,5 s trifft die Spur jeden Gegner darauf einmal, auch wenn er auf mehreren Feldern steht. Höchstens 40 Felder pro Spieler. Liegende Felder wirken weiter, wenn der Spieler down ist. |
| Boomerang Axe (Paket 8) | Fliegt mit 40 Studs/s 20 Studs weit zum nächsten Gegner, dreht um und fliegt zurück zu dem Ort, an dem der Spieler jetzt ist. Trifft jeden Gegner einmal auf dem Hinweg und einmal auf dem Rückweg, Trefferbreite 1,2 Studs. Gefangen bei 2 Studs Abstand, spätestens nach 3 s weg. Mehrere Äxte gehen an verschiedene Gegner, sonst 20° gefächert. |

**Evolutionen (seit Paket 8):** Blade Storm (8 Klingen, Radius 10, doppelter Schaden, rot leuchtend) und Starfire (jeder Treffer eines Bolts explodiert mit 6 Studs Radius; die anderen Gegner in der Explosion bekommen den vollen Bolt-Schaden, Annahme) funktionieren. Der Server prüft die Voraussetzung (Waffe auf Level 5, noch nicht entwickelt, mindestens 1 des Items). Seit Paket 9 kommen sie aus Elite-Truhen (Abschnitt 8). Zum Testen bleibt der Knopf „Evolve weapons": Er hebt Waffen mit Evolution auf Level 5, gibt das fehlende Item einmal und entwickelt sie.

**Spark Mage:** seit Paket 5 wählbar (Spark Bolt, seit B2 +10 % Attack Speed). Das eigene Kostüm kommt mit dem Look in Paket 21.

**Items im Spiel (seit B2):** Items kommen aus dem Shop und aus Elite-Truhen (mindestens Uncommon, Abschnitt 8). Ihre Werte addieren sich mit Klasse, Werte-Karten und Team-Level (Blade Warden mit 2 × Vitality: 100 + 20 + 2 × 30 = 180 HP, Damage −2 %). Mehr Max HP heilt um den Unterschied, weniger kappt nur. Speed ändert das Lauftempo (nicht den Dash). Oben links im HUD stehen die Items mit Anzahl („Might x3") in der Farbe ihrer Stufe. Die Passive (Paket 6 bis B1) gibt es nicht mehr.

**Waffen und Werte (seit B2, `Config/Weapons.luau` → `class`, `scaling`, `rangeKeys`):** Jede Waffe hat eine Art, die bestimmt, welcher flache Schaden zählt, und Werte, die mit Range wachsen:

| Waffe | Art | Skalierung | wächst mit Range |
| --- | --- | --- | --- |
| Orbit Blades | Melee | 100 % Melee Damage | Radius (Hälfte) |
| Spark Bolt | Ranged | 100 % Ranged Damage | Reichweite |
| Shockwave | Melee | 100 % Melee Damage | Radius (Hälfte) |
| Chain Lightning | Elemental | 100 % Elemental Damage | Reichweite und Sprungweite |
| Thorn Trail | Elemental | 100 % Elemental Damage | – |
| Boomerang Axe | Ranged | 100 % Ranged Damage | Reichweite |

Allgemein: Krit-Chance 5 % pro Treffer plus Crit Chance, Krit = doppelter Schaden (`Config/Player.luau`). Schaden pro Level addiert sich auf den Grundwert (Level 5 mit zweimal +15 % = 130 %). Dann: Schaden = (Level-Schaden + Skalierung · flacher Schaden) · (1 + Damage/100), mindestens 1. Attack Speed teilt Cooldowns, Trefferpausen und Tick-Abstände (nie unter 0,2 s) und beschleunigt das Drehen der Klingen. Spark Mage feuert also alle 0,9 / 1,1 ≈ 0,82 s. Jeder Treffer mit Schaden würfelt Life Steal (Abschnitt 4).

## 7. Gegner, Elites & Boss

| Gegner | Rolle | HP | Tempo (Studs/s) | Schaden | XP | Ab Minute |
| --- | --- | --- | --- | --- | --- | --- |
| Shadeling | Schwarm, läuft direkt auf dich zu | 10 | 14 | 5 pro Kontakt | 1 | 0 |
| Brute | Tank, langsam, schiebt den Pulk | 60 | 8 | 12 pro Kontakt | 4 | 2 |
| Charger | lädt 0,9 s auf (glüht orange, roter Streifen zeigt die Bahn), stürmt dann geradeaus | 40 | 9, im Ansturm 38 | 8 pro Kontakt | 4 | 3 |
| Spitter | hält 30 Studs Abstand, schießt alle 2,5 s | 20 | 10 | 8 pro Projektil | 2 | 4 |
| Abyss Shadeling | stärkerer Shadeling, rote Augen | 18 | 15 | 8 pro Kontakt | 2 | 6 |
| Splitter | zerfällt beim Tod in 3 Splitlings | 32 | 11 | 7 pro Kontakt | 2 | 7 |
| Splitling | klein und schnell, nur aus Splittern | 6 | 15 | 3 pro Kontakt | 1 | 7 |
| Abyss Brute | stärkerer Brute, rote Augen | 140 | 8,5 | 18 pro Kontakt | 8 | 8 |
| Gloom Elite | beliebiger Typ, leuchtet, 1,5× so groß, ab 6:00 mit Eigenschaft | 8× | 0,9× | 1,5× | 25 + Truhe | 2, 4, 6 (2×), 8, 10 (2×) |
| The Lantern Eater | Boss | 4.000 × Spielerfaktor | 9 | siehe unten | – | nach Welle 12 |

**Boss: The Lantern Eater**

1. **Bodenschlag:** roter Kreis, Radius 14 Studs, 1,2 s Vorwarnung, 35 Schaden.
2. **Ansturm:** rennt geradeaus; Linie 0,8 s vorher sichtbar, 30 Schaden.
3. **Schatten rufen:** beschwört alle 25 s 20 Shadelings.
4. **Phase 2 ab 50 % HP:** alle Angriffe 25 % schneller.

Sieg = Boss-Truhe (3 Upgrades für jeden Spieler) + 150 Embers, danach Run-Ende-Screen.

**Spawn-Director**

```text
Spawnrate (Gegner/s)  = Ratenkurve(t) · Wellenstärke · fSpieler (· 2 im Swarm Rush)   t = Plan-Minute (1 pro Welle)
Ratenkurve            = 1 → 2,2 (Min. 1) → 3,6 (3) → 5 (6) → 6,8 (9) → 8,6 (12), linear dazwischen
Wellenstärke          = in jeder Welle von 0,7 auf 1,2 steigend (seit B1 ohne Atempause, dafür Shop);
                        Welle 12 zusätzlich · 1,4
Gegner-HP-Faktor      = 1 → 1,15 (2) → 1,5 (4) → 2 (6) → 2,8 (8) → 3,8 (10) → 5 (12)        (seit B2)
Gegner-Schadensfaktor = 1 → 1,1 (3) → 1,6 (6) → 2,4 (9) → 3,4 (12)                      (seit B2)
fSpieler              = 1 + 0.6 · (n − 1)               n = Spieler im Run → 1 / 1.6 / 2.2 / 2.8
```

Bis Paket 9 stiegen Rate und HP gerade an (`(1.5 + 0.55 · t)` und `1 + 0.15 · t`): Der Run begann gleich voll und fühlte sich danach immer gleich an (Owner-Feedback). Die Kurven starten ruhiger und steigen spät steiler; HP und Schaden gelten ab dem Spawn, beides mal Schwierigkeit. Seit B2 steigen HP (bis 5 statt 3,8) und Schaden (bis 3,4 statt 1,25) deutlich steiler: Die Werte der Spieler wachsen jetzt ohne Grenze, ohne steilere Gegner überlebten gute Bots alle 12 Wellen, ohne in den letzten Wellen in Gefahr zu kommen (Abschnitt 9). Brotato macht es genauso: Dort gewinnen Gegner jede Welle HP und Schaden dazu.

- Gleichzeitig maximal 80 Gegner + 20 pro weiterem Spieler (höchstens 140); beim Limit pausiert das Spawnen.
- Spawn-Ort: Ring 45–60 Studs um einen zufälligen Spieler, außerhalb der Sicht, nie in Hindernissen.
- Mischung (seit dem Spaß-Paket): fast jede Minute kommt etwas Neues, siehe Tabelle in Abschnitt 3. Ab Minute 4 rund 10 % Spitter (Paket 9, vorher 20 %: damit starben auch gute Spieler um Minute 5 am Dauerbeschuss), ab Minute 10 keine einfachen Shadelings und Brutes mehr. Genaue Anteile in `Config/Run.luau` → `spawn.mix`.
- „Swarm Rush" in Welle 6 und 10 (Plan-Minute 5 und 9): 60 % der Welle doppelte Spawnrate, nur Shadelings.

**Stand im Code (seit Paket 3):** Der SpawnDirector kann Rate, Spielerfaktor, Obergrenze, Spawn-Ring, Mischung nach Minute und HP-Faktor (mal Schwierigkeit). Er spawnt nur in der Phase „Running", um einen zufälligen lebenden Teilnehmer, und rechnet n aus den Teilnehmern, die noch im Server sind. Swarm Rush, Elites und die Schüsse der Spitter kamen mit Paket 9.

**Stand im Code (seit Paket 9):** Werte in `Config/Enemies.luau` (Spitter `ranged`, `elite`) und `Config/Run.luau` (`spawn`, `coop`). Annahmen fürs Spielgefühl, Urteil des Owners steht aus:

| Was | Umsetzung |
| --- | --- |
| Spitter-Schüsse | Ein Spitter schießt alle 2,5 s auf den nächsten Spieler, aber nur, wenn der höchstens 34 Studs entfernt ist (er hält 30). Rosa Glutkugel mit Schweif (seit Paket 9d), 18 Studs/s, fliegt 50 Studs weit, Trefferkreis 0,6 Studs, 8 Schaden (Rüstung und 0,5 s Schutz gelten). Sie zielt 30 % vor: Wer stur geradeaus läuft, wird eher getroffen; Haken schlagen oder Dash hilft. Ruinen halten Schüsse auf (Deckung). Der erste Schuss jedes Spitters kommt versetzt, damit nicht alle gleichzeitig feuern. |
| Gloom Elite | Ab 2:00 alle 2 Minuten eine Elite, auch über der Gegner-Obergrenze; der Typ kommt aus der aktuellen Mischung. Werte wie in der Tabelle oben (8× HP, 0,9× Tempo, 1,5× Schaden auch bei Schüssen, 1,5× so groß, 25 XP), dazu 2,25× Masse (schiebt normale Gegner beiseite). Aussehen: königsviolett und gold mit Sonnenstrahlen-Krone (seit Paket 9d, siehe Abschnitt 14), goldene Augen, Leuchten, rote Lebensleiste über dem Kopf. Alle bekommen die Meldung „A Gloom … appeared! Kill it for a chest." |
| Swarm Rush | 5:00 und 9:00 für 30 s: doppelte Spawnrate, nur Shadelings. Neu: beim Start zusätzlich ein geschlossener Ring aus 24 Shadelings in 45 Studs um jeden Spieler (bis zur Obergrenze). Meldung „Swarm Rush!". |
| Gegen Weglaufen | 35 % der Spawns eines laufenden Spielers landen in einem 120°-Kegel vor ihm. Gegner, die weiter als 80 Studs von allen Spielern weg sind, tauchen jede Sekunde neu auf dem Spawn-Ring auf (wie frisch gespawnt). Ist die Obergrenze voll, wandern zusätzlich die 5 entferntesten Gegner über 40 Studs nach vorn, sonst konnte man mit einer vollen Schlange hinter sich im Kreis laufen und es kam nichts Neues. |

**Stand im Code (Spaß-Paket nach Paket 9, Teil 1):** Werte in `Config/Enemies.luau` (`charge`, `split`, `elite.affixes`) und `Config/Run.luau` (`spawn.rateCurve`, `hpCurve`, `damageCurve`, `waves`, `mix`, `elites`). Annahmen fürs Spielgefühl:

| Was | Umsetzung |
| --- | --- |
| Wellen | 12 Wellen (`Util/RunSchedule.luau`, Server und HUD rechnen gleich), seit B1 20–60 s lang mit Shop dazwischen, vorher je 1 Minute mit 12 s Atempause. In jeder Welle steigt die Rate von 0,7× auf 1,2×; die letzte läuft mit 1,4×. Elites und neue Gegnerarten kommen zu Wellenbeginn. |
| Charger | Ist ein Spieler höchstens 24 Studs entfernt, bleibt er stehen und lädt 0,9 s auf (glüht orange, roter Streifen auf dem Boden zeigt die Bahn). Dann stürmt er mit 38 Studs/s in die anfangs gezielte Richtung, bis 30 Studs, eine Ruine, der Rand oder ein Spieler ihn stoppt; danach 1,2 s Pause und 3 s normales Laufen. Ausweichen: zur Seite gehen oder dashen. |
| Splitter | Zerfällt beim Tod in 3 Splitlings (behalten HP- und Schadensfaktor des Splitters, dürfen über die Obergrenze bis zum Maximum 140). |
| Abyss-Gegner | Stärkere Versionen von Shadeling und Brute mit dem gleichen Modell, aber roten Augen. |
| Elite-Eigenschaften | Ab 6:00 bekommt jede Elite zufällig eine: **Swift** (1,45× Tempo), **Armored** (nimmt nur 60 % Schaden), **Summoning** (ruft alle 6 s 4 Shadelings um sich, solange ein Spieler nahe ist). Sie steht über der Lebensleiste („Armored") und im Namen („Armored Gloom Brute"). |
| Rückstoß | Spark Bolt schiebt getroffene Gegner 0,8 Studs zurück, Boomerang Axe 1,5 Studs (nur Treffer, die nicht töten). |

Ein Gegner-Typ ist im Snapshot ein Byte; Elites senden Typ + 128, so kennt der Client sie ohne Zusatzdaten. Seit dem Spaß-Paket kommt ein zweites Byte dazu (Modus des Chargers und Elite-Eigenschaft, Abschnitt 15).

## 8. Koop-Regeln

- **XP:** Jedes Orb zählt fürs ganze Team. XP-Bedarf pro Level × Spielerfaktor.
- **Level-up ohne Pause:** jeder Spieler eigene Karten (seit B2 4 Werte-Karten, seit B1 erst am Wellenende); während der Wahl kann man weiterlaufen und dashen und bleibt verwundbar (Owner-Wunsch nach Paket 9; Schalter `levelUp.freezeWhileChoosing`), Waffen feuern weiter; nach 10 s wird die erste Karte automatisch gewählt.
- **Truhen:** Elite-Truhe gibt jedem Spieler im Umkreis von 20 Studs eine eigene Belohnung.
  Seit Paket 9: Die Truhe liegt, wo die Elite starb (goldene Kiste mit Lichtsäule, Pfeil am Bildschirmrand, wenn sie außer Sicht ist), und öffnet sich, sobald ein lebender Spieler auf 3,5 Studs heran ist. Jeder lebende Spieler im Umkreis bekommt: eine Evolution, wenn er eine nehmen darf; sonst (seit B2) ein Item, mindestens Uncommon, Stufe nach Welle und Luck gewürfelt wie im Shop (Banner „CHEST – Might x2 – -10 Max HP, +5% Damage"); gibt es keins mehr, volle Heilung. Bis B1: +1 Level einer Waffe oder eines Passivs. Dazu heilt die Truhe jeden Belohnten um 50 % seiner max. HP (neu, Annahme: ohne Heilung bringt jeder Spitter-Treffer bleibenden Schaden). Die eigene Belohnung erscheint groß in der Bildschirmmitte („CHEST – Starfire – Spark Bolt evolved!"). Truhen verschwinden am Run-Ende.
- **Down & Wiederbeleben:** bei 0 HP „down" (30-s-Timer); Teammate steht 3 s daneben → Wiederbelebung mit 40 % HP. Timer abgelaufen → Zuschauer bis Run-Ende, Embers anteilig.
- **Run-Ende:** alle gleichzeitig down = Run vorbei.
- **Revive-Token (Kauf):** höchstens 1 pro Spieler und Run.
- **Ein-/Aussteigen:** kein Beitritt in laufende Runs (v1); wer geht, fällt raus, Spawn-Director rechnet ab nächstem Tick neu.
- **Solo:** jederzeit, Spielerfaktor 1. **Kein Friendly Fire, kein PvP.**

## 9. XP-Kurve, Level-ups & Balancing-Startwerte

```text
XP für Level L → L+1 = round((L + 3)² · fSpieler)        (seit B2, Brotatos Kurve)
```

Solo: L1→2 = 16 XP, L10→11 = 169 XP, L20→21 = 529 XP; bis Level 20 zusammen rund 3.800 XP, bis Level 25 rund 6.900 XP. Gute Spieler (Bots, die fast jedes Orb holen) enden nach 12 Wellen bei Level 20–27 (Balance-Simulation unten). Bis B1 galt round((5 + 2,4 · L^1,3) · fSpieler) mit Ziel Level 34–36; mit den Werte-Karten ist ein Level viel mehr wert, deshalb die steilere Kurve.

**Werte-Karten (seit B2, `Config/Run.luau` → `levelUp`, `Config/Stats.luau` → `upgrade`):** Jedes Level gibt +10 Max HP (automatisch) und eine Wahl aus 4 Karten mit verschiedenen Werten. Jede Karte hat eine Stufe I–IV (Farbe wie bei Items); die Stufe wird wie im Shop gewürfelt, nur mit dem Level statt der Welle und mit Luck. Feste Stufen wie in Brotato: Level 5 Uncommon, Level 10, 15 und 20 Rare, ab Level 25 jedes 5. Level Legendary. Neu würfeln kostet Shards zum Shop-Preis (Abschnitt 3); es gibt keinen kostenlosen Neuwurf mehr.

| Wert | I | II | III | IV |
| --- | --- | --- | --- | --- |
| Max HP | +30 | +60 | +90 | +120 |
| HP Regeneration | +2 | +3 | +4 | +5 |
| Life Steal | +1 % | +2 % | +3 % | +4 % |
| Damage | +5 % | +8 % | +12 % | +16 % |
| Melee Damage | +2 | +4 | +6 | +8 |
| Ranged Damage | +1 | +2 | +3 | +4 |
| Elemental Damage | +1 | +2 | +3 | +4 |
| Attack Speed | +5 % | +10 % | +15 % | +20 % |
| Crit Chance | +3 % | +5 % | +7 % | +9 % |
| Range | +15 | +30 | +45 | +60 |
| Armor | +1 | +2 | +3 | +4 |
| Dodge | +3 % | +6 % | +9 % | +12 % |
| Speed | +3 % | +6 % | +9 % | +12 % |
| Luck | +5 | +10 | +15 | +20 |
| Harvesting | +5 | +8 | +10 | +12 |

Waffen und Items gibt es nicht mehr auf Karten, nur im Shop und in Truhen. Bis B1: 3 Karten aus Waffen und Passiven, 1 kostenloser Neuwurf pro Run.

**Stand im Code (seit Paket 6; Werte in `Config/Run.luau` → `xpCurve`, `xpOrbs`, `levelUp`):**

- Jeder getötete Gegner lässt ein XP-Orb mit seinem XP-Wert fallen. Lebende Teilnehmer sammeln alle Orbs im Aufsammelradius (8 Studs, Magnet mehr) sofort ein; das Orb fliegt sichtbar zum Sammler. Die XP gehen an ein gemeinsames Team-Level, der Bedarf rechnet mit den Teilnehmern, die gerade im Server sind. Spieler, die down sind, sammeln nichts.
- Annahme: höchstens 300 Orbs gleichzeitig am Boden; darüber geht die XP eines neuen Orbs in das nächstgelegene (es wird größer und färbt sich: blau ab 1, grün ab 4, rot ab 20 XP). Orbs bleiben liegen, bis jemand sie holt, und verschwinden am Run-Ende.
- Pro Team-Level bekommt jeder Teilnehmer, der nicht „Out" ist, eigene Karten. Mehrere Level-ups stauen sich, die nächste Wahl kommt direkt nach der vorigen („2 more waiting"; seit B1 alle am Wellenende). Seit dem Feedback nach Paket 9 läuft und dasht man während der Wahl weiter und kann getroffen werden (`levelUp.freezeWhileChoosing = false`); nur wenn der Schalter an ist, steht man still, ist unverwundbar und danach 0,5 s geschützt. Nach 10 s wird die erste Karte gewählt; ein Neuwurf gibt neue Karten, möglichst andere Werte, und startet die 10 s neu.
- Karten reagieren erst 0,4 s nach dem Erscheinen (Annahme), damit ein Daumen auf dem Stick nicht versehentlich wählt. Am PC auch Tasten 1–4.
- Bis B1 füllten „Heal" und „Embers" auf, wenn weniger Items übrig waren als Karten; mit Werte-Karten (seit B2) gibt es immer genug, die Embers-Karte entfällt.
- Evolutionen sind nie Karten, nur Truhen (Paket 9).

**Stand Paket 7 (Balance-Simulation, `tests/balance/BalanceSim.luau`):** Ganze Solo-Runs mit dem echten Server-Code und Computer-Spielern, je 3 Durchläufe. Noch ohne Elites, Swarm Rush und Spitter-Schüsse (Paket 9), daher eher zu leicht.

| Spielweise | Blade Warden | Spark Mage |
| --- | --- | --- |
| steht still | tot nach 2:20–2:30, Level 6–9 | tot nach 2:07–2:13, Level 3–4 |
| weicht bis 3:00 aus, dann still | danach noch 15–46 s | danach noch 11–17 s |
| hält Gegner auf Waffenabstand, sammelt Orbs | tot nach 2:40–5:20, Level 12–21 | meist 12:00 überlebt, Level 34–40 |
| weicht perfekt aus, sammelt Orbs | 12:00 überlebt (tötet aber kaum) | 12:00 überlebt, Level 37–39 |

Folgerungen: Das Ziel „ohne Ausweichen ab Minute 3 in unter 20 s tot" passt im Schnitt. Wer nur wegläuft, überlebt, weil Spieler (16) schneller sind als Shadelings (14); das fängt Paket 9 mit Swarm Rush, Elites und Spitter-Schüssen ab. Ein guter Fernkampf-Spieler erreicht Level 35–40, also etwas über dem Ziel 34–36 (die Bots sammeln fast jedes Orb). Der Blade Warden war deutlich schwächer als der Spark Mage, deshalb machen die Orbit Blades jetzt 15 statt 12 Schaden (ein Treffer tötet einen Shadeling bis Minute 2) und drehen mit 240 statt 180°/s. Er bleibt die riskantere Klasse; Brutes im Nahkampf sind tödlich. Nächster Schritt: Urteil aus dem Freunde-Test (Anleitung in `docs/PLAYTEST.md`).

**Stand Paket 8:** Mit allen sechs Waffen im Kartenpool wird es noch leichter: Spark Mage überlebt ausweichend oder auf Abstand kämpfend immer bis 12:00 und tötet praktisch alles (Level 41, etwa 3.400 Kills, über dem Ziel 34–36); der Blade Warden auf Abstand stirbt weiter nach 3:09–4:59. Stillstehen bleibt tödlich (Blade Warden 1:18–2:21, Spark Mage 0:32–2:17), ab Minute 3 still: nach 9–46 s tot. Keine Waffe dominiert: Bei vollen Runs teilen sich Spark Bolt bzw. Orbit Blades den Schaden mit Boomerang Axe, Chain Lightning, Shockwave und Thorn Trail; Axe und Chain Lightning liegen etwas vorn. Den Druck bringt Paket 9; danach neu messen.

**Stand Paket 9:** Mit Spitter-Schüssen, Elites, Swarm Rush, Spawns in Laufrichtung und zurückkehrenden Gegnern wird es deutlich härter. Die Bots weichen jetzt Schüssen aus (spät, wie ein ordentlicher Spieler), gehen auf Spitter los und holen Truhen; 6 Durchläufe je Spielweise:

| Spielweise | Blade Warden | Spark Mage |
| --- | --- | --- |
| steht still | tot nach 1:17–2:21 | tot nach 2:09–2:46 |
| ab Minute 3 still | danach noch 2–67 s | danach noch 3–75 s |
| läuft nur im Kreis | tot nach 3:09–7:00 | tot nach 3:02–6:46 |
| weicht aus, sammelt, jagt Spitter | tot nach 4:50–11:43 | 3 von 6 bis 12:00 (Level 40–41), sonst tot nach 5:02–7:39 |
| hält Gegner auf Abstand | tot nach 2:12–3:49 | 1 von 6 bis 12:00 (Level 40), sonst tot nach 5:02–7:57 |

Folgerungen: Nur Weglaufen reicht nicht mehr, gute Spieler kommen nicht mehr sicher durch, und wer 12:00 erreicht, hat meist eine Evolution aus einer Truhe. Der Hauptschaden der guten Bots kommt von Spitter-Schüssen. Die Spitze ist eher etwas zu hart; das Urteil kommt aus dem Studio-Test. Stellschrauben, falls es zu schwer ist: Spitter-Anteil, Vorhalten (`aimLead`) oder Feuerreichweite der Spitter, Heilung der Truhe. Stillstehen ab Minute 3 überlebt länger als das Ziel (unter 20 s), weil die Truhe bei 2:00 heilt.

**Stand Spaß-Paket Teil 1:** Mit Wellen, ruhigem Start, steileren Kurven, Chargern, Splittern, Abyss-Gegnern und Elite-Eigenschaften. Die Bots laufen seitdem nicht mehr durch die Außenwände (vorher standen sie manchmal außerhalb der Arena und wurden nie erreicht) und weichen Chargern aus, ohne dabei die anderen Gegner zu vergessen. Vergleich ist der Stand davor mit denselben Bots (Paket 9 plus Laufen beim Kartenwählen, also ohne Schutz in der Wahl); 6 Durchläufe je Spielweise:

| Spielweise | Blade Warden | Spark Mage | vorher: Blade Warden | vorher: Spark Mage |
| --- | --- | --- | --- | --- |
| steht still | tot nach 1:33–2:46 | tot nach 0:49–3:20 | 1:10–2:21 | 2:04–2:23 |
| ab Minute 3 still | danach noch 0–25 s | danach noch 10–85 s | 0–44 s | 7–71 s |
| läuft nur im Kreis | tot nach 2:45–4:23 | tot nach 3:44–8:20 | 2:47–4:17 | 4:08–4:48, 1× 12:00 |
| weicht aus, sammelt, jagt Spitter | tot nach 4:42–9:45 | tot nach 6:47–11:22 (meist ≈ 7:30), Level 26–43 | 4:45–7:40 | 7:13–7:43, 2× 12:00 |
| hält Gegner auf Abstand | tot nach 2:49–5:51 | tot nach 4:52–9:39 | 3:06–4:18 | 5:03–6:58, 2× 12:00 |

Folgerungen: Bis Minute 7 etwa so schwer wie vorher, danach deutlich härter; gerade kommt kein Bot bis 12:00. Das ist für Teil 1 gewollt: Teil 2 macht den Spieler mit Level-Sprüngen, seltenen Karten, Krits und Glück stärker, danach wird neu gemessen. Der meiste Schaden kommt jetzt von Brutes und Chargern im Kontakt, später von Abyss Brutes und Elites; Spitter-Schüsse treffen seltener. Die erste Fassung war viel zu hart (alle Bots tot bis 6:30, viele genau beim Swarm Rush um 5:46); danach: sanftere Kurven, Charger 8 statt 14 Schaden, Elite-Eigenschaften erst ab 6:00 statt 4:00, Armored nimmt 60 % statt 50 %, Abyss Shadeling 18 statt 22 HP, Wellen steigen bis 1,2× statt 1,3×, Schaden bei 12:00 1,25× statt 1,6×. Die Streuung zwischen den Durchläufen ist groß; kleine Unterschiede zwischen Varianten zeigen 6 Durchläufe nicht.

**Run-Statistik (seit Paket 7):** Der Ergebnis-Bildschirm zeigt Team-Level, Kills des Teams und pro Spieler Kills, Schaden und erlittenen Schaden (`RunStatsService`). Der Server schreibt am Run-Ende eine Zusammenfassung ins Output (im Live-Spiel: F9 → Server): Dauer, Team-Level pro Minute, Kills nach Gegnertyp, Waffen mit Level/Schaden/Kills und Items jedes Spielers (seit B2, „Items: Might x2 · Focus x1").

| Balancing-Ziel | Wert |
| --- | --- |
| Spark Bolt tötet einen Shadeling | mit 1 Treffer |
| Erst-Runs, die Minute 8 erreichen | ≈ 60 % |
| Bosssieg in den ersten 3 Runs (Normal) | 25–35 % |
| Ohne Ausweichen tot ab Minute 3 | in unter 20 s |
| Run-Dauer inkl. Boss | ≈ 14 Min |

**Stand Paket B1 (Brotato-Richtung, Wellen mit Shop):** Die Bots kaufen nach jeder Welle, was sie sich leisten können (erst Eigenes, dann das Billigste; 2–19 Käufe pro Run), und drücken dann Ready. Die Zeiten sind Kampfzeit (ohne Shop), insgesamt gibt es 9:00; „w9" = in Welle 9 gestorben. 6 Durchläufe je Spielweise:

| Spielweise | Blade Warden | Spark Mage |
| --- | --- | --- |
| steht still | Welle 3–5 (1:08–2:21) | Welle 3–5 (1:12–2:23) |
| ab Welle 7 still | Welle 4–7 | Welle 7–8 |
| läuft im Kreis | Welle 4–9 | Welle 8–11 |
| weicht aus, sammelt | Welle 5–9, meist 9 | Welle 9, einmal 11 |
| hält Abstand | Welle 3–9, meist 9 | Welle 9, einmal 11 |

Folgerungen: Die volle Heilung nach jeder Welle trägt durch die ersten Wellen; die Wand ist Welle 9 (erste 60-s-Welle mit Abyss Brutes). Kein Bot schafft Welle 12, wie nach Teil 1 des Spaß-Pakets. Das ist bis B2 gewollt: Werte, Items und Seltenheit machen den Spieler stärker, danach wird neu gemessen. Stellschrauben, falls es vorher zu hart ist: Grundpreise in `Config/Shop.luau`, Shards pro XP, HP-Kurve ab Plan-Minute 8.

**Stand Paket B2 (Werte, Items, Werte-Karten):** Die Bots wählen jetzt Werte-Karten und kaufen nach einem einfachen Geschmack (Schadensart der Klasse, dann Max HP, Damage, Attack Speed, Armor; Wert pro Shard), eigene Waffen vor neuen. Am Run-Ende druckt die Simulation Build und Werte, pro Welle das niedrigste HP. Erste Messung mit den alten Gegnerkurven: Ausweichende und auf Abstand kämpfende Bots überlebten 23 von 24 Runs bis zum Ende von Welle 12 und hatten in den Wellen 10–12 meist noch über 80 % HP. Mit unbegrenzt wachsenden Werten war das Ende also viel zu leicht. Drei Varianten mit steileren Gegnerkurven getestet; übernommen: HP-Faktor bis 5 und Schaden bis 3,4 (Abschnitt 7). Ergebnis (Kampfzeit, „w9" = in Welle 9 gestorben; Ausweichen und Abstand mit 12 Durchläufen, der Rest mit 6):

| Spielweise | Blade Warden | Spark Mage |
| --- | --- | --- |
| steht still | Welle 3 (0:54–1:13) | Welle 3–4 (1:04–1:46) |
| ab 3:00 still | danach noch 13–46 s | danach noch 31–45 s, einmal 150 s |
| läuft im Kreis | 1 von 6 bis zum Ende, sonst Welle 4–9 | 1 von 6 bis zum Ende, sonst Welle 7–12 |
| weicht aus, sammelt | 6 von 12 bis zum Ende, sonst Welle 5–11 | 9 von 12 bis zum Ende, sonst Welle 11–12 |
| hält Abstand | 7 von 12 bis zum Ende, sonst Welle 5–9 | 4 von 12 bis zum Ende, sonst Welle 5–12 |

Folgerungen: Gute Bots erreichen in gut der Hälfte der Runs (26 von 48) das Ende von Welle 12 und kommen in den letzten Wellen oft in echte Gefahr; Stillstehen ist früh tödlich, und ab 3:00 stillstehen hält jetzt meist unter 50 s (Ziel unter 20 s, vorher 45–170 s). Die Wand bleibt Welle 9 (erste 60-s-Welle, Abyss Brutes), einzelne Bots sterben schon am Ende von Welle 5. Der Boss (Paket 10) macht es noch schwerer; das Ziel „Bosssieg in den ersten 3 Runs 25–35 %" ist damit erreichbar. Die Bots bauen einfach; Menschen mit klugen Builds sind vermutlich stärker, das Urteil kommt aus dem Studio-Test. Stellschrauben: `hpCurve`, `damageCurve` in `Config/Run.luau`, Item-Preise in `Config/Items.luau`, Kartenwerte in `Config/Stats.luau`.

## 10. Meta-Progression & Schwierigkeitsgrade

**Embers verdienen** (ein Run bringt je nach Dauer etwa 100–350)

| Quelle | Embers |
| --- | --- |
| pro überlebter Minute | 10 |
| pro Elite | 15 |
| Boss besiegt | 150 |
| tägliche Quest | 50–100 |

**Geplant (Paket 13, Brotato-Referenz):** Brotato hat keine dauerhaften Stärke-Boni, nur Freischaltungen. Die Stärke-Talente unten fallen deshalb weg (Vorschlag vom 29.10.2026, Owner hat den Plan abgenickt). Charaktere, Waffen und Items werden über Erfolge freigeschaltet („Gewinne einen Run mit X", „Töte 2.000 Gegner"); Embers kaufen Freischaltungen und Kosmetik früher frei. Statt Normal/Hard/Nightmare kommen Gefahrenstufen 0–5 pro Charakter (Paket B11). Die Tabellen unten sind der alte Plan.

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
- **HUD:** oben Team-XP-Leiste mit Level, Timer Mitte, Kills rechts; unten links HP, unten rechts Dash; Waffen/Passive oben links; Teammates außer Sicht als Randpfeile. Seit Paket 5 steht oben links die Waffenliste mit Level („LV 2", ab Level 5 „MAX"), seit Paket 6 darunter die Passive und oben Mitte die Team-XP-Leiste mit „LV n" über dem Timer; in der Team-Liste steht „picking", solange jemand Karten wählt. Seit B2 stehen statt der Passive die Items da („ITEMS (5)", je Zeile „Might x3" in der Farbe der Stufe, höchstens 8 Zeilen, dann „+n more").
- **Wellen (seit dem Spaß-Paket nach Paket 9, seit B1 mit Shop):** der große Timer zeigt die Restzeit der Welle bzw. des Shops; darunter „Wave 3 / 12", im Shop grün „Shop · wave 4 / 12 next", in der letzten Welle rot „Final wave 12 / 12". Zu Beginn jeder Welle ein großes „WAVE n" oben in der Mitte (2,6 s), darunter, was sie bringt: „New: Chargers", „Swarm Rush!", „2 Gloom Elites!", „Final wave". Rot, wenn etwas Neues kommt. Der Client rechnet das selbst aus der Konfiguration (`Util/RunSchedule.luau`), ohne eigene Remote.
- **Shop (seit B1, seit B2 mit Items):** neben dem Timer immer die eigenen Shards (türkis). Zwischen den Wellen verdeckt ein dunkler Hintergrund die Arena (unter dem HUD, Titel „WAVE n CLEARED"). Nach den Level-up-Karten ein Fenster „SHOP" mit „Wave 3 cleared · next wave in 34", 4 Karten (Badge „NEW"/„LV 3", bei Items Stufe und Anzahl wie „RARE · X2", Name, Effekt, Preis in Shards, rot wenn zu teuer, „SOLD" nach dem Kauf), „Reroll (5 Shards)" und „READY" (danach „WAITING…", nochmal tippen = weiter einkaufen). Seit B2 haben Item-Karten Rahmen und Badge in der Farbe ihrer Stufe (grau, blau, violett, rot) und zeigen ihre Werte zeilenweise, Vorteile grün, Nachteile rot. Rechts daneben während Kartenwahl und Shop die Werte-Liste „STATS" (`StatsController`).
- **Treffer-Gefühl (seit dem Spaß-Paket nach Paket 9):** eigene Schadenszahlen über den Gegnern (weiß, kritische Treffer groß, golden, mit „!"), Partikel-Puff beim Tod, Kamera-Wackeln, wenn man selbst getroffen wird, bei Elite-Tod und Truhe, goldener Lichtring um die Figur beim Level-up.
- **Level-up:** 3 große Karten (Icon, Name, eine Zeile Effekt, „NEW"/„LV 3"), daumentauglich. Seit Paket 6: Fenster in der Bildmitte mit „LEVEL n", „Pick one", drei Karten (Icon = Kreis mit Anfangsbuchstaben, gelb Waffe, grün Passiv, violett Belohnung), einem Balken, der bis zur automatischen Wahl abläuft, und „Reroll (1 left)". Seit B2 vier Werte-Karten (Tasten 1–4) mit Wert-Name, Effekt („+8% Damage") und Stufe als Badge und Rahmenfarbe; der Knopf heißt „Reroll (n Shards)" und ist grau, wenn die Shards fehlen.
- **Run-Ende:** Zeit, Kills, Schaden pro Waffe, Embers inkl. Boni, großer „Nochmal"-Knopf.
- **Shop, Talente, Pass:** je ein Fenster, max. 2 Taps bis Kauf.

**Erster Start (FTUE):** Erst-Join landet direkt in „First Night" (3-Min-Solo-Run, leichter) → Pfeil „Move" → erstes Level-up nach ~5 s mit „Pick one" → Minute 2 Mini-Elite mit Truhe → Minute 3 Run-Ende, dann Lobby mit Hinweis auf den Talent-Altar.

**Barrierefreiheit:** Bildschirmwackeln und Schadenszahlen abschaltbar (bis zum Einstellungsmenü in Paket 14 als Schalter in `Config/Feedback.luau`); Gefahrzonen mit Farbe und Muster; Musik/Effekte getrennt regelbar.

## 14. Art-Direction & Audio

- **Stil (seit Paket 9d, Wunsch des Owners: „im Style von Deadlock"): okkultes Art déco.** Gealtertes Messing und Gold, Porzellanmasken, Gasmasken und Kutten, rußschwarze Kreaturen, dazu leuchtende Augen, Linsen und Risse in kräftigen Neonfarben, Sonnenstrahlen- und Zackenformen. Übernommen ist nur die Stimmung: keine Figuren, Namen, Logos oder Designs aus Deadlock.
- Low-Poly aus einfachen Formen, flache Materialien (SmoothPlastic, Metal für Messing, Neon für alles, was leuchtet), wenige Texturen. Spieler/Laternen warm-gelb, die Gloom (Gegner) dunkel mit leuchtenden Akzenten; jede Gegnerart hat eine eigene Silhouette und eine eigene Augenfarbe, damit man sie in der Traube erkennt.
- Gefahrzonen rot (z. B. der Sturm-Streifen des Chargers).
- Avatare R15; Klassen = Kostüme über dem Avatar.
- Gegner ohne Humanoids: im Code aus 5–20 einfachen Teilen gebaut (Block, Kugel, Ei, Zylinder, Keil; keine hochgeladenen Meshes, `EnemyRenderer/Models.luau`), Bewegung per Code über ein einfaches Rig: Der Körper wippt, schwankt und neigt sich beim Laufen, Beine und Arme schwingen mit der gelaufenen Strecke, das Rauchfass pendelt, Kronen und Irrlichter drehen sich. Gesichter sind leicht nach oben gekippt, damit man sie aus der Schräg-Kamera sieht.

| Gegner | Look (seit Paket 9d) |
| --- | --- |
| Shadeling | gebückter Kapuzen-Schatten mit schräger Porzellanmaske, violette Schlitzaugen, Messing-Amulett, Klauen |
| Brute | Gasmasken-Soldat: Messing-Brustpanzer, Schulterplatten, Helm mit Kamm und bernsteinfarbenen Linsen, Filter, Tank auf dem Rücken, schwingende Fäuste |
| Spitter | Kultist in Robe mit Messingsaum, Maske mit glühendem Mund, Sonnenstrahl-Scheibe hinter dem Kopf, schwingendes Rauchfass; schießt rosa Glut |
| Charger | vierbeiniger Widder: Knochenschädel mit gedrehten Hörnern, Panzersattel, Ofen mit Schornstein auf dem Rücken. Beim Ausholen duckt und zittert er, Körper rot, Ofen und Augen weißglühend, roter Streifen am Boden zeigt die Sturmbahn |
| Splitter | gesprungene Urne mit Messingband, türkis leuchtenden Rissen und drei schwebenden Irrlichtern, auf zwei Füßchen |
| Splitling | kleines türkises Irrlicht mit Flammenspitze und Maskenscherbe, hüpft |
| Abyss-Varianten | blutschwarz, geschwärzte Bronze, Obsidian-Maske, rote Augen, Hörner und Stacheln |
| Gloom Elite | königsviolett und gold, goldene Augen, drehende Sonnenstrahlen-Krone, Leuchten, Lebensleiste mit dem Namen der Eigenschaft. Swift: cyan Schweif; Armored: Stahl statt Messing; Summoning: zwei grüne Irrlichter kreisen |

- **Waffen und Fähigkeiten (seit Paket 9d):** Alles, was leuchtet, hat einen weißen Kern in einem farbigen, durchscheinenden Schein; was fliegt, zieht einen Schweif. Feste Teile sind Messing.
  - Spark Bolt: weißblauer Bolzen mit Schein und Schweif, Funken beim Treffer. Starfire: golden, Explosion als weißer Blitz, Feuerring und Glut.
  - Orbit Blades: Messingklingen mit leuchtender Schneide vorn in Drehrichtung, jede zieht einen Lichtbogen. Blade Storm: dunkles Eisen, rote Schneide.
  - Shockwave: weißer Blitz an der Figur, ein Ring aus 12 leuchtenden Art-déco-Segmenten läuft über eine goldene Scheibe nach außen, Staub vom Boden.
  - Chain Lightning: weißer Kern, darum violette Bögen, die 25-mal pro Sekunde neu zucken, Funken an jedem Getroffenen.
  - Thorn Trail: dunkle Dornenranke am Boden, aus der drei giftgrüne Dornen schießen und am Ende wieder versinken.
  - Boomerang Axe: dunkler Griff, zwei Messingköpfe mit glühenden Schneiden, zieht beim Drehen einen Feuerring.
  - Dash: goldener Lichtstreifen hinter der Figur, Funken und eine Rauchwolke am Start (bei allen Spielern sichtbar).
  - Spitter-Schüsse: heller Kern in rosa Schein mit Schweif, Funken beim Einschlag.
  - Tod: Funken und aufsteigende Seelen-Irrlichter in der Augenfarbe, Elites zusätzlich Glut.
- Assets: Roblox-KI-Generierung und Creator Store, nur mit erlaubter Nutzung; keine fremden Marken/Figuren/Memes.
- VFX sparsam und gepoolt (`src/client/Vfx/Bursts.luau`: Funken, Glut, Seelen, Rauch, Staub; ein Emitter pro Stil und Farbe, Partikel per `Emit`); Audio aus der Roblox-Bibliothek, eigener Boss-Track.
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
  Config/            Player, Weapons, Items, Stats, Evolutions, Enemies, Classes, Run, Talents,
                     Economy, Difficulty, Simulation, Map, Admin, Camera, Feedback, Shop
  Net/               Definition aller RemoteEvents und Snapshot-Format
  Util/              SpatialHash, Signal, Loader, Format, Orbit, UpgradeText, EnemyKinds, RunSchedule, StatMath
src/server/          → ServerScriptService.Server
  Services/          RunDirector, SpawnDirector (+ SpawnRules), EnemySim (+ World, Volleys), CombatService,
                     WeaponService (+ Arsenal, WeaponStats, Behaviors/ je Waffe), ExperienceService (+ OrbField,
                     Progression), UpgradeService (+ UpgradePool), ShopService (+ ShopRules, seit B1), StatService (seit B2),
                     LootService, ReviveService, PlayerDataService, MonetizationService, AnalyticsService,
                     MapService (Platzhalter-Karte), AdminService (Test-Befehle)
src/client/          → StarterPlayer.StarterPlayerScripts.Client
  Controllers/       InputController, CameraController, PlayerStateController, EnemyRenderer (+ SnapshotBuffer, Models),
                     LoadoutController, WeaponRenderer (+ VisualKit, Visuals/ je Waffe), ProgressController,
                     LevelUpController, ShopController, StatsController, XpOrbRenderer, EnemyShotRenderer, ChestController, HUDController, VFXController,
                     RunStateController, LobbyController, ResultsController, NotifyController, DebugController
  UI/                Theme, Widgets (UI im Code gebaut)
tests/               Unit-Tests für reine Module (Runner in tools/luau-test-runner)
```

**Gerüst (seit Arbeitspaket 2)**

- **Lebenszyklus:** Server- und Client-Bootstrap laden jedes Modul in `Services` bzw. `Controllers` über `Util/Loader`, alphabetisch. Oberste Ebene legt nur Zustand und Signals an, `init()` verbindet Remotes und Events (ohne zu warten), danach läuft `start()` je Modul in eigenem Thread. Module requiren sich direkt; RunDirector hängt nur von MapService und PlayerDataService ab, alle anderen hängen sich an RunDirector.
- **RunDirector** besitzt den Run-Ablauf (Regeln als reine Zustandsmaschine in `RunDirector/RunFlow.luau`, mit Unit-Tests). Signals für spätere Pakete: `RunStarted(players)`, `RunEnded(results)`, `PhaseChanged(phase, previous)`, `ParticipantStateChanged(player, state)`. Befehle: `setParticipantState` (ReviveService), `endRun("Victory")` und `setBossEncounter` (Boss), `getElapsed()` (SpawnDirector).
- **RunState:** Der Server schickt bei jeder Änderung den vollständigen, kleinen Zustand (`Net/Types.luau`) an alle; Timer laufen auf dem Client über `workspace:GetServerTimeNow()`, also kein Senden pro Sekunde. Ein neuer Client holt sich den Stand mit `RequestSync`.
- **Phasen:** Lobby → Countdown → Running ⇄ Shop (seit B1, nach jeder Welle außer der letzten) → Boss → Ended → Lobby. Gegner, Waffen und Schaden laufen nur in Running und Boss (`isActive`); der Run läuft in Running, Shop und Boss (`isOngoing`). Die Kampfzeit (`getElapsed`) steht im Shop still; RunState schickt dafür `wave`, `pausedSeconds` und `pausedAt`. Teilnehmer-Zustände: Alive, Down, Out.
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
- Snapshots gebündelt per UnreliableRemoteEvent: 9 Byte pro Gegner (ID, Position, Typ, HP-Anteil, Flags) in einem `buffer`; bei 140 Gegnern und 15 Hz ≈ 19 KB/s pro Spieler. Gesendet wird nur an die Teilnehmer des Runs. Das Flag-Byte (seit dem Spaß-Paket nach Paket 9) trägt in 2 Bit den Zustand eines Chargers (läuft, holt aus, stürmt, erholt sich) und in 2 Bit die Eigenschaft einer Elite, seit dem Fix nach Paket 9d in den übrigen 4 Bit die Sturmrichtung eines Chargers (16 Stufen, also höchstens gut 11° daneben). So schaut ein Charger beim Ausholen und Stürmen in seine Sturmrichtung, und der rote Streifen zeigt dorthin; vorher drehte er sich nach der Laufrichtung, und Nachbarn, die ihn beim Ausholen anschoben, drehten ihn weg (Owner-Feedback).
- Ein UnreliableRemoteEvent-Paket darf höchstens ~900 Byte haben: ein Tick wird gleichmäßig auf Pakete mit max. 90 Gegnern verteilt (8 Byte Kopf mit Tick, Teil, Teilanzahl und Gegnerzahl + 9 Byte pro Gegner, also höchstens 818 Byte). Der Client nutzt einen Tick erst, wenn alle Teile da sind; geht ein Paket verloren, fällt nur dieser Tick aus. Format in `src/shared/Net/Snapshot.luau`.
- Gegner-IDs (1–65535) werden reihum vergeben, eine frei gewordene ID kommt also erst nach Zehntausenden Spawns wieder.
- Clients (`EnemyRenderer`): Modell-Pool pro Gegnertyp, Interpolation zwischen zwei Ticks (~100 ms hinter dem neuesten; die Uhr gleicht unregelmäßige Ankunft weich aus und läuft nie über den neuesten Tick hinaus, sonst sprangen Gegner nach einer Pause wie dem Shop immer wieder auf alte Stände zurück und flackerten), Positionen gesammelt per `workspace:BulkMoveTo`, kurzes weißes Aufblitzen bei Treffern (0,1 s). Modelle aus 5–20 Teilen in der Größe des Kollisionskreises (`EnemyRenderer/Models.luau`, Look in Abschnitt 14, seit Paket 9d; vorher Platzhalter aus 2–5 Teilen). `Models.pose` rechnet pro Bild jedes sichtbare Teil aus Boden-Punkt, Körper und Gelenk (vorberechnete Drehpunkte) und hängt es an die BulkMoveTo-Liste; unsichtbare Teile (Elite-Eigenschaft nicht aktiv, Sturm-Streifen aus) werden nicht bewegt. Bei 140 Gegnern sind das ≈ 1700 Teile pro Bild. Ab 80 Gegnern (am Handy ab 40, zurück unter 85 % davon) lassen normale Gegner kleine Verzierungen weg (Klauen, Filter, Saum, Bänder, `LocalTransparencyModifier`), das spart gut ein Viertel (≈ 1260 Teile); Elites behalten alles (`Config/Feedback.luau` → `enemyDetail`). Verschwindet ein Gegner aus den Snapshots, ist er tot: Funken und Seelen-Irrlichter in seiner Augenfarbe (`EnemyRenderer/DeathBursts.luau` über `Vfx/Bursts`).
- **Schadenszahlen** (seit dem Spaß-Paket nach Paket 9): WeaponService sammelt pro Schritt die eigenen Treffer jedes Spielers (pro Gegner zusammengezählt, mit Krit- und Kill-Flag) und schickt sie als `buffer` über das UnreliableRemoteEvent `DamageNumbers` nur an diesen Spieler: 1 Byte Kopf + 7 Byte pro Treffer, höchstens 100 Treffer (701 Byte) pro Schritt; Format in `src/shared/Net/HitNumbers.luau`. Üblich sind 1–5 KB/s, im schlimmsten Fall ≈ 10 KB/s. `DamageNumberController` zeigt höchstens 40 Zahlen gleichzeitig (am Handy 20) als gepoolte BillboardGuis an einem Anker-Teil.
- Gegner-Teile verankert, ohne Kollision, ohne Schatten.

**Schnittstellen der Gegner-Engine für spätere Pakete**

- `EnemySim.spawn(enemyId, x, z, hpMultiplier, damageMultiplier, elite?, affix?)` – SpawnDirector, Boss (Paket 10). Elite-Varianten jedes Typs (schlicht und je Eigenschaft, alle mit derselben typeId) baut `Util/EnemyKinds` aus `Config/Enemies.luau` (seit Paket 9).
- `EnemySim.getMode(id)` – Zustand und Sturmrichtung eines Chargers (World-Spalten, seit dem Spaß-Paket); Splitter zerfallen in `EnemySim.damage`, Beschwörer melden sich in `World.summons` und EnemySim spawnt ihre Gegner (beides mit den HP- und Schadensfaktoren des Auslösers, auch über der Obergrenze bis 140).
- `EnemySim.teleport(id, position)`, `collectIds(out)`, `getKind(id)` (Typ und ob Elite), `getShotCount()` – seit Paket 9 für SpawnDirector, Debug und die Balance-Simulation.
- `EnemySim.damage(id, amount, player)` (gibt zurück, ob der Gegner starb, wie viel HP der Treffer wirklich nahm und den Schaden nach dem Faktor der Elite-Eigenschaft „Armored"), `queryRadius(position, radius, out)`, `querySegment(from, to, radius, out)`, `nearest(position, maxRange)`, `getPosition(id)`, `push(id, offset)` (Rückstoß, geteilt durch die Masse über 1), `killAll()` – Waffen, Debug.
- `EnemySim.getPlayerPosition(player)` – wo der letzte Schritt einen lebenden Teilnehmer gesehen hat, mit demselben Vorlauf wie bei Kontakten; Waffen zielen von dort.
- Signal `EnemySim.Stepped(dt, now)` – direkt nach jedem Schritt, noch innerhalb der gemessenen Schrittzeit; hier laufen die Waffen (seit Paket 5).
- Signal `EnemySim.EnemyKilled(info)` mit Typ, Position, XP und Killer – XP-Orbs (Paket 6), Truhen (Paket 9), Statistik.
- Signal `EnemySim.Contact(player, damage)` – Spieler-HP mit 0,5 s Schutz nach Treffer (seit Paket 4 über CombatService).
- Signal `EnemySim.ShotHit(player, damage)` – ein Gegner-Geschoss traf (seit Paket 9, auch über CombatService).
- **Gegner-Geschosse** (seit Paket 9): `World` meldet pro Schritt, welcher Spitter schießt (Abklingzeit als eigene Spalte); `EnemySim/Volleys.luau` (rein, mit Unit-Tests) fliegt die Kugeln gegen die Spielerpositionen mit Vorlauf, Ruinen und Arenarand. `EnemyShots` geht nach jedem Snapshot mit Änderungen an die Teilnehmer (abgefeuert: Ort, Richtung, Tempo, Reichweite, Serverzeit; beendet: ID und Strecke); `EnemyShotRenderer` zeichnet gepoolte Kugeln in Serverzeit.
- **Truhen** (seit Paket 9): `LootService` legt bei `EnemyKilled` einer Elite eine Truhe ab, öffnet sie nach jedem Schritt, wenn ein lebender Spieler nah genug ist, und vergibt über `UpgradeService.grantChest(player)` (Evolution, sonst Upgrade, sonst Heilung; Auswahl rein in `UpgradePool.chestUpgrade`). `Chests` (Liste am Boden) und `ChestOpened` (wer was bekam) gehen an die Teilnehmer; `LootService.drop(position)` kann die Boss-Truhe (Paket 10) nutzen. `ChestController` zeichnet Truhen, Pfeile und das Belohnungs-Banner.

**Spieler** (seit Paket 4)

- **CombatService** (Server) hält HP, Verteidigung (seit B2 Rüstungs-Faktor und Ausweich-Chance aus den Werten), Regeneration, Schutzfenster und Dash-Cooldown pro Spieler; die Regeln stehen als reines Modul in `CombatService/Vitals.luau` (mit Unit-Tests). Kontaktschaden kommt von `EnemySim.Contact`; bei 0 HP setzt der Service den Spieler über `RunDirector.setParticipantState` auf Down. Wieder Alive (Debug-Knopf, später Paket 11) → 40 % HP; am Wellenende (seit B1) volle HP für alle. Bei Countdown und Lobby volle HP. In der Shop-Phase ist das Lauftempo 0 und Dashes werden abgelehnt.
- Schnittstellen für spätere Pakete: `CombatService.damagePlayer(player, damage)` (Projektile, Boss), `healPlayer(player, amount)` (Heilung, Truhen), `setStats(player, sheet)` und `lifeSteal(player)` (seit B2, StatService bzw. WeaponService), `protect(player, seconds)` (Level-up-Wahl, Paket 6), `getHp(player)`.
- Dash: Der Client bewegt die eigene Figur sofort (LinearVelocity entlang des Bodens) und schickt `RequestDash`; der Server prüft den Cooldown (0,25 s Kulanz für Ping) und gibt 0,3 s Unverwundbarkeit. Die Bewegung selbst ist wie bei jeder Roblox-Figur Sache des Clients; der Plausibilitätscheck für Bewegung folgt im Sicherheits-Paket 23.
- `PlayerState` geht bei jeder Änderung an alle Clients (`Net/Types.PlayerVitals`: HP, Max-HP, Dash bereit ab, unverwundbar bis). Ein neuer Client bekommt alle Stände mit `RequestSync` (Signal `RunDirector.SyncRequested`).
- Client: `InputController` (Dash, Springen aus, Roblox-Lebensanzeige aus), `CameraController`, `PlayerStateController` (Stände + vorhergesagter Cooldown).

**Waffen-Framework** (seit Paket 5; Werte in `Config/Weapons.luau`, `Config/Player.luau`, `Config/Simulation.luau`)

- **WeaponService** (Server) gibt jedem Teilnehmer beim Run-Start die Klassen-Waffe und führt nach jedem Gegner-Schritt (15 Hz, Signal `EnemySim.Stepped`) alle Waffen aus. Die Regeln stehen als reines Modul in `WeaponService/Arsenal.luau` (mit Unit-Tests gegen eine echte Gegner-Welt), die Werte rechnet `WeaponStats.luau` aus: Grundwert + Level-Schritte + Evolution + Boni des Spielers.
- Pro Spieler bis zu 6 Waffen (seit B2, vorher 4), jede bis Level 5. Pro Schritt und Waffe: erst `step` des Verhaltens (Klingen drehen, Projektile fliegen), dann, wenn der Cooldown um ist und der Spieler lebt, `fire` (neuer Angriff). Findet `fire` kein Ziel, versucht es die Waffe im nächsten Schritt wieder; Schüsse werden nicht angespart. Was schon fliegt, fliegt weiter, auch wenn der Spieler down geht.
- **Neue Waffe** = Datensatz in `Config/Weapons.luau` + Verhalten in `WeaponService/Behaviors/<behavior>.luau` (Server, entscheidet die Treffer) + Aussehen in `WeaponRenderer/Visuals/<behavior>.luau` (Client, nur Anzeige). Das Verhalten erreicht die Welt nur über den Kontext: Gegner abfragen (Kreis, Strecke, nächste Gegner), `hit` (Schaden mit Krit, pro Waffe gezählt), `push` (Rückstoß), `emit` (Effekt für die Clients). Eine Waffe ohne Verhaltens-Modul kann niemand bekommen; `ConfigCheck` meldet, wenn einer Klassen-Waffe das Modul fehlt.
- Treffer sind Daten gegen das Gegner-Raster, keine Roblox-Physik: Klingen und Projektile werden als Strecke zwischen zwei Schritten geprüft, damit nichts durchrutscht (Klingen in Stücken von höchstens 1,5 Studs an der Spitze).
- **Netzwerk:** `Loadout` (Waffen, Level und fertige Werte eines Spielers) geht bei jeder Änderung an alle; `WeaponEffects` bündelt pro Schritt die Effekte (Bolt abgefeuert, Bolt gestoppt, Druckwelle) und geht nur an die Teilnehmer. Orbit-Klingen brauchen keine Effekte: Server und Clients rechnen den Winkel aus der Serverzeit (`Util/Orbit.luau`). Der Client schickt für Waffen nichts.
- **Client:** `LoadoutController` merkt sich die Loadouts, `WeaponRenderer` zeichnet mit gepoolten Neon-Teilen und einem `workspace:BulkMoveTo` pro Frame. Klingen drehen sich um die Figur, wie dieser Client sie sieht; Bolts fliegen in Serverzeit von dort, wo der Server sie abgefeuert hat; die Druckwelle wächst um die Figur des Werfers und verblasst in 0,35 s.
- Schnittstellen für spätere Pakete: `WeaponService.addWeapon(player, id)`, `levelUp(player, id)`, `removeWeapon`, `evolve(player, id, evolutionId)` (die Item-Voraussetzung prüft der Aufrufer), `getWeapons`, `getImplemented()` (Karten-Pool, Paket 6), `getDamageStats(player)` (Schaden und Kills pro Waffe für den Run-Ende-Screen, Paket 14), `setStats(player, sheet)` (seit B2 die Werte aus StatService; vorher `setBonuses` mit Passiven und Klassen-Bonus; Talente kommen in Paket 13 über StatService dazu).
- Gemessen im Test-Runner: 4 Spieler mit je 3 Waffen auf Level 5 zwischen 140 Gegnern ≈ 0,1 ms für die Waffen, zusammen mit den Gegnern ≈ 1,1 ms pro Schritt (Budget 4 ms). Die Messanzeige zeigt seit Paket 5 die Zeit für Gegner und Waffen zusammen.

**XP und Level-ups** (seit Paket 6; Werte in `Config/Run.luau`)

- **ExperienceService** (Server) hört auf `EnemySim.EnemyKilled` und legt Orbs als Daten an (`ExperienceService/OrbField.luau`); nach jedem Gegner-Schritt (`EnemySim.Stepped`) sammeln die lebenden Teilnehmer ein, gemessen an `EnemySim.getPlayerPosition` (wie bei Kontakten). Team-Level und XP-Kurve stehen rein in `ExperienceService/Progression.luau`. Beides mit Unit-Tests.
- **UpgradeService** (Server) macht aus jedem Level-up Werte-Karten pro Spieler (`UpgradeService/UpgradePool.luau`, rein, mit Unit-Tests), gibt den gewählten Wert an StatService, kassiert Neuwürfe über `ShopService.spendShards` und vergibt Truhen-Belohnungen (`grantChest`).
- **StatService** (Server, seit B2) hält pro Teilnehmer Items (mit Anzahl), Werte aus Karten und Harvesting-Wachstum und die Zahl der Team-Level. Bei jeder Änderung rechnet es die Werte neu zusammen (Grundwerte + Klasse + Items × Anzahl + Karten + 10 Max HP pro Level, `Util/StatMath`) und schickt sie an WeaponService (Schaden, Attack Speed, Range, Krit, Life Steal), CombatService (Max HP, Rüstung, Ausweichen, Regeneration, Tempo) und ExperienceService (Aufsammelradius, XP Gain). Außerhalb eines Runs gelten die Grundwerte. Schnittstellen: `addItem` (Shop, Truhen, Debug; prüft Obergrenzen), `addUpgrade`, `growHarvesting`, `getStat`, `getSheet`, `getItemCounts`, `getItems`.
- **ShopService** zahlt am Wellenende Harvesting aus (Shards + Team-XP über `ExperienceService.addXp`), würfelt Waffen und Items (`ShopRules`, rein, mit Unit-Tests) und gibt gekaufte Items an StatService.
- **CombatService.setChoosing(player, an/aus):** schützt ohne Zeitlimit, setzt das Lauftempo auf 0 und lehnt Dashes ab; `PlayerVitals.choosing` geht an alle Clients.
- **Netzwerk:** `TeamProgress` (Level, XP, Bedarf) an alle; `XpOrbs` pro Schritt gebündelt an die Teilnehmer, als flache Zahlenlisten (neue oder gewachsene Orbs: ID, x, z, Wert; eingesammelt: ID, Spieler); `LevelUpOffer` nur an den Wählenden (seit B2 mit `rerollPrice`); `Items` pro Spieler an alle (seit B2, vorher `Passives`); `Stats` (alle Werte) nur an den Spieler selbst. Der Client schickt `ChooseUpgrade(cardId)` (nur vom Server angebotene IDs zählen) und `RequestReroll`.
- **Client:** `ProgressController` merkt sich Team-XP und Items, `StatsController` die eigenen Werte (Liste im Shop), `XpOrbRenderer` zeichnet gepoolte Orbs (liegende werden einmal gesetzt, nur fliegende bewegt, per `workspace:BulkMoveTo`), `LevelUpController` zeigt die Karten; Kartentexte baut `Util/UpgradeText` aus der Config.
- Debug-Knopf „Team +1 level" löst sofort ein Level-up aus (seit B1 kommen die Karten erst am Wellenende; im Shop sofort).
- Schnittstellen für spätere Pakete: `ExperienceService.LevelGained(level)`, `grantLevel()`, `getLevel()`; `UpgradeService.getEvolutions(player)` (Evolutions-Voraussetzung, Paket 9); seit B2 `ExperienceService.addXp(amount)` (Harvesting). `getPassives` und `getBonusEmbers` gibt es nicht mehr.

**Performance-Budgets**

| Budget | Ziel |
| --- | --- |
| Gegner gleichzeitig | 80 + 20 pro weiterem Spieler, max. 140 |
| Server-Simulation | 15 Hz, unter 4 ms pro Schritt |
| Client-FPS Mittelklasse-Handy | ≥ 30 |
| Netzwerk pro Client | < 50 KB/s |
| Partikel-Emitter | so wenige wie möglich, gepoolt (`Vfx/Bursts`: einer pro Stil und Farbe, ≈ 30) |
| Teile pro Gegner | höchstens 20, Elite 25 (Test `EnemyModels.spec`); in großen Trauben wenig Details |

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

**Sicherheit:** Client schickt nur Absichten (Bewegung, Dash, Level-up-Wahl, Kaufwunsch). Server berechnet Schaden, Kills, XP, Drops, Embers, Truhen, Ranglistenwerte. Jede Remote mit Rate-Limit und Validierung (nur angebotene Karten-IDs, Dash nur nach Cooldown). Bewegungs-Plausibilitätscheck. Admin-Befehle nur für die UserId des Owners, serverseitig geprüft: Admin ist, wer in Studio testet, der Besitzer einer Experience im eigenen Account (`game.CreatorId`) und wer in `Config/Admin.luau` steht. Test-Befehle seit Paket 2: Timer +1 Minute, zu 11:50 springen, sich selbst umhauen/aufstehen, Run gewinnen. Seit Paket 3: 40 Gegner um sich spawnen (Obergrenze gilt), Gegner in 20 Studs Umkreis treffen (5 Schaden), alle Gegner töten, Spawnen pausieren/fortsetzen. Seit Paket 4: sich selbst 25 Schaden geben (Rüstung und Schutz gelten), sich voll heilen; dazu eine Messanzeige unten links (Gegnerzahl, Spawnrate, Serverzeit pro Schritt, Gegnerdaten in KB/s, FPS; rot, wenn ein Budget überschritten ist). Seit Paket 5: nächste fehlende Waffe hinzufügen, nur die nächste Waffe behalten (zum Ausprobieren einzeln), alle Waffen +1 Level, alle Waffen aus/an (gilt bis zum nächsten Run); das Debug-Menü hat dafür zwei Spalten. Seit Paket 8: Waffen entwickeln („Evolve weapons"). Seit Paket 9: eine Elite in der Nähe spawnen („Spawn an elite", ihre Truhe lässt sich so testen); die Messanzeige zeigt auch die Gegner-Geschosse in der Luft. Seit B1: „End this wave" (statt „+1 minute", springt ans Wellenende und öffnet den Shop), „Stop/run wave timer" (die Welle endet nicht, bis man wieder drückt; gilt auch für die nächsten Runs), „+100 Shards". Shop-Remotes: `BuyShopOffer` (nur vom Server angebotene IDs, Preis und Plätze prüft der Server), `RerollShop`, `SetShopReady` (nur in der Shop-Phase).

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
| Vertical Slice | Spark Mage, alle 6 Waffen, 46 Items (seit B2, vorher 6 Passive), 2 Evolutionen, 3 Gegnertypen + Elites, Boss, Wiederbeleben, Speichern, Embers + Talente, HUD | kompletter Run auf Normal |
| MVP | Hub + Teleport, Hard/Nightmare, Shop und Käufe, Quests, Ranglisten, Badges, FTUE, Analytics, Look und Sound, Performance | launchfähiges Spiel |
| Soft Launch | Launch-Paket, Closed Test, öffentlich 16+, Ads-Test | erste echte KPIs |
| Live-Ops | wöchentliche Updates, neue Klassen/Maps, Lantern Pass, Weekly Challenge, Endlos-Modus | Wachstum nach Daten |

## 20. Effort-Plan (Opus 5.5) & Zeitaufwand

Bis zum Soft Launch rund 40–50 Sessions und 50–60 Stunden Zeit des Owners (6–8 h/Woche über 8 Wochen); seit dem Plan nach der Brotato-Referenz (29.10.2026) etwa 18–22 Sessions mehr. In Claude Code per `/effort` einstellen.

**Abgleich mit der Brotato-Referenz (29.10.2026, Stand nach B2):** Schon wie Brotato sind Wellen mit Shop, volle Heilung am Wellenende, 4 Angebote mit Preis-, Neuwurf- und Seltenheitsformel, die 17 Werte mit ihren Formeln, Items mit Vor- und Nachteil, XP-Kurve und Werte-Karten. Es fehlt noch:

| Bereich | Fehlt | Paket |
| --- | --- | --- |
| Run | 20 Wellen mit Brotatos Dauern, Boss-Welle 20 (90 s) | B3, 10 |
| Shop | Sperren (kostenlos, Preis bleibt), Verkaufen (25 % des Preises), Waffen-Stufen I–IV statt Level 1–5, Verschmelzen zweier gleicher Waffen gleicher Stufe (per Knopf oder automatisch bei vollen Plätzen), Gratis-Neuwurf nach 4 Käufen, Waffen-Pool 20 % eigene / 15 % gleiche Klasse / 65 % alle, keine Wiederholung des vorigen Wurfs | B3 |
| Effekte | Ereignisse (Welle startet/endet, Treffer, Krit, Kill, Ausweichen, getroffen, Aufsammeln, Level-up, Shop betreten, Timer), Effekte als Daten {Auslöser, Bedingung, Aktion, Werte}, Werte im Stillstand/in Bewegung, „pro X", „nächste Welle", Wachstum am Wellenende, Multiplikatoren auf Wert-Gewinne (für Charaktere), getrennte Zufalls-Ströme (Shop, Drops, Spawns, Kampf) | B4 |
| Neben-Werte | Item-Preise, Gratis-Neuwürfe, Doppel-Beute, Schaden gegen Bosse/Elites, Frucht-Heilung, Heilung beim Aufsammeln, Gegner-Anzahl/-HP/-Schaden/-Tempo, Explosionsschaden und -größe, Durchschlag, Abprall, Brenn-Tempo und -Ausbreitung, Rückstoß | B4, B5 |
| Kampf | Krit-Chance und Krit-Faktor pro Waffe (×1,5 bis ×4), Lebensraub pro Waffe, Rückstoß mit Widerstand der Gegner, Brennen (stapelt nicht, Ausbreitung), Verlangsamen, Explosionen, Durchschlag mit Schadensabzug, Abprall, höchstens 12 Angriffe/s, Skalierung pro Waffe (z. B. 80 % Melee, mehrere Werte), Schutz nach Treffer 0,2–0,4 s | B5 |
| Waffenklassen | 1–2 Klassen pro Waffe, gestaffelte Boni bei 2–6 Waffen einer Klasse (Brotatos 15 Staffeln, eigene Klassennamen) | B5 |
| Waffen | 20–24 eigene Waffen statt 6, alle Klassen und Effekt-Arten (Stoß/Schwung, Schrot, Raketen, Feuer, Eis, Stapel pro Kill, Wert solange getragen, Heil-Geschoss, Magazin) | B7 |
| Items | ~100 statt 46, viele mit Effekten (Kill, Ausweichen, Wellenende, Gegner-Änderung, Zufallswerte), Item-Limits | B8 |
| Beute | Drop-Chance 100 % bis Welle 4, dann −1,5 % pro Welle (mind. 50 %), Beutel (Liegengebliebenes zieht in der nächsten Welle je Drop 1 dazu), höchstens 50 liegende Beute-Objekte (darüber zusammenlegen), Heil-Früchte, Kisten von normalen Gegnern (Item nehmen oder verkaufen, Chance sinkt mit jeder Kiste der Welle), Plünderer-Gegner, Bäume, Legendäre Kiste von Elites/Boss | B6 |
| Gegner | Spawn-Marker vor dem Erscheinen, Wellen als Spawn-Gruppen (Typ, Anzahl, Start, Abstand), Werte pro Typ = Grund + Zuwachs pro Welle, neue Verhalten: Beschleuniger, flüchtender Schütze, Konter-Schütze, Buffer, Heiler, Ei (schlüpft nach 5 s), Hieb-Gegner, Beute-Fresser | B9 |
| Elites und Boss | Phasen-Automat (Angriffe, Wechsel bei HP-Schwelle oder Zeit), Vorwarnen–Ausführen–Erholen, 2 Bosse, Elites mit Phasen | 10 |
| Charaktere | Regelpakete statt Klassen: Startwerte, Startwaffe zur Wahl, Waffen-Plätze 1–12, Multiplikatoren auf Gewinne, Shop-Regeln, Wunsch-Tags (5 % Shop-Gewicht), Sonderregeln | B10 |
| Schwierigkeit | Gefahrenstufen 0–5 (neue Gegner ab 1, Elite-/Horden-Wellen ab 2, +12/+26/+40 % Gegner-HP und -Schaden ab 3/4/5, 2 Bosse auf 5), Endlos nach Welle 20 mit Brotatos Formel, Regler für Gegner-HP/-Schaden/-Tempo, Welle wiederholen | B11 |
| Bauten | Engineering-Wert, Geschütztürme (5 Stufen), Minen, Garten, wandernder Bot, Begleiter (Pets), höchstens 100 Bauten | B12 |
| Fortschritt | Erfolge mit Zählern schalten Charaktere, Waffen, Items frei; Gefahrenstufe pro Charakter | 13 |
| Anzeige | Tooltips mit Skalierung („20 (+80 % Melee)"), Set-Bonus-Fortschritt, Item-Limits, Werte Haupt/Neben umschaltbar, Vorschau kommender Elite-/Horden-Wellen | 14 |

**Bewusst anders als Brotato (bleibt):** Online-Koop für 1–4 mit Wiederbeleben, Dash, gemeinsames Team-Level, HP mal 10, 3D-Schräg-Kamera, unsere Evolutionen (ab B3 an Waffen-Stufe IV statt Level 5), Gegner-Obergrenze 80 + 20 pro Spieler (Performance-Budget).

**Reihenfolge:** Der Shop (B3) ist das Herz und kommt zuerst. Effekt-Maschine (B4) und Kampf-Tiefe (B5) sind das Gerüst für alle neuen Waffen, Items und Charaktere; Inhalte davor zu bauen hieße, sie später umzubauen. Jedes Paket aktualisiert die Balance-Simulation.

| # | Arbeitspaket | Phase | Effort | Sessions | Zeit Owner | Owner tut |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Projekt-Setup: Rojo, Git, Ordner, Config, Net | Prototyp | Medium | 1 | 0,5 h | Installationen abnicken, Studio + Rojo-Plugin verbinden |
| 2 | Architektur-Gerüst: Services, Netzwerk-Schicht, Run-Ablauf | Prototyp | Extra high | 1–2 | 1 h | prüfen, dass ein Run startet und endet |
| 3 | Gegner-Engine: Simulation, Raster, Snapshots, Renderer | Prototyp | Extra high | 2–3 | 2 h | mit 1–4 Test-Clients und am Handy testen |
| 4 | Spieler: Kamera, Steuerung, Dash, HP | Prototyp | Medium | 1 | 1 h | Spielgefühl beurteilen |
| 5 | Waffen-Framework + 3 Waffen | Prototyp | Extra high (Framework), Medium (Waffen) | 2 | 1,5 h | Waffengefühl beurteilen |
| 6 | XP, Level-up-Karten, Upgrade-Pool | Prototyp | Medium | 1 | 1 h | Karten am Handy prüfen |
| 7 | Prototyp-Playtest + Balancing | Prototyp | Medium | 1 | 3 h | Spaß-Check mit 3–5 Freunden |
| 8 | Restliche Waffen, Evolutionen, Spark Mage (Passive seit Paket 6) | Vertical Slice | Medium | 2 | 1,5 h | Balancing-Feedback |
| 9 | Gegnertypen, Elites, Spawn-Director | Vertical Slice | Medium | 1–2 | 1 h | Schwierigkeit beurteilen |
| 9b | Spaß-Paket Teil 1: Wellen, Charger, Splitter, Abyss-Gegner, Elite-Eigenschaften, Treffer-Gefühl | Vertical Slice | Extra high | 1 | 1 h | Spielgefühl beurteilen |
| ~~9c~~ | ~~Spaß-Paket Teil 2~~ – entfällt seit der Brotato-Richtung: Krits, Glück und seltene Karten gehen in B2, Level-Sprünge ersetzt der Shop | – | – | – | – | – |
| 9d | Look-Paket: Gegner im Deadlock-Stil (okkultes Art déco), neue Waffen-, Dash- und Todes-Effekte | Vertical Slice | Extra high | 1 | 30 min | Look beurteilen, am Handy auf Ruckler achten |
| B1 | Brotato-Richtung 1: Wellen 20–60 s mit Shop-Phase, Shards, Level-ups am Wellenende, Aufstehen und Heilen am Wellenende | Vertical Slice | Extra high | 1 | 1 h | Run solo und zu zweit spielen |
| B2 | Brotato-Richtung 2: Werte-System (Schaden, Angriffstempo, Krit, Glück, Rüstung, Ausweichen, Regeneration, Lebensraub, Reichweite, Tempo, Ernte), 46 Items in 4 Seltenheiten mit Trade-offs, unbegrenzt stapelbar, 6 Waffen-Plätze, Level-ups als Werte-Wahl, Werte-Liste im Shop | Vertical Slice | Extra high | 1–2 | 1 h | Items ausprobieren |
| B3 | Brotato 3: Shop komplett und 20 Wellen – Run auf 20 Wellen mit Brotatos Dauern, Sperren, Verkaufen, Waffen-Stufen I–IV statt Level, Verschmelzen, Gratis-Neuwurf nach 4 Käufen, Waffen-Pool-Regeln, Evolutionen ab Stufe IV, Handy-Layout | Vertical Slice | High | 1–2 | 1 h | Shop am PC und Handy bedienen |
| B4 | Brotato 4: Effekt-Maschine – Ereignisse, Effekte als Daten, bedingte und „pro X"-Werte, nächste Welle, Wellenende-Wachstum, Neben-Werte, getrennte Zufalls-Ströme, ~20 neue Items mit Effekten | Vertical Slice | Extra high | 2 | 1 h | neue Items ausprobieren |
| B5 | Brotato 5: Kampf-Tiefe – Krit und Lebensraub pro Waffe, Rückstoß, Brennen, Verlangsamen, Explosionen, Durchschlag/Abprall, 12 Angriffe/s, Skalierung pro Waffe, Waffenklassen mit Set-Boni | Vertical Slice | Extra high | 2 | 1 h | Waffengefühl beurteilen |
| B6 | Brotato 6: Beute – sinkende Drop-Chance, Beutel, Heil-Früchte, Kisten von normalen Gegnern, Plünderer, Bäume, Beute-Obergrenze | Vertical Slice | High | 1–2 | 1 h | Wirtschaft beurteilen |
| B7 | Brotato 7: Waffen-Paket – auf 20–24 Waffen, alle Klassen und Effekt-Arten | Vertical Slice | Medium | 2 | 1 h | Waffen ausprobieren |
| B8 | Brotato 8: Item-Paket – auf ~100 Items, viele mit Effekten | Vertical Slice | Medium | 2 | 1 h | Items ausprobieren |
| B9 | Brotato 9: Gegner-Paket – Spawn-Marker, Wellen als Spawn-Gruppen, Werte pro Typ und Welle, 8 neue Verhalten | Vertical Slice | Extra high | 2 | 1 h | Schwierigkeit und Lesbarkeit beurteilen |
| B10 | Brotato 10: Charaktere – 10–12 Charaktere als Regelpakete (ersetzt die Klassen), Charakter- und Waffenwahl in der Lobby | Vertical Slice | High | 2 | 1,5 h | jeden Charakter einmal spielen |
| 10 | Boss und Elites mit Phasen: Boss-Welle 20 (90 s), 2 Bosse mit Phasen-Wechseln, Vorwarnungen, Elites mit Phasen | Vertical Slice | High | 2 | 1,5 h | Boss 3× spielen |
| B11 | Brotato 11: Gefahrenstufen 0–5, Elite- und Horden-Wellen, Endlos-Modus, Regler für Gegner-Werte, Welle wiederholen | Vertical Slice | High | 1–2 | 1 h | Stufen durchprobieren |
| B12 | Brotato 12: Bauten und Begleiter – Engineering, Türme, Minen, Garten, Bot, Pets | Vertical Slice | High | 2 | 1 h | Bau-Builds testen |
| 11 | Down & Wiederbeleben während der Welle (Aufstehen am Wellenende gibt es seit B1) | Vertical Slice | Medium | 1 | 1 h | mit 2 Clients testen |
| 12 | Datenspeicherung: ProfileStore, Schema, Migration | Vertical Slice | Extra high | 1–2 | 1 h | Test-Experience anlegen, Join/Leave testen |
| 13 | Fortschritt: Embers, Erfolge schalten Charaktere, Waffen und Items frei, Gefahrenstufe pro Charakter (statt Talente und Normal/Hard/Nightmare) | Vertical Slice | Medium | 1–2 | 1 h | Freischaltungen abnicken |
| 14 | HUD, Run-Ende, mobiles Layout, Tooltips (Skalierung, Set-Bonus, Elite-Vorschau) | Vertical Slice | Medium | 2–3 | 2 h | Handy-Screenshots |
| 15 | Hub-Lobby, Teleport, Party, Quick Join | MVP | Extra high | 2–3 | 2 h | Party-Teleport testen |
| 16 | Käufe: Passes, Products, ProcessReceipt | MVP | Extra high | 1–2 | 1 h | Produkte im Creator Hub anlegen, IDs liefern, Testkäufe |
| 17 | Ember-Shop-, Freischaltungs- und Pass-UI | MVP | Medium | 2 | 1 h | Look abnicken |
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
- [x] Look: okkultes Art déco im Stil von Deadlock (Owner, Paket 9d) – umgesetzt für Gegner und Effekte; Karte, Kostüme und Laternen folgen in Paket 21.
- [ ] Eigentümer: Veröffentlichung unter einer Roblox-Gruppe?
- [ ] Beitritt in laufende Runs (v1: nein)?
- [x] Endlos-Modus nach dem Boss: ja, wie Brotato mit dessen Formel (Paket B11).
- [x] Run-Länge: 20 Wellen wie Brotato (Owner, 29.10.2026; Umstellung in B3).
- [x] Talente: Stärke-Talente fallen weg, dafür Freischaltungen wie Brotato (Paket 13).
- [ ] Pets und Bauten (B12) vor oder nach dem Soft Launch?
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
