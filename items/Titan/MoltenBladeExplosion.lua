if Debug and Debug.beginFile then Debug.beginFile("items/Titan/MoltenBladeExplosion") end

OnInit("TitanItemMoltenBladeExplosion", function(import)
    import.strict("ItemExtras")
    import.strict("TitanDamageSystem")

    local IDS = {
        MOLTEN_BLADE = FourCC("I093")
    }

    local EXPLOSION_DAMAGE = 49.0
    local EXPLOSION_AOE_DEFAULT = 200.0
    local EXPLOSION_AOE_MAGIC = 75.0
    local EXPLOSION_EFFECT = "Abilities\\Spells\\Other\\Incinerate\\FireLordDeathExplode.mdl"

    local TitanItemMoltenBladeExplosion = {}
    local suppressDamage = false

    local function hasItem(unit)
        return ItemExtras.unitHasItemById(unit, IDS.MOLTEN_BLADE)
    end

    local function isAlive(unit)
        return unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405
    end

    local function armorReducedDamage(unit, amount)
        local armor = 0.0

        if rawget(_G, "BlzGetUnitArmor") then
            armor = BlzGetUnitArmor(unit)
        end
        return amount * (1.0 - ((armor * 0.06) / (1.0 + armor * 0.06)))
    end

    local function validExplosionTarget(unit, attacker, magic)
        if not isAlive(unit) or IsUnitAlly(unit, GetOwningPlayer(attacker)) then
            return false
        end
        if magic and IsUnitType(unit, UNIT_TYPE_STRUCTURE) then
            return false
        end
        return true
    end

    function TitanItemMoltenBladeExplosion.explode(deadUnit, attacker, magic)
        local group = CreateGroup()
        local unit = nil
        local radius = magic and EXPLOSION_AOE_MAGIC or EXPLOSION_AOE_DEFAULT

        GroupEnumUnitsInRange(group, GetUnitX(deadUnit), GetUnitY(deadUnit), radius, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if validExplosionTarget(unit, attacker, magic) then
                TitanDamageSystem.dealDamage(attacker, unit, armorReducedDamage(unit, EXPLOSION_DAMAGE), ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                DestroyEffect(AddSpecialEffectTarget(EXPLOSION_EFFECT, unit, "origin"))
            end
            unit = FirstOfGroup(group)
        end

        DestroyGroup(group)
    end

    local function onDamaged()
        local attacker = GetEventDamageSource()
        local damaged = GetTriggerUnit()
        local damage = GetEventDamage()
        local damageType = BlzGetEventDamageType and BlzGetEventDamageType() or DAMAGE_TYPE_NORMAL
        local magic = damageType == DAMAGE_TYPE_MAGIC

        if suppressDamage or not attacker or not damaged or not hasItem(attacker) then
            return
        end
        if damage <= 0.0 or (damageType ~= DAMAGE_TYPE_NORMAL and damageType ~= DAMAGE_TYPE_MAGIC) then
            return
        end
        if GetWidgetLife(damaged) > damage then
            return
        end

        suppressDamage = true
        TitanItemMoltenBladeExplosion.explode(damaged, attacker, magic)
        suppressDamage = false
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

    TitanItemMoltenBladeExplosion.ids = IDS

    _G.TitanItemMoltenBladeExplosion = TitanItemMoltenBladeExplosion
end)

if Debug and Debug.endFile then Debug.endFile() end
