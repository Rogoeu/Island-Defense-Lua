if Debug and Debug.beginFile then Debug.beginFile("items/Titan/EssenceOfPureMagic") end

OnInit("TitanItemEssenceOfPureMagic", function(import)
    import.strict("GameTimer")
    import.strict("ItemExtras")
    import.strict("UnitStateSystem")

    local IDS = {
        ESSENCE_OF_PURE_MAGIC = FourCC("I08U"),
        ACTIVE = FourCC("A0IY")
    }

    local DURATION = 2.5
    local RESTORE_AMOUNT = 1500.0
    local TIMER_SPEED = 0.10
    -- Count ticks rather than summing elapsed time: 25 additions of 0.1 land just
    -- above 2.5 in floating point and used to skip the final tick.
    local TICK_COUNT = math.floor(DURATION / TIMER_SPEED + 0.5)
    local RESTORE_PER_TICK = RESTORE_AMOUNT / TICK_COUNT

    local TitanItemEssenceOfPureMagic = {}

    local function hasItem(unit)
        return ItemExtras.unitHasItemById(unit, IDS.ESSENCE_OF_PURE_MAGIC)
    end

    local function restoreTimed(unit)
        local ticksLeft = TICK_COUNT
        local timer = nil

        timer = GameTimer.every(TIMER_SPEED, function()
            if ticksLeft <= 0 or not UnitStateSystem.isAlive(unit) then
                timer:destroy()
                return
            end
            ticksLeft = ticksLeft - 1

            UnitStateSystem.restore(
                unit,
                RESTORE_PER_TICK,
                RESTORE_PER_TICK,
                { attachPoint = "origin" }
            )
        end)
    end

    function TitanItemEssenceOfPureMagic.activate(unit)
        restoreTimed(unit)
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()

        if GetSpellAbilityId() == IDS.ACTIVE and hasItem(caster) then
            TitanItemEssenceOfPureMagic.activate(caster)
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

    TitanItemEssenceOfPureMagic.ids = IDS

    _G.TitanItemEssenceOfPureMagic = TitanItemEssenceOfPureMagic
end)

if Debug and Debug.endFile then Debug.endFile() end
