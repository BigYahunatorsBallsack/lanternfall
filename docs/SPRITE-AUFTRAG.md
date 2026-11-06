# Sprite-Auftrag für ChatGPT

Du zeichnest die Bilder von Lanternfall. Claude baut den Code; fertige Bilder ersetzen Platzhalter, ohne dass sich am Code etwas ändert. Du änderst keinen Code und lädst nichts bei Roblox hoch.

## Look

Der Owner will den Look so nah wie möglich an Brotato:

- flache Cartoon-Farben, dicke dunkle Kontur, kaum Schattierung
- große, einfache Formen, die auch bei 60 Pixeln Größe auf dem Handy lesbar bleiben
- überall dieselbe Konturstärke und dieselbe Farbwelt, damit alles zusammenpasst
- Charaktere: kleine runde Knollen-Figur mit Gesicht, **ohne Füße und Beine** (die Füße sind das eigene Bild `shared/foot`, das Spiel bewegt sie), Unterschiede über Gesicht und Accessoires
- Gegner: kleine, freche Monster mit klarer Silhouette

**Alles neu zeichnen.** Bilder aus Brotato oder dem Brotato-Wiki nicht kopieren, nicht abpausen und nicht als Eingabe verwenden. Der Stil darf ähnlich sein, die Bilder müssen eigene sein: Sie landen auf dem Roblox-Konto des Owners.

## Technik

- PNG mit echter Transparenz, kein Karomuster und kein einfarbiger Hintergrund
- quadratisch, am besten 1024 × 1024; verkleinert wird beim Import
- genau eine Figur pro Bild, vollständig im Bild, mit etwas Rand
- keine Schrift, kein Boden, kein Schatten, kein Leuchtrand: Schatten, Treffer-Blitz, Hüpfen und Wackeln macht das Spiel selbst
- **nur ein Bild pro Figur**, keine Animationsbilder
- Figuren von vorn gezeichnet, wie in Brotato, obwohl die Kamera von oben schaut; sie schauen nach vorn oder nach rechts, läuft eine Figur nach links, spiegelt das Spiel sie
- Charaktere halten **keine Waffen**: Waffen schweben wie in Brotato um die Figur
- Boden-Bilder sind nahtlos kachelbar und haben keine Transparenz

## Reihenfolge

1. **Probe zuerst:** `characters/NightWatch`, `enemies/Shadeling`, `enemies/Brute`, `pickups/Fruit`, `floors/Arena`. Der Owner schaut sie im Spiel an und gibt den Look frei.
2. Danach der Rest. Teil-Lieferungen sind in Ordnung; fehlende Bilder bleiben Platzhalter.

## Abgabe

1. Dateien exakt so benennen wie unten, Groß- und Kleinschreibung zählt.
2. Prüfen: `python tools/art2d/import_sprites.py check`
3. Branch `wp-26-sprites`, PR-Titel `[ChatGPT] Paket 26 Sprites`, sonst wie in `AGENTS.md` und `docs/PARALLEL.md`.

Hochladen und Eintragen der Bild-IDs macht Claude danach mit `tools/art2d/import_sprites.py` (`build`, Upload, `apply`).

## Liste

Kommt die Liste nicht passend hier an, gilt `tools/art2d/sprites.json`.

<!-- SPRITE-LIST -->

### Charaktere (bleiben neun, kein Blade Warden)

