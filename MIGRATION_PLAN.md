# Island Defense Lua Migration Plan

Stand: 2026-06-11

## Aktueller Workspace

- Originalquelle: `IslandDefense_4.4.4unprot06.wct` mit ca. 3.16 MB altem JASS/Zinc-Code.
- Vorhandene Lua-Basis:
  - `TotalInit/DebugUtils.lua`
  - `TotalInit/IngameConsole.lua`
  - `TotalInit/TotalInitialization.lua`
- `TotalInitialization.lua` stellt `OnInit`, `Require`, `OnGlobalInit`, `OnTrigInit`, `OnMapInit` und `OnGameStart` bereit.
- `DebugUtils.lua` stellt `Debug`, `Debug.try`, `Debug.beginFile`, `Debug.endFile` und Ingame-Fehlerausgaben bereit.
- `IngameConsole.lua` stellt `IngameConsole.startFor(player)` und `IngameConsole.exitFor(player)` sowie `-console`/`-exec` bereit.

## Vorgeschlagene Lua-Struktur

- Die spaetere Struktur soll sich an den World-Editor-Kategorien der Originalmap orientieren:
  - `Variables/`
  - `Top Libraries/`
  - `Island Defense System/`
  - `XE/`
  - `Items/`
  - `Upgrades/`
  - `Modes/`
  - `Meta Data Systems/`
  - `Races/`
  - `Multiboard/`
  - `Commands/`
  - `Systems/`
  - `Libraries/`
  - `User Interface/`
  - `Snippets/`
  - `Abilities/`
  - `Quests/`
  - `Item Abilities/`
  - `Custom Models/`
  - `AurasPerks/`
  - `Turtle models/`
  - `Playground/`
- Bisheriger technischer Startpunkt:
  - `core/` enthaelt fruehe Lua-Kompatibilitaetsmodule. Diese koennen spaeter in die passenden WE-Kategorien einsortiert werden.
  - Neue Ports sollen ab jetzt bevorzugt in den WE-nahen Ordnern entstehen, wenn die Zuordnung eindeutig ist.
- Object-IDs/Rawcodes bleiben identisch zur `.wct` und zur bestehenden Map. Lua-Module duerfen Rawcodes zentral referenzieren, aber nicht stillschweigend umbenennen oder neu vergeben.

## Erkannte Systeme aus der `.wct`

Die `.wct` enthaelt 553 erkannte `library`-Deklarationen, 56 `struct`-Deklarationen, eine `scope`-Deklaration und viele importierte/inline Zinc-Systeme.

### Core / Init

- `IslandDefenseSystem`
- `IslandDefenseGameMode`
- `IslandDefenseTagGameMode`
- `DefaultDefenderDeath`
- `TagDefenderDeath`
- `HCLSystem`
- `MetaData`
- `ElapsedGameTime`
- `GameTimer`
- `TimerUtils`
- `Event`, `EventReg`
- `Alloc`
- `AIDS`, `PUI`, `AutoIndex`

### PlayerData

- `Players`
- `PlayerDataPick`
- `PlayerDataPickRandoming`
- `PlayerDataMultiboard`
- `PlayCountManager`
- `LeaveEvent`
- `LeaveHook`
- `GetPlayerColored`
- `GetPlayerActualName`, `GetPAN`

### GameSettings

- `GameSettings`
- `TweakManager`
- `SettingsTweak`
- Viele konkrete Tweaks: `CameraTweak`, `VoteTweak`, `TitanTweak`, `ClassTweak`, `BanTweak`, `TimerTweak`, `InventoryTweak`, `QuestTweak`, `SwapTweak`, `DefenderTweak`, `LightningOffCommand`, `UpgradesCommand`, `PlayCountCommand`, `SmartHealCommand`, `GoldStolenCommand`, `MovespeedCommand`, `FogCommand`, `OrdersDebugCommand`.

### Race-System

