if Debug and Debug.beginFile then Debug.beginFile("Abilities/Titans/LucidiousAbilities") end

OnInit("LucidiousAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameTimer")
    import.strict("DummyCaster")
    import.strict("UnitStateSystem")
    import.strict("TitanDamageSystem")
    import.strict("TitanAbilityUtils")
    import.strict("AbilityMeta")

    local IDS = {
        LUCIDIOUS = FourCC("E01D"),
        MINION = FourCC("U016"),
        NUKEMASTER = FourCC("I08S"),
        CLOUD_REFLECTION = FourCC("A095"),
        CLOUD_REFLECTION_DUMMY = FourCC("TLAD"),
        NUKE = FourCC("TLAQ"),
        HEAL = FourCC("TLAE"),
        UNIQUE = FourCC("TLAR"),
        TIDAL_STRIKE_COUNTER = FourCC("TLDR"),
        HASTE = FourCC("A098"),
        ULTIMATE = FourCC("TLAF"),
        ULTIMATE_BUFF = FourCC("B004"),
        MINION_NUKE = FourCC("TLNQ"),
        MINION_HEAL = FourCC("TLNE"),
        MINION_STEALTH = FourCC("TLNW"),
        MINION_ULTIMATE = FourCC("TLNF")
    }

    local ORDER_CLOUD_REFLECTION = 852122
    local ORDER_HASTE = 852189

    local NAGA_EFFECT = "Objects\\Spawnmodels\\Naga\\NagaDeath\\NagaDeath.mdl"
    local HEAL_EFFECT = "Abilities\\Spells\\Other\\CrushingWave\\CrushingWaveDamage.mdl"

    local CLOUD_DISTANCE = 7500.0
    local CLOUD_AOE = 850.0
    local CLOUD_LEVEL_DISTANCE = 550.0

    local UNIQUE_WATER_CHECK_INTERVAL = 0.5
    local TIDAL_STRIKE_DAMAGE_PER_LEVEL = 25.0
    local TIDAL_STRIKE_MAX_STACK = 6

    local ULTIMATE_TICK = 0.25
    local ULTIMATE_DAMAGE_PER_SECOND = 80.0
    local ULTIMATE_DAMAGE_AREA = 235.0
    local ULTIMATE_MANA_COST_PERCENT = 0.0075

    local waterState = {}
    local waterTimers = {}
    local ultimateTimers = {}
    local suppressDamage = false

    local function isAlive(unit)
        return UnitStateSystem.isAlive(unit)
    end

    local function isNukable(unit, caster)
        return TitanAbilityUtils.isNukable(unit, caster) and IsUnitVisible(unit, GetOwningPlayer(caster))
    end

    local function isHealable(unit, caster)
        return TitanAbilityUtils.isHealable(unit, caster)
    end

    local function effectAt(path, x, y)
        DestroyEffect(AddSpecialEffect(path, x, y))
    end

    local function distanceBetween(x1, y1, x2, y2)
        local dx = x2 - x1
        local dy = y2 - y1
        return SquareRoot(dx * dx + dy * dy)
    end

    local function isShallowWater(x, y)
        local bjPathable = rawget(_G, "IsTerrainPathableBJ")
        local nativePathable = rawget(_G, "IsTerrainPathable")
        local loc = nil
        local result = false

        if bjPathable then
            loc = Location(x, y)
            result = bjPathable(loc, PATHING_TYPE_FLOATABILITY) == false
            RemoveLocation(loc)
            return result
        end

        if nativePathable then
            return nativePathable(x, y, PATHING_TYPE_FLOATABILITY) == false
        end

        return false
    end

    local function updateUniqueTooltip(unit)
        local uniqueLevel = GetUnitAbilityLevel(unit, IDS.UNIQUE)
        local heroLevel = GetHeroLevel(unit)
        local damage = R2I(heroLevel * TIDAL_STRIKE_DAMAGE_PER_LEVEL)
        local pureDamage = R2I((heroLevel * 0.05) * damage)

        if uniqueLevel > 0 then
            AbilityMeta.setDescription(IDS.UNIQUE,
                "|cff80c0e0Leaving shallow water grants Lucidious |r15%|cff80c0e0 bonus movement speed for |r5.00|cff80c0e0 second.|n|nEvery |rsixth|cff80c0e0 attack against enemy structures deals |r" ..
                I2S(damage) .. "|cff80c0e0 bonus damage.",
                1
            )
            AbilityMeta.setDescription(IDS.UNIQUE,
                "|cff80c0e0Leaving shallow water grants Lucidious |r15%|cff80c0e0 bonus movement speed for |r5.00|cff80c0e0 second.|n|nEvery |rsixth|cff80c0e0 attack against enemy structures deals |r" ..
                I2S(damage) .. "|cff80c0e0 bonus damage, of which |r" .. I2S(pureDamage) .. "|cff80c0e0 is |rpure damage|cff80c0e0.",
                2
            )
        end
    end

    local function startWaterWatcher(unit)
        local id = GetHandleId(unit)

        if waterTimers[id] then
            return
        end

        UnitAddAbility(unit, IDS.TIDAL_STRIKE_COUNTER)
        waterState[id] = isShallowWater(GetUnitX(unit), GetUnitY(unit))
        waterTimers[id] = GameTimer.every(UNIQUE_WATER_CHECK_INTERVAL, function()
            local inShallow = false
            local wasShallow = waterState[id] == true

            if not isAlive(unit) or GetUnitAbilityLevel(unit, IDS.UNIQUE) <= 0 then
                if waterTimers[id] then
                    waterTimers[id]:destroy()
                    waterTimers[id] = nil
                end
                waterState[id] = nil
                return
            end

            inShallow = isShallowWater(GetUnitX(unit), GetUnitY(unit))
            if wasShallow and not inShallow then
                DummyCaster.castTarget(GetOwningPlayer(unit), IDS.HASTE, GetUnitAbilityLevel(unit, IDS.UNIQUE), ORDER_HASTE, unit, GetUnitX(unit), GetUnitY(unit), GetUnitFacing(unit), 1.0)
            end
            waterState[id] = inShallow
        end)
    end

    local function castCloudReflection(caster)
        local casterX = GetUnitX(caster)
        local casterY = GetUnitY(caster)
        local targetX = GetSpellTargetX()
        local targetY = GetSpellTargetY()
        local angle = bj_RADTODEG * Atan2(targetY - casterY, targetX - casterX)
        local distance = CLOUD_AOE
        local maxDistance = CLOUD_DISTANCE + CLOUD_LEVEL_DISTANCE * GetHeroLevel(caster)

        while distance < maxDistance do
            local x = casterX + distance * Cos(angle * bj_DEGTORAD)
            local y = casterY + distance * Sin(angle * bj_DEGTORAD)

            if -12000.0 < x and x < 12000.0 and -12000.0 < y and y < 12000.0 then
                DummyCaster.castPoint(GetOwningPlayer(caster), IDS.CLOUD_REFLECTION_DUMMY, 1, ORDER_CLOUD_REFLECTION, x, y, casterX, casterY, GetUnitFacing(caster), 1.0)
                distance = distance + CLOUD_AOE
            else
                distance = maxDistance
            end
        end
    end

    local function castBounceNuke(caster, firstTarget, abilityId)
        TitanAbilityUtils.bounceNuke(caster, firstTarget, {
            abilityId = abilityId,
            effect = NAGA_EFFECT,
            targetEffect = true,
            effectAttachPoint = "origin",
            chainEffect = false,
            filter = isNukable
        })
    end

    local function castBounceHeal(caster, abilityId, effect)
        TitanAbilityUtils.bounceHeal(caster, caster, {
            abilityId = abilityId,
            effect = effect or NAGA_EFFECT,
            filter = isHealable
        })
    end

    local function isUltimateTarget(unit, caster)
        return isAlive(unit) and
            (not IsUnitAlly(unit, GetOwningPlayer(caster)) or GetOwningPlayer(unit) == Player(PLAYER_NEUTRAL_PASSIVE)) and
            (IsUnitType(unit, UNIT_TYPE_STRUCTURE) or IsUnitType(unit, UNIT_TYPE_MECHANICAL))
    end

    local function stopUltimate(caster, outOfMana)
        local id = GetHandleId(caster)

        if ultimateTimers[id] then
            ultimateTimers[id]:destroy()
            ultimateTimers[id] = nil
        end
        if caster and GetUnitTypeId(caster) ~= 0 then
            if outOfMana then
                SetUnitState(caster, UNIT_STATE_MANA, 0.0)
                IssueImmediateOrder(caster, "unimmolation")
                AbilityMeta.startCooldown(caster, IDS.ULTIMATE, 15.0)
            end
        end
    end

    local function castUltimate(caster)
        local id = GetHandleId(caster)
        local elapsed = 0.0

        if ultimateTimers[id] then
            ultimateTimers[id]:destroy()
        end

        ultimateTimers[id] = GameTimer.every(ULTIMATE_TICK, function()
            local group = CreateGroup()
            local unit = nil
            local ratioDamage = 0.0
            local damage = 0.0
            local manaCost = 0.0

            elapsed = elapsed + ULTIMATE_TICK
            if not isAlive(caster) or (elapsed > 0.5 and GetUnitAbilityLevel(caster, IDS.ULTIMATE_BUFF) <= 0) then
                DestroyGroup(group)
                stopUltimate(caster, false)
                return
            end

            if GetUnitAbilityLevel(caster, FourCC("B04A")) <= 0 and
                GetUnitAbilityLevel(caster, FourCC("BOwk")) <= 0 and
                GetUnitAbilityLevel(caster, FourCC("B07M")) <= 0 and
                GetUnitAbilityLevel(caster, FourCC("B063")) <= 0 then
                local maxLife = UnitStateSystem.maxLife(caster)
                if maxLife <= 0.0 then
                    maxLife = 1.0
                end
                ratioDamage = 1.0 + (1.0 - (UnitStateSystem.life(caster) / maxLife))
                if ratioDamage > 1.67 then
                    ratioDamage = 1.67
                end

                damage = ULTIMATE_DAMAGE_PER_SECOND * ratioDamage * ULTIMATE_TICK
                manaCost = UnitStateSystem.maxMana(caster) * ULTIMATE_MANA_COST_PERCENT
                if UnitStateSystem.mana(caster) <= manaCost then
                    DestroyGroup(group)
                    stopUltimate(caster, true)
                    return
                end

                UnitStateSystem.addMana(caster, -manaCost)
                GroupEnumUnitsInRange(group, GetUnitX(caster), GetUnitY(caster), ULTIMATE_DAMAGE_AREA, nil)
                unit = FirstOfGroup(group)
                while unit do
                    GroupRemoveUnit(group, unit)
                    if isUltimateTarget(unit, caster) then
                        TitanDamageSystem.dealDamage(caster, unit, damage, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                        effectAt(NAGA_EFFECT, GetUnitX(unit), GetUnitY(unit))
                    end
                    unit = FirstOfGroup(group)
                end
            end

            DestroyGroup(group)
        end)
    end

    local function onTidalStrikeDamage()
        local attacker = GetEventDamageSource()
        local target = GetTriggerUnit()
        local counterLevel = attacker and GetUnitAbilityLevel(attacker, IDS.TIDAL_STRIKE_COUNTER) or 0
        local uniqueLevel = attacker and GetUnitAbilityLevel(attacker, IDS.UNIQUE) or 0

        if suppressDamage or not attacker or not target or uniqueLevel <= 0 then
            return
        end
        if not rawget(_G, "BlzGetEventDamageType") or BlzGetEventDamageType() ~= DAMAGE_TYPE_NORMAL then
            return
        end
        if not IsUnitType(target, UNIT_TYPE_STRUCTURE) then
            return
        end
        if counterLevel <= 0 then
            UnitAddAbility(attacker, IDS.TIDAL_STRIKE_COUNTER)
            counterLevel = 1
        end

        if counterLevel >= TIDAL_STRIKE_MAX_STACK then
            local heroLevel = GetHeroLevel(attacker)
            local total = heroLevel * TIDAL_STRIKE_DAMAGE_PER_LEVEL
            local universal = 0.0
            local normal = total

            SetUnitAbilityLevel(attacker, IDS.TIDAL_STRIKE_COUNTER, 1)
            if uniqueLevel >= 2 then
                local fraction = heroLevel / 20.0
                if fraction < 0.0 then fraction = 0.0 end
                if fraction > 1.0 then fraction = 1.0 end
                universal = total * fraction
                normal = total - universal
            end

            suppressDamage = true
            if universal > 0.0 then
                TitanDamageSystem.dealDamage(attacker, target, universal, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
            end
            if normal > 0.0 then
                TitanDamageSystem.dealDamage(attacker, target, normal, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
            end
            suppressDamage = false
            effectAt(NAGA_EFFECT, GetUnitX(target), GetUnitY(target))
        else
            SetUnitAbilityLevel(attacker, IDS.TIDAL_STRIKE_COUNTER, counterLevel + 1)
        end
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.CLOUD_REFLECTION then
            castCloudReflection(caster)
        elseif abilityId == IDS.NUKE then
            castBounceNuke(caster, GetSpellTargetUnit(), IDS.NUKE)
        elseif abilityId == IDS.HEAL then
            castBounceHeal(caster, IDS.HEAL, NAGA_EFFECT)
        elseif abilityId == IDS.ULTIMATE then
            castUltimate(caster)
        elseif abilityId == IDS.MINION_NUKE then
            castBounceNuke(caster, GetSpellTargetUnit(), IDS.MINION_NUKE)
        elseif abilityId == IDS.MINION_HEAL then
            castBounceHeal(caster, IDS.MINION_HEAL, HEAL_EFFECT)
        elseif abilityId == IDS.MINION_ULTIMATE then
            castBounceNuke(caster, GetSpellTargetUnit(), IDS.MINION_ULTIMATE)
        end
    end

    local function onHeroSkill()
        local unit = GetTriggerUnit()
        if GetLearnedSkill() == IDS.UNIQUE then
            startWaterWatcher(unit)
            updateUniqueTooltip(unit)
        end
    end

    local function onHeroLevel()
        updateUniqueTooltip(GetTriggerUnit())
    end

    local spellTrigger = CreateTrigger()
    local skillTrigger = CreateTrigger()
    local levelTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(skillTrigger, Player(i), EVENT_PLAYER_HERO_SKILL, nil)
        TriggerRegisterPlayerUnitEvent(levelTrigger, Player(i), EVENT_PLAYER_HERO_LEVEL, nil)
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
    TriggerAddAction(skillTrigger, function() guarded(onHeroSkill) end)
    TriggerAddAction(levelTrigger, function() guarded(onHeroLevel) end)
    TriggerAddAction(damageTrigger, function() guarded(onTidalStrikeDamage) end)

    AbilityRegistry.registerRace("Lucidious", "titan", {
        notes = "Lucidious abilities ported from LucidiousNuke, LucidiousHealNew, LucidiousUnique, LucidiousTidalStrike, CloudReflection, LucidiousUltimate, LucidiousNukeMinion and LucidiousHealMinion.",
        abilities = {
            {
                name = "Cloud Reflection",
                id = IDS.CLOUD_REFLECTION,
                source = "library CloudReflection",
                behavior = "Casts reflection dummies every 850 range along a long line from Lucidious toward the target point."
            },
            {
                name = "Lucidious Nuke",
                id = IDS.NUKE,
                source = "library LucidiousNuke",
                behavior = "Bounces magic damage between visible valid targets using TitanDamageSystem."
            },
            {
                name = "Lucidious Heal",
                id = IDS.HEAL,
                source = "library LucidiousHealNew",
                behavior = "Bounces healing between wounded allied units using UnitStateSystem."
            },
            {
                name = "Lucidious Unique",
                id = IDS.UNIQUE,
                source = "library LucidiousUnique and LucidiousTidalStrike",
                behavior = "Leaving shallow water grants haste; every sixth normal attack against structures triggers Tidal Strike bonus damage."
            },
            {
                name = "Lucidious Ultimate",
                id = IDS.ULTIMATE,
                source = "library LucidiousUltimate",
                behavior = "While active, drains mana and damages enemy structures/mechanicals around Lucidious; damage scales with missing health."
            },
            {
                name = "Lucidious Minion Nuke",
                id = IDS.MINION_NUKE,
                source = "library LucidiousNukeMinion",
                behavior = "Bounces Lucidious-style magic damage between visible valid targets."
            },
            {
                name = "Lucidious Minion Heal",
                id = IDS.MINION_HEAL,
                source = "library LucidiousHealMinion",
                behavior = "Bounces healing between wounded allies."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
