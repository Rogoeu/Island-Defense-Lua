if Debug and Debug.beginFile then Debug.beginFile("items/Titan/RunicMark") end

OnInit("TitanItemRunicMark", function(import)
    import.strict("DummyCaster")
    import.strict("GameTimer")
    import.strict("ItemExtras")
    import.strict("TitanDamageSystem")
    import.strict("UnitStateSystem")

    local IDS = {
        RUNIC_AXE = FourCC("I08R"),
        RUNE_FRAGMENT = FourCC("I07X"),
        HIGHSEER_SLIPPERS = FourCC("I08Y"),
        FORETELLERS_SICKLE = FourCC("I090"),
        RUNIC_MARK = FourCC("A0OX"),
        RUNIC_MARK_SMALL = FourCC("A0DL"),
        RUNIC_MARK_BUFF = FourCC("B07N"),
        RUNIC_MARK_SMALL_BUFF = FourCC("B07O"),
        TITAN_HUNTER = FourCC("TIHU")
    }

    local ORDER_RUNIC_MARK = 852570
    local ORDER_RUNIC_MARK_SMALL = 852189
    local RUNIC_DAMAGE = 25.0
    local RUNE_FRAGMENT_DAMAGE = 10.0
    local HUNTER_DAMAGE = 200.0
    local HIGHSEER_DAMAGE = 50.0
    local HIGHSEER_AOE = 250.0
    local HIGHSEER_SPELLS_NEEDED = 4
    local HIGHSEER_CLEANSE_DURATION = 2.0
    local HIGHSEER_CLEANSE_REFRESH = 0.20
    local HIGHSEER_CHARGE_EFFECT = "Abilities\\Spells\\Items\\AIem\\AIemTarget.mdl"
    local FORETELLER_MANA_DAMAGE_RATIO = 0.025

    local TitanItemRunicMark = {}
    local stateByUnit = {}
    local suppressDamage = false

    local function stateFor(unit)
        local id = GetHandleId(unit)
        if not stateByUnit[id] then
            stateByUnit[id] = {
                spellCount = 0,
                charged = false,
                cleanseTimer = nil,
                chargeEffect = nil
            }
        end
        return stateByUnit[id]
    end

    local function hasItem(unit, itemId)
        return ItemExtras.unitHasItemById(unit, itemId)
    end

    local function markDamage(target, normalDamage)
        if GetUnitAbilityLevel(target, IDS.TITAN_HUNTER) > 0 then
            return HUNTER_DAMAGE
        end
        return normalDamage
    end

    local function castMark(attacker, target, abilityId, orderId)
        DummyCaster.castTarget(GetOwningPlayer(attacker), abilityId, 1, orderId, target, GetUnitX(attacker), GetUnitY(attacker), GetUnitFacing(attacker), 1.0)
    end

    local function destroyChargeEffect(state)
        if state.chargeEffect then
            DestroyEffect(state.chargeEffect)
            state.chargeEffect = nil
        end
    end

    local function clearCharge(attacker)
        local state = stateFor(attacker)
        state.charged = false
        destroyChargeEffect(state)
    end

    local function createCharge(attacker)
        local state = stateFor(attacker)
        state.charged = true
        destroyChargeEffect(state)
        state.chargeEffect = AddSpecialEffectTarget(HIGHSEER_CHARGE_EFFECT, attacker, "origin")
    end

    local function damageTarget(attacker, target, amount)
        if amount <= 0.0 then
            return
        end
        suppressDamage = true
        TitanDamageSystem.dealDamage(attacker, target, amount, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
        suppressDamage = false
    end

    local function damageAOE(attacker, mainTarget, x, y, radius, amount)
        local group = CreateGroup()
        local unit = nil

        GroupEnumUnitsInRange(group, x, y, radius, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if unit ~= mainTarget and IsUnitEnemy(unit, GetOwningPlayer(attacker)) and not IsUnitType(unit, UNIT_TYPE_DEAD) then
                damageTarget(attacker, unit, amount)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function startHighseerCleanse(caster)
        local state = stateFor(caster)
        local ticks = 0

        if state.cleanseTimer then
            state.cleanseTimer:destroy()
        end

        state.cleanseTimer = GameTimer.every(HIGHSEER_CLEANSE_REFRESH, function()
            ticks = ticks + 1
            if not caster or GetUnitTypeId(caster) == 0 or not hasItem(caster, IDS.HIGHSEER_SLIPPERS) then
                state.cleanseTimer:destroy()
                state.cleanseTimer = nil
                return
            end
            if ticks <= R2I(HIGHSEER_CLEANSE_DURATION / HIGHSEER_CLEANSE_REFRESH) then
                UnitRemoveBuffs(caster, false, true)
            else
                state.cleanseTimer:destroy()
                state.cleanseTimer = nil
            end
        end)
    end

    local function updateSickleTooltip(unit)
        local item = ItemExtras.itemFromUnitById(unit, IDS.FORETELLERS_SICKLE)
        local bonusDamage = 0

        if item and BlzSetItemExtendedTooltip then
            bonusDamage = R2I(UnitStateSystem.mana(unit) * FORETELLER_MANA_DAMAGE_RATIO)
            BlzSetItemExtendedTooltip(item,
                "Foreteller's Sickle attributes:|n|cff99b4d1+ 25% attack speed|n+ 200 mana points|n|cff3399ffPassive - Foreteller's Echo|n|cff99b4d1Your attacks deal |cff60b0f0+" ..
                I2S(bonusDamage) .. " damage |cff99b4d1to buildings and |cff60b0f0+" .. I2S(R2I(bonusDamage * 0.50)) ..
                " damage |cff99b4d1to non-structure units. You lose mana equal to |cff60b0f0150% of the bonus damage dealt|cff99b4d1.|r"
            )
        end
    end

    local function applyRunicAxe(attacker, target)
        if GetUnitAbilityLevel(target, IDS.RUNIC_MARK_BUFF) <= 0 then
            castMark(attacker, target, IDS.RUNIC_MARK, ORDER_RUNIC_MARK)
        else
            UnitRemoveAbility(target, IDS.RUNIC_MARK_BUFF)
            damageTarget(attacker, target, markDamage(target, RUNIC_DAMAGE))
        end
    end

    local function applyRuneFragment(attacker, target)
        if GetUnitAbilityLevel(target, IDS.RUNIC_MARK_SMALL_BUFF) <= 0 then
            castMark(attacker, target, IDS.RUNIC_MARK_SMALL, ORDER_RUNIC_MARK_SMALL)
        else
            UnitRemoveAbility(target, IDS.RUNIC_MARK_SMALL_BUFF)
            damageTarget(attacker, target, RUNE_FRAGMENT_DAMAGE)
        end
    end

    local function applyHighseer(attacker, target)
        local state = stateFor(attacker)
        local amount = markDamage(target, HIGHSEER_DAMAGE)

        if state.charged then
            UnitRemoveAbility(target, IDS.RUNIC_MARK_BUFF)
            damageTarget(attacker, target, amount)
            damageAOE(attacker, target, GetUnitX(target), GetUnitY(target), HIGHSEER_AOE, HIGHSEER_DAMAGE * 2.0)
            clearCharge(attacker)
        elseif GetUnitAbilityLevel(target, IDS.RUNIC_MARK_BUFF) <= 0 then
            castMark(attacker, target, IDS.RUNIC_MARK, ORDER_RUNIC_MARK)
        else
            UnitRemoveAbility(target, IDS.RUNIC_MARK_BUFF)
            damageTarget(attacker, target, amount)
        end
    end

    local function applyForeteller(attacker, target)
        local currentMana = UnitStateSystem.mana(attacker)
        local bonus = currentMana * FORETELLER_MANA_DAMAGE_RATIO
        local damage = bonus
        local manaCost = bonus * 1.5

        if bonus <= 0.0 then
            return
        end

        if not IsUnitType(target, UNIT_TYPE_STRUCTURE) then
            damage = bonus * 0.5
            manaCost = bonus
        end

        damageTarget(attacker, target, damage)
        UnitStateSystem.addMana(attacker, -manaCost)
        updateSickleTooltip(attacker)
    end

    local function onDamaged()
        local attacker = GetEventDamageSource()
        local target = GetTriggerUnit()
        local damageType = BlzGetEventDamageType and BlzGetEventDamageType() or DAMAGE_TYPE_NORMAL

        if suppressDamage or not attacker or not target or damageType ~= DAMAGE_TYPE_NORMAL then
            return
        end
        if not IsUnitEnemy(target, GetOwningPlayer(attacker)) then
            return
        end

        if hasItem(attacker, IDS.RUNIC_AXE) then
            applyRunicAxe(attacker, target)
        elseif hasItem(attacker, IDS.RUNE_FRAGMENT) then
            applyRuneFragment(attacker, target)
        elseif hasItem(attacker, IDS.HIGHSEER_SLIPPERS) then
            applyHighseer(attacker, target)
        end

        if hasItem(attacker, IDS.FORETELLERS_SICKLE) then
            applyForeteller(attacker, target)
        end
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local state = nil

        if hasItem(caster, IDS.HIGHSEER_SLIPPERS) then
            state = stateFor(caster)
            startHighseerCleanse(caster)
            state.spellCount = state.spellCount + 1
            if state.spellCount >= HIGHSEER_SPELLS_NEEDED then
                state.spellCount = 0
                createCharge(caster)
            end
        end
    end

    local function onPickup()
        local unit = GetTriggerUnit()
        if GetItemTypeId(GetManipulatedItem()) == IDS.FORETELLERS_SICKLE then
            updateSickleTooltip(unit)
        end
    end

    local damageTrigger = CreateTrigger()
    local spellTrigger = CreateTrigger()
    local pickupTrigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(pickupTrigger, Player(i), EVENT_PLAYER_UNIT_PICKUP_ITEM, nil)
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
    TriggerAddAction(spellTrigger, function() guarded(onSpellEffect) end)
    TriggerAddAction(pickupTrigger, function() guarded(onPickup) end)

    TitanItemRunicMark.ids = IDS
    TitanItemRunicMark.updateSickleTooltip = updateSickleTooltip

    _G.TitanItemRunicMark = TitanItemRunicMark
end)

if Debug and Debug.endFile then Debug.endFile() end
