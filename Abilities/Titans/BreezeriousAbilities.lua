if Debug and Debug.beginFile then Debug.beginFile("Abilities/Titans/BreezeriousAbilities") end

OnInit("BreezeriousAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameTimer")
    import.strict("DummyCaster")
    import.strict("UnitStateSystem")
    import.strict("TitanDamageSystem")

    local IDS = {
        BREEZERIOUS = FourCC("E011"),
        MINION = FourCC("U00Y"),
        NUKEMASTER = FourCC("I08S"),
        PASSIVE = FourCC("A0B9"),
        PASSIVE_ATTACK_SPEED = FourCC("A09L"),
        PASSIVE_MOVE_SPEED = FourCC("A0B8"),
        SCOUT = FourCC("A0DB"),
        SCOUT_GUST = FourCC("A0CJ"),
        SCOUT_GUST_BUFF = FourCC("B041"),
        SCOUT_DUMMY = FourCC("n02A"),
        SCOUT_WW_MARK = FourCC("A0H0"),
        WW = FourCC("A0CA"),
        WW_BUFF = FourCC("B03Z"),
        NUCLEAR_TORNADO = FourCC("A094"),
        NUCLEAR_TORNADO_DUMMY = FourCC("u00R"),
        CYCLONE_STUN = FourCC("A09K"),
        CYCLONE_BUFF = FourCC("Bcyc"),
        CYCLONE_BUFF_ALT = FourCC("Bcy2"),
        HEAL = FourCC("A0CT"),
        HEAL_ORB = FourCC("n02B"),
        UNIQUE = FourCC("A0D4"),
        ULTIMATE = FourCC("A0CY"),
        ULTIMATE_CURSE = FourCC("A0D0"),
        ULTIMATE_WIND_GUST = FourCC("u00U"),
        ULTIMATE_DUMMY = FourCC("u00V"),
        MINION_NUKE = FourCC("A0D5"),
        MINION_HEAL = FourCC("A0D6")
    }

    local ORDER_SLOW = 852075
    local ORDER_CYCLONE = 852144
    local ORDER_CURSE = 852190

    local PASSIVE_DURATION = 2.0
    local PASSIVE_DECAY_INTERVAL = 0.25
    local SCOUT_DURATION = 35.0
    local SCOUT_RADIUS = 500.0
    local SCOUT_INTERVAL = 0.12
    local WW_EFFECT = "Model_Ability_BreezeriousStealth.mdx"
    local WW_FADE_TIME = 2.0
    local WW_RADIUS = 500.0
    local WW_CLOUDS = 6
    local WW_INTERVAL = 0.03125
    local NUCLEAR_TICK = 0.03125
    local NUCLEAR_DISTANCE = 700.0
    local NUCLEAR_START_SPEED = 800.0
    local NUCLEAR_MAX_SPEED = 1400.0
    local NUCLEAR_START_AOE = 150.0
    local NUCLEAR_MAX_AOE = 240.0
    local NUCLEAR_START_SCALE = 0.3
    local NUCLEAR_MAX_SCALE = 1.2
    local NUCLEAR_START_STUN = 0.1
    local NUCLEAR_MAX_STUN = 0.75
    local HEAL_MISSILE_EFFECT = "TBAEMissile.mdx"
    local HEAL_DURATION = 10.0
    local HEAL_INTERVAL = 0.03125
    local HEAL_TICKS = 20
    local HEAL_AMOUNT = 60.0 * HEAL_INTERVAL * HEAL_TICKS
    local HEAL_RADIUS = 600.0
    local HEAL_ORB_OFFSET = 400.0
    local HEAL_ROTATION = 20.0 * HEAL_INTERVAL
    local ULTIMATE_DURATION = 45.0
    local ULTIMATE_RADIUS = 3000.0
    local ULTIMATE_INTERVAL = 0.0625
    local ULTIMATE_TRAVEL_DURATION = 8.0
    local ULTIMATE_ROTATION = 40.0 * ULTIMATE_INTERVAL
    local ULTIMATE_CYCLONE_RADIUS = 100.0
    local MINION_BOUNCE_RANGE = 500.0
    local MINION_BOUNCE_DELAY = 0.30
    local MINION_HEAL_RANGE = 600.0
    local MINION_HEAL_DELAY = 0.12
    local MINION_HEAL_EFFECT = "Model_Ability_Minion_Breezerious_Heal.mdx"
    local MINION_NUKE_EFFECT = "Model_AbilityTarget_BreezeriousMinion.mdx"

    local passiveTimers = {}

    local function isAlive(unit)
        return UnitStateSystem.isAlive(unit)
    end

    local function isWard(unit)
        return unit and GetUnitAbilityLevel(unit, FourCC("WARD")) > 0
    end

    local function isInvulnerable(unit)
        return BlzIsUnitInvulnerable and BlzIsUnitInvulnerable(unit)
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

    local function isHealable(unit, caster)
        return isAlive(unit) and
            IsUnitAlly(unit, GetOwningPlayer(caster)) and
            GetOwningPlayer(unit) ~= Player(PLAYER_NEUTRAL_PASSIVE) and
            not IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
            not IsUnitType(unit, UNIT_TYPE_MECHANICAL) and
            not isWard(unit) and
            UnitStateSystem.life(unit) < UnitStateSystem.maxLife(unit)
    end

    local function xFromAngle(x, angle, distance)
        return x + distance * Cos(angle * bj_DEGTORAD)
    end

    local function yFromAngle(y, angle, distance)
        return y + distance * Sin(angle * bj_DEGTORAD)
    end

    local function distanceBetween(x1, y1, x2, y2)
        local dx = x2 - x1
        local dy = y2 - y1
        return SquareRoot(dx * dx + dy * dy)
    end

    local function scaleEffect(effect, scale)
        if effect and BlzSetSpecialEffectScale then
            BlzSetSpecialEffectScale(effect, scale)
        end
    end

    local function setEffectPosition(effect, x, y, z)
        if BlzSetSpecialEffectPosition then
            BlzSetSpecialEffectPosition(effect, x, y, z or 0.0)
        end
    end

    local function effectAt(path, x, y, scale)
        local effect = AddSpecialEffect(path, x, y)
        scaleEffect(effect, scale or 1.0)
        DestroyEffect(effect)
    end

    local function hasNukemaster(caster)
        return TitanDamageSystem.hasItem(caster, IDS.NUKEMASTER)
    end

    local function applyNukemaster(caster, amount)
        if hasNukemaster(caster) then
            return amount * 1.20
        end
        return amount
    end

    local function castTargetDummy(owner, abilityId, level, orderId, target, caster)
        DummyCaster.castTarget(owner, abilityId, level or 1, orderId, target, GetUnitX(caster), GetUnitY(caster), GetUnitFacing(caster), 1.0)
    end

    local function levelOrOne(unit, abilityId)
        local level = GetUnitAbilityLevel(unit, abilityId)
        if level <= 0 then
            return 1
        end
        return level
    end

    local function beginPassiveDecay(unit)
        local id = GetHandleId(unit)

        if passiveTimers[id] then
            passiveTimers[id]:destroy()
        end

        passiveTimers[id] = GameTimer.after(PASSIVE_DURATION, function()
            local decayTimer = nil
            decayTimer = GameTimer.every(PASSIVE_DECAY_INTERVAL, function()
                if not isAlive(unit) then
                    decayTimer:destroy()
                    passiveTimers[id] = nil
                    return
                end

                if GetUnitAbilityLevel(unit, IDS.PASSIVE_ATTACK_SPEED) > 1 and GetUnitAbilityLevel(unit, IDS.PASSIVE_MOVE_SPEED) > 1 then
                    DecUnitAbilityLevel(unit, IDS.PASSIVE_ATTACK_SPEED)
                    DecUnitAbilityLevel(unit, IDS.PASSIVE_MOVE_SPEED)
                else
                    decayTimer:destroy()
                    passiveTimers[id] = nil
                end
            end)
            passiveTimers[id] = decayTimer
        end)
    end

    local function triggerPassive(attacker)
        if GetUnitAbilityLevel(attacker, IDS.PASSIVE_ATTACK_SPEED) <= 0 then
            UnitAddAbility(attacker, IDS.PASSIVE_ATTACK_SPEED)
        end
        if GetUnitAbilityLevel(attacker, IDS.PASSIVE_MOVE_SPEED) <= 0 then
            UnitAddAbility(attacker, IDS.PASSIVE_MOVE_SPEED)
        end

        if GetUnitAbilityLevel(attacker, IDS.PASSIVE_ATTACK_SPEED) < 10 and GetUnitAbilityLevel(attacker, IDS.PASSIVE_MOVE_SPEED) < 10 then
            IncUnitAbilityLevel(attacker, IDS.PASSIVE_ATTACK_SPEED)
            IncUnitAbilityLevel(attacker, IDS.PASSIVE_MOVE_SPEED)
        end
        beginPassiveDecay(attacker)
    end

    local function startScouting(caster)
        local owner = GetOwningPlayer(caster)
        local duration = SCOUT_DURATION + (7.5 * GetUnitAbilityLevel(caster, IDS.UNIQUE))
        local dummy = CreateUnit(owner, IDS.SCOUT_DUMMY, GetUnitX(caster), GetUnitY(caster), GetUnitFacing(caster))
        local elapsed = 0.0
        local timer = nil

        UnitApplyTimedLife(dummy, FourCC("BTLF"), duration)
        timer = GameTimer.every(SCOUT_INTERVAL, function()
            local group = CreateGroup()
            local unit = nil
            elapsed = elapsed + SCOUT_INTERVAL

            if not isAlive(caster) or elapsed >= duration then
                if dummy and GetUnitTypeId(dummy) ~= 0 then
                    RemoveUnit(dummy)
                end
                DestroyGroup(group)
                timer:destroy()
                return
            end

            SetUnitX(dummy, GetUnitX(caster))
            SetUnitY(dummy, GetUnitY(caster))
            SetUnitFacing(dummy, GetUnitFacing(caster))

            if GetUnitAbilityLevel(caster, IDS.WW_BUFF) > 0 then
                UnitAddAbility(dummy, FourCC("Apiv"))
            elseif GetUnitAbilityLevel(dummy, FourCC("Apiv")) > 0 then
                UnitRemoveAbility(dummy, FourCC("Apiv"))
            end

            GroupEnumUnitsInRange(group, GetUnitX(caster), GetUnitY(caster), SCOUT_RADIUS, nil)
            unit = FirstOfGroup(group)
            while unit do
                GroupRemoveUnit(group, unit)
                if isAlive(unit) and
                    IsUnitEnemy(unit, owner) and
                    not IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
                    IsUnitVisible(unit, owner) and
                    GetUnitAbilityLevel(unit, IDS.SCOUT_GUST_BUFF) <= 0 and
                    not isInvulnerable(unit) then
                    castTargetDummy(owner, IDS.SCOUT_GUST, 1, ORDER_SLOW, unit, caster)
                end
                unit = FirstOfGroup(group)
            end
            DestroyGroup(group)
        end)
    end

    local function startWhirlwind(caster)
        local effects = {}
        local angles = {}
        local elapsed = 0.0
        local timer = nil
        local i = 1

        while i <= WW_CLOUDS do
            local angle = (360.0 / WW_CLOUDS) * (i - 1)
            local x = xFromAngle(GetUnitX(caster), angle, WW_RADIUS)
            local y = yFromAngle(GetUnitY(caster), angle, WW_RADIUS)
            effects[i] = AddSpecialEffect(WW_EFFECT, x, y)
            angles[i] = angle
            i = i + 1
        end

        timer = GameTimer.every(WW_INTERVAL, function()
            local distance = WW_RADIUS * (1.0 - (elapsed / WW_FADE_TIME))
            local z = 200.0
            elapsed = elapsed + WW_INTERVAL

            if elapsed >= WW_FADE_TIME then
                local j = 1
                while j <= #effects do
                    if effects[j] then
                        DestroyEffect(effects[j])
                    end
                    j = j + 1
                end
                timer:destroy()
                return
            end

            i = 1
            while i <= #effects do
                angles[i] = angles[i] - 3.0
                setEffectPosition(effects[i], xFromAngle(GetUnitX(caster), angles[i], distance), yFromAngle(GetUnitY(caster), angles[i], distance), z)
                i = i + 1
            end
        end)

        local group = CreateGroup()
        local unit = nil
        GroupEnumUnitsInRange(group, GetUnitX(caster), GetUnitY(caster), 250.0, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if GetUnitTypeId(unit) == IDS.SCOUT_DUMMY then
                UnitAddAbility(unit, IDS.SCOUT_WW_MARK)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function startNuclearTornado(caster)
        local owner = GetOwningPlayer(caster)
        local casterX = GetUnitX(caster)
        local casterY = GetUnitY(caster)
        local targetX = GetSpellTargetX()
        local targetY = GetSpellTargetY()
        local angle = bj_RADTODEG * Atan2(targetY - casterY, targetX - casterX)
        local dummy = CreateUnit(owner, IDS.NUCLEAR_TORNADO_DUMMY, casterX, casterY, bj_UNIT_FACING)
        local unitsHit = {}
        local traveled = 0.0
        local timer = nil
        local level = levelOrOne(caster, IDS.NUCLEAR_TORNADO)
        local damage = applyNukemaster(caster, 105.0 + (25.0 * level))
        local maxStun = NUCLEAR_MAX_STUN

        if GetUnitAbilityLevel(caster, IDS.UNIQUE) > 0 then
            maxStun = NUCLEAR_MAX_STUN * (1.0 + 0.5 * GetUnitAbilityLevel(caster, IDS.UNIQUE))
        end

        SetUnitScale(dummy, NUCLEAR_START_SCALE, NUCLEAR_START_SCALE, NUCLEAR_START_SCALE)
        timer = GameTimer.every(NUCLEAR_TICK, function()
            local percent = traveled / NUCLEAR_DISTANCE
            local speed = NUCLEAR_MAX_SPEED * percent
            local aoe = NUCLEAR_MAX_AOE * percent
            local scale = NUCLEAR_MAX_SCALE * percent
            local stun = maxStun * percent
            local newX = 0.0
            local newY = 0.0
            local group = CreateGroup()
            local unit = nil

            if speed < NUCLEAR_START_SPEED then speed = NUCLEAR_START_SPEED end
            if aoe < NUCLEAR_START_AOE then aoe = NUCLEAR_START_AOE end
            if scale < NUCLEAR_START_SCALE then scale = NUCLEAR_START_SCALE end
            if stun < NUCLEAR_START_STUN then stun = NUCLEAR_START_STUN end

            traveled = traveled + speed * NUCLEAR_TICK
            SetUnitScale(dummy, scale, scale, scale)

            if traveled > NUCLEAR_DISTANCE then
                UnitApplyTimedLife(dummy, FourCC("BTLF"), 0.2)
                DestroyGroup(group)
                timer:destroy()
                return
            end

            newX = GetUnitX(dummy) + (speed * NUCLEAR_TICK) * Cos(angle * bj_DEGTORAD)
            newY = GetUnitY(dummy) + (speed * NUCLEAR_TICK) * Sin(angle * bj_DEGTORAD)
            SetUnitX(dummy, newX)
            SetUnitY(dummy, newY)

            GroupEnumUnitsInRange(group, newX, newY, aoe, nil)
            unit = FirstOfGroup(group)
            while unit do
                local id = GetHandleId(unit)
                GroupRemoveUnit(group, unit)
                if not unitsHit[id] and
                    isAlive(unit) and
                    IsUnitEnemy(unit, owner) and
                    not IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
                    not IsUnitType(unit, UNIT_TYPE_MAGIC_IMMUNE) and
                    not isInvulnerable(unit) then
                    unitsHit[id] = true
                    TitanDamageSystem.dealDamage(caster, unit, damage, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                    if isAlive(unit) then
                        local finalStun = stun
                        if GetUnitAbilityLevel(unit, IDS.SCOUT_GUST_BUFF) > 0 then
                            finalStun = finalStun + 0.5
                        end
                        castTargetDummy(owner, IDS.CYCLONE_STUN, 1, ORDER_CYCLONE, unit, caster)
                        GameTimer.after(finalStun, function()
                            if unit and GetUnitTypeId(unit) ~= 0 then
                                UnitRemoveAbility(unit, IDS.CYCLONE_BUFF)
                                UnitRemoveAbility(unit, IDS.CYCLONE_BUFF_ALT)
                                SetUnitInvulnerable(unit, false)
                            end
                        end)
                    end
                end
                unit = FirstOfGroup(group)
            end
            DestroyGroup(group)
        end)
    end

    local function lowestHealthTargetNear(x, y, radius, caster)
        local group = CreateGroup()
        local unit = nil
        local best = nil
        local bestRatio = 999999.0

        GroupEnumUnitsInRange(group, x, y, radius, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isHealable(unit, caster) and GetUnitTypeId(unit) ~= IDS.HEAL_ORB then
                local ratio = UnitStateSystem.life(unit) / UnitStateSystem.maxLife(unit)
                if ratio < bestRatio then
                    bestRatio = ratio
                    best = unit
                end
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        return best
    end

    local function startHeal(caster)
        local level = levelOrOne(caster, IDS.HEAL)
        local orbCount = level
        local orbHP = 100.0 + (level * 50.0) + (GetUnitAbilityLevel(caster, IDS.UNIQUE) * 75.0)
        local orbs = {}
        local angles = {}
        local elapsed = 0.0
        local tickCount = 0
        local timer = nil
        local i = 1

        while i <= orbCount do
            local angle = (360.0 / orbCount) * i
            local x = xFromAngle(GetUnitX(caster), angle, HEAL_ORB_OFFSET)
            local y = yFromAngle(GetUnitY(caster), angle, HEAL_ORB_OFFSET)
            orbs[i] = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), IDS.HEAL_ORB, x, y, bj_UNIT_FACING)
            if BlzSetUnitMaxHP then
                BlzSetUnitMaxHP(orbs[i], R2I(orbHP))
            end
            SetWidgetLife(orbs[i], orbHP)
            UnitApplyTimedLife(orbs[i], FourCC("BTLF"), HEAL_DURATION)
            angles[i] = angle
            i = i + 1
        end

        timer = GameTimer.every(HEAL_INTERVAL, function()
            local anyOrb = false
            elapsed = elapsed + HEAL_INTERVAL
            tickCount = tickCount + 1

            if elapsed >= HEAL_DURATION or not isAlive(caster) then
                timer:destroy()
                return
            end

            i = 1
            while i <= orbCount do
                local orb = orbs[i]
                if orb and isAlive(orb) then
                    local x = 0.0
                    local y = 0.0
                    anyOrb = true
                    angles[i] = angles[i] + HEAL_ROTATION
                    x = xFromAngle(GetUnitX(caster), angles[i], HEAL_ORB_OFFSET)
                    y = yFromAngle(GetUnitY(caster), angles[i], HEAL_ORB_OFFSET)
                    SetUnitX(orb, x)
                    SetUnitY(orb, y)
                    UnitStateSystem.heal(orb, 4.0 * level * HEAL_INTERVAL, { allowDead = false })

                    if tickCount >= HEAL_TICKS then
                        local target = lowestHealthTargetNear(x, y, HEAL_RADIUS, caster)
                        if target then
                            UnitStateSystem.heal(target, HEAL_AMOUNT, { effect = HEAL_MISSILE_EFFECT, attachPoint = "chest" })
                        end
                    end
                end
                i = i + 1
            end

            if not anyOrb then
                timer:destroy()
            elseif tickCount >= HEAL_TICKS then
                tickCount = 0
            end
        end)
    end

    local function startUltimate(caster)
        local owner = GetOwningPlayer(caster)
        local centerX = GetUnitX(caster)
        local centerY = GetUnitY(caster)
        local elapsed = 0.0
        local unitCreation = 0.0
        local windCreation = 0.0
        local dummyUnits = {}
        local dummyAngles = {}
        local windUnits = {}
        local windAngles = {}
        local windOffsets = {}
        local timer = nil

        windAngles[1] = 0.0
        timer = GameTimer.every(ULTIMATE_INTERVAL, function()
            local i = 1
            elapsed = elapsed + ULTIMATE_INTERVAL
            unitCreation = unitCreation + ULTIMATE_INTERVAL
            windCreation = windCreation + ULTIMATE_INTERVAL

            if elapsed > 1.0 and unitCreation > 1.0 and ULTIMATE_DURATION - elapsed > 1.0 then
                local angle = GetRandomReal(0.0, 360.0)
                local distance = ULTIMATE_RADIUS - GetRandomReal(100.0, 500.0)
                local unit = CreateUnit(owner, IDS.ULTIMATE_DUMMY, xFromAngle(centerX, angle, distance), yFromAngle(centerY, angle, distance), 270.0)
                unitCreation = -2.5
                if elapsed > 8.5 then
                    unitCreation = -0.5
                end
                dummyUnits[#dummyUnits + 1] = unit
                dummyAngles[#dummyAngles + 1] = angle - 180.0
                UnitApplyTimedLife(unit, FourCC("BTLF"), ULTIMATE_DURATION - elapsed)
            end

            while i <= #dummyUnits do
                local unit = dummyUnits[i]
                if unit and GetUnitTypeId(unit) ~= 0 and GetWidgetLife(unit) > 0.405 then
                    local speed = (ULTIMATE_RADIUS / ULTIMATE_TRAVEL_DURATION) * ULTIMATE_INTERVAL
                    local x = GetUnitX(unit) + speed * Cos(dummyAngles[i] * bj_DEGTORAD)
                    local y = GetUnitY(unit) + speed * Sin(dummyAngles[i] * bj_DEGTORAD)
                    local group = CreateGroup()
                    local target = nil
                    if distanceBetween(centerX, centerY, x, y) > ULTIMATE_RADIUS then
                        KillUnit(unit)
                    else
                        SetUnitX(unit, x)
                        SetUnitY(unit, y)
                        GroupEnumUnitsInRange(group, x, y, ULTIMATE_CYCLONE_RADIUS, nil)
                        target = FirstOfGroup(group)
                        while target do
                            GroupRemoveUnit(group, target)
                            if IsUnitEnemy(target, owner) then
                                castTargetDummy(owner, IDS.ULTIMATE_CURSE, 1, ORDER_CURSE, target, caster)
                            end
                            target = FirstOfGroup(group)
                        end
                    end
                    DestroyGroup(group)
                end
                i = i + 1
            end

            if windCreation >= 2.55 then
                local index = #windUnits + 1
                local angle = 0.0
                if index > 1 then
                    angle = windAngles[index - 1] + 60.0
                end
                windCreation = 0.0
                windAngles[index] = angle
                windOffsets[index] = 100.0
                windUnits[index] = CreateUnit(owner, IDS.ULTIMATE_WIND_GUST, xFromAngle(centerX, angle, 100.0), yFromAngle(centerY, angle, 100.0), 270.0)
                UnitApplyTimedLife(windUnits[index], FourCC("BTLF"), ULTIMATE_DURATION - elapsed)
            end

            i = 1
            while i <= #windUnits do
                if windUnits[i] and GetUnitTypeId(windUnits[i]) ~= 0 then
                    windAngles[i] = windAngles[i] + ULTIMATE_ROTATION * 2.0
                    windOffsets[i] = windOffsets[i] + (1500.0 / ULTIMATE_DURATION) * ULTIMATE_INTERVAL
                    if windOffsets[i] >= 1000.0 then
                        windOffsets[i] = windOffsets[i] - 2.0 * (1500.0 / ULTIMATE_DURATION) * ULTIMATE_INTERVAL
                    end
                    SetUnitX(windUnits[i], xFromAngle(centerX, windAngles[i], windOffsets[i]))
                    SetUnitY(windUnits[i], yFromAngle(centerY, windAngles[i], windOffsets[i]))
                end
                i = i + 1
            end

            if elapsed >= ULTIMATE_DURATION then
                i = 1
                while i <= #dummyUnits do
                    if dummyUnits[i] and GetUnitTypeId(dummyUnits[i]) ~= 0 then
                        RemoveUnit(dummyUnits[i])
                    end
                    i = i + 1
                end
                i = 1
                while i <= #windUnits do
                    if windUnits[i] and GetUnitTypeId(windUnits[i]) ~= 0 then
                        RemoveUnit(windUnits[i])
                    end
                    i = i + 1
                end
                timer:destroy()
            end
        end)
    end

    local function closestNukeTarget(x, y, radius, caster, hit)
        local group = CreateGroup()
        local unit = nil
        local best = nil
        local bestDistance = radius + 50.0

        GroupEnumUnitsInRange(group, x, y, radius, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if not hit[GetHandleId(unit)] and isNukable(unit, caster) and IsUnitVisible(unit, GetOwningPlayer(caster)) then
                local distance = distanceBetween(x, y, GetUnitX(unit), GetUnitY(unit))
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

    local function minionNukeDamage(caster)
        local level = levelOrOne(caster, IDS.MINION_NUKE)
        if level == 1 then return 130.0 end
        if level == 2 then return 155.0 end
        return 180.0
    end

    local function minionNukeBounces(caster)
        local level = levelOrOne(caster, IDS.MINION_NUKE)
        if level == 1 then return 4 end
        if level == 2 then return 5 end
        return 6
    end

    local function castMinionNuke(caster)
        local target = GetSpellTargetUnit()
        local hit = {}
        local bounces = 0
        local maxBounces = minionNukeBounces(caster)
        local damage = applyNukemaster(caster, minionNukeDamage(caster))
        local current = target

        local function step()
            -- The first target is separate from the configured number of additional bounces.
            if not current or bounces > maxBounces then
                return
            end
            hit[GetHandleId(current)] = true
            effectAt(MINION_NUKE_EFFECT, GetUnitX(current), GetUnitY(current), 1.0)
            TitanDamageSystem.dealDamage(caster, current, damage, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            bounces = bounces + 1
            current = closestNukeTarget(GetUnitX(current), GetUnitY(current), MINION_BOUNCE_RANGE, caster, hit)
            if current and bounces <= maxBounces then
                GameTimer.after(MINION_BOUNCE_DELAY, step)
            end
        end

        if current and isNukable(current, caster) then
            step()
        end
    end

    local function closestHealTarget(x, y, radius, caster, hit)
        local group = CreateGroup()
        local unit = nil
        local best = nil
        local bestDistance = radius + 50.0

        GroupEnumUnitsInRange(group, x, y, radius, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if not hit[GetHandleId(unit)] and isHealable(unit, caster) then
                local distance = distanceBetween(x, y, GetUnitX(unit), GetUnitY(unit))
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

    local function minionHealAmount(caster)
        local level = levelOrOne(caster, IDS.MINION_HEAL)
        if level == 1 then return 300.0 end
        if level == 2 then return 400.0 end
        if level == 3 then return 500.0 end
        return 600.0
    end

    local function minionHealBounces(caster)
        local level = levelOrOne(caster, IDS.MINION_HEAL)
        if level == 1 then return 1 end
        if level == 2 then return 2 end
        if level == 3 then return 2 end
        return 3
    end

    local function castMinionHeal(caster)
        local hit = {}
        local bounces = 0
        local maxBounces = minionHealBounces(caster)
        local amount = minionHealAmount(caster)
        local current = caster

        local function step()
            if not current or bounces > maxBounces then
                return
            end
            hit[GetHandleId(current)] = true
            UnitStateSystem.heal(current, amount, { effect = MINION_HEAL_EFFECT, attachPoint = "chest" })
            bounces = bounces + 1
            current = closestHealTarget(GetUnitX(current), GetUnitY(current), MINION_HEAL_RANGE, caster, hit)
            if current and bounces <= maxBounces then
                GameTimer.after(MINION_HEAL_DELAY, step)
            end
        end

        step()
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.SCOUT then
            startScouting(caster)
        elseif abilityId == IDS.WW then
            startWhirlwind(caster)
        elseif abilityId == IDS.NUCLEAR_TORNADO then
            startNuclearTornado(caster)
        elseif abilityId == IDS.HEAL then
            startHeal(caster)
        elseif abilityId == IDS.ULTIMATE then
            startUltimate(caster)
        elseif abilityId == IDS.MINION_NUKE then
            castMinionNuke(caster)
        elseif abilityId == IDS.MINION_HEAL then
            castMinionHeal(caster)
        end
    end

    local function onDamaged()
        local attacker = GetEventDamageSource()
        local target = GetTriggerUnit()

        if not attacker or not target then
            return
        end

        if GetUnitAbilityLevel(attacker, IDS.PASSIVE) > 0 and
            BlzGetEventDamageType and BlzGetEventDamageType() == DAMAGE_TYPE_NORMAL and
            IsUnitEnemy(target, GetOwningPlayer(attacker)) then
            triggerPassive(attacker)
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

    TriggerAddAction(spellTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onSpellEffect)
        else
            onSpellEffect()
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

    AbilityRegistry.registerRace("Breezerious", "titan", {
        notes = "Breezerious Titan and Minion abilities ported from BreezeriousPassive, BreezeriousScouting, BreezeriousNuke, BreezeriousWW, BreezeriousHeal, BreezeriousUltimate, BreezeriousNukeMinion and BreezeriousHealMinion.",
        abilities = {
            {
                name = "Swift Winds",
                id = IDS.PASSIVE,
                source = "library BreezeriousPassive",
                behavior = "Normal attacks against enemies stack attack and movement speed bonuses, then decay after a short delay."
            },
            {
                name = "Breezerious Scout",
                id = IDS.SCOUT,
                source = "library BreezeriousScouting",
                behavior = "Creates a following true-sight dummy and periodically gusts visible nearby enemies."
            },
            {
                name = "Cyclone Nuke",
                id = IDS.NUCLEAR_TORNADO,
                source = "library BreezeriousNuke",
                behavior = "Launches a scaling tornado projectile that damages valid enemies through TitanDamageSystem and applies cyclone stun."
            },
            {
                name = "Whirlwind",
                id = IDS.WW,
                source = "library BreezeriousWW",
                behavior = "Creates the old cloud spiral visual and empowers nearby scout dummies."
            },
            {
                name = "Breezerious Heal",
                id = IDS.HEAL,
                source = "library BreezeriousHeal",
                behavior = "Creates rotating healing orbs that heal nearby wounded allies through UnitStateSystem."
            },
            {
                name = "Breezerious Ultimate",
                id = IDS.ULTIMATE,
                source = "library BreezeriousUltimate",
                behavior = "Creates the long storm field with moving wind dummies and cyclone curse casts."
            },
            {
                name = "Breezerious Minion Nuke",
                id = IDS.MINION_NUKE,
                source = "library BreezeriousNukeMinion",
                behavior = "Bounces magic damage between visible valid targets using TitanDamageSystem."
            },
            {
                name = "Breezerious Minion Heal",
                id = IDS.MINION_HEAL,
                source = "library BreezeriousHealMinion",
                behavior = "Bounces healing between allied wounded units using UnitStateSystem."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
