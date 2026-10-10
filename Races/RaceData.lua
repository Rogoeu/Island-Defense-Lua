if Debug and Debug.beginFile then Debug.beginFile("Races/RaceData") end

OnInit("RaceData", function(import)
    import.strict("Races")
    import.strict("PlayerData")

    local DEFENDER = PlayerData.CLASS_DEFENDER
    local TITAN = PlayerData.CLASS_TITAN

    local RACE_TECH = {
        ULTIMATE_TOWERS = {
            "e00Y", -- The Crown
            "h00P", -- Heavy Cannon Tower
            "n01J", -- Deep Freeze
            "n01K", -- Rapid Fire Tower
            "n01L", -- Energy Spire
            "o003", -- Sludge Launcher
            "o005", -- Sacred Seashell
            "o006", -- Tropical Glyph
            "o007", -- Magic Pearl
            "o00J", -- Giant Hermit
            "o00K", -- Crab Mutant
            "o00L", -- Catapult
            "o00M", -- Stasis Totem
            "o00N", -- Whirlpool
            "o00O", -- Anti-Magic Tower
            "o00P", -- Bombard Tower
            "o00Q", -- Magic Mushroom
            "o00R", -- Aura Tree
            "o00S", -- Spell Well
            "o00T", -- Spiny Protector
            "o015", -- Mutation Tower
            "o016", -- Toxic Tower
            "o017", -- Light Energy Tower
            "o01P", -- Wave Tower
            "o01U", -- Demolisher Totem
            "o01V", -- Replicator
            "o01Y", -- Methane Machine
            "o02A", -- High Energy Conduct
            "o02E", -- Well of Power
            "o02G", -- Box of Flames
            "o02H", -- Box of Stones
            "o02I", -- Box of Storms
            "o02P", -- Tavern
            "o02Q", -- Fireworks Launcher
            "o02R", -- Ice Palace
            "o02S", -- Pandaren Arrow Tower
            "o02Y", -- Storm Spire
            "o03C", -- Island Bloom
            "o03N", -- Super Keg of Destruction
            "o01Z", -- Volcano
            "h02I", -- Advanced Earth Wall
            "h03E", -- Earth Wall
            "o02Z", -- Egg Sack
            "o03S", -- Demonic Altar
            "o021", -- Box of Pandaren
            "o024", -- Feral Fruit Tree
            "o027", -- Deadly Mega Axe Tower
            "h051", -- Goblin Worker
            "o040", -- Tribal Totem
            "e00X", -- Elephant Foot
            "o04G"  -- Stampede Tower
        }
    }

    local function defender(data)
        data.classValue = DEFENDER
        data.ultimateTowerIds = data.ultimateTowerIds or RACE_TECH.ULTIMATE_TOWERS
        data.wiki = data.wiki or {
            towers = {},
            walls = {},
            hunters = {},
            ultis = {},
            abilities = {},
            escapes = {}
        }
        return data
    end

    local function titan(data)
        data.classValue = TITAN
        data.wiki = data.wiki or {
            abilities = {},
            ultis = {}
        }
        return data
    end

    local DEFENDER_RACES = {
        defender({
            name = "Arachnid",
            widgetId = "h03D",
            itemId = "I08F",
            childId = "H04U",
            icon = "ReplaceableTextures\\CommandButtons\\BTNSpiderBlack.blp",
            difficulty = 2.0,
            techLimits = {
                { id = "o02Z", max = -1, note = "Egg Sack ultimate tower" },
                { id = "o02R", max = -1, note = "Ice Palace ultimate tower" },
                { id = "o00Q", max = -1, note = "Magic Mushroom ultimate tower" }
            }
        }),
        defender({
            name = "Demonologist",
            widgetId = "u00I",
            itemId = "I00S",
            childId = "U00S",
            icon = "ReplaceableTextures\\CommandButtons\\BTNDoomGuard.blp",
            difficulty = 3.0,
            techLimits = {
                { id = "o03S", max = -1, note = "Demonic Altar ultimate tower" }
            }
        }),
        defender({
            name = "Draenei",
            widgetId = "u00W",
            itemId = "I03Y",
            childId = "H040",
            childIds = { "H040", "H03Z" },
            icon = "ReplaceableTextures\\CommandButtons\\BTNDranaiMage.blp",
            difficulty = 2.0,
            techLimits = {
                { id = "o02A", max = -1, note = "High Energy Conduct ultimate tower" },
                { id = "o02E", max = -1, note = "Well of Power ultimate tower" },
                { id = "o00O", max = -1, note = "Magic Tower ultimate tower" },
                { id = "H03Z", max = 1, note = "Draenei Hunter" }
            }
        }),
        defender({
            name = "Dryad",
            widgetId = "h01T",
            itemId = "I066",
            childId = "H02L",
            icon = "ReplaceableTextures\\CommandButtons\\BTNDryad.blp",
            difficulty = 1.0,
            techLimits = {
                { id = "o00S", max = -1, note = "Spell Well ultimate tower" },
                { id = "o03C", max = -1, note = "Island Bloom ultimate tower" },
                { id = "o00Q", max = -1, note = "Magic Mushroom ultimate tower" },
                { id = "H02L", max = 1, note = "Dryad Hunter" }
            }
        }),
        defender({
            name = "Faerie",
            widgetId = "h02S",
            itemId = "I02W",
            icon = "ReplaceableTextures\\CommandButtons\\BTNFaerieDragon.blp",
            difficulty = 3.0,
            techLimits = {
                { id = "o017", max = -1, note = "Light Energy Tower ultimate tower" },
                { id = "o01P", max = -1, note = "Wave Tower ultimate tower" },
                { id = "o00O", max = -1, note = "Anti-Magic Tower ultimate tower" },
                { id = "o03L", max = 0, note = "Panda Super Volcano Tower locked for Faerie at game start" }
            }
        }),
        defender({
            name = "Gnoll",
            widgetId = "h009",
            itemId = "I02A",
            childId = "H00O",
            childIds = { "H00O", "H05M" },
            icon = "ReplaceableTextures\\CommandButtons\\BTNGnollKing.blp",
            difficulty = 1.0,
            techLimits = {
                { id = "o003", max = -1, note = "Sludge Launcher ultimate tower" },
                { id = "o006", max = -1, note = "Tropical Glyph ultimate tower" },
                { id = "o00Q", max = -1, note = "Magic Mushroom ultimate tower" },
                { id = "o027", max = 0, note = "Deadly Mega Axe Tower locked until Gnoll research unlocks it" },
                { id = "H00O", max = 1, note = "Gnoll Hunter" },
                { id = "H05M", max = 1, note = "Gnoll Hunter" }
            }
        }),
        defender({
            name = "Goblin",
            widgetId = "h00X",
            itemId = "I02E",
            childId = "H00Z",
            childIds = { "H00Z", "H05G" },
            icon = "ReplaceableTextures\\CommandButtons\\BTNHeroTinker.blp",
            difficulty = 3.0,
            techLimits = {
                { id = "n01K", max = -1, note = "Rapid Fire Tower ultimate tower" },
                { id = "n01J", max = -1, note = "Deep Freeze ultimate tower" },
                { id = "n01L", max = -1, note = "Energy Spire ultimate tower" },
                { id = "h051", max = 0, note = "Goblin Worker locked until Goblin research unlocks it" },
                { id = "h005", max = 0, note = "Goblin unit unavailable for this race" },
                { id = "H00Z", max = 1, note = "Goblin Hunter" },
                { id = "H05G", max = 1, note = "Goblin Hunter" }
            }
        }),
        defender({
            name = "Huntress",
            widgetId = "H05U",
            itemId = "I05K",
            icon = "ReplaceableTextures\\CommandButtons\\BTNSylvanusWindrunner.blp",
            difficulty = 3.0,
            randomPool = false,
            techLimits = {
                { id = "o00T", max = -1, note = "Spiny Protector ultimate tower" },
                { id = "o00S", max = -1, note = "Spell Well ultimate tower" },
                { id = "e01F", max = 0, note = "Owl Research Center locked until Owl companion choice" },
                { id = "o041", max = 0, note = "Advanced Owl Research Center locked until Owl companion choice" },
                { id = "o00Z", max = 0, note = "Owl Ultimate Structure locked until companion choice" },
                { id = "h05V", max = 0, note = "Owl Wall locked until Owl companion choice" },
                { id = "e01W", max = 0, note = "Owl Tower locked until Owl companion choice" },
                { id = "e01T", max = 0, note = "Azshara locked until Owl companion choice" },
                { id = "e01V", max = 0, note = "Wolf Research Center locked until Wolf companion choice" },
                { id = "o04J", max = 0, note = "Wolf Advanced Research locked until Wolf companion choice" },
                { id = "h05X", max = 0, note = "Wolf Wall locked until Wolf companion choice" }
            }
        }),
        defender({
            name = "Magnataur",
            widgetId = "h01B",
            itemId = "I02C",
            icon = "ReplaceableTextures\\CommandButtons\\BTNBlueMagnataur.blp",
            difficulty = 2.0,
            techLimits = {
                { id = "n01J", max = -1, note = "Deep Freeze ultimate tower" },
                { id = "o02R", max = -1, note = "Ice Palace ultimate tower" }
            }
        }),
        defender({
            name = "Makrura",
            widgetId = "h008",
            itemId = "I02D",
            childId = "H00N",
            icon = "ReplaceableTextures\\CommandButtons\\BTNLobstrokkGreen.blp",
            difficulty = 1.0,
            techLimits = {
                { id = "o00J", max = -1, note = "Giant Hermit ultimate tower" },
                { id = "o00K", max = -1, note = "Crab Mutant ultimate tower" },
                { id = "o00N", max = -1, note = "Whirlpool ultimate tower" },
                { id = "H00N", max = 1, note = "Makrura Hunter" }
            }
        }),
        defender({
            name = "Morphling",
            widgetId = "h021",
            widgetIds = { "h021", "h024", "h023" },
            itemId = "I029",
            icon = "ReplaceableTextures\\CommandButtons\\BTNFacelessOne.blp",
            difficulty = 2.0,
            techLimits = {
                { id = "o01V", max = -1, note = "Replicator ultimate tower" },
                { id = "n01L", max = -1, note = "Energy Spire ultimate tower" },
                { id = "o017", max = -1, note = "Light Energy Tower ultimate tower" }
            }
        }),
        defender({
            name = "Murloc",
            widgetId = "h04I",
            widgetIds = { "h04I", "h059" },
            itemId = "I012",
            childId = "H04K",
            childItemId = "q088",
            icon = "ReplaceableTextures\\CommandButtons\\BTNMurgalSlave.blp",
            difficulty = 1.0,
            techLimits = {
                { id = "o006", max = -1, note = "Tropical Glyph ultimate tower" },
                { id = "o007", max = -1, note = "Magic Pearl ultimate tower" },
                { id = "o005", max = -1, note = "Sacred Seashell ultimate tower" },
                { id = "H04K", max = 1, note = "Murloc Hunter" }
            }
        }),
        defender({
            name = "Nature",
            widgetId = "h00Q",
            itemId = "I02B",
            childId = "H00S",
            childItemId = "q050",
            icon = "ReplaceableTextures\\CommandButtons\\BTNAncientOfLore.blp",
            difficulty = 3.0,
            techLimits = {
                { id = "o00R", max = -1, note = "Aura Tree ultimate tower" },
                { id = "o00T", max = -1, note = "Spiny Protector ultimate tower" },
                { id = "o00S", max = -1, note = "Spell Well ultimate tower" },
                { id = "o024", max = -1, note = "Feral Fruit Tree ultimate tower" },
                { id = "H00S", max = 1, note = "Nature Hunter" }
            }
        }),
        defender({
            name = "Ogre",
            widgetId = "h037",
            widgetIds = { "h037", "h01N" },
            itemId = "I039",
            childId = "H039",
            childItemId = "q126",
            icon = "ReplaceableTextures\\CommandButtons\\BTNOgreLord.blp",
            difficulty = 2.0,
            techLimits = {
                { id = "o01Y", max = -1, note = "Methane Machine ultimate tower" },
                { id = "o016", max = -1, note = "Toxic Tower ultimate tower" },
                { id = "o003", max = -1, note = "Sludge Launcher ultimate tower" },
                { id = "h00P", max = -1, note = "Heavy Cannon Tower ultimate tower" },
                { id = "o012", max = 0, note = "Enhanced Catapult locked until Ogre tech unlocks it" },
                { id = "o019", max = 0, note = "Super Catapult locked until Ogre tech unlocks it" },
                { id = "o01E", max = 0, note = "Mega Catapult locked until Ogre tech unlocks it" },
                { id = "R034", max = 0, note = "Ogre damage research locked until R033 reaches level 5" },
                { id = "H039", max = 1, note = "Ogre Hunter" }
            }
        }),
        defender({
            name = "Panda",
            widgetId = "h02D",
            widgetIds = { "h02D", "h04V", "h04D", "h02N" },
            itemId = "I03T",
            icon = "ReplaceableTextures\\CommandButtons\\BTNPandarenBrewmaster.blp",
            difficulty = 3.0,
            techLimits = {
                { id = "o021", max = -1, note = "Box of Pandaren ultimate tower" },
                { id = "o02I", max = -1, note = "Box of Storms" },
                { id = "o02H", max = -1, note = "Box of Stones" },
                { id = "o02G", max = -1, note = "Box of Flames" },
                { id = "o02S", max = -1, note = "Basic Panda arrow tower" },
                { id = "o02Y", max = 0, note = "Storm Spire locked until Storm form" },
                { id = "h03E", max = 0, note = "Earth Wall locked until Earth form" },
                { id = "h02I", max = 0, note = "Advanced Earth Wall locked until Earth research/form" },
                { id = "o01Z", max = 0, note = "Volcano locked until Fire form" }
            }
        }),
        defender({
            name = "Pirate",
            widgetId = "h043",
            itemId = "I04C",
            childId = "H046",
            childItemId = "q205",
            icon = "ReplaceableTextures\\CommandButtons\\BTNMedivh.blp",
            difficulty = 1.0,
            techLimits = {
                { id = "o02P", max = -1, note = "Tavern ultimate tower" },
                { id = "o02Q", max = -1, note = "Fireworks Launcher ultimate tower" },
                { id = "o03N", max = -1, note = "Super Keg of Destruction ultimate tower" },
                { id = "o00P", max = -1, note = "Bombard Tower ultimate tower" },
                { id = "R04W", max = -1, note = "Admiral fleet deployment research" },
                { id = "R04X", max = -1, note = "Carronade fleet deployment research" },
                { id = "R04Y", max = -1, note = "Chainshot fleet deployment research" },
                { id = "R050", max = -1, note = "Flintlock fleet deployment research" },
                { id = "H046", max = 1, note = "Pirate Hunter" }
            }
        }),
        defender({
            name = "Radioactive",
            widgetId = "u009",
            itemId = "I028",
            childId = "H020",
            childIds = { "H020", "H017" },
            childItemId = "q092",
            icon = "ReplaceableTextures\\CommandButtons\\BTNInfernalStone.blp",
            difficulty = 2.0,
            techLimits = {
                { id = "o015", max = -1, note = "Mutation Tower ultimate tower" },
                { id = "h00P", max = -1, note = "Heavy Cannon Tower ultimate tower" },
                { id = "o016", max = -1, note = "Toxic Tower ultimate tower" },
                { id = "e00X", max = -1, note = "Elephant Foot ultimate tower" },
                { id = "H020", max = 1, note = "Radioactive Hunter" }
            }
        }),
        defender({
            name = "Satyr",
            widgetId = "h035",
            itemId = "I033",
            icon = "ReplaceableTextures\\CommandButtons\\BTNSatyrTrickster.blp",
            randomPool = false
        }),
        defender({
            name = "Tauren",
            widgetId = "O01Q",
            widgetIds = { "O01Q", "O01R" },
            itemId = "I02X",
            icon = "ReplaceableTextures\\CommandButtons\\BTNSpiritWalker.blp",
            difficulty = 2.0,
            techLimits = {
                { id = "o01U", max = -1, note = "Demolisher Totem ultimate tower" },
                { id = "o040", max = -1, note = "Tribal Totem ultimate tower" },
                { id = "o04G", max = -1, note = "Stampede Tower ultimate tower" }
            }
        }),
        defender({
            name = "Troll",
            widgetId = "h007",
            itemId = "I01J",
            childId = "H00M",
            childItemId = "q040",
            icon = "ReplaceableTextures\\CommandButtons\\BTNWitchDoctor.blp",
            difficulty = 2.0,
            techLimits = {
                { id = "o00M", max = -1, note = "Stasis Totem ultimate tower" },
                { id = "h00P", max = -1, note = "Heavy Cannon Tower ultimate tower" },
                { id = "o00L", max = -1, note = "Catapult ultimate tower" },
                { id = "h03R", max = 0, note = "Troll Worker locked until Troll research unlocks it" },
                { id = "H00M", max = 1, note = "Troll Hunter" }
            }
        }),
        defender({
            name = "Zergling",
            widgetId = "h04O",
            itemId = "I05Y",
            childId = "H057",
            childIds = { "H057", "H05L" },
            icon = "ReplaceableTextures\\CommandButtons\\BTNZergling.blp",
            difficulty = 2.0,
            techLimits = {
                { id = "o00K", max = -1, note = "Crab Mutant ultimate tower" },
                { id = "o00J", max = -1, note = "Giant Hermit ultimate tower" },
                { id = "o01V", max = -1, note = "Replicator ultimate tower" },
                { id = "H057", max = 1, note = "Zergling Hunter" },
                { id = "H05L", max = 1, note = "Zergling Hunter" }
            }
        })
    }

    local TITAN_RACES = {
        titan({
            name = "Arborius",
            widgetId = "TITA",
            itemId = "I08E",
            childId = "TIMA",
            icon = "ReplaceableTextures\\CommandButtons\\BTNAncientOfTheMoon.blp",
            childIcon = "ReplaceableTextures\\CommandButtons\\BTNTreant.blp",
            abilityIds = { "A0P6" }
        }),
        titan({
            name = "Breezerious",
            widgetId = "E011",
            itemId = "I02U",
            childId = "U00Y",
            icon = "ReplaceableTextures\\CommandButtons\\BTNNetherDragon.blp",
            childIcon = "ReplaceableTextures\\CommandButtons\\BTNNetherDragon.blp",
            abilityIds = { "A0CY" }
        }),
        titan({
            name = "Bubonicus",
            widgetId = "E00I",
            itemId = "I02M",
            childId = "U00B",
            icon = "ReplaceableTextures\\CommandButtons\\BTNAbomination.blp",
            childIcon = "ReplaceableTextures\\CommandButtons\\BTNDalaranMutant.blp",
            abilityIds = { "TBAF" }
        }),
        titan({
            name = "Demonicus",
            widgetId = "E00E",
            itemId = "I02K",
            childId = "U005",
            icon = "ReplaceableTextures\\CommandButtons\\BTNVoidWalker.blp",
            childIcon = "ReplaceableTextures\\CommandButtons\\BTNVoidwalker2.blp",
            abilityIds = { "A09B" }
        }),
        titan({
            name = "Fossurious",
            widgetId = "E012",
            itemId = "I03X",
            childId = "U01A",
            icon = "ReplaceableTextures\\CommandButtons\\BTNHeroCryptLord.blp",
            childIcon = "ReplaceableTextures\\CommandButtons\\BTNCarrionScarabs.blp",
            abilityIds = { "A0QU" }
        }),
        titan({
            name = "Glacious",
            widgetId = "E00J",
            itemId = "I00R",
            childId = "U00D",
            icon = "ReplaceableTextures\\CommandButtons\\BTNArchimonde.blp",
            childIcon = "ReplaceableTextures\\CommandButtons\\BTNWendigo.blp",
            abilityIds = { "A0QV" }
        }),
        titan({
            name = "Lucidious",
            widgetId = "E01D",
            itemId = "I02G",
            childId = "U016",
            icon = "ReplaceableTextures\\CommandButtons\\BTNNagaMyrmidon.blp",
            childIcon = "ReplaceableTextures\\CommandButtons\\BTNNagaMyrmidonRoyalGuard.blp",
            abilityIds = { "TLAF" }
        }),
        titan({
            name = "Moltenious",
            widgetId = "E00C",
            itemId = "I02I",
            childId = "U003",
            icon = "ReplaceableTextures\\CommandButtons\\BTNHeroAvatarOfFlame.blp",
            childIcon = "ReplaceableTextures\\CommandButtons\\BTNInfernal.blp",
            abilityIds = { "A0NG" }
        }),
        titan({
            name = "Noxious",
            widgetId = "E00B",
            itemId = "I02H",
            childId = "U001",
            icon = "ReplaceableTextures\\CommandButtons\\BTNHydra.blp",
            childIcon = "ReplaceableTextures\\CommandButtons\\BTNGreenHydra.blp",
            abilityIds = { "A092" }
        }),
        titan({
            name = "Granitacles",
            widgetId = "E00O",
            itemId = "I02J",
            childId = "U00O",
            icon = "ReplaceableTextures\\CommandButtons\\BTNMountainGiant.blp",
            childIcon = "ReplaceableTextures\\CommandButtons\\BTNAncientOfWonders.blp"
        }),
        titan({
            name = "Voltron",
            widgetId = "E00K",
            itemId = "I02L",
            childId = "U00L",
            icon = "ReplaceableTextures\\CommandButtons\\BTNDeepLordRevenant.blp",
            childIcon = "ReplaceableTextures\\CommandButtons\\BTNRevenant.blp",
            abilityIds = { "TVAF" }
        }),
    }

    local function registerAll(list)
        local i = 1
        while i <= #list do
            Races.register(list[i])
            i = i + 1
        end
    end

    registerAll(DEFENDER_RACES)
    registerAll(TITAN_RACES)

    _G.RaceData = {
        tech = RACE_TECH,
        defenders = DEFENDER_RACES,
        titans = TITAN_RACES
    }
end)

if Debug and Debug.endFile then Debug.endFile() end