| Datei | Was |
| --- | --- |
| `assets/world2d/final/characters/NightWatch.png` | Standard-Figur. Schütze mit dunkler Mütze, schräger misstrauischer Blick. Vorbild-Regeln: Ranger. |
| `assets/world2d/final/characters/SparkMage.png` | Magier, frech grinsend, kleine gelbe Funken am Körper. Vorbild-Regeln: Mage. |
| `assets/world2d/final/characters/ManyHands.png` | Gestresst, Schweißtropfen, viele kleine dunkle Hände rund um den Körper. Vorbild-Regeln: Multitasker. |
| `assets/world2d/final/characters/SoleConductor.png` | Lässig, ein Auge fast zu, schiefes Lächeln. Vorbild-Regeln: One Armed. |
| `assets/world2d/final/characters/DuelMaestro.png` | Eitler Fechter, hochgezogene Braue, kleines Lächeln. Vorbild-Regeln: Gladiator. |
| `assets/world2d/final/characters/FarSeer.png` | Kneift ein Auge zu, hält ein Fernrohr ans andere. Vorbild-Regeln: Hunter. |
| `assets/world2d/final/characters/MarbleHost.png` | Breit und schwer, müder Blick, Risse wie Marmor. Vorbild-Regeln: Bull. |
| `assets/world2d/final/characters/TwinLedger.png` | Listig, zwei unterschiedliche Augen, kleines Lächeln. Vorbild-Regeln: Ambidextrous. |
| `assets/world2d/final/characters/CandleScholar.png` | Traurig-müde, Augenringe, offenes Buch mit brennender Kerze. Vorbild-Regeln: Apprentice. |

### Gegner

| Datei | Was |
| --- | --- |
| `assets/world2d/final/enemies/Shadeling.png` | Kleiner Standard-Gegner, läuft stumpf auf den Spieler zu. Muss bei großer Menge gut lesbar sein. |
| `assets/world2d/final/enemies/Stalker.png` | Schneller, dünner Verwandter des Shadeling. |
| `assets/world2d/final/enemies/AbyssShadeling.png` | Dunklere, gefährlichere Variante des Shadeling. |
| `assets/world2d/final/enemies/Brute.png` | Groß, schwer, langsam, viel Masse. |
| `assets/world2d/final/enemies/AbyssBrute.png` | Dunklere, gefährlichere Variante des Brute. |
| `assets/world2d/final/enemies/Thornback.png` | Massig, mit Stacheln auf dem Rücken; wirft Stacheln zurück, wenn man ihn trifft. |
| `assets/world2d/final/enemies/Spitter.png` | Bleibt auf Abstand und spuckt Geschosse, großer Mund. |
| `assets/world2d/final/enemies/Skulker.png` | Hinterhältiger Schütze, duckt sich, flieht vor dem Spieler. |
| `assets/world2d/final/enemies/Herald.png` | Unterstützer, stärkt andere Gegner: Horn oder Fahne, goldene Akzente. |
| `assets/world2d/final/enemies/Mender.png` | Heiler, heilt andere Gegner: grüne Akzente, freundlich-unheimlich. |
| `assets/world2d/final/enemies/Charger.png` | Stürmt in gerader Linie: gesenkter Kopf, Hörner, vorgebeugt. |
| `assets/world2d/final/enemies/Reaper.png` | Schlägt im Halbkreis zu: lange Klingenarme. |
| `assets/world2d/final/enemies/Splitter.png` | Rund und prall, zerplatzt beim Tod in kleine Splitlinge. |
| `assets/world2d/final/enemies/Splitling.png` | Winziger Rest des Splitter, gleiche Farbe. |
| `assets/world2d/final/enemies/BroodEgg.png` | Unbewegliches Ei, aus dem Gegner schlüpfen. Kein Gesicht nötig. |
| `assets/world2d/final/enemies/Looter.png` | Flieht mit einem Beutel auf dem Rücken, lässt beim Tod eine Kiste fallen. |
| `assets/world2d/final/enemies/Gobbler.png` | Frisst herumliegende Beute: riesiger Mund, runder Bauch. |
| `assets/world2d/final/enemies/Tree.png` | Kleiner Baum, steht still und lässt Früchte fallen. Dicker Stamm, runde Krone. |
| `assets/world2d/final/enemies/LanternEater.png` | Boss. Riesiges Raubtier, jagt und stürmt, glühender Bauch. |
| `assets/world2d/final/enemies/HollowSeer.png` | Boss. Schwebende Gestalt mit großem leuchtendem Auge, wirkt Magie. |
| `assets/world2d/final/enemies/BrassRam.png` | Champion. Messing-Widder, stürmt und prallt von Wänden ab. |
| `assets/world2d/final/enemies/Flayer.png` | Champion. Hager mit langen Krallen. |
| `assets/world2d/final/enemies/Abbot.png` | Champion. Kuttenträger mit Kapuze, schnell. |
| `assets/world2d/final/enemies/MireJaw.png` | Champion. Sumpfwesen, vor allem Maul. |
| `assets/world2d/final/enemies/Monolith.png` | Champion. Lebender Steinblock. |
| `assets/world2d/final/enemies/SickleWraith.png` | Champion. Schwebender Geist mit zwei Sicheln. |
| `assets/world2d/final/enemies/BroodMatron.png` | Champion. Dicke Mutter-Kreatur mit Eiern am Körper. |
| `assets/world2d/final/enemies/StoneSeraph.png` | Champion. Engel aus Stein mit Flügeln. |

