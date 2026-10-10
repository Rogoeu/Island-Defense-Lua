if Debug and Debug.beginFile then Debug.beginFile("items/Titan/CasqueOfValor") end

OnInit("TitanItemCasqueOfValor", function(import)
    import.strict("AbilityMeta")
    import.strict("GameTimer")
    import.strict("ItemExtras")
    import.strict("TitanDamageSystem")
    import.strict("UnitFilter")

    local IDS = {
        CASQUE = FourCC("I031"),
        ACTIVE = FourCC("A0CO"),
        BUFF = FourCC("A0MN")
    }

    local DURATION = 10.0
    local DAMAGE_SHARED = 0.15
    local ARMOR_BONUS = 2.0
    local EFFECT = "Abilities\\Spells\\Items\\Alda\\AldaTarget.mdl"

    local TitanItemCasqueOfValor = {}
    local activeByUnit = {}
    local suppressDamage = false

    local function hasItem(unit)
        return ItemExtras.unitHasItemById(unit, IDS.CASQUE)
    end

    local function effectTarget(path, unit, attach)
        return AddSpecialEffectTarget(path, unit, attach or "origin")
    end

    local function addArmor(unit, amount)
        if unit and GetUnitTypeId(unit) ~= 0 and rawget(_G, "BlzSetUnitRealField") and rawget(_G, "BlzGetUnitRealField") then
            BlzSetUnitRealField(unit, UNIT_RF_DEFENSE, BlzGetUnitRealField(unit, UNIT_RF_DEFENSE) + amount)
        end
    end

    local function clearInstance(instance)
        if not instance or instance.done then
            return
        end

        instance.done = true
        activeByUnit[GetHandleId(instance.caster)] = nil
        activeByUnit[GetHandleId(instance.target)] = nil

        if UnitFilter.isAlive(instance.caster) then
            addArmor(instance.caster, -ARMOR_BONUS)
            UnitRemoveAbility(instance.caster, IDS.BUFF)
        end
        if UnitFilter.isAlive(instance.target) then
            addArmor(instance.target, -ARMOR_BONUS)
            UnitRemoveAbility(instance.target, IDS.BUFF)
        end
        if instance.casterEffect then
            DestroyEffect(instance.casterEffect)
        end
        if instance.targetEffect then
            DestroyEffect(instance.targetEffect)
        end
    end

    local function apply(caster, target)
        local instance = nil

        if not caster or not target or IsUnitEnemy(target, GetOwningPlayer(caster)) then
            return false
        end
        if activeByUnit[GetHandleId(caster)] or activeByUnit[GetHandleId(target)] then
            return false
        end

        instance = {
            caster = caster,
            target = target,
            casterEffect = effectTarget(EFFECT, caster, "overhead"),
            targetEffect = effectTarget(EFFECT, target, "overhead"),
            done = false
        }

        activeByUnit[GetHandleId(caster)] = instance
        activeByUnit[GetHandleId(target)] = instance

        AbilityMeta.addAbilityTimed(caster, IDS.BUFF, DURATION)
        AbilityMeta.addAbilityTimed(target, IDS.BUFF, DURATION)
        addArmor(caster, ARMOR_BONUS)
        addArmor(target, ARMOR_BONUS)

        GameTimer.after(DURATION, function()
            clearInstance(instance)
        end)

        return true
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local target = GetSpellTargetUnit()

        if GetSpellAbilityId() == IDS.ACTIVE and target and hasItem(caster) then
            apply(caster, target)
        end
    end

    local function onDamaged()
        local damaged = GetTriggerUnit()
        local damage = GetEventDamage()
        local instance = activeByUnit[GetHandleId(damaged)]
        local receiver = nil

        if suppressDamage or damage <= 0.0 or not instance then
            return
        end
        if not UnitFilter.isAlive(instance.caster) or not UnitFilter.isAlive(instance.target) then
            clearInstance(instance)
            return
        end

        if damaged == instance.caster then
            receiver = instance.target
        elseif damaged == instance.target then
            receiver = instance.caster
        else
            return
        end

        if BlzSetEventDamage then
            BlzSetEventDamage(damage * (1.0 - DAMAGE_SHARED))
        end

        suppressDamage = true
        TitanDamageSystem.dealDamage(damaged, receiver, damage * DAMAGE_SHARED, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
        suppressDamage = false
    end

    local spellTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        i = i + 1
    end

    local function guarded(callback)
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(callback)
        else
            callback()
        end
    end

    TriggerAddAction(spellTrigger, function() guarded(onSpellEffect) end)
    TriggerAddAction(damageTrigger, function() guarded(onDamaged) end)

    TitanItemCasqueOfValor.ids = IDS
    TitanItemCasqueOfValor.apply = apply
    _G.TitanItemCasqueOfValor = TitanItemCasqueOfValor
end)

if Debug and Debug.endFile then Debug.endFile() end
