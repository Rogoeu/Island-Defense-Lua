# Ability Port TODO

Offene Punkte fuer den Ability-Port. Fokus: erst Alpha-relevante Builder/Races fertig machen, danach gemeinsame Systeme sauberer ziehen.

## High Priority

- [ ] Tauren - Stun System
  - `War Stomp` nutzt aktuell einen simplen `PauseUnit`-Stun.
  - Altes Verhalten mit einem richtigen `StunUnitTimed`-System nachbauen.
  - Danach `TaurenBuilderAbilities.lua` auf das neue System umstellen.

- [ ] Troll - Voodoo animation
  - `Voodoo` blockt/verschiebt Schaden bereits, aber die alte visuelle Rueckleitung fehlt noch.
  - Im alten Zinc/JASS pruefen, welches Modell/Effect benutzt wurde.
  - Effekt auf Ziel und/oder Voodoo-Empfaenger nachziehen.

- [ ] Breezerious - Nuke animation
  - `BreezeriousAbilities.lua` Nuke-Verhalten funktioniert, aber die alte Tornado/Cyclone-Visual-Fuehrung nochmal gegen Zinc abgleichen.
  - Projektil/Scale/Impact-Animation ingame pruefen und bei Bedarf nachziehen.

- [ ] Bubonicus - Nuke animation
  - `BubonicusAbilities.lua` Nuke-Logik ist portiert, aber die alte Meatwagon-Missile-Salve/Impact-Animation noch genauer nachziehen.
  - Vor allem Flugbahn, Splat-Effekte und Treffer-Timing gegen alten Code testen.

- [ ] Demonicus - Invul animation
  - `DemonicusAbilities.lua` Etherity/Unique setzt Invulnerable bereits, aber die alte Invul-/Etherity-Animation nochmal ingame gegenpruefen.
  - Effekte `DemonicusEtherityBuff.mdx` und Hand-Effect auf Attachpoints/Timing abgleichen.

- [ ] Noxious - Animationen fixen
  - `NoxiousAbilities.lua` funktioniert mechanisch, aber Nuke/Trap/Cloud/Ultimate-Visuals nochmal gegen alten Code und Ingame-Eindruck abgleichen.
  - Besonders Poison-Wave-Scale, Trap-Explosion und Ultimate-Missile/Poison-Dummy Timing pruefen.

- [x] Items - Blasting Wand alte Library/Rawcode nachziehen
  - Alte `BlastingWand`-Library gefunden und als eigenes Verhalten in `items/Titan/BlastingWand.lua` portiert.
  - Item `I06X`, Ability `A04T`.

## Race Follow-Ups

- [x] Troll - Worker unlock final pruefen
  - `h03R` ist initial per TechLimit gesperrt.
  - `TrollStructureAbilities.unlockWorker(player)` existiert.
  - Noch klaeren, welches Research/Object-Event im alten Code oder Objekteditor den Worker freischalten sollte.

- [x] Troll - Voodoo Verhalten testen
  - Damage blockt aktuell direkt und wird nach `0.10s` auf den Voodoo-Empfaenger uebertragen.
  - Testen mit mehreren Targets, totem/hero death edge cases und Magic/Normal damage.

- [x] Tauren - Ancestral Call testen
  - Damage split: 90 Prozent auf nahe eigene Totems.
  - Missile-Flug und Schaden pro Totem im Spiel pruefen.
  - Sicherstellen, dass Redirect-Damage keine TaurenEXP/andere Damage-Trigger doppelt ausloest.

- [x] Tauren - TaurenEXP Empower testen
  - Erfolgreicher Angriff gegen Titan/Minion soll EXP geben.
  - Nahe Totems sollen Mana, Leben und temporaeren Damage Bonus bekommen.
  - Werte mit altem Code abgleichen: 25 Mana, 5 Prozent Leben, 10 Prozent Damage fuer 5 Sekunden.

- [x] Zergling - Builder porten
  - Race setup und Hive Mind/ZerglingTower-System portiert.
  - Ingame noch pruefen, ob alle A0ST-Tower den Damage-Bonus korrekt anzeigen.

## Shared Systems

- [ ] Status System
  - Zentral fuer Stun/Pause/Disable Effekte.
  - Muss stack-sicher sein, damit zwei kurze Stuns nicht einen laengeren zu frueh aufheben.

- [ ] Damage Utility System
  - Gemeinsame Helfer fuer Damage blocken, delayed damage, redirects und recursion guards.
  - Kandidaten: Troll Voodoo, Tauren Ancestral Call, Morphling heroic aura, spaetere Titan-Faehigkeiten.

- [ ] Ability visual helpers
  - Kleine Wrapper fuer timed effects, lightning, missile impact effects.
  - Ziel: weniger Copy/Paste in Tower-Abilities mit vielen gleichzeitigen Triggern.

## Performance Checks

- [ ] Tower-heavy abilities profilieren
  - Besonders Damage-Trigger mit vielen Towers/Titan-Minions im Blick behalten.
  - Keine unnoetigen Group scans pro Hit, wenn ein frueher Ability/Unit-Type check reicht.

- [ ] Missile/Lightning cleanup pruefen
  - Sicherstellen, dass alle timed visuals sauber entfernt werden.
  - Keine Handle-Leaks bei Chain/Missile-Faehigkeiten.

## Notes

- Debug-/Testcommands sollen weiter ueber `DebugCheatPack.isEnabled(player)` gated bleiben.
- Desync-Regel: nur UI/Kamera lokal machen; Gameplay-State immer synchron halten.
