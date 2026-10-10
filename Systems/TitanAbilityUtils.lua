if Debug and Debug.beginFile then Debug.beginFile("Systems/TitanAbilityUtils") end

OnInit("TitanAbilityUtils", function(import)
    import.strict("GameTimer")
    import.strict("MissileSystem")
    import.strict("UnitStateSystem")
    import.strict("TitanDamageSystem")
    import.strict("UnitFilter")

    local TitanAbilityUtils = {}

    local NUKEMASTER_ITEM = FourCC("I08S")
    local DEFAULT_EFFECT = "Abilities\\Spells\\Other\\Doom\\DoomDeath.mdl"

    local function isAlive(unit)
        return UnitStateSystem.isAlive(unit)
    end

    local function distanceBetween(x1, y1, x2, y2)
        local dx = x2 - x1
        local dy = y2 - y1
        return SquareRoot(dx * dx + dy * dy)
    end

    local function levelOrOne(unit, abilityId)
        local level = GetUnitAbilityLevel(unit, abilityId)
        if level <= 0 then
            return 1
        end
        return level
    end

    local function scaleEffect(effect, scale)
        if effect and BlzSetSpecialEffectScale then
            BlzSetSpecialEffectScale(effect, scale or 1.0)
        end
    end

    local function effectAt(path, x, y, scale)
        local effect = nil
        if path and path ~= "" then
            effect = AddSpecialEffect(path, x, y)
            scaleEffect(effect, scale or 1.0)
            DestroyEffect(effect)
        end
    end

    local function effectTarget(path, unit, attachPoint, scale)
        local effect = nil
        if path and path ~= "" and unit and GetUnitTypeId(unit) ~= 0 then
            effect = AddSpecialEffectTarget(path, unit, attachPoint or "origin")
            scaleEffect(effect, scale or 1.0)
            DestroyEffect(effect)
        end
    end

    local function createBounceLightning(source, target, code, duration)
        local lightning = nil

        if not source or not target or not code or code == "" then
            return
        end

        if AddLightningEx then
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
        elseif AddLightning then
            lightning = AddLightning(code, true, GetUnitX(source), GetUnitY(source), GetUnitX(target), GetUnitY(target))
        end

        if lightning then
            GameTimer.after(duration or 0.30, function()
                DestroyLightning(lightning)
            end)
        end
    end

    local function nukeDamageForLevel(level)
        if level == 1 then
            return 130.0
        elseif level == 2 then
            return 155.0
        elseif level == 3 then
            return 180.0
        end
        return 105.0 + 25.0 * level
    end

    local function healAmountForLevel(level)
        if level == 1 then
            return 300.0
        elseif level == 2 then
            return 500.0
        elseif level == 3 then
            return 700.0
        end
        return 900.0
    end

    local function bounceCountForLevel(level)
        if level == 1 then
            return 4
        elseif level == 2 then
            return 5
        end
        return 6
    end

    local function healBounceCountForLevel(level)
        if level == 1 then
            return 1
        elseif level == 2 then
            return 2
        elseif level == 3 then
            return 2
        end
        return 3
    end

    local function applyNukemaster(caster, amount)
        if TitanDamageSystem.hasItem(caster, NUKEMASTER_ITEM) then
            return amount * 1.20
        end
        return amount
    end

    function TitanAbilityUtils.isAlive(unit)
        return isAlive(unit)
    end

    function TitanAbilityUtils.isNukable(unit, caster)
        return UnitFilter.isNukable(unit, caster)
    end

    function TitanAbilityUtils.isNukableStructure(unit, caster)
        return UnitFilter.isNukableStructure(unit, caster)
    end

    function TitanAbilityUtils.isHealable(unit, caster)
        return UnitFilter.isHealable(unit, caster)
    end

    function TitanAbilityUtils.levelOrOne(unit, abilityId)
        return levelOrOne(unit, abilityId)
    end

    function TitanAbilityUtils.effectAt(path, x, y, scale)
        effectAt(path, x, y, scale)
    end

    function TitanAbilityUtils.applyNukemaster(caster, amount)
        return applyNukemaster(caster, amount)
    end

    function TitanAbilityUtils.standardNukeDamage(caster, abilityId, amount)
        return applyNukemaster(caster, amount or nukeDamageForLevel(levelOrOne(caster, abilityId)))
    end

    function TitanAbilityUtils.standardHealAmount(caster, abilityId, amount)
        return amount or healAmountForLevel(levelOrOne(caster, abilityId))
    end

    function TitanAbilityUtils.areaNuke(caster, x, y, radius, amount, effectPath, filter)
        local group = CreateGroup()
        local unit = nil
        local damage = amount or 0.0

        effectAt(effectPath or DEFAULT_EFFECT, x, y, 1.0)
        GroupEnumUnitsInRange(group, x, y, radius or 250.0, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if (filter and filter(unit, caster)) or (not filter and TitanAbilityUtils.isNukable(unit, caster)) then
                TitanDamageSystem.dealDamage(caster, unit, damage, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    function TitanAbilityUtils.areaHeal(caster, x, y, radius, amount, effectPath, filter)
        local group = CreateGroup()
        local unit = nil

        GroupEnumUnitsInRange(group, x, y, radius or 600.0, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if (filter and filter(unit, caster)) or (not filter and TitanAbilityUtils.isHealable(unit, caster)) then
                UnitStateSystem.heal(unit, amount or 0.0, { effect = effectPath, attachPoint = "chest" })
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    function TitanAbilityUtils.closestNukeTarget(x, y, radius, caster, hit, filter)
        local group = CreateGroup()
        local unit = nil
        local best = nil
        local bestDistance = (radius or 500.0) + 50.0

        GroupEnumUnitsInRange(group, x, y, radius or 500.0, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if not hit[GetHandleId(unit)] and ((filter and filter(unit, caster)) or (not filter and TitanAbilityUtils.isNukable(unit, caster))) then
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

    function TitanAbilityUtils.closestHealTarget(x, y, radius, caster, hit, filter)
        local group = CreateGroup()
        local unit = nil
        local best = nil
        local bestDistance = (radius or 600.0) + 50.0

        GroupEnumUnitsInRange(group, x, y, radius or 600.0, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if not hit[GetHandleId(unit)] and ((filter and filter(unit, caster)) or (not filter and TitanAbilityUtils.isHealable(unit, caster))) then
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

    function TitanAbilityUtils.bounceNuke(caster, firstTarget, options)
        local hit = {}
        local current = firstTarget
        local bounces = 0
        local maxBounces = options.bounces or bounceCountForLevel(levelOrOne(caster, options.abilityId))
        local range = options.range or 500.0
        local delay = options.delay or 0.30
        local damage = applyNukemaster(caster, options.damage or nukeDamageForLevel(levelOrOne(caster, options.abilityId)))
        local previous = caster
        local previousX = GetUnitX(caster)
        local previousY = GetUnitY(caster)

        local function step()
            local target = current

            -- maxBounces counts jumps after the initial spell target.
            if not target or bounces > maxBounces then
                return
            end

            local function hitTarget()
                hit[GetHandleId(target)] = true
                if options.targetEffect == true then
                    effectTarget(options.effect or DEFAULT_EFFECT, target, options.effectAttachPoint or "origin", options.effectScale or 1.0)
                else
                    effectAt(options.effect or DEFAULT_EFFECT, GetUnitX(target), GetUnitY(target), options.effectScale or 1.0)
                end
                TitanDamageSystem.dealDamage(caster, target, damage, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                bounces = bounces + 1
                previous = target
                previousX = GetUnitX(target)
                previousY = GetUnitY(target)
                current = TitanAbilityUtils.closestNukeTarget(GetUnitX(target), GetUnitY(target), range, caster, hit, options.filter)
                if current and bounces <= maxBounces then
                    GameTimer.after(delay, step)
                end
            end

            if options.missileEffect and options.missileEffect ~= "" then
                MissileSystem.launch({
                    x = previousX,
                    y = previousY,
                    z = options.missileZ or 40.0,
                    targetZ = options.missileTargetZ,
                    terrainRelative = options.missileTerrainRelative == true,
                    target = target,
                    speed = options.missileSpeed or 900.0,
                    collision = options.missileCollision or 16.0,
                    model = options.missileEffect,
                    onImpact = function()
                        hitTarget()
                    end
                })
            else
                if options.lightningEffect and options.lightningEffect ~= "" then
                    createBounceLightning(previous, target, options.lightningEffect, delay)
                end
                hitTarget()
            end
        end

        if current and ((options.filter and options.filter(current, caster)) or (not options.filter and TitanAbilityUtils.isNukable(current, caster))) then
            step()
        end
    end

    function TitanAbilityUtils.bounceHeal(caster, firstTarget, options)
        local hit = {}
        local current = firstTarget or caster
        local bounces = 0
        local maxBounces = options.bounces or healBounceCountForLevel(levelOrOne(caster, options.abilityId))
        local range = options.range or 600.0
        local delay = options.delay or 0.12
        local amount = options.amount or healAmountForLevel(levelOrOne(caster, options.abilityId))

        local function step()
            if not current or bounces > maxBounces then
                return
            end

            hit[GetHandleId(current)] = true
            UnitStateSystem.heal(current, amount, { effect = options.effect, attachPoint = "chest" })
            bounces = bounces + 1
            current = TitanAbilityUtils.closestHealTarget(GetUnitX(current), GetUnitY(current), range, caster, hit, options.filter)
            if current and bounces <= maxBounces then
                GameTimer.after(delay, step)
            end
        end

        step()
    end

    _G.TitanAbilityUtils = TitanAbilityUtils
end)

if Debug and Debug.endFile then Debug.endFile() end
