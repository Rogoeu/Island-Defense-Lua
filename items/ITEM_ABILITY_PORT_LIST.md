# Titan Item Ability Port List

Ziel: Die grossen Item-Effekte aus `TitanItemAbilities.lua` wieder in kleine, getrennte Lua-Libraries aufteilen, aehnlich wie frueher in Zinc.

## Zielstruktur

Die vorbereiteten Dateien liegen unter `Lua code/items/Titan/` und sind erstmal passive Skeletons. Sie registrieren noch keine Trigger, damit nichts doppelt laeuft, solange `TitanItemAbilities.lua` noch aktiv ist.

- `Protection.lua`
- `CrisisRegen.lua`
- `AnkhOfSuperiority.lua`
- `FarSight.lua`
- `BlastingWand.lua`
- `TidalsGuardiansGrace.lua`
- `FieryTouch.lua`
- `MoltenBladeExplosion.lua`
- `RunicMark.lua`
- `TitanTrident.lua`
- `ShadowWalk.lua`
- `CasqueOfValor.lua`
- `CooldownReduction.lua`
- `EnchantressFluid.lua`
- `MagicArmor.lua`
- `dVoodooDecay.lua`
- `EtherealMirror.lua`
- `EssenceOfPureMagic.lua`
- `SpearOfFervor.lua`
- `TidalScepter.lua`
- `RobeOfSpellCraft.lua`
- `Dawnkeeper.lua`
- `MaceOfMortality.lua`
- `SiegecastersTrophy.lua`

Gemeinsame Helfer wie `hasItem`, `isAlive`, `effectTarget`, Item-Rawcodes und kleine Trigger-Registrierung koennen danach in eine gemeinsame Datei, z.B. `TitanItemAbilityUtils.lua`.

## Port-Reihenfolge

1. Kleine passive Damage-Hooks zuerst: Protection, MagicArmor.
2. Kleine OnPickup/Timer-Effekte: CrisisRegen.
3. Einfache Spell-Effekte: FarSight, EssenceOfPureMagic, EtherealMirror.
4. Death/attack side effects: FieryTouch, MoltenBladeExplosion, TidalsGuardiansGrace, TitanTrident.
5. Komplexere attack stacking/mark systems: RunicMark, SpearOfFervor, MaceOfMortality.
6. dVoodooDecay und ShadowWalk.
7. Alle bekannten Titan-Item-Libraries sind in eigene Dateien portiert.

## Item / Effect Map

