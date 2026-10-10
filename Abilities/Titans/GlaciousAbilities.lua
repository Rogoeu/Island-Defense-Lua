if Debug and Debug.beginFile then Debug.beginFile("Abilities/Titans/GlaciousAbilities") end

OnInit("GlaciousAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameTimer")
    import.strict("DummyCaster")
    import.strict("UnitStateSystem")
    import.strict("TitanDamageSystem")
    import.strict("TitanAbilityUtils")
    import.strict("AbilityMeta")

    local IDS = {
        GLACIOUS = FourCC("E00J"),
        MINION = FourCC("U00D"),
        NUKEMASTER = FourCC("I08S"),
        MIRROR = FourCC("A09J"),
        MIRROR_ALT = FourCC("TGAW"),
        MIRROR_DUMMY = FourCC("o02F"),
        MIRROR_VISION = FourCC("A0BG"),
        MIRROR_TRUE_SIGHT = FourCC("A0BC"),
        FROST_EXPLOSION = FourCC("TGAQ"),
        FROST_EXPLOSION_LEARN = FourCC("A0PL"),
        FROST_SLOW = FourCC("TGA0"),
        HEAL = FourCC("TGAE"),
        UNIQUE = FourCC("TGAR"),
        UNIQUE_DUMMY_EFFECT = FourCC("S002"),
        ICE_SHIELD = FourCC("A0QV"),
        MINION_NUKE = FourCC("TGNQ"),
        MINION_HEAL = FourCC("TGNE"),
        MINION_ULTIMATE = FourCC("TGNF")
    }

    local ORDER_ACID_BOMB = 852662

    local FROST_EFFECT = "Abilities\\Spells\\Undead\\FrostNova\\FrostNovaTarget.mdl"
    local FROST_TARGET_EFFECT = "Abilities\\Weapons\\ZigguratFrostMissile\\ZigguratFrostMissile.mdl"
    local HEAL_EFFECT = "Abilities\\Spells\\Undead\\FrostArmor\\FrostArmorTarget.mdl"

    local MIRROR_DELAY = 2.0
    local MIRROR_DURATION = 22.0
    local MIRROR_TICK = 0.25
    local MIRROR_EMPOWER_RANGE = 1000.0
    local UNIQUE_MIRROR_DURATION = 20.0

    local NUKE_AOE_BASE = 255.0
    local NUKE_AOE_UNIQUE_ONE = 355.0
    local NUKE_AOE_UNIQUE_TWO = 455.0
    local MINION_NUKE_RADIUS = 250.0

    local ICE_SHIELD_TICK = 0.5
    local ICE_SHIELD_MANA_DRAIN_PER_SECOND = 10.0
    local ICE_SHIELD_MANA_DRAIN_PER_DAMAGE = 2.0
    local ICE_SHIELD_MANA_PER_ATTACK = 250.0
    local ICE_SHIELD_COOLDOWN = 15.0
    local ICE_SHIELD_OOM_COOLDOWN = 120.0

    local mirrors = {}
    local iceShieldActive = {}
    local suppressDamage = false

    local function isAlive(unit)
        return UnitStateSystem.isAlive(unit)
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

    local function effectAt(path, x, y, scale, duration)
        local effect = AddSpecialEffect(path, x, y)
        scaleEffect(effect, scale or 1.0)
        if duration and duration > 0.0 then
            GameTimer.after(duration, function()
                if effect then
                    DestroyEffect(effect)
                end
            end)
        else
            DestroyEffect(effect)
        end
    end

    local function isNukable(unit, caster)
        return TitanAbilityUtils.isNukable(unit, caster)
    end

    local function isHealable(unit, caster)
        return TitanAbilityUtils.isHealable(unit, caster)
    end

    local function applyNukemaster(caster, amount)
        return TitanAbilityUtils.applyNukemaster(caster, amount)
    end

    local function frostExplosionDamage(caster)
        local learnLevel = GetUnitAbilityLevel(caster, IDS.FROST_EXPLOSION_LEARN)
        local abilityLevel = GetUnitAbilityLevel(caster, IDS.FROST_EXPLOSION)
        local level = learnLevel

        if level <= 0 then
            level = abilityLevel
        end
        if level <= 0 then
            level = 1
        end

        return applyNukemaster(caster, 105.0 + 25.0 * level)
    end

    local function minionNukeDamage(caster)
        local level = GetUnitAbilityLevel(caster, IDS.MINION_NUKE)
        if level <= 1 then return applyNukemaster(caster, 135.0) end
        if level == 2 then return applyNukemaster(caster, 155.0) end
        return applyNukemaster(caster, 180.0)
    end

    local function nearestMirror(caster)
        local casterX = GetUnitX(caster)
        local casterY = GetUnitY(caster)
        local best = nil
        local bestDistance = 999999.0
        local i = 1

        while i <= #mirrors do
            local mirror = mirrors[i]
            local unit = mirror.unit
            if unit and isAlive(unit) then
                local distance = distanceBetween(casterX, casterY, GetUnitX(unit), GetUnitY(unit))
                if distance < bestDistance then
                    best = mirror
                    bestDistance = distance
                end
            end
            i = i + 1
        end

        return best, bestDistance
    end

    local function addFrostRing(x, y, radius, offset)
        local angle = offset or 0.0
        local i = 0
        while i < 5 do
            effectAt(FROST_EFFECT, xFromAngle(x, angle, radius), yFromAngle(y, angle, radius), 1.0, 0.75)
            angle = angle + 72.0
            i = i + 1
        end
    end

    local function slowTarget(caster, target, level)
        DummyCaster.castTarget(
            GetOwningPlayer(caster),
            IDS.FROST_SLOW,
            level or 1,
            ORDER_ACID_BOMB,
            target,
            GetUnitX(caster),
            GetUnitY(caster),
            GetUnitFacing(caster),
            3.0
        )
    end

    local function castFrostExplosion(caster, x, y, radius)
        local group = CreateGroup()
        local unit = nil
        local damage = frostExplosionDamage(caster)
        local level = GetUnitAbilityLevel(caster, IDS.FROST_EXPLOSION)
        local aoe = radius or NUKE_AOE_BASE

        effectAt(FROST_EFFECT, x, y, 1.75, 1.0)
        if aoe >= NUKE_AOE_UNIQUE_ONE then
            addFrostRing(x, y, 170.0, 0.0)
        end
        if aoe >= NUKE_AOE_UNIQUE_TWO then
            addFrostRing(x, y, 300.0, 36.0)
        end

        GroupEnumUnitsInRange(group, x, y, aoe, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isNukable(unit, caster) then
                TitanDamageSystem.dealDamage(caster, unit, damage, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                slowTarget(caster, unit, level)
                effectAt(FROST_TARGET_EFFECT, GetUnitX(unit), GetUnitY(unit), 1.0)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function cleanupMirror(mirror)
        local i = 1
        while i <= #mirrors do
            if mirrors[i] == mirror then
                table.remove(mirrors, i)
                break
            end
            i = i + 1
        end
        if mirror.timer then
            mirror.timer:destroy()
        end
        if mirror.unit and GetUnitTypeId(mirror.unit) ~= 0 then
            KillUnit(mirror.unit)
            UnitApplyTimedLife(mirror.unit, FourCC("BTLF"), 2.0)
        end
        AbilityMeta.setAreaOfEffect(mirror.caster, IDS.FROST_EXPLOSION, 250.0)
    end

    local function castMirror(caster)
        local mirror = {
            caster = caster,
            unit = CreateUnit(GetOwningPlayer(caster), IDS.MIRROR_DUMMY, GetSpellTargetX(), GetSpellTargetY(), bj_UNIT_FACING),
            elapsed = 0.0,
            addedVision = false,
            empowered = false
        }

        SetUnitAnimation(mirror.unit, "Birth")
        mirrors[#mirrors + 1] = mirror

        mirror.timer = GameTimer.every(MIRROR_TICK, function()
            local distance = 999999.0

            if not isAlive(caster) or not mirror.unit or GetUnitTypeId(mirror.unit) == 0 then
                cleanupMirror(mirror)
                return
            end

            mirror.elapsed = mirror.elapsed + MIRROR_TICK
            distance = distanceBetween(GetUnitX(mirror.unit), GetUnitY(mirror.unit), GetUnitX(caster), GetUnitY(caster))

            if not mirror.addedVision and (mirror.elapsed >= MIRROR_DELAY or distance <= MIRROR_EMPOWER_RANGE) then
                UnitAddAbility(mirror.unit, IDS.MIRROR_VISION)
                UnitAddAbility(mirror.unit, IDS.MIRROR_TRUE_SIGHT)
                mirror.addedVision = true
            end

            if distance <= MIRROR_EMPOWER_RANGE then
                if not mirror.empowered then
                    if GetUnitAbilityLevel(caster, IDS.UNIQUE) == 1 then
                        AbilityMeta.setAreaOfEffect(caster, IDS.FROST_EXPLOSION, 350.0)
                    elseif GetUnitAbilityLevel(caster, IDS.UNIQUE) >= 2 then
                        AbilityMeta.setAreaOfEffect(caster, IDS.FROST_EXPLOSION, 450.0)
                    end
                    mirror.empowered = true
                end
            elseif mirror.empowered then
                AbilityMeta.setAreaOfEffect(caster, IDS.FROST_EXPLOSION, 250.0)
                mirror.empowered = false
            end

            if mirror.elapsed >= MIRROR_DURATION then
                cleanupMirror(mirror)
            end
        end)
    end

    local function castNuke(caster)
        local target = GetSpellTargetUnit()
        local x = GetSpellTargetX()
        local y = GetSpellTargetY()
        local mirror, distance = nearestMirror(caster)
        local aoe = NUKE_AOE_BASE

        if target then
            x = GetUnitX(target)
            y = GetUnitY(target)
        end

        if mirror and distance <= MIRROR_EMPOWER_RANGE and GetUnitAbilityLevel(caster, IDS.UNIQUE) > 0 then
            if GetUnitAbilityLevel(caster, IDS.UNIQUE) == 1 then
                aoe = NUKE_AOE_UNIQUE_ONE
            else
                aoe = NUKE_AOE_UNIQUE_TWO
            end
        else
            AbilityMeta.setAreaOfEffect(caster, IDS.FROST_EXPLOSION, 250.0)
        end

        castFrostExplosion(caster, x, y, aoe)
    end

    local function healAmount(caster, abilityId)
        local level = TitanAbilityUtils.levelOrOne(caster, abilityId)
        if level == 1 then return 300.0 end
        if level == 2 then return 500.0 end
        if level == 3 then return 700.0 end
        return 900.0
    end

    local function castHeal(caster)
        TitanAbilityUtils.areaHeal(caster, GetUnitX(caster), GetUnitY(caster), 650.0, healAmount(caster, IDS.HEAL), HEAL_EFFECT)
    end

    local function castUnique(caster)
        local unit = CreateUnit(GetOwningPlayer(caster), DummyCaster.unitId(), GetSpellTargetX(), GetSpellTargetY(), 270.0)
        local mirror = nil

        UnitAddAbility(unit, IDS.UNIQUE_DUMMY_EFFECT)
        SetUnitAbilityLevel(unit, IDS.UNIQUE_DUMMY_EFFECT, TitanAbilityUtils.levelOrOne(caster, IDS.UNIQUE))
        UnitApplyTimedLife(unit, FourCC("BTLF"), UNIQUE_MIRROR_DURATION)
        mirror = {
            caster = caster,
            unit = unit,
            elapsed = 0.0,
            addedVision = true,
            empowered = true,
            unique = true
        }
        mirrors[#mirrors + 1] = mirror
        AbilityMeta.setAreaOfEffect(caster, IDS.FROST_EXPLOSION, GetUnitAbilityLevel(caster, IDS.UNIQUE) >= 2 and 450.0 or 350.0)

        mirror.timer = GameTimer.after(UNIQUE_MIRROR_DURATION, function()
            cleanupMirror(mirror)
        end)
    end

    local function startIceShield(caster)
        local id = GetHandleId(caster)

        if iceShieldActive[id] and iceShieldActive[id].timer then
            iceShieldActive[id].timer:destroy()
        end

        AbilityMeta.setCooldown(caster, IDS.ICE_SHIELD, 0.0)
        iceShieldActive[id] = {
            unit = caster,
            timer = GameTimer.every(ICE_SHIELD_TICK, function()
                if not isAlive(caster) then
                    if iceShieldActive[id] and iceShieldActive[id].timer then
                        iceShieldActive[id].timer:destroy()
                    end
                    iceShieldActive[id] = nil
                    return
                end

                UnitStateSystem.addMana(caster, -ICE_SHIELD_MANA_DRAIN_PER_SECOND * ICE_SHIELD_TICK)
                if UnitStateSystem.mana(caster) < 50.0 then
                    UnitRemoveAbility(caster, IDS.ICE_SHIELD)
                    UnitAddAbility(caster, IDS.ICE_SHIELD)
                    AbilityMeta.startCooldown(caster, IDS.ICE_SHIELD, ICE_SHIELD_OOM_COOLDOWN)
                    if iceShieldActive[id] and iceShieldActive[id].timer then
                        iceShieldActive[id].timer:destroy()
                    end
                    iceShieldActive[id] = nil
                end
            end)
        }
    end

    local function stopIceShield(caster)
        local id = GetHandleId(caster)
        if iceShieldActive[id] and iceShieldActive[id].timer then
            iceShieldActive[id].timer:destroy()
        end
        iceShieldActive[id] = nil
        AbilityMeta.startCooldown(caster, IDS.ICE_SHIELD, ICE_SHIELD_COOLDOWN)
    end

    local function castMinionNuke(caster, radius)
        local target = GetSpellTargetUnit()
        local x = GetSpellTargetX()
        local y = GetSpellTargetY()
        local group = CreateGroup()
        local unit = nil
        local damage = minionNukeDamage(caster)

        if target then
            x = GetUnitX(target)
            y = GetUnitY(target)
        end

        effectAt(FROST_EFFECT, x, y, 1.0, 1.0)
        GroupEnumUnitsInRange(group, x, y, radius or MINION_NUKE_RADIUS, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isNukable(unit, caster) then
                TitanDamageSystem.dealDamage(caster, unit, damage, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
                slowTarget(caster, unit, GetUnitAbilityLevel(caster, IDS.MINION_NUKE))
                effectAt(FROST_TARGET_EFFECT, GetUnitX(unit), GetUnitY(unit), 1.0)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function castMinionHeal(caster)
        TitanAbilityUtils.bounceHeal(caster, caster, {
            abilityId = IDS.MINION_HEAL,
            effect = HEAL_EFFECT,
            range = 650.0
        })
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.MIRROR or abilityId == IDS.MIRROR_ALT then
            castMirror(caster)
        elseif abilityId == IDS.FROST_EXPLOSION then
            castNuke(caster)
        elseif abilityId == IDS.HEAL then
            castHeal(caster)
        elseif abilityId == IDS.UNIQUE then
            castUnique(caster)
        elseif abilityId == IDS.MINION_NUKE then
            castMinionNuke(caster, MINION_NUKE_RADIUS)
        elseif abilityId == IDS.MINION_HEAL then
            castMinionHeal(caster)
        elseif abilityId == IDS.MINION_ULTIMATE then
            castMinionNuke(caster, 500.0)
        end
    end

    local function onHeroSkill()
        local unit = GetTriggerUnit()
        if GetLearnedSkill() == IDS.FROST_EXPLOSION_LEARN then
            if GetUnitAbilityLevel(unit, IDS.FROST_EXPLOSION) <= 0 then
                UnitAddAbility(unit, IDS.FROST_EXPLOSION)
            else
                IncUnitAbilityLevel(unit, IDS.FROST_EXPLOSION)
            end
        end
    end

    local function onIssuedOrder()
        local caster = GetOrderedUnit()
        local order = GetIssuedOrderId()

        if GetUnitTypeId(caster) == IDS.GLACIOUS then
            if order == OrderId("manashieldon") then
                startIceShield(caster)
            elseif order == OrderId("manashieldoff") then
                stopIceShield(caster)
            end
        end
    end

    local function onDamaged()
        local attacker = GetEventDamageSource()
        local target = GetTriggerUnit()
        local damage = GetEventDamage()
        local targetId = target and GetHandleId(target) or 0

        if suppressDamage or damage <= 0.0 or not attacker or not target or attacker == target then
            return
        end

        if iceShieldActive[GetHandleId(attacker)] and
            IsUnitEnemy(target, GetOwningPlayer(attacker)) and
            rawget(_G, "BlzGetEventDamageType") and BlzGetEventDamageType() == DAMAGE_TYPE_NORMAL then
            UnitStateSystem.addMana(attacker, ICE_SHIELD_MANA_PER_ATTACK)
        end

        if iceShieldActive[targetId] then
            local mana = UnitStateSystem.mana(target)
            local maxMana = UnitStateSystem.maxMana(target)
            local manaPercent = 0.5
            local prevented = 0.0

            if maxMana > 0.0 then
                manaPercent = mana / maxMana
            end
            if manaPercent < 0.5 then
                manaPercent = 0.5
            end

            prevented = damage * manaPercent
            UnitStateSystem.addMana(target, -prevented * ICE_SHIELD_MANA_DRAIN_PER_DAMAGE)
            if rawget(_G, "BlzSetEventDamage") then
                BlzSetEventDamage(damage - prevented)
            else
                suppressDamage = true
                UnitStateSystem.heal(target, prevented)
                suppressDamage = false
            end
        end
    end

    local spellTrigger = CreateTrigger()
    local skillTrigger = CreateTrigger()
    local orderTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(skillTrigger, Player(i), EVENT_PLAYER_HERO_SKILL, nil)
        TriggerRegisterPlayerUnitEvent(orderTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_ORDER, nil)
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
    TriggerAddAction(orderTrigger, function() guarded(onIssuedOrder) end)
    TriggerAddAction(damageTrigger, function() guarded(onDamaged) end)

    AbilityRegistry.registerRace("Glacious", "titan", {
        notes = "Glacious abilities ported from GlaciousTrap, GlaciousNuke, GlaciousHeal, GlaciousUnique, GlaciousUltimate, GlaciousMinionNuke and GlaciousMinionHeal.",
        abilities = {
            {
                name = "Glacial Mirror",
                id = IDS.MIRROR,
                source = "library GlaciousTrap",
                behavior = "Creates a mirror dummy for 22 seconds; after 2 seconds or while close to Glacious it gains vision/true sight and empowers Frost Explosion range."
            },
            {
                name = "Frost Explosion",
                id = IDS.FROST_EXPLOSION,
                source = "library GlaciousNuke",
                behavior = "Deals frost magic damage in 255/355/455 AoE depending on Glacial Mirror and Unique level, and applies the old acid-bomb slow dummy."
            },
            {
                name = "Glacious Heal",
                id = IDS.HEAL,
                source = "library GlaciousHeal",
                behavior = "Heals allied organic non-ward units in 650 AoE through UnitStateSystem."
            },
            {
                name = "Glacious Unique",
                id = IDS.UNIQUE,
                source = "library GlaciousUnique",
                behavior = "Creates the old S002 mirror/empower dummy at the target point for 20 seconds."
            },
            {
                name = "Ice Shield",
                id = IDS.ICE_SHIELD,
                source = "library GlaciousUltimate",
                behavior = "Mana Shield drains mana over time, grants mana on successful normal attacks and reduces incoming damage by current mana percent with mana cost per damage prevented."
            },
            {
                name = "Glacious Minion Nuke",
                id = IDS.MINION_NUKE,
                source = "library GlaciousMinionNuke",
                behavior = "Deals frost magic AoE damage around the target point and applies the old slow dummy."
            },
            {
                name = "Glacious Minion Heal",
                id = IDS.MINION_HEAL,
                source = "library GlaciousMinionHeal",
                behavior = "Bounces frost armor healing between allied wounded units."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
