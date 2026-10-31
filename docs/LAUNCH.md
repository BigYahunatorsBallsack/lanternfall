# Launch-Paket (Paket 24)

Alles, was der Owner für den Soft Launch im Creator Hub einträgt, plus die Liste der Handgriffe vor dem Veröffentlichen. Spieltexte sind Englisch (wie im Spiel), Erklärungen Deutsch.

## 1. Was im Spiel neu ist

- **Launch-Check:** Beim Start schreibt der Server eine Zeile ins Output („Launch check: 1 must, 3 should open"). Der Debug-Knopf **„Launch check"** listet alles einzeln: `[MUST]` = muss vor dem Launch erledigt sein, `[should]` = läuft, wirkt aber unfertig, `[ok]` = erledigt. Auf einem Live-Server landen offene MUST-Punkte als Warnung in der Developer Console (F9). Werte: `Config/Launch.luau`, Regeln: `Util/LaunchRules.luau`.
- **Aufnahme-Modus (nur Admins, also du):** **F6** blendet alle Menüs und die Roblox-Knöpfe aus, **F7** wechselt die Kamera (Game camera, Close, Low hero, Wide). Nochmal F6 = alles zurück. Auch als Knopf „Capture mode (F6)" im Debug-Feld.
- **Debug-Knopf „Showcase scene"** (im Run): Wellen-Timer steht, alle 6 Waffenplätze voll auf Stufe III, 70 Gegner um dich herum. Ideal für Clips. Der Run zählt danach nicht für die Rangliste.
- **Bilder:** `assets/launch/` (Kopie in den Projektdateien `lanternfall-wp24/`): `icon-a/b/c.png` (512 × 512) und `thumbnail-1/2/3.png` (1920 × 1080). Neu erzeugen: `python3 tools/launch/art.py`.

## 2. Texte für die Spielseite (Creator Hub → Experience → Configure → Basic Info)

**Name:** `Lanternfall` (Alternative zum Testen: `Lanternfall: Co-op Survivors`)

**Beschreibung** (unter 1000 Zeichen, einfach kopieren):

```text
The Gloom rises every night. Hold up your lantern and survive.

Lanternfall is a co-op horde survivor for 1-4 players. Your weapons fire on their own: you move, dodge and dash while hundreds of enemies close in. Survive 20 waves, shop between them and face a boss at the end.

• 10 characters, each with its own play style
• 24 weapons in 4 tiers: buy two of the same and merge them
• 100+ items that stack without limit
• Elites, champions and two bosses
• Revive your friends before their light goes out
• 6 danger levels and an endless mode for the brave
• Daily quests, login rewards, badges and weekly leaderboards

New here? Your First Night is a short guided run.

Play solo, with your party or press Quick Join to team up with others.

Tip: Like and favourite the game to get notified about weekly updates!
```

**Genre:** Survival (sonst „All Genres"). **Unterkategorie (falls gefragt):** Roguelike/Co-op.

**Kurztext für Ads/Social:** „Hold the light. Survive the horde. 1-4 player co-op survivors."

## 3. Icon und Thumbnails (Creator Hub → Experience → Places → Start-Place → Configure → Icon / Thumbnails)

1. **Icon:** `icon-a.png` hochladen (Laterne gegen Horde, ohne Text, liest sich am Handy am besten). `icon-b` (mit Namen) und `icon-c` (Riesen-Gloom) sind die Varianten für einen späteren Icon-Test (Plan: 2–3 Varianten im Soft Launch).
2. **Thumbnails:** in dieser Reihenfolge `thumbnail-1.png` (Titel), `thumbnail-2.png` (Koop), `thumbnail-3.png` (Inhalt). Besser noch: **1–2 echte Screenshots** aus dem Spiel davor setzen (siehe 4). Echte Spielszenen klicken meist besser als gemalte Bilder.
3. Beide Places (Hub und Run) bekommen dasselbe Icon; Thumbnails zählen nur am Start-Place (Hub).

## 4. Screenshots und Clips aufnehmen

1. Studio → **Test → Play** (oder im veröffentlichten Spiel als Owner).
2. Einen Run starten (PLAY SOLO), im Debug-Feld **„Showcase scene"** drücken.
3. **F6** (Menüs weg), mit **F7** die Kamera wählen: „Close" oder „Low hero" für Thumbnails, „Wide" für die Horde.
4. Screenshot: Windows **Win + Shift + S** (Bereich wählen). Clip: Windows **Win + Alt + R** (Xbox Game Bar) oder OBS. Für TikTok/Shorts das Fenster hochkant stellen oder später zuschneiden.
5. **F6** drückt alles wieder ein.

**Clip-Ideen (15–30 s, Plan Abschnitt 22):**

| Clip | So geht's |
| --- | --- |
| „Eine gegen 140" | Showcase scene, Kamera Wide, 10 s nur ausweichen und dashen, dann Close |
| Waffen verschmelzen | Im Shop zwei gleiche Waffen kaufen, Verschmelzen zeigen, dann Showcase |
| Boss-Finale zu viert | 4 Spieler (echte Freunde), Debug „Skip to boss", Kamera Low hero |
| Rettung in letzter Sekunde | Mitspieler geht down (Debug „Knock me down"), der andere rettet ihn bei „DOWN 1 s" |
| Endlos-Modus | Danger 5 + Endless, späte Welle, Kamera Wide |

## 5. Fragebogen (Creator Hub → Experience → Audience → Maturity & Compliance Questionnaire)

So beantworten, wie das Spiel heute ist (bei Unsicherheit lieber strenger):

- **Gewalt:** ja, **Fantasy-Gewalt ohne Blut** (Laternen-Waffen gegen Schattenwesen, Gegner zerfallen zu Rauch). Kein realistisches Blut, keine Verstümmelung.
- **Blut, Horror:** kein Blut; Horror höchstens „leicht" (dunkle Kreaturen mit leuchtenden Augen, keine Schockeffekte).
- **Grobe Sprache, Alkohol/Drogen, Glücksspiel, romantische Inhalte:** nein.
- **Zufällige kostenpflichtige Gegenstände (Lootboxen):** nein (Embers-Pakete und Pässe geben feste Inhalte).
- **Käufe:** ja (Game Passes VIP und Double Embers, Developer Products Revive, Rerolls, Ember-Pakete, Server Boost).
- **Text-Chat/Sprach-Chat:** Standard-Roblox-Chat, nichts Eigenes.
- **Nutzer-Inhalte, Teilen von Links, soziale Medien:** nein.

Das Ergebnis ist voraussichtlich „Mild" (9+). Der Plan sieht den Soft Launch für 16+ vor; das ist eine Einstellung bei der Zielgruppe, kein Fragebogen-Ergebnis.

## 6. Vor dem Launch: Liste für den Owner

Erledigt = der Debug-Knopf „Launch check" zeigt `[ok]`. Reihenfolge = Vorschlag.

1. **Live-Experience festlegen.** Regel aus CLAUDE.md: getestet wird gegen die Test-Experience, nie gegen Live-Daten. Für den Launch also eine eigene Experience „Lanternfall" mit zwei Places (Hub + Run) anlegen; Pässe, Produkte und Badges dort neu anlegen. Alle IDs (Universe-ID, beide Place-IDs, 2 Pass-, 6 Produkt-, 5 Badge-IDs) an Claude/ChatGPT schicken; die tragen sie als neuen Eintrag in `Config/Places`, `Config/Store`, `Config/Badges` ein. Danach in der Test-Experience deren Universe-ID als `gameId` setzen, damit Live nie Test-IDs benutzt (der Launch-Check meldet das als MUST).
2. **Badge-IDs** (5 Badges, Namen und Texte in `Config/Badges.luau`) anlegen und schicken.
3. **Musik-IDs** (7 Stücke: Lobby, Welle, Shop, Boss, Ergebnis, Sieg, Niederlage) in der Toolbox aussuchen und schicken.
4. ~~15 eigene Sounds~~ erledigt (31.10.2026); in der Live-Experience gehen sie weiter, solange die Audio-Dateien für sie freigegeben sind (Creator Hub → Audio → Berechtigungen).
5. **Places einstellen:** Hub max. 24 Spieler, Run-Place max. 4; beide mit dem aktuellen Code veröffentlichen (Rojo verbunden → Datei → Veröffentlichen). Avatar: R15 only. Private Server: an (Plan: 100 Robux/Monat).
6. **Handy-Test** auf einem echten, eher alten Handy: ein ganzer Run, Grafik LOW ansehen, Ziel ≥ 30 FPS.
7. **Testkäufe** im veröffentlichten Spiel (Studio-Testkäufe kosten nichts, echte schon: lieber in Studio).
8. **Fragebogen** ausfüllen (Abschnitt 5), Spielseite (Abschnitt 2), Icon und Thumbnails (Abschnitt 3).
9. **Closed Test:** 10–20 Tester über einen privaten Server, Feedback sammeln. Danach öffentlich schalten, Roblox Ads mit kleinem Budget (Vorschlag 50–100 €), Clips posten.
10. Nach dem Start: Creator Hub → Analytics (Retention D1/D7, Funnel „First Night") nach 3–7 Tagen ansehen.
