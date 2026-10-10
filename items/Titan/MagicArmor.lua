if Debug and Debug.beginFile then Debug.beginFile("items/Titan/MagicArmor") end

OnInit("TitanItemMagicArmor", function(import)
    import.strict("ItemExtras")

    local IDS = {
        MAGIC_ARMOR = FourCC("I087"),
        ENHANCED_MAGIC_ARMOR = FourCC("I08Z")
    }

    local MAGIC_ARMOR_REDUCTION = 0.15
    local ENHANCED_MAGIC_ARMOR_REDUCTION = 0.30

    local TitanItemMagicArmor = {}

    local function hasItem(unit, itemId)
        return ItemExtras.unitHasItemById(unit, itemId)
    end

    local function reductionFor(unit)
        if hasItem(unit, IDS.ENHANCED_MAGIC_ARMOR) then
            return ENHANCED_MAGIC_ARMOR_REDUCTION
        elseif hasItem(unit, IDS.MAGIC_ARMOR) then
            return MAGIC_ARMOR_REDUCTION
        end
        return 0.0
    end

    local function apply(unit, damage)
        local reduction = reductionFor(unit)

        if reduction <= 0.0 or not BlzSetEventDamage then
            return damage
        end

        if damage <= 0.0 then
            damage = damage * (1.0 + reduction)
        else
            damage = damage * (1.0 - reduction)
        end

        BlzSetEventDamage(damage)
        return damage
    end

    function TitanItemMagicArmor.apply(unit, damage)
        return apply(unit, damage)
    end

    local function onDamaged()
        local damaged = GetTriggerUnit()
        local damage = GetEventDamage()
        local damageType = BlzGetEventDamageType and BlzGetEventDamageType() or DAMAGE_TYPE_NORMAL

        if not damaged or damageType == DAMAGE_TYPE_NORMAL then
            return
        end

        apply(damaged, damage)
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

    TitanItemMagicArmor.ids = IDS

    _G.TitanItemMagicArmor = TitanItemMagicArmor
end)

if Debug and Debug.endFile then Debug.endFile() end
