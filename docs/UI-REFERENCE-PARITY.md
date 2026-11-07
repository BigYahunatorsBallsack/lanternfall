# UI nach den acht Owner-Referenzen

Paket 21k, 07.11.2026. Fortsetzung des freigegebenen UI-Reworks 21j, auf GitHub-main `e38a762`. Der veraltete lokale Ausgangsordner wurde nicht bearbeitet.

## Gestaltung und Umfang

Die gelieferten acht Screenshots bestimmen die Bildschirmaufteilung: Startmenue mit Aktionen links und grossem Titel rechts; danach Charakter-, Waffen- und Schwierigkeitswahl; kleine Bildkacheln unten und Detailfelder darueber. Im Run stehen eckige rote HP und gruene XP links, Welle und Sekunden in der Mitte. Offene Level-ups bekommen ein eigenes Zeichen. Beim Level-up bleiben HP, XP und Welle sichtbar, vier breite Karten zeigen kleine Bilder oben links und Choose unten. Der Shop hat vier hohe Angebote, breite separate Sperren, Preis und Materialsymbol mit getrennten Flaechen, Inventare unten und die Wertespalte rechts.

Lanternfall behaelt seine vorhandenen Charaktere, Namen und Bilder. Das Startmenue bietet die vorhandenen Funktionen Start, Collection, Co-op und Options. Es gibt keine funktionslosen Mods-/DLC-/Profilwahl-/Bann-Schalter und keine zusaetzlichen Charaktere oder Spielregeln. Die Gegnermenge, Arena und Weltgrafik sind nicht Teil dieses UI-Pakets. Der ruhige Menuehintergrund wird aus UI-Formen gezeichnet und braucht keinen weiteren Bild-Upload.

Desktop nutzt eine gemeinsame 1280-x-720-Geometrie mit Skalierung. Kleine Displays behalten lesbare Schrift und scrollbare Auswahlseiten; Level-up-Karten werden dort ein- oder zweispaltig. Shop-Aktionen bleiben ausserhalb des Scrollbereichs; Primary/Secondary ist im kompakten Shop ueber STATS erreichbar. Koop, gespeicherte Sammlung, weitere Einstellungen, Verkauf, Verschmelzen und Bonus-Neuwuerfe bleiben vorhanden.

## Technische Aenderungen

- `LobbyLayout` ordnet bestehende Kontrollen neu; `CharacterChoice.Chosen` und `getStartWeapon` sind lokale UI-Schnittstellen. Die Charakterseite wartet bei einem Wechsel auf die vom Server bestaetigte Auswahl. Gesperrte Charaktere fuehren nicht weiter.
- `LevelComposition` ordnet die vorhandenen Karten neu. `LevelUpController.Changed(open)` aktualisiert HUD und Wertespalte bei der Kartenwahl, auch ohne weiteren Phasenwechsel. F wuerfelt je nach geoeffnetem Bildschirm Shop oder Level-up neu; die vorhandenen Serverpruefungen bleiben massgeblich.
- Preise bekommen ein eigenes Textfeld neben dem Materialsymbol. Die Materialanzeige bleibt beim Level-up unter den HP-/XP-Leisten. Die Wertespalte hat explizite Innenraender, damit rechte Zahlen nicht abgeschnitten werden. Elite-/Horden-Vorschau liegt unter GO und erscheint nur mit einer tatsaechlichen geplanten Welle.
- Die Waffenvorschau zeigt Reichweite in den originalen Punkten statt in Roblox-Studs und den effektiven Schaden neben der Skalierungsformel. `OfferText.stats` bleibt unveraendert mit den Kampfwerten vergleichbar.
- Kann Roblox ein Stat-/Kartenbild nicht laden, erscheint das vorhandene gezeichnete Symbol. Ein neuer Regressionstest reproduziert den Ladefehler vor dem Fix und besteht danach.
- Bestehende Anzeigeerwartungen in `Smoke`, `UiRedesign` und `HubStudio` wurden an die neuen Seiten und Texte angepasst. Kauf-, Eingabe-, Sperr-, Rechte-, Tutorial- und Auswahlpruefungen bleiben erhalten. Die First-Night-Hinweise behalten ihre ausfuehrlichen Wellenangaben.

