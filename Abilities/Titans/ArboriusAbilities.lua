if Debug and Debug.beginFile then Debug.beginFile("Abilities/Titans/ArboriusAbilities") end

OnInit("ArboriusAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameTimer")
    import.strict("DummyCaster")
    import.strict("UnitStateSystem")
    import.strict("TitanDamageSystem")
    import.strict("AbilityMeta")

    local IDS = {
        ARBORIUS = FourCC("TITA"),
        MINION = FourCC("TIMA"),
        NUKEMASTER = FourCC("I08S"),
        VISION_TRAIL = FourCC("o03W"),
        VISION_WANDER = FourCC("o03Z"),
        TIMED_LIFE = FourCC("B061"),
        POLLEN_NUKE = FourCC("TAAQ"),
        POLLEN_LEARN = FourCC("A0NJ"),
        POLLEN_MARK_DUMMY = FourCC("A0O1"),
        POLLEN_SLOW_DUMMY = FourCC("A0OB"),
        POLLEN_MARK_BUFF = FourCC("B07A"),
        LUSH_MEADOW = FourCC("A0NW"),
        ENTANGLING_GROWTH = FourCC("A0NQ"),
        ENEMY_INFO = FourCC("A0KQ"),
        DAMAGE_REDUCTION = FourCC("TAAV"),
        ATTACK_SPEED_BURST = FourCC("TAAA"),
        STICKY_SAP_BUFF = FourCC("BTAS"),
        ARBORIUS_ULTIMATE = FourCC("A0P6"),
        WRATHFUL_ROOTS = FourCC("o03O"),
        ROOT_ENTANGLE = FourCC("A0P7"),
        ROOT_DISABLE = FourCC("A0P8"),
        ROOT_DAMAGE_BONUS = FourCC("A0P9"),
        VENGEFUL_ROOTS = FourCC("h02O"),
        MINION_NUKE = FourCC("A0NY"),
        MINION_NUKE_LIST_ID = FourCC("A0A1"),
        MINION_HEAL = FourCC("A0P0")
    }

    local POLLEN_MARK_ORDER = 852190
    local POLLEN_SLOW_ORDER = 852075
    local ROOT_ENTANGLE_ORDER = 852171
    local ROOT_DISABLE_ORDER = 852231
    local ROOT_DAMAGE_BONUS_ORDER = 852066

    local VISION_DURATION = 75.0
    local VISION_WANDER_DISTANCE = 1500.0
    local POLLEN_MARK_RADIUS = 300.0
    local POLLEN_DETONATION_RADIUS = 2000.0
    local POLLEN_SLOW_BASE_DELAY = 6.0
    local POLLEN_EXPLOSION_EFFECT = "ConflagrateGreen.mdx"
    local POLLEN_DETONATION_EFFECT = "ArboriusNukeBlast.mdx"
    local LUSH_DURATION = 9.0
    local LUSH_INTERVAL = 0.5
    local LUSH_RADIUS = 350.0
    local LUSH_EFFECT = "ArboriusHealGreen.mdx"
    local ENTANGLE_CHANCE = 0.15
    local ENTANGLE_DURATION = 6.0
    local ENTANGLE_EFFECT = "Abilities\\Spells\\NightElf\\EntanglingRoots\\EntanglingRootsTarget.mdl"
    local BURST_ATTACKS = 2
    local BURST_DURATION = 3.0
    local ULTIMATE_ROOT_RADIUS = 150.0
    local ULTIMATE_ROOT_STEP = 200.0
    local ULTIMATE_DURATION = 15.0
    local ULTIMATE_EFFECT = "Objects\\Spawnmodels\\NightElf\\EntBirthTarget\\EntBirthTarget.mdl"
    local MINION_NUKE_RADIUS = 250.0
    local MINION_HEAL_RADIUS = 650.0

    local pollenByCaster = {}
    local entangleTimers = {}
    local burstTimers = {}

    local function isAlive(unit)
        return UnitStateSystem.isAlive(unit)
    end

    local function isWard(unit)
        return unit and GetUnitAbilityLevel(unit, FourCC("WARD")) > 0
    end

    local function isNukable(unit, caster)
        local owner = GetOwningPlayer(caster)
        return isAlive(unit) and
            (IsUnitEnemy(unit, owner) or GetOwningPlayer(unit) == Player(PLAYER_NEUTRAL_PASSIVE)) and
            not IsUnitType(unit, UNIT_TYPE_MAGIC_IMMUNE) and
            not IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
            not IsUnitType(unit, UNIT_TYPE_MECHANICAL) and
            not isWard(unit)
    end

    local function isPollenTarget(unit, caster)
        return isAlive(unit) and
            IsUnitEnemy(unit, GetOwningPlayer(caster)) and
            not IsUnitType(unit, UNIT_TYPE_MAGIC_IMMUNE) and
            not IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
            not IsUnitType(unit, UNIT_TYPE_RESISTANT)
    end

    local function isHealable(unit, caster)
        return isAlive(unit) and
            IsUnitAlly(unit, GetOwningPlayer(caster)) and
            GetOwningPlayer(unit) ~= Player(PLAYER_NEUTRAL_PASSIVE) and
            not IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
            not IsUnitType(unit, UNIT_TYPE_MECHANICAL) and
            not isWard(unit) and
            UnitStateSystem.life(unit) < UnitStateSystem.maxLife(unit)
    end

    local function scaleEffect(effect, scale)
        if effect and BlzSetSpecialEffectScale then
            BlzSetSpecialEffectScale(effect, scale)
        end
    end

    local function effectAt(path, x, y, scale)
        local effect = AddSpecialEffect(path, x, y)
        scaleEffect(effect, scale or 1.0)
        DestroyEffect(effect)
    end

    local function xFromAngle(x, angle, distance)
        return x + distance * Cos(angle * bj_DEGTORAD)
    end

    local function yFromAngle(y, angle, distance)
        return y + distance * Sin(angle * bj_DEGTORAD)
    end

    local function damageAmountForPollen(level)
        local damage = 105.0 + 25.0 * (level - 3)
        if damage < 0.0 then
            damage = 0.0
        end
        return damage
    end

    local function damageAmountForMinionNuke(caster, abilityId)
        return 105.0 + 25.0 * GetUnitAbilityLevel(caster, abilityId or IDS.MINION_NUKE)
    end

    local function applyNukemaster(caster, amount)
        if TitanDamageSystem.hasItem(caster, IDS.NUKEMASTER) then
            return amount * 1.20
        end
        return amount
    end

    local function castTargetDummy(owner, abilityId, level, orderId, target, caster)
        -- Create the caster at the marked target, like the old xecast path.
        -- A dummy spawned at Arborius can fail its target order when the target
        -- is outside the owner's current vision.
        DummyCaster.castTarget(owner, abilityId, level or 1, orderId, target,
            GetUnitX(target), GetUnitY(target), GetUnitFacing(caster), 1.0)
    end

    local function cleanupPollen(casterId)
        local data = pollenByCaster[casterId]
        if not data then
            return
        end
        if data.timer then
            data.timer:destroy()
        end
        pollenByCaster[casterId] = nil
    end

    local function expirePollen(caster, casterId)
        local data = pollenByCaster[casterId]
        local i = 1
        local level = 0

        if not data or not isAlive(caster) then
            cleanupPollen(casterId)
            return
        end

        level = GetUnitAbilityLevel(caster, IDS.POLLEN_NUKE)
        if level > 3 then
            SetUnitAbilityLevel(caster, IDS.POLLEN_NUKE, level - 3)
            AbilityMeta.startCooldown(caster, IDS.POLLEN_NUKE, 6.0)
            AbilityMeta.refundManaCostPercent(caster, IDS.POLLEN_NUKE, 0.50, true)
        end

        while i <= #data.targets do
            local unit = data.targets[i]
            if isAlive(unit) and GetUnitAbilityLevel(unit, IDS.POLLEN_MARK_BUFF) > 0 then
                castTargetDummy(data.owner, IDS.POLLEN_SLOW_DUMMY, 1, POLLEN_SLOW_ORDER, unit, caster)
            end
            i = i + 1
        end

        cleanupPollen(casterId)
    end

    local function beginPollen(caster)
        local casterId = GetHandleId(caster)
        local x = GetSpellTargetX()
        local y = GetSpellTargetY()
        local group = CreateGroup()
        local unit = nil
        local level = GetUnitAbilityLevel(caster, IDS.POLLEN_NUKE)
        local delay = POLLEN_SLOW_BASE_DELAY - GetUnitAbilityLevel(caster, IDS.POLLEN_LEARN)
        local data = {
            owner = GetOwningPlayer(caster),
            targets = {},
            targetMap = {}
        }

        if delay < 0.25 then
            delay = 0.25
        end

        cleanupPollen(casterId)
        GroupEnumUnitsInRange(group, x, y, POLLEN_MARK_RADIUS, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isPollenTarget(unit, caster) then
                castTargetDummy(data.owner, IDS.POLLEN_MARK_DUMMY, 1, POLLEN_MARK_ORDER, unit, caster)
                data.targets[#data.targets + 1] = unit
                data.targetMap[GetHandleId(unit)] = true
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)

        data.timer = GameTimer.after(delay, function()
            expirePollen(caster, casterId)
        end)
        pollenByCaster[casterId] = data

        effectAt(POLLEN_EXPLOSION_EFFECT, x, y, 1.5)
        SetUnitAbilityLevel(caster, IDS.POLLEN_NUKE, level + 3)
    end

    local function detonatePollen(caster)
        local casterId = GetHandleId(caster)
        local data = pollenByCaster[casterId]
        local level = GetUnitAbilityLevel(caster, IDS.POLLEN_NUKE)
        local group = CreateGroup()
        local unit = nil
        local x = GetUnitX(caster)
        local y = GetUnitY(caster)
        local damage = applyNukemaster(caster, damageAmountForPollen(level))

        if not data then
            if level > 3 then
                SetUnitAbilityLevel(caster, IDS.POLLEN_NUKE, level - 3)
            end
            DestroyGroup(group)
            return
        end

        GroupEnumUnitsInRange(group, x, y, POLLEN_DETONATION_RADIUS, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            -- Zinc used the saved target group as the authoritative mark.
            -- The visual dummy buff may fail to apply around blocked terrain,
            -- but that must not cancel the detonation damage.
            if isAlive(unit) and data.targetMap[GetHandleId(unit)] then
                TitanDamageSystem.dealDamage(caster, unit, damage, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                UnitRemoveAbility(unit, IDS.POLLEN_MARK_BUFF)
                effectAt(POLLEN_DETONATION_EFFECT, GetUnitX(unit), GetUnitY(unit), 1.65)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)

        SetUnitAbilityLevel(caster, IDS.POLLEN_NUKE, level - 3)
        cleanupPollen(casterId)
    end

    local function createVisionTrail(caster)
        local owner = GetOwningPlayer(caster)
        local count = 3 + R2I(GetHeroLevel(caster) / 2)
        local i = 0

        UnitApplyTimedLife(CreateUnit(owner, IDS.VISION_TRAIL, GetUnitX(caster), GetUnitY(caster), 0), IDS.TIMED_LIFE, VISION_DURATION)
        if count > 10 then
            count = 10
        end

        while i < count do
            local x = GetUnitX(caster)
            local y = GetUnitY(caster)
            local angle = GetRandomReal(0.0, 360.0)
            local dummy = CreateUnit(owner, IDS.VISION_WANDER, x, y, angle)
            UnitApplyTimedLife(dummy, IDS.TIMED_LIFE, VISION_DURATION)
            IssuePointOrder(dummy, "move", xFromAngle(x, angle, VISION_WANDER_DISTANCE), yFromAngle(y, angle, VISION_WANDER_DISTANCE))
            i = i + 1
        end
    end

    local function lushHealPerTick(caster)
        return (45.0 + GetUnitAbilityLevel(caster, IDS.LUSH_MEADOW) * 15.0) * LUSH_INTERVAL
    end

    local function createLushMeadow(caster)
        local x = GetUnitX(caster)
        local y = GetUnitY(caster)
        local effect = AddSpecialEffect(LUSH_EFFECT, x, y)
        local elapsed = 0.0
        local timer = nil

        if BlzSetSpecialEffectTimeScale then
            BlzSetSpecialEffectTimeScale(effect, 0.1)
        end
        scaleEffect(effect, 2.35)

        timer = GameTimer.every(LUSH_INTERVAL, function()
            local group = CreateGroup()
            local unit = nil
            elapsed = elapsed + LUSH_INTERVAL

            GroupEnumUnitsInRange(group, x, y, LUSH_RADIUS, nil)
            unit = FirstOfGroup(group)
            while unit do
                GroupRemoveUnit(group, unit)
                if isHealable(unit, caster) then
                    UnitStateSystem.heal(unit, lushHealPerTick(caster))
                end
                unit = FirstOfGroup(group)
            end
            DestroyGroup(group)

            if elapsed >= LUSH_DURATION then
                DestroyEffect(effect)
                timer:destroy()
            end
        end)
    end

    local function removeEntangle(structure)
        local id = GetHandleId(structure)
        local data = entangleTimers[id]
        if not data then
            return
        end

        UnitRemoveAbility(structure, IDS.DAMAGE_REDUCTION)
        UnitRemoveAbility(structure, IDS.ENEMY_INFO)
        UnitRemoveBuffBJ(FourCC("BTAR"), structure)
        if data.effect then
            DestroyEffect(data.effect)
        end
        entangleTimers[id] = nil
    end

    local function applyBurst(arborius)
        local id = GetHandleId(arborius)
        if burstTimers[id] then
            burstTimers[id]:destroy()
        end

        if GetUnitAbilityLevel(arborius, IDS.ATTACK_SPEED_BURST) <= 0 then
            UnitAddAbility(arborius, IDS.ATTACK_SPEED_BURST)
        end
        if GetUnitAbilityLevel(arborius, IDS.ATTACK_SPEED_BURST) < 7 then
            SetUnitAbilityLevel(arborius, IDS.ATTACK_SPEED_BURST, GetUnitAbilityLevel(arborius, IDS.ATTACK_SPEED_BURST) + BURST_ATTACKS)
        end

        burstTimers[id] = GameTimer.after(BURST_DURATION, function()
            if isAlive(arborius) then
                SetUnitAbilityLevel(arborius, IDS.ATTACK_SPEED_BURST, 1)
                UnitRemoveAbility(arborius, IDS.ATTACK_SPEED_BURST)
            end
            burstTimers[id] = nil
        end)
    end

    local function consumeBurst(arborius)
        local level = GetUnitAbilityLevel(arborius, IDS.ATTACK_SPEED_BURST)
        local id = GetHandleId(arborius)

        if level <= 0 then
            return
        end

        DecUnitAbilityLevel(arborius, IDS.ATTACK_SPEED_BURST)
        if GetUnitAbilityLevel(arborius, IDS.ATTACK_SPEED_BURST) <= 1 then
            UnitRemoveAbility(arborius, IDS.ATTACK_SPEED_BURST)
            if burstTimers[id] then
                burstTimers[id]:destroy()
                burstTimers[id] = nil
            end
        end
    end

    local function tryEntanglingGrowth(arborius, attacker)
        local id = GetHandleId(attacker)
        local data = entangleTimers[id]
        local effect = nil

        if GetRandomReal(0.0, 1.0) > ENTANGLE_CHANCE then
            return
        end

        if not data then
            effect = AddSpecialEffect(ENTANGLE_EFFECT, GetUnitX(attacker), GetUnitY(attacker))
            if BlzSpecialEffectRemoveSubAnimation then
                BlzSpecialEffectRemoveSubAnimation(effect, SUBANIM_TYPE_LARGE)
                BlzSpecialEffectRemoveSubAnimation(effect, SUBANIM_TYPE_MEDIUM)
            end
            scaleEffect(effect, 2.0)

            UnitAddAbility(attacker, IDS.ENEMY_INFO)
            UnitAddAbility(attacker, IDS.DAMAGE_REDUCTION)
            data = { effect = effect }
            entangleTimers[id] = data
        elseif data.timer then
            data.timer:destroy()
        end

        SetUnitAbilityLevel(attacker, IDS.DAMAGE_REDUCTION, GetUnitAbilityLevel(arborius, IDS.ENTANGLING_GROWTH))
        if GetUnitAbilityLevel(attacker, IDS.STICKY_SAP_BUFF) > 0 then
            applyBurst(arborius)
        end

        data.timer = GameTimer.after(ENTANGLE_DURATION, function()
            if attacker and GetUnitTypeId(attacker) ~= 0 then
                removeEntangle(attacker)
            end
        end)
    end

    local function startUltimateCrawler(caster, targetX, targetY, angle)
        local currentX = targetX
        local currentY = targetY
        local elapsed = 0.0
        local effect = nil
        local timer = nil

        timer = GameTimer.every(0.45, function()
            local distX = currentX - targetX
            local distY = currentY - targetY
            local distance = SquareRoot(distX * distX + distY * distY)
            local group = CreateGroup()
            local unit = nil

            elapsed = elapsed + 0.45
            if effect then
                scaleEffect(effect, 1.0)
                DestroyEffect(effect)
            end

            if elapsed >= ULTIMATE_DURATION or not isAlive(caster) then
                timer:destroy()
                DestroyGroup(group)
                return
            end

            if distance > 850.0 then
                angle = angle + 12.0
            elseif distance < 350.0 and elapsed > 2.0 then
                angle = angle - 34.0
            end
            angle = angle + 22.0
            if angle > 360.0 then
                angle = angle - 360.0
            end

            currentX = xFromAngle(currentX, angle, ULTIMATE_ROOT_STEP)
            currentY = yFromAngle(currentY, angle, ULTIMATE_ROOT_STEP)
            effect = AddSpecialEffect(ULTIMATE_EFFECT, currentX, currentY)
            scaleEffect(effect, 1.7)

            GroupEnumUnitsInRange(group, currentX, currentY, ULTIMATE_ROOT_RADIUS, nil)
            unit = FirstOfGroup(group)
            while unit do
                GroupRemoveUnit(group, unit)
                if IsUnitType(unit, UNIT_TYPE_STRUCTURE) and GetUnitAbilityLevel(unit, IDS.DAMAGE_REDUCTION) > 0 then
                    castTargetDummy(GetOwningPlayer(caster), IDS.ROOT_DISABLE, 1, ROOT_DISABLE_ORDER, unit, caster)
                end
                if isNukable(unit, caster) and GetUnitAbilityLevel(unit, FourCC("B06V")) <= 0 then
                    castTargetDummy(GetOwningPlayer(caster), IDS.ROOT_ENTANGLE, 1, ROOT_ENTANGLE_ORDER, unit, caster)
                end
                unit = FirstOfGroup(group)
            end
            DestroyGroup(group)
        end)
    end

    local function castUltimate(caster)
        local x = GetSpellTargetX()
        local y = GetSpellTargetY()
        local facing = GetUnitFacing(caster)
        local i = 0

        DummyCaster.castTarget(GetOwningPlayer(caster), IDS.ROOT_DAMAGE_BONUS, 1, ROOT_DAMAGE_BONUS_ORDER, caster, GetUnitX(caster), GetUnitY(caster), facing, 1.0)
        while i < 4 do
            CreateUnit(GetOwningPlayer(caster), IDS.WRATHFUL_ROOTS, x, y, GetRandomReal(0.0, 360.0))
            i = i + 1
        end

        startUltimateCrawler(caster, x, y, facing + 45.0)
        startUltimateCrawler(caster, x, y, facing + 235.0)
    end

    local function castMinionNuke(caster, abilityId)
        local x = GetSpellTargetX()
        local y = GetSpellTargetY()
        local group = CreateGroup()
        local unit = nil
        local damage = applyNukemaster(caster, damageAmountForMinionNuke(caster, abilityId))

        GroupEnumUnitsInRange(group, x, y, MINION_NUKE_RADIUS, nil)
        effectAt(POLLEN_EXPLOSION_EFFECT, x, y, 1.0)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isNukable(unit, caster) then
                TitanDamageSystem.dealDamage(caster, unit, damage, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function minionHealAmount(caster)
        local level = GetUnitAbilityLevel(caster, IDS.MINION_HEAL)
        if level == 1 then
            return 300.0
        elseif level == 2 then
            return 400.0
        elseif level == 3 then
            return 500.0
        end
        return 600.0
    end

    local function castMinionHeal(caster)
        local group = CreateGroup()
        local unit = nil
        local amount = minionHealAmount(caster)

        GroupEnumUnitsInRange(group, GetUnitX(caster), GetUnitY(caster), MINION_HEAL_RADIUS, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isHealable(unit, caster) then
                UnitStateSystem.heal(unit, amount, { effect = LUSH_EFFECT, attachPoint = "chest" })
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.POLLEN_NUKE then
            if GetUnitAbilityLevel(caster, IDS.POLLEN_NUKE) > 3 then
                detonatePollen(caster)
            else
                beginPollen(caster)
            end
            createVisionTrail(caster)
        elseif abilityId == IDS.LUSH_MEADOW then
            createLushMeadow(caster)
            createVisionTrail(caster)
        elseif abilityId == IDS.ARBORIUS_ULTIMATE then
            castUltimate(caster)
            createVisionTrail(caster)
        elseif abilityId == IDS.MINION_NUKE or abilityId == IDS.MINION_NUKE_LIST_ID then
            castMinionNuke(caster, abilityId)
        elseif abilityId == IDS.MINION_HEAL then
            castMinionHeal(caster)
        elseif abilityId == FourCC("TAAW") then
            createVisionTrail(caster)
        end
    end

    local function onHeroSkill()
        local unit = GetTriggerUnit()
        if GetLearnedSkill() == IDS.POLLEN_LEARN then
            if GetUnitAbilityLevel(unit, IDS.POLLEN_NUKE) == 0 then
                UnitAddAbility(unit, IDS.POLLEN_NUKE)
            else
                IncUnitAbilityLevel(unit, IDS.POLLEN_NUKE)
            end
        end
    end

    local function onDamaged()
        local target = GetTriggerUnit()
        local attacker = GetEventDamageSource()

        if not target or not attacker then
            return
        end

        if GetUnitTypeId(target) == IDS.ARBORIUS and
            GetUnitAbilityLevel(target, IDS.ENTANGLING_GROWTH) > 0 and
            IsUnitEnemy(attacker, GetOwningPlayer(target)) and
            IsUnitType(attacker, UNIT_TYPE_STRUCTURE) then
            tryEntanglingGrowth(target, attacker)
        end

        if GetUnitTypeId(attacker) == IDS.ARBORIUS and
            GetUnitAbilityLevel(attacker, IDS.ATTACK_SPEED_BURST) > 0 and
            IsUnitEnemy(target, GetOwningPlayer(attacker)) and
            BlzGetEventDamageType and BlzGetEventDamageType() == DAMAGE_TYPE_NORMAL then
            consumeBurst(attacker)
        end
    end

    local function onDeath()
        local killer = GetKillingUnit()
        local dying = GetDyingUnit()
        if killer and dying and IsUnitType(dying, UNIT_TYPE_STRUCTURE) and GetUnitAbilityLevel(killer, FourCC("B06W")) > 0 then
            CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), IDS.VENGEFUL_ROOTS, GetUnitX(dying), GetUnitY(dying), 0)
        end
    end

    local spellTrigger = CreateTrigger()
    local skillTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local deathTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(skillTrigger, Player(i), EVENT_PLAYER_HERO_SKILL, nil)
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        i = i + 1
    end

    TriggerAddAction(spellTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onSpellEffect)
        else
            onSpellEffect()
        end
    end)

    TriggerAddAction(skillTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onHeroSkill)
        else
            onHeroSkill()
        end
    end)

    TriggerAddAction(damageTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDamaged)
        else
            onDamaged()
        end
    end)

    TriggerAddAction(deathTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDeath)
        else
            onDeath()
        end
    end)

    AbilityRegistry.registerRace("Arborius", "titan", {
        notes = "Arborius Titan and Minion abilities ported from ArboriusScout, ArboriusNuke, LushMeadow, EntanglingGrowth, ArboriusUltimate, ArboriusMinionNuke and ArboriusMinionHeal.",
        abilities = {
            {
                name = "Vision Trail",
                source = "library ArboriusScout",
                behavior = "Arborius spell casts create a 75 second vision dummy and level-scaling wandering vision sparks."
            },
            {
                name = "Suffocating Pollen",
                id = IDS.POLLEN_NUKE,
                source = "library ArboriusNuke",
                behavior = "First cast marks enemies in 300 AoE; second cast performs the Zinc 2000-AoE group check and detonates marked enemies for magic damage. If not recast, it slows marked units and refunds half mana."
            },
            {
                name = "Lush Meadow",
                id = IDS.LUSH_MEADOW,
                source = "library LushMeadow",
                behavior = "Heals allied organic non-ward units in 350 AoE for 9 seconds using UnitStateSystem instead of negative damage."
            },
            {
                name = "Entangling Growth",
                id = IDS.ENTANGLING_GROWTH,
                source = "library EntanglingGrowth",
                behavior = "Enemy structures attacking Arborius have a 15 percent chance to be entangled for 6 seconds; Sticky Sap grants Arborius a short attack speed burst."
            },
            {
                name = "Wrath of the Roots",
                id = IDS.ARBORIUS_ULTIMATE,
                source = "library ArboriusUltimate",
                behavior = "Creates Wrathful Roots, crawling roots that entangle valid targets, disables entangled structures and enables Vengeful Roots from structure kills."
            },
            {
                name = "Arborius Minion Nuke",
                id = IDS.MINION_NUKE,
                source = "library ArboriusMinionNuke",
                behavior = "Deals Arborius-style magic AoE damage around the target point using TitanDamageSystem."
            },
            {
                name = "Arborius Minion Heal",
                id = IDS.MINION_HEAL,
                source = "library ArboriusMinionHeal",
                behavior = "Heals allied organic non-ward units in 650 AoE using UnitStateSystem."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