- `Races`, `RacesExtra`, `CustomTitanRace`
- Pick-System: `RacePicker`, `RacePickMode`, `RacePickModeAllRandom`, `RacePickModeDraftPick`, `RacePickModeBuilderRandom`, `RacePickModeAllPick`, `RacePickModeUniquePick`, `RacePickModeInHousePick`, `RacePickModeInHouse`
- Defender-Races: `ArachnidRace`, `DemonologistRace`, `DraeneiRace`, `DryadRace`, `FaerieRace`, `GnollRace`, `GoblinRace`, `HuntressRace`, `MagnataurRace`, `MakruraRace`, `MorphlingRace`, `MurlocRace`, `NatureRace`, `OgreRace`, `PandaRace`, `PirateRace`, `RadioactiveRace`, `SatyrRace`, `TaurenRace`, `TrollRace`, `ZerglingRace`
- Titan-Races: `ArboriusRace`, `BreezeriousRace`, `BubonicusRace`, `DemonicusRace`, `FossuriousRace`, `GlaciousRace`, `LucidiousRace`, `MolteniousRace`, `SypheriousRace`, `TerminusRace`, `VoltronRace`

### Titans

- `TitanFinder`
- `TitanUnit`
- `TitanHunterExperience`
- `TitanHunterResist`
- `GiveGoldForKillingTitanHunters`
- `TitanHunterMurloc`, `TitanHunterDryad`, `TitanHunterNature`, `TitanHunterRadioactive`, `TitanHunterTroll`
- `GenericTitanTargets`
- `TitanCourier`
- `ApplyTitanUpgrades`
- Titan ability groups for Arborius, Breezerious, Bubonicus, Demonicus/Demo, Fossurious, Glacious, Lucidious, Moltenious, Noxious, Sypherious, Terminus, Voltron

### Defenders

- `DefenderUnit`
- `HunterUnit`
- `DefaultDefenderDeath`
- `TagDefenderDeath`
- Race-specific defender systems and abilities, e.g. `NestBuilder`, `VoidGate`, `PandaTransformations`, `TrollVoodoo`, `SatyrElixir`, `NatureReplant`, `TowerRange`

### Minions

- `MinionUnit`
- `MinionLumber`
- Titan-specific minion nuke/heal systems such as `ArboriusMinionNuke`, `BreezeriousHealMinion`, `BubonicusNukeMinion`, `GlaciousMinionHeal`, `TerminusMinionNuke`, `VoltronMinionHeal`

### Commands

- `CommandParser`
- `Commandfuncs`
- Tweak/utility commands: `LightningOffCommand`, `UpgradesCommand`, `PlayCountCommand`, `SmartHealCommand`, `GoldStolenCommand`, `MovespeedCommand`, `FogCommand`, `OrdersDebugCommand`
- Old cheat/test functions visible in global function list: `Cheatz`, `Cheatz0r`, `DirectCheat`, `CheatActivate`, `CheatUseLeft`, `CheatUseRight`, `CheatUseUp`, `CheatUseDown`, `SecretCheatAction`

### UI / Frame-Systeme

- `MultiboardUpdater`
- `MultiboardManager`
- `PlayerDataMultiboard`
- `MultiboardDefender`
- `MultiboardTitan`
- `VoteModule`
- `VoteBoardGeneric`
- `Dialog`
- `Board`
- `AddBars`, `ProgressBar`, `Multibar`
- `Wiki`, `WikiUI`
- `ItemGuide`

### Debug / Cheat / Tester Tools

- `Monitor`
- `CustomTestTweak`
- `OrdersDebugCommand`
- `PreventSave`
- `CheatPack` dependency in `IslandDefenseSystem`
- Existing Lua tools: `DebugUtils` and `IngameConsole`

### Save / Load / FileIO

- `FileIO` is referenced by `PlayCountManager`, `CameraPersistence`, `BanPersistence`, `ClanPersistence`.
- `PreventSave`
- `ClanRegistry`, `ClanPersistence`, `ClanSystem`
- `PlayCountManager`
- `CameraPersistence`
- `BanPersistence`

### Timers

- `GameTimer`
- `TimerUtils`
- `ElapsedGameTime`
- Many gameplay systems depend on `GameTimer`, so this should be ported before active gameplay modules.

### Combat / Units / Abilities

