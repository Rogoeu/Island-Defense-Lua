# Ability Migration Layout

Diese Struktur ist ein Scaffold fuer die 1:1-Portierung der alten JASS/Zinc-Ability-Systeme.

## Reihenfolge

1. `Abilities/AbilityRegistry.lua`
2. `Abilities/Global/GlobalBuilderAbilities.lua`
3. `Abilities/Global/GlobalTitanAbilities.lua`
4. `Abilities/Builders/*BuilderAbilities.lua`
5. `Abilities/Builders/*StructureAbilities.lua`
6. `Abilities/Titans/*Abilities.lua`

## Regeln

- Object-IDs bleiben identisch zur `.wct`/Map.
- Jede Race bekommt eigene Dateien.
- Defender-Races haben zwei Dateien:
  - `*BuilderAbilities.lua` fuer Builder/Hunter/aktive Race-Unit-Logik.
  - `*StructureAbilities.lua` fuer Tower/Wall/Building/Upgrade-Logik.
- Titan-Races haben je eine Datei fuer Titan- und Minion-Abilitys.
- Shared Abilitys landen in `GlobalBuilderAbilities.lua` oder `GlobalTitanAbilities.lua`.
- Erst registrieren, dann Ability fuer Ability porten und testen.
