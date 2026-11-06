# Originale Hauptspiel-Waffensprites

62 unveränderte transparente 96×96-PNGs aus der vom Owner verlinkten [Brotato-Waffenseite](https://brotato.wiki.spellsandguns.com/Weapons), abgerufen am 06.11.2026. Original-Art: Brotato / Blobfish. Vom Owner für seinen privaten Umbau angefordert.

- `catalog.json`: Originalwerte pro Stufe und Zuordnung zu den kompatiblen internen IDs.
- `sprites/`: exakte Originaldateien; `sprites.json` enthält Quelle, Größe und SHA-256 jeder Datei.
- `contact-sheet.jpg`: Übersicht aller 62 Waffen zur visuellen Prüfung; ausschließlich für die Übersicht skaliert.
- `roblox-assets.json`: 62 eindeutige Image-Assets unter dem Experience-Besitzer.
- `validation.json`: Prüfstand und native Roblox-Ladeprüfung aller Bilder (`Success`).

Shop, Startwaffen, HUD und gehaltene Welt-Sprites lesen dieselbe `UI/WeaponImages`-Tabelle. Die alten eigenen Waffenbilder werden dort über den angehängten Originalblock ersetzt. Größe und Ausrichtung im Spielfeld: `Config/WeaponVisuals`.

Die PNGs sind vollständig im Repo, die Experience wurde nicht veröffentlicht. Der im Studio geöffnete Stand enthielt zusätzliche 2D-Arbeit und wurde nicht überschrieben. Eine komplette Run-/Zwei-Client-Prüfung des Branchs bleibt daher erforderlich.

Daten neu einlesen: `python tools/import_brotato_weapons.py` (lädt fehlende Quell-Snapshots herunter); Bilder prüfen/herunterladen: `python tools/fetch_brotato_sprites.py` (Python + Pillow). Danach nur die generierten Luau-Dateien mit StyLua formatieren. Bereits heruntergeladene Originalbilder werden nicht verändert.
