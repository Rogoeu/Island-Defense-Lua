if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/MurlocBuilderAbilities") end

OnInit("MurlocBuilderAbilities", function(import)
    import.strict("AbilityRegistry")

    local IDS = {
        SHORE_HUNTER = FourCC("A0KE"),
        CRITTER_MARKER = FourCC("CRIT"),
        SPAWN_UNIT = FourCC("h019")
    }
    local LUMBER_BOUNTY = 25

    local function onDeath()
        local hunter = GetKillingUnit()
        local target = GetDyingUnit()

        if hunter and target and
            GetUnitAbilityLevel(hunter, IDS.SHORE_HUNTER) > 0 and
            GetUnitAbilityLevel(target, IDS.CRITTER_MARKER) > 0 then
            local owner = GetOwningPlayer(hunter)
            local lumber = GetPlayerState(owner, PLAYER_STATE_RESOURCE_LUMBER)
            local reward = GetHeroLevel(hunter) * LUMBER_BOUNTY

            SetPlayerState(owner, PLAYER_STATE_RESOURCE_LUMBER, lumber + reward)

            if GetRandomInt(0, 3) == 1 then
                CreateUnit(owner, IDS.SPAWN_UNIT, GetUnitX(target), GetUnitY(target), GetUnitFacing(hunter))
            end
        end
    end

    local trigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        i = i + 1
    end
    TriggerAddAction(trigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDeath)
        else
            onDeath()
        end
    end)

    AbilityRegistry.registerRace("Murloc", "builder", {
        notes = "Murloc builder/unit abilities ported from TitanHunterMurloc.",
        abilities = {
            {
                name = "Shore Hunter",
                id = IDS.SHORE_HUNTER,
                source = "library TitanHunterMurloc",
                behavior = "Killing a CRIT-marked unit gives 25 lumber per hunter level and has a 1/4 chance to spawn h019."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
