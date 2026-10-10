# Island Defense Lua Migration Status

Stand: 2026-06-22

Diese Datei ist eine Arbeitsuebersicht fuer Ankuendigungen, Tests und die weitere
Migration. Die alte Referenz bleibt `IslandDefense_4.4.4unprot06.wct`. Sie wird
nicht mehr veraendert; neue Logik entsteht in `Lua code/`.

## Kurzfassung

Die spielbare Kernschleife ist weitgehend nach Lua portiert: Lobby, Titan- und
Builder-Auswahl, Rassen-Spawns, Defender-Tod zu Minion, Minion-Spawns, wichtige
Items, Titan-/Builder-Ability-Module, Multiboard, Observer, Team-Allianzen und
ein erstes Spielerprofil funktionieren als Lua-Systeme.

Viele alte Zinc-Libraries sind jedoch noch nicht einzeln auf vollstaendige
Funktionsgleichheit geprueft. "Vorhanden" bedeutet deshalb nicht automatisch
"bis auf jeden Spezialfall identisch".

## Portierte Kernsysteme

- Init-, Debug- und Command-Basis mit `OnInit`, `Debug.try` und Lua-Command-Registry.
- `GameSettings` und kommentierte `DefaultGameSettings`.
- `PlayerData`, feste Teilnehmer-Slots `0-10` und Observer-Slots `11-23`.
- Zentrale `TeamAlliances`: Builder-Team, Titan/Minion-Team, Observer-Sicht,
  Leave-Grace-Control und Ghost-Building-Feindschaft werden gemeinsam berechnet.
- Island-Defense-Autostart inklusive Titan-Auswahl, Pick-Mode-Setup und Race-Pick.
- Pick-Modi: All Pick, Unique Pick und All Random. All Random verteilt Builder
  aus einem gemeinsamen einzigartigen Pool, solange genug Rassen verfuegbar sind.
- Rassen- und Tech-Limits, Titan-Startlevel, Minion-Startlevel und Titan-Startitems.
- Defender-Tod, Defender-Leave, Observer-Uebernahme, Titan-Ersatz und Minion-Spawning.
- Defender-Strukturen als Ghost Buildings; normale Defender-Units werden entfernt.
- Corpse-Cleanup nach kurzer Zeit fuer Units und Gebaeude.
- WinCondition, Goldfeed-/Experience-Basis, Gold Coins und Hero-Level-Boni.

## Titan, Hunter und Minions

- TitanHunterExperience mit Critter-, Super-Critter- und Glyph-Logik.
- Super Critter ist ueber die Lobby aktivierbar und im Multiboard sichtbar.
- TitanHunterResist fuer Draenei, Dryad und Demonologist.
- Levelbasierte Hunter-Goldbounty wird auch als `Goldfed` erfasst.
- MinionSpawner als eigene Library, inklusive Grace-Courier vom Mound und
  Spawn nahe dem Killer ausserhalb der Grace-Phase.
- TitanDeath: Titan-/Minion-Bones, Chicken-Spawns und Titan Eggs.
- CritterSystem mit gezielter Chicken-Explosion und Critter-Respawn.

## Items und Shops

- BuilderShop mit manuellen Kosten, Auto-Complete, Rezepten, Varianten-Konvertierung
  und Ultimate-Tower-Transmute/Reroll.
- Stacked Items, Titan-/Builder-Pickup-Restriktionen und Titan-Item-Abilities.
- Bones, Eggs, Rezeptmarker und direkte Builder-Shop-Kaeufe sind als Lua-Logik vorhanden.
- Titan kann keine Permanent Items aufheben; Builder keine Artifacts.

## Abilities

### Globale Systeme

- TowerRange, GoldToLumber, FakeTeleport, Azshara und DisableAttack.
- Azshara: nach 20 Minuten freigeschaltet, pro Spieler genau eine, sichtbare
  Voraussetzungsanzeige, Cooldown-Timer, Builder-Tod-Verlaengerung und Titan-Sicht.

### Builder

- Eigene Builder-/Structure-Module existieren fuer Arachnid, Demonologist, Draenei,
  Dryad, Faerie, Gnoll, Goblin, Huntress, Magnataur, Makrura, Morphling, Murloc,
  Nature, Ogre, Panda, Pirate, Radioactive, Satyr, Tauren, Troll und Zergling.
