if Debug and Debug.beginFile then Debug.beginFile("Abilities/Titans/VoltronAbilities") end

OnInit("VoltronAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameTimer")
    import.strict("MissileSystem")
    import.strict("DummyCaster")
    import.strict("UnitStateSystem")
    import.strict("TitanDamageSystem")
    import.strict("TitanAbilityUtils")
    import.strict("AbilityMeta")
    import.strict("PlayerData")

    local IDS = {
        VOLTRON = FourCC("E00K"),
        MINION = FourCC("U00L"),
        NUKE = FourCC("TVAQ"),
        HEAL = FourCC("A07Y"),
        STEALTH = FourCC("TVA0"),
        STEALTH_LEARN = FourCC("TVAW"),
        UNIQUE = FourCC("TVAR"),
        PASSIVE_ATTACK = FourCC("TVAS"),
        ULTIMATE = FourCC("TVAF"),
        DISCHARGE_SCOUT = FourCC("TVAD"),
        DISCHARGE_DUMMY = FourCC("A0NH"),
        DISCHARGE_BUFF = FourCC("B077"),
        ULTIMATE_ATTACK_SPEED = FourCC("TVA1"),
        ULTIMATE_ATTACK_SPEED_BUFF = FourCC("B034"),
        FADED_STRUCTURE = FourCC("e016"),
        MINION_NUKE = FourCC("TVNQ"),
        MINION_HEAL = FourCC("TVNE"),
        MINION_STEALTH = FourCC("TVNW"),
        MINION_ULTIMATE = FourCC("TVNF")
    }

    local ORDER_DISCHARGE = 852066
    local ORDER_ULTIMATE_POINT = 852525

    local NUKE_EFFECT = "war3mapImported\\LightningSphere_FX.mdx"
    local NUKE_MISSILE_EFFECT = "war3mapImported\\OrbOfLightning.mdx"
    local HEAL_MARK_EFFECT = "Abilities\\Spells\\Orc\\LightningShield\\LightningShieldTarget.mdx"
    local HEAL_EFFECT = "Abilities\\Spells\\Other\\Monsoon\\MonsoonBoltTarget.mdl"
    local MINION_HEAL_EFFECT = "Abilities\\Spells\\Orc\\FeralSpirit\\feralspirittarget.mdl"
    local ULTIMATE_FADED_EFFECT = "Abilities\\Spells\\Other\\Monsoon\\MonsoonBoltTarget.mdl"
    local MINION_ULTIMATE_EFFECT = "Abilities\\Spells\\Orc\\Purge\\PurgeBuffTarget.mdl"

    local NUKE_RANGE = 220.0
    local NUKE_DELAY = 0.10

    local UNIQUE_BOUNCE_AOE = 250.0
    local UNIQUE_BOUNCE_DELAY = 0.20

    local HEAL_MARK_DURATION = 23.0
    local HEAL_TRIGGER_RADIUS = 200.0
    local HEAL_RADIUS = 500.0
    local HEAL_TICK = 0.5

    local ULTIMATE_FADED_AOE = 1500.0

    local MINION_NUKE_DISTANCE = 650.0
    local MINION_NUKE_CONE_DEGREES = 35.0
    local activeHealMarks = {}

    local function isAlive(unit)
        return UnitStateSystem.isAlive(unit)
    end

    local function isTitanSideUnit(unit)
        local playerData = unit and PlayerData.get(GetOwningPlayer(unit)) or nil
        return playerData and (
            playerData:class() == PlayerData.CLASS_TITAN or
            playerData:class() == PlayerData.CLASS_MINION
        )
    end

    local function effectAt(path, x, y, scale)
        TitanAbilityUtils.effectAt(path, x, y, scale or 1.0)
    end

    local function effectTarget(path, unit, attachPoint)
        DestroyEffect(AddSpecialEffectTarget(path, unit, attachPoint or "origin"))
    end

    local function isWall(unit)
        return unit and GetUnitAbilityLevel(unit, FourCC("WALL")) > 0
    end

    local function isNukable(unit, caster)
        return TitanAbilityUtils.isNukable(unit, caster)
    end

    local function isHealable(unit, caster)
        return TitanAbilityUtils.isHealable(unit, caster)
    end

    local function stealthLevelForHero(unit)
        local level = R2I(GetHeroLevel(unit) / 2.0)
        if level < 1 then
            level = 1
        elseif level > 6 then
            level = 6
        end
        return level
    end

    local function syncLevelScaledAbilities(unit)
        local level = stealthLevelForHero(unit)
        if GetUnitAbilityLevel(unit, IDS.STEALTH) > 0 then
            SetUnitAbilityLevel(unit, IDS.STEALTH, level)
        end
        if GetUnitAbilityLevel(unit, IDS.DISCHARGE_SCOUT) > 0 then
            SetUnitAbilityLevel(unit, IDS.DISCHARGE_SCOUT, level)
        end
    end

    local function castDischarge(caster, level)
        -- Use the shared caster preparation (mana, cooldown and positioning)
        -- so the Discharge buff can be applied reliably before the next hit.
        DummyCaster.castTarget(GetOwningPlayer(caster), IDS.DISCHARGE_DUMMY,
            level or 1, ORDER_DISCHARGE, caster,
            GetUnitX(caster), GetUnitY(caster), 0.0, 2.0)
    end

    local function castNuke(caster, firstTarget, abilityId)
        local level = TitanAbilityUtils.levelOrOne(caster, abilityId)
        TitanAbilityUtils.bounceNuke(caster, firstTarget, {
            abilityId = abilityId,
            effect = NUKE_EFFECT,
            missileEffect = NUKE_MISSILE_EFFECT,
            missileSpeed = 900.0,
            missileTerrainRelative = true,
            missileTargetZ = 40.0,
            chainEffect = false,
            range = NUKE_RANGE,
            delay = NUKE_DELAY,
            bounces = 3 + level * 3,
            filter = function(unit, source)
                return isNukable(unit, source) and IsUnitVisible(unit, GetOwningPlayer(source))
            end
        })
    end

    local function stealMana(target, attacker)
        local level = GetUnitAbilityLevel(attacker, IDS.UNIQUE)
        local maxMana = UnitStateSystem.maxMana(target)
        local currentMana = UnitStateSystem.mana(target)
        local drain = 0.0

        if level <= 0 or maxMana <= 10.0 or currentMana <= 0.0 then
            return
        end

        drain = GetHeroLevel(attacker) * 2.0 * level
        UnitStateSystem.addMana(target, -drain)
    end

    local function closestWallAround(source, x, y, hit)
        local group = CreateGroup()
        local unit = nil
        local best = nil
        local bestDistance = UNIQUE_BOUNCE_AOE + 1.0

        GroupEnumUnitsInRange(group, x, y, UNIQUE_BOUNCE_AOE, nil)
        unit = FirstOfGroup(group)
        while unit do
            local distance = 0.0
            GroupRemoveUnit(group, unit)
            if not hit[GetHandleId(unit)] and isWall(unit) and IsUnitEnemy(unit, GetOwningPlayer(source)) then
                local dx = GetUnitX(unit) - x
                local dy = GetUnitY(unit) - y
                distance = SquareRoot(dx * dx + dy * dy)
                if distance < bestDistance then
                    bestDistance = distance
                    best = unit
                end
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        return best
    end

    local function removeDischargeBuff(unit)
        UnitRemoveAbility(unit, IDS.DISCHARGE_BUFF)
    end

    local function startWallBounce(target, attacker, baseDamage)
        local level = GetUnitAbilityLevel(attacker, IDS.UNIQUE)
        local bounceAmount = 1 + level
        local damageAmount = baseDamage * (0.10 * level)
        local current = target
        local hit = {}
        local count = 0

        if GetUnitAbilityLevel(attacker, IDS.DISCHARGE_BUFF) > 0 then
            damageAmount = damageAmount + (20.0 + GetUnitAbilityLevel(attacker, IDS.STEALTH) * 15.0)
            removeDischargeBuff(attacker)
        end

        local function step()
            if not current or count >= bounceAmount then
                return
            end

            hit[GetHandleId(current)] = true
            effectAt(NUKE_EFFECT, GetUnitX(current), GetUnitY(current), 1.0)
            if damageAmount > 0.0 then
                TitanDamageSystem.dealDamage(attacker, current, damageAmount, ATTACK_TYPE_CHAOS, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
            end
            count = count + 1
            current = closestWallAround(attacker, GetUnitX(current), GetUnitY(current), hit)
            if current and count < bounceAmount then
                GameTimer.after(UNIQUE_BOUNCE_DELAY, step)
            end
        end

        step()
    end

    local function castHealMark(caster)
        local x = GetUnitX(caster)
        local y = GetUnitY(caster)
        local casterId = GetHandleId(caster)
        local level = TitanAbilityUtils.levelOrOne(caster, IDS.HEAL)
        local primaryHeal = 200.0 + 200.0 * level
        local allyHeal = 100.0 + 100.0 * level
        local elapsed = 0.0
        local effect = nil
        local timer = nil
        local finished = false

        if activeHealMarks[casterId] then
            return
        end
        activeHealMarks[casterId] = true
        effect = AddSpecialEffect(HEAL_MARK_EFFECT, x, y)
        local setEffectPosition = rawget(_G, "BlzSetSpecialEffectPosition")
        if setEffectPosition then
            local point = Location(x, y)
            setEffectPosition(effect, x, y, GetLocationZ(point) + 40.0)
            RemoveLocation(point)
        end

        local function cleanup()
            if finished then
                return
            end
            finished = true
            if effect then
                DestroyEffect(effect)
            end
            if timer then
                timer:destroy()
            end
            activeHealMarks[casterId] = nil
        end

        timer = GameTimer.every(HEAL_TICK, function()
            local triggerGroup = CreateGroup()
            local unit = nil

            elapsed = elapsed + HEAL_TICK
            if elapsed >= HEAL_MARK_DURATION then
                DestroyGroup(triggerGroup)
                cleanup()
                return
            end

            GroupEnumUnitsInRange(triggerGroup, x, y, HEAL_TRIGGER_RADIUS, nil)
            unit = FirstOfGroup(triggerGroup)
            while unit do
                GroupRemoveUnit(triggerGroup, unit)
                if GetUnitAbilityLevel(unit, IDS.DISCHARGE_BUFF) > 0 then
                    local healGroup = CreateGroup()
                    local target = nil
                    GroupEnumUnitsInRange(healGroup, x, y, HEAL_RADIUS, nil)
                    target = FirstOfGroup(healGroup)
                    while target do
                        GroupRemoveUnit(healGroup, target)
                        if isTitanSideUnit(target) then
                            UnitStateSystem.heal(target, target == unit and primaryHeal or allyHeal, {
                                effect = HEAL_EFFECT,
                                attachPoint = "origin"
                            })
                        end
                        target = FirstOfGroup(healGroup)
                    end
                    DestroyGroup(healGroup)
                    DestroyGroup(triggerGroup)
                    cleanup()
                    return
                end
                unit = FirstOfGroup(triggerGroup)
            end
            DestroyGroup(triggerGroup)
        end)
    end

    local function pointInCone(baseX, baseY, angle, delta, x, y)
        local posAngle = Atan2(y - baseY, x - baseX) * bj_RADTODEG
        local diff = posAngle - angle
        if diff < 0.0 then
            diff = -diff
        end
        if diff > 180.0 then
            diff = 360.0 - diff
        end
        return diff <= delta
    end

    local function fireMinionNukeMissile(caster, target, damage)
        MissileSystem.launch({
            x = GetUnitX(caster),
            y = GetUnitY(caster),
            z = 80.0,
            targetZ = 40.0,
            terrainRelative = true,
            target = target,
            speed = 1100.0,
            collision = 30.0,
            model = NUKE_MISSILE_EFFECT,
            onImpact = function(impactTarget)
                if impactTarget and isNukable(impactTarget, caster) then
                    effectTarget(NUKE_EFFECT, impactTarget, "chest")
                    TitanDamageSystem.dealDamage(caster, impactTarget, damage, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                end
            end
        })
    end

    local function castMinionNuke(caster)
        local target = GetSpellTargetUnit()
        local targetX = GetSpellTargetX()
        local targetY = GetSpellTargetY()
        local castX = GetUnitX(caster)
        local castY = GetUnitY(caster)
        local angle = Atan2(targetY - castY, targetX - castX) * bj_RADTODEG
        local damage = TitanAbilityUtils.standardNukeDamage(caster, IDS.MINION_NUKE)
        local group = CreateGroup()
        local unit = nil
        local fired = {}

        if target and isNukable(target, caster) then
            fired[GetHandleId(target)] = true
            fireMinionNukeMissile(caster, target, damage)
        end

        GroupEnumUnitsInRange(group, castX, castY, MINION_NUKE_DISTANCE, nil)
        unit = FirstOfGroup(group)
        while unit do
            local id = GetHandleId(unit)
            GroupRemoveUnit(group, unit)
            if not fired[id] and isNukable(unit, caster) and pointInCone(castX, castY, angle, MINION_NUKE_CONE_DEGREES, GetUnitX(unit), GetUnitY(unit)) then
                fired[id] = true
                fireMinionNukeMissile(caster, unit, damage)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function castUltimate(caster)
        AbilityMeta.addAbilityTimed(caster, IDS.ULTIMATE_ATTACK_SPEED, 5.0, IDS.ULTIMATE_ATTACK_SPEED_BUFF)
        castDischarge(caster, 7)
    end

    local function handleUltimatePointOrder()
        local caster = GetTriggerUnit()
        local x = GetOrderPointX()
        local y = GetOrderPointY()
        local group = nil
        local unit = nil
        local found = false

        if GetIssuedOrderId() ~= ORDER_ULTIMATE_POINT then
            return
        end

        group = CreateGroup()
        GroupEnumUnitsInRange(group, x, y, ULTIMATE_FADED_AOE, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if GetUnitTypeId(unit) == IDS.FADED_STRUCTURE then
                found = true
                TitanDamageSystem.dealDamage(caster, unit, 1.0, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)

        if found then
            effectAt(ULTIMATE_FADED_EFFECT, x, y, 1.0)
        elseif GetUnitAbilityLevel(caster, IDS.ULTIMATE) > 1 then
            SetUnitAbilityLevel(caster, IDS.ULTIMATE, 1)
        end
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.NUKE then
            castNuke(caster, GetSpellTargetUnit(), IDS.NUKE)
        elseif abilityId == IDS.HEAL then
            castHealMark(caster)
        elseif abilityId == IDS.STEALTH or abilityId == IDS.MINION_STEALTH then
            castDischarge(caster, GetUnitAbilityLevel(caster, abilityId))
        elseif abilityId == IDS.ULTIMATE then
            castUltimate(caster)
        elseif abilityId == IDS.MINION_NUKE then
            castMinionNuke(caster)
        elseif abilityId == IDS.MINION_HEAL then
            TitanAbilityUtils.bounceHeal(caster, caster, {
                abilityId = IDS.MINION_HEAL,
                effect = MINION_HEAL_EFFECT,
                filter = isHealable
            })
        elseif abilityId == IDS.MINION_ULTIMATE then
            TitanAbilityUtils.areaNuke(caster, GetSpellTargetX(), GetSpellTargetY(), 500.0, TitanAbilityUtils.applyNukemaster(caster, 300.0), MINION_ULTIMATE_EFFECT)
        end
    end

    local function onHeroSkill()
        local getLearningUnit = rawget(_G, "GetLearningUnit")
        local unit = getLearningUnit and getLearningUnit() or GetTriggerUnit()
        if not unit then
            return
        end

        if GetLearnedSkill() == IDS.STEALTH_LEARN then
            if GetUnitAbilityLevel(unit, IDS.STEALTH) <= 0 then
                UnitAddAbility(unit, IDS.STEALTH)
            end
            syncLevelScaledAbilities(unit)
        end
    end

    local function onHeroLevel()
        syncLevelScaledAbilities(GetLevelingUnit())
    end

    local function onDamaged()
        local attacker = GetEventDamageSource()
        local target = GetTriggerUnit()
        local damage = GetEventDamage()

        if not attacker or not target or damage <= 0.0 then
            return
        end
        if not rawget(_G, "BlzGetEventDamageType") or BlzGetEventDamageType() ~= DAMAGE_TYPE_NORMAL then
            return
        end
        -- The learned passive and Discharge buff are sufficient to identify
        -- these effects even if the unit lacks the auxiliary TVAS ability.
        if GetUnitAbilityLevel(attacker, IDS.PASSIVE_ATTACK) <= 0 and
            GetUnitAbilityLevel(attacker, IDS.UNIQUE) <= 0 and
            GetUnitAbilityLevel(attacker, IDS.DISCHARGE_BUFF) <= 0 then
            return
        end

        if isWall(target) then
            if GetUnitAbilityLevel(attacker, IDS.UNIQUE) > 0 or GetUnitAbilityLevel(attacker, IDS.DISCHARGE_BUFF) > 0 then
                startWallBounce(target, attacker, damage)
            end
        else
            stealMana(target, attacker)
        end
    end

    local spellTrigger = CreateTrigger()
    local skillTrigger = CreateTrigger()
    local levelTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local orderTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(skillTrigger, Player(i), EVENT_PLAYER_HERO_SKILL, nil)
        TriggerRegisterPlayerUnitEvent(levelTrigger, Player(i), EVENT_PLAYER_HERO_LEVEL, nil)
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        TriggerRegisterPlayerUnitEvent(orderTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER, nil)
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
    TriggerAddAction(damageTrigger, function() guarded(onDamaged) end)
    TriggerAddAction(orderTrigger, function() guarded(handleUltimatePointOrder) end)

    AbilityRegistry.registerRace("Voltron", "titan", {
        notes = "Voltron abilities ported from Voltron, VoltronDischarge, VoltronNuke, VoltronUnique, VoltronHeal, VoltronUltimate, VoltronMinionNuke and VoltronMinionHeal.",
        abilities = {
            {
                name = "Voltron Nuke",
                id = IDS.NUKE,
                source = "library VoltronNuke",
                behavior = "Fast bouncing Orb of Lightning nuke with 220 range, 0.10s delay and 3 + 3 per level bounces."
            },
            {
                name = "Voltron Heal",
                id = IDS.HEAL,
                source = "library VoltronHeal",
                behavior = "Places a lightning mark that triggers when a Discharged titan-side unit steps on it, healing nearby titan-side units."
            },
            {
                name = "Voltron Discharge",
                id = IDS.STEALTH,
                source = "library Voltron and VoltronDischarge",
                behavior = "Stealth/mini-stealth casts apply the old Discharge dummy buff; Voltron's learned stealth scales with hero level."
            },
            {
                name = "Voltron Unique",
                id = IDS.UNIQUE,
                source = "library VoltronUnique",
                behavior = "Normal attacks drain mana from non-wall targets and chain universal lightning damage between enemy walls."
            },
            {
                name = "Voltron Ultimate",
                id = IDS.ULTIMATE,
                source = "library VoltronUltimate",
                behavior = "Applies timed attack-speed bonus and Discharge level 7; point targeting pulses nearby faded structures."
            },
            {
                name = "Voltron Minion Nuke",
                id = IDS.MINION_NUKE,
                source = "library VoltronMinionNuke",
                behavior = "Fires lightning missiles at the main target plus valid units in a 35 degree cone, including units in fog."
            },
            {
                name = "Voltron Minion Heal",
                id = IDS.MINION_HEAL,
                source = "library VoltronMinionHeal",
                behavior = "Bounces healing between allied wounded units."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
