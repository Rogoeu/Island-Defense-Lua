if Debug and Debug.beginFile then Debug.beginFile("items/Titan/RobeOfSpellCraft") end

OnInit("TitanItemRobeOfSpellCraft", function(import)
    import.strict("DummyCaster")
    import.strict("GameTimer")
    import.strict("ItemExtras")
    import.strict("UnitStateSystem")

    local IDS = {
        ROBE_OF_SPELLCRAFT = FourCC("I08W"),
        ACTIVE = FourCC("A0HR"),
        DUMMY_BANISH = FourCC("A0IF"),
        ETHERITY_BUFF = FourCC("B063"),
        ARMOR_BONUS = FourCC("A0HQ")
    }

    local ORDER_BANISH = 852486
    local ETHEREAL_HEAL_INCREASE = 0.10
    local WISDOM_HEAL_RATIO = 0.25
    local ARMOR_DURATION = 5.0
    local MAX_ARMOR_STACKS = 3
    local SPELL_HEAL_MANA_RATIO = 0.10
    local HEAL_MANA_COST_RATIO = 0.50

    local TitanItemRobeOfSpellCraft = {}
    local armorTimers = {}

    local function hasItem(unit)
        return ItemExtras.unitHasItemById(unit, IDS.ROBE_OF_SPELLCRAFT)
    end

    local function isItemAbility(unit, abilityId)
        local ability = unit and BlzGetUnitAbility(unit, abilityId) or nil
        local field = rawget(_G, "ABILITY_BF_ITEM_ABILITY")

        if ability and field and BlzGetAbilityBooleanField then
            return BlzGetAbilityBooleanField(ability, field)
        end

        return false
    end

    local function oldCategoryMatches(name, abilityId)
        local fn = rawget(_G, name)
        if fn then
            return fn(abilityId)
        end
        return false
    end

    local function isTitanAbility(unit, abilityId)
        if oldCategoryMatches("isStealth", abilityId) or
            oldCategoryMatches("isScout", abilityId) or
            oldCategoryMatches("isNuke", abilityId) or
            oldCategoryMatches("isHeal", abilityId) or
            oldCategoryMatches("isUnique", abilityId) or
            oldCategoryMatches("isUltimate", abilityId) then
            return true
        end

        return not isItemAbility(unit, abilityId)
    end

    local function activateEtherity(caster)
        DummyCaster.castTarget(GetOwningPlayer(caster), IDS.DUMMY_BANISH, 1, ORDER_BANISH, caster, GetUnitX(caster), GetUnitY(caster), GetUnitFacing(caster), 1.0)
    end

    local function expireArmorStack(unit)
        local id = GetHandleId(unit)
        local level = GetUnitAbilityLevel(unit, IDS.ARMOR_BONUS)

        if level > 1 then
            DecUnitAbilityLevel(unit, IDS.ARMOR_BONUS)
            armorTimers[id] = GameTimer.after(0.15, function()
                if unit and GetUnitTypeId(unit) ~= 0 then
                    expireArmorStack(unit)
                else
                    armorTimers[id] = nil
                end
            end)
        else
            UnitRemoveAbility(unit, IDS.ARMOR_BONUS)
            armorTimers[id] = nil
        end
    end

    local function enchantArmor(unit)
        local id = GetHandleId(unit)
        local level = GetUnitAbilityLevel(unit, IDS.ARMOR_BONUS)

        if level <= 0 then
            UnitAddAbility(unit, IDS.ARMOR_BONUS)
        elseif level < MAX_ARMOR_STACKS then
            IncUnitAbilityLevel(unit, IDS.ARMOR_BONUS)
        end

        if armorTimers[id] then
            armorTimers[id]:destroy()
        end
        armorTimers[id] = GameTimer.after(ARMOR_DURATION, function()
            if unit and GetUnitTypeId(unit) ~= 0 then
                expireArmorStack(unit)
            else
                armorTimers[id] = nil
            end
        end)
    end

    local function healOnTitanSpell(unit)
        local healAmount = UnitStateSystem.maxMana(unit) * SPELL_HEAL_MANA_RATIO
        local manaCost = healAmount * HEAL_MANA_COST_RATIO

        if UnitStateSystem.mana(unit) >= manaCost then
            UnitStateSystem.addLife(unit, healAmount)
            UnitStateSystem.addMana(unit, -manaCost)
        end
    end

    local function removeEtheritySoon(unit)
        GameTimer.after(0.15, function()
            if unit and GetUnitTypeId(unit) ~= 0 then
                UnitRemoveAbility(unit, IDS.ETHERITY_BUFF)
            end
        end)
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.ACTIVE and hasItem(caster) then
            activateEtherity(caster)
            return
        end

        if hasItem(caster) and isTitanAbility(caster, abilityId) then
            enchantArmor(caster)
            healOnTitanSpell(caster)
        end

        if GetUnitAbilityLevel(caster, IDS.ETHERITY_BUFF) > 0 and isTitanAbility(caster, abilityId) then
            removeEtheritySoon(caster)
        end
    end

    local function onDamaged()
        local healed = GetTriggerUnit()
        local eventDamage = GetEventDamage()
        local factor = 0.0
        local amplified = 0.0
        local healAmount = 0.0
        local manaCost = 0.0

        if eventDamage >= 0.0 or GetUnitAbilityLevel(healed, IDS.ETHERITY_BUFF) <= 0 or not BlzSetEventDamage then
            return
        end

        factor = 1.0 + ETHEREAL_HEAL_INCREASE + (WISDOM_HEAL_RATIO * GetHeroInt(healed, true) / 100.0)
        amplified = eventDamage * factor
        healAmount = -amplified
        manaCost = healAmount * HEAL_MANA_COST_RATIO

        if UnitStateSystem.mana(healed) >= manaCost then
            BlzSetEventDamage(amplified)
            UnitStateSystem.addMana(healed, -manaCost)
        else
            BlzSetEventDamage(0.0)
        end
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

    TitanItemRobeOfSpellCraft.ids = IDS
    TitanItemRobeOfSpellCraft.activateEtherity = activateEtherity

    _G.TitanItemRobeOfSpellCraft = TitanItemRobeOfSpellCraft
end)

if Debug and Debug.endFile then Debug.endFile() end
