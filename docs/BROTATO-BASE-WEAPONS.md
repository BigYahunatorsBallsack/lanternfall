# Hauptspiel-Waffen – privater Brotato-Umbau

Owner-Auftrag vom 06.11.2026 ersetzt für dieses Waffenpaket die bisherige Regel eigener Namen und eigener Waffen. Quelle ist [Weapons](https://brotato.wiki.spellsandguns.com/Weapons), Datenstand laut Seite Patch 1.1.6.3, abgerufen am 06.11.2026. Alle 62 Einträge ohne DLC-Markierung sind enthalten; keine DLC-Waffen und keine eigenen Evolutionen.

## Werte und Kompatibilität

- `assets/weapons/brotato-base/catalog.json`: unveränderte Zahlen aus der Wiki-Datentabelle, pro verfügbarer Stufe I–IV. Schaden, Skalierung, Cooldown, Krit, Reichweite, Rückstoß, Lebensraub und Preis.
- `Config/Weapons`: ausführbare Datensätze plus Sondereffekte. Die bisherigen 26 internen IDs bleiben erhalten, damit Charakter-Startlisten, Freischaltungen und vorhandene Referenzen gültig bleiben. Angezeigt werden ausschließlich Originalnamen.
- Reichweite: 10 Wiki-Einheiten = 1 Stud wie im bestehenden Spiel. Max HP, Heilung und HP-Skalierungen nutzen die inzwischen auf main eingeführten Originaleinheiten (hpScale = 1). Die Beschreibung zeigt die Originalprozente.
- Die frühere gemeinsame Grenze von 12 Angriffen/s würde Chain Gun/Gatling Laser verfälschen. Die neuen Waffen behalten ihre Ausgangs-Cooldowns, schnelle Schüsse werden innerhalb des 15-Hz-Schritts begrenzt nachgeholt. `Arsenal` ist unverändert.
- Angriffsgeschwindigkeit mit positiven/negativen Boni verwendet weiter die bestehende Formel des Projekts; Brotatos genaue animationsabhängige Rundung und Nahkampf-Reichweitenwirkung sind damit keine vollständige Godot-Engine-Nachbildung. Projektilgeschwindigkeit, Trefferbreite, Fächerwinkel und Sprite-Abstände sind Anpassungen an die Roblox-Arena, keine aus der Wiki-Tabelle behaupteten Originalwerte.
- Explosionsgrößen folgen den relativen Größen auf [Explosions](https://brotato.wiki.spellsandguns.com/Explosions), multipliziert mit dem bestehenden Roblox-Grundradius 6 Studs.

## Sondereffekte

Eigene Angriffsmodule registrieren jede Waffe. Die gemeinsamen Brotato-Verhalten ergänzen das unveränderte Arsenal: kritabhängiges Durchbohren/Abprallen, Magazine, on-hit Projektile, Explosionen, Brennen, Verlangsamen, Hinrichtungen gewöhnlicher Gegner, kritische Materialgewinne, permanente Ethereal-Kill-Gewinne, temporäre Drill-/Railgun-/Scythe-Gewinne, Stick-Kopien, Excalibur-Rüstungsmalus, Lance-Stillstand und Sharp-Tooth-Lebensraub. Wrench/Screwdriver nutzen das vorhandene Bausystem; Pruner erhält einen Garten mit stufenabhängigem Fruchtintervall.

## Katalog

| Originalname | Interne ID | Mindeststufe |
| --- | --- | --- |
| Cacti Club | `CactiClub` | 1 |
| Chopper | `Chopper` | 1 |
| Circular Saw | `OrbitBlades` | 2 |
| Claw | `Claw` | 1 |
| Drill | `Drill` | 4 |
| Excalibur | `Excalibur` | 4 |
| Quarterstaff | `Quarterstaff` | 1 |
| Fist | `BrassKnuckles` | 1 |
| Flaming Brass Knuckles | `FlamingBrassKnuckles` | 2 |
| Ghost Axe | `WraithHatchet` | 1 |
| Ghost Flint | `SpiritFlint` | 1 |
| Hammer | `Shockwave` | 2 |
| Hand | `TithePalm` | 1 |
| Hatchet | `Hatchet` | 1 |
| Jousting Lance | `JoustingLance` | 1 |
| Knife | `RitualDirk` | 1 |
| Lightning Shiv | `ChainLightning` | 1 |
| Plank | `Plank` | 1 |
| Plasma Sledge | `PlasmaSledge` | 3 |
| Power Fist | `PowerFist` | 3 |
| Pruner | `ThornTrail` | 1 |
| Rock | `Gravestone` | 1 |
| Scissors | `Scissors` | 1 |
| Screwdriver | `RuneAwl` | 1 |
| Scythe | `Scythe` | 4 |
| Spear | `LamplighterPike` | 1 |
| Spiky Shield | `SpikyShield` | 1 |
| Stick | `Stick` | 1 |
| Sword | `DuskSabre` | 2 |
| Thief Dagger | `ThiefDagger` | 1 |
| Thunder Sword | `ThunderSword` | 3 |
| Torch | `Torch` | 1 |
| Wrench | `FoundryKey` | 1 |
| Chain Gun | `ChainGun` | 4 |
| Crossbow | `BoomerangAxe` | 1 |
| Double Barrel Shotgun | `ScatterBell` | 1 |
| Flamethrower | `CinderBreath` | 2 |
| Gatling Laser | `CathedralEngine` | 4 |
| Ghost Scepter | `GhostScepter` | 1 |
| Laser Gun | `LaserGun` | 1 |
| Medical Gun | `LeechCarbine` | 1 |
| Minigun | `Minigun` | 3 |
| Nuclear Launcher | `NuclearLauncher` | 3 |
| Obliterator | `Obliterator` | 3 |
| Pistol | `WatchmanPistol` | 1 |
| Potato Thrower | `PotatoThrower` | 2 |
| Railgun | `Railgun` | 1 |
| Revolver | `Revolver` | 1 |
| Rocket Launcher | `MortarLantern` | 2 |
| Shredder | `ShrapnelOrgan` | 1 |
| Shuriken | `Shuriken` | 1 |
| Slingshot | `Slingshot` | 1 |
| SMG | `RattleRepeater` | 1 |
| Sniper Gun | `SniperGun` | 3 |
| Taser | `GalvanicFork` | 1 |
| Wand | `SparkBolt` | 1 |
| DEX-troyer | `DEXtroyer` | 4 |
| Fireball | `Fireball` | 2 |
| Icicle | `WinterNeedle` | 1 |
| Particle Accelerator | `ParticleAccelerator` | 3 |
| Sharp Tooth | `SharpTooth` | 1 |
| Vorpal Sword | `VorpalSword` | 2 |

## Testanleitung für den Owner

1. Den Branch `wp-b7-brotato-base` mit Rojo synchronisieren oder die lokale Datei `lanternfall-brotato-base.rbxl` in einem separaten Studio-Fenster öffnen. Den derzeit offenen 2D-Arbeitsstand vorher speichern.
2. In der Lobby Blade Warden wählen. Startwaffen müssen Originalnamen und Originalbilder zeigen, zum Beispiel Pistol, Fist und Knife. Einen Run starten: dieselbe Waffe ist als 2D-Sprite neben der Figur sichtbar.
3. Im Debug-Menü `NextWeapon` durchgehen: jede der 62 Waffen erscheint mit eigenem Originalbild; stärkere Waffen beginnen direkt in ihrer Mindeststufe. Hammer schwingt, Circular Saw schwingt als einzelne Waffe und Crossbow bleibt beim Schuss sichtbar.
4. Im Shop zwei gleiche Waffen gleicher Stufe verschmelzen, eine verkaufen und ein neues Angebot kaufen. Name, Stufe, Bild und Werte müssen zusammenpassen. Bei zwei Sticks steigt der Schaden; Hand erhöht Harvesting, Excalibur verringert Armor.
5. An einem starken Gegner Crossbow/Shuriken mit hoher Crit Chance testen; Lightning Shiv/Cacti Club erzeugen zusätzliche Geschosse, Rocket Launcher explodiert auch bei einem tödlichen Treffer. Revolver/Chain Gun haben nach ihrem Magazin eine längere Pause.
6. Drill und Railgun mindestens zehn Sekunden halten, dann Schaden nehmen. Railgun verliert seinen Schadenszuwachs; Drill behält das Angriffstempo bis Wellenende. Pruner, Wrench und Screwdriver erzeugen Garten/Turm/Minen. Mit Scythe verliert die Figur regelmäßig HP, auch ohne Gegnerkontakt.
7. Mit zwei Clients prüfen, ob beide Spieler dieselben Waffen und Angriffe sehen. Auf dem Handy oder im Gerätesimulator Shopbilder, Lesbarkeit und Ausrichtung prüfen. Output darf keine neuen roten Luau-Fehler zeigen.