- Unit wrappers: `Unit`, `DefenderUnit`, `HunterUnit`, `TitanUnit`, `MinionUnit`, `UnitManager`, `UnitSpawner`
- Unit classification: `IsUnitWard`, `IsUnitWall`, `IsUnitTower`, `IsUnitUltimateTower`, `IsUnitWorker`, `IsUnitTitanHunter`, `IsUnitBuilder`, `IsUnitTitanous`, `IsUnitWindWalk`, `IsUnitCritter`, `UnitAlive`
- Combat engines/utilities: `Damage`, `DamageEngine`, `GT`, `BUM`, `ABMA`, `BonusMod`, `UnitMaxState`, `xedamage`, `xecollider`, `xecast`, `xefx`, `xemissile`
- Item systems: `ItemExtras`, `ShopSystem`, `ShopSystemAutoBuy`, `RecommendedItems`, `ItemDrops`, `ItemRecipes`, `ItemCast`, `RebuildItemSystem`
- Upgrade/build systems: `UpgradeSystem`, `StructureAbilities`, `StructureUpgrades`, `BuilderUpgrades`, `RemoveRallyUpgrades`, `BasingSystem`, `BasingSystemTweak`

### Win / Loss / Game Flow

- `IslandDefenseSystem`
- `IslandDefenseGameMode`
- `IslandDefenseTagGameMode`
- `IslandDefenseEndScreen`
- `RevealMapForPlayer`
- `PenaltyTimer`
- `PeriodicTips`
- `MercyLumber`
- `EnvironmentManager`
- `TitanFinder`

## Empfohlene Migrationsreihenfolge

1. Lua-Grundgeruest festlegen: Ordnerstruktur, Debug-/Init-Konvention, Modulnamen, Kompatibilitaetsregeln.
2. Isolierte Utilities portieren: `GameSettings`, String-Helfer, kleine Player-Farbhelfer, einfache Table/Array-Wrapper.
3. Timer-Schicht portieren: `GameTimer` als Lua-Wrapper ueber WC3-Timer, mit Kompatibilitaets-API fuer alte Systeme.
4. Command-Schicht portieren: kleiner `CommandParser`/Command-Registry-Adapter, danach Debug-Testkommandos.
5. Player-Schicht portieren: `Players`, `PlayerData`, Klassen, Leave-Hooks, PlayCount/Persistenzadapter als Stub oder echter FileIO-Port.
6. Race-Registry portieren: `Races`, Race-Daten als reine Datenmodule, danach Pick-Modes.
7. Unit-Schicht portieren: `UnitManager`, `UnitSpawner`, `Unit`, `DefenderUnit`, `TitanUnit`, `MinionUnit`, Unit-Klassifizierer.
8. Game-Flow portieren: `IslandDefenseSystem`, GameMode-Registrierung, Setup/Start/Pause/Finish, Win/Loss.
9. UI portieren: Multiboards, Voteboards, Dialoge, Wiki/ItemGuide.
10. Items, Shops, Upgrades und Combat-Utilities portieren.
11. Defender-/Titan-/Minion-Faehigkeiten schrittweise pro Race/Ability portieren.
12. Alte JASS/Zinc-Teile erst deaktivieren, wenn das jeweilige Lua-Aequivalent im Spiel getestet wurde.

## Risiken und Abhaengigkeiten

- `IslandDefenseSystem` ist zentral und haengt an `HCL`, `Players`, `GameTimer`, `CheatPack`, Persistenz und Clan-Systemen. Es sollte nicht als erster grosser Block migriert werden.
- `Players` haengt bereits an `Races` und `PlayCountManager`; eine direkte Portierung ohne Stubs erzeugt viele Folgeabhaengigkeiten.
- `RacePicker` haengt an `IslandDefenseSystem`, `PlayerDataPick`, `UnitManager`, `CommandParser`, Voteboards und Race-Daten.
- `GameTimer` ist breit genutzt. Ein falscher Port kann sehr viele Systeme beeinflussen, ist aber frueh noetig.
- Viele Ability-Systeme nutzen alte vJass/Zinc-Utilities wie `GT`, `AIDS`, `TimerUtils`, `BonusMod`, `xedamage`, `xecast`, `xefx`. Diese sollten zuerst als Adapter oder Lua-native Ersatzschicht existieren.
- Save/Load/FileIO, Clan- und Ban-Persistenz sind versions- und environment-sensibel. Erst portieren, wenn Debug-/Command-Tests stabil sind.
- Doppelte Library-Namen existieren, z. B. `MMD`, `FieryTouch`, `TidalScepter`, `StructureUpgrades`, `Board`, `Table`. Beim Portieren muss entschieden werden, ob das echte Duplikate, Varianten oder WCT-Artefakte sind.
- Die `.wct` enthaelt Binary-/Kontrollzeichen im Header und sollte nur gelesen, nicht direkt normalisiert oder ueberschrieben werden.

