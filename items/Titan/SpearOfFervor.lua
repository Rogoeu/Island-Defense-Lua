if Debug and Debug.beginFile then Debug.beginFile("items/Titan/SpearOfFervor") end

OnInit("TitanItemSpearOfFervor", function(import)
    import.strict("GameTimer")
    import.strict("ItemExtras")

    local IDS = {
        SPEAR_OF_FERVOR = FourCC("I095"),
        ATTACK_SPEED_BONUS = FourCC("A0IN")
    }

    local STACK_DURATION = 2.5
    local DECAY_INTERVAL = 0.15
    local MAX_LEVEL = 11

    local TitanItemSpearOfFervor = {}
    local timersByUnit = {}

    local function hasItem(unit)
        return ItemExtras.unitHasItemById(unit, IDS.SPEAR_OF_FERVOR)
    end

    local function startDecayTimer(unit, delay)
        local id = GetHandleId(unit)

        if timersByUnit[id] then
            timersByUnit[id]:destroy()
        end

        timersByUnit[id] = GameTimer.after(delay, function()
            timersByUnit[id] = nil
            if not unit or GetUnitTypeId(unit) == 0 then
                return
            end

            DecUnitAbilityLevel(unit, IDS.ATTACK_SPEED_BONUS)
            if GetUnitAbilityLevel(unit, IDS.ATTACK_SPEED_BONUS) > 1 then
                startDecayTimer(unit, DECAY_INTERVAL)
            end
        end)
    end

    local function addStack(unit)
        if GetUnitAbilityLevel(unit, IDS.ATTACK_SPEED_BONUS) <= 0 then
            UnitAddAbility(unit, IDS.ATTACK_SPEED_BONUS)
        end

        if GetUnitAbilityLevel(unit, IDS.ATTACK_SPEED_BONUS) < MAX_LEVEL then
            IncUnitAbilityLevel(unit, IDS.ATTACK_SPEED_BONUS)
        end

        startDecayTimer(unit, STACK_DURATION)
    end

    function TitanItemSpearOfFervor.apply(unit)
        addStack(unit)
    end

    local function onDamaged()
        local attacker = GetEventDamageSource()
        local target = GetTriggerUnit()
        local damageType = BlzGetEventDamageType and BlzGetEventDamageType() or DAMAGE_TYPE_NORMAL

        if not attacker or not target or damageType ~= DAMAGE_TYPE_NORMAL then
            return
        end
        if hasItem(attacker) and IsUnitEnemy(target, GetOwningPlayer(attacker)) then
            addStack(attacker)
        end
    end

    local trigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        i = i + 1
    end

    TriggerAddAction(trigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDamaged)
        else
            onDamaged()
        end
    end)

    TitanItemSpearOfFervor.ids = IDS

    _G.TitanItemSpearOfFervor = TitanItemSpearOfFervor
end)

if Debug and Debug.endFile then Debug.endFile() end
