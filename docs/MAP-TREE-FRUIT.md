# Arena, Baum und Früchte

Visuelle Referenzen aus dem Brotato-Wiki: [Bäume](https://brotato.wiki.spellsandguns.com/Trees) und [Consumables](https://brotato.wiki.spellsandguns.com/Consumable). Die erste Umsetzung verwendete eigene Roblox-Parts und eigene Farben; es wurden keine Wiki-Bilder oder Spielassets eingebunden.

## Erste Umsetzung (bis 03.11.2026)

- Die Arena ist offen, quadratisch und hellgrau. Kleine Kiesel geben dem Boden Struktur, ohne die Bewegung zu blockieren.
- Der Baum hat einen breiten Stamm, drei runde grüne Kronenteile und zwei sichtbare hellgrüne Früchte. Er bleibt ein statisches Gegnerziel und nutzt weiterhin den bestehenden Gegnerpool.
- Eine Frucht erscheint als hellgrüne Kugel mit Reflex, Stiel und zwei Blättern. Der bestehende serverseitige Drop- und Heilungsablauf bleibt erhalten.

Studio-Sichtprüfung: Arena ohne Hindernisse und mit 85 Kieseln; Baum mit 11 Teilen; drei simulierte Frucht-Drops mit je fünf sichtbaren Teilen. Das Projekt baut mit Rojo. Die bestehenden Tests für Arena und Grafikeinstellungen wurden auf die neue Dekoration angepasst.

## Modell-Überarbeitung (03.11.2026)

Auf ausdrücklichen Wunsch des Owners verwenden Baum und Pickups nun dieselbe Art eigener, texturierter Cartoon-Meshes wie die neuen Gegner. Die früheren Part-Modelle sind nur noch Rückfallcode für den Baum. Der Baum nutzt den bestehenden Gegnerpool und denselben Trefferblitz; sein Stamm, Wurzelwerk, die breite unregelmäßige Krone und zwei vorn sichtbare Früchte bestehen aus fünf Mesh-Teilen plus Schatten. Der Baum bleibt unbeweglich und sein Trefferbereich bleibt gleich.

Die aufhebbare Frucht ist ein einzelnes hellgrünes Mesh mit kurzem Stiel und Blättern. Die normale Kiste ist eine grüne, dunkel eingefasste Beutekiste; die größere legendäre Kiste hat eine rote und goldene Oberfläche sowie einen dezenten Schimmer. Beide behalten den bestehenden serverseitigen Drop-, Heilungs- und Item-Ablauf. Je Pickup sind nur ein Mesh-Teil und bei der legendären Kiste ein zusätzlicher Schimmer zu bewegen.

Die Modelle wurden eigens in Roblox Studio erzeugt und die einzelnen Meshes und Texturen als Projekt-Assets veröffentlicht. Modell-IDs: Baum `113484973790810`, Frucht `85556399159639`, grüne Kiste `105485146945463`, legendäre Kiste `105964233819162`. Die verwendeten Einzel-Mesh- und Textur-IDs stehen in `EnemyRenderer/MeshCatalog.luau` und `PickupRenderer.luau`. Es wurden keine Brotato-Grafiken oder -Modelle übernommen. Die stilistischen Anhaltspunkte sind die [Brotato-Bäume](https://brotato.wiki.spellsandguns.com/Trees), [Consumables](https://brotato.wiki.spellsandguns.com/Consumables) und die bereits freigegebene Gegnerfamilie in `docs/ENEMY-ART.md`.