### Beute

| Datei | Was |
| --- | --- |
| `assets/world2d/final/pickups/Fruit.png` | Grüne Frucht, heilt beim Einsammeln. |
| `assets/world2d/final/pickups/Crate.png` | Normale Holzkiste mit dunkler Kontur. |
| `assets/world2d/final/pickups/LegendaryCrate.png` | Besondere Kiste, rot und gold. |

### Bauten und Begleiter

| Datei | Was |
| --- | --- |
| `assets/world2d/final/structures/BrassSentry.png` | Geschützturm aus Messing, schießt Kugeln. |
| `assets/world2d/final/structures/CinderSentry.png` | Geschützturm, der brennt; orange. |
| `assets/world2d/final/structures/PrismSentry.png` | Geschützturm mit Kristall; türkis. |
| `assets/world2d/final/structures/MercySentry.png` | Heil-Turm; grün mit Kreuz oder Herz. |
| `assets/world2d/final/structures/SiegeSentry.png` | Schwerer Mörser-Turm; violett. |
| `assets/world2d/final/structures/RuneMine.png` | Flache Mine am Boden; gold. |
| `assets/world2d/final/structures/MoonGarden.png` | Kleines Beet mit Früchten; grün. |
| `assets/world2d/final/structures/OrbitWisp.png` | Kleines schwebendes Licht, kreist um den Spieler; blau. |
| `assets/world2d/final/structures/StormFamiliar.png` | Kleines Sturm-Tier, schwebt, schießt Blitze; violett. |

### Welt

| Datei | Was |
| --- | --- |
| `assets/world2d/final/world/Chest.png` | Truhe, die ein Elite-Gegner hinterlässt. Holz und Gold, geschlossen. |

### Lobby

| Datei | Was |
| --- | --- |
| `assets/world2d/final/lobby/Arch.png` | Großer Torbogen eines Lobby-Portals, von vorn. Innen frei und transparent: dahinter leuchtet das Spiel. |
| `assets/world2d/final/lobby/Beacon.png` | Leuchtfeuer auf einem Sockel, von vorn. |
| `assets/world2d/final/lobby/Lamp.png` | Laternenpfahl, von vorn. |
| `assets/world2d/final/lobby/CornerRuin.png` | Kleine Ruine für die Ecken der Lobby, von vorn. |

### Boden (nahtlos kachelbar, ohne Transparenz)

| Datei | Was |
| --- | --- |
| `assets/world2d/final/floors/Arena.png` | Boden des Kampffelds: ruhig, hell, damit Gegner gut sichtbar bleiben. Nur leichte Flecken, kleine Steine oder Gras. |
| `assets/world2d/final/floors/Lobby.png` | Boden der Lobby, gleiche Machart, etwas anderer Farbton. |

### Waffen (fehlt ein Bild, bleibt das heutige)

