if Debug and Debug.beginFile then Debug.beginFile("Abilities/Titans/NoxiousAbilities") end

OnInit("NoxiousAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameTimer")
    import.strict("MissileSystem")
    import.strict("DummyCaster")
    import.strict("UnitStateSystem")
    import.strict("TitanDamageSystem")
    import.strict("TitanAbilityUtils")
    import.strict("PlayerData")

    local IDS = {
        NOXIOUS = FourCC("E00B"),
        MINION = FourCC("U001"),
        NUKEMASTER = FourCC("I08S"),
        SCOUT_TRAP = FourCC("TOTR"),
        TRAP_DUMMY = FourCC("o025"),
        TRAP_SLOW = FourCC("A08Y"),
        TRAP_EYE = FourCC("A08X"),
        POISON_BUFF = FourCC("B038"),
        NUKE = FourCC("TSAQ"),
        HEAL = FourCC("TSAE"),
        HEAL_MINI = FourCC("A08Z"),
        WW = FourCC("TSAW"),
        WW_SLOW = FourCC("A08S"),
        UNIQUE = FourCC("TSAF"),
        UNIQUE_DUMMY = FourCC("A08R"),
        ULTIMATE = FourCC("A092"),
        ULTIMATE_POISON_DUMMY = FourCC("o028"),
        MINION_NUKE = FourCC("TSNQ"),
        MINION_HEAL = FourCC("TSNE"),
        MINION_STEALTH = FourCC("A0D9"),
        MINION_ULTIMATE = FourCC("TSNF")
    }

    local ORDER_TRAP_EYE = 852570

    local TRAP_TICK = 0.25
    local TRAP_RADIUS = 235.0
    local TRAP_DURATION = 900.0
    local TRAP_TRIGGERED_LIFE = 5.0
    local TRAP_TOTAL_DAMAGE = 500.0
    local TRAP_DAMAGE_PER_LEVEL = 15.0

    local WW_TICK = 0.25
    local WW_RADIUS = 500.0
    local WW_DURATION = 10.0
    local WW_DAMAGE_PER_SECOND = 12.0

    local HEAL_TICK = 0.25
    local HEAL_RADIUS = 800.0
    local HEAL_DURATION = 5.0

    local NUKE_TICK = 0.03125
    local NUKE_TRAVEL_TIME = 0.45
    local NUKE_END_SIZE = 240.0

    local ULTIMATE_DURATION = 20.0
    local ULTIMATE_TICK = 0.4
    local ULTIMATE_DAMAGE_PER_SECOND = 25.0
    local ULTIMATE_DAMAGE_AREA = 425.0
    local ULTIMATE_POISON_INTERVAL = 1.0
    local ULTIMATE_POISON_DURATION = 5.0

    local TRAP_HIT_EFFECT = "Abilities\\Spells\\NightElf\\CorrosiveBreath\\ChimaeraAcidTargetArt.mdl"
    local TRAP_EXPLOSION_EFFECT = "war3mapImported\\NecroticBlast.mdx"
    local WW_CLOUD_EFFECT = "war3mapImported\\GreenCloudOfFog.mdx"
    local WW_HIT_EFFECT = "war3mapImported\\DebuffPoisoned.mdx"
    local NUKE_EFFECT = "war3mapImported\\NoxiousPoisonMissile.mdx"
    local HEAL_EFFECT = "war3mapImported\\NoxiousHealCloud.mdl"
    local HEAL_PERIODIC_EFFECT = "war3mapImported\\Noxious'HealSparkle.mdl"
    local ULTIMATE_TARGET_EFFECT = "Abilities\\Weapons\\PoisonSting\\PoisonStingTarget.mdl"
    local ULTIMATE_MISSILE_EFFECT = "Abilities\\Weapons\\ChimaeraAcidMissile\\ChimaeraAcidMissile.mdl"
    local UNIQUE_TARGET_EFFECT = "Abilities\\Spells\\Undead\\AntiMagicShell\\AntiMagicShell.mdl"
    local MINION_NUKE_EFFECT = "war3mapImported\\Model_Nuke(MNAQ)TargetSplash.mdx"
    local MINION_HEAL_EFFECT = "Abilities\\Spells\\Undead\\VampiricAura\\VampiricAuraTarget.mdl"

    local function isAlive(unit)
        return UnitStateSystem.isAlive(unit)
    end

    local function effectTarget(path, unit, attachPoint)
        DestroyEffect(AddSpecialEffectTarget(path, unit, attachPoint or "origin"))
    end

    local function scaleEffect(effect, scale)
        local setter = rawget(_G, "BlzSetSpecialEffectScale")
        if effect and setter then
            setter(effect, scale or 1.0)
        end
    end

    local function setEffectPosition(effect, x, y, z)
        local setter = rawget(_G, "BlzSetSpecialEffectPosition")
        if effect and setter then
            setter(effect, x, y, z or 0.0)
        end
    end

    local function setEffectYaw(effect, angle)
        local setter = rawget(_G, "BlzSetSpecialEffectYaw")
        if effect and setter then
            setter(effect, angle)
        end
    end

    local function isTitanSideUnit(unit)
        local playerData = unit and PlayerData.get(GetOwningPlayer(unit)) or nil
        return playerData and (
            playerData:class() == PlayerData.CLASS_TITAN or
            playerData:class() == PlayerData.CLASS_MINION
        )
    end

    local function isWard(unit)
        return unit and GetUnitAbilityLevel(unit, FourCC("WARD")) > 0
    end

    local function isNukable(unit, caster)
        return TitanAbilityUtils.isNukable(unit, caster)
    end

    local function isTrapTarget(unit, caster, dummy)
        return isAlive(unit) and
            IsUnitEnemy(unit, GetOwningPlayer(caster)) and
            not IsUnitType(unit, UNIT_TYPE_MAGIC_IMMUNE) and
            not IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
            not IsUnitType(unit, UNIT_TYPE_MECHANICAL) and
            not isWard(unit) and
            not isTitanSideUnit(unit) and
            unit ~= dummy and
            GetUnitTypeId(unit) ~= IDS.TRAP_DUMMY
    end

    local function isCloudTarget(unit, caster)
        return isAlive(unit) and
            (IsUnitEnemy(unit, GetOwningPlayer(caster)) or GetOwningPlayer(unit) == Player(PLAYER_NEUTRAL_PASSIVE)) and
            not IsUnitType(unit, UNIT_TYPE_MAGIC_IMMUNE) and
            not IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
            not IsUnitType(unit, UNIT_TYPE_MECHANICAL) and
            not isWard(unit)
    end

    local function isUltimateTarget(unit, caster)
        return isAlive(unit) and
            (not IsUnitAlly(unit, GetOwningPlayer(caster)) or GetOwningPlayer(unit) == Player(PLAYER_NEUTRAL_PASSIVE)) and
            (GetUnitAbilityLevel(unit, FourCC("WALL")) > 0 or not IsUnitType(unit, UNIT_TYPE_STRUCTURE))
    end

    local function isUniqueTarget(unit, caster)
        return isAlive(unit) and
            (not IsUnitAlly(unit, GetOwningPlayer(caster)) or GetOwningPlayer(unit) == Player(PLAYER_NEUTRAL_PASSIVE)) and
            (IsUnitType(unit, UNIT_TYPE_STRUCTURE) or IsUnitType(unit, UNIT_TYPE_MECHANICAL))
    end

    local function nukeDamage(level)
        if level == 1 then
            return 130.0
        elseif level == 2 then
            return 150.0
        elseif level == 3 then
            return 180.0
        end
        return 105.0 + 25.0 * level
    end

    local function castScoutTrap(caster)
        local x = GetSpellTargetX()
        local y = GetSpellTargetY()
        local level = TitanAbilityUtils.levelOrOne(caster, IDS.SCOUT_TRAP)
        local dummy = CreateUnit(GetOwningPlayer(caster), IDS.TRAP_DUMMY, x, y, bj_UNIT_FACING)
        local damagePerTick = TRAP_DAMAGE_PER_LEVEL * level * TRAP_TICK
        local damageDone = 0.0
        local triggered = false
        local cleaned = false
        local groundEffect = nil
        local timer = nil
        local durationTimer = nil

        local function cleanup(removeDummy)
            if cleaned then
                return
            end

            cleaned = true
            if groundEffect then
                DestroyEffect(groundEffect)
                groundEffect = nil
            end
            if removeDummy and dummy and GetUnitTypeId(dummy) ~= 0 then
                RemoveUnit(dummy)
            end
            if timer then
                timer:destroy()
            end
            if durationTimer then
                durationTimer:destroy()
            end
        end

        UnitAddAbility(dummy, IDS.TRAP_SLOW)
        timer = GameTimer.every(TRAP_TICK, function()
            local group = CreateGroup()
            local unit = nil

            if not isAlive(dummy) then
                DestroyGroup(group)
                cleanup(false)
                return
            end

            GroupEnumUnitsInRange(group, x, y, TRAP_RADIUS, nil)
            unit = FirstOfGroup(group)
            while unit do
                GroupRemoveUnit(group, unit)
                if damageDone < TRAP_TOTAL_DAMAGE and isTrapTarget(unit, caster, dummy) then
                    if not triggered then
                        triggered = true
                        DummyCaster.castTarget(GetOwningPlayer(caster), IDS.TRAP_EYE, 1, ORDER_TRAP_EYE, unit, x, y, bj_UNIT_FACING, 1.0)
                        groundEffect = AddSpecialEffect(TRAP_EXPLOSION_EFFECT, GetUnitX(unit), GetUnitY(unit))
                        UnitApplyTimedLife(dummy, FourCC("BTLF"), TRAP_TRIGGERED_LIFE)
                    end
                    effectTarget(TRAP_HIT_EFFECT, unit, "origin")
                    TitanDamageSystem.dealDamage(caster, unit, damagePerTick, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                    damageDone = damageDone + damagePerTick
                end
                unit = FirstOfGroup(group)
            end
            DestroyGroup(group)
        end)

        durationTimer = GameTimer.after(TRAP_DURATION, function()
            cleanup(true)
        end)
    end

    local function castNuke(caster)
        local level = TitanAbilityUtils.levelOrOne(caster, IDS.NUKE)
        local startX = GetUnitX(caster)
        local startY = GetUnitY(caster)
        local targetX = GetSpellTargetX()
        local targetY = GetSpellTargetY()
        local angle = Atan2(targetY - startY, targetX - startX)
        local distance = 600.0 + 100.0 * (level - 1)
        local speed = distance / NUKE_TRAVEL_TIME
        local traveled = 0.0
        local hit = {}
        local effect = AddSpecialEffect(NUKE_EFFECT, startX, startY)
        local timer = nil
        local damage = TitanAbilityUtils.applyNukemaster(caster, nukeDamage(level))
        local x = startX
        local y = startY

        scaleEffect(effect, 0.0)
        setEffectPosition(effect, x, y, 80.0)
        setEffectYaw(effect, angle)
        timer = GameTimer.every(NUKE_TICK, function()
            local group = CreateGroup()
            local unit = nil
            local factor = 0.0
            local collision = 0.0
            local step = speed * NUKE_TICK

            if not isAlive(caster) or traveled >= distance then
                DestroyEffect(effect)
                DestroyGroup(group)
                timer:destroy()
                return
            end

            traveled = traveled + step
            x = startX + traveled * Cos(angle)
            y = startY + traveled * Sin(angle)
            factor = traveled / distance
            collision = factor * NUKE_END_SIZE
            scaleEffect(effect, ((factor / 2.0) + 0.5) * (NUKE_END_SIZE / 140.0))
            setEffectPosition(effect, x, y, 80.0)
            setEffectYaw(effect, angle)

            GroupEnumUnitsInRange(group, x, y, collision, nil)
            unit = FirstOfGroup(group)
            while unit do
                local id = GetHandleId(unit)
                GroupRemoveUnit(group, unit)
                if not hit[id] and unit ~= caster and isNukable(unit, caster) then
                    hit[id] = true
                    effectTarget(NUKE_EFFECT, unit, "origin")
                    TitanDamageSystem.dealDamage(caster, unit, damage, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                end
                unit = FirstOfGroup(group)
            end
            DestroyGroup(group)
        end)
    end

    local function castWhirlwind(caster)
        local x = GetUnitX(caster)
        local y = GetUnitY(caster)
        local elapsed = 0.0
        local dummyCreated = false
        local cloud = AddSpecialEffect(WW_CLOUD_EFFECT, x, y)
        local timer = nil

        scaleEffect(cloud, 0.7)
        setEffectPosition(cloud, x, y, 10.0)
        timer = GameTimer.every(WW_TICK, function()
            local group = CreateGroup()
            local unit = nil
            local damage = WW_DAMAGE_PER_SECOND * WW_TICK

            elapsed = elapsed + WW_TICK
            if elapsed >= WW_DURATION then
                local cleanup = CreateGroup()
                local cleanupUnit = nil

                GroupEnumUnitsInRect(cleanup, bj_mapInitialPlayableArea, nil)
                cleanupUnit = FirstOfGroup(cleanup)
                while cleanupUnit do
                    GroupRemoveUnit(cleanup, cleanupUnit)
                    UnitRemoveAbility(cleanupUnit, IDS.POISON_BUFF)
                    cleanupUnit = FirstOfGroup(cleanup)
                end
                DestroyGroup(cleanup)
                DestroyEffect(cloud)
                DestroyGroup(group)
                timer:destroy()
                return
            end

            GroupEnumUnitsInRange(group, x, y, WW_RADIUS, nil)
            unit = FirstOfGroup(group)
            while unit do
                GroupRemoveUnit(group, unit)
                if isCloudTarget(unit, caster) then
                    if not dummyCreated then
                        local dummy = CreateUnit(GetOwningPlayer(caster), DummyCaster.unitId(), x, y, bj_UNIT_FACING)
                        UnitAddAbility(dummy, IDS.WW_SLOW)
                        UnitApplyTimedLife(dummy, FourCC("BTLF"), WW_DURATION)
                        dummyCreated = true
                    end
                    effectTarget(WW_HIT_EFFECT, unit, "origin")
                    if GetWidgetLife(unit) > damage then
                        TitanDamageSystem.dealDamage(caster, unit, damage, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                    end
                end
                unit = FirstOfGroup(group)
            end
            DestroyGroup(group)
        end)
    end

    local function healAmount(caster, abilityId, periodic)
        local level = TitanAbilityUtils.levelOrOne(caster, abilityId)
        -- Zinc used the full instant and periodic amounts for both abilities;
        -- its reduced miniHealAmountInstant field was never used by HealUnits.
        if periodic then
            return (10.0 + 20.0 * level) * HEAL_TICK
        end
        return 125.0 + 50.0 * level
    end

    local function castHeal(caster, abilityId)
        local x = GetUnitX(caster)
        local y = GetUnitY(caster)
        local elapsed = 0.0
        local timer = nil

        TitanAbilityUtils.areaHeal(caster, x, y, HEAL_RADIUS, healAmount(caster, abilityId, false), HEAL_EFFECT, function(unit)
            return isTitanSideUnit(unit) and UnitStateSystem.life(unit) < UnitStateSystem.maxLife(unit)
        end)

        timer = GameTimer.every(HEAL_TICK, function()
            elapsed = elapsed + HEAL_TICK
            if elapsed > HEAL_DURATION then
                timer:destroy()
                return
            end

            TitanAbilityUtils.areaHeal(caster, x, y, HEAL_RADIUS, healAmount(caster, abilityId, true), HEAL_PERIODIC_EFFECT, function(unit)
                return isTitanSideUnit(unit) and UnitStateSystem.life(unit) < UnitStateSystem.maxLife(unit)
            end)
        end)
    end

    local function disableTimed(unit, duration)
        if not isAlive(unit) then
            return
        end

        PauseUnit(unit, true)
        GameTimer.after(duration, function()
            if unit and GetUnitTypeId(unit) ~= 0 then
                PauseUnit(unit, false)
            end
        end)
    end

    local function castUnique(caster)
        local level = TitanAbilityUtils.levelOrOne(caster, IDS.UNIQUE)
        local x = GetSpellTargetX()
        local y = GetSpellTargetY()
        local range = 250.0 + 100.0 * level
        local duration = 4.0 * level
        local group = CreateGroup()
        local unit = nil

        GroupEnumUnitsInRange(group, x, y, range, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isUniqueTarget(unit, caster) then
                local finalDuration = duration
                local effect = AddSpecialEffect(UNIQUE_TARGET_EFFECT, GetUnitX(unit), GetUnitY(unit))
                local dummy = CreateUnit(GetOwningPlayer(caster), DummyCaster.unitId(), x, y, bj_UNIT_FACING)

                if GetUnitAbilityLevel(unit, FourCC("WALL")) > 0 then
                    finalDuration = finalDuration * 2.0
                end

                setEffectPosition(effect, GetUnitX(unit), GetUnitY(unit), 80.0)
                GameTimer.after(finalDuration, function()
                    if effect then
                        DestroyEffect(effect)
                    end
                end)

                UnitAddAbility(dummy, IDS.UNIQUE_DUMMY)
                SetUnitAbilityLevel(dummy, IDS.UNIQUE_DUMMY, level)
                UnitApplyTimedLife(dummy, FourCC("BTLF"), finalDuration)
                disableTimed(unit, finalDuration)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function castUltimate(caster)
        local elapsed = 0.0
        local poisonElapsed = 0.0
        local tickTimer = nil

        tickTimer = GameTimer.every(ULTIMATE_TICK, function()
            local group = CreateGroup()
            local unit = nil
            local x = GetUnitX(caster)
            local y = GetUnitY(caster)

            elapsed = elapsed + ULTIMATE_TICK
            poisonElapsed = poisonElapsed + ULTIMATE_TICK
            if elapsed >= ULTIMATE_DURATION or not isAlive(caster) then
                DestroyGroup(group)
                tickTimer:destroy()
                return
            end

            if GetUnitAbilityLevel(caster, FourCC("B006")) <= 0 and GetUnitAbilityLevel(caster, FourCC("BHbn")) <= 0 then
                GroupEnumUnitsInRange(group, x, y, ULTIMATE_DAMAGE_AREA, nil)
                unit = FirstOfGroup(group)
                while unit do
                    GroupRemoveUnit(group, unit)
                    if isUltimateTarget(unit, caster) then
                        MissileSystem.launch({
                            x = x,
                            y = y,
                            z = 100.0,
                            target = unit,
                            speed = 1000.0,
                            collision = 20.0,
                            model = ULTIMATE_MISSILE_EFFECT
                        })
                        effectTarget(ULTIMATE_TARGET_EFFECT, unit, "head")
                        TitanDamageSystem.dealDamage(caster, unit, ULTIMATE_DAMAGE_PER_SECOND * ULTIMATE_TICK, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                    end
                    unit = FirstOfGroup(group)
                end
            end

            if poisonElapsed >= ULTIMATE_POISON_INTERVAL then
                local poison = CreateUnit(GetOwningPlayer(caster), IDS.ULTIMATE_POISON_DUMMY, x, y, bj_UNIT_FACING)
                UnitApplyTimedLife(poison, FourCC("BTLF"), ULTIMATE_POISON_DURATION)
                poisonElapsed = 0.0
            end
            DestroyGroup(group)
        end)
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.SCOUT_TRAP then
            castScoutTrap(caster)
        elseif abilityId == IDS.NUKE then
            castNuke(caster)
        elseif abilityId == IDS.WW then
            castWhirlwind(caster)
        elseif abilityId == IDS.HEAL or abilityId == IDS.HEAL_MINI then
            castHeal(caster, abilityId)
        elseif abilityId == IDS.UNIQUE then
            castUnique(caster)
        elseif abilityId == IDS.ULTIMATE then
            castUltimate(caster)
        elseif abilityId == IDS.MINION_NUKE then
            TitanAbilityUtils.bounceNuke(caster, GetSpellTargetUnit(), {
                abilityId = IDS.MINION_NUKE,
                effect = MINION_NUKE_EFFECT,
                filter = function(unit, source)
                    return isNukable(unit, source) and IsUnitVisible(unit, GetOwningPlayer(source))
                end
            })
        elseif abilityId == IDS.MINION_HEAL then
            TitanAbilityUtils.bounceHeal(caster, caster, {
                abilityId = IDS.MINION_HEAL,
                effect = MINION_HEAL_EFFECT
            })
        elseif abilityId == IDS.MINION_ULTIMATE then
            TitanAbilityUtils.areaNuke(caster, GetSpellTargetX(), GetSpellTargetY(), 500.0, TitanAbilityUtils.applyNukemaster(caster, 300.0), ULTIMATE_TARGET_EFFECT)
        end
    end

    local trigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        i = i + 1
    end

    TriggerAddAction(trigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onSpellEffect)
        else
            onSpellEffect()
        end
    end)

    AbilityRegistry.registerRace("Noxious", "titan", {
        notes = "Noxious abilities ported from NoxiousTrap, NoxiousNuke, NoxiousWW, NoxiousHeal, NoxiousUltimate and Noxious minion generic abilities.",
        abilities = {
            {
                name = "Noxious Trap",
                id = IDS.SCOUT_TRAP,
                source = "library NoxiousTrap",
                behavior = "Places the old long-lived poison trap dummy. The first valid defender trigger receives the eye cast and starts the trap's poison damage."
            },
            {
                name = "Noxious Nuke",
                id = IDS.NUKE,
                source = "library NoxiousNuke",
                behavior = "Launches a growing poison wave for 600/700/800 range, damaging valid enemies including enemies in fog through TitanDamageSystem."
            },
            {
                name = "Noxious Whirlwind",
                id = IDS.WW,
                source = "library NoxiousWW",
                behavior = "Creates the old green poison cloud at Noxious' position for 10 seconds, damaging valid nearby organic enemies."
            },
            {
                name = "Noxious Heal",
                id = IDS.HEAL,
                source = "library NoxiousHeal",
                behavior = "Instantly heals titan-side units in 800 AoE, then applies periodic healing for 5 seconds through UnitStateSystem."
            },
            {
                name = "Noxious Unique",
                id = IDS.UNIQUE,
                source = "library SypheriousUltimate",
                behavior = "Disables nearby enemy/neutral structures and mechanical units around the target point, doubled duration on walls, and spawns the old armor-reduction dummy aura."
            },
            {
                name = "Noxious Ultimate",
                id = IDS.ULTIMATE,
                source = "library NoxiousUltimate",
                behavior = "For 20 seconds, fires poison missiles at nearby valid enemies and leaves temporary poison dummy clouds behind."
            },
            {
                name = "Noxious Minion Nuke",
                id = IDS.MINION_NUKE,
                source = "library SypheriousNukeMinion",
                behavior = "Bounces poison splash damage between visible valid targets."
            },
            {
                name = "Noxious Minion Heal",
                id = IDS.MINION_HEAL,
                source = "library SypheriousHealMinion",
                behavior = "Bounces healing between allied wounded units."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
