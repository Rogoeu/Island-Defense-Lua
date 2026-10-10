if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/NatureBuilderAbilities") end

OnInit("NatureBuilderAbilities", function(import)
    import.strict("AbilityRegistry")

    local IDS = {
        ENHANCED_VIGOR = FourCC("A0OP")
    }

    local function onHeroLevel()
        local hunter = GetTriggerUnit()
        local level = GetUnitAbilityLevel(hunter, IDS.ENHANCED_VIGOR)

        if level > 0 then
            SetHeroStr(hunter, GetHeroStr(hunter, false) + level, false)
        end
    end

    local trigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_HERO_LEVEL, nil)
        i = i + 1
    end
    TriggerAddAction(trigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onHeroLevel)
        else
            onHeroLevel()
        end
    end)

    AbilityRegistry.registerRace("Nature", "builder", {
        notes = "Nature builder/unit abilities ported from TitanHunterNature.",
        abilities = {
            {
                name = "Enhanced Vigor",
                id = IDS.ENHANCED_VIGOR,
                source = "library TitanHunterNature",
                behavior = "On hero level, add ability level as permanent strength."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
