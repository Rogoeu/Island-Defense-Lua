if Debug and Debug.beginFile then Debug.beginFile("Systems/AbilityMeta") end

OnInit("AbilityMeta", function(import)
    import.strict("GameTimer")

    local AbilityMeta = {}

    local function levelIndex(unit, abilityId)
        local level = GetUnitAbilityLevel(unit, abilityId)
        if level <= 0 then
            return 0
        end
        return level - 1
    end

    local function ability(unit, abilityId)
        if not unit then
            return nil
        end
        return BlzGetUnitAbility(unit, abilityId)
    end

    local function refresh(unit, abilityId)
        if unit and GetUnitAbilityLevel(unit, abilityId) > 0 then
            IncUnitAbilityLevel(unit, abilityId)
            DecUnitAbilityLevel(unit, abilityId)
        end
    end

    local function setReal(unit, abilityId, field, value)
        local abil = ability(unit, abilityId)
        if abil then
            BlzSetAbilityRealLevelField(abil, field, levelIndex(unit, abilityId), value)
            refresh(unit, abilityId)
        end
    end

    local function setInt(unit, abilityId, field, value)
        local abil = ability(unit, abilityId)
        if abil then
            BlzSetAbilityIntegerLevelField(abil, field, levelIndex(unit, abilityId), value)
            refresh(unit, abilityId)
        end
    end

    local function getReal(unit, abilityId, field, fallback)
        local abil = ability(unit, abilityId)
        if abil then
            return BlzGetAbilityRealLevelField(abil, field, levelIndex(unit, abilityId))
        end
        return fallback or 0.0
    end

    function AbilityMeta.setDescription(abilityId, text, level)
        BlzSetAbilityExtendedTooltip(abilityId, text or "", (level or 1) - 1)
    end

    function AbilityMeta.setTitle(abilityId, text, level)
        BlzSetAbilityTooltip(abilityId, text or "", (level or 1) - 1)
    end

    function AbilityMeta.addAbilityTimed(unit, abilityId, duration, buffId)
        UnitAddAbility(unit, abilityId)
        GameTimer.after(duration or 0.0, function()
            if unit and GetUnitTypeId(unit) ~= 0 then
                UnitRemoveAbility(unit, abilityId)
                if buffId and buffId ~= 0 then
                    UnitRemoveAbility(unit, buffId)
                end
            end
        end)
    end

    function AbilityMeta.refundCooldownPercent(unit, abilityId, percent)
        local level = levelIndex(unit, abilityId)
        local cooldown = 0.0

        if percent < 1 then
            cooldown = BlzGetAbilityCooldown(abilityId, level) * (1.0 - percent)
        else
            cooldown = BlzGetAbilityCooldown(abilityId, level) * ((100.0 - percent) / 100.0)
        end

        BlzEndUnitAbilityCooldown(unit, abilityId)
        SetUnitAbilityLevel(unit, abilityId, level + 1)
        BlzStartUnitAbilityCooldown(unit, abilityId, cooldown)
    end

    function AbilityMeta.startCooldown(unit, abilityId, seconds)
        local level = levelIndex(unit, abilityId)
        BlzEndUnitAbilityCooldown(unit, abilityId)
        SetUnitAbilityLevel(unit, abilityId, level + 1)
        BlzStartUnitAbilityCooldown(unit, abilityId, seconds or 0.0)
    end

    function AbilityMeta.refundManaCostPercent(unit, abilityId, percent, showEffect)
        local cost = BlzGetUnitAbilityManaCost(unit, abilityId, levelIndex(unit, abilityId))
        local refund = 0.0

        if percent < 1 then
            refund = cost * percent
        else
            refund = cost * (percent / 100.0)
        end

        if showEffect then
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\MoonWell\\MoonWellCasterArt.mdl", unit, "origin"))
        end
        SetUnitState(unit, UNIT_STATE_MANA, GetUnitState(unit, UNIT_STATE_MANA) + refund)
    end

    function AbilityMeta.setDuration(unit, abilityId, seconds)
        setReal(unit, abilityId, ABILITY_RLF_DURATION_NORMAL, seconds)
        setReal(unit, abilityId, ABILITY_RLF_DURATION_HERO, seconds)
    end

    function AbilityMeta.setManaCost(unit, abilityId, cost)
        setInt(unit, abilityId, ABILITY_ILF_MANA_COST, cost or 0)
    end

    function AbilityMeta.setAreaOfEffect(unit, abilityId, radius)
        setReal(unit, abilityId, ABILITY_RLF_AREA_OF_EFFECT, radius)
    end

    function AbilityMeta.areaOfEffect(unit, abilityId)
        return getReal(unit, abilityId, ABILITY_RLF_AREA_OF_EFFECT, 0.0)
    end

    function AbilityMeta.setCooldown(unit, abilityId, seconds)
        setReal(unit, abilityId, ABILITY_RLF_COOLDOWN, seconds)
    end

    function AbilityMeta.setCastTime(unit, abilityId, seconds)
        setReal(unit, abilityId, ABILITY_RLF_CASTING_TIME, seconds)
    end

    function AbilityMeta.setRange(unit, abilityId, range)
        setReal(unit, abilityId, ABILITY_RLF_CAST_RANGE, range)
    end

    function AbilityMeta.setRealData(unit, abilityId, value, field)
        setReal(unit, abilityId, field, value)
    end

    function AbilityMeta.refresh(unit, abilityId)
        refresh(unit, abilityId)
    end

    function AbilityMeta.addDamageBonus(unit, amount, duration, percentBased)
        local abilityId = FourCC("ABAD")
        local bonus = amount or 0

        if percentBased then
            bonus = R2I(BlzGetUnitWeaponIntegerField(unit, UNIT_WEAPON_IF_ATTACK_DAMAGE_BASE, 0) * bonus / 100.0)
        end

        if GetUnitAbilityLevel(unit, abilityId) <= 0 then
            UnitAddAbility(unit, abilityId)
            UnitMakeAbilityPermanent(unit, true, abilityId)
        end

        setInt(unit, abilityId, ABILITY_ILF_ATTACK_BONUS, BlzGetAbilityIntegerLevelField(ability(unit, abilityId), ABILITY_ILF_ATTACK_BONUS, 0) + bonus)

        if duration and duration > 0 then
            GameTimer.after(duration, function()
                if unit and GetUnitTypeId(unit) ~= 0 and GetUnitAbilityLevel(unit, abilityId) > 0 then
                    setInt(unit, abilityId, ABILITY_ILF_ATTACK_BONUS, BlzGetAbilityIntegerLevelField(ability(unit, abilityId), ABILITY_ILF_ATTACK_BONUS, 0) - bonus)
                end
            end)
        end
    end

    function AbilityMeta.addLifeBonus(unit, amount, duration, percentBased)
        local bonus = amount or 0
        local oldMax = BlzGetUnitMaxHP(unit)

        if percentBased then
            bonus = oldMax * bonus / 100.0
        end

        BlzSetUnitMaxHP(unit, R2I(oldMax + bonus))
        SetWidgetLife(unit, GetWidgetLife(unit) + bonus)

        if duration and duration > 0 then
            GameTimer.after(duration, function()
                if unit and GetUnitTypeId(unit) ~= 0 then
                    local newMax = BlzGetUnitMaxHP(unit) - bonus
                    if newMax < 1 then
                        newMax = 1
                    end
                    BlzSetUnitMaxHP(unit, R2I(newMax))
                    if GetWidgetLife(unit) > newMax then
                        SetWidgetLife(unit, newMax)
                    end
                end
            end)
        end
    end

    function AbilityMeta.addManaBonus(unit, amount, duration, percentBased)
        local bonus = amount or 0
        local oldMax = BlzGetUnitMaxMana(unit)

        if percentBased then
            bonus = oldMax * bonus / 100.0
        end

        BlzSetUnitMaxMana(unit, R2I(oldMax + bonus))
        SetUnitState(unit, UNIT_STATE_MANA, GetUnitState(unit, UNIT_STATE_MANA) + bonus)

        if duration and duration > 0 then
            GameTimer.after(duration, function()
                if unit and GetUnitTypeId(unit) ~= 0 then
                    local newMax = BlzGetUnitMaxMana(unit) - bonus
                    if newMax < 0 then
                        newMax = 0
                    end
                    BlzSetUnitMaxMana(unit, R2I(newMax))
                    if GetUnitState(unit, UNIT_STATE_MANA) > newMax then
                        SetUnitState(unit, UNIT_STATE_MANA, newMax)
                    end
                end
            end)
        end
    end

    function AbilityMeta.increaseMoveSpeedPercent(unit, duration, increase)
        local abilityId = FourCC("ABMS")
        local dummy = CreateUnit(GetOwningPlayer(unit), FourCC("e01B"), GetUnitX(unit), GetUnitY(unit), 0)
        local value = increase or 0

        if value == 0 then
            value = 10000
        elseif value > 1 or value < -1 then
            value = value / 100.0
        end

        UnitAddAbility(dummy, abilityId)
        BlzSetAbilityRealLevelField(BlzGetUnitAbility(dummy, abilityId), ABILITY_RLF_MOVEMENT_SPEED_INCREASE_PERCENT_BLO2, 0, value)
        BlzSetAbilityRealLevelField(BlzGetUnitAbility(dummy, abilityId), ABILITY_RLF_DURATION_NORMAL, 0, duration or 0)
        BlzSetAbilityRealLevelField(BlzGetUnitAbility(dummy, abilityId), ABILITY_RLF_DURATION_HERO, 0, duration or 0)
        IssueTargetOrderById(dummy, 852101, unit)
        RemoveUnit(dummy)
    end

    _G.AbilityMeta = AbilityMeta

    _G.ABMASetUnitAbilityDescription = AbilityMeta.setDescription
    _G.ABMASetUnitAbilityTitle = AbilityMeta.setTitle
    _G.ABMAUnitAddAbilityTimed = AbilityMeta.addAbilityTimed
    _G.ABMARefundCooldownPercent = AbilityMeta.refundCooldownPercent
    _G.ABMAStartAbilityCooldown = AbilityMeta.startCooldown
    _G.ABMARefundManacostPercent = AbilityMeta.refundManaCostPercent
    _G.ABMASetUnitAbilityDuration = AbilityMeta.setDuration
    _G.ABMASetUnitAbilityManacost = AbilityMeta.setManaCost
    _G.ABMASetUnitAbilityAoE = AbilityMeta.setAreaOfEffect
    _G.ABMAGetUnitAbilityAoE = AbilityMeta.areaOfEffect
    _G.ABMASetUnitAbilityCooldown = AbilityMeta.setCooldown
    _G.ABMASetUnitAbilityCastTime = AbilityMeta.setCastTime
    _G.ABMASetUnitAbilityRange = AbilityMeta.setRange
    _G.ABMASetUnitAbilityRealData = AbilityMeta.setRealData
    _G.ABMARefreshAbilityData = AbilityMeta.refresh
    _G.ABMAAddUnitDamageBonus = AbilityMeta.addDamageBonus
    _G.ABMAAddUnitLifeBonus = AbilityMeta.addLifeBonus
    _G.ABMAAddUnitManaBonus = AbilityMeta.addManaBonus
    _G.ABMAMovespeedIncreasePercent = AbilityMeta.increaseMoveSpeedPercent
end)

if Debug and Debug.endFile then Debug.endFile() end
