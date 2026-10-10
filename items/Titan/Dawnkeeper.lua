if Debug and Debug.beginFile then Debug.beginFile("items/Titan/Dawnkeeper") end

OnInit("TitanItemDawnkeeper", function(import)
    import.strict("AbilityMeta")
    import.strict("GameTimer")
    import.strict("ItemExtras")
    import.strict("TitanDamageSystem")
    import.strict("UnitFilter")
    import.strict("UnitStateSystem")

    local IDS = {
        DAWNKEEPER = FourCC("I069"),
        ROBE_OF_LIES = FourCC("I07K"),
        ACTIVE = FourCC("A04P"),
        BUFF = FourCC("A0MN")
    }

    local SCOUT_ABILITIES = {
        [FourCC("A08J")] = true,
        [FourCC("A09J")] = true,
        [FourCC("A095")] = true,
        [FourCC("TMAD")] = true,
        [FourCC("TOTR")] = true,
        [FourCC("TVAD")] = true,
        [FourCC("A0DB")] = true,
        [FourCC("TTAD")] = true,
        [FourCC("A0Q3")] = true
    }

    local DURATION = 10.0
    local DAMAGE_SHARED = 0.25
    local ARMOR_BONUS = 5.0
    local SCOUT_HEAL = 0.05
    local EFFECT = "Abilities\\Spells\\Items\\Alda\\AldaTarget.mdl"
    local HEAL_EFFECT = "Abilities\\Spells\\Items\\AIlm\\AIlmTarget.mdl"

    local TitanItemDawnkeeper = {}
    local activeByUnit = {}
    local suppressDamage = false

    local function hasItem(unit, itemId)
        return ItemExtras.unitHasItemById(unit, itemId)
    end

    local function isScout(abilityId)
        local old = rawget(_G, "isScout")

        if old then
            return old(abilityId)
        end

        return SCOUT_ABILITIES[abilityId] == true
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
            casterEffect = AddSpecialEffectTarget(EFFECT, caster, "overhead"),
            targetEffect = AddSpecialEffectTarget(EFFECT, target, "overhead"),
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

    local function healOnScout(caster, abilityId)
        if isScout(abilityId) and hasItem(caster, IDS.DAWNKEEPER) and not hasItem(caster, IDS.ROBE_OF_LIES) then
            UnitStateSystem.addLife(caster, UnitStateSystem.maxLife(caster) * SCOUT_HEAL, { effect = HEAL_EFFECT, attachPoint = "origin" })
        end
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local target = GetSpellTargetUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.ACTIVE and target and hasItem(caster, IDS.DAWNKEEPER) then
            apply(caster, target)
        end

        healOnScout(caster, abilityId)
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

    TitanItemDawnkeeper.ids = IDS
    TitanItemDawnkeeper.apply = apply
    _G.TitanItemDawnkeeper = TitanItemDawnkeeper
end)

if Debug and Debug.endFile then Debug.endFile() end