| Datei | Was |
| --- | --- |
| `assets/world2d/final/weapons/OrbitBlades.png` | Kreisende Klingen. |
| `assets/world2d/final/weapons/SparkBolt.png` | Funken-Stab. |
| `assets/world2d/final/weapons/Shockwave.png` | Schockwellen-Hammer. |
| `assets/world2d/final/weapons/ChainLightning.png` | Kettenblitz-Stab. |
| `assets/world2d/final/weapons/ThornTrail.png` | Dornen-Waffe. |
| `assets/world2d/final/weapons/BoomerangAxe.png` | Bumerang-Axt. |
| `assets/world2d/final/weapons/BrassKnuckles.png` | Schlagring. |
| `assets/world2d/final/weapons/RitualDirk.png` | Ritualdolch. |
| `assets/world2d/final/weapons/LamplighterPike.png` | Lange Pike. |
| `assets/world2d/final/weapons/DuskSabre.png` | Säbel. |
| `assets/world2d/final/weapons/Gravestone.png` | Grabstein als Keule. |
| `assets/world2d/final/weapons/TithePalm.png` | Gierige Hand. |
| `assets/world2d/final/weapons/WraithHatchet.png` | Geister-Beil. |
| `assets/world2d/final/weapons/SpiritFlint.png` | Feuerstein. |
| `assets/world2d/final/weapons/WatchmanPistol.png` | Pistole. |
| `assets/world2d/final/weapons/RattleRepeater.png` | Schnellfeuer-Gewehr. |
| `assets/world2d/final/weapons/ScatterBell.png` | Schrotflinte mit Glockenmündung. |
| `assets/world2d/final/weapons/ShrapnelOrgan.png` | Mehrläufige Splitter-Kanone. |
| `assets/world2d/final/weapons/CinderBreath.png` | Flammenwerfer. |
| `assets/world2d/final/weapons/GalvanicFork.png` | Blitz-Gabel. |
| `assets/world2d/final/weapons/LeechCarbine.png` | Blutsauger-Gewehr. |
| `assets/world2d/final/weapons/CathedralEngine.png` | Riesige Kanone. |
| `assets/world2d/final/weapons/MortarLantern.png` | Mörser in Laternenform. |
| `assets/world2d/final/weapons/WinterNeedle.png` | Eisnadel. |
| `assets/world2d/final/weapons/FoundryKey.png` | Großer Schraubenschlüssel. |
| `assets/world2d/final/weapons/RuneAwl.png` | Runen-Ahle. |

### Weiße Bilder, die das Spiel einfärbt (nur Graustufen, Motiv mittig, Glow weich auslaufend)

| Datei | Was |
| --- | --- |
| `assets/world2d/final/shared/glow.png` | Weicher runder Lichtfleck, zur Kante hin ganz durchsichtig. Für Leuchten und Explosionen. |
| `assets/world2d/final/shared/orb.png` | Sammel-Material (XP), kleines rundes Korn. Bekommt je Wert eine Farbe. |
| `assets/world2d/final/shared/bolt.png` | Geschoss, zeigt nach rechts. Wird in Flugrichtung gedreht. |
| `assets/world2d/final/shared/beam.png` | Weiche senkrechte Lichtsäule. |
| `assets/world2d/final/shared/crown.png` | Strahlenkranz über Elite-Gegnern, mittig, dreht sich im Spiel. |
| `assets/world2d/final/shared/lanternCageFrame.png` | Laterne Käfig: Rahmen. |
| `assets/world2d/final/shared/lanternCageGlow.png` | Laterne Käfig: Leuchtkern. |
| `assets/world2d/final/shared/lanternOrbFrame.png` | Laterne Kugel: Rahmen. |
| `assets/world2d/final/shared/lanternOrbGlow.png` | Laterne Kugel: Leuchtkern. |
| `assets/world2d/final/shared/lanternSpireFrame.png` | Laterne Turm: Rahmen. |
| `assets/world2d/final/shared/lanternSpireGlow.png` | Laterne Turm: Leuchtkern. |
| `assets/world2d/final/shared/foot.png` | Ein Fuß der Charaktere, dunkel und rund, von vorn. Das Spiel zeichnet ihn zweimal und bewegt ihn im Wechselschritt. |

### Item-Icons (fehlt ein Bild, bleibt das heutige). Name und Wirkung: src/shared/Config/Items.luau

