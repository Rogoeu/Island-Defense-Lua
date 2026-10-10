# Lua Import Order

Diese Reihenfolge ist fuer den aktuellen Migrationsstand gedacht:

1. `TotalInit/DebugUtils.lua`
2. `TotalInit/IngameConsole.lua`
3. `TotalInit/TotalInitialization.lua`
4. `Variables/ObjectIds.lua`
5. `Libraries/StringLib.lua`
6. `Libraries/PlayerColorUtils.lua`
7. `Races/RaceRegistry.lua`
8. `Player/PlayerData.lua`
9. `Player/PlayerNameDisplay.lua`
10. `Libraries/UnitFilter.lua`
11. `Races/RaceData.lua`
12. `core/GameSettings.lua`
13. `core/DefaultGameSettings.lua`
14. `Island Defense System/Game.lua`
15. `Player/PlayerProfile.lua`
15a. `Player/Cosmetics.lua`
16. `Modes/IslandDefenseGameMode.lua`
17. `Systems/GameTimer.lua`
17a. `Systems/LocalModelScaling.lua` (benoetigt PlayerProfile und GameTimer; vor PlayerProfileUI laden).
18. `Systems/UnitSpawner.lua`
    - Zuvor `Systems/MapAreas.lua` importieren (gemeinsame Bereichsauswahl und Spawnkoordinaten).
19. `User Interface/IslandDefenseMultiboard.lua`
    - Zuvor `User Interface/VictoryLinks.lua` als Lua-Modul importieren.
    - `User Interface/VictoryLinks.toc` und `VictoryLinks.fdf` als Dateien unter `war3mapImported\VictoryLinks.toc` bzw. `war3mapImported\VictoryLinks.fdf` importieren.
    - Discord- und Donation-URL stehen oben in `VictoryLinks.lua`.
    - `VictoryLinks.toc` mit CRLF und abschliessender Leerzeile speichern; ein einzelnes LF am Dateiende kann den WC3-TOC-Loader scheitern lassen.
20. `User Interface/PickModeSelectionUI.lua`
21. `Commands/CommandRegistry.lua`
21a. `Commands/CosmeticCommand.lua`
21b. `Systems/SpeechSystem.lua`
22. `Systems/TeamAlliances.lua`
23. `Commands/CameraCommand.lua`
24. `Commands/ObserverCommand.lua`
25. `Commands/TitanKickCommand.lua`
26. `Commands/GiveCommand.lua`
27. `Commands/VoteKickCommand.lua`
28. `Commands/BootCommand.lua`
29. `Commands/GameTweakCommands.lua`
30. `Systems/DebugCheatPack.lua`
31. `Systems/BaseHandicap.lua`
32. `Systems/PunishmentCentre.lua`
33. `Systems/MinionSpawner.lua`
34. `Systems/MinionLumberTribute.lua`
35. `Systems/PenaltyTimer.lua`
35a. `Systems/MercyLumber.lua`
36. `Systems/DefenderGhostBuildings.lua`
37. `Systems/DefenderDeath.lua`
38. `Systems/DefenderLeave.lua`
39. `Systems/WinCondition.lua`
40. `Systems/ExperienceSystem.lua`
41. `Systems/ItemDrops.lua`
42. `Systems/ShowTagFromUnit.lua`
43. `Systems/DummyCaster.lua`
44. `Systems/MissileSystem.lua`
45. `Systems/UnitStateSystem.lua`
46. `Systems/AbilityMeta.lua`
47. `Systems/TitanDamageSystem.lua`
48. `Systems/TitanAbilityUtils.lua`
49. `Systems/HunterSystem.lua`
50. `Systems/TitanHunterResist.lua`
51. `Systems/TitanDeath.lua`
52. `Systems/CritterSystem.lua`
52a. `EasterEggs/Jen.lua`
53. `Systems/HeroLevelBonuses.lua`
54. `Systems/TitanHunterExperience.lua`
55. `Abilities/AbilityRegistry.lua`
56. `Races/RacePickSystem.lua`
57. `Abilities/Global/GlobalBuilderAbilities.lua`
58. `Abilities/Global/DisableAttack.lua`
59. `Abilities/Global/GlobalTitanAbilities.lua`
60. `Abilities/Global/TowerRange.lua`
61. `Abilities/Global/GoldToLumber.lua`
62. `Abilities/Global/AzsharaAbilities.lua`
63. `Abilities/Global/FakeTeleport.lua`
64. `items/ItemExtras.lua`
65. `items/ItemPickupRestrictions.lua`
66. `items/StackedItems.lua`
67. `items/ShopSystemAutoBuy.lua`
68. `items/BuilderShop.lua`
69. `items/Builder/*.lua`
    - Inklusive `items/Builder/TurtleInventory.lua` (Verkaufssperre fuer Turtle-Inventar `A014`).
