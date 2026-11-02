# [ChatGPT] Großes UI-Rework im Brotato-Stil

## [Strang B] UI – Bildkarten und klare Bildschirmaufteilung

**Was gebaut wurde:** Die textlastige Oberfläche erhält eine neue Gestaltung mit gezeichneten Charakter-/Waffenkarten, warmen Steinfarben, kräftigen Konturen und grünen Hauptaktionen. Shop-Angebote, Waffeninventar, Items und Werte sind klar getrennt; Play- und Shopaktionen bleiben beim Scrollen erreichbar. Das HUD ist kompakter und Dialoge sind einheitlich zentriert und scrollbar. Details und native Vorschauen: [UI-BROTATO-REWORK.md](UI-BROTATO-REWORK.md).

**Geteilte Dateien, die ich angefasst habe:** UI/Theme, Widgets, LobbyLayout, Dialog, neues UI/Icons; CharacterChoice, PartyController, HUDController, InputController, DebugController, ShopController, StatsController, LevelUpController. DESIGN-Ergänzung, eigene STATUS-Zeile und Anhang, drei bestehende UI-/Freischalt-Specs. Die UI-Überarbeitung wurde ausdrücklich vom Owner beauftragt; daher sind dies gezielte Änderungen, nicht ausschließlich Anhänge in den UI-Dateien.

**Neue Schnittstellen für den anderen Strang:** `Icons.draw(parent, kind, id)` und `Icons.holder(parent, size, order?)` für wiederverwendbare GUI-Illustrationen; `CharacterChoice.resize(width, height?)` berücksichtigt kurze Displays. Keine neuen Remotes, Daten- oder Balancewerte.

**Wunsch an den anderen Strang:** Keiner.

**Checks:** StyLua ✅ · Selene 0 Fehler / 11 vorhandene Warnungen (gecachte Roblox-API) · 69 Specs / 724 Tests ✅ · Rojo ✅ · Diff-Check ✅. Native Sichtprüfung von Lobby, HUD, Shop, Level-up, Settings und Ergebnissen; HD-720/1080 und Handy-Portrait/Querformat. Kauf, Sperre, Itemanzeige und mobile Werteansicht in Studio bedient. Kein neuer UI-Laufzeitfehler; bestehende fremde Asset-/Badge-Warnungen dokumentiert.

**Testanleitung für den Owner:**
1. Studio → Play: Charakter und Startwaffe wählen. Detailansicht prüfen, dann Play solo.
2. Debug → Skip wave: kaufen, sperren, Inventar ansehen und eine Waffe zum Verkaufen/Kombinieren wählen.
3. Handy-Emulator drehen: Shop scrollen, STATS öffnen und zurückgehen. Settings öffnen und schließen.

**Offene Punkte / Annahmen:** Physisches Handy und echter Zwei-Client-Studio-Test stehen aus; Mehrspieler-Flows wurden im Mock geprüft. Item-Symbole sind Kategorien, keine 114 individuellen Zeichnungen. Nur die UI-Module wurden in Studio synchronisiert; die Gegner-Art aus #56 blieb erhalten. Nicht veröffentlicht und nicht gemerged. Dieser Text ist vorbereitet, solange #56 wegen der Ein-PR-Regel offen bleibt.