| Datei | Was |
| --- | --- |
| `assets/world2d/final/items/Satchel.png` | Item-Icon. |
| `assets/world2d/final/items/Vitality.png` | Item-Icon. |
| `assets/world2d/final/items/Haste.png` | Item-Icon. |
| `assets/world2d/final/items/Focus.png` | Item-Icon. |
| `assets/world2d/final/items/Magnet.png` | Item-Icon. |
| `assets/world2d/final/items/Might.png` | Item-Icon. |
| `assets/world2d/final/items/Armor.png` | Item-Icon. |
| `assets/world2d/final/items/WaxHeart.png` | Item-Icon. |
| `assets/world2d/final/items/CrackedLens.png` | Item-Icon. |
| `assets/world2d/final/items/BoneKnuckles.png` | Item-Icon. |
| `assets/world2d/final/items/TallowCandle.png` | Item-Icon. |
| `assets/world2d/final/items/MothWing.png` | Item-Icon. |
| `assets/world2d/final/items/GraveSpade.png` | Item-Icon. |
| `assets/world2d/final/items/RustedCoin.png` | Item-Icon. |
| `assets/world2d/final/items/FlintShard.png` | Item-Icon. |
| `assets/world2d/final/items/WardRune.png` | Item-Icon. |
| `assets/world2d/final/items/PawnTicket.png` | Item-Icon. |
| `assets/world2d/final/items/ChitteringFamiliar.png` | Item-Icon. |
| `assets/world2d/final/items/BoneCharm.png` | Item-Icon. |
| `assets/world2d/final/items/LeechJar.png` | Item-Icon. |
| `assets/world2d/final/items/AshBlindfold.png` | Item-Icon. |
| `assets/world2d/final/items/SignalBanner.png` | Item-Icon. |
| `assets/world2d/final/items/Brazier.png` | Item-Icon. |
| `assets/world2d/final/items/OilFlask.png` | Item-Icon. |
| `assets/world2d/final/items/LoadedDice.png` | Item-Icon. |
| `assets/world2d/final/items/NarrowScope.png` | Item-Icon. |
| `assets/world2d/final/items/Whetstone.png` | Item-Icon. |
| `assets/world2d/final/items/AcidVial.png` | Item-Icon. |
| `assets/world2d/final/items/StaticBracelet.png` | Item-Icon. |
| `assets/world2d/final/items/PowderPouch.png` | Item-Icon. |
| `assets/world2d/final/items/LanternOil.png` | Item-Icon. |
| `assets/world2d/final/items/BitterTonic.png` | Item-Icon. |
| `assets/world2d/final/items/JesterBell.png` | Item-Icon. |
| `assets/world2d/final/items/DowsingRod.png` | Item-Icon. |
| `assets/world2d/final/items/QuiltedCoat.png` | Item-Icon. |
| `assets/world2d/final/items/TitheBox.png` | Item-Icon. |
| `assets/world2d/final/items/RottingHeart.png` | Item-Icon. |
| `assets/world2d/final/items/ScrapAltar.png` | Item-Icon. |
| `assets/world2d/final/items/GlassLantern.png` | Item-Icon. |
| `assets/world2d/final/items/FourLeafCharm.png` | Item-Icon. |
| `assets/world2d/final/items/EelFin.png` | Item-Icon. |
| `assets/world2d/final/items/BloodOffering.png` | Item-Icon. |
| `assets/world2d/final/items/IronShackle.png` | Item-Icon. |
| `assets/world2d/final/items/ClockworkGears.png` | Item-Icon. |
| `assets/world2d/final/items/TomeOfEchoes.png` | Item-Icon. |
| `assets/world2d/final/items/SmokeMantle.png` | Item-Icon. |
| `assets/world2d/final/items/SilverRounds.png` | Item-Icon. |
| `assets/world2d/final/items/ThornCrown.png` | Item-Icon. |
| `assets/world2d/final/items/IronVigil.png` | Item-Icon. |
| `assets/world2d/final/items/StillVeil.png` | Item-Icon. |
| `assets/world2d/final/items/StoneIdol.png` | Item-Icon. |
| `assets/world2d/final/items/GildedPlume.png` | Item-Icon. |
| `assets/world2d/final/items/OathRing.png` | Item-Icon. |
| `assets/world2d/final/items/PulseDraught.png` | Item-Icon. |
| `assets/world2d/final/items/HuntersTally.png` | Item-Icon. |
| `assets/world2d/final/items/GalvanicCoil.png` | Item-Icon. |
| `assets/world2d/final/items/MourningVeil.png` | Item-Icon. |
| `assets/world2d/final/items/MossWard.png` | Item-Icon. |
| `assets/world2d/final/items/PlagueRat.png` | Item-Icon. |
| `assets/world2d/final/items/HushCandle.png` | Item-Icon. |
| `assets/world2d/final/items/Changeling.png` | Item-Icon. |
| `assets/world2d/final/items/SweetReliquary.png` | Item-Icon. |
| `assets/world2d/final/items/TitanArms.png` | Item-Icon. |
| `assets/world2d/final/items/ShadowCloak.png` | Item-Icon. |
| `assets/world2d/final/items/HeavyRounds.png` | Item-Icon. |
| `assets/world2d/final/items/ColossusHeart.png` | Item-Icon. |
| `assets/world2d/final/items/BrassHarness.png` | Item-Icon. |
| `assets/world2d/final/items/WitchMortar.png` | Item-Icon. |
| `assets/world2d/final/items/LanternCodex.png` | Item-Icon. |
| `assets/world2d/final/items/EternalFlame.png` | Item-Icon. |
| `assets/world2d/final/items/ClockworkArm.png` | Item-Icon. |
| `assets/world2d/final/items/EvergreenSprig.png` | Item-Icon. |
| `assets/world2d/final/items/FortuneCoin.png` | Item-Icon. |
| `assets/world2d/final/items/EightEyedIdol.png` | Item-Icon. |
| `assets/world2d/final/items/LoneFlame.png` | Item-Icon. |
| `assets/world2d/final/items/FieldCenser.png` | Item-Icon. |
| `assets/world2d/final/items/EmberAnvil.png` | Item-Icon. |
| `assets/world2d/final/items/SmolderingWick.png` | Item-Icon. |
| `assets/world2d/final/items/AshSerpent.png` | Item-Icon. |
| `assets/world2d/final/items/Bellows.png` | Item-Icon. |
| `assets/world2d/final/items/BlackPowder.png` | Item-Icon. |
| `assets/world2d/final/items/FulminateJar.png` | Item-Icon. |
| `assets/world2d/final/items/BurstingSigil.png` | Item-Icon. |
| `assets/world2d/final/items/NeedleCharm.png` | Item-Icon. |
| `assets/world2d/final/items/GourdLantern.png` | Item-Icon. |
| `assets/world2d/final/items/MirrorShard.png` | Item-Icon. |
| `assets/world2d/final/items/IronGauntlet.png` | Item-Icon. |
| `assets/world2d/final/items/RecoilSpring.png` | Item-Icon. |
| `assets/world2d/final/items/GrubTincture.png` | Item-Icon. |
| `assets/world2d/final/items/BeckoningBell.png` | Item-Icon. |
| `assets/world2d/final/items/TaintedElixir.png` | Item-Icon. |
| `assets/world2d/final/items/HookedTongue.png` | Item-Icon. |
| `assets/world2d/final/items/CrackedSkull.png` | Item-Icon. |
| `assets/world2d/final/items/WispJar.png` | Item-Icon. |
| `assets/world2d/final/items/OrderSash.png` | Item-Icon. |
| `assets/world2d/final/items/RollingEye.png` | Item-Icon. |
| `assets/world2d/final/items/InkPolyp.png` | Item-Icon. |
| `assets/world2d/final/items/Knucklebones.png` | Item-Icon. |
| `assets/world2d/final/items/WitchKettle.png` | Item-Icon. |
| `assets/world2d/final/items/SaltCoral.png` | Item-Icon. |
| `assets/world2d/final/items/AstralPhilter.png` | Item-Icon. |
| `assets/world2d/final/items/RabbleBanner.png` | Item-Icon. |
| `assets/world2d/final/items/HearthSprite.png` | Item-Icon. |
| `assets/world2d/final/items/CrimsonHand.png` | Item-Icon. |
| `assets/world2d/final/items/BloodChalice.png` | Item-Icon. |
| `assets/world2d/final/items/VelvetDivan.png` | Item-Icon. |
| `assets/world2d/final/items/ThunderShells.png` | Item-Icon. |
| `assets/world2d/final/items/TitanGirdle.png` | Item-Icon. |
| `assets/world2d/final/items/SecondStomach.png` | Item-Icon. |
| `assets/world2d/final/items/PyreAshes.png` | Item-Icon. |
| `assets/world2d/final/items/CalibratedTools.png` | Item-Icon. |