70. `items/TitanItemAbilities.lua`
71. `items/TomeOfRetraining.lua`
72. `items/Titan/*.lua`
73. `Abilities/Builders/*BuilderAbilities.lua`
74. `Abilities/Builders/*StructureAbilities.lua`
75. `Abilities/Titans/*Abilities.lua`
76. `Modes/RacePickModeAllPick.lua`
77. `Modes/RacePickModeUniquePick.lua`
78. `Modes/RacePickModeAllRandom.lua`
79. `Commands/ClearMessagesCommand.lua`
80. `Commands/PlayerProfileCommand.lua`
81. `Playground/LuaSmokeTests.lua`
82. `Playground/TimerTest.lua`
83. `Playground/IslandDefenseCoreTest.lua`
84. `User Interface/PlayerProfileUI.lua`
85. `Island Defense System/AutoStart.lua`

## Ingame-Test

Chatbefehl:

```text
-luatest
```

Weitere kontrollierte Testbefehle:

```text
-idsetup
-idstatus
-idreset
-idstarttest
-timertest
-idspawn me
-idspawn core
-defdie
-ghostbuildings on
-ghostbuildings off
-ghostduration 10
-spawnminion
-cheats
-cheats help
-gold 10000
-lumber 10000
-str 100
-agi 100
-int 100
-unit hfoo
-item I000
-mh
-shareall
-wincheck
-endgame on
-endgame off
-feedstats
-feedreduction on
-feedreduction off
-c 150
-cam l 200
-cam s
-cam reset
-b mur gno mor tau
-banrandom mur
-gnollaxe
-gobworker
-obs
-observer
-spec
-spectate
-kick
-kick 7
-vk 3
-votekick playername
-boot observername
-exp
-fr
-froff
-gc
-tweaks
```

Automatischer Lua-Teststart:

- `Island Defense System/AutoStart.lua` startet nach Mapstart automatisch eine Titan-Auswahl.
- Zum Deaktivieren vor dem Autostart setzen:

```lua
GameSettings.setBool("LUA_AUTOSTART_DISABLED", true)
```

Erwartung:

- Mehrere gruene `... ok` Meldungen.
- Am Ende `Lua smoke tests passed.`

## Hinweise

- Object-IDs/Rawcodes bleiben identisch zur `.wct` und zur Map.
- Die `.wct` und `.w3x` werden von diesen Lua-Dateien nicht veraendert.
- `Playground/LuaSmokeTests.lua` ist nur fuer die Migration gedacht und kann spaeter aus Release-Builds entfernt werden.

## Announcement-/AI-Briefing: bisheriger Lua-Migrationsstand

Dieser Abschnitt ist als kompakte Vorlage fuer Announcements, Changelogs oder AI-gestuetzte Zusammenfassungen gedacht.

### Kurzfassung

Island Defense wurde in grossen Teilen von alter Zinc-/Trigger-Logik auf modulare Lua-Systeme umgestellt. Der Fokus lag bisher darauf, die alte Funktionalitaet spielbar zu erhalten, aber die Systeme so aufzuteilen, dass sie spaeter leichter verbessert, getestet und erweitert werden koennen.

### Wichtigste erreichte Punkte