| Item | Rawcode | Alte Library/Effekt | Aktueller Code | Ziel-Datei | Status |
| --- | --- | --- | --- | --- | --- |
| Armor of Tides | `I08V` | Protection, Crisis Regen | `TitanItemProtection.apply`, `TitanItemCrisisRegen.start` | `Protection.lua`, `CrisisRegen.lua` | Ported in eigene Dateien |
| Reef Armor | `I07Z` | Protection | `TitanItemProtection.apply` | `Protection.lua` | Ported in eigene Datei |
| Super Reg Spines | `I080` | Crisis Regen | `TitanItemCrisisRegen.start` | `CrisisRegen.lua` | Ported in eigener Datei |
| Mistlord's Cape | `I092` | Shadow Walk, Crisis Regen | `TitanItemShadowWalk.cast`, `TitanItemCrisisRegen.start` | `ShadowWalk.lua`, `CrisisRegen.lua` | Ported in eigene Dateien |
| Ankh of Superiority | `I07A` | Ankh Of Superiority | `TitanItemAnkhOfSuperiority.apply` | `AnkhOfSuperiority.lua` | Ported in eigener Datei |
| Pearl of Grand Vision | `I09K` | FarSight | `TitanItemFarSight.castPearl`, timed reveal | `FarSight.lua` | Ported in eigene Datei |
| Mystic Staff of Gods | `I01T` | FarSight | `TitanItemFarSight.castMysticStaff`, int-scaling AoE, temporary True Sight removal | `FarSight.lua` | Ported in eigene Datei |
| Enchanted Druid Leaf / Mystic Staff of Gods | `I052` / `I01T` | PassableItems | Replaces the picked-up item with a fresh copy, resetting only its item cooldown | `CooldownSwapReset.lua` | Ported in eigene Datei |
| Blasting Wand | `I06X` | BlastingWand | `TitanItemBlastingWand.cast` | `BlastingWand.lua` | Ported in eigener Datei |
| Tidal Guardian's Grace | `I089` | TidalsGuardiansGrace | critter kill shallow spawn, item-drop cleanup | `TidalsGuardiansGrace.lua` | Ported in eigene Datei |
| Gauntlets of Embers | `I08Q` | FieryTouch | `TitanItemFieryTouch.apply`, ember reveal, structure burn | `FieryTouch.lua` | Ported in eigene Datei |
| Molten Blade | `I093` | FieryTouch, MoltenBladeExplosion | `TitanItemFieryTouch.apply`, `TitanItemMoltenBladeExplosion.explode` | `FieryTouch.lua`, `MoltenBladeExplosion.lua` | Ported in eigene Dateien |
| Rune Fragment | `I07X` | RunicMark | small mark apply/consume | `RunicMark.lua` | Ported in eigene Datei |
| Runic Axe | `I08R` | RunicMark | mark apply/consume, hunter bonus | `RunicMark.lua` | Ported in eigene Datei |
| Foreteller's Sickle | `I090` | RunicMark | mana-scaled bonus damage, tooltip update | `RunicMark.lua` | Ported in eigene Datei |
| Highseer Slippers | `I08Y` | Cooldown Reduction, RunicMark | `TitanItemCooldownReduction.refundCooldown`, spellblade charge, cleanse, AoE mark hit | `CooldownReduction.lua`, `RunicMark.lua` | Ported in eigene Dateien |
| Titanic Trident | `I0A0` | TitanTrident | structure bonus damage on normal hit | `TitanTrident.lua` | Ported in eigene Datei |
| Poseidon's Trident | `I094` | TitanTrident | stronger structure bonus, active duration scaling | `TitanTrident.lua` | Ported in eigene Datei |
| Stormrider's Cloak | `I09Z` | ShadowWalk | `TitanItemShadowWalk.cast`, `onSpellCast` | `ShadowWalk.lua` | Ported in eigene Datei |
| Casque of Valor | `I031` | Casque of Valor | `TitanItemCasqueOfValor.apply`, shared damage in `onDamaged` | `CasqueOfValor.lua` | Ported in eigener Datei |
| Caster Scroll | `I081` | Cooldown Reduction | `TitanItemCooldownReduction.refundCooldown` | `CooldownReduction.lua` | Ported in eigener Datei |
| Enchantress Fluid | `I086` | Enchantress Fluid | `restoreTimed`, `onSpellEffect` | `EnchantressFluid.lua` | Ported in eigene Datei |
| Magic Armor | `I087` | MagicArmor | magic damage/heal reduction | `MagicArmor.lua` | Ported in eigene Datei |
| Enhanced Magic Armor | `I08Z` | MagicArmor | stronger magic damage/heal reduction | `MagicArmor.lua` | Ported in eigene Datei |
| Voodoo Wards | `I08B` | dVoodooDecay | `TitanItemDVoodooDecay.castVoodooWard`, aura decay, lifesteal in `onDamage` | `dVoodooDecay.lua` | Ported in eigener Datei |
| Helmet of the Damned | `I091` | dVoodooDecay | `TitanItemDVoodooDecay.castVoodooWard`, stronger aura decay, allied lifesteal aura | `dVoodooDecay.lua` | Ported in eigener Datei |
| Ethereal Mirror | `I068` | Ethereal Mirror | `TitanItemEtherealMirror.cast`, AoE ethereal, building fade/cancel | `EtherealMirror.lua` | Ported in eigene Datei |
| Essence of Pure Magic | `I08U` | EssenceOfPureMagic | `restoreTimed`, `onSpellEffect` | `EssenceOfPureMagic.lua` | Ported in eigene Datei |
| Spear of Fervor | `I095` | SpearOfFervor | attack speed stack timer, `A0IN` | `SpearOfFervor.lua` | Ported in eigene Datei |
| Tidal Scepter | `I08S` | TidalScepti / Tidal Scepter | range update, blast AoE, dynamic cooldown, nuke refund | `TidalScepter.lua` | Ported in eigene Datei |
| Robe of Spellcraft | `I08W` | RobeOfSpellCraft | `TitanItemRobeOfSpellCraft.activateEtherity`, armor stacks, spell heal, ethereal heal amp | `RobeOfSpellCraft.lua` | Ported in eigene Datei |
| Dawnkeeper | `I069` | Dawnkeeper | `TitanItemDawnkeeper.apply`, scout heal, shared damage in `onDamaged` | `Dawnkeeper.lua` | Ported in eigener Datei |
| Mace of Mortality | `I08T` | Mace Of Mortality | `TitanItemMaceOfMortality.apply`, attacker missing-life bonus/heal | `MaceOfMortality.lua` | Ported in eigene Datei |
| Siegecaster's Trophy | `I01P` | Siegecasters Trophy / Ruinous Harvest | building death rune spawn, rune pickup/despawn mana restore | `SiegecastersTrophy.lua` | Ported in eigene Datei |

## Offene Fragen vor dem Split

- Soll jede Item-Familie eigene Trigger registrieren, wie frueher, oder nutzen wir spaeter ein kleines gemeinsames Event-Bus-System fuer Item-Events?
- Soll `TitanItemAbilities.lua` am Ende komplett weg, oder als Kompatibilitaets-Loader/Index bestehen bleiben?
- `Siegecaster's Trophy` nutzt `I01P`; die alte Ruinous-Harvest-Logik ist nach `SiegecastersTrophy.lua` portiert.