### Werte-Icons (fehlt ein Bild, bleibt das heutige)

| Datei | Was |
| --- | --- |
| `assets/world2d/final/stats/maxHp.png` | Icon für den Wert. |
| `assets/world2d/final/stats/hpRegen.png` | Icon für den Wert. |
| `assets/world2d/final/stats/lifeSteal.png` | Icon für den Wert. |
| `assets/world2d/final/stats/damage.png` | Icon für den Wert. |
| `assets/world2d/final/stats/meleeDamage.png` | Icon für den Wert. |
| `assets/world2d/final/stats/rangedDamage.png` | Icon für den Wert. |
| `assets/world2d/final/stats/elementalDamage.png` | Icon für den Wert. |
| `assets/world2d/final/stats/attackSpeed.png` | Icon für den Wert. |
| `assets/world2d/final/stats/critChance.png` | Icon für den Wert. |
| `assets/world2d/final/stats/range.png` | Icon für den Wert. |
| `assets/world2d/final/stats/armor.png` | Icon für den Wert. |
| `assets/world2d/final/stats/dodge.png` | Icon für den Wert. |
| `assets/world2d/final/stats/speed.png` | Icon für den Wert. |
| `assets/world2d/final/stats/luck.png` | Icon für den Wert. |
| `assets/world2d/final/stats/harvesting.png` | Icon für den Wert. |
| `assets/world2d/final/stats/xpGain.png` | Icon für den Wert. |
| `assets/world2d/final/stats/pickupRange.png` | Icon für den Wert. |
| `assets/world2d/final/stats/itemPrice.png` | Icon für den Wert. |
| `assets/world2d/final/stats/freeRerolls.png` | Icon für den Wert. |
| `assets/world2d/final/stats/sellValue.png` | Icon für den Wert. |
| `assets/world2d/final/stats/doubleShards.png` | Icon für den Wert. |
| `assets/world2d/final/stats/shardHealing.png` | Icon für den Wert. |
| `assets/world2d/final/stats/eliteDamage.png` | Icon für den Wert. |
| `assets/world2d/final/stats/enemyCount.png` | Icon für den Wert. |
| `assets/world2d/final/stats/enemyHp.png` | Icon für den Wert. |
| `assets/world2d/final/stats/enemyDamage.png` | Icon für den Wert. |
| `assets/world2d/final/stats/knockback.png` | Icon für den Wert. |
| `assets/world2d/final/stats/explosionDamage.png` | Icon für den Wert. |
| `assets/world2d/final/stats/explosionSize.png` | Icon für den Wert. |
| `assets/world2d/final/stats/piercing.png` | Icon für den Wert. |
| `assets/world2d/final/stats/piercingDamage.png` | Icon für den Wert. |
| `assets/world2d/final/stats/bounce.png` | Icon für den Wert. |
| `assets/world2d/final/stats/burnSpeed.png` | Icon für den Wert. |
| `assets/world2d/final/stats/burnSpread.png` | Icon für den Wert. |
| `assets/world2d/final/stats/fruitHeal.png` | Icon für den Wert. |
| `assets/world2d/final/stats/trees.png` | Icon für den Wert. |
| `assets/world2d/final/stats/engineering.png` | Icon für den Wert. |
| `assets/world2d/final/stats/enemySpeed.png` | Icon für den Wert. |