- Die Lua-Initialisierung ist geordnet und dokumentiert. `DefaultGameSettings.lua` verwaltet zentrale Spielwerte, UI-Toggles, Debugwerte, Startressourcen, Pick-Zeiten, Minion-Grace, Ghost Buildings, Experience-Faktoren und Gold-Coin-Settings.
- Die Host-Setup-UI wurde erweitert. Der Host kann Pick Mode, Minion Grace und Extra Modes wie Random Bonus, Base Handicap, Ghost Buildings, EXP, FROFF, GC, Debug und Super Critter einstellen.
- Das Multiboard wurde an die neuen Systeme angebunden. Es zeigt Game-Phase, Zeit, Tweaks und optional den Super-Critter-Fortschritt an.
- Defender Ghost Buildings wurden aus `DefenderDeath.lua` in `Systems/DefenderGhostBuildings.lua` ausgelagert und ueber GameSettings sowie UI/Commands steuerbar gemacht.
- Minion-Spawning wurde in `Systems/MinionSpawner.lua` zentralisiert. Dadurch kann Defender-Death sauberer bleiben und Minions koennen kontrollierter am Mound, per Courier oder durch Spezialfaelle gespawnt werden.
- Titan Hunter Experience wurde neu aufgebaut. Critter, Super Critter, Glyphs, Titan-Kills, normale Kills und Schaden an Titanen geben wieder passende Hunter-Experience. Super Critter ist per Start-UI abschaltbar.
- Der Super-Critter-Fortschritt ist konfigurierbar. `TITAN_HUNTER_SUPER_CRITTER_KILLS` bestimmt, wie viele Critter-Kills bis zum Spawn noetig sind.
- Das EXP-Glyph/EXP-Stone wird jetzt ueber `UnitSpawner` gespawnt und nach Game-Start an den Titan-Shop-Owner uebergeben.
- Nach der Defender-Auswahl startet die Titan-Auswahl direkt; es gibt keine separate Titan-Spawn-Grace-Time mehr.
- Hero-Level-Boni wurden in `Systems/HeroLevelBonuses.lua` ausgelagert. Titanen, Titan Hunter und spezielle Builder erhalten ihre Level-Up-Damage-/Armor-Boni wieder ueber ein eigenes System.
- Tower Range wurde als globale Ability-Library nach `Abilities/Global/TowerRange.lua` verschoben und kann Tower-Reichweiten anzeigen.
- Der Builder Shop wurde wieder eingebaut und modernisiert. Er unterstuetzt Builder/Titan-Varianten, Auto-Complete, manuelle Gold-/Lumber-Kosten, Recipe-Verarbeitung, Shopping-List-Logik und neutrale World-Editor-Shop-Units.
- Ultimate-Tower-Transmute wurde als Builder-Item-System ausgelagert. Ultitower-Rerolls brauchen einen echten mitgebrachten Ultimate Tower; fehlende Recipe-Komponenten wie Titan Egg koennen ueber Auto-Complete gekauft werden.
- Viele Titan-Item-Faehigkeiten wurden aus dem grossen `TitanItemAbilities.lua` in einzelne Dateien unter `items/Titan/` portiert. Beispiele: Crisis Regen, Cooldown Reduction, Far Sight, Ethereal Mirror, Fiery Touch, Mace of Mortality, Molten Blade Explosion, Protection, Magic Armor, Runic Mark, Shadow Walk, Spear of Fervor, Tidal Scepter, Tidal Guardian's Grace, Titan Trident und Siegecaster's Trophy.
- `TitanItemAbilities.lua` ist dadurch deutlich kleiner geworden und dient zunehmend nur noch als Rest-/Kompatibilitaetscontainer fuer noch nicht ausgelagerte Effekte.

### Spieler-sichtbare Highlights

- Host kann mehr Game Modes direkt am Anfang einstellen.
- Random Bonus ist standardmaessig aktiv.
- Ghost Buildings koennen an/aus geschaltet werden.
- Super Critter kann an/aus geschaltet werden; wenn aus, verschwindet auch der Multiboard-Zaehler.
- Builder Shop funktioniert wieder mit Auto-Complete und Kostenlogik.
- Ultimate Towers koennen wieder transmuted/rerolled werden.
- Titan Hunter Progression, EXP-Glyphs und Super-Critter-Objective sind wieder im Spiel.
- Titan sieht waehrend der Spawn-Grace weiterhin die Titan-Pick-Shops.
- Tower Range kann wieder angezeigt werden.

### Technische Leitlinie fuer weitere Announcements

- Nicht als kompletter Rewrite verkaufen. Besser: "Lua migration in progress", "systems split into smaller libraries", "old behavior restored first, improvements next".
- Betonung auf Stabilitaet: Rawcodes/Object-Editor-Daten bleiben gleich, damit die Map weiter mit bestehenden Object-IDs funktioniert.
- Betonung auf Wartbarkeit: grosse alte Systeme wurden in kleine Lua-Libraries aufgeteilt.
- Betonung auf Spielbarkeit: Builder Shop, Titan Items, Hunter EXP, Minion Spawn, Ghost Buildings und Pick-UI sind wieder verbunden.

### Moeglicher Announcement-Text

```text
Lua migration progress update:

A lot of old Zinc/trigger logic has now been moved into smaller Lua systems. The goal is still to preserve the original Island Defense behavior first, while making the codebase easier to maintain and improve later.

Recent work restored and modernized several major systems: the Builder Shop with auto-complete and gold/lumber costs, Ultimate Tower transmute/reroll logic, Titan Hunter experience including EXP glyphs and Super Critter progress, Ghost Buildings, Minion spawning, Hero level bonuses, Tower Range display, and many Titan item abilities that are now split into their own Lua files.

The host setup UI also has more control now: Random Bonus, Base Handicap, Ghost Buildings, EXP/FROFF/GC, Debug, Minion Grace and Super Critter can be configured at game start. If Super Critter is disabled, its multiboard progress display is hidden as well.

This is still migration-first rather than redesign-first, but the map is moving away from the old monolithic code and toward cleaner Lua libraries that can be improved over time.
```
