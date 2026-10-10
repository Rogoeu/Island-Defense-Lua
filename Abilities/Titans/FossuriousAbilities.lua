if Debug and Debug.beginFile then Debug.beginFile("Abilities/Titans/FossuriousAbilities") end

OnInit("FossuriousAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameTimer")
    import.strict("UnitStateSystem")
    import.strict("TitanDamageSystem")
    import.strict("TitanAbilityUtils")
    import.strict("AbilityMeta")
    import.strict("UnitSpawner")
    import.strict("DummyCaster")

    local IDS = {
        FOSSURIOUS = FourCC("E012"),
        MINION = FourCC("U01A"),
        NUKEMASTER = FourCC("I08S"),
        NUKE = FourCC("A0PW"),
        BURROWING = FourCC("A0PY"),
        STEALTH = FourCC("A0PZ"),
        PASSIVE = FourCC("A0Q2"),
        CRYPT_SWARMERS = FourCC("A0Q3"),
        UNIQUE = FourCC("A0Q0"),
        UNIQUE_DUMMY = FourCC("A0QW"),
        BURROW_DUMMY = FourCC("A0QX"),
        ULTIMATE = FourCC("A0QU"),
        MAGIC_IMMUNITY = FourCC("A0QZ"),
        DAMAGE_REDUCTION = FourCC("A0SZ"),
        SCOUT_DUMMY = FourCC("A0C6"),
        SCOUT_DUMMY_BUFF = FourCC("B088"),
        BURROWED_BUFF = FourCC("B07U"),
        CRYPT_SWARMER = FourCC("u019"),
        CRYPT_TUNNEL = FourCC("e01E"),
        COCOON = FourCC("U01B"),
        MINION_NUKE = FourCC("A0DA"),
        MINION_HEAL = FourCC("A0DE"),
        MINION_ULTIMATE = FourCC("A0JM")
    }

    local ORDER_SCOUT_DUMMY = 852066
    local ORDER_BURROW = 852533
    local ORDER_CHANNEL = 852150

    local NUKE_EFFECT = "Model_Ability_Titan_Fossurious_NukeMissile.mdx"
    local NUKE_STRUCTURE_EFFECT = "Model_Ability_Titan_Fossurious_NukeMissile.mdx"
    local TUNNEL_EFFECT = "Objects\\Spawnmodels\\Undead\\ImpaleTargetDust\\ImpaleTargetDust.mdl"
    local HEAL_EFFECT = "ArboriusHealGreen.mdx"

    local NUKE_DISTANCE = 600.0
    local NUKE_SPEED = 1100.0
    local NUKE_COLLISION = 150.0
    local NUKE_STRUCTURE_AOE = 500.0
    local NUKE_STUN = 0.5
    local NUKE_TICK = 0.03125

    local BURROW_NORMAL_STEALTH_DURATION = 8.0
    local BURROW_EXTENDED_STEALTH_DURATION = 40.0
    local BURROW_HEAL_INTERVAL = 0.25
    local BURROW_HEAL_PER_LEVEL = 30.0
    local BURROW_UNBURROW_COOLDOWN = 8.0

    local SWARM_DISTANCE = 450.0
    local SWARM_NORMAL_DURATION = 30.0
    local SWARM_ENHANCED_DURATION = 60.0
    local SWARM_SPEED_DURATION = 5.0
    local SWARM_SPEED_PERCENT = 25.0

    local TUNNEL_EFFECT_DISTANCE = 74.0
    local TUNNEL_RANGE = 250.0
    local TUNNEL_LIFE = 600.0
    local TUNNEL_LEVEL_ONE_DURATION = 12.0
    local TUNNEL_LEVEL_TWO_DURATION = 4.0

    local ULTIMATE_DURATION = 30.0
    local ULTIMATE_TICK = 0.5
    local ULTIMATE_EFFECT_AREA = 500.0
    local ULTIMATE_HEAL_AREA = 650.0
    local ULTIMATE_DAMAGE_PER_OUT_OF_RANGE_COCOON = 15.0

    local MINION_NUKE_RADIUS = 250.0
    local MINION_HEAL_RADIUS = 650.0

    local burrowed = {}
    local burrowTimers = {}
    local uniqueInstances = {}
    local uniqueFinishing = {}
    local cocoonToMinion = {}
    local cocoonToInstance = {}

    local function isAlive(unit)
        return UnitStateSystem.isAlive(unit)
    end

    local function levelOrOne(unit, abilityId)
        return TitanAbilityUtils.levelOrOne(unit, abilityId)
    end

    local function distanceBetween(x1, y1, x2, y2)
        local dx = x2 - x1
        local dy = y2 - y1
        return SquareRoot(dx * dx + dy * dy)
    end

    local function xFromAngle(x, angle, distance)
        return x + distance * Cos(angle * bj_DEGTORAD)
    end

    local function yFromAngle(y, angle, distance)
        return y + distance * Sin(angle * bj_DEGTORAD)
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

    local function effectAt(path, x, y, scale)
        local effect = AddSpecialEffect(path, x, y)
        scaleEffect(effect, scale or 1.0)
        DestroyEffect(effect)
    end

    local function setTimeScalePercent(unit, percent)
        local custom = rawget(_G, "SetUnitTimeScalePercent")
        if custom then
            custom(unit, percent)
        else
            SetUnitTimeScale(unit, (percent or 100.0) / 100.0)
        end
    end

    local function isFossurious(unit)
        return unit and GetUnitTypeId(unit) == IDS.FOSSURIOUS
    end

    local function isFossMinion(unit)
        local id = unit and GetUnitTypeId(unit) or 0
        return id == IDS.MINION or id == IDS.CRYPT_SWARMER
    end

    local function isWard(unit)
        return unit and GetUnitAbilityLevel(unit, FourCC("WARD")) > 0
    end

    local function isNukable(unit, caster)
        return TitanAbilityUtils.isNukable(unit, caster)
    end

    local function isNukableStructure(unit, caster)
        return TitanAbilityUtils.isNukableStructure(unit, caster)
    end

    local function isHealable(unit, caster)
        return TitanAbilityUtils.isHealable(unit, caster) and not isWard(unit)
    end

    local function nukeDamage(caster, abilityId)
        local level = levelOrOne(caster, abilityId or IDS.NUKE)
        local amount = 105.0 + 25.0 * level

        if level == 1 then amount = 130.0 end
        if level == 2 then amount = 155.0 end
        if level == 3 then amount = 180.0 end
        return TitanAbilityUtils.applyNukemaster(caster, amount)
    end

    local function stunTimed(unit, duration)
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

    local function disableAbility(unit, abilityId, disabled)
        local fn = rawget(_G, "BlzUnitDisableAbility")
        if fn then
            fn(unit, abilityId, disabled, false)
        end
    end

    local function setAbilityDuration(unit, abilityId, duration)
        AbilityMeta.setDuration(unit, abilityId, duration)
    end

    local function setAbilityManaCost(unit, abilityId, cost)
        AbilityMeta.setManaCost(unit, abilityId, cost)
    end

    local function castNuke(caster)
        local startX = GetUnitX(caster)
        local startY = GetUnitY(caster)
        local targetX = GetSpellTargetX()
        local targetY = GetSpellTargetY()
        local angle = Atan2(targetY - startY, targetX - startX)
        local x = startX
        local y = startY
        local traveled = 0.0
        local hit = {}
        local structureHit = false
        local effect = AddSpecialEffect(NUKE_EFFECT, x, y)
        local timer = nil
        local damage = nukeDamage(caster, IDS.NUKE)

        setEffectPosition(effect, x, y, 80.0)
        timer = GameTimer.every(NUKE_TICK, function()
            local group = CreateGroup()
            local unit = nil
            local step = NUKE_SPEED * NUKE_TICK

            if structureHit or not isAlive(caster) or traveled >= NUKE_DISTANCE then
                DestroyEffect(effect)
                DestroyGroup(group)
                timer:destroy()
                return
            end

            traveled = traveled + step
            x = x + step * Cos(angle)
            y = y + step * Sin(angle)
            setEffectPosition(effect, x, y, 80.0)

            GroupEnumUnitsInRange(group, x, y, NUKE_COLLISION, nil)
            unit = FirstOfGroup(group)
            while unit do
                local id = GetHandleId(unit)
                GroupRemoveUnit(group, unit)

                if isNukableStructure(unit, caster) then
                    local sx = GetUnitX(unit)
                    local sy = GetUnitY(unit)
                    local splash = CreateGroup()
                    local target = nil

                    structureHit = true
                    effectAt(NUKE_STRUCTURE_EFFECT, sx, sy, 2.45)
                    GroupEnumUnitsInRange(splash, sx, sy, NUKE_STRUCTURE_AOE, nil)
                    target = FirstOfGroup(splash)
                    while target do
                        local targetId = GetHandleId(target)
                        GroupRemoveUnit(splash, target)
                        if isNukable(target, caster) then
                            stunTimed(target, NUKE_STUN)
                            if not hit[targetId] then
                                hit[targetId] = true
                                TitanDamageSystem.dealDamage(caster, target, damage, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                            end
                        end
                        target = FirstOfGroup(splash)
                    end
                    DestroyGroup(splash)
                    break
                elseif not hit[id] and isNukable(unit, caster) then
                    hit[id] = true
                    TitanDamageSystem.dealDamage(caster, unit, damage, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                end

                unit = FirstOfGroup(group)
            end
            DestroyGroup(group)
        end)
    end

    local function burrowHealTick(unit)
        local heal = 5.0 + BURROW_HEAL_PER_LEVEL * levelOrOne(unit, IDS.BURROWING) * BURROW_HEAL_INTERVAL
        UnitStateSystem.heal(unit, heal)
    end

    local function setBurrowed(unit, value)
        local id = GetHandleId(unit)
        local abilities = {
            IDS.PASSIVE,
            IDS.CRYPT_SWARMERS,
            IDS.NUKE,
            IDS.UNIQUE,
            IDS.ULTIMATE,
            FourCC("Amov"),
            FourCC("Aatk")
        }
        local i = 1

        burrowed[id] = value or nil
        while i <= #abilities do
            disableAbility(unit, abilities[i], value)
            i = i + 1
        end
    end

    local function finishBurrowAnimation(unit, isBurrowing)
        GameTimer.after(isBurrowing and 1.0 or 0.75, function()
            if unit and GetUnitTypeId(unit) ~= 0 then
                if isBurrowing then
                    setTimeScalePercent(unit, 0.0)
                else
                    setTimeScalePercent(unit, 100.0)
                    SetUnitAnimation(unit, "stand")
                end
            end
        end)
    end

    local function toggleBurrow(caster)
        local id = GetHandleId(caster)

        if not burrowed[id] then
            setBurrowed(caster, true)
            setTimeScalePercent(caster, 84.0)
            finishBurrowAnimation(caster, true)
            setAbilityManaCost(caster, IDS.BURROWING, 0)
            UnitAddAbility(caster, IDS.MAGIC_IMMUNITY)

            if burrowTimers[id] then
                burrowTimers[id]:destroy()
            end
            burrowTimers[id] = GameTimer.every(BURROW_HEAL_INTERVAL, function()
                if not isAlive(caster) or not burrowed[id] then
                    if burrowTimers[id] then
                        burrowTimers[id]:destroy()
                        burrowTimers[id] = nil
                    end
                    return
                end
                burrowHealTick(caster)
            end)
        else
            local maxLife = UnitStateSystem.maxLife(caster)
            local burstHeal = maxLife * (0.05 + 0.05 * levelOrOne(caster, IDS.BURROWING))

            setBurrowed(caster, false)
            setTimeScalePercent(caster, 15.0)
            finishBurrowAnimation(caster, false)
            if burrowTimers[id] then
                burrowTimers[id]:destroy()
                burrowTimers[id] = nil
            end
            UnitStateSystem.heal(caster, burstHeal)
            UnitRemoveAbility(caster, IDS.BURROWED_BUFF)
            setAbilityManaCost(caster, IDS.BURROWING, 200)
            AbilityMeta.startCooldown(caster, IDS.BURROWING, BURROW_UNBURROW_COOLDOWN)
            UnitRemoveAbility(caster, IDS.MAGIC_IMMUNITY)
        end
    end

    local function castStealth(caster)
        if burrowed[GetHandleId(caster)] then
            setAbilityDuration(caster, IDS.STEALTH, BURROW_EXTENDED_STEALTH_DURATION)
        else
            setAbilityDuration(caster, IDS.STEALTH, BURROW_NORMAL_STEALTH_DURATION)
        end
    end

    local function summonSwarm(caster, count, enhanced)
        local owner = GetOwningPlayer(caster)
        local angleStep = 360.0 / count
        local i = 0
        local group = CreateGroup()

        while i < count do
            local angle = angleStep * i
            local unit = CreateUnit(owner, IDS.CRYPT_SWARMER, GetUnitX(caster), GetUnitY(caster), angle)
            UnitApplyTimedLife(unit, FourCC("BTLF"), enhanced and SWARM_ENHANCED_DURATION or SWARM_NORMAL_DURATION)
            UnitAddAbility(unit, FourCC("A0MF"))
            IssuePointOrder(unit, "move", xFromAngle(GetUnitX(caster), angle, SWARM_DISTANCE), yFromAngle(GetUnitY(caster), angle, SWARM_DISTANCE))
            GroupAddUnit(group, unit)
            i = i + 1
        end

        if enhanced then
            GroupAddUnit(group, caster)
            local unit = FirstOfGroup(group)
            while unit do
                GroupRemoveUnit(group, unit)
                AbilityMeta.increaseMoveSpeedPercent(unit, SWARM_SPEED_DURATION, SWARM_SPEED_PERCENT)
                unit = FirstOfGroup(group)
            end
        end
        DestroyGroup(group)
    end

    local function castCryptSwarmers(caster)
        if GetUnitAbilityLevel(caster, IDS.SCOUT_DUMMY_BUFF) > 0 then
            summonSwarm(caster, 3, true)
        else
            summonSwarm(caster, 1, false)
        end
    end

    local function grantScoutDummyOnKill(killer)
        if killer and GetUnitAbilityLevel(killer, IDS.CRYPT_SWARMERS) > 0 then
            if (not rawget(_G, "BlzGetUnitAbilityCooldownRemaining")) or BlzGetUnitAbilityCooldownRemaining(killer, IDS.CRYPT_SWARMERS) < 1.0 then
                DummyCaster.castTarget(
                    GetOwningPlayer(killer),
                    IDS.SCOUT_DUMMY,
                    1,
                    ORDER_SCOUT_DUMMY,
                    killer,
                    GetUnitX(killer),
                    GetUnitY(killer),
                    GetUnitFacing(killer),
                    1.0
                )
            end
        end
    end

    local function nearbyTunnelOrMound(x, y)
        local group = CreateGroup()
        local unit = nil
        local found = false
        local mound = UnitSpawner.get("TITAN_SPELL_WELL")

        if mound and isAlive(mound) and distanceBetween(x, y, GetUnitX(mound), GetUnitY(mound)) <= TUNNEL_RANGE then
            DestroyGroup(group)
            return true
        end

        GroupEnumUnitsInRange(group, x, y, TUNNEL_RANGE, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isAlive(unit) and GetUnitTypeId(unit) == IDS.CRYPT_TUNNEL then
                found = true
                break
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        return found
    end

    local function createTunnelDust(x, y)
        effectAt(TUNNEL_EFFECT, x + GetRandomReal(-80.0, 80.0), y + GetRandomReal(-80.0, 80.0), GetRandomReal(0.8, 1.65))
    end

    local function cleanupUnique(unit, id, version)
        if uniqueInstances[id] == version then
            uniqueInstances[id] = nil
        end
        if uniqueFinishing[id] == version then
            uniqueFinishing[id] = nil
        end
        if unit and GetUnitTypeId(unit) ~= 0 then
            UnitRemoveAbility(unit, IDS.UNIQUE_DUMMY)
            UnitRemoveAbility(unit, IDS.BURROW_DUMMY)
            disableAbility(unit, IDS.UNIQUE, false)
            setTimeScalePercent(unit, 100.0)
            SetUnitAnimation(unit, "stand")
            ShowUnit(unit, true)
        end
    end

    local function finishTunnel(caster, targetX, targetY, version, channeling)
        local id = GetHandleId(caster)
        local step = 4
        local timer = nil

        uniqueFinishing[id] = version
        timer = GameTimer.every(1.0, function()
            if uniqueInstances[id] ~= version or not isAlive(caster) then
                timer:destroy()
                cleanupUnique(caster, id, version)
                return
            end

            if channeling then
                if step == 4 then
                    UnitAddAbility(caster, IDS.BURROW_DUMMY)
                    IssueImmediateOrderById(caster, ORDER_BURROW)
                    setTimeScalePercent(caster, 84.0)
                elseif step == 3 then
                    setTimeScalePercent(caster, 0.0)
                    ShowUnit(caster, false)
                elseif step == 2 then
                    SetUnitPosition(caster, targetX, targetY)
                    SetUnitX(caster, targetX)
                    SetUnitY(caster, targetY)
                    ShowUnit(caster, true)
                    SelectUnitForPlayerSingle(caster, GetOwningPlayer(caster))
                    IssueImmediateOrderById(caster, ORDER_BURROW)
                    setTimeScalePercent(caster, 15.0)
                end
            else
                step = 0
            end

            createTunnelDust(targetX, targetY)
            step = step - 1
            if step <= 0 then
                timer:destroy()
                cleanupUnique(caster, id, version)
            end
        end)
    end

    local function castUnique(caster)
        local id = GetHandleId(caster)
        local version = (uniqueInstances[id] or 0) + 1
        local startX = GetUnitX(caster)
        local startY = GetUnitY(caster)
        local targetX = GetSpellTargetX()
        local targetY = GetSpellTargetY()
        local distance = distanceBetween(startX, startY, targetX, targetY)
        local effectCount = R2I(distance / TUNNEL_EFFECT_DISTANCE)
        local abilityLevel = levelOrOne(caster, IDS.UNIQUE)
        local tick = 0.25
        local currentX = startX
        local currentY = startY
        local ticksLeft = effectCount
        local channeling = true
        local timer = nil

        if effectCount < 1 then
            effectCount = 1
            ticksLeft = 1
        end
        if abilityLevel == 1 then
            tick = (TUNNEL_LEVEL_ONE_DURATION - 1.0) / effectCount
        else
            tick = (TUNNEL_LEVEL_TWO_DURATION - 1.0) / effectCount
        end
        if tick < 0.03125 then
            tick = 0.03125
        end

        uniqueInstances[id] = version
        if nearbyTunnelOrMound(startX, startY) then
            finishTunnel(caster, targetX, targetY, version, true)
            return
        end

        disableAbility(caster, IDS.UNIQUE, true)
        UnitAddAbility(caster, IDS.UNIQUE_DUMMY)
        SetUnitAbilityLevel(caster, IDS.UNIQUE_DUMMY, abilityLevel)
        IssueImmediateOrderById(caster, ORDER_CHANNEL)

        timer = GameTimer.every(tick, function()
            if uniqueInstances[id] ~= version or not isAlive(caster) then
                channeling = false
                timer:destroy()
                finishTunnel(caster, targetX, targetY, version, channeling)
                return
            end

            currentX = currentX + TUNNEL_EFFECT_DISTANCE * Cos(Atan2(targetY - currentY, targetX - currentX))
            currentY = currentY + TUNNEL_EFFECT_DISTANCE * Sin(Atan2(targetY - currentY, targetX - currentX))
            createTunnelDust(currentX, currentY)
            ticksLeft = ticksLeft - 1

            if ticksLeft <= 0 then
                UnitApplyTimedLife(CreateUnit(GetOwningPlayer(caster), IDS.CRYPT_TUNNEL, startX, startY, GetUnitFacing(caster)), FourCC("BTLF"), TUNNEL_LIFE)
                timer:destroy()
                finishTunnel(caster, targetX, targetY, version, channeling)
            end
        end)
    end

    local function cancelUnique(caster)
        local id = caster and GetHandleId(caster) or 0
        if id ~= 0 and uniqueInstances[id] and uniqueFinishing[id] ~= uniqueInstances[id] then
            uniqueInstances[id] = uniqueInstances[id] + 1
        end
    end

    local function restoreCocoon(cocoon, removeCocoon)
        local id = GetHandleId(cocoon)
        local minion = cocoonToMinion[id]
        local owner = GetOwningPlayer(cocoon)

        cocoonToMinion[id] = nil
        cocoonToInstance[id] = nil
        if minion and GetUnitTypeId(minion) ~= 0 then
            PauseUnit(minion, false)
            ShowUnit(minion, true)
            SetUnitOwner(minion, owner, true)
            SelectUnitAddForPlayer(minion, owner)
        end
        if removeCocoon and cocoon and GetUnitTypeId(cocoon) ~= 0 then
            RemoveUnit(cocoon)
        end
    end

    local function collectGroupUnits(group)
        local units = {}
        local unit = FirstOfGroup(group)

        while unit do
            GroupRemoveUnit(group, unit)
            units[#units + 1] = unit
            unit = FirstOfGroup(group)
        end

        return units
    end

    local function castUltimate(caster)
        local instance = {
            caster = caster,
            elapsed = 0.0,
            cocoons = CreateGroup(),
            total = 0,
            finished = false
        }
        local group = CreateGroup()
        local unit = nil
        local timer = nil

        GroupEnumUnitsInRange(group, GetUnitX(caster), GetUnitY(caster), ULTIMATE_EFFECT_AREA, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isAlive(unit) and isFossMinion(unit) and GetOwningPlayer(unit) == GetOwningPlayer(caster) then
                local selected = IsUnitSelected(unit, GetOwningPlayer(unit))
                local cocoon = nil

                PauseUnit(unit, true)
                ShowUnit(unit, false)
                cocoon = CreateUnit(GetOwningPlayer(unit), IDS.COCOON, GetUnitX(unit), GetUnitY(unit), 0.0)
                if IsUnitType(cocoon, UNIT_TYPE_HERO) and IsUnitType(unit, UNIT_TYPE_HERO) then
                    SetHeroLevel(cocoon, GetHeroLevel(unit), false)
                end
                if selected then
                    SelectUnitAddForPlayer(cocoon, GetOwningPlayer(cocoon))
                end
                cocoonToMinion[GetHandleId(cocoon)] = unit
                cocoonToInstance[GetHandleId(cocoon)] = instance
                GroupAddUnit(instance.cocoons, cocoon)
                instance.total = instance.total + 1
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)

        local function finish()
            local units = nil
            local i = 1
            if instance.finished then
                return
            end
            instance.finished = true

            units = collectGroupUnits(instance.cocoons)
            while i <= #units do
                restoreCocoon(units[i], true)
                i = i + 1
            end
            DestroyGroup(instance.cocoons)
            if timer then
                timer:destroy()
            end
        end

        timer = GameTimer.every(ULTIMATE_TICK, function()
            local units = nil
            local i = 1
            local inRange = 0
            local total = 0

            instance.elapsed = instance.elapsed + ULTIMATE_TICK
            units = collectGroupUnits(instance.cocoons)
            while i <= #units do
                local cocoon = units[i]
                if isAlive(cocoon) then
                    total = total + 1
                    if distanceBetween(GetUnitX(caster), GetUnitY(caster), GetUnitX(cocoon), GetUnitY(cocoon)) <= ULTIMATE_HEAL_AREA then
                        inRange = inRange + 1
                    end
                    GroupAddUnit(instance.cocoons, cocoon)
                else
                    restoreCocoon(cocoon, false)
                end
                i = i + 1
            end

            instance.total = total
            if instance.elapsed >= ULTIMATE_DURATION or total <= 0 or not isAlive(caster) then
                finish()
                return
            end

            if inRange > 0 and isHealable(caster, caster) then
                UnitStateSystem.heal(caster, (UnitStateSystem.maxLife(caster) - UnitStateSystem.life(caster)) * 0.02 * inRange)
            end
            if total > inRange then
                AbilityMeta.addDamageBonus(caster, (total - inRange) * ULTIMATE_DAMAGE_PER_OUT_OF_RANGE_COCOON, ULTIMATE_TICK, false)
            end
        end)
    end

    local function onCocoonDeath()
        local cocoon = GetTriggerUnit()
        local instance = cocoonToInstance[GetHandleId(cocoon)]

        if GetUnitTypeId(cocoon) == IDS.COCOON then
            if instance then
                GroupRemoveUnit(instance.cocoons, cocoon)
                instance.total = instance.total - 1
            end
            restoreCocoon(cocoon, false)
        end
    end

    local function castMinionNuke(caster, radius)
        local x = GetSpellTargetX()
        local y = GetSpellTargetY()
        local group = CreateGroup()
        local unit = nil
        local damage = nukeDamage(caster, IDS.MINION_NUKE)

        effectAt(NUKE_EFFECT, x, y, 1.0)
        GroupEnumUnitsInRange(group, x, y, radius or MINION_NUKE_RADIUS, nil)
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
        local level = levelOrOne(caster, IDS.MINION_HEAL)
        if level == 1 then return 300.0 end
        if level == 2 then return 400.0 end
        if level == 3 then return 500.0 end
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
                UnitStateSystem.heal(unit, amount, { effect = HEAL_EFFECT, attachPoint = "chest" })
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.NUKE then
            castNuke(caster)
        elseif abilityId == IDS.BURROWING then
            toggleBurrow(caster)
        elseif abilityId == IDS.STEALTH then
            castStealth(caster)
        elseif abilityId == IDS.CRYPT_SWARMERS then
            castCryptSwarmers(caster)
        elseif abilityId == IDS.ULTIMATE then
            castUltimate(caster)
        elseif abilityId == IDS.MINION_NUKE then
            castMinionNuke(caster, MINION_NUKE_RADIUS)
        elseif abilityId == IDS.MINION_HEAL then
            castMinionHeal(caster)
        elseif abilityId == IDS.MINION_ULTIMATE then
            castMinionNuke(caster, 450.0)
        end
    end

    local function onSpellChannel()
        if GetSpellAbilityId() == IDS.UNIQUE then
            castUnique(GetTriggerUnit())
        end
    end

    local function onSpellEndcast()
        if GetSpellAbilityId() == IDS.UNIQUE_DUMMY then
            cancelUnique(GetTriggerUnit())
        end
    end

    local function onHeroSkill()
        local unit = GetTriggerUnit()
        local learned = GetLearnedSkill()
        if burrowed[GetHandleId(unit)] and learned ~= IDS.STEALTH and learned ~= IDS.BURROWING and GetUnitAbilityLevel(unit, learned) == 1 then
            disableAbility(unit, learned, true)
        end
    end

    local function onDeath()
        grantScoutDummyOnKill(GetKillingUnit())
    end

    TitanDamageSystem.register({
        direction = "incoming",
        side = "titan",
        multiplier = 0.75,
        predicate = function(context, actor)
            return isFossurious(actor) and burrowed[GetHandleId(actor)]
        end
    })

    local spellTrigger = CreateTrigger()
    local channelTrigger = CreateTrigger()
    local endcastTrigger = CreateTrigger()
    local skillTrigger = CreateTrigger()
    local deathTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(channelTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_CHANNEL, nil)
        TriggerRegisterPlayerUnitEvent(endcastTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_ENDCAST, nil)
        TriggerRegisterPlayerUnitEvent(skillTrigger, Player(i), EVENT_PLAYER_HERO_SKILL, nil)
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
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
    TriggerAddAction(channelTrigger, function() guarded(onSpellChannel) end)
    TriggerAddAction(endcastTrigger, function() guarded(onSpellEndcast) end)
    TriggerAddAction(skillTrigger, function() guarded(onHeroSkill) end)
    TriggerAddAction(deathTrigger, function() guarded(onDeath) end)

    AbilityRegistry.registerRace("Fossurious", "titan", {
        notes = "Fossurious abilities ported from FossuriousNuke, FossuriousHeal, FossuriousScout, FossuriousUnique, FossuriousUlt, FossuriousMinionNuke and FossuriousMinionHeal.",
        abilities = {
            {
                name = "Spasmic Shock",
                id = IDS.NUKE,
                source = "library FossuriousNuke",
                behavior = "Launches the Fossurious missile wave for 600 range. It damages valid units on collision and explodes/stuns around the first structure it hits."
            },
            {
                name = "Burrowing",
                id = IDS.BURROWING,
                source = "library FossuriousHeal",
                behavior = "Toggles burrow state, disables Fossurious actions while burrowed, heals over time, grants magic immunity and reduces incoming damage by 25 percent through TitanDamageSystem."
            },
            {
                name = "Fossurious Stealth",
                id = IDS.STEALTH,
                source = "library FossuriousHeal",
                behavior = "Uses normal duration while unburrowed and extended duration while burrowed."
            },
            {
                name = "Crypt Swarmers",
                id = IDS.CRYPT_SWARMERS,
                source = "library FossuriousScout",
                behavior = "Summons one Crypt Swarmer normally, or three enhanced swarmers if the dummy scout buff is active from a recent kill."
            },
            {
                name = "Crypt Tunnel",
                id = IDS.UNIQUE,
                source = "library FossuriousUnique",
                behavior = "Channels an impale-dust tunnel, leaves a temporary Crypt Tunnel at the start when no tunnel/mound is nearby, then burrows Fossurious to the target point."
            },
            {
                name = "Cocoon",
                id = IDS.ULTIMATE,
                source = "library FossuriousUlt",
                behavior = "Transforms nearby Fossurious minions and Crypt Swarmers into cocoons. Nearby cocoons heal Fossurious from missing life; distant cocoons grant short flat damage bonuses."
            },
            {
                name = "Fossurious Minion Nuke",
                id = IDS.MINION_NUKE,
                source = "library FossuriousMinionNuke",
                behavior = "Deals Fossurious magic AoE damage around the target point using TitanDamageSystem."
            },
            {
                name = "Fossurious Minion Heal",
                id = IDS.MINION_HEAL,
                source = "library FossuriousMinionHeal",
                behavior = "Heals allied organic non-ward units in 650 AoE using UnitStateSystem."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