## Systeme, die zuerst in Lua portiert werden sollten

1. `GameSettings` - isoliert, einfache API, gute Basis fuer Tweaks und Config.
2. Kleine Utility-Module: String-Funktionen, Player-Farben, Debug-Log-Adapter.
3. `GameTimer` - zentraler Timer-Wrapper, aber erst nach kleinem Testmodul.
4. Minimaler `CommandParser`/Command-Registry-Adapter fuer Debug- und Smoke-Tests.
5. `Players`/`PlayerData` mit bewusst kleinen, testbaren APIs.

## Erster Portierungsschritt

Erstellt: `core/GameSettings.lua`

Ziel:
- Lua-kompatibles `GameSettings` bereitstellen.
- Alte API-Namen wie `GameSettings.getBool`, `GameSettings.setBool`, `GameSettings.getStr`, `GameSettings.setStr`, `GameSettings.getReal`, `GameSettings.setReal`, `GameSettings.getInt`, `GameSettings.setInt` erhalten.
- Tabellenzugriff `GameSettings["KEY"]` und Zuweisung `GameSettings["KEY"] = "value"` als Kompatibilitaetswrapper unterstuetzen.
- Noch kein Gameplay-Verhalten aktiv veraendern.

Test im Spiel:
- `core/GameSettings.lua` nach `TotalInit` als Script einbinden.
- Mit IngameConsole testen:
  - `GameSettings.setBool("ANTIHACK", true)`
  - `GameSettings.getBool("ANTIHACK")`
  - `GameSettings["TEST"] = "42"`
  - `GameSettings.getInt("TEST")`

## Zweiter Portierungsschritt

Erstellt:
- `Variables/ObjectIds.lua`
- `Libraries/StringLib.lua`

Ziel:
- Einen festen Ort fuer unveraenderte Object-IDs/Rawcodes schaffen.
- `StringLib` als isoliertes Utility-System nach Lua portieren.
- Alte globale API-Namen erhalten: `StringTrimLeft`, `StringTrimRight`, `StringTrim`, `StringIndexOf`, `StringIndexOfReverse`, `StringReplace`, `StringHashCS`, `IsStringAscii`, `StringAsciiAt`, `StringLengthUtf8`, `IsStringValidUtf8`, `StringSegments`.

Test im Spiel:
- `Variables/ObjectIds.lua` und `Libraries/StringLib.lua` nach `TotalInit` einbinden.
- Mit IngameConsole testen:
  - `StringTrim("  test  ")`
  - `StringIndexOf("Island Defense", "def", false)`
  - `StringReplace("a-b-a", "a", "x", true)`
  - `local s = StringSegments.create("red blue  teal", " "); s:countSegments(); s:nextSegment()`

## Dritter Portierungsschritt

Erstellt:
- `Commands/CommandRegistry.lua`
- `Playground/LuaSmokeTests.lua`

Ziel:
- Ein kleines fertiges Testsystem im Spiel bereitstellen.
- Neue Lua-Ports ohne grosse Gameplay-Aenderung per Chat pruefbar machen.
- Kompatiblen Zugriff `Command["-name"].register(function(args) ... end)` vorbereiten, weil die alte `.wct` diese Schreibweise bereits verwendet.

Test im Spiel:
- Script-Reihenfolge nach `TotalInit`:
  1. `Variables/ObjectIds.lua`
  2. `Libraries/StringLib.lua`
  3. `core/GameSettings.lua`
  4. `Commands/CommandRegistry.lua`
  5. `Playground/LuaSmokeTests.lua`
