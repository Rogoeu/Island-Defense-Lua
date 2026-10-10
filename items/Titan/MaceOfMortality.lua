if Debug and Debug.beginFile then Debug.beginFile("items/Titan/MaceOfMortality") end

OnInit("TitanItemMaceOfMortality", function(import)
    import.strict("ItemExtras")
    import.strict("TitanDamageSystem")
    import.strict("UnitStateSystem")

    local IDS = {
        MACE_OF_MORTALITY = FourCC("I08T"),
        WARCRY_BUFF = FourCC("B099")
    }

    local COLOSSUS_RATIO = 0.03
    local SMASH_HEAL_RATIO = 0.01

    local TitanItemMaceOfMortality = {}
    local suppressDamage = false

    local function hasItem(unit)
        return ItemExtras.unitHasItemById(unit, IDS.MACE_OF_MORTALITY)
    end

    local function missingLife(unit)
        local missing = UnitStateSystem.maxLife(unit) - UnitStateSystem.life(unit)

        if missing < 0.0 then
            return 0.0
        end
        return missing
    end

    local function hasWarCry(unit)
        return GetUnitAbilityLevel(unit, IDS.WARCRY_BUFF) > 0
    end

    function TitanItemMaceOfMortality.apply(attacker, target)
        local missing = missingLife(attacker)
        local bonusDamage = missing * COLOSSUS_RATIO
        local healAmount = missing * SMASH_HEAL_RATIO

        if hasWarCry(attacker) then
            bonusDamage = bonusDamage * 2.0
        end

        suppressDamage = true
        if bonusDamage > 0.0 then
            TitanDamageSystem.dealDamage(attacker, target, bonusDamage, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
        end
        if healAmount > 0.0 then
            UnitStateSystem.heal(attacker, healAmount)
        end
        suppressDamage = false
    end

    local function onDamaged()
        local attacker = GetEventDamageSource()
        local target = GetTriggerUnit()
        local damageType = BlzGetEventDamageType and BlzGetEventDamageType() or DAMAGE_TYPE_NORMAL

        if suppressDamage or not attacker or not target then
            return
        end
        if damageType ~= DAMAGE_TYPE_NORMAL or not IsUnitEnemy(target, GetOwningPlayer(attacker)) or not hasItem(attacker) then
            return
        end

        TitanItemMaceOfMortality.apply(attacker, target)
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

    TitanItemMaceOfMortality.ids = IDS

    _G.TitanItemMaceOfMortality = TitanItemMaceOfMortality
end)

if Debug and Debug.endFile then Debug.endFile() end
