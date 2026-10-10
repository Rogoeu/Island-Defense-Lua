if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/OgreStructureAbilities") end

OnInit("OgreStructureAbilities", function(import)
    import.strict("AbilityRegistry")

    local IDS = {
        ARTILLERY_RESEARCH = FourCC("R033"),
        DAMAGE_RESEARCH = FourCC("R034"),
        ENHANCED_CATAPULT = FourCC("o012"),
        SUPER_CATAPULT = FourCC("o019"),
        MEGA_CATAPULT = FourCC("o01E")
    }

    local function unlockDamageResearch(player)
        SetPlayerTechMaxAllowed(player, IDS.DAMAGE_RESEARCH, -1)
    end

    local function onResearchFinish()
        local researcher = GetTriggerUnit()
        local player = GetOwningPlayer(researcher)

        if GetResearched() == IDS.ARTILLERY_RESEARCH and GetPlayerTechCount(player, IDS.ARTILLERY_RESEARCH, true) >= 5 then
            unlockDamageResearch(player)
        end
    end

    local researchTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(researchTrigger, Player(i), EVENT_PLAYER_UNIT_RESEARCH_FINISH, nil)
        i = i + 1
    end

    TriggerAddAction(researchTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onResearchFinish)
        else
            onResearchFinish()
        end
    end)

    AbilityRegistry.registerRace("Ogre", "structures", {
        notes = "Ogre tower/building/upgrade abilities ported from OgreRace setupTech and research unlock logic.",
        abilities = {
            {
                name = "Ogre Catapult Locks",
                source = "library DefenderUnit/OgreRace",
                behavior = "RaceData keeps o012, o019 and o01E locked at start; Ogre research can unlock the chain through object data."
            },
            {
                name = "Artillery Damage Unlock",
                id = IDS.DAMAGE_RESEARCH,
                source = "library OgreRace",
                behavior = "When R033 reaches level 5, R034 is unlocked for the researching Ogre player."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