- Im Spiel eingeben:
  - `-luatest`
- Erwartung:
  - Mehrere gruene `... ok` Meldungen.
- Am Ende `Lua smoke tests passed.`

## Vierter Portierungsschritt

Erstellt:
- `Races/RaceRegistry.lua`
- `Races/RaceData.lua`
- `Player/PlayerData.lua`
- `Island Defense System/Game.lua`
- `Modes/IslandDefenseGameMode.lua`
- `Systems/UnitSpawner.lua`

Ziel:
- Kernsysteme fuer Island Defense in Lua vorbereiten, ohne Ability-Logik zu migrieren.
- Alle bekannten Defender- und Titan-Races aus der `.wct` mit identischen `widgetId`/`itemId` Rawcodes registrieren.
- `PlayerData` mit alten Klassenwerten bereitstellen:
  - `CLASS_NONE = 0`
  - `CLASS_MINION = 1`
  - `CLASS_TITAN = 2`
  - `CLASS_DEFENDER = 3`
  - `CLASS_OBSERVER = 4`
- `Game` als Lua-Version der zentralen State-/Mode-Registry vorbereiten.
- `IslandDefenseGameMode` als minimalen normalen Modus registrieren.
- `UnitSpawner` mit alten Shop-/Picker-/Spell-Well Rawcodes und sicheren Spawn-Funktionen vorbereiten.

Wichtig:
- Nichts davon startet automatisch eine Runde.
- Alte `.wct`-Systeme werden nicht deaktiviert.
- Abilities, Race-spezifische Spawn-Hooks und Death-Handling bleiben bewusst fuer spaetere Schritte offen.

Test im Spiel:
- Import-Reihenfolge aus `IMPORT_ORDER.md` verwenden.
- `-luatest` ausfuehren.
- Erwartung: Neben den bisherigen Checks werden Race-Anzahl, PlayerData, GameMode und ein Spawner-Rawcode geprueft.

## Fuenfter Portierungsschritt

Erstellt:
- `Playground/IslandDefenseCoreTest.lua`

Erweitert:
- `Systems/UnitSpawner.lua`

Ziel:
- Einen sichtbaren, aber kontrollierten Island-Defense-Core-Test bereitstellen.
- `-idsetup` laedt aktive Spieler, setzt den normalen `IslandDefenseGameMode`, verteilt Klassen und weist zufaellige Titan-/Defender-Races zu.
- `-idspawn me` spawnt die zugewiesene Race-Unit des ausloesenden Spielers an seiner Startposition.
- `-idspawn core` spawnt Spell Well und zentrale Shop-/Test-Units.

Wichtig:
- Diese Commands sind Migrations-/Playground-Werkzeuge.
- Sie starten nicht automatisch.
- Sie ersetzen noch nicht das finale Game-Flow-System.
- Ability-Hooks, Death-Handling, RacePicker und echte Spawn-Positionen werden spaeter portiert.

Test im Spiel:
- Erst `-luatest`.
- Dann `-idsetup`.
- Danach optional `-idspawn me` oder `-idspawn core`.

Erweitert:
- `-idstatus` zeigt Game-State, Mode und alle geladenen PlayerData-Eintraege.
- `-idreset` entfernt Lua-Test-Spawns und setzt Klassen/Races/State zurueck.
- `-idstarttest` fuehrt `-idsetup`, Core-Spawns und Player-Race-Spawns in einem Ablauf aus und setzt den Game-State auf gestartet.

## Sechster Portierungsschritt

Erstellt:
- `Systems/GameTimer.lua`
- `Playground/TimerTest.lua`

Erweitert:
- `Playground/IslandDefenseCoreTest.lua`

Ziel:
- Einen Lua-kompatiblen `GameTimer`-Wrapper ueber Warcraft-3-Timer bereitstellen.
- Kompatibilitaetsfunktionen vorbereiten: `StartGameTimer`, `PauseGameTimer`, `ResumeGameTimer`, `IsGameTimerPaused`, `IsGameTimerRunning`.
- Mit `-timertest` einen einfachen 3-Tick-Test im Spiel bereitstellen.
- `-idstarttest` auf zeitversetzte Schritte umstellen:
  - sofort Setup
  - nach 1 Sekunde Core-Spawns
  - nach 2 Sekunden Player-Race-Spawns
  - nach 3 Sekunden Game-Start

