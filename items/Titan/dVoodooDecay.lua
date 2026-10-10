if Debug and Debug.beginFile then Debug.beginFile("items/Titan/dVoodooDecay") end

OnInit("TitanItemDVoodooDecay", function(import)
    import.strict("GameTimer")
    import.strict("ItemExtras")
    import.strict("UnitStateSystem")
    import.strict("UnitFilter")

    local IDS = {
        VOODOO_DOLL = FourCC("I08B"),
        HELM_DAMNED = FourCC("I091"),
        VOODOO_WARD = FourCC("o03G"),
        DECAY_5 = FourCC("A0V8"),
        DECAY_3 = FourCC("A0V9"),
        LIFESTEAL = FourCC("A0VA"),
        LIFESTEAL_BUFF = FourCC("B09D"),
        TIMED_LIFE = FourCC("BTLF")
    }

    local AURA_RADIUS = 500.0
    local AURA_PERIOD = 1.0
    local WARD_DURATION = 30.0
    local LIFESTEAL_FACTOR = 0.25

    local TitanItemDVoodooDecay = {}
    local wardGroup = CreateGroup()
    local tempGroup = CreateGroup()
    local effectGroup = CreateGroup()
    local wardAbility = {}
    local touched = {}
    local affected = {}

    local function idOf(unit)
        return GetHandleId(unit)
    end

    local function hasItem(unit, itemId)
        return ItemExtras.unitHasItemById(unit, itemId)
    end

    local function hasLifestealBuff(unit)
        return unit and GetUnitAbilityLevel(unit, IDS.LIFESTEAL_BUFF) > 0
    end

    local function markTouched(unit)
        touched[idOf(unit)] = true
    end

    local function clearTouched(unit)
        touched[idOf(unit)] = nil
    end

    local function wasTouched(unit)
        return touched[idOf(unit)] == true
    end

    local function setAffected(unit, flag)
        affected[idOf(unit)] = flag == true
    end

    local function isAffected(unit)
        return affected[idOf(unit)] == true
    end

    local function wardAuraAbility(owner)
        if hasItem(owner, IDS.HELM_DAMNED) then
            return IDS.DECAY_5
        elseif hasItem(owner, IDS.VOODOO_DOLL) then
            return IDS.DECAY_3
        end

        return 0
    end

    local function applyArmorDecay(ward, target, abilityId)
        setAffected(target, true)
        GroupAddUnit(effectGroup, target)

        UnitAddAbility(ward, abilityId)
        IssueTargetOrder(ward, "faeriefire", target)
        UnitRemoveAbility(ward, abilityId)
    end

    local function applyLifesteal(ward, target)
        UnitAddAbility(ward, IDS.LIFESTEAL)
        IssueTargetOrder(ward, "bloodlust", target)
        UnitRemoveAbility(ward, IDS.LIFESTEAL)
    end

    local function clearTrackedEffect(unit)
        if isAffected(unit) then
            setAffected(unit, false)
            GroupRemoveUnit(effectGroup, unit)
        end
    end

    local function registerWard(ward, abilityId)
        if ward and abilityId and abilityId ~= 0 then
            GroupAddUnit(wardGroup, ward)
            wardAbility[idOf(ward)] = abilityId
        end
    end

    local function unregisterWard(ward)
        if ward then
            GroupRemoveUnit(wardGroup, ward)
            wardAbility[idOf(ward)] = nil
        end
    end

    local function processWardAura()
        local ward = GetEnumUnit()
        local abilityId = wardAbility[idOf(ward)] or 0
        local owner = nil
        local unit = nil

        if not UnitFilter.isAlive(ward) or abilityId == 0 then
            unregisterWard(ward)
            return
        end

        owner = GetOwningPlayer(ward)
        GroupEnumUnitsInRange(tempGroup, GetUnitX(ward), GetUnitY(ward), AURA_RADIUS, nil)
        unit = FirstOfGroup(tempGroup)
        while unit do
            GroupRemoveUnit(tempGroup, unit)
            if UnitFilter.isAlive(unit) then
                if IsUnitEnemy(unit, owner) then
                    markTouched(unit)
                    applyArmorDecay(ward, unit, abilityId)
                elseif abilityId == IDS.DECAY_5 and IsUnitAlly(unit, owner) then
                    markTouched(unit)
                    applyLifesteal(ward, unit)
                end
            end
            unit = FirstOfGroup(tempGroup)
        end
    end

    local function cleanupEffects()
        local unit = GetEnumUnit()

        if not wasTouched(unit) then
            clearTrackedEffect(unit)
        end

        clearTouched(unit)
    end

    local function onAuraTick()
        ForGroup(wardGroup, processWardAura)
        ForGroup(effectGroup, cleanupEffects)
    end

    local function castVoodooWard(caster)
        local abilityId = wardAuraAbility(caster)
        local ward = nil

        if abilityId == 0 then
            return nil
        end

        ward = CreateUnit(GetOwningPlayer(caster), IDS.VOODOO_WARD, GetUnitX(caster), GetUnitY(caster), GetUnitFacing(caster))
        UnitApplyTimedLife(ward, IDS.TIMED_LIFE, WARD_DURATION)
        registerWard(ward, abilityId)
        return ward
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()

        if GetSpellAbilityId() == IDS.LIFESTEAL and (hasItem(caster, IDS.VOODOO_DOLL) or hasItem(caster, IDS.HELM_DAMNED)) then
            castVoodooWard(caster)
        end
    end

    local function onSummon()
        local ward = GetSummonedUnit()
        local owner = GetSummoningUnit()

        if GetUnitTypeId(ward) == IDS.VOODOO_WARD then
            registerWard(ward, wardAuraAbility(owner))
        end
    end

    local function onDeath()
        local unit = GetTriggerUnit()

        if GetUnitTypeId(unit) == IDS.VOODOO_WARD then
            unregisterWard(unit)
        end
    end

    local function onDamage()
        local attacker = GetEventDamageSource()
        local damage = GetEventDamage()
        local isAttack = (rawget(_G, "BlzGetEventIsAttack") and BlzGetEventIsAttack()) or
            ((rawget(_G, "BlzGetEventAttackType") and BlzGetEventAttackType() == ATTACK_TYPE_NORMAL) and true or false)

        if isAttack and damage > 0.0 and hasLifestealBuff(attacker) then
            UnitStateSystem.heal(attacker, damage * LIFESTEAL_FACTOR)
        end
    end

    local spellTrigger = CreateTrigger()
    local summonTrigger = CreateTrigger()
    local deathTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(summonTrigger, Player(i), EVENT_PLAYER_UNIT_SUMMON, nil)
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
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
    TriggerAddAction(summonTrigger, function() guarded(onSummon) end)
    TriggerAddAction(deathTrigger, function() guarded(onDeath) end)
    TriggerAddAction(damageTrigger, function() guarded(onDamage) end)

    GameTimer.every(AURA_PERIOD, onAuraTick)

    TitanItemDVoodooDecay.ids = IDS
    TitanItemDVoodooDecay.castVoodooWard = castVoodooWard
    _G.TitanItemDVoodooDecay = TitanItemDVoodooDecay
end)

if Debug and Debug.endFile then Debug.endFile() end
