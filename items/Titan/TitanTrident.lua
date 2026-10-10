if Debug and Debug.beginFile then Debug.beginFile("items/Titan/TitanTrident") end

OnInit("TitanItemTitanTrident", function(import)
    import.strict("AbilityMeta")
    import.strict("ItemExtras")
    import.strict("TitanDamageSystem")

    local IDS = {
        TITANIC_TRIDENT = FourCC("I0A0"),
        POSEIDONS_TRIDENT = FourCC("I094"),
        POSEIDON_ACTIVE = FourCC("A0IR")
    }

    local TITANIC_BASE_DAMAGE = 10.0
    local TITANIC_DAMAGE_PER_LEVEL = 2.0
    local POSEIDON_BASE_DAMAGE = 10.0
    local POSEIDON_DAMAGE_PER_LEVEL = 5.0
    local MAX_DAMAGE = 99999.0
    local EFFECT = "Abilities\\Spells\\Other\\CrushingWave\\CrushingWaveDamage.mdl"

    local TitanItemTitanTrident = {}
    local suppressDamage = false

    local function hasItem(unit, itemId)
        return ItemExtras.unitHasItemById(unit, itemId)
    end

    local function effectTarget(path, unit, attach)
        DestroyEffect(AddSpecialEffectTarget(path, unit, attach or "origin"))
    end

    local function clampDamage(amount)
        if amount > MAX_DAMAGE then
            return MAX_DAMAGE
        end
        return amount
    end

    local function damageFor(attacker)
        if hasItem(attacker, IDS.POSEIDONS_TRIDENT) then
            return clampDamage(POSEIDON_BASE_DAMAGE + (POSEIDON_DAMAGE_PER_LEVEL * GetHeroLevel(attacker)))
        elseif hasItem(attacker, IDS.TITANIC_TRIDENT) then
            return clampDamage(TITANIC_BASE_DAMAGE + (TITANIC_DAMAGE_PER_LEVEL * GetHeroLevel(attacker)))
        end
        return 0.0
    end

    local function apply(attacker, target)
        local amount = damageFor(attacker)

        if not attacker or not target or amount <= 0.0 or not IsUnitType(target, UNIT_TYPE_STRUCTURE) then
            return false
        end

        suppressDamage = true
        TitanDamageSystem.dealDamage(attacker, target, amount, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
        suppressDamage = false
        effectTarget(EFFECT, target, "origin")
        return true
    end

    function TitanItemTitanTrident.apply(attacker, target)
        return apply(attacker, target)
    end

    local function onDamaged()
        local attacker = GetEventDamageSource()
        local target = GetTriggerUnit()
        local damageType = BlzGetEventDamageType and BlzGetEventDamageType() or DAMAGE_TYPE_NORMAL

        if suppressDamage or not attacker or not target or damageType ~= DAMAGE_TYPE_NORMAL then
            return
        end

        apply(attacker, target)
    end

    local function onSpellCast()
        local caster = GetTriggerUnit()

        if GetSpellAbilityId() == IDS.POSEIDON_ACTIVE then
            AbilityMeta.setDuration(caster, IDS.POSEIDON_ACTIVE, GetHeroLevel(caster))
        end
    end

    local damageTrigger = CreateTrigger()
    local castTrigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        TriggerRegisterPlayerUnitEvent(castTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_CAST, nil)
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

    TriggerAddAction(damageTrigger, function() guarded(onDamaged) end)
    TriggerAddAction(castTrigger, function() guarded(onSpellCast) end)

    TitanItemTitanTrident.ids = IDS

    _G.TitanItemTitanTrident = TitanItemTitanTrident
end)

if Debug and Debug.endFile then Debug.endFile() end