## Siebter Portierungsschritt

Erstellt:
- `Island Defense System/AutoStart.lua`

Ziel:
- Beim Spielstart automatisch einen Lua-Teststart ausloesen.
- Allen aktiven Spielern ein Dialogfenster anzeigen: Titan spielen ja/nein.
- Wenn mehrere Spieler Titan wollen, wird zufaellig einer aus den Freiwilligen gewaehlt.
- Wenn niemand Titan will, wird zufaellig ein aktiver Spieler Titan.
- Danach werden Klassen/Races gesetzt, Core-Units gespawnt, Player-Units gespawnt und der Game-State gestartet.

Wichtig:
- Das ist noch ein Lua-Autostart-Prototyp.
- Ability-Hooks, RacePicker/Voting, echte Spawnlogik und finales Balancing folgen spaeter.
- Deaktivierbar ueber `GameSettings.setBool("LUA_AUTOSTART_DISABLED", true)`.

## Achter Portierungsschritt

Erweitert:
- `Player/PlayerData.lua`
- `Island Defense System/AutoStart.lua`
- `Modes/IslandDefenseGameMode.lua`
- `Playground/IslandDefenseCoreTest.lua`

Ziel:
- Solo-Lobby automatisch mit Fake-PlayerData auffuellen.
- Wenn genau ein echter Spieler die Lobby startet, werden Fake-Player bis auf insgesamt 11 PlayerData-Eintraege ergaenzt.
- Bei zwei oder mehr echten Spielern werden keine Fake-Player hinzugefuegt.
- Fake-Player bekommen Klassen/Races und koennen fuer Spawn-/Flow-Tests genutzt werden.

Wichtig:
- Fake-Player sind Lua-PlayerData auf freien Warcraft-Spielerslots.
- Titan-Auswahl-Dialoge werden nur echten Spielern angezeigt.
- Fake-Player sind fuer Test-/Migrationszwecke gedacht, nicht als finales KI-System.

## Neunter Portierungsschritt

Erstellt:
- `User Interface/IslandDefenseMultiboard.lua`

Erweitert:
- `Island Defense System/AutoStart.lua`
- `Playground/IslandDefenseCoreTest.lua`
- `Races/RaceRegistry.lua`

Ziel:
- Erstes Lua-Multiboard anzeigen.
- Spalten: `Clan`, Race-Icon, `Name`, `Gold`, `Lumber`, `Fed`, `Goldfed`.
- `Fed` und `Goldfed` sind vorerst Platzhalterwerte `0`.
- Titel zeigt aktuelle Spielphase und einen herunterlaufenden Sekunden-Timer.
- Race-Icons werden aus `race:icon()` gelesen; fehlende Icons nutzen einen Klassen-Fallback.

Test:
- Map starten und AutoStart laufen lassen, oder `-idstarttest`.
- `-idstatus` zeigt/refreshes das Multiboard ebenfalls.

Erweitert:
- Multiboard gruppiert Spieler jetzt nach `Defenders`, `Titan`, `Minions`, `Observers` und `Unassigned`.
- Dadurch ist zwischen Defender-Gruppe und Titan-Gruppe sichtbar Platz/Struktur.

## Zehnter Portierungsschritt

Erstellt:
- `Races/RacePickSystem.lua`
- `Modes/RacePickModeAllPick.lua`
- `Modes/RacePickModePlaceholders.lua`

Erweitert:
- `Player/PlayerData.lua`
- `Systems/UnitSpawner.lua`
- `Island Defense System/AutoStart.lua`
- `Playground/IslandDefenseCoreTest.lua`

