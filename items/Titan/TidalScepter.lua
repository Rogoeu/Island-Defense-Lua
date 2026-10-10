if Debug and Debug.beginFile then Debug.beginFile("items/Titan/TidalScepter") end

OnInit("TitanItemTidalScepter", function(import)
    import.strict("AbilityMeta")
    import.strict("GameTimer")
    import.strict("ItemExtras")
    import.strict("TitanDamageSystem")
    import.strict("UnitFilter")

    local IDS = {
        TIDAL_SCEPTER = FourCC("I08S"),
        TIDAL_BLAST = FourCC("A0IP")
    }

    local BLAST_RANGE = 750.0
    local AOE = 250.0
    local AOE_DAMAGE = 200.0
    local COOLDOWN_KILL = 45.0
    local COOLDOWN_NO_KILL = 90.0
    local NUKE_REFUND = 0.20
    local LIGHTNING_CODE = "AFOD"
    local HIT_EFFECT = "Abilities\\Spells\\Demon\\DemonBoltImpact\\DemonBoltImpact.mdl"

    local ITEM_SLOT_ORDERS = {
        [0] = 852008,
        [1] = 852009,
        [2] = 852010,
        [3] = 852011,
        [4] = 852012,
        [5] = 852013
    }

    local TitanItemTidalScepter = {}

    local function hasItem(unit)
        return ItemExtras.unitHasItemById(unit, IDS.TIDAL_SCEPTER)
    end

    local function effectTarget(path, unit, attach)
        DestroyEffect(AddSpecialEffectTarget(path, unit, attach or "origin"))
    end

    local function targetFilter(owner, unit)
        return UnitFilter.isAlive(unit) and
            IsUnitEnemy(unit, owner) and
            not IsUnitType(unit, UNIT_TYPE_STRUCTURE)
    end

    local function damageFor(unit)
        if UnitFilter.isTitanHunter(unit) then
            return AOE_DAMAGE + (0.15 * GetUnitState(unit, UNIT_STATE_MAX_LIFE))
        end
        if UnitFilter.isBuilder(unit) then
            return AOE_DAMAGE * 0.50
        end
        return AOE_DAMAGE
    end

    local function isNukeAbility(abilityId)
        local fn = rawget(_G, "isNuke")
        if fn then
            return fn(abilityId)
        end
        return false
    end

    local function destroyLightningTimed(lightning)
        GameTimer.after(0.15, function()
            if lightning then
                DestroyLightning(lightning)
            end
        end)
    end

    local function createLightning(caster, target)
        local lightning = AddLightning(
            LIGHTNING_CODE,
            false,
            GetUnitX(caster),
            GetUnitY(caster),
            GetUnitX(target),
            GetUnitY(target)
        )

        destroyLightningTimed(lightning)
    end

    local function applyBlast(caster, target)
        local group = CreateGroup()
        local unit = nil
        local killed = false
        local owner = GetOwningPlayer(caster)
        local x = GetUnitX(target)
        local y = GetUnitY(target)

        GroupEnumUnitsInRange(group, x, y, AOE, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if targetFilter(owner, unit) then
                effectTarget(HIT_EFFECT, unit, "origin")
                TitanDamageSystem.dealDamage(caster, unit, damageFor(unit), ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                if not killed and GetWidgetLife(unit) < 0.405 then
                    killed = true
                end
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)

        if killed then
            AbilityMeta.startCooldown(caster, IDS.TIDAL_BLAST, COOLDOWN_KILL)
        else
            AbilityMeta.startCooldown(caster, IDS.TIDAL_BLAST, COOLDOWN_NO_KILL)
        end
    end

    function TitanItemTidalScepter.cast(caster, target)
        if target then
            createLightning(caster, target)
            applyBlast(caster, target)
        end
    end

    local function isScepterOrder(unit)
        local slot = ItemExtras.slotById(unit, IDS.TIDAL_SCEPTER)
        return slot >= 0 and ITEM_SLOT_ORDERS[slot] == GetIssuedOrderId()
    end

    local function onTargetOrder()
        local unit = GetTriggerUnit()

        if hasItem(unit) and isScepterOrder(unit) then
            AbilityMeta.setRange(unit, IDS.TIDAL_BLAST, BLAST_RANGE)
        end
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.TIDAL_BLAST and hasItem(caster) then
            TitanItemTidalScepter.cast(caster, GetSpellTargetUnit())
        elseif hasItem(caster) and isNukeAbility(abilityId) then
            GameTimer.after(0.0, function()
                if caster and GetUnitTypeId(caster) ~= 0 and GetUnitAbilityLevel(caster, abilityId) > 0 then
                    AbilityMeta.refundCooldownPercent(caster, abilityId, NUKE_REFUND)
                end
            end)
        end
    end

    local orderTrigger = CreateTrigger()
    local spellTrigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(orderTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, nil)
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
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

    TriggerAddAction(orderTrigger, function() guarded(onTargetOrder) end)
    TriggerAddAction(spellTrigger, function() guarded(onSpellEffect) end)

    TitanItemTidalScepter.ids = IDS

    _G.TitanItemTidalScepter = TitanItemTidalScepter
end)

if Debug and Debug.endFile then Debug.endFile() end
