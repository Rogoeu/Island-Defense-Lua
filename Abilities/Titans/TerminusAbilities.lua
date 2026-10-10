if Debug and Debug.beginFile then Debug.beginFile("Abilities/Titans/TerminusAbilities") end

OnInit("TerminusAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameTimer")
    import.strict("MissileSystem")
    import.strict("UnitStateSystem")
    import.strict("TitanDamageSystem")
    import.strict("TitanAbilityUtils")
    import.strict("TomeOfRetraining")
    import.strict("UnitFilter")

    local IDS = {
        TERMINUS = FourCC("E00O"),
        MINION = FourCC("U00O"),
        NUKEMASTER = FourCC("I08S"),
        NUKE = FourCC("TTAQ"),
        HEAL = FourCC("TTAE"),
        HEAL_WARD = FourCC("o023"),
        SCOUT_SENTRY_STONE = FourCC("TTAD"),
        SENTRY_STONE = FourCC("o022"),
        EARTHQUAKE_AURA = FourCC("A0VX"),
        UNIQUE_PEBBLE_TOSS = FourCC("TTA0"),
        UNIQUE_RAGE = FourCC("TTAR"),
        PUMMEL = FourCC("TTAS"),
        ULTIMATE = FourCC("TTAF"),
        WAR_CLUB = FourCC("TTA1"),
        MINION_NUKE = FourCC("TTNQ"),
        MINION_HEAL = FourCC("TTNE"),
        MINION_STEALTH = FourCC("TTNW"),
        MINION_ULTIMATE = FourCC("TTNF")
    }

    local NUKE_MISSILE_EFFECT = "Doodads\\LordaeronSummer\\Terrain\\LoardaeronRockChunks\\LoardaeronRockChunks3.mdl"
    local IMPACT_EFFECT = "Objects\\Spawnmodels\\Undead\\ImpaleTargetDust\\ImpaleTargetDust.mdl"
    local ULTIMATE_EFFECT = "Abilities\\Spells\\Orc\\EarthQuake\\EarthQuakeTarget.mdl"

    local NUKE_SPEED = 1300.0
    local NUKE_ARC = 0.60
    local NUKE_AREA = 245.0
    local NUKE_COLLISION = 20.0
    local NUKE_Z = 80.0

    local MINION_NUKE_DISTANCE = 600.0
    local MINION_NUKE_SPEED = 1100.0
    local MINION_NUKE_COLLISION = 150.0
    local MINION_NUKE_TICK = 0.03125

    local HEAL_TICK = 0.5
    local HEAL_DURATION = 12.0
    local HEAL_AREA = 400.0

    local EARTHQUAKE_RADIUS = 600.0
    local EARTHQUAKE_INTERVAL = 1.0

    local ULTIMATE_AREA = 700.0
    local ULTIMATE_DAMAGE = 400.0
    local MINION_ULTIMATE_AREA = 500.0
    local MINION_ULTIMATE_DAMAGE = 300.0

    local sentryTimers = {}

    local function isAlive(unit)
        return UnitStateSystem.isAlive(unit)
    end

    local function effectAt(path, x, y, scale)
        TitanAbilityUtils.effectAt(path, x, y, scale or 1.0)
    end

    local function effectTarget(path, unit, attachPoint)
        DestroyEffect(AddSpecialEffectTarget(path, unit, attachPoint or "origin"))
    end

    local function isNukable(unit, caster)
        return TitanAbilityUtils.isNukable(unit, caster)
    end

    local function isHealable(unit, caster)
        return TitanAbilityUtils.isHealable(unit, caster) and GetUnitTypeId(unit) ~= IDS.HEAL_WARD
    end

    local function nukeDamage(caster, abilityId)
        return TitanAbilityUtils.standardNukeDamage(caster, abilityId)
    end

    local function pummelMultiplier(unit)
        local level = GetUnitAbilityLevel(unit, IDS.UNIQUE_RAGE)
        if level >= 2 then
            return 2.0
        elseif level >= 1 then
            return 1.5
        end
        return 1.0
    end

    local function addStrength(unit, amount)
        if amount ~= 0 and IsUnitType(unit, UNIT_TYPE_HERO) then
            SetHeroStr(unit, GetHeroStr(unit, false) + amount, true)
        end
    end

    local function damageNukeArea(caster, x, y, amount)
        local group = CreateGroup()
        local unit = nil

        effectAt(IMPACT_EFFECT, x, y, 1.0)
        GroupEnumUnitsInRange(group, x, y, NUKE_AREA, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isNukable(unit, caster) then
                local finalDamage = amount
                if TitanDamageSystem.hasItem(caster, FourCC("I06Z")) and UnitFilter.isTitanHunter(unit) then
                    finalDamage = finalDamage * 1.15
                end
                TitanDamageSystem.dealDamage(caster, unit, finalDamage, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                effectTarget(IMPACT_EFFECT, unit, "overhead")
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function castNuke(caster)
        local target = GetSpellTargetUnit()
        local targetX = GetSpellTargetX()
        local targetY = GetSpellTargetY()
        local amount = nukeDamage(caster, IDS.NUKE)

        MissileSystem.launch({
            x = GetUnitX(caster),
            y = GetUnitY(caster),
            z = GetUnitFlyHeight(caster) + NUKE_Z,
            target = target,
            targetX = targetX,
            targetY = targetY,
            speed = NUKE_SPEED,
            arc = NUKE_ARC,
            collision = NUKE_COLLISION,
            model = NUKE_MISSILE_EFFECT,
            onImpact = function(_, x, y)
                damageNukeArea(caster, x, y, amount)
            end
        })
    end

    local function healAmountForLevel(level)
        if level == 1 then
            return 1200.0 / (HEAL_DURATION / HEAL_TICK)
        elseif level == 2 then
            return 1440.0 / (HEAL_DURATION / HEAL_TICK)
        elseif level == 3 then
            return 1680.0 / (HEAL_DURATION / HEAL_TICK)
        end
        return 1920.0 / (HEAL_DURATION / HEAL_TICK)
    end

    local function castHeal(caster)
        local level = TitanAbilityUtils.levelOrOne(caster, IDS.HEAL)
        local x = GetSpellTargetX()
        local y = GetSpellTargetY()
        local ward = CreateUnit(GetOwningPlayer(caster), IDS.HEAL_WARD, x, y, bj_UNIT_FACING)
        local elapsed = 0.0
        local amount = healAmountForLevel(level)
        local timer = nil

        UnitApplyTimedLife(ward, FourCC("BTLF"), HEAL_DURATION)
        timer = GameTimer.every(HEAL_TICK, function()
            local group = CreateGroup()
            local unit = nil

            elapsed = elapsed + HEAL_TICK
            if elapsed > HEAL_DURATION or not isAlive(ward) then
                DestroyGroup(group)
                timer:destroy()
                return
            end

            GroupEnumUnitsInRange(group, GetUnitX(ward), GetUnitY(ward), HEAL_AREA, nil)
            unit = FirstOfGroup(group)
            while unit do
                GroupRemoveUnit(group, unit)
                if isHealable(unit, caster) then
                    UnitStateSystem.heal(unit, amount, { effect = IMPACT_EFFECT, attachPoint = "origin" })
                end
                unit = FirstOfGroup(group)
            end
            DestroyGroup(group)
        end)
    end

    local function startSentryStone(stone)
        local id = GetHandleId(stone)

        if sentryTimers[id] then
            return
        end

        UnitAddAbility(stone, IDS.EARTHQUAKE_AURA)
        sentryTimers[id] = GameTimer.every(EARTHQUAKE_INTERVAL, function()
            local group = CreateGroup()
            local unit = nil

            if not isAlive(stone) then
                DestroyGroup(group)
                sentryTimers[id]:destroy()
                sentryTimers[id] = nil
                return
            end

            GroupEnumUnitsInRange(group, GetUnitX(stone), GetUnitY(stone), EARTHQUAKE_RADIUS, nil)
            unit = FirstOfGroup(group)
            while unit do
                GroupRemoveUnit(group, unit)
                if isAlive(unit) and IsUnitType(unit, UNIT_TYPE_STRUCTURE) then
                    local armor = 0.0
                    if rawget(_G, "BlzGetUnitArmor") then
                        armor = BlzGetUnitArmor(unit) * 2.0
                    end
                    if armor > 0.0 then
                        TitanDamageSystem.dealDamage(stone, unit, armor, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_NORMAL, WEAPON_TYPE_WHOKNOWS)
                    end
                end
                unit = FirstOfGroup(group)
            end
            DestroyGroup(group)
        end)
    end

    local function castMinionNuke(caster)
        local startX = GetUnitX(caster)
        local startY = GetUnitY(caster)
        local targetX = GetSpellTargetX()
        local targetY = GetSpellTargetY()
        local angle = Atan2(targetY - startY, targetX - startX)
        local x = startX
        local y = startY
        local traveled = 0.0
        local hit = {}
        local effect = AddSpecialEffect(NUKE_MISSILE_EFFECT, x, y)
        local amount = nukeDamage(caster, IDS.MINION_NUKE)
        local timer = nil

        if rawget(_G, "BlzSetSpecialEffectPosition") then
            BlzSetSpecialEffectPosition(effect, x, y, NUKE_Z)
        end

        timer = GameTimer.every(MINION_NUKE_TICK, function()
            local step = MINION_NUKE_SPEED * MINION_NUKE_TICK
            local group = CreateGroup()
            local unit = nil

            if traveled >= MINION_NUKE_DISTANCE or not isAlive(caster) then
                DestroyEffect(effect)
                DestroyGroup(group)
                timer:destroy()
                return
            end

            traveled = traveled + step
            x = startX + traveled * Cos(angle)
            y = startY + traveled * Sin(angle)
            if rawget(_G, "BlzSetSpecialEffectPosition") then
                BlzSetSpecialEffectPosition(effect, x, y, NUKE_Z)
                BlzSetSpecialEffectYaw(effect, angle)
            end

            GroupEnumUnitsInRange(group, x, y, MINION_NUKE_COLLISION, nil)
            unit = FirstOfGroup(group)
            while unit do
                local handleId = GetHandleId(unit)
                GroupRemoveUnit(group, unit)
                if not hit[handleId] and unit ~= caster and isNukable(unit, caster) then
                    hit[handleId] = true
                    effectTarget(IMPACT_EFFECT, unit, "origin")
                    TitanDamageSystem.dealDamage(caster, unit, amount, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                end
                unit = FirstOfGroup(group)
            end
            DestroyGroup(group)
        end)
    end

    local function minionHealAmount(caster)
        local level = TitanAbilityUtils.levelOrOne(caster, IDS.MINION_HEAL)
        if level == 1 then return 300.0 end
        if level == 2 then return 400.0 end
        if level == 3 then return 500.0 end
        return 600.0
    end

    local function castMinionHeal(caster)
        TitanAbilityUtils.areaHeal(caster, GetUnitX(caster), GetUnitY(caster), 600.0, minionHealAmount(caster), IMPACT_EFFECT)
    end

    local function castUltimate(caster, area, amount)
        TitanAbilityUtils.areaNuke(caster, GetSpellTargetX(), GetSpellTargetY(), area, TitanAbilityUtils.applyNukemaster(caster, amount), ULTIMATE_EFFECT)
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.NUKE then
            castNuke(caster)
        elseif abilityId == IDS.HEAL then
            castHeal(caster)
        elseif abilityId == IDS.ULTIMATE then
            castUltimate(caster, ULTIMATE_AREA, ULTIMATE_DAMAGE)
        elseif abilityId == IDS.MINION_NUKE then
            castMinionNuke(caster)
        elseif abilityId == IDS.MINION_HEAL then
            castMinionHeal(caster)
        elseif abilityId == IDS.MINION_ULTIMATE then
            castUltimate(caster, MINION_ULTIMATE_AREA, MINION_ULTIMATE_DAMAGE)
        elseif abilityId == IDS.WAR_CLUB then
            local destructable = GetSpellTargetDestructable()
            if destructable then
                DestructableRestoreLife(destructable, GetDestructableMaxLife(destructable), false)
            end
        end
    end

    local function onHeroSkill()
        local unit = GetTriggerUnit()
        local learned = GetLearnedSkill()
        local level = GetLearnedSkillLevel()

        if learned == IDS.UNIQUE_RAGE then
            if GetUnitAbilityLevel(unit, IDS.UNIQUE_PEBBLE_TOSS) > 0 then
                IncUnitAbilityLevel(unit, IDS.UNIQUE_PEBBLE_TOSS)
            end
            addStrength(unit, 6 * level)
        end
    end

    local function onRetraining(unit)
        if GetUnitAbilityLevel(unit, IDS.UNIQUE_PEBBLE_TOSS) > 1 then
            local wasLevel = GetUnitAbilityLevel(unit, IDS.UNIQUE_PEBBLE_TOSS) - 1
            if wasLevel >= 1 then
                addStrength(unit, -6)
            end
            if wasLevel == 2 then
                addStrength(unit, -12)
            end
            SetUnitAbilityLevel(unit, IDS.UNIQUE_PEBBLE_TOSS, 1)
        end
    end

    local function onDamaged()
        local target = GetTriggerUnit()
        local attacker = GetEventDamageSource()

        if not target or not attacker or GetUnitAbilityLevel(attacker, IDS.PUMMEL) <= 0 then
            return
        end
        if not rawget(_G, "BlzGetEventIsAttack") or not BlzGetEventIsAttack() then
            return
        end
        if not IsUnitType(target, UNIT_TYPE_STRUCTURE) then
            return
        end
        if rawget(_G, "BlzSetEventDamage") and rawget(_G, "BlzGetUnitArmor") then
            local armor = BlzGetUnitArmor(target)
            if armor < 0.0 then
                armor = 0.0
            end
            BlzSetEventDamage(GetEventDamage() + armor * pummelMultiplier(attacker))
        end
    end

    local function onSummon()
        local summoned = GetSummonedUnit()
        if summoned and GetUnitTypeId(summoned) == IDS.SENTRY_STONE then
            startSentryStone(summoned)
        end
    end

    local spellTrigger = CreateTrigger()
    local skillTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local summonTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(skillTrigger, Player(i), EVENT_PLAYER_HERO_SKILL, nil)
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        TriggerRegisterPlayerUnitEvent(summonTrigger, Player(i), EVENT_PLAYER_UNIT_SUMMON, nil)
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
    TriggerAddAction(damageTrigger, function() guarded(onDamaged) end)
    TriggerAddAction(summonTrigger, function() guarded(onSummon) end)

    TomeOfRetraining.register(onRetraining)

    AbilityRegistry.registerRace("Granitacles", "titan", {
        notes = "Granitacles abilities ported from TerminusNuke, TerminusHeal, TerminusUnique, TerminusMinionNuke, TerminusMinionHeal and TerminusWarClub.",
        abilities = {
            {
                name = "Granitacles Nuke",
                id = IDS.NUKE,
                source = "library TerminusNuke",
                behavior = "Launches a rock missile at the target point/unit and deals magic AoE damage on impact."
            },
            {
                name = "Granitacles Heal",
                id = IDS.HEAL,
                source = "library TerminusHeal",
                behavior = "Spawns the old healing ward and heals allied wounded units in 400 AoE every 0.5 seconds for 12 seconds."
            },
            {
                name = "Titan's Rage / Pummel",
                id = IDS.UNIQUE_RAGE,
                source = "library TerminusUnique",
                behavior = "Learning rage increases Pebble Toss level and Strength; Pummel attacks add structure damage based on target armor."
            },
            {
                name = "Sentry Stone Earthquake",
                id = IDS.SCOUT_SENTRY_STONE,
                source = "library TerminusUnique",
                behavior = "Summoned Sentry Stones gain the earthquake aura and damage nearby structures by twice their armor every second."
            },
            {
                name = "Granitacles Ultimate",
                id = IDS.ULTIMATE,
                source = "Ultimate registry placeholder",
                behavior = "Large earth impact AoE kept as alpha-safe fallback because no dedicated old TTAF library was present in the extracted code."
            },
            {
                name = "Granitacles Minion Nuke",
                id = IDS.MINION_NUKE,
                source = "library TerminusMinionNuke",
                behavior = "Launches a 600-range rock wave that damages valid targets on collision."
            },
            {
                name = "Granitacles Minion Heal",
                id = IDS.MINION_HEAL,
                source = "library TerminusMinionHeal",
                behavior = "Heals allied wounded units in 600 AoE using UnitStateSystem."
            },
            {
                name = "War Club",
                id = IDS.WAR_CLUB,
                source = "library TerminusWarClub",
                behavior = "Restores the target destructable immediately after War Club consumes it, matching the old anti-tree-loss behavior."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