Ziel:
- Modulare Picking-Phase vorbereiten.
- `RacePickSystem` registriert Pick-Modes und verarbeitet Race-Item-Kaeufe aus Pick-Shops.
- `All Pick` ist als erster echter Mode implementiert.
- Ablauf:
  - Titan-Wunsch/AutoStart bestimmt den Titan-Spieler.
  - Pick-Shops und Picker-Units werden gespawnt.
  - Defender bekommen Gold und duerfen zuerst kaufen.
  - Nach Defender-Pickphase startet eine 55-Sekunden-Grace-Phase.
  - Danach bekommt der Titan Gold und darf picken.
  - Nach Titan-Pick werden Picker/Pickshops entfernt, Player-Units gespawnt und das Spiel gestartet.
- Vorbereitet als Platzhalter: `All Random`, `Draft Pick`, `Funny Pick`, `Unique Pick`.

Offen:
- Echte Mode-Details fuer AR/DP/FP/UP.
- Bessere fruehe Beendigung, wenn alle Spieler vor Ablauf gepickt haben.
- Buy-Validation/Refund-Feinschliff.

Erweitert:
- Wenn ein Picker Random-Race-Item `I006` kauft, weist `RacePickSystem` zufaellig eine zur Spielerklasse passende Race zu.
- `I006` wird nicht per Lua in den Shop gelegt, weil die Map/Object-Editor-Daten das Item bereits im Stock haben koennen.

Erweitert:
- Picker-Kamera wird bei aktivierter Pickphase auf Defender- bzw. Titan-Pickshops bewegt.
- Nach der Titan-Auswahl werden Titan und Builder als gegnerische Teams gesetzt.
- `UnitSpawner.setTitanShopOwner(player)` setzt Gold Mound/Spell Well, Titan-Shops und Punishment-Cage-Units auf den Titan-Besitzer und kann spaeter wiederverwendet werden.
- Nach dem Spawn wird die Kamera jedes Spielers auf seine Main Unit gesetzt.
- Race-Units spawnen in zufaellig versetzten Ringpositionen um den Gold Mound/Spell Well, damit Spieler nicht immer an derselben festen Slotposition erscheinen.

## Elfter Portierungsschritt

Erstellt:
- `Systems/DefenderDeath.lua`

Erweitert:
- `Systems/UnitSpawner.lua`
- `IMPORT_ORDER.md`

Ziel:
- Ersten Defender-Death-Flow in Lua bereitstellen.
- Wenn die Main Unit eines Defenders stirbt:
  - der Spieler wechselt von `Defender` zu `Minion`,
  - seine Alliances werden auf Titan/Minion-Team umgestellt,
  - seine Buildings werden optional fuer eine konfigurierbare Zeit zu Ghost Buildings,
  - danach bekommt er die zur aktuellen Titan-Race passende Minion-Unit aus `race:childId()` gespawnt,
  - Multiboard wird aktualisiert.
- Ghost Buildings sind ueber `GameSettings` und Chatbefehle leicht anpassbar:
  - `DEFENDER_GHOST_BUILDINGS_ENABLED`
  - `DEFENDER_GHOST_BUILDING_SECONDS`
  - `DEFENDER_GHOST_BUILDINGS_REMOVE`

Test:
- Import-Reihenfolge aus `IMPORT_ORDER.md` aktualisieren.
- Runde starten, als Defender Builder/Main Unit erhalten.
- Zum schnellen Test `-defdie` eingeben.
- Erwartung: Spieler wird im Multiboard Minion, Kamera springt zur Minion-Unit, Buildings werden geghostet und nach Standard `120s` entfernt.
- Optional testen:
  - `-ghostbuildings off`
  - `-ghostbuildings on`
  - `-ghostduration 10`

Offen:
- Pseudologos wurde fuer die Alpha entfernt und wird nicht mehr portiert.
- Minion-Faehigkeiten und titan-spezifische Minion-Logik folgen spaeter.

Erweitert:
- `Races/RaceData.lua` enthaelt jetzt die alten Race-Icons aus der `.wct` fuer Defender und Titanen.
- `Races/RaceRegistry.lua` unterstuetzt zusaetzlich `race:childIcon()` fuer Titan-Minion-Icons.

## Zwoelfter Portierungsschritt

Erstellt:
- `Systems/DebugCheatPack.lua`

