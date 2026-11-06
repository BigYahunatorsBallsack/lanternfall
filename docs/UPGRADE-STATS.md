# Paket 21i: Originale Upgrade-Bilder und Hauptwerte

Der Owner hat am 06.11.2026 ausdruecklich originale Brotato-Bilder und Kartenwerte beauftragt. Grundlage ist die [Upgrade-Tabelle im Wiki, Revision 7968](https://brotato.wiki.spellsandguns.com/index.php?title=Upgrades&oldid=7968). Die 16 Upgrade-Arten mit je vier Stufen sind vollstaendig abgeglichen. Engineering IV war als einziger Wert abweichend und gibt jetzt +5 statt +6; HP bleibt auf den bereits eingefuehrten originalen +3/+6/+9/+12.

## Bilder und Einbindung

- 16 originale Upgrade-Illustrationen fuer Karten und 16 separate Originalsymbole fuer die Werteliste, unveraendert als transparente 96-x-96-PNGs. Das Wiki verwendet dieselbe Kartenillustration fuer alle vier Stufen eines Wertes.
- Dateien, Original-URLs, SHA-256 und alle 64 Kartenwerte: `assets/ui/stats/brotato/manifest.json`. Gegenueberstellung: `assets/ui/stats/brotato/Preview.png`.
- Alle 32 Bilder nach Ordnerfreigabe ueber Open Cloud als Image-Assets unter dem Experience-Besitzer 3898708794 hochgeladen. Alle sind Approved; alle 32 erreichten bei einer ContentProvider-Pruefung in Studio Edit Success. IDs und tatsaechliche Ergebnisse: `roblox-assets.json` und `studio-preload.json` im selben Ordner.
- `UI/PrimaryStatArt` enthaelt die zwei Bildtabellen. `StatImages` ergaenzt am Ende die 16 Symbol-Overrides. `Icons.draw` erkennt den bestehenden LevelUp-Screen und verwendet dort die separaten Kartenbilder. Der Kontext steckt im internen Illustration-Cache-Schluessel (`upgrade:<statId>` bzw. `stat:<statId>`), damit auch ein wiederverwendeter Bildhalter korrekt wechselt. Beide bestehenden Controller und ihre Aufrufe bleiben erhalten.
- Die 22 weiteren Stats haben in der Basisspiel-Tabelle keine Upgrade-Karten. Ihre bisherigen Bilder bleiben erhalten. Keine neuen Werte-IDs, Remotes oder Profilfelder.

## Pruefung

- Aktuellen GitHub-main zu Beginn geprueft; vor Abgabe den zwischenzeitlichen Waffen-Merge #77 (`5a1ec54`) konfliktfrei aufgenommen. Der veraltete urspruengliche Arbeitsordner bleibt unangetastet.
- 65 Tests bestanden, 0 fehlgeschlagen in sieben einzeln aufgerufenen Specs: UpgradeReference (17), PrimaryStatArt (6), UpgradePool (10), StatMath (8), Config (6), UiRedesign (10), StructuresB12 (8).
- Die neuen Tests pruefen die 64 serverseitig erzeugten Kartenwerte gegen die feste Wiki-Tabelle sowie Karten-/Stat-Kontext, Cache, Neuwurf, Wiederverwendung, Nebenwerte und Kistenbilder. Die auf dem aelteren Ausgangs-main vorhandenen UI-/Bauten-Mockfehler sind nach Aufnahme von #77 ebenfalls behoben; der finale Lauf hat keine solchen Fehlschlaege.
- `python tools/check-upgrade-reference.py` prueft offline PNG-Hashes, Transparenz, Groessen, alle Kartenwerte, Runtime-Bildtabellen und die gespeicherten Upload-/Preload-Ergebnisse. Bericht: `assets/ui/stats/brotato/validation.json`.
- StyLua fuer alle sechs geaenderten/neuen Luau-Dateien, Selene 0 Fehler / 11 bestehende Warnungen, Rojo-Build und Diff-Pruefung erfolgreich.
- Studio hat ausschliesslich temporaere, nicht ins Spiel eingehaengte ImageLabels zum Vorladen verwendet; sie wurden danach zerstoert. Kein Spielcode im offenen Studio geaendert, kein voller Branch-Run behauptet. Solo-, Zwei-Client- und Handy-Sichttest bleiben beim Owner.

## Testanleitung fuer den Owner

1. Die erzeugte Datei `lanternfall-upgrade-stats.rbxl` im Paket-Checkout oeffnen oder den PR-Branch mit Rojo laden. Play druecken, einen Charakter waehlen und den Run starten.
2. Ein Level gewinnen und die Welle beenden. Auf den Karten muessen jetzt die originalen Koerperteil-Motive erscheinen, etwa Herz, Lunge oder Zaehne. Eine Karte waehlen; die gewaehlten Werte muessen in der Stat-Liste ankommen.
3. STATS im Shop oeffnen. Dort stehen die separaten originalen Stat-Symbole, etwa das gruene Herz fuer Max HP oder die gekreuzten Werkzeuge fuer Engineering. Mit der PNG-Vorschau vergleichen.
4. Neuwurf auf den Karten ausprobieren: Das Bild muss zum neuen angebotenen Wert passen. Engineering IV zeigt +5; HP I-IV gibt +3/+6/+9/+12. Diese vollstaendige Zahlenpruefung ist zusaetzlich automatisiert.
5. Dasselbe mit zwei Clients und in der Handy-Vorschau pruefen: Bilder ohne Ueberlagerung und die bestehende Auswahl/Shop-Bedienung weiterhin nutzbar. Das offene Studio-Spiel wurde durch das Paket nicht automatisch synchronisiert.
