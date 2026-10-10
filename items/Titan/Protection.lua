if Debug and Debug.beginFile then Debug.beginFile("items/Titan/Protection") end

OnInit("TitanItemProtection", function(import)
    import.strict("ItemExtras")

    local IDS = {
        ARMOR_OF_TIDES = FourCC("I08V"),
        REEF_ARMOR = FourCC("I07Z")
    }

    local REEF_REDUCTION = 0.01
    local TIDES_REDUCTION = 0.02

    local TitanItemProtection = {}

    local function hasItem(unit, itemId)
        return ItemExtras.unitHasItemById(unit, itemId)
    end

    local function reductionFor(unit)
        if hasItem(unit, IDS.ARMOR_OF_TIDES) then
            return TIDES_REDUCTION
        elseif hasItem(unit, IDS.REEF_ARMOR) then
            return REEF_REDUCTION
        end
        return 0.0
    end

    function TitanItemProtection.apply(target, damage)
        local reduction = reductionFor(target)

        if reduction <= 0.0 then
            return damage
        end
        return damage * (1.0 - reduction)
    end

    local function onDamaged()
        local target = GetTriggerUnit()
        local damage = GetEventDamage()
        local damageType = BlzGetEventDamageType and BlzGetEventDamageType() or DAMAGE_TYPE_NORMAL

        if damage <= 0.0 or damageType ~= DAMAGE_TYPE_NORMAL or not BlzSetEventDamage then
            return
        end

        BlzSetEventDamage(TitanItemProtection.apply(target, damage))
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

    TitanItemProtection.ids = IDS

    _G.TitanItemProtection = TitanItemProtection
end)

if Debug and Debug.endFile then Debug.endFile() end