Erweitert:
- `Island Defense System/AutoStart.lua`
- `IMPORT_ORDER.md`

Ziel:
- In Solo-Debug-Lobbys automatisch ein Lua-CheatPack aktivieren.
- Eine Debug-Lobby ist aktuell: genau ein echter Spieler und mindestens ein Fake-Player.
- Bei Aktivierung werden `GameSettings.DEBUG` und `GameSettings.FORCE_DEBUG_MODE` gesetzt.
- Der erste Lua-Port orientiert sich am alten `.wct`-CheatPack und bietet Kernbefehle fuer Ressourcen, Unit/Item-Spawns, Unit-Manipulation, Alliances und Map-Reveal.
- In Debug-Lobbys werden Autostart-/Pick-Zeiten automatisch verkuerzt:
  - `TITAN_SELECTION_TIME = 4`
  - `PICK_MODE_SELECTION_TIME = 4`
  - `DEFENDER_PICK_TIME = 6`
  - `TITAN_PICK_TIME = 5`

Test:
- Map alleine starten, Fake-Player muessen erzeugt werden.
- Erwartung: `CheatPack activated.`
- Danach testen:
  - `-cheats`
  - `-cheats help`
  - `-gold 10000`
  - `-lumber 10000`
  - `-unit hfoo`
  - `-heal`
  - `-kill`
  - `-mh`
  - `-shareall`

Offen:
- Alte Keybinds (`-bindup`, `-bindleft`, `-bindright`, `-binddown`) spaeter als eigenes kleines Modul portieren.
- Alte Rect-/Area-/Skin-/Model-Testbefehle spaeter gezielt nachziehen, falls sie fuer Map-Debugging gebraucht werden.

## Dreizehnter Portierungsschritt

Erstellt:
- `Modes/RacePickModeUniquePick.lua`

Erweitert:
- `Races/RacePickSystem.lua`
- `Modes/RacePickModePlaceholders.lua`
- `Island Defense System/AutoStart.lua`
- `IMPORT_ORDER.md`

Ziel:
- `Unique Pick` (`UP`) als echten Lua-Pick-Mode bereitstellen.
- `UP` ist aktuell der Default-Pickmode, wenn keine Stimme abgegeben wird oder der Pickmode ohne Parameter gestartet wird.
- Der Modus orientiert sich am alten `.wct`-Verhalten:
  - Defender waehlen zuerst mehrere gewuenschte Races oder Random.
  - Am Ende der Pickphase wird eine zufaellige Spielerreihenfolge erzeugt.
  - Jeder Defender bekommt dann den ersten noch freien Wunsch aus seiner Liste.
  - Spieler ohne verfuegbaren Wunsch und Random-Picks bekommen eine zufaellige noch freie Defender-Race.
  - Dadurch wird jede Defender-Race hoechstens einmal vergeben.
  - Danach laufen Builder-Spawn, Grace-Time, Titan-Pick und Titan-Spawn wie im normalen Ablauf weiter.

Test:
- Beim Pick-Mode-Vote `UP` waehlen.
- Zwei echte Spieler koennen dieselbe Builder-Race kaufen; nach Ablauf sollte nur einer diese Race bekommen, der andere eine andere freie Race.
- In Solo-Debug-Lobby werden Fake-Player als Random-Picks behandelt und eindeutig verteilt.

Erweitert:
- `User Interface/PickModeSelectionUI.lua` ersetzt das alte All-Player-Voting durch eine Host-Auswahl.
- Red/Host bekommt zu Rundenbeginn ein Auswahl-UI fuer `UP`, `AP`, `AR`, `DP`, `FP`.
- Alle anderen echten Spieler bekommen ein Warte-/Info-UI mit derselben Mode-Liste und sehen, dass der Host entscheidet.
- Timeout/Default bleibt `UP`.
- Die Auswahl ist jetzt intern modular: weitere Host-Settings koennen ueber `PickModeSelectionUI.registerChoiceSetting(...)` hinzugefuegt werden.
- Positionierung nach links ist mit WC3-Dialogen nicht moeglich; dafuer muss spaeter ein Frame-basiertes UI ueber `BlzCreateFrame...` gebaut werden.
