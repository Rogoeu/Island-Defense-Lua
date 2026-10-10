if Debug and Debug.beginFile then Debug.beginFile("items/TitanItemAbilities") end

OnInit("TitanItemAbilities", function()
    -- Legacy item-library map:
    -- Armor of Tides:          Protection ported to items/Titan/Protection.lua, Crisis Regen ported to items/Titan/CrisisRegen.lua
    -- Reef Armor:              ported to items/Titan/Protection.lua
    -- Super Reg Spines:                            ported to items/Titan/CrisisRegen.lua
    -- Pearl of Grand Vision:                       ported to items/Titan/FarSight.lua
    -- Mystic Staff of Gods:                        ported to items/Titan/FarSight.lua
    -- Tidal Guardian's Grace:                      ported to items/Titan/TidalsGuardiansGrace.lua
    -- Gauntlets of Embers:                         ported to items/Titan/FieryTouch.lua
    -- Molten Blade:                                ported to items/Titan/FieryTouch.lua and items/Titan/MoltenBladeExplosion.lua
    -- Runic Axe:                                   ported to items/Titan/RunicMark.lua
    -- Rune Fragment:                               ported to items/Titan/RunicMark.lua
    -- Foreteller's Sickle:                         ported to items/Titan/RunicMark.lua
    -- Titanic Trident:                             ported to items/Titan/TitanTrident.lua
    -- Poseidon's Trident:                          ported to items/Titan/TitanTrident.lua
    -- Stormrider's Cloak:                          ported to items/Titan/ShadowWalk.lua
    -- Mistlord's Cape:                             Shadow Walk ported to items/Titan/ShadowWalk.lua, Crisis Regen ported to items/Titan/CrisisRegen.lua
    -- Casque of Valor:                            ported to items/Titan/CasqueOfValor.lua
    -- Caster Scroll:                               ported to items/Titan/CooldownReduction.lua
    -- Enchantress Fluid:                          ported to items/Titan/EnchantressFluid.lua
    -- Magic Armor:                                 ported to items/Titan/MagicArmor.lua
    -- Enhanced Magic Armor:                        ported to items/Titan/MagicArmor.lua
    -- Voodoo Wards:                                ported to items/Titan/dVoodooDecay.lua
    -- Helmet of the Damned:                        ported to items/Titan/dVoodooDecay.lua
    -- Ethereal Mirror:                             ported to items/Titan/EtherealMirror.lua
    -- Essence of Pure Magic:                       ported to items/Titan/EssenceOfPureMagic.lua
    -- Spear of Fervor:                             ported to items/Titan/SpearOfFervor.lua
    -- Highseer Slippers:                           Cooldown Reduction ported to items/Titan/CooldownReduction.lua, Runic Mark ported to items/Titan/RunicMark.lua
    -- Dawnkeeper:                                  ported to items/Titan/Dawnkeeper.lua
    -- Mace of Mortality:                           ported to items/Titan/MaceOfMortality.lua
    -- Siegecaster's Trophy:                        ported to items/Titan/SiegecastersTrophy.lua
    -- Tidal Scepter:                               ported to items/Titan/TidalScepter.lua
    _G.TitanItemAbilities = {
        ids = {}
    }
end)

if Debug and Debug.endFile then Debug.endFile() end
