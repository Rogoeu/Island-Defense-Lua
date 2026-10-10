if Debug and Debug.beginFile then Debug.beginFile("Abilities/Global/TowerRange") end

OnInit("TowerRange", function(import)
    import.strict("GameTimer")

    local IDS = {
        SHOW_RANGE = FourCC("A0H9"),
        OGRE_CATAPULT_RANGE = FourCC("R037"),
        MURLOC_DART_RANGE = FourCC("R004"),
        ZERGLING_SPORE_RANGE = FourCC("R07B")
    }

    local MODEL_PATH = "Abilities\\Weapons\\SpiritOfVengeanceMissile\\SpiritOfVengeanceMissile.mdl"
    local EFFECT_COUNT = 32
    local EFFECT_DURATION = 8.0
    local RANGE_BUMP = 80.0

    local TOWER_RANGES = {
        [FourCC("o005")] = 1000.0, -- Sacred Seashell
        [FourCC("o00S")] = 1000.0, -- Spell Well
        [FourCC("o004")] = 825.0, -- Mega Dart Tower
        [FourCC("o006")] = 1000.0, -- Tropical Glyph
        [FourCC("o00L")] = 2000.0, -- Catapult
        [FourCC("o038")] = 750.0, -- Feral Tower Stage 7
        [FourCC("o010")] = 1000.0, -- Enhanced Factory
        [FourCC("e00Q")] = 600.0, -- Totem Tower
        [FourCC("o03C")] = 900.0, -- Island Bloom
        [FourCC("n01L")] = 1000.0, -- Energy Spire
        [FourCC("o02M")] = 600.0, -- Enhanced Frigate
        [FourCC("o036")] = 700.0, -- Feral Tower Stage 5
        [FourCC("h04J")] = 600.0, -- Cannon Tower
        [FourCC("o019")] = 800.0, -- Super Catapult
        [FourCC("o00O")] = 1100.0, -- Magic Tower
        [FourCC("o017")] = 850.0, -- Light Energy Tower
        [FourCC("o00H")] = 800.0, -- Enlarged Tidal Guardian
        [FourCC("o00G")] = 750.0, -- Enhanced Tidal Guardian
        [FourCC("n002")] = 700.0, -- Enhanced Spear Tower
        [FourCC("o02C")] = 900.0, -- Mega Arcane Construct
        [FourCC("o00A")] = 700.0, -- Super Axe Tower
        [FourCC("o01M")] = 900.0, -- Mega Energy Tower
        [FourCC("e006")] = 600.0, -- Protector Tree
        [FourCC("o033")] = 600.0, -- Feral Tower Stage 2
        [FourCC("o013")] = 700.0, -- Powerplant
        [FourCC("o001")] = 750.0, -- Super Dart Tower
        [FourCC("o02R")] = 800.0, -- Ice Palace
        [FourCC("o015")] = 1000.0, -- Mutation Tower
        [FourCC("o00W")] = 700.0, -- Factory
        [FourCC("o024")] = 700.0, -- Nature Feral Fruit Tree
        [FourCC("o011")] = 1000.0, -- Enhanced Mana Pool
        [FourCC("o03I")] = 1000.0, -- Refined Mana Pool
        [FourCC("o00Q")] = 900.0, -- Magic Mushroom
        [FourCC("o031")] = 900.0, -- Spiritual Rift
        [FourCC("h00P")] = 900.0, -- Heavy Cannon Tower
        [FourCC("o03A")] = 850.0, -- Feral Tower Stage 9
        [FourCC("o01H")] = 600.0, -- Dark Fissure
        [FourCC("o00T")] = 900.0, -- Spiny Protector
        [FourCC("h005")] = 105.0, -- Advanced Wall
        [FourCC("h011")] = 700.0, -- Super Cannon Tower
        [FourCC("o007")] = 1100.0, -- Magic Pearl
        [FourCC("o01Y")] = 2000.0, -- Methane Machine
        [FourCC("o02J")] = 700.0, -- Animal Cage
        [FourCC("o01N")] = 700.0, -- Mana Pool
        [FourCC("e00U")] = 800.0, -- Mega Totem Tower
        [FourCC("o01U")] = 1200.0, -- Demolisher Totem
        [FourCC("o003")] = 850.0, -- Sludge Launcher
        [FourCC("o01A")] = 700.0, -- Enhanced Pulse Tower
        [FourCC("o035")] = 675.0, -- Feral Tower Stage 4
        [FourCC("n003")] = 700.0, -- Spear Tower
        [FourCC("o034")] = 650.0, -- Feral Tower Stage 3
        [FourCC("n004")] = 750.0, -- Super Spear Tower
        [FourCC("o00P")] = 900.0, -- Bombard Tower
        [FourCC("o00N")] = 1000.0, -- Whirlpool
        [FourCC("o02A")] = 1000.0, -- High Energy Conduit
        [FourCC("o02L")] = 900.0, -- Mega Frigate
        [FourCC("o02D")] = 800.0, -- Super Arcane Construct
        [FourCC("o027")] = 900.0, -- Deadly Mega Axe Tower
        [FourCC("o01P")] = 1000.0, -- Wave Tower
        [FourCC("e00S")] = 650.0, -- Enhanced Totem Tower
        [FourCC("o01E")] = 900.0, -- Mega Catapult
        [FourCC("o018")] = 700.0, -- Pulse Tower
        [FourCC("h012")] = 900.0, -- Mega Cannon Tower
        [FourCC("n01K")] = 1100.0, -- Rapid Fire Tower
        [FourCC("o01L")] = 700.0, -- Super Energy Tower
        [FourCC("o02E")] = 1000.0, -- Well of Power
        [FourCC("o012")] = 700.0, -- Enhanced Catapult
        [FourCC("o02W")] = 600.0, -- Energy Tower
        [FourCC("o00K")] = 900.0, -- Crab Mutant
        [FourCC("e008")] = 700.0, -- Super Protector Tree
        [FourCC("o002")] = 600.0, -- Axe Tower
        [FourCC("n01J")] = 850.0, -- Deep Freeze
        [FourCC("o00J")] = 900.0, -- Giant Hermit
        [FourCC("o00I")] = 1050.0, -- Enraged Tidal Guardian
        [FourCC("o02B")] = 700.0, -- Enhanced Arcane Construct
        [FourCC("o02K")] = 600.0, -- Frigate
        [FourCC("o01J")] = 600.0, -- Enhanced Energy Tower
        [FourCC("o032")] = 550.0, -- Feral Tower Stage 1
        [FourCC("o01I")] = 700.0, -- Fruit Tree
        [FourCC("o01V")] = 1000.0, -- Replicator
        [FourCC("o01W")] = 600.0, -- Catapult
        [FourCC("o000")] = 675.0, -- Enhanced Dart Tower
        [FourCC("e007")] = 600.0, -- Enhanced Protector Tree
        [FourCC("o02N")] = 800.0, -- Super Frigate
        [FourCC("n005")] = 800.0, -- Mega Spear Tower
        [FourCC("o03B")] = 900.0, -- Feral Tower Stage 10
        [FourCC("h015")] = 400.0, -- Fortified Armed Wall
        [FourCC("h010")] = 600.0, -- Enhanced Cannon Tower
        [FourCC("o00M")] = 1000.0, -- Stasis Totem
        [FourCC("h014")] = 400.0, -- Armed Wall
        [FourCC("o037")] = 725.0, -- Feral Tower Stage 6
        [FourCC("e00T")] = 700.0, -- Super Totem Tower
        [FourCC("o009")] = 600.0, -- Enhanced Axe Tower
        [FourCC("o00R")] = 1000.0, -- Aura Tree
        [FourCC("o00B")] = 900.0, -- Mega Axe Tower
        [FourCC("o01B")] = 800.0, -- Super Pulse Tower
        [FourCC("o01C")] = 900.0, -- Mega Pulse Tower
        [FourCC("e009")] = 900.0, -- Mega Protector Tree
        [FourCC("o039")] = 800.0, -- Feral Tower Stage 8
        [FourCC("h03V")] = 600.0, -- Arcane Construct
        [FourCC("h01H")] = 600.0, -- Radon Tower
        [FourCC("o01F")] = 600.0, -- Dart Tower
        [FourCC("o016")] = 1000.0, -- Toxic Tower
        [FourCC("o00F")] = 700.0, -- Tidal Guardian
        [FourCC("o01Z")] = 540.0, -- Panda Volcano Tower / old duplicate override
        [FourCC("o02S")] = 600.0, -- Panda Basic Arrow Tower
        [FourCC("o02U")] = 675.0, -- Panda Enhanced Arrow Tower
        [FourCC("o02V")] = 750.0, -- Panda Super Arrow Tower
        [FourCC("o02X")] = 825.0, -- Panda Mega Arrow Tower
        [FourCC("o02Y")] = 750.0, -- Panda Lightning Tower
        [FourCC("o030")] = 825.0, -- Panda Enhanced Lightning Tower
        [FourCC("o03E")] = 900.0, -- Panda Super Lightning Tower
        [FourCC("o03F")] = 1000.0, -- Panda Mega Lightning Tower
        [FourCC("o03K")] = 590.0, -- Panda Enhanced Volcano Tower
        [FourCC("o03L")] = 540.0, -- Panda Super Volcano Tower
        [FourCC("o03M")] = 690.0, -- Panda Mega Volcano Tower
        [FourCC("o02I")] = 750.0, -- Box of Storms
        [FourCC("o02H")] = 750.0, -- Box of Earth
        [FourCC("o02G")] = 750.0, -- Box of Fire
        [FourCC("h01I")] = 600.0, -- Enhanced Radon Tower
        [FourCC("h01J")] = 700.0, -- Super Radon Tower
        [FourCC("h01K")] = 850.0, -- Mega Radon Tower
        [FourCC("h03G")] = 600.0, -- Radioactive Radon Tower, Enhanced Frost
        [FourCC("h03K")] = 700.0, -- Radioactive Radon Tower, Super Frost, Gold
        [FourCC("h03L")] = 700.0, -- Radioactive Radon Tower, Super Frost, Lumber
        [FourCC("h03T")] = 850.0, -- Radioactive Radon Tower, Mega Frost, Gold
        [FourCC("h04C")] = 850.0, -- Radioactive Radon Tower, Mega Frost, Lumber
        [FourCC("h03H")] = 600.0, -- Radioactive Radon Tower, Enhanced Magic
        [FourCC("h03M")] = 700.0, -- Radioactive Radon Tower, Super Magic, Gold
        [FourCC("h03N")] = 700.0, -- Radioactive Radon Tower, Super Magic, Lumber
        [FourCC("h03Y")] = 850.0, -- Radioactive Radon Tower, Mega Magic, Gold
        [FourCC("h04B")] = 850.0, -- Radioactive Radon Tower, Mega Magic, Lumber
        [FourCC("h04I")] = 600.0, -- Radioactive Radon Tower, Enhanced Overload
        [FourCC("h03O")] = 700.0, -- Radioactive Radon Tower, Super Overload, Gold
        [FourCC("H03P")] = 700.0, -- Radioactive Radon Tower, Super Overload, Lumber
        [FourCC("h047")] = 850.0, -- Radioactive Radon Tower, Mega Overload, Gold
        [FourCC("h04A")] = 850.0, -- Radioactive Radon Tower, Mega Overload, Lumber
        [FourCC("h03J")] = 600.0, -- Radioactive Radon Tower, Enhanced Rapid
        [FourCC("h03Q")] = 700.0, -- Radioactive Radon Tower, Super Rapid, Gold
        [FourCC("h03S")] = 700.0, -- Radioactive Radon Tower, Super Rapid, Lumber
        [FourCC("h048")] = 850.0, -- Radioactive Radon Tower, Mega Rapid, Gold
        [FourCC("h049")] = 850.0, -- Radioactive Radon Tower, Mega Rapid, Lumber
        [FourCC("o03S")] = 850.0, -- Demonic Altar
        [FourCC("h04Q")] = 600.0, -- Webweaver
        [FourCC("h04X")] = 600.0, -- Webweaver, Lumber only
        [FourCC("h04R")] = 680.0, -- Enhanced Webweaver
        [FourCC("h04S")] = 760.0, -- Super Webweaver
        [FourCC("h04T")] = 840.0, -- Mega Webweaver
        [FourCC("o040")] = 650.0, -- Tribal Totem
        [FourCC("o02Q")] = 1800.0, -- Firework Launcher
        [FourCC("e00X")] = 800.0, -- Elephant Foot
        [FourCC("o03Q")] = 550.0, -- Advanced Research Center Arachnid
        [FourCC("o043")] = 600.0, -- Zergling Spore Crawler
        [FourCC("e01W")] = 600.0, -- Glaive Thrower
        [FourCC("e01X")] = 700.0, -- Enhanced Glaive Thrower
        [FourCC("e01Y")] = 800.0, -- Super Glaive Thrower
        [FourCC("e021")] = 850.0, -- Mega Glaive Thrower
        [FourCC("n02G")] = 750.0 -- Berserk Spear Tower
    }

    local TowerRange = {}

    local function upgradeBonus(player, unitId)
        local ogreCount = GetPlayerTechCount(player, IDS.OGRE_CATAPULT_RANGE, true)
        local murlocCount = GetPlayerTechCount(player, IDS.MURLOC_DART_RANGE, true)
        local zerglingCount = GetPlayerTechCount(player, IDS.ZERGLING_SPORE_RANGE, true)

        if ogreCount > 0 and unitId == FourCC("o01W") then
            return ogreCount * 50.0
        end

        if zerglingCount > 0 and unitId == FourCC("o043") then
            return zerglingCount * 50.0
        end

        if murlocCount > 0 and
            (unitId == FourCC("o01F") or unitId == FourCC("o001") or unitId == FourCC("o004") or unitId == FourCC("o000")) then
            return 100.0
        end

        return 0.0
    end

    local function createRangeEffects(player, x, y, radius)
        local effects = {}
        local step = 2.0 * bj_PI / EFFECT_COUNT
        local i = 0

        while i < EFFECT_COUNT do
            local effect = AddSpecialEffect(MODEL_PATH, x + Cos(step * i) * radius, y + Sin(step * i) * radius)

            -- Create the same handle on every client. Alpha is visual-only and
            -- may safely differ for the owner of the range preview.
            if effect and rawget(_G, "BlzSetSpecialEffectAlpha") and GetLocalPlayer() ~= player then
                BlzSetSpecialEffectAlpha(effect, 0)
            end
            effects[#effects + 1] = effect
            i = i + 1
        end

        GameTimer.after(EFFECT_DURATION, function()
            local index = 1
            while index <= #effects do
                DestroyEffect(effects[index])
                effects[index] = nil
                index = index + 1
            end
        end)
    end

    local function rangeFor(unit)
        local unitId = GetUnitTypeId(unit)
        local base = TOWER_RANGES[unitId]

        if not base then
            return 0.0
        end

        return base + upgradeBonus(GetOwningPlayer(unit), unitId)
    end

    function TowerRange.rangeFor(unit)
        return rangeFor(unit)
    end

    function TowerRange.show(unit)
        local range = unit and rangeFor(unit) or 0.0

        if range <= 0.0 then
            return false
        end

        createRangeEffects(GetOwningPlayer(unit), GetUnitX(unit), GetUnitY(unit), range + RANGE_BUMP)
        return true
    end

    local function onSpellEffect()
        if GetSpellAbilityId() == IDS.SHOW_RANGE then
            TowerRange.show(GetTriggerUnit())
        end
    end

    local trigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        i = i + 1
    end

    TriggerAddAction(trigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onSpellEffect)
        else
            onSpellEffect()
        end
    end)

    TowerRange.ids = IDS
    TowerRange.ranges = TOWER_RANGES

    _G.TowerRange = TowerRange
    _G.BuilderTowerRange = TowerRange
end)

if Debug and Debug.endFile then Debug.endFile() end