Keine neuen Remotes, Config-Balancingwerte, Profildaten oder Serverdienste. Die beteiligten gemeinsamen UI-Dateien und Anzeigecontroller werden im Rahmen des ausdruecklichen UI-Auftrags umgestaltet; dies ist keine reine Anhaenge-Aenderung.

## Pruefungen

Vollstaendiger Vergleich mit identischem Zufallsstart 1234, jede Spec in einem eigenen Lune-Aufruf: main **977 bestanden / 26 fehlgeschlagen** in 80 Specs; UI **982 / dieselben 26** in 81 Specs. Keine neue fehlgeschlagene Pruefung. Rust/Cargo wurde nicht verwendet; der vorhandene Lune-Runner fuehrt dieselbe Test-Prelude aus. Bericht: [ui-reference-validation.json](ui-reference-validation.json).

StyLua fuer alle geaenderten Luau-Dateien, Selene **0 Fehler / 11 vorhandene Warnungen**, Rojo-Build und Diff-Pruefung. Selene verwendet den vorhandenen API-Cache, weil der automatische API-Download hier scheitert.

Native Solo-Pruefung in einer separaten lokalen Studio-Datei, niemals in der geoeffneten Main-Lobby: vor der Sichtpruefung 358 Produktionsquellen gegen den UI-Checkout verglichen, ohne Abweichung. Start, Charakter, Waffe, Schwierigkeit und READY tatsaechlich geklickt. HUD und Level-up-Bilder angesehen, eine Karte mit Taste 1 gewaehlt. Shop-Kauf: **115 -> 98** bei Preis 17; danach SOLD. Angebot gesperrt, F: **98 -> 97**; das gesperrte Angebot bleibt und wandert im neuen Angebotssatz auf Platz 1. GO startet **WAVE 2**, zeigt 25 Sekunden und blendet den Shop aus. Die im Test verwendeten bestehenden Debug-Schalter und zusaetzlichen Materialien werden nicht gespeichert.

Die native Sichtpruefung fand und beseitigte die ueberlagerten Materialien, ueberlappende Preiszahl/Symbol sowie abgeschnittene Werte rechts. Bei einem fruehen lokalen Preload schlugen die Kartenbilder fehl; im spaeteren Lauf wurden sie sichtbar. Die neue Fehlerdarstellung ist deshalb unabhaengig von der Bildverfuegbarkeit getestet. Vorhandene Asset-Meldungen zu 203785492 und den beiden generierten Bodenbildern bleiben ausserhalb dieses Pakets. Eine fehlgeschlagene MCP-Abfrage des Run-Zustands erzeugte eine AssistantCommand-Meldung; das war Testcode, kein Fehler im Spielcontroller.

**Nicht geprueft:** nativer Zwei-Client-Lauf, physisches Handy, veroeffentlichter Run-Place und alle Charakterbilder. Programmatische Groessenwechsel ersetzen diese Abnahme nicht. Kein Publish und kein Merge.

## Owner-Test

1. Die finale Datei `lanternfall-ui-reference.rbxl` aus dem Paket-Checkout oeffnen oder den PR-Branch per Rojo in die Test-Experience laden. Play: Start -> Charakter -> Startwaffe -> Gefahr -> READY. Mit Back durch die Seiten zurueckgehen; gesperrte Charaktere duerfen nicht weiterfuehren. Collection, Co-op und Options oeffnen.
2. Im Run HP, XP, Welle und Sekunden ansehen. Debug: Team +1 level und End this wave. Eine Karte klicken oder 1 druecken. HP/XP bleiben waehrend der Wahl sichtbar; danach erscheinen die Shop-Angebote. Fuer eine zweite Wahl F ausprobieren.
3. Im Shop kaufen, ein Angebot sperren und F druecken. Preis und Materialsymbol muessen getrennt lesbar sein; das gesperrte Angebot muss erhalten bleiben. Getragene Waffen verkaufen/verschmelzen, Primary/Secondary wechseln und GO druecken. Bei Gefahr 2 oder hoeher darf die Wellen-Vorschau GO nicht ueberdecken.
4. Mit zwei Clients wiederholen. Auf dem Handy Hoch- und Querformat pruefen: Auswahl und Karten scrollen, Sammlung schliessen, STATS und SHOP wechseln, GO erreichen. Auffaellige oder fehlende Charakterbilder getrennt melden.
