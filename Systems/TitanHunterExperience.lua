if Debug and Debug.beginFile then Debug.beginFile("Systems/TitanHunterExperience") end

OnInit("TitanHunterExperience", function(import)
    import.strict("ExperienceSystem")
    import.strict("GameSettings")
    import.strict("GameTimer")
    import.strict("MinionSpawner")
    import.strict("UnitSpawner")
    import.strict("UnitFilter")

    local IDS = {
        TITAN_HUNTER = FourCC("TIHU"),
        TITAN = FourCC("CTIT"),
        CRITTER = FourCC("CRIT"),
        SUPER_CRITTER = FourCC("SCRI"),
        EXP_GLYPH = FourCC("EXPS"),
        MINION_KILL_CREDIT = FourCC("A07N"),
        HUNTER_TECH_DOUBLE_DAMAGE_XP = FourCC("R07E"),
        SUPER_CRITTER_UNIT = FourCC("H05R")
    }

    local HUNTRESS_HUNTERS = {
        [FourCC("H05U")] = true,
        [FourCC("H05Z")] = true,
        [FourCC("H05J")] = true,
        [FourCC("H05S")] = true,
        [FourCC("H050")] = true,
        [FourCC("H05W")] = true
    }

    local GLYPH_RESPAWNS = {
        { x = 10730.8, y = 526.8 },
        { x = 3526.3, y = -10154.9 },
        { x = -9730.0, y = -2307.8 },
        { x = -1348.6, y = 7620.5 }
    }

    local CRITTER_XP = 4
    local UNIT_XP = 25
    local HERO_XP = 400.0
    local XP_SPILL_RANGE = 1500.0
    local HERO_XP_MULTI = 0.60
    local LEVEL_XP_BASE = 100.0
    local LEVEL_XP_STEP = 100.0
    local OBJECTIVE_XP_FACTOR = 0.50
    local GOLD_PER_HUNTER_LEVEL = 50
    local DEFAULT_SUPER_CRITTER_KILLS = 50
    local SUPER_CRITTER_AGGRO_RANGE = 900.0
    local SUPER_CRITTER_AGGRO_PERIOD = 1.0

    local TitanHunterExperience = {}
    local stormTrooperPoints = 0
    local superCritterKills = 1
    local superCritter = nil
    local superCritterAiTimer = nil
    local sharing = false
    local stopSuperCritterAi = nil

    local function isAlive(unit)
        return UnitFilter.isAlive(unit) and not IsUnitType(unit, UNIT_TYPE_DEAD)
    end

    local function isHunter(unit)
        return unit and (
            UnitFilter.isTitanHunter(unit) or
            HUNTRESS_HUNTERS[GetUnitTypeId(unit)] == true
        )
    end

    local function isHuntressHunter(unit)
        return unit and HUNTRESS_HUNTERS[GetUnitTypeId(unit)] == true
    end

    local function isTitanous(unit)
        return unit and GetUnitAbilityLevel(unit, IDS.TITAN) > 0
    end

    local function isCritter(unit)
        return unit and GetUnitAbilityLevel(unit, IDS.CRITTER) > 0
    end

    local function isSuperCritter(unit)
        return unit and GetUnitAbilityLevel(unit, IDS.SUPER_CRITTER) > 0
    end

    local function isGlyph(unit)
        return unit and GetUnitAbilityLevel(unit, IDS.EXP_GLYPH) > 0
    end

    local function isSuperCritterTarget(unit)
        return isAlive(unit) and
            not IsUnitType(unit, UNIT_TYPE_STRUCTURE) and
            (isHunter(unit) or isTitanous(unit) or GetUnitAbilityLevel(unit, IDS.MINION_KILL_CREDIT) > 0)
    end

    local function giveExperience(unit, amount)
        if unit and amount and amount > 0 then
            ExperienceSystem.giveExperience(unit, R2I(amount))
        end
    end

    local function addExperience(unit, amount)
        if unit and amount and amount > 0 then
            SuspendHeroXP(unit, false)
            AddHeroXP(unit, R2I(amount), true)
            SuspendHeroXP(unit, true)
        end
    end

    local function superCritterGoal()
        if GameSettings.exists("TITAN_HUNTER_SUPER_CRITTER_ENABLED") and not GameSettings.getBool("TITAN_HUNTER_SUPER_CRITTER_ENABLED") then
            return 0
        end
        if GameSettings.exists("TITAN_HUNTER_SUPER_CRITTER_KILLS") then
            return GameSettings.getInt("TITAN_HUNTER_SUPER_CRITTER_KILLS")
        end
        return DEFAULT_SUPER_CRITTER_KILLS
    end

    local function superCritterEnabled()
        return superCritterGoal() > 0
    end

    local function removeSuperCritter()
        if superCritter and GetUnitTypeId(superCritter) ~= 0 then
            RemoveUnit(superCritter)
        end
        if stopSuperCritterAi then
            stopSuperCritterAi()
        end
        superCritter = nil
    end

    local function giveExperienceShared(unit, amount)
        local group = nil
        local candidate = nil
        local owner = nil

        if not unit or not amount or amount <= 0 then
            return
        end

        if not isHuntressHunter(unit) or sharing then
            giveExperience(unit, amount)
            return
        end

        sharing = true
        owner = GetOwningPlayer(unit)
        group = CreateGroup()
        GroupEnumUnitsOfPlayer(group, owner, nil)
        candidate = FirstOfGroup(group)
        while candidate do
            GroupRemoveUnit(group, candidate)
            if isHuntressHunter(candidate) and isAlive(candidate) then
                giveExperience(candidate, amount)
            end
            candidate = FirstOfGroup(group)
        end
        DestroyGroup(group)
        sharing = false
    end

    local function addExperienceShared(unit, amount)
        local group = nil
        local candidate = nil
        local owner = nil

        if not unit or not amount or amount <= 0 then
            return
        end

        if not isHuntressHunter(unit) or sharing then
            addExperience(unit, amount)
            return
        end

        sharing = true
        owner = GetOwningPlayer(unit)
        group = CreateGroup()
        GroupEnumUnitsOfPlayer(group, owner, nil)
        candidate = FirstOfGroup(group)
        while candidate do
            GroupRemoveUnit(group, candidate)
            if isHuntressHunter(candidate) and isAlive(candidate) then
                addExperience(candidate, amount)
            end
            candidate = FirstOfGroup(group)
        end
        DestroyGroup(group)
        sharing = false
    end

    local function huntersInRange(x, y, range)
        local group = CreateGroup()
        local hunters = {}
        local unit = nil

        GroupEnumUnitsInRange(group, x, y, range, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isHunter(unit) and isAlive(unit) then
                hunters[#hunters + 1] = unit
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        return hunters
    end

    local function shareHeroKillExperience(x, y)
        local hunters = huntersInRange(x, y, XP_SPILL_RANGE)
        local count = #hunters
        local xp = 0.0
        local i = 1

        if count <= 0 then
            return
        end

        xp = HERO_XP + (count * (HERO_XP * HERO_XP_MULTI) - (HERO_XP * HERO_XP_MULTI))
        while i <= count do
            addExperienceShared(hunters[i], xp / count)
            i = i + 1
        end
    end

    local function objectiveExperienceFor(unit)
        return (LEVEL_XP_BASE + (GetHeroLevel(unit) * LEVEL_XP_STEP)) * OBJECTIVE_XP_FACTOR
    end

    local function shareObjectiveExperience(x, y)
        local hunters = huntersInRange(x, y, XP_SPILL_RANGE)
        local i = 1

        while i <= #hunters do
            addExperienceShared(hunters[i], objectiveExperienceFor(hunters[i]))
            i = i + 1
        end
    end

    local function addGold(unit, amount)
        local owner = GetOwningPlayer(unit)
        local tag = nil

        if not unit or amount <= 0 then
            return
        end

        SetPlayerState(owner, PLAYER_STATE_RESOURCE_GOLD, GetPlayerState(owner, PLAYER_STATE_RESOURCE_GOLD) + amount)
        tag = CreateTextTag()
        SetTextTagText(tag, "|cffffcc00+ " .. I2S(amount), TextTagSize2Height(8))
        SetTextTagPos(tag, GetUnitX(unit), GetUnitY(unit), 100)
        SetTextTagVisibility(tag, true)
        SetTextTagPermanent(tag, false)
        SetTextTagLifespan(tag, 1.8)
        SetTextTagFadepoint(tag, 1.4)
        SetTextTagVelocity(tag, TextTagSpeed2Velocity(0), TextTagSpeed2Velocity(44))
    end

    local function addHunterBountyGoldFeed(hunter, amount)
        local feedApi = rawget(_G, "PlayerDataFed")
        local hunterData = hunter and PlayerData.get(GetOwningPlayer(hunter)) or nil
        local feedData = nil

        if amount <= 0 or not GameSettings.getBool("GOLD_FEED_TRACKING_ENABLED") then
            return
        end
        if feedApi and feedApi.get and feedApi.addGold and hunterData then
            feedData = feedApi.get(hunterData)
            if feedData then
                feedApi.addGold(feedData, amount)
            end
        end
    end

    stopSuperCritterAi = function()
        if superCritterAiTimer then
            superCritterAiTimer:destroy()
            superCritterAiTimer = nil
        end
    end

    local function nearestSuperCritterTarget()
        local group = CreateGroup()
        local unit = nil
        local target = nil
        local bestDistance = 0.0
        local x = GetUnitX(superCritter)
        local y = GetUnitY(superCritter)

        GroupEnumUnitsInRange(group, x, y, SUPER_CRITTER_AGGRO_RANGE, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isSuperCritterTarget(unit) then
                local dx = GetUnitX(unit) - x
                local dy = GetUnitY(unit) - y
                local distance = dx * dx + dy * dy

                if not target or distance < bestDistance then
                    target = unit
                    bestDistance = distance
                end
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
        return target
    end

    local function startSuperCritterAi()
        stopSuperCritterAi()
        superCritterAiTimer = GameTimer.every(SUPER_CRITTER_AGGRO_PERIOD, function()
            local target = nil

            if not superCritter or not isAlive(superCritter) then
                stopSuperCritterAi()
                return
            end

            target = nearestSuperCritterTarget()
            if target then
                IssueTargetOrder(superCritter, "attack", target)
            end
        end)
    end

    local function spawnSuperCritter(x, y)
        stormTrooperPoints = 0
        PingMinimap(x, y, 5.0)
        BJDebugMsg("A Super Critter has spawned stop the titan from killing it!")
        superCritter = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), IDS.SUPER_CRITTER_UNIT, x, y, 180.0)
        SetUnitState(superCritter, UNIT_STATE_LIFE, GetUnitState(superCritter, UNIT_STATE_MAX_LIFE) / 5.0 * superCritterKills)
        SetUnitAcquireRange(superCritter, SUPER_CRITTER_AGGRO_RANGE)
        startSuperCritterAi()
    end

    local function respawnGlyph(glyph)
        local point = GLYPH_RESPAWNS[GetRandomInt(1, #GLYPH_RESPAWNS)]
        UnitSpawner.track("EXP_STONE", CreateUnit(GetOwningPlayer(glyph), GetUnitTypeId(glyph), point.x, point.y, 270.0))
    end

    local function onHunterDeathBounty(killer, target)
        local bounty = 0

        if not isHunter(target) then
            return
        end
        if not isTitanous(killer) and GetUnitAbilityLevel(killer, IDS.MINION_KILL_CREDIT) <= 0 then
            return
        end

        bounty = GetHeroLevel(target) * GOLD_PER_HUNTER_LEVEL
        addGold(killer, bounty)
        -- This level-scaled bounty is not part of the unit's Object Editor gold bounty,
        -- so ExperienceSystem cannot discover it automatically from the death event.
        addHunterBountyGoldFeed(target, bounty)
    end

    local function onDeath()
        local killer = GetKillingUnit()
        local target = GetTriggerUnit()
        local x = 0.0
        local y = 0.0

        if not killer or not target then
            return
        end

        onHunterDeathBounty(killer, target)

        if isHunter(killer) and isSuperCritter(target) then
            x = GetUnitX(target)
            y = GetUnitY(target)
            RemoveUnit(target)
            superCritterKills = superCritterKills + 1
            stopSuperCritterAi()
            superCritter = nil
            shareObjectiveExperience(x, y)
            local hunters = huntersInRange(x, y, XP_SPILL_RANGE)
            local i = 1
            while i <= #hunters do
                addGold(hunters[i], 5)
                i = i + 1
            end
        elseif isTitanous(killer) and isSuperCritter(target) then
            x = GetUnitX(target)
            y = GetUnitY(target)
            RemoveUnit(target)
            stopSuperCritterAi()
            superCritter = nil
            MinionSpawner.spawnUnitForTitan(killer, x, y)
        elseif isHunter(killer) and isCritter(target) then
            x = GetUnitX(target)
            y = GetUnitY(target)
            if superCritterEnabled() then
                stormTrooperPoints = stormTrooperPoints + 1
                if stormTrooperPoints >= superCritterGoal() then
                    spawnSuperCritter(x, y)
                end
            end
            if GetHeroLevel(killer) < 5 then
                addExperienceShared(killer, CRITTER_XP + (GetHeroLevel(killer) * CRITTER_XP))
            end
        elseif isHunter(killer) and
            IsUnitEnemy(target, GetOwningPlayer(killer)) and
            not IsUnitIllusion(target) and
            not IsUnitType(target, UNIT_TYPE_HERO) and
            not IsUnitType(target, UNIT_TYPE_STRUCTURE) then
            addExperienceShared(killer, UNIT_XP)
        elseif isTitanous(target) then
            shareHeroKillExperience(GetUnitX(target), GetUnitY(target))
        elseif isGlyph(target) then
            local hunters = huntersInRange(GetUnitX(target), GetUnitY(target), XP_SPILL_RANGE)
            local i = 1

            if not isTitanous(killer) then
                while i <= #hunters do
                    if GetHeroLevel(hunters[i]) <= 6 then
                        addExperienceShared(hunters[i], objectiveExperienceFor(hunters[i]))
                    end
                    i = i + 1
                end
            end
            respawnGlyph(target)
        end
    end

    local function onDamaged()
        local attacker = GetEventDamageSource()
        local target = GetTriggerUnit()
        local damage = GetEventDamage()
        local damageType = BlzGetEventDamageType and BlzGetEventDamageType() or DAMAGE_TYPE_NORMAL
        local techFactor = 1
        local expFactor = 1

        if damageType ~= DAMAGE_TYPE_NORMAL or damage <= 0.0 or not isHunter(attacker) or not isTitanous(target) then
            return
        end

        if BlzGetUnitWeaponRealField and BlzGetUnitWeaponRealField(attacker, UNIT_WEAPON_RF_ATTACK_RANGE, 0) < 300.0 then
            expFactor = 2
        end
        if GetPlayerTechResearched(GetOwningPlayer(attacker), IDS.HUNTER_TECH_DOUBLE_DAMAGE_XP, true) then
            techFactor = 2
        end

        giveExperienceShared(attacker, GetHeroLevel(target) * techFactor * expFactor)
    end

    function TitanHunterExperience.stormTrooperPoints()
        return stormTrooperPoints
    end

    function TitanHunterExperience.stormTrooperGoal()
        return superCritterGoal()
    end

    function TitanHunterExperience.superCritterEnabled()
        return superCritterEnabled()
    end

    function TitanHunterExperience.setSuperCritterEnabled(enabled)
        GameSettings.setBool("TITAN_HUNTER_SUPER_CRITTER_ENABLED", enabled == true)
        if not enabled then
            stormTrooperPoints = 0
            removeSuperCritter()
        end
    end

    function TitanHunterExperience.giveExperience(unit, amount)
        addExperienceShared(unit, amount)
    end

    local deathTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
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

    TriggerAddAction(deathTrigger, function() guarded(onDeath) end)
    TriggerAddAction(damageTrigger, function() guarded(onDamaged) end)

    _G.TitanHunterExperience = TitanHunterExperience
end)

if Debug and Debug.endFile then Debug.endFile() end
