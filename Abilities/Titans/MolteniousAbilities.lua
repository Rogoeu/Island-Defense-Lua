if Debug and Debug.beginFile then Debug.beginFile("Abilities/Titans/MolteniousAbilities") end

OnInit("MolteniousAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameTimer")
    import.strict("DummyCaster")
    import.strict("UnitStateSystem")
    import.strict("TitanDamageSystem")
    import.strict("TitanAbilityUtils")

    local IDS = {
        MOLTENIOUS = FourCC("E00C"),
        MINION = FourCC("U003"),
        NUKEMASTER = FourCC("I08S"),
        NUKE = FourCC("TMAQ"),
        HEAL = FourCC("TMAE"),
        STEALTH = FourCC("TMAW"),
        UNIQUE = FourCC("TMAR"),
        HIDDEN_UNIQUE = FourCC("A0NE"),
        BURN = FourCC("A0NF"),
        AMP_BUFF = FourCC("B03Q"),
        ULTIMATE = FourCC("A0NG"),
        ULTIMATE_CHANNEL_BUFF = FourCC("A0NZ"),
        MAGMIDE = FourCC("n008"),
        PHOENIX_SCOUT = FourCC("tMT1"),
        MINION_NUKE = FourCC("TMNQ"),
        MINION_HEAL = FourCC("TMNE"),
        MINION_STEALTH = FourCC("TMNW"),
        MINION_ULTIMATE = FourCC("TMNF")
    }

    local ORDER_BURN = 852609

    local EXPLOSION_EFFECT = "Objects\\Spawnmodels\\Other\\NeutralBuildingExplosion\\NeutralBuildingExplosion.mdl"
    local UNIQUE_EFFECT = "Abilities\\Spells\\Human\\FlameStrike\\FlameStrikeDamageTarget.mdl"
    local HEAL_EFFECT = "Abilities\\Spells\\Human\\MarkOfChaos\\MarkOfChaosTarget.mdl"
    local MINION_HEAL_EFFECT = "Abilities\\Spells\\Other\\Doom\\DoomDeath.mdl"

    local UNIQUE_INTERVAL = 0.5
    local UNIQUE_RANGE = 250.0
    local UNIQUE_DAMAGE_PER_LEVEL = 5.0
    local UNIQUE_AMPLIFIER = 2.0

    local MAGMIDE_LEASH_RANGE = 850.0
    local MAGMIDE_OFFSET = 150.0
    local MAGMIDE_DAMAGE_PER_LEVEL = 10.0
    local ULTIMATE_HEAL_INTERVAL = 1.75
    local ULTIMATE_HEAL_AMOUNT = 350.0
    local NUKE_BOUNCE_RANGE = 500.0
    local NUKE_BOUNCE_DELAY = 0.30

    local uniqueTimers = {}
    local magmideData = {}
    local molteniousToMagmide = {}
    local phoenixByCaster = {}
    local phoenixCasterByUnit = {}
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

    local function effectAt(path, x, y)
        DestroyEffect(AddSpecialEffect(path, x, y))
    end

    local function effectTarget(path, unit, attachPoint)
        DestroyEffect(AddSpecialEffectTarget(path, unit, attachPoint or "origin"))
    end

    local function isNukable(unit, caster)
        return TitanAbilityUtils.isNukable(unit, caster) and IsUnitVisible(unit, GetOwningPlayer(caster))
    end

    local function isHealable(unit, caster)
        return TitanAbilityUtils.isHealable(unit, caster)
    end

    local function hasHiddenBuff(unit)
        return GetUnitAbilityLevel(unit, FourCC("B00P")) > 0 or
            GetUnitAbilityLevel(unit, FourCC("A0MO")) > 0 or
            GetUnitAbilityLevel(unit, FourCC("BOwk")) > 0
    end

    local function cliffDifference(source, target)
        local diff = GetTerrainCliffLevel(GetUnitX(source), GetUnitY(source)) -
            GetTerrainCliffLevel(GetUnitX(target), GetUnitY(target))

        if diff < 0 then
            diff = -diff
        end

        return diff
    end

    local function sameCliffOrWall(source, target)
        return cliffDifference(source, target) == 0 or GetUnitAbilityLevel(target, FourCC("WALL")) > 0
    end

    local function sameCliffOrNonTower(source, target)
        return cliffDifference(source, target) == 0 or GetUnitAbilityLevel(target, FourCC("TOWR")) <= 0
    end

    local function fireDamage(caster, target, amount)
        if amount <= 0.0 then
            return
        end

        TitanDamageSystem.dealDamage(caster, target, amount, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
        effectTarget(UNIQUE_EFFECT, target, "origin")
    end

    local function uniqueAuraTick(source, ownerAbilityLevel, magmideRules)
        local group = CreateGroup()
        local unit = nil
        local level = ownerAbilityLevel or GetUnitAbilityLevel(source, IDS.UNIQUE)
        local baseDamage = 5.0 + UNIQUE_DAMAGE_PER_LEVEL * level

        if not isAlive(source) or level <= 0 or hasHiddenBuff(source) then
            DestroyGroup(group)
            return
        end

        GroupEnumUnitsInRange(group, GetUnitX(source), GetUnitY(source), UNIQUE_RANGE, nil)
        unit = FirstOfGroup(group)
        while unit do
            local damage = baseDamage

            GroupRemoveUnit(group, unit)
            if not IsUnitAlly(unit, GetOwningPlayer(source)) and
                IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
                not IsUnitType(unit, UNIT_TYPE_MAGIC_IMMUNE) and
                ((magmideRules and sameCliffOrNonTower(source, unit)) or (not magmideRules and sameCliffOrWall(source, unit))) then
                if magmideRules then
                    damage = 5.0 + MAGMIDE_DAMAGE_PER_LEVEL
                end
                if GetUnitAbilityLevel(unit, IDS.AMP_BUFF) > 0 then
                    damage = damage * UNIQUE_AMPLIFIER
                end
                fireDamage(source, unit, damage)
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function startUniqueAura(unit)
        local id = GetHandleId(unit)

        if uniqueTimers[id] then
            return
        end

        UnitAddAbility(unit, IDS.HIDDEN_UNIQUE)
        uniqueTimers[id] = GameTimer.every(UNIQUE_INTERVAL, function()
            if not isAlive(unit) or GetUnitAbilityLevel(unit, IDS.UNIQUE) <= 0 then
                if uniqueTimers[id] then
                    uniqueTimers[id]:destroy()
                    uniqueTimers[id] = nil
                end
                return
            end
            uniqueAuraTick(unit)
        end)
    end

    local function castBurn(caster, target)
        local dummy = nil
        if not target or not isAlive(target) then
            return
        end

        dummy = CreateUnit(GetOwningPlayer(caster), DummyCaster.unitId(), GetUnitX(target), GetUnitY(target), 0.0)
        UnitAddAbility(dummy, IDS.BURN)
        SetUnitAbilityLevel(dummy, IDS.BURN, TitanAbilityUtils.levelOrOne(caster, IDS.NUKE))
        IssueTargetOrderById(dummy, ORDER_BURN, target)
        UnitApplyTimedLife(dummy, FourCC("BTLF"), 2.2)
    end

    local function castMolteniousNuke(caster, firstTarget)
        local hit = {}
        local current = firstTarget
        local bounces = 0
        local maxBounces = nil
        local level = TitanAbilityUtils.levelOrOne(caster, IDS.NUKE)
        local damage = TitanAbilityUtils.standardNukeDamage(caster, IDS.NUKE)

        if level == 1 then
            maxBounces = 4
        elseif level == 2 then
            maxBounces = 5
        else
            maxBounces = 6
        end

        local function step()
            local x = 0.0
            local y = 0.0

            -- The first target is separate from the configured number of additional bounces.
            if not current or bounces > maxBounces then
                return
            end

            x = GetUnitX(current)
            y = GetUnitY(current)
            hit[GetHandleId(current)] = true
            effectTarget(EXPLOSION_EFFECT, current, "origin")
            TitanDamageSystem.dealDamage(caster, current, damage, ATTACK_TYPE_MAGIC, DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            if GetUnitAbilityLevel(current, IDS.AMP_BUFF) > 0 then
                castBurn(caster, current)
            end

            bounces = bounces + 1
            current = TitanAbilityUtils.closestNukeTarget(x, y, NUKE_BOUNCE_RANGE, caster, hit, isNukable)
            if current and bounces <= maxBounces then
                GameTimer.after(NUKE_BOUNCE_DELAY, step)
            end
        end

        if current and isNukable(current, caster) then
            step()
        end
    end

    local function castBounceNuke(caster, firstTarget, abilityId)
        TitanAbilityUtils.bounceNuke(caster, firstTarget, {
            abilityId = abilityId,
            effect = EXPLOSION_EFFECT,
            targetEffect = true,
            effectAttachPoint = "origin",
            chainEffect = false,
            filter = isNukable
        })
    end

    local function castHeal(caster)
        TitanAbilityUtils.areaHeal(caster, GetUnitX(caster), GetUnitY(caster), 600.0, TitanAbilityUtils.standardHealAmount(caster, IDS.HEAL), HEAL_EFFECT)
    end

    local function castMinionHeal(caster)
        TitanAbilityUtils.bounceHeal(caster, caster, {
            abilityId = IDS.MINION_HEAL,
            effect = MINION_HEAL_EFFECT,
            filter = isHealable
        })
    end

    local function isWalkable(x, y)
        local terrainFn = rawget(_G, "IsTerrainWalkable")
        local pathableFn = rawget(_G, "IsTerrainPathable")

        if terrainFn then
            return terrainFn(x, y)
        end
        if pathableFn then
            return not pathableFn(x, y, PATHING_TYPE_WALKABILITY)
        end
        return true
    end

    local function copyItemsToMagmide(moltenious, magmide)
        local slot = 0

        while slot < 6 do
            local item = UnitItemInSlot(moltenious, slot)
            local itemId = item and GetItemTypeId(item) or 0

            if itemId ~= 0 and itemId ~= FourCC("I00P") and itemId ~= FourCC("I07A") then
                UnitAddItemById(magmide, itemId)
            end
            slot = slot + 1
        end
    end

    local function removeMagmideItems(magmide)
        local slot = 0

        if not magmide or GetUnitTypeId(magmide) == 0 then
            return
        end

        while slot < 6 do
            local item = UnitItemInSlot(magmide, slot)
            if item then
                RemoveItem(item)
            end
            slot = slot + 1
        end
    end

    local function showMagmideSpawnEffects(magmide)
        if magmide and GetUnitTypeId(magmide) ~= 0 then
            effectTarget(MINION_HEAL_EFFECT, magmide, "chest")
            effectTarget(EXPLOSION_EFFECT, magmide, "chest")
        end
    end

    local function isUltimateHealTarget(unit, caster)
        return isAlive(unit) and
            IsUnitType(unit, UNIT_TYPE_HERO) and
            IsUnitAlly(unit, GetOwningPlayer(caster))
    end

    local function healUltimateAllies(caster)
        local group = CreateGroup()
        local unit = nil

        GroupEnumUnitsInRect(group, GetWorldBounds(), nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isUltimateHealTarget(unit, caster) then
                UnitStateSystem.heal(unit, ULTIMATE_HEAL_AMOUNT, {
                    effect = HEAL_EFFECT,
                    attachPoint = "chest"
                })
            end
            unit = FirstOfGroup(group)
        end

        DestroyGroup(group)
    end

    local function cleanupMagmide(magmide)
        local id = magmide and GetHandleId(magmide) or 0
        local data = magmideData[id]
        local moltenious = data and data.moltenious or nil

        if not data or data.cleaning then
            return
        end

        data.cleaning = true
        if data.periodicTimer then
            data.periodicTimer:destroy()
        end
        if data.leashTimer then
            data.leashTimer:destroy()
        end
        if data.healTimer then
            data.healTimer:destroy()
        end

        if moltenious and GetUnitTypeId(moltenious) ~= 0 then
            UnitRemoveAbility(moltenious, IDS.ULTIMATE_CHANNEL_BUFF)
            UnitRemoveAbility(moltenious, FourCC("INVU"))
            UnitRemoveAbility(moltenious, FourCC("Aeth"))
            IssueImmediateOrder(moltenious, "stop")
            SelectUnitAddForPlayer(moltenious, GetOwningPlayer(moltenious))
            molteniousToMagmide[GetHandleId(moltenious)] = nil
        end

        if magmide and GetUnitTypeId(magmide) ~= 0 then
            removeMagmideItems(magmide)
            UnitRemoveAbility(magmide, IDS.UNIQUE)
            if GetWidgetLife(magmide) > 0.45 then
                KillUnit(magmide)
            end
        end

        magmideData[id] = nil
    end

    local function magmidePeriodic(magmide)
        if not isAlive(magmide) then
            cleanupMagmide(magmide)
            return
        end
        uniqueAuraTick(magmide, 1, true)
    end

    local function checkMagmideLeash(magmide)
        local data = magmideData[GetHandleId(magmide)]
        local moltenious = data and data.moltenious or nil

        if not data or not isAlive(magmide) or not isAlive(moltenious) then
            cleanupMagmide(magmide)
            return
        end

        if distanceBetween(GetUnitX(magmide), GetUnitY(magmide), GetUnitX(moltenious), GetUnitY(moltenious)) > MAGMIDE_LEASH_RANGE then
            cleanupMagmide(magmide)
        end
    end

    local function castUltimate(caster)
        local x = GetUnitX(caster)
        local y = GetUnitY(caster)
        local facing = GetUnitFacing(caster)
        local finalX = xFromAngle(x, facing, MAGMIDE_OFFSET)
        local finalY = yFromAngle(y, facing, MAGMIDE_OFFSET)
        local magmide = nil
        local data = nil

        UnitAddAbility(caster, IDS.ULTIMATE_CHANNEL_BUFF)
        UnitAddAbility(caster, FourCC("INVU"))
        UnitAddAbility(caster, FourCC("Aeth"))

        if not isWalkable(finalX, finalY) or GetTerrainCliffLevel(x, y) ~= GetTerrainCliffLevel(finalX, finalY) then
            finalX = x
            finalY = y
        end

        magmide = CreateUnit(GetOwningPlayer(caster), IDS.MAGMIDE, finalX, finalY, facing)
        copyItemsToMagmide(caster, magmide)
        UnitAddAbility(magmide, IDS.HIDDEN_UNIQUE)
        data = {
            moltenious = caster,
            magmide = magmide
        }

        data.periodicTimer = GameTimer.every(UNIQUE_INTERVAL, function()
            magmidePeriodic(magmide)
        end)
        data.leashTimer = GameTimer.every(UNIQUE_INTERVAL, function()
            checkMagmideLeash(magmide)
        end)
        data.healTimer = GameTimer.every(ULTIMATE_HEAL_INTERVAL, function()
            if not isAlive(caster) or not isAlive(magmide) or GetUnitAbilityLevel(caster, IDS.ULTIMATE_CHANNEL_BUFF) <= 0 then
                cleanupMagmide(magmide)
                return
            end
            healUltimateAllies(caster)
        end)

        magmideData[GetHandleId(magmide)] = data
        molteniousToMagmide[GetHandleId(caster)] = magmide
        showMagmideSpawnEffects(magmide)
        GameTimer.after(0.0, function()
            showMagmideSpawnEffects(magmide)
        end)
        SelectUnitAddForPlayer(magmide, GetOwningPlayer(caster))
        SelectUnitRemoveForPlayer(caster, GetOwningPlayer(caster))
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local abilityId = GetSpellAbilityId()

        if abilityId == IDS.NUKE then
            castMolteniousNuke(caster, GetSpellTargetUnit())
        elseif abilityId == IDS.HEAL then
            castHeal(caster)
        elseif abilityId == IDS.ULTIMATE then
            castUltimate(caster)
        elseif abilityId == IDS.MINION_NUKE then
            castBounceNuke(caster, GetSpellTargetUnit(), IDS.MINION_NUKE)
        elseif abilityId == IDS.MINION_HEAL then
            castMinionHeal(caster)
        elseif abilityId == IDS.MINION_ULTIMATE then
            castBounceNuke(caster, GetSpellTargetUnit(), IDS.MINION_ULTIMATE)
        end
    end

    local function onSpellEndcast()
        if GetSpellAbilityId() == IDS.ULTIMATE then
            cleanupMagmide(molteniousToMagmide[GetHandleId(GetTriggerUnit())])
        end
    end

    local function onHeroSkill()
        if GetLearnedSkill() == IDS.UNIQUE then
            startUniqueAura(GetTriggerUnit())
        end
    end

    local function onSummon()
        local caster = GetSummoningUnit()
        local phoenix = GetSummonedUnit()
        local casterId = caster and GetHandleId(caster) or 0
        local previous = phoenixByCaster[casterId]

        if not phoenix or GetUnitTypeId(phoenix) ~= IDS.PHOENIX_SCOUT or casterId == 0 then
            return
        end

        if previous and previous ~= phoenix and GetUnitTypeId(previous) ~= 0 then
            phoenixCasterByUnit[GetHandleId(previous)] = nil
            RemoveUnit(previous)
        end

        phoenixByCaster[casterId] = phoenix
        phoenixCasterByUnit[GetHandleId(phoenix)] = casterId
    end

    local function onDeath()
        local dying = GetTriggerUnit()
        local dyingId = GetHandleId(dying)
        local casterId = phoenixCasterByUnit[dyingId]

        if GetUnitTypeId(dying) == IDS.MAGMIDE then
            removeMagmideItems(dying)
            cleanupMagmide(dying)
        end
        if casterId then
            if phoenixByCaster[casterId] == dying then
                phoenixByCaster[casterId] = nil
            end
            phoenixCasterByUnit[dyingId] = nil
        end
    end

    local function onDropItem()
        local unit = GetTriggerUnit()
        local item = GetManipulatedItem()

        if unit and GetUnitTypeId(unit) == IDS.MAGMIDE and item then
            RemoveItem(item)
        end
    end

    local function onDamaged()
        local target = GetTriggerUnit()
        local attacker = GetEventDamageSource()
        local damage = GetEventDamage()

        if suppressDamage or not target or not attacker then
            return
        end

        if GetUnitAbilityLevel(target, IDS.ULTIMATE_CHANNEL_BUFF) > 0 and damage > 0.0 then
            if rawget(_G, "BlzSetEventDamage") then
                BlzSetEventDamage(0.0)
            else
                suppressDamage = true
                UnitStateSystem.heal(target, damage)
                suppressDamage = false
            end
        end
    end

    local spellTrigger = CreateTrigger()
    local endcastTrigger = CreateTrigger()
    local skillTrigger = CreateTrigger()
    local summonTrigger = CreateTrigger()
    local deathTrigger = CreateTrigger()
    local dropTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(endcastTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_ENDCAST, nil)
        TriggerRegisterPlayerUnitEvent(skillTrigger, Player(i), EVENT_PLAYER_HERO_SKILL, nil)
        TriggerRegisterPlayerUnitEvent(summonTrigger, Player(i), EVENT_PLAYER_UNIT_SUMMON, nil)
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        TriggerRegisterPlayerUnitEvent(dropTrigger, Player(i), EVENT_PLAYER_UNIT_DROP_ITEM, nil)
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
    TriggerAddAction(endcastTrigger, function() guarded(onSpellEndcast) end)
    TriggerAddAction(skillTrigger, function() guarded(onHeroSkill) end)
    TriggerAddAction(summonTrigger, function() guarded(onSummon) end)
    TriggerAddAction(deathTrigger, function() guarded(onDeath) end)
    TriggerAddAction(dropTrigger, function() guarded(onDropItem) end)
    TriggerAddAction(damageTrigger, function() guarded(onDamaged) end)

    AbilityRegistry.registerRace("Moltenious", "titan", {
        notes = "Moltenious abilities ported from MolteniousNuke, MolteniousNukeBurn, MolteniousHeal, MolteniousUnique, MolteniousUltimate, MolteniousNukeMinion and MolteniousHealMinion.",
        abilities = {
            {
                name = "Moltenious Nuke",
                id = IDS.NUKE,
                source = "library MolteniousNuke and MolteniousNukeBurn",
                behavior = "Bounces fire magic damage between visible valid targets and triggers the Incinerate burn dummy on amplified targets."
            },
            {
                name = "Moltenious Heal",
                id = IDS.HEAL,
                source = "library MolteniousHeal",
                behavior = "Heals allied organic non-ward units in 600 AoE through UnitStateSystem."
            },
            {
                name = "Moltenious Unique",
                id = IDS.UNIQUE,
                source = "library MolteniousUnique",
                behavior = "Every 0.5 seconds burns nearby enemy structures, doubled against Incinerate-amplified targets."
            },
            {
                name = "Moltenious Ultimate",
                id = IDS.ULTIMATE,
                source = "library MolteniousUltimate",
                behavior = "Spawns a Magmide with copied non-Ankh items, protects Moltenious while channeling and despawns the Magmide on leash/end/death."
            },
            {
                name = "Moltenious Minion Nuke",
                id = IDS.MINION_NUKE,
                source = "library MolteniousNukeMinion",
                behavior = "Bounces Moltenious-style fire magic damage between visible valid targets."
            },
            {
                name = "Moltenious Minion Heal",
                id = IDS.MINION_HEAL,
                source = "library MolteniousHealMinion",
                behavior = "Bounces healing between wounded allied units."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
