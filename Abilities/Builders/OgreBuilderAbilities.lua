if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/OgreBuilderAbilities") end

OnInit("OgreBuilderAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("DummyCaster")

    local IDS = {
        FART = FourCC("A067"),
        FART_SILENCE = FourCC("A0LI"),
        FART_CLOUD = FourCC("u00T"),
        TIMED_LIFE = FourCC("BTLF")
    }

    local FART_CLOUD_COUNT = 5
    local FART_CLOUD_DURATION = 10.0
    local FART_CLOUD_OFFSET = 50.0
    local FART_SILENCE_ORDER = OrderId("silence")

    local function playFartSound()
        local sound = rawget(_G, "gg_snd_Fart")
        if sound then
            PlaySoundBJ(sound)
        end
    end

    local function createFartClouds(player, x, y)
        local i = 0
        local cloud = nil

        while i < FART_CLOUD_COUNT do
            cloud = CreateUnit(
                player,
                IDS.FART_CLOUD,
                GetRandomReal(-FART_CLOUD_OFFSET, FART_CLOUD_OFFSET) + x,
                GetRandomReal(-FART_CLOUD_OFFSET, FART_CLOUD_OFFSET) + y,
                0.0
            )
            UnitApplyTimedLife(cloud, IDS.TIMED_LIFE, FART_CLOUD_DURATION)
            i = i + 1
        end
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local player = nil
        local x = 0.0
        local y = 0.0

        if GetSpellAbilityId() ~= IDS.FART then
            return
        end

        player = GetOwningPlayer(caster)
        x = GetUnitX(caster)
        y = GetUnitY(caster)

        DummyCaster.castPoint(player, IDS.FART_SILENCE, 1, FART_SILENCE_ORDER, x, y, x, y, GetUnitFacing(caster), 1.0)
        createFartClouds(player, x, y)
        playFartSound()
    end

    local spellTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        i = i + 1
    end

    TriggerAddAction(spellTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onSpellEffect)
        else
            onSpellEffect()
        end
    end)

    AbilityRegistry.registerRace("Ogre", "builder", {
        notes = "Ogre builder/unit abilities ported from Fart.",
        abilities = {
            {
                name = "Fart Cloud",
                id = IDS.FART,
                source = "library Fart",
                behavior = "On A067, dummy-casts A0LI Silence at the Ogre, creates five u00T fart clouds for 10 seconds and plays gg_snd_Fart."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
