# B10 – Charaktere und Testanleitung

Historischer Lieferumfang von B10: neun Charakterpakete (urspruenglich zehn; Blade Warden ist seit Paket 25 entfernt). **Aktuelle Anforderung seit 06.11.2026: alle Charaktere mit Originalnamen und originalen Brotato-Regeln 1:1. HP, Heilung und HP-Abzuege mit Faktor 1.** Der bisherige Katalog erfuellt diesen Gesamtumfang noch nicht. Die folgende Tabelle beschreibt den vorhandenen Code mit seinen internen IDs, keine vollstaendige Brotato-Abnahme. Sprites liefert ein anderer Agent. Die fruehere Beschraenkung dieses Dokuments auf neun Basisspiel-Charaktere ist keine Begrenzung des neuen Auftrags.

## Zuordnung und Quellen

Urspruenglicher Abgleich am 30.10.2026; HP-Angaben am 06.11.2026 an den aktuellen main angepasst. Die alte Beschraenkung auf eigene Anzeigenamen ist aufgehoben.

| Lanternfall | Referenz | Umsetzung |
| --- | --- | --- |
| Spark Mage | [Mage](https://brotato.wiki.spellsandguns.com/Mage) | Elemental ×1,25, Melee/Ranged ×0, Engineering ×0,5; Ash Serpent und Smoldering Wick zu Beginn |
| Night Watch | [Ranger](https://brotato.wiki.spellsandguns.com/Ranger) | +50 Range, zusätzliche Watchman Pistol; Ranged ×1,5, Max HP ×0,75; keine Nahkampfwaffen |
| Many Hands | [Multitasker](https://brotato.wiki.spellsandguns.com/Multitasker) | zwölf Plätze; +20 % Damage, −5 % je gehaltener Waffe; Setboni bleiben bei sechs gedeckelt |
| Sole Conductor | [One Armed](https://brotato.wiki.spellsandguns.com/One_Armed) | ein Platz; +200 % Attack Speed, Damage-Gewinne ×2 |
| Duel Maestro | [Gladiator](https://brotato.wiki.spellsandguns.com/Gladiator) | +5 Melee, −40 % Attack Speed, −30 Luck; +20 % Attack Speed je unterschiedlicher Waffen-ID; keine Fernkampfwaffen |
| Far Seer | [Hunter](https://brotato.wiki.spellsandguns.com/Hunter) | +100 Range; +1 % Damage je zehn Range; Crit ×1,25, Max HP ×0,67, Harvesting ×0 |
| Marble Host | [Chunky](https://brotato.wiki.spellsandguns.com/Chunky) | Max HP ×1,25; +1 % Damage je 3 dauerhafte Max HP; +3 Fruit Healing, −100 % Life Steal; Regen/Dodge ×0,5, Speed ×0 |
| Twin Ledger | [Generalist](https://brotato.wiki.spellsandguns.com/Generalist) | drei Nah-/drei Fernkampfplätze; +2 Melee je Ranged, +1 Ranged je zwei Melee; Umrechnung ohne Rückkopplung |
| Candle Scholar | [Apprentice](https://brotato.wiki.spellsandguns.com/Apprentice) | pro Team-Level +2 Melee, +1 Ranged/Elemental/Engineering und −2 Max HP zusätzlich zu normalen +1 Level-HP |

Die Multiplikatoren gelten für erworbene Werte einschließlich negativer Änderungen, nicht für die festen Startboni. Engineering ist bereits als Wert vorhanden; Bauten folgen in B12. Startitems benutzen die vorhandene B8-Effektverarbeitung und werden bei jedem neuen Run genau einmal vergeben.

## Shop, Auswahl und Kompatibilität

- Standard sechs Waffen, persönliche Grenzen serverseitig. Nah-/Fernkampf-Verbot gilt auch für direkte Waffenvergaben. Ein volles Teil-Limit erlaubt weiterhin den Kauf einer gleichen Waffenstufe zum Verschmelzen.
- Wunsch-Tags: 5 % Sonderziehung im passenden Seltenheitspool, danach normaler Fallback. Positive Werte und Effektboni des eigenen Item-Katalogs liefern die Affinitäten; Consumable/Burn erhalten passende Affinitäten. Das ist eine dokumentierte Annäherung an die Wiki-Tags. Keine Seltenheits-Erhöhung durch den Wunsch-Pool.
- Der Client markiert die Startwaffe erst nach Serverbestätigung. Fremde Charakterwahl, nicht angebotene Waffen und Änderungen während des eigenen Runs werden abgewiesen. Auswahl wird pro Spieler und Charakter innerhalb der Session gemerkt.
- `SparkMage` behält seine Profil-ID, bekommt aber ein neues Regelpaket. `LanternKeeper` und `Trapper` bleiben als gesperrte Alt-IDs lesbar. Freischaltungen folgen in Paket 13; die zehn neuen Pakete sind zum Testen alle frei.
- Keine Änderung am Arsenal, Profilformat oder RunFlow. Der Waffenservice setzt die gemeinsame technische Obergrenze auf das größte Charakterlimit und prüft persönliche Regeln vor jeder Vergabe.

## Test in Studio

1. [Pruefbranch als ZIP herunterladen](https://github.com/BigYahunatorsBallsack/lanternfall/archive/refs/heads/wp-b10-brotato-characters.zip), entpacken und aus diesem Ordner wie bisher `rojo serve` starten. Studio mit diesem Rojo-Projekt verbinden. Unter **Fenster → Ausgabe** die Ausgabe oeffnen. Diese Anleitung beschreibt bis zur Charakter-Erweiterung die neun bestehenden Pakete.
2. **Play** starten. In der Lobby müssen neun Charakterknöpfe sichtbar sein. Jeden kurz anklicken: Beschreibung und angebotene Startwaffen wechseln. Eine andere Startwaffe auswählen und **READY** drücken; genau diese muss im Run erscheinen.
3. **Spark Mage**: bei Start Snake und Scared Sausage sowie 9 Max HP (= 10 Basis minus 1 durch Snake) pruefen. **Night Watch**: zur gewaehlten Waffe kommt eine Pistol dazu; im Shop nur Fernkampfwaffen.
4. **Sole Conductor**: im Shop nur ein Waffenplatz. Gleiche Waffenstufe kaufen muss die gehaltene Waffe verbessern. Andere Waffe erst nach Verkauf aufnehmen. **Many Hands**: bis zwölf Waffen aufnehmen; Damage sinkt je zusätzlicher Waffe um fünf Punkte und steigt beim Verkauf wieder.
5. **Duel Maestro**: unterschiedliche Nahkampfwaffen erhöhen Attack Speed, zusätzliche Kopien nicht. **Twin Ledger**: maximal drei Nah- und drei Fernkampfwaffen; vierte gleiche Art blockiert, andere Art weiterhin erlaubt.
6. **Far Seer**: Range erhoeht Damage; **Marble Host**: dauerhafte Max HP erhoehen Damage, Speed-Items aendern Speed nicht; **Candle Scholar**: Level-up erhoeht die vier Angriffswerte, Max HP sinkt netto um eins (Untergrenze 1).
7. Einen Run beenden und neu starten. Alte Items und Charakterboni dürfen nicht mitgenommen werden. Danach mit **zwei Clients** testen (im selben Studio-Fenster zwischen Clients wechseln): verschiedene Charaktere und Startwaffen wählen, beide READY; Grenzen und Boni müssen pro Spieler getrennt bleiben.
8. Fenster kleiner ziehen beziehungsweise Handy-Vorschau prüfen: Charakterknöpfe, Beschreibung, Startwaffen und READY müssen bedienbar sein. Ausgabe auf rote Fehler prüfen.

## Automatisierte Abnahme und Grenzen

`CharactersB10.spec.luau` bootet den echten, unveränderten Katalog mit Server und Client und prüft alle neun Pakete, zwei Spieler, verbotene Auswahl, Startitems, Item-/Karten-/dynamische Multiplikatoren, Konvertierungen, Teil-Limits, zwölf Waffen, Kauf-Verschmelzung und Reset. Der bestehende Smoke-Test verwendet eine explizite alte Spark-Mage-Testfigur für seine allgemeinen Kampf-/Item-Szenarien; B10 wird unabhängig davon mit den produktiven Daten geprüft.

Nach Integration von main inklusive B9/Boss (`327e6f9`): 388 Tests in 31 Dateien bestanden, StyLua und Rojo-Build erfolgreich, Selene ohne Fehler (acht bestehende UI-Stilwarnungen).

Die Tests laufen über den vorhandenen Test-Prelude mit portablem Lune, weil hier kein Rust-Compiler vorhanden ist. Kein langer Balance-Bot-Lauf. Studio-Ansicht, echte Netzwerk-Latenz und Bedienbarkeit auf Geräten müssen nach Synchronisierung dieses Branches geprüft werden; die beim Entwickeln offene Studio-Experience enthielt den B10-Stand noch nicht.
