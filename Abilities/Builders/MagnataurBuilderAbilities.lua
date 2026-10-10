if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/MagnataurBuilderAbilities") end

OnInit("MagnataurBuilderAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("RacePickSystem")

    local IDS = {
        FROSTBITE = FourCC("A04G"),
        WAR_CRY = FourCC("A04L"),
        SUMMON_ABOMINABLE_SNOW_MAN = FourCC("A04O"),
        BLIZZARD = FourCC("A04Y"),
        HYPOTHERMIA = FourCC("A04N"),
        ICY_WEAPONS = FourCC("A04W"),
        ARCTIC_ARMOR = FourCC("A04X"),
        ICE_FLOW = FourCC("A04Z"),
        ARCTIC_ENDURANCE = FourCC("A07O"),
        FORTIFICATION_AURA = FourCC("A04K")
    }

    local PERMANENT_ABILITIES = {
        IDS.FROSTBITE,
        IDS.WAR_CRY,
        IDS.SUMMON_ABOMINABLE_SNOW_MAN,
        IDS.BLIZZARD,
        IDS.HYPOTHERMIA,
        IDS.ICY_WEAPONS,
        IDS.ARCTIC_ARMOR,
        IDS.ICE_FLOW,
        IDS.ARCTIC_ENDURANCE,
        IDS.FORTIFICATION_AURA
    }

    local function isMagnataur(playerData)
        local race = playerData and playerData:race() or nil
        return race and race ~= NullRace.instance() and race:toString() == "Magnataur"
    end

    local function onBuilderSpawn(playerData, unit)
        if not unit or not isMagnataur(playerData) then
            return
        end

        local i = 1
        while i <= #PERMANENT_ABILITIES do
            UnitMakeAbilityPermanent(unit, true, PERMANENT_ABILITIES[i])
            i = i + 1
        end
    end

    RacePickSystem.onBuilderSpawn(onBuilderSpawn)

    AbilityRegistry.registerRace("Magnataur", "builder", {
        notes = "Magnataur builder/unit abilities ported from MagnataurRace.",
        abilities = {
            {
                name = "Magnataur permanent abilities",
                source = "library MagnataurRace",
                behavior = "Makes Frostbite, War Cry, Summon Abominable Snow Man, Blizzard, Hypothermia, Icy Weapons, Arctic Armor, Ice Flow, Arctic Endurance and Fortification Aura permanent on spawn."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
