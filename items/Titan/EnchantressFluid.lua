if Debug and Debug.beginFile then Debug.beginFile("items/Titan/EnchantressFluid") end

OnInit("TitanItemEnchantressFluid", function(import)
    import.strict("GameTimer")
    import.strict("ItemExtras")
    import.strict("UnitStateSystem")

    local IDS = {
        ENCHANTRESS_FLUID = FourCC("I086"),
        ACTIVE = FourCC("A0V7")
    }

    local ACTIVE_DURATION = 2.5
    local RESTORE_AMOUNT = 800.0
    local TIMER_SPEED = 0.25

    local TitanItemEnchantressFluid = {}

    local function hasItem(unit)
        return ItemExtras.unitHasItemById(unit, IDS.ENCHANTRESS_FLUID)
    end

    local function restoreTimed(unit)
        local elapsed = 0.0
        local timer = nil

        timer = GameTimer.every(TIMER_SPEED, function()
            elapsed = elapsed + TIMER_SPEED
            if elapsed > ACTIVE_DURATION or not UnitStateSystem.isAlive(unit) then
                timer:destroy()
                return
            end

            UnitStateSystem.restore(
                unit,
                RESTORE_AMOUNT * TIMER_SPEED / ACTIVE_DURATION,
                RESTORE_AMOUNT * TIMER_SPEED / ACTIVE_DURATION,
                { attachPoint = "origin" }
            )
        end)
    end

    function TitanItemEnchantressFluid.activate(unit)
        restoreTimed(unit)
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()

        if GetSpellAbilityId() == IDS.ACTIVE and hasItem(caster) then
            TitanItemEnchantressFluid.activate(caster)
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

    TitanItemEnchantressFluid.ids = IDS

    _G.TitanItemEnchantressFluid = TitanItemEnchantressFluid
end)

if Debug and Debug.endFile then Debug.endFile() end
