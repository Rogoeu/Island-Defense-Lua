if Debug and Debug.beginFile then Debug.beginFile("Abilities/Titans/DemonicusAbilities") end

OnInit("DemonicusAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameTimer")
    import.strict("MissileSystem")
    import.strict("UnitStateSystem")
    import.strict("TitanDamageSystem")
    import.strict("TitanAbilityUtils")
    import.strict("PlayerData")

    local IDS = {
        DEMONICUS = FourCC("E00E"),
        MINION = FourCC("U005"),
        NUKEMASTER = FourCC("I08S"),
        NUCLE = FourCC("A0DR"),
        HEAL = FourCC("TDAE"),
        SCOUT = FourCC("A08J"),
        SCOUT_SHADE = FourCC("u004"),
        SCOUT_VISION = FourCC("A08G"),
        WW = FourCC("A096"),
        WW_INVIS = FourCC("A01X"),
        UNIQUE = FourCC("A099"),
        ULTIMATE = FourCC("A09B"),
        ULTIMATE_VISION = FourCC("A09A"),
        ULTIMATE_ATTACK_SPEED = FourCC("A08H"),
        PHASE = FourCC("Aeth"),
        SPAWN_OF_DARKNESS = FourCC("n00I"),
        MINION_NUKE = FourCC("TDNQ"),
        MINION_HEAL = FourCC("TDNE"),
        MINION_STEALTH = FourCC("TDNW"),
        MINION_ULTIMATE = FourCC("TDNF")
    }

    local NUKE_RADIUS = 650.0
    local NUKE_MISSILE_SPEED = 1600.0
    local NUKE_MISSILE_COLLISION = 20.0
    local NUKE_MISSILE_Z = 100.0
    local NUKE_PHASE_DURATION = 3.0
    local SPAWN_CHANCE = 20
    local SPAWN_DEGEN_INTERVAL = 0.25
    local SPAWN_DEGEN_PERCENT_PER_SECOND = 0.05
    local SPAWN_REGEN_PERCENT = 0.20
    local HEAL_INTERVAL = 0.5
    local SCOUT_SHADE_COUNT = 6
    local SCOUT_INTERVAL = 1.0
    local SCOUT_DURATION = 20.0
    local SCOUT_COLLISION_RADIUS = 600.0
    local WW_DURATION = 30.0
    local UNIQUE_EFFECT = "war3mapImported\\DemonicusEtherityBuff.mdx"
    local UNIQUE_HAND_EFFECT = "war3mapImported\\DemonicusEtherityBuff.mdl"
    local NUKE_MISSILE_EFFECT = "war3mapImported\\Model_Ability_Titan_Demonicus_Nuke(Missile).mdx"
    local NUKE_FALLBACK_MISSILE_EFFECT = "Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilMissile.mdl"
    local NUKE_IMPACT_EFFECT = "Abilities\\Spells\\Undead\\CarrionSwarm\\CarrionSwarmDamage.mdl"
    local HEAL_MISSILE_EFFECT = "Abilities\\Weapons\\SludgeMissile\\SludgeMissile.mdl"
    local HEAL_AREA_EFFECT = "Abilities\\Spells\\NightElf\\Starfall\\StarfallCaster.mdl"
    local SPAWN_EFFECT = "Abilities\\Spells\\Undead\\AnimateDead\\AnimateDeadTarget.mdl"
    local SPAWN_REGEN_EFFECT = "Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilSpecialArt.mdl"
    local MINION_NUKE_EFFECT = "Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilSpecialArt.mdl"
    local activeHelpBlocks = 0
    local uniqueVersions = {}

    local function isAlive(unit)
        return UnitStateSystem.isAlive(unit)
    end

    local function levelOrOne(unit, abilityId)
        return TitanAbilityUtils.levelOrOne(unit, abilityId)
    end

    local function isTitanSideUnit(unit)
        local playerData = unit and PlayerData.get(GetOwningPlayer(unit)) or nil
        return playerData and (
            playerData:class() == PlayerData.CLASS_TITAN or
            playerData:class() == PlayerData.CLASS_MINION
        )
    end

    local function isDefenderUnit(unit)
        local playerData = unit and PlayerData.get(GetOwningPlayer(unit)) or nil
        return playerData and playerData:class() == PlayerData.CLASS_DEFENDER
    end

    local function distanceBetween(x1, y1, x2, y2)
        local dx = x2 - x1
        local dy = y2 - y1
        return SquareRoot(dx * dx + dy * dy)
    end

    local function nukeDamage(caster)
        local amount = 105.0 + 25.0 * levelOrOne(caster, IDS.NUCLE)
        if TitanDamageSystem.hasItem(caster, IDS.NUKEMASTER) then
            amount = amount * 1.20
        end
        return amount
    end

    local function setHelpAlliance(enabled)
        local outer = 0
        local inner = 0

        while outer <= 9 do
            inner = 0
            while inner <= 9 do
                if outer ~= inner then
                    SetPlayerAlliance(Player(outer), Player(inner), ALLIANCE_HELP_REQUEST, enabled)
                    SetPlayerAlliance(Player(outer), Player(inner), ALLIANCE_HELP_RESPONSE, enabled)
                end
                inner = inner + 1
            end
            outer = outer + 1
        end
    end

    local function blockHelp()
        activeHelpBlocks = activeHelpBlocks + 1
        if activeHelpBlocks == 1 then
            setHelpAlliance(false)
        end
    end

    local function releaseHelp()
        if activeHelpBlocks <= 0 then
            return
        end

        activeHelpBlocks = activeHelpBlocks - 1
        if activeHelpBlocks == 0 then
            setHelpAlliance(true)
        end
    end

    local function effectAt(path, x, y, scale)
        TitanAbilityUtils.effectAt(path, x, y, scale or 1.0)
    end

    local function addTimedEffectTarget(unit, path, attachPoint, duration)
        local effect = AddSpecialEffectTarget(path, unit, attachPoint or "origin")
        GameTimer.after(duration, function()
            if effect then
                DestroyEffect(effect)
            end
        end)
        return effect
    end

    local function phaseTimed(unit, duration)
        if not isAlive(unit) then
            return
        end

        UnitAddAbility(unit, IDS.PHASE)
        UnitMakeAbilityPermanent(unit, true, IDS.PHASE)
        GameTimer.after(duration, function()
            if unit and GetUnitTypeId(unit) ~= 0 then
                UnitRemoveAbility(unit, IDS.PHASE)
            end
        end)
    end

    local function createSpawnOfDarkness(ownerUnit, x, y)
        local spawn = CreateUnit(GetOwningPlayer(ownerUnit), IDS.SPAWN_OF_DARKNESS, x, y, GetUnitFacing(ownerUnit))
        local timer = nil

        effectAt(SPAWN_EFFECT, x, y, 1.0)
        timer = GameTimer.every(SPAWN_DEGEN_INTERVAL, function()
            if not isAlive(spawn) then
                timer:destroy()
                return
            end

            UnitStateSystem.addLife(spawn, -UnitStateSystem.maxLife(spawn) * SPAWN_DEGEN_PERCENT_PER_SECOND * SPAWN_DEGEN_INTERVAL, { allowKill = true })
            if UnitStateSystem.life(spawn) <= 0.405 then
                timer:destroy()
            end
        end)
    end

    local function validNukeTarget(unit, caster)
        return TitanAbilityUtils.isNukable(unit, caster) and IsUnitVisible(unit, GetOwningPlayer(caster))
    end

    local function nukeImpact(caster, target)
        if not target or GetUnitTypeId(target) == 0 then
            return
        end

        effectAt(NUKE_IMPACT_EFFECT, GetUnitX(target), GetUnitY(target), 1.0)
        TitanDamageSystem.dealDamage(caster, target, nukeDamage(caster), ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
        phaseTimed(target, NUKE_PHASE_DURATION)

        if not isAlive(target) and GetRandomInt(1, 100) <= SPAWN_CHANCE then
            createSpawnOfDarkness(caster, GetUnitX(target), GetUnitY(target))
        end
    end

    local function launchNukeMissile(caster, target, onImpact)
        local x = GetUnitX(caster)
        local y = GetUnitY(caster)

        -- The old DemoNuke used war3mapImported\Model_Ability_Titan_Demonicus_Nuke(Missile).mdx
        -- via xehomingmissile.fxpath. The fallback is visual-only and keeps the spell readable
        -- in rebuilt maps where that imported model is missing or invisible.
        MissileSystem.launch({
            x = x,
            y = y,
            z = NUKE_MISSILE_Z,
            target = target,
            speed = NUKE_MISSILE_SPEED,
            collision = NUKE_MISSILE_COLLISION,
            model = NUKE_FALLBACK_MISSILE_EFFECT
        })
        MissileSystem.launch({
            x = x,
            y = y,
            z = NUKE_MISSILE_Z,
            target = target,
            speed = NUKE_MISSILE_SPEED,
            collision = NUKE_MISSILE_COLLISION,
            model = NUKE_MISSILE_EFFECT,
            onImpact = onImpact
        })
    end

    local function castNuke(caster)
        local group = CreateGroup()
        local target = nil

        GroupEnumUnitsInRange(group, GetUnitX(caster), GetUnitY(caster), NUKE_RADIUS, nil)
        target = FirstOfGroup(group)
        while target do
            GroupRemoveUnit(group, target)
            if validNukeTarget(target, caster) then
                launchNukeMissile(caster, target, function(impactTarget)
                    nukeImpact(caster, impactTarget)
                end)
            end
            target = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function healAmountPerTick(caster)
        local level = levelOrOne(caster, IDS.HEAL)
        return (50.0 + 50.0 * level) * HEAL_INTERVAL
    end

    local function healRadius(caster)
        return 300.0 + 100.0 * levelOrOne(caster, IDS.HEAL)
    end

    local function fireHealMissile(caster, target)
        MissileSystem.launch({
            x = GetUnitX(caster) + GetRandomReal(-100.0, 100.0),
            y = GetUnitY(caster) + GetRandomReal(-100.0, 100.0),
            z = 1200.0,
            target = target,
            speed = 600.0,
            collision = 20.0,
            model = HEAL_MISSILE_EFFECT
        })
    end

    local function castHeal(caster)
        local x = GetUnitX(caster)
        local y = GetUnitY(caster)
        local level = levelOrOne(caster, IDS.HEAL)
        local duration = 2.0 + 0.5 * level
        -- The Minion heal lasts at least three seconds (six half-second ticks
        -- at level one). Preserve the Titan duration and higher-level scaling.
        if GetUnitTypeId(caster) == IDS.MINION or
            PlayerData.mainUnitClass(caster) == PlayerData.CLASS_MINION then
            duration = math.max(3.0, duration)
        end
        local elapsed = 0.0
        local amount = healAmountPerTick(caster)
        local radius = healRadius(caster)
        local aoeEffect = AddSpecialEffect(HEAL_AREA_EFFECT, x, y)
        local timer = nil

        local setEffectPosition = rawget(_G, "BlzSetSpecialEffectPosition")

        if setEffectPosition then
            setEffectPosition(aoeEffect, x, y, 900.0)
        end

        timer = GameTimer.every(HEAL_INTERVAL, function()
            local group = CreateGroup()
            local unit = nil

            elapsed = elapsed + HEAL_INTERVAL
            if elapsed > duration or not isAlive(caster) then
                if aoeEffect then
                    DestroyEffect(aoeEffect)
                end
                DestroyGroup(group)
                timer:destroy()
                return
            end

            GroupEnumUnitsInRange(group, x, y, radius, nil)
            unit = FirstOfGroup(group)
            while unit do
                GroupRemoveUnit(group, unit)
                if isTitanSideUnit(unit) and UnitStateSystem.life(unit) < UnitStateSystem.maxLife(unit) then
                    fireHealMissile(caster, unit)
                    UnitStateSystem.heal(unit, amount)
                end
                unit = FirstOfGroup(group)
            end
            DestroyGroup(group)
        end)
    end

    local function cleanupScouting(instance)
        local unit = nil

        if instance.finished then
            return
        end
        instance.finished = true

        unit = FirstOfGroup(instance.affectedUnits)
        while unit do
            GroupRemoveUnit(instance.affectedUnits, unit)
            UnitRemoveAbility(unit, IDS.SCOUT_VISION)
            unit = FirstOfGroup(instance.affectedUnits)
        end

        unit = FirstOfGroup(instance.shades)
        while unit do
            GroupRemoveUnit(instance.shades, unit)
            if unit and GetUnitTypeId(unit) ~= 0 then
                KillUnit(unit)
            end
            unit = FirstOfGroup(instance.shades)
        end

        DestroyGroup(instance.affectedUnits)
        DestroyGroup(instance.shades)
        DestroyGroup(instance.targets)
        if instance.timer then
            instance.timer:destroy()
        end
    end

    local function scoutingTarget(unit)
        return isAlive(unit) and not isTitanSideUnit(unit)
    end

    local function checkShadeCollision(instance, shade)
        local group = CreateGroup()
        local unit = nil

        GroupEnumUnitsInRange(group, GetUnitX(shade), GetUnitY(shade), SCOUT_COLLISION_RADIUS, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if unit == instance.caster and instance.elapsed > 10.0 then
                GroupRemoveUnit(instance.shades, shade)
                KillUnit(shade)
                DestroyGroup(group)
                return
            elseif scoutingTarget(unit) then
                if isDefenderUnit(unit) and not IsUnitInGroup(unit, instance.targets) then
                    IssueTargetOrder(shade, "smart", unit)
                    GroupRemoveUnit(instance.shades, shade)
                    GroupAddUnit(instance.targets, unit)
                    DestroyGroup(group)
                    return
                elseif not isDefenderUnit(unit) and GetUnitAbilityLevel(unit, IDS.SCOUT_VISION) <= 0 then
                    UnitAddAbility(unit, IDS.SCOUT_VISION)
                    GroupAddUnit(instance.affectedUnits, unit)
                end
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function castScouting(caster)
        local instance = {
            caster = caster,
            targetX = GetSpellTargetX(),
            targetY = GetSpellTargetY(),
            aoe = 2000.0 + 250.0 * GetHeroLevel(caster),
            elapsed = 0.0,
            finished = false,
            shades = CreateGroup(),
            affectedUnits = CreateGroup(),
            targets = CreateGroup()
        }
        local angleStep = 360.0 / SCOUT_SHADE_COUNT
        local i = 0

        if GetUnitAbilityLevel(caster, IDS.SCOUT) > 0 then
            SetUnitAbilityLevel(caster, IDS.SCOUT, GetHeroLevel(caster))
        end

        while i < SCOUT_SHADE_COUNT do
            local angle = angleStep * i
            local shade = CreateUnit(GetOwningPlayer(caster), IDS.SCOUT_SHADE, instance.targetX, instance.targetY, angle)
            local distance = instance.aoe + 100.0
            local x = instance.targetX + distance * Cos(angle * bj_DEGTORAD)
            local y = instance.targetY + distance * Sin(angle * bj_DEGTORAD)

            UnitAddAbility(shade, FourCC("Aloc"))
            UnitApplyTimedLife(shade, FourCC("BTLF"), SCOUT_DURATION)
            IssuePointOrder(shade, "move", x, y)
            GroupAddUnit(instance.shades, shade)
            i = i + 1
        end

        instance.timer = GameTimer.every(SCOUT_INTERVAL, function()
            local copy = CreateGroup()
            local shade = nil
            local count = 0

            instance.elapsed = instance.elapsed + SCOUT_INTERVAL
            ForGroup(instance.shades, function()
                GroupAddUnit(copy, GetEnumUnit())
            end)
            shade = FirstOfGroup(copy)
            while shade do
                GroupRemoveUnit(copy, shade)
                if not isAlive(shade) then
                    GroupRemoveUnit(instance.shades, shade)
                else
                    count = count + 1
                    if distanceBetween(instance.targetX, instance.targetY, GetUnitX(shade), GetUnitY(shade)) >= instance.aoe then
                        IssueTargetOrder(shade, "smart", instance.caster)
                    end
                    checkShadeCollision(instance, shade)
                end
                shade = FirstOfGroup(copy)
            end
            DestroyGroup(copy)

            if count == 0 or instance.elapsed >= SCOUT_DURATION + 1.0 then
                cleanupScouting(instance)
            end
        end)
    end

    local function castWhirlwind(caster)
        local level = GetUnitAbilityLevel(caster, IDS.UNIQUE) + 1

        blockHelp()
        if GetUnitAbilityLevel(caster, IDS.WW) > 0 then
            SetUnitAbilityLevel(caster, IDS.WW, level)
        end
        UnitAddAbility(caster, IDS.WW_INVIS)
        SetUnitAbilityLevel(caster, IDS.WW_INVIS, level)

        GameTimer.after(WW_DURATION, function()
            releaseHelp()
            if caster and GetUnitTypeId(caster) ~= 0 then
                UnitRemoveAbility(caster, IDS.WW_INVIS)
            end
        end)
    end

    local function castUnique(caster)
        local duration = 3.0 * levelOrOne(caster, IDS.UNIQUE)
        local id = GetHandleId(caster)
        local version = (uniqueVersions[id] or 0) + 1

        uniqueVersions[id] = version
        UnitAddAbility(caster, FourCC("Avul"))
        SetUnitInvulnerable(caster, true)
        addTimedEffectTarget(caster, UNIQUE_EFFECT, "chest", duration)
        addTimedEffectTarget(caster, UNIQUE_HAND_EFFECT, "hands", duration)

        GameTimer.after(duration, function()
            if caster and GetUnitTypeId(caster) ~= 0 and uniqueVersions[id] == version then
                UnitRemoveAbility(caster, FourCC("Avul"))
                SetUnitInvulnerable(caster, false)
                uniqueVersions[id] = nil
            end
        end)
    end

    local function ultimateTarget(unit, caster)
        return isAlive(unit) and not IsUnitAlly(caster, GetOwningPlayer(unit))
    end

    local function castUltimate(caster)
        local affected = CreateGroup()
        local group = CreateGroup()
        local unit = nil
        local x = GetUnitX(caster)
        local y = GetUnitY(caster)
        local radius = 5000.0

        UnitAddAbility(caster, IDS.ULTIMATE_ATTACK_SPEED)
        GroupEnumUnitsInRange(group, x, y, radius, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if ultimateTarget(unit, caster) then
                GroupAddUnit(affected, unit)
                if GetUnitAbilityLevel(unit, IDS.ULTIMATE_VISION) <= 0 then
                    UnitAddAbility(unit, IDS.ULTIMATE_VISION)
                end
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)

        GameTimer.after(20.0, function()
            local cleanup = CreateGroup()
            local u = nil

            if caster and GetUnitTypeId(caster) ~= 0 then
                UnitRemoveAbility(caster, IDS.ULTIMATE_VISION)
                UnitRemoveAbility(caster, IDS.ULTIMATE_ATTACK_SPEED)
            end

            u = FirstOfGroup(affected)
            while u do
                GroupRemoveUnit(affected, u)
                UnitRemoveAbility(u, IDS.ULTIMATE_VISION)
                u = FirstOfGroup(affected)
            end
            DestroyGroup(affected)

            GroupEnumUnitsInRange(cleanup, x, y, 99999.0, nil)
            u = FirstOfGroup(cleanup)
            while u do
                GroupRemoveUnit(cleanup, u)
                UnitRemoveAbility(u, IDS.ULTIMATE_VISION)
                u = FirstOfGroup(cleanup)
            end
            DestroyGroup(cleanup)
        end)
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.NUCLE then
            castNuke(caster)
        elseif abilityId == IDS.HEAL then
            castHeal(caster)
        elseif abilityId == IDS.SCOUT then
            castScouting(caster)
        elseif abilityId == IDS.WW then
            castWhirlwind(caster)
        elseif abilityId == IDS.ULTIMATE then
            castUltimate(caster)
        elseif abilityId == IDS.MINION_NUKE then
            TitanAbilityUtils.bounceNuke(caster, GetSpellTargetUnit(), {
                abilityId = IDS.MINION_NUKE,
                effect = MINION_NUKE_EFFECT,
                filter = validNukeTarget
            })
        elseif abilityId == IDS.MINION_HEAL or abilityId == IDS.MINION_ULTIMATE then
            TitanAbilityUtils.bounceHeal(caster, caster, {
                abilityId = IDS.MINION_HEAL,
                effect = MINION_NUKE_EFFECT
            })
        end
    end

    local function onSpellCast()
        if GetSpellAbilityId() == IDS.UNIQUE then
            castUnique(GetTriggerUnit())
        end
    end

    local function onHeroSkill()
        if GetLearnedSkill() == IDS.UNIQUE and GetUnitAbilityLevel(GetTriggerUnit(), IDS.WW) > 0 then
            IncUnitAbilityLevel(GetTriggerUnit(), IDS.WW)
        end
    end

    local function onDamaged()
        local source = GetEventDamageSource()
        local target = GetTriggerUnit()

        if source and GetUnitTypeId(source) == IDS.SPAWN_OF_DARKNESS and IsUnitEnemy(target, GetOwningPlayer(source)) then
            UnitStateSystem.heal(source, UnitStateSystem.maxLife(source) * SPAWN_REGEN_PERCENT, {
                effect = SPAWN_REGEN_EFFECT,
                attachPoint = "origin"
            })
        end
    end

    local spellTrigger = CreateTrigger()
    local castTrigger = CreateTrigger()
    local skillTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(castTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_CAST, nil)
        TriggerRegisterPlayerUnitEvent(skillTrigger, Player(i), EVENT_PLAYER_HERO_SKILL, nil)
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
    TriggerAddAction(castTrigger, function() guarded(onSpellCast) end)
    TriggerAddAction(skillTrigger, function() guarded(onHeroSkill) end)
    TriggerAddAction(damageTrigger, function() guarded(onDamaged) end)

    AbilityRegistry.registerRace("Demonicus", "titan", {
        notes = "Demonicus abilities ported from DemoWW, DemoNuke, DemoHeal, DemoUnique, DemoUlti, SpawnofDarkness and DemonicusNukeMinion.",
        abilities = {
            {
                name = "Demonicus Nuke",
                id = IDS.NUCLE,
                source = "library DemoNuke",
                behavior = "Launches homing darkness missiles at visible valid enemies in 650 range, damages on impact, phases targets and can spawn Spawn of Darkness on kills."
            },
            {
                name = "Demonicus Heal",
                id = IDS.HEAL,
                source = "library DemoHeal",
                behavior = "Creates a short healing field that sends sludge missiles and heals titan-side wounded units every 0.5 seconds."
            },
            {
                name = "Shroud of Darkness",
                id = IDS.SCOUT,
                source = "library DemoScouting",
                behavior = "Summons 6 shades at the target point, reveals non-defender units they touch and sends shades after defenders they collide with."
            },
            {
                name = "Demonicus Whirlwind",
                id = IDS.WW,
                source = "library DemoWW",
                behavior = "Temporarily disables help alliances and grants the old invisibility ability scaled by Etherity level."
            },
            {
                name = "Etherity",
                id = IDS.UNIQUE,
                source = "library DemoUnique",
                behavior = "Grants temporary invulnerability and Demonicus etherity visuals for 3 seconds per level."
            },
            {
                name = "Demonicus Ultimate",
                id = IDS.ULTIMATE,
                source = "library DemoUlti",
                behavior = "Grants attack speed to Demonicus and adds the vision ability to nearby enemies for 20 seconds."
            },
            {
                name = "Spawn of Darkness",
                id = IDS.SPAWN_OF_DARKNESS,
                source = "library SpawnofDarkness",
                behavior = "Nuke-spawned units degenerate over time and heal for 20 percent max life when damaging enemies."
            },
            {
                name = "Demonicus Minion Nuke",
                id = IDS.MINION_NUKE,
                source = "library DemonicusNukeMinion",
                behavior = "Bounces Death Coil impact damage between visible valid targets."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