- HunterSystem begrenzt Builder auf einen Titan Hunter, auch wenn eine Rasse mehrere
  Hunter-Optionen besitzt.
- Demonologist-, Draenei-, Panda- und weitere Spezialfaehigkeiten wurden bereits
  gezielt gegen alte Zinc-Libraries abgeglichen.

### Titan

- Titan-Ability-Module existieren fuer Arborius, Breezerious, Bubonicus, Demonicus,
  Fossurious, Glacious, Lucidious, Moltenious, Noxious, Terminus und Voltron.
- MissileSystem unterstuetzt gerichtete Geschosse, Boegen und Bounce-Nuke-Ketten.
- TitanDamageSystem verwendet magischen Schaden fuer Nukes, damit normale Warcraft-
  Magic/Spell-Resistance greifen kann.

## UI und Spielerkomfort

- Custom Game-Setup-UI mit Pick Mode, Minion Grace und Extra Modes.
- IslandDefenseMultiboard mit Team-Sicht, Spielerfarben, verborgenem Gegner-Icon
  und Goldfed-Spalte.
- Voting Board fuer Tweak-Votes mit altem `Ready`-Sound, Titel, Ja-Stimmen,
  Ablauf-Timer und lokalem `-vb on` / `-vb off`.
- PlayerNameDisplay ohne Clan-System: Namen zeigen lokal Rolle/Rasse entsprechend
  der Team-Perspektive, gegnerische Rassen bleiben verborgen.
- PlayerProfileUI sowie versioniertes PlayerProfile fuer Rollenstats, Wins, Elo,
  Kamera, Bans und spaetere Cosmetics.

## Debug und Tests

- DebugCheatPack ist die zentrale Freigabe fuer Testbefehle.
- Direkte Testcommands wie `-spawnminion`, `-defdie`, `-idspawn`, `-timertest`,
  `-luatest`, Multiboard-Debug und WinCondition-Debug sind ausserhalb einer
  aktivierten Debug-Lobby gesperrt.
- Import-Reihenfolge steht in `IMPORT_ORDER.md`.

## Bewusst nicht portiert oder noch offen

- Clan-System, Clan-Tags und Clan-Persistenz sind bewusst ausgelassen.
- Die alte Map enthaelt mehr als 500 Libraries. Ein vollstaendiger Library-fuer-
  Library-Paritaetsabgleich steht noch aus.
- Alte Pick-Modi wie Draft, Builder Random und InHouse sind noch nicht als moderne
  Lua-Pick-Modi umgesetzt.
- Viele alte Tweak-/Utility-Commands fehlen noch, zum Beispiel Quest-, Inventory-,
  Swap-, Lightning-, MoveSpeed-, Fog- und diverse Admin-/Debug-Tweaks.
- Cosmetics, Skins, Auras und Achievements haben eine vorbereitete Save-Struktur,
  aber noch kein fertiges Freischalt-/Ausrustungssystem.
- PlayerProfile speichert lokal ueber Preload/FileIO-Mechanik. Das ist an den Namen
  gebunden und obfuskiert, aber nicht manipulationssicher oder serverautoritaer.
- Race-Ability-Module muessen weiterhin im Spiel gegen die alte Map getestet werden,
  besonders seltene Upgrades, passive Interaktionen, Dummy-Zauber und Spezialfaelle.
- Weitere UI-Politur, Observer-Tests mit 24 Slots und Multiplayer-Synchronitaet
  bleiben wichtige Testthemen.

## Empfohlene naechste Schritte

1. Volle Lobby mit Buildern, Titan und Observers testen: Start, Teamwechsel,
   Observer-Uebernahme, Defender-Leave und Titan-Ersatz.
2. Jede Rasse einzeln spielen und alte Zinc-Libraries nur bei beobachteten Luecken
   gezielt nachportieren.
3. Das PlayerProfile mit echten mehrspielrigen Save/Load-Tests pruefen.
4. Fehlende Pick-Modi und die gewuenschten Cosmetics/Achievements priorisieren.
