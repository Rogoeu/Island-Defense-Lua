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
    local RESTORE_AMOUNT = 1000.0
    local TIMER_SPEED = 0.10

    local TitanItemEssenceOfPureMagic = {}

    local function hasItem(unit)
        return ItemExtras.unitHasItemById(unit, IDS.ESSENCE_OF_PURE_MAGIC)
    end

    local function restoreTimed(unit)
        local elapsed = 0.0
        local timer = nil

        timer = GameTimer.every(TIMER_SPEED, function()
            elapsed = elapsed + TIMER_SPEED
            if elapsed > DURATION or not UnitStateSystem.isAlive(unit) then
                timer:destroy()
                return
            end

            UnitStateSystem.restore(
                unit,
                RESTORE_AMOUNT * TIMER_SPEED / DURATION,
                RESTORE_AMOUNT * TIMER_SPEED / DURATION,
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
