if Debug and Debug.beginFile then Debug.beginFile("Abilities/Titans/BubonicusAbilities") end

OnInit("BubonicusAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("RacePickSystem")
    import.strict("UnitSpawner")
    import.strict("PlayerData")
    import.strict("GameTimer")
    import.strict("DummyCaster")
    import.strict("UnitStateSystem")
    import.strict("TitanDamageSystem")
    import.strict("TitanAbilityUtils")
    import.strict("TomeOfRetraining")

    local IDS = {
        BUBONICUS = FourCC("E00I"),
        MINION = FourCC("U00B"),
        MOUND_CORPSE_SPAWN = FourCC("A044"),
        NUKEMASTER = FourCC("I08S"),
        CORPSE_SUMMON = FourCC("u00A"),
        CORPSE_WARD = FourCC("u008"),
        CORPSE_WARD_CLOUD = FourCC("u007"),
        CORPSE_WARD_ATTACK = FourCC("A04B"),
        CORPSE_ARMOR = FourCC("A045"),
        CORPSE_DROP_READY = FourCC("TBAD"),
        EXHUME = FourCC("TBAR"),
        NUCLE = FourCC("ANhs"),
        HEAL = FourCC("TBAE"),
        HEAL_BUFF = FourCC("A040"),
        ULTIMATE = FourCC("TBAF"),
        ULTIMATE_BUFF = FourCC("B01B"),
        ULTIMATE_WW_BUFF = FourCC("B01C"),
        MINION_NUKE = FourCC("TBNQ"),
        MINION_HEAL = FourCC("TBNE")
    }

    local CORPSE_ABILITIES = {
        FourCC("TBA0"),
        FourCC("TBA1"),
        FourCC("TBA2"),
        FourCC("TBA3"),
        FourCC("TBA4"),
        FourCC("TBA5"),
        FourCC("TBA6")
    }

    local CORPSE_DROP_ABILITIES = {
        FourCC("TBA1"),
        FourCC("TBA2"),
        FourCC("TBA3"),
        FourCC("TBA4"),
        FourCC("TBA5"),
        FourCC("TBA6")
    }

    local ORDER_BLOODLUST = 852101
    local TIMED_LIFE = FourCC("BTLF")
    local DISEASE_RADIUS = 250.0
    local DISEASE_TICK = 1.0
    local DISEASE_TICKS = 5
    local DISEASE_DAMAGE_PER_CORPSE = 4.0
    local NUKE_MISSILE_COUNT = 24
    local NUKE_LAUNCH_INTERVAL = 0.05
    local NUKE_SPLASH = 125.0
    local NUKE_TARGET_AREA = 250.0
    local NUKE_EFFECT = "Objects\\Spawnmodels\\Human\\HumanLargeDeathExplode\\HumanLargeDeathExplode.mdl"
    local NUKE_SPLAT = "war3mapImported\\Splat0"
    local HEAL_EFFECT = "Objects\\Spawnmodels\\Orc\\Orcblood\\OrdBloodWyvernRider.mdl"
    local HEAL_LIGHTNING = "AFOD"
    local MINION_HEAL_EFFECT = "Abilities\\Spells\\Undead\\AnimateDead\\AnimateDeadTarget.mdl"
    local WARD_READY_DELAY = 15.0
    local WARD_DURATION = 300.0
    local SHIELD_EFFECT = "Abilities\\Weapons\\MeatwagonMissile\\MeatwagonMissile.mdl"
    local SHIELD_TRAIL = "war3mapImported\\BloodySplat Missile.mdl"
    local SHIELD_HEALTH = 500.0
    local SHIELD_RADIUS = 150.0
    local SHIELD_TICK = 0.03125
    local SHIELD_MAX = 6

    local states = {}
    local diseaseInstances = {}
    local activeNukes = {}
    local activeShields = {}
    local suppressDamage = false

    local function isAlive(unit)
        return UnitStateSystem.isAlive(unit)
    end

    local function isBubonicus(unit)
        return unit and GetUnitTypeId(unit) == IDS.BUBONICUS
    end

    local function isDiseaseTarget(unit, cause)
        return isAlive(unit) and
            (not IsUnitAlly(unit, GetOwningPlayer(cause)) or GetOwningPlayer(unit) == Player(PLAYER_NEUTRAL_PASSIVE)) and
            not IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
            not IsUnitType(unit, UNIT_TYPE_MECHANICAL)
    end

    local function keyFor(cause, target)
        return I2S(GetHandleId(cause)) .. ":" .. I2S(GetHandleId(target))
    end

    local function hasItem(unit, itemId)
        return TitanDamageSystem.hasItem(unit, itemId)
    end

    local function distanceBetween(x1, y1, x2, y2)
        local dx = x2 - x1
        local dy = y2 - y1
        return SquareRoot(dx * dx + dy * dy)
    end

    local function damageForNuke(caster)
        local level = TitanAbilityUtils.levelOrOne(caster, IDS.NUCLE)
        local amount = 180.0

        if level == 1 then
            amount = 130.0
        elseif level == 2 then
            amount = 155.0
        end

        if hasItem(caster, IDS.NUKEMASTER) then
            amount = amount * 1.20
        end
        return amount
    end

    local function stunForNuke(caster)
        local level = TitanAbilityUtils.levelOrOne(caster, IDS.NUCLE)
        if level == 1 then
            return 0.25
        elseif level == 2 then
            return 0.50
        end
        return 1.00
    end

    local function healForLevel(caster)
        local level = TitanAbilityUtils.levelOrOne(caster, IDS.HEAL)
        if level == 1 then
            return 200.0, 500.0
        elseif level == 2 then
            return 400.0, 600.0
        elseif level == 3 then
            return 600.0, 600.0
        end
        return 800.0, 700.0
    end

    local function sayToOwner(unit, text)
        local playerData = PlayerData.get(GetOwningPlayer(unit))
        if playerData and playerData.say then
            playerData:say(text)
        else
            DisplayTimedTextToPlayer(GetOwningPlayer(unit), 0, 0, 10, text)
        end
    end

    local function stunTimed(unit, seconds)
        if not isAlive(unit) then
            return
        end
        PauseUnit(unit, true)
        GameTimer.after(seconds, function()
            if isAlive(unit) then
                PauseUnit(unit, false)
            end
        end)
    end

    local function createLightningTimed(code, source, target, duration)
        local lightning = nil
        if not source or not target or not AddLightningEx then
            return
        end
        lightning = AddLightningEx(
            code,
            true,
            GetUnitX(source),
            GetUnitY(source),
            GetUnitFlyHeight(source) + 60.0,
            GetUnitX(target),
            GetUnitY(target),
            GetUnitFlyHeight(target) + 60.0
        )
        GameTimer.after(duration or 1.0, function()
            if lightning then
                DestroyLightning(lightning)
            end
        end)
    end

    local function stateFor(unit)
        local id = GetHandleId(unit)
        local state = states[id]

        if not state then
            state = {
                unit = unit,
                corpses = 0,
                exhumeLevel = 0,
                diseaseEffect = nil
            }
            states[id] = state
        end

        return state
    end

    local function maxCorpses(state)
        if state.exhumeLevel >= 1 then
            return 6
        end
        return 4
    end

    local function displayedCorpseCount(unit)
        local i = #CORPSE_ABILITIES

        while i >= 2 do
            if GetUnitAbilityLevel(unit, CORPSE_ABILITIES[i]) > 0 then
                return i - 1
            end
            i = i - 1
        end

        return 0
    end

    local function syncCorpseCount(state)
        local displayed = displayedCorpseCount(state.unit)

        if displayed > state.corpses then
            state.corpses = displayed
        end
    end

    local function setAbilityAvailable(unit, abilityId, available)
        if GetUnitAbilityLevel(unit, abilityId) > 0 then
            UnitMakeAbilityPermanent(unit, true, abilityId)
        end

        if BlzUnitDisableAbility then
            BlzUnitDisableAbility(unit, abilityId, not available, false)
            if available then
                BlzUnitDisableAbility(unit, abilityId, false, true)
                BlzUnitDisableAbility(unit, abilityId, false, false)
            end
        end
    end

    local function updateEnabled(state)
        local unit = state.unit
        local hasCorpses = state.corpses > 0

        syncCorpseCount(state)
        hasCorpses = state.corpses > 0

        if GetUnitAbilityLevel(unit, IDS.CORPSE_DROP_READY) > 0 then
            if state.corpses >= maxCorpses(state) then
                SetUnitAbilityLevel(unit, IDS.CORPSE_DROP_READY, 2)
            else
                SetUnitAbilityLevel(unit, IDS.CORPSE_DROP_READY, 1)
            end
        end

        setAbilityAvailable(unit, IDS.NUCLE, hasCorpses)
        setAbilityAvailable(unit, IDS.ULTIMATE, hasCorpses)
    end

    local function updateCorpseAbilities(state)
        local unit = state.unit
        local i = 1

        while i <= #CORPSE_ABILITIES do
            if GetUnitAbilityLevel(unit, CORPSE_ABILITIES[i]) > 0 then
                UnitRemoveAbility(unit, CORPSE_ABILITIES[i])
            end
            i = i + 1
        end

        UnitAddAbility(unit, CORPSE_ABILITIES[state.corpses + 1])

        if state.corpses > 0 and not state.diseaseEffect then
            state.diseaseEffect = AddSpecialEffectTarget("units\\undead\\PlagueCloud\\PlagueCloud.mdl", unit, "origin")
        elseif state.corpses <= 0 and state.diseaseEffect then
            DestroyEffect(state.diseaseEffect)
            state.diseaseEffect = nil
        end

        if state.exhumeLevel >= 2 and state.corpses > 0 then
            if GetUnitAbilityLevel(unit, IDS.CORPSE_ARMOR) <= 0 then
                UnitAddAbility(unit, IDS.CORPSE_ARMOR)
            end
            SetUnitAbilityLevel(unit, IDS.CORPSE_ARMOR, state.corpses)
        elseif GetUnitAbilityLevel(unit, IDS.CORPSE_ARMOR) > 0 then
            UnitRemoveAbility(unit, IDS.CORPSE_ARMOR)
        end

        updateEnabled(state)
    end

    local function addCorpse(unit)
        local state = stateFor(unit)

        if state.corpses >= maxCorpses(state) then
            return false
        end

        state.corpses = state.corpses + 1
        updateCorpseAbilities(state)
        GameTimer.after(0.0, function()
            if isAlive(unit) then
                updateEnabled(state)
            end
        end)
        return true
    end

    local function subtractCorpse(unit)
        local state = stateFor(unit)

        syncCorpseCount(state)
        if state.corpses <= 0 then
            return false
        end

        state.corpses = state.corpses - 1
        updateCorpseAbilities(state)
        return true
    end

    local function consumeAllCorpses(unit)
        local state = stateFor(unit)
        local count = state.corpses

        syncCorpseCount(state)
        count = state.corpses
        state.corpses = 0
        updateCorpseAbilities(state)
        return count
    end

    local function diseaseTarget(cause, target, corpseCount)
        local key = keyFor(cause, target)
        local instance = diseaseInstances[key]

        if corpseCount <= 0 or not isDiseaseTarget(target, cause) then
            return
        end

        if instance then
            instance.ticks = DISEASE_TICKS
            instance.amount = DISEASE_DAMAGE_PER_CORPSE * corpseCount
            return
        end

        instance = {
            cause = cause,
            target = target,
            ticks = DISEASE_TICKS,
            amount = DISEASE_DAMAGE_PER_CORPSE * corpseCount,
            effect = AddSpecialEffectTarget("Units\\Undead\\PlagueCloud\\PlagueCloudtarget.mdl", target, "head")
        }
        diseaseInstances[key] = instance

        instance.timer = GameTimer.every(DISEASE_TICK, function()
            if not isAlive(instance.cause) or
                not isAlive(instance.target) or
                not isDiseaseTarget(instance.target, instance.cause) or
                instance.ticks <= 0 then
                if instance.effect then
                    DestroyEffect(instance.effect)
                end
                diseaseInstances[key] = nil
                instance.timer:destroy()
                return
            end

            instance.ticks = instance.ticks - 1
            if GetUnitAbilityLevel(instance.cause, IDS.ULTIMATE_WW_BUFF) <= 0 then
                suppressDamage = true
                TitanDamageSystem.dealDamage(instance.cause, instance.target, instance.amount, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_DISEASE, WEAPON_TYPE_WHOKNOWS)
                suppressDamage = false
            end
        end)
    end

    local function diseaseTick()
        local group = CreateGroup()
        local unit = nil

        GroupEnumUnitsInRect(group, GetWorldBounds(), nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isBubonicus(unit) then
                local state = stateFor(unit)
                local targets = CreateGroup()
                local target = nil

                if state.corpses > 0 and GetUnitAbilityLevel(unit, IDS.ULTIMATE_WW_BUFF) <= 0 then
                    GroupEnumUnitsInRange(targets, GetUnitX(unit), GetUnitY(unit), DISEASE_RADIUS, nil)
                    target = FirstOfGroup(targets)
                    while target do
                        GroupRemoveUnit(targets, target)
                        diseaseTarget(unit, target, state.corpses)
                        target = FirstOfGroup(targets)
                    end
                end
                DestroyGroup(targets)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function spawnCorpse(owner, x, y)
        local corpse = CreateUnit(owner, IDS.CORPSE_SUMMON, x, y, bj_UNIT_FACING)
        UnitApplyTimedLife(corpse, TIMED_LIFE, 10.0)
        return corpse
    end

    local function dropCorpse(unit)
        local state = stateFor(unit)
        local x = GetUnitX(unit)
        local y = GetUnitY(unit)
        local ward = nil

        syncCorpseCount(state)
        if state.corpses <= 0 then
            return
        end

        state.corpses = state.corpses - 1

        local isTerrainDeepWater = rawget(_G, "IsTerrainDeepWater")

        if isTerrainDeepWater and isTerrainDeepWater(x, y) then
            sayToOwner(unit, "|cffff0000You may not spawn Corpse Wards on water.|r")
            spawnCorpse(GetOwningPlayer(unit), x, y)
            updateCorpseAbilities(state)
            return
        end

        ward = CreateUnit(GetOwningPlayer(unit), IDS.CORPSE_WARD, x, y, bj_UNIT_FACING)
        UnitApplyTimedLife(ward, TIMED_LIFE, WARD_DURATION)
        GameTimer.after(WARD_READY_DELAY, function()
            if isAlive(ward) then
                UnitAddAbility(ward, IDS.CORPSE_WARD_ATTACK)
                if maxCorpses(stateFor(unit)) == 6 then
                    SetUnitAbilityLevel(ward, IDS.CORPSE_WARD_ATTACK, 2)
                end
            end
        end)

        updateCorpseAbilities(state)
    end

    local function addSplat(x, y)
        local index = GetRandomInt(1, 6)
        local effect = AddSpecialEffect(NUKE_SPLAT .. I2S(index) .. ".mdx", x, y)

        GameTimer.after(5.0, function()
            if effect then
                DestroyEffect(effect)
            end
        end)
    end

    local function nukeHit(caster, x, y, damaged, damageAmount, stunDuration)
        local group = CreateGroup()
        local unit = nil

        TitanAbilityUtils.effectAt(NUKE_EFFECT, x, y, 1.0)
        addSplat(x, y)

        GroupEnumUnitsInRange(group, x, y, NUKE_SPLASH, nil)
        unit = FirstOfGroup(group)
        while unit do
            local id = GetHandleId(unit)
            local already = damaged[id] or 0.0
            GroupRemoveUnit(group, unit)

            if already < damageAmount and TitanAbilityUtils.isNukable(unit, caster) then
                local factor = 1.0 - ((distanceBetween(x, y, GetUnitX(unit), GetUnitY(unit)) / NUKE_SPLASH) / 2.0)
                local amount = damageAmount * factor

                if amount + already > damageAmount then
                    amount = damageAmount - already
                end

                if amount > 0.0 then
                    local damagedTarget = TitanDamageSystem.dealDamage(
                        caster,
                        unit,
                        amount,
                        ATTACK_TYPE_MAGIC,
                        DAMAGE_TYPE_MAGIC,
                        WEAPON_TYPE_WHOKNOWS
                    )

                    -- Zinc counted every attempted splash toward the per-target
                    -- cap, even when Warcraft rejected the damage event.
                    damaged[id] = already + amount
                    if damagedTarget and isAlive(unit) then
                        stunTimed(unit, stunDuration)
                    end
                end
            end

            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function startNuke(caster)
        local state = stateFor(caster)
        local targetX = GetSpellTargetX()
        local targetY = GetSpellTargetY()
        local launched = 0
        local damaged = {}
        local damageAmount = damageForNuke(caster)
        local stunDuration = stunForNuke(caster)
        local timer = nil

        syncCorpseCount(state)
        if state.corpses <= 0 then
            return
        end

        timer = GameTimer.every(NUKE_LAUNCH_INTERVAL, function()
            local i = 1

            while i <= 2 and launched < NUKE_MISSILE_COUNT do
                local angle = GetRandomReal(0.0, 360.0)
                local distance = GetRandomReal(0.0, NUKE_TARGET_AREA)
                local x = targetX + distance * Cos(angle * bj_DEGTORAD)
                local y = targetY + distance * Sin(angle * bj_DEGTORAD)

                launched = launched + 1
                -- The old xemissiles completed after launch even if Bubonicus
                -- died before impact.
                GameTimer.after(0.40, function()
                    nukeHit(caster, x, y, damaged, damageAmount, stunDuration)
                end)

                i = i + 1
            end

            if launched >= NUKE_MISSILE_COUNT then
                subtractCorpse(caster)
                activeNukes[GetHandleId(caster)] = nil
                timer:destroy()
            end
        end)

        activeNukes[GetHandleId(caster)] = timer
    end

    local function castHeal(caster)
        local state = stateFor(caster)
        local healAmount, healRange = healForLevel(caster)
        local amount = healAmount * 1.33
        local bonus = false
        local group = nil
        local unit = nil

        syncCorpseCount(state)
        if state.corpses > 0 then
            subtractCorpse(caster)
            bonus = true
            UnitStateSystem.heal(caster, amount, { effect = HEAL_EFFECT, attachPoint = "chest" })
            DummyCaster.castTarget(GetOwningPlayer(caster), IDS.HEAL_BUFF, 1, ORDER_BLOODLUST, caster, GetUnitX(caster), GetUnitY(caster), GetUnitFacing(caster), 1.0)
        elseif UnitStateSystem.life(caster) > amount then
            TitanDamageSystem.dealDamage(caster, caster, amount, ATTACK_TYPE_NORMAL, DAMAGE_TYPE_UNIVERSAL, WEAPON_TYPE_WHOKNOWS)
            bonus = true
        else
            return
        end

        group = CreateGroup()
        GroupEnumUnitsInRange(group, GetUnitX(caster), GetUnitY(caster), healRange, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if unit ~= caster and TitanAbilityUtils.isHealable(unit, caster) then
                UnitStateSystem.heal(unit, amount, { effect = HEAL_EFFECT, attachPoint = "chest" })
                if bonus then
                    DummyCaster.castTarget(GetOwningPlayer(caster), IDS.HEAL_BUFF, 1, ORDER_BLOODLUST, unit, GetUnitX(caster), GetUnitY(caster), GetUnitFacing(caster), 1.0)
                end
                createLightningTimed(HEAL_LIGHTNING, caster, unit, 1.0)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function destroyShield(shield)
        if shield.meat then
            DestroyEffect(shield.meat)
        end
        if shield.trail then
            DestroyEffect(shield.trail)
        end
        shield.meat = nil
        shield.trail = nil
    end

    local function setShieldHealth(shield, amount)
        shield.health = amount
        if shield.meat and BlzSetSpecialEffectScale then
            BlzSetSpecialEffectScale(shield.meat, (amount / SHIELD_HEALTH) + 1.25)
        end
        if shield.trail and BlzSetSpecialEffectScale then
            BlzSetSpecialEffectScale(shield.trail, amount / SHIELD_HEALTH)
        end
    end

    local function createShield()
        local shield = {
            health = SHIELD_HEALTH,
            meat = AddSpecialEffect(SHIELD_EFFECT, 0.0, 0.0),
            trail = AddSpecialEffect(SHIELD_TRAIL, 0.0, 0.0)
        }
        setShieldHealth(shield, SHIELD_HEALTH)
        return shield
    end

    local function setShieldPosition(shield, x, y)
        if shield.meat and BlzSetSpecialEffectPosition then
            BlzSetSpecialEffectPosition(shield.meat, x, y, 100.0)
        end
        if shield.trail and BlzSetSpecialEffectPosition then
            BlzSetSpecialEffectPosition(shield.trail, x, y, 20.0)
        end
        shield.x = x
        shield.y = y
    end

    local function removeShield(instance, index)
        local shield = instance.shields[index]
        local last = instance.shields[#instance.shields]

        if not shield then
            return
        end

        UnitApplyTimedLife(CreateUnit(instance.owner, IDS.CORPSE_WARD_CLOUD, shield.x or GetUnitX(instance.caster), shield.y or GetUnitY(instance.caster), 270.0), TIMED_LIFE, 5.0)
        destroyShield(shield)

        instance.shields[index] = last
        instance.shields[#instance.shields] = nil
        if #instance.shields == 0 then
            UnitRemoveAbility(instance.caster, IDS.ULTIMATE_BUFF)
        end
    end

    local function endShields(instance)
        local i = 1

        if instance.timer then
            instance.timer:destroy()
        end
        while i <= #instance.shields do
            destroyShield(instance.shields[i])
            i = i + 1
        end
        activeShields[GetHandleId(instance.caster)] = nil
    end

    local function startUltimate(caster)
        local count = consumeAllCorpses(caster)
        local instance = activeShields[GetHandleId(caster)]
        local i = 1

        if instance then
            endShields(instance)
        end

        if count <= 0 then
            sayToOwner(caster, "|cffff0000Your ultimate ability requires at least one corpse.|r")
            UnitRemoveAbility(caster, IDS.ULTIMATE_BUFF)
            return
        end
        if count > SHIELD_MAX then
            count = SHIELD_MAX
        end

        instance = {
            caster = caster,
            owner = GetOwningPlayer(caster),
            shields = {},
            delta = 0.0
        }

        while i <= count do
            instance.shields[i] = createShield()
            i = i + 1
        end

        instance.timer = GameTimer.every(SHIELD_TICK, function()
            local j = 1

            if not isAlive(instance.caster) or GetUnitAbilityLevel(instance.caster, IDS.ULTIMATE_BUFF) <= 0 or #instance.shields == 0 then
                endShields(instance)
                return
            end

            instance.delta = instance.delta + 6.0
            if instance.delta > 360.0 then
                instance.delta = instance.delta - 360.0
            end

            while j <= #instance.shields do
                local angle = (j - 1) * (360.0 / #instance.shields) + instance.delta
                setShieldPosition(
                    instance.shields[j],
                    GetUnitX(instance.caster) + SHIELD_RADIUS * Cos(angle * bj_DEGTORAD),
                    GetUnitY(instance.caster) + SHIELD_RADIUS * Sin(angle * bj_DEGTORAD)
                )
                j = j + 1
            end
        end)

        activeShields[GetHandleId(caster)] = instance
    end

    local function damageShield(target, source, damage)
        local instance = activeShields[GetHandleId(target)]
        local index = 0
        local shield = nil

        if not instance or #instance.shields == 0 or damage <= 0.0 or source == target then
            return false
        end

        index = GetRandomInt(1, #instance.shields)
        shield = instance.shields[index]
        if shield.health - damage <= 0.405 then
            removeShield(instance, index)
        else
            setShieldHealth(shield, shield.health - damage)
        end

        if BlzSetEventDamage then
            BlzSetEventDamage(0.0)
        end
        return true
    end

    local function learnExhume(unit, level)
        local state = stateFor(unit)
        local group = CreateGroup()
        local ward = nil
        local mound = UnitSpawner.get("TITAN_SPELL_WELL")

        if level <= 1 then
            state.exhumeLevel = 1
            updateCorpseAbilities(state)
            DestroyGroup(group)
            return
        end

        state.exhumeLevel = 2
        if mound and GetUnitAbilityLevel(mound, IDS.MOUND_CORPSE_SPAWN) > 0 then
            SetUnitAbilityLevel(mound, IDS.MOUND_CORPSE_SPAWN, 2)
        end

        GroupEnumUnitsInRect(group, GetWorldBounds(), nil)
        ward = FirstOfGroup(group)
        while ward do
            GroupRemoveUnit(group, ward)
            if GetUnitAbilityLevel(ward, IDS.CORPSE_WARD_ATTACK) == 1 then
                SetUnitAbilityLevel(ward, IDS.CORPSE_WARD_ATTACK, 2)
            end
            ward = FirstOfGroup(group)
        end
        DestroyGroup(group)
        updateCorpseAbilities(state)
    end

    local function unlearnExhume(unit)
        local state = stateFor(unit)
        local group = CreateGroup()
        local ward = nil
        local mound = UnitSpawner.get("TITAN_SPELL_WELL")

        state.exhumeLevel = 0
        if mound and GetUnitAbilityLevel(mound, IDS.MOUND_CORPSE_SPAWN) > 0 then
            SetUnitAbilityLevel(mound, IDS.MOUND_CORPSE_SPAWN, 1)
        end

        GroupEnumUnitsInRect(group, GetWorldBounds(), nil)
        ward = FirstOfGroup(group)
        while ward do
            GroupRemoveUnit(group, ward)
            if GetUnitAbilityLevel(ward, IDS.CORPSE_WARD_ATTACK) == 2 then
                SetUnitAbilityLevel(ward, IDS.CORPSE_WARD_ATTACK, 1)
            end
            ward = FirstOfGroup(group)
        end
        DestroyGroup(group)
        updateCorpseAbilities(state)
    end

    local function onTitanSpawn(playerData, unit)
        local race = playerData and playerData:race() or nil
        local mound = UnitSpawner.get("TITAN_SPELL_WELL")

        if not unit or not race or race:toString() ~= "Bubonicus" then
            return
        end

        if mound then
            UnitAddAbility(mound, IDS.MOUND_CORPSE_SPAWN)
        end

        stateFor(unit)
        updateCorpseAbilities(stateFor(unit))
    end

    local function onSummon()
        local summoner = GetSummoningUnit()
        local summoned = GetSummonedUnit()

        if isBubonicus(summoner) and GetUnitTypeId(summoned) == IDS.CORPSE_SUMMON then
            addCorpse(summoner)
            RemoveUnit(summoned)
        end
    end

    local function onLoaded()
        local loaded = GetTriggerUnit()
        local getTransportUnit = rawget(_G, "GetTransportUnit")
        local transport = nil

        if getTransportUnit then
            transport = getTransportUnit()
        end

        if isBubonicus(transport) and GetUnitTypeId(loaded) == IDS.CORPSE_SUMMON then
            if addCorpse(transport) then
                RemoveUnit(loaded)
            end
        end
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()
        local i = 1

        if abilityId == IDS.NUCLE and isBubonicus(caster) then
            startNuke(caster)
        elseif abilityId == IDS.HEAL and isBubonicus(caster) then
            castHeal(caster)
        elseif abilityId == IDS.ULTIMATE and isBubonicus(caster) then
            startUltimate(caster)
        elseif abilityId == IDS.MINION_NUKE then
            TitanAbilityUtils.bounceNuke(caster, GetSpellTargetUnit(), { abilityId = IDS.MINION_NUKE, effect = NUKE_EFFECT, filter = function(unit, source)
                return TitanAbilityUtils.isNukable(unit, source) and IsUnitVisible(unit, GetOwningPlayer(source))
            end })
        elseif abilityId == IDS.MINION_HEAL then
            TitanAbilityUtils.bounceHeal(caster, caster, { abilityId = IDS.MINION_HEAL, effect = MINION_HEAL_EFFECT })
        else
            while i <= #CORPSE_DROP_ABILITIES do
                if abilityId == CORPSE_DROP_ABILITIES[i] and isBubonicus(caster) then
                    dropCorpse(caster)
                    return
                end
                i = i + 1
            end
        end
    end

    local function onHeroSkill()
        local unit = GetTriggerUnit()
        local abilityId = GetLearnedSkill()

        if not isBubonicus(unit) then
            return
        end

        if abilityId == IDS.EXHUME then
            learnExhume(unit, GetLearnedSkillLevel())
        elseif abilityId == IDS.NUCLE or abilityId == IDS.ULTIMATE then
            updateEnabled(stateFor(unit))
        end
    end

    local function onRetraining(unit)
        if isBubonicus(unit) then
            unlearnExhume(unit)
        end
    end

    local function onDeath()
        local unit = GetTriggerUnit()
        if GetUnitTypeId(unit) == IDS.CORPSE_WARD then
            RemoveUnit(unit)
        end
    end

    local function onDamaged()
        if suppressDamage then
            return
        end
        damageShield(GetTriggerUnit(), GetEventDamageSource(), GetEventDamage())
    end

    RacePickSystem.onTitanSpawn(onTitanSpawn)

    GameTimer.every(DISEASE_TICK / 2.0, diseaseTick)

    local summonTrigger = CreateTrigger()
    local loadTrigger = CreateTrigger()
    local spellTrigger = CreateTrigger()
    local skillTrigger = CreateTrigger()
    local deathTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(summonTrigger, Player(i), EVENT_PLAYER_UNIT_SUMMON, nil)
        TriggerRegisterPlayerUnitEvent(loadTrigger, Player(i), EVENT_PLAYER_UNIT_LOADED, nil)
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(skillTrigger, Player(i), EVENT_PLAYER_HERO_SKILL, nil)
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
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

    TriggerAddAction(summonTrigger, function() guarded(onSummon) end)
    TriggerAddAction(loadTrigger, function() guarded(onLoaded) end)
    TriggerAddAction(spellTrigger, function() guarded(onSpellEffect) end)
    TriggerAddAction(skillTrigger, function() guarded(onHeroSkill) end)
    TriggerAddAction(deathTrigger, function() guarded(onDeath) end)
    TriggerAddAction(damageTrigger, function() guarded(onDamaged) end)

    TomeOfRetraining.register(onRetraining)

    AbilityRegistry.registerRace("Bubonicus", "titan", {
        notes = "Bubonicus abilities ported from BubonicusRace, Bubonicus, BubonicusNuke, BubonicusHeal, BubonicusUltimate, BubonicusNukeMinion and BubonicusHealMinion.",
        abilities = {
            {
                name = "Corpse system",
                source = "library Bubonicus",
                behavior = "Tracks carried corpses, enables nuke/ultimate only while corpses are held, grants disease cloud, supports Exhume upgrades and corpse ward drops."
            },
            {
                name = "Bubonicus Nuke",
                id = IDS.NUCLE,
                source = "library BubonicusNuke",
                behavior = "Consumes one corpse after launching 24 meatwagon splashes around the target point; each target can take up to the level damage and is briefly stunned."
            },
            {
                name = "Bubonicus Heal",
                id = IDS.HEAL,
                source = "library BubonicusHeal",
                behavior = "Consumes a corpse for self-heal and bloodlust bonus, or damages Bubonicus if no corpse is available, then heals allies in range."
            },
            {
                name = "Bubonicus Ultimate",
                id = IDS.ULTIMATE,
                source = "library BubonicusUltimate",
                behavior = "Consumes all corpses to create rotating meat shields that block incoming damage and leave gas clouds when destroyed."
            },
            {
                name = "Bubonicus Minion Nuke",
                id = IDS.MINION_NUKE,
                source = "library BubonicusNukeMinion",
                behavior = "Bounces magic damage between visible valid targets using TitanDamageSystem."
            },
            {
                name = "Bubonicus Minion Heal",
                id = IDS.MINION_HEAL,
                source = "library BubonicusHealMinion",
                behavior = "Bounces healing between wounded allied units using UnitStateSystem."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
