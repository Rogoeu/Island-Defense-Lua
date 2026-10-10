if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/PirateStructureAbilities") end

OnInit("PirateStructureAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("GameTimer")

    local IDS = {
        DEPLOY_ADMIRAL = FourCC("R04W"),
        DEPLOY_CARRONADE = FourCC("R04X"),
        DEPLOY_CHAINSHOT = FourCC("R04Y"),
        DEPLOY_FLINTLOCK = FourCC("R050"),
        ADMIRAL = FourCC("A0Q8"),
        CARRONADE = FourCC("A0Q7"),
        CARRONADE_ATTACK_SPEED = FourCC("A0QB"),
        CHAINSHOT = FourCC("A0Q9"),
        CHAINSHOT_ARMOR_REDUCTION = FourCC("A0QC"),
        FLINTLOCK = FourCC("A0QA"),
        FLINTLOCK_DOUBLE_SHOT = FourCC("A0QE"),
        BARREL_TRANSFORM = FourCC("A0KY"),
        BARREL_TRANSFORM_ABILITY = FourCC("S00N"),
        BARREL = FourCC("u011"),
        BUFF_ADMIRAL = FourCC("B07Y"),
        BUFF_CARRONADE = FourCC("B07Z"),
        BUFF_CHAINSHOT = FourCC("B080"),
        BUFF_CHAINSHOT_ARMOR = FourCC("B082"),
        BUFF_FLINTLOCK = FourCC("B081"),
        FRIGATE_NORMAL = FourCC("o02K"),
        FRIGATE_ENHANCED = FourCC("o02M"),
        FRIGATE_SUPER = FourCC("o02N"),
        FRIGATE_MEGA = FourCC("o02L")
    }

    local ADMIRAL_BONUS = 1.40
    local CHAINSHOT_DURATION = 1.20
    local CHAINSHOT_REFRESH_DURATION = 0.75
    local CARRONADE_DURATION = 7.50
    local FLINTLOCK_CHANCE = 20
    local FLINTLOCK_DURATION = 0.40
    local INVALID_BARREL_MANA_REFUND = 0.20
    local LUMBER_COST = 1000
    local carronadeTimers = {}
    local chainshotTimers = {}

    local function isFrigate(unit)
        local id = unit and GetUnitTypeId(unit) or 0
        return id == IDS.FRIGATE_NORMAL or
            id == IDS.FRIGATE_ENHANCED or
            id == IDS.FRIGATE_SUPER or
            id == IDS.FRIGATE_MEGA
    end

    local function distance(source, target)
        local dx = GetUnitX(source) - GetUnitX(target)
        local dy = GetUnitY(source) - GetUnitY(target)
        return SquareRoot(dx * dx + dy * dy)
    end

    local function noPreviousDeployment(unit)
        return GetUnitAbilityLevel(unit, IDS.ADMIRAL) == 0 and
            GetUnitAbilityLevel(unit, IDS.CARRONADE) == 0 and
            GetUnitAbilityLevel(unit, IDS.CHAINSHOT) == 0 and
            GetUnitAbilityLevel(unit, IDS.FLINTLOCK) == 0
    end

    local function resetDeploymentTech(player, researchId)
        SetPlayerTechMaxAllowed(player, researchId, -1)
        SetPlayerTechResearched(player, researchId, 0)
    end

    local function addDeployment(unit, player, researchId, abilityId)
        UnitAddAbility(unit, abilityId)
        UnitMakeAbilityPermanent(unit, true, abilityId)
        SetPlayerTechMaxAllowed(player, researchId, 0)
    end

    local function onResearchFinish()
        local frigate = GetTriggerUnit()
        local player = GetOwningPlayer(frigate)
        local researched = GetResearched()
        local abilityId = 0

        if not isFrigate(frigate) then
            return
        end

        if researched == IDS.DEPLOY_ADMIRAL then
            abilityId = IDS.ADMIRAL
        elseif researched == IDS.DEPLOY_CARRONADE then
            abilityId = IDS.CARRONADE
        elseif researched == IDS.DEPLOY_CHAINSHOT then
            abilityId = IDS.CHAINSHOT
        elseif researched == IDS.DEPLOY_FLINTLOCK then
            abilityId = IDS.FLINTLOCK
        else
            return
        end

        if noPreviousDeployment(frigate) then
            addDeployment(frigate, player, researched, abilityId)
        else
            SetPlayerTechResearched(player, researched, 0)
            SetPlayerState(player, PLAYER_STATE_RESOURCE_LUMBER, GetPlayerState(player, PLAYER_STATE_RESOURCE_LUMBER) + LUMBER_COST)
            DisplayTimedTextToPlayer(player, 0, 0, 3, "|cffbb2020A frigate can only have one Fleet Deployment.|r")
        end
    end

    local function onDeath()
        local frigate = GetDyingUnit()
        local player = GetOwningPlayer(frigate)

        if not isFrigate(frigate) then
            return
        end

        if GetUnitAbilityLevel(frigate, IDS.ADMIRAL) > 0 then
            UnitRemoveAbility(frigate, IDS.ADMIRAL)
            resetDeploymentTech(player, IDS.DEPLOY_ADMIRAL)
        elseif GetUnitAbilityLevel(frigate, IDS.CARRONADE) > 0 then
            UnitRemoveAbility(frigate, IDS.CARRONADE)
            resetDeploymentTech(player, IDS.DEPLOY_CARRONADE)
        elseif GetUnitAbilityLevel(frigate, IDS.CHAINSHOT) > 0 then
            UnitRemoveAbility(frigate, IDS.CHAINSHOT)
            resetDeploymentTech(player, IDS.DEPLOY_CHAINSHOT)
        elseif GetUnitAbilityLevel(frigate, IDS.FLINTLOCK) > 0 then
            UnitRemoveAbility(frigate, IDS.FLINTLOCK)
            resetDeploymentTech(player, IDS.DEPLOY_FLINTLOCK)
        end
    end

    local function startCarronade(frigate)
        local id = GetHandleId(frigate)

        if GetUnitAbilityLevel(frigate, IDS.CARRONADE_ATTACK_SPEED) < 1 then
            UnitAddAbility(frigate, IDS.CARRONADE_ATTACK_SPEED)
        elseif GetUnitAbilityLevel(frigate, IDS.CARRONADE_ATTACK_SPEED) < 31 then
            IncUnitAbilityLevel(frigate, IDS.CARRONADE_ATTACK_SPEED)
        end

        if carronadeTimers[id] then
            carronadeTimers[id]:destroy()
        end
        carronadeTimers[id] = GameTimer.after(CARRONADE_DURATION, function()
            if frigate and GetUnitTypeId(frigate) ~= 0 then
                UnitRemoveAbility(frigate, IDS.CARRONADE_ATTACK_SPEED)
            end
            carronadeTimers[id] = nil
        end)
    end

    local function chainshotTriggers(frigate, target)
        local roll = GetRandomInt(0, 100)
        local range = distance(frigate, target)

        if range >= 600.0 then
            return roll >= 95
        elseif range > 500.0 then
            return roll >= 90
        elseif range > 400.0 then
            return roll >= 50
        elseif range > 350.0 then
            return roll <= 75
        end
        return true
    end

    local function applyChainshot(target)
        local id = GetHandleId(target)
        local duration = CHAINSHOT_DURATION

        if GetUnitAbilityLevel(target, IDS.CHAINSHOT_ARMOR_REDUCTION) == 0 then
            UnitAddAbility(target, IDS.CHAINSHOT_ARMOR_REDUCTION)
        else
            duration = CHAINSHOT_REFRESH_DURATION
        end

        if chainshotTimers[id] then
            chainshotTimers[id]:destroy()
        end
        chainshotTimers[id] = GameTimer.after(duration, function()
            if target and GetUnitTypeId(target) ~= 0 then
                UnitRemoveAbility(target, IDS.CHAINSHOT_ARMOR_REDUCTION)
                UnitRemoveAbility(target, IDS.BUFF_CHAINSHOT_ARMOR)
            end
            chainshotTimers[id] = nil
        end)
    end

    local function isFlintlockable(source, unit)
        return isFrigate(unit) and
            GetOwningPlayer(unit) == GetOwningPlayer(source) and
            GetUnitAbilityLevel(unit, IDS.BUFF_ADMIRAL) < 1 and
            GetUnitAbilityLevel(unit, IDS.BUFF_CARRONADE) < 1 and
            GetUnitAbilityLevel(unit, IDS.BUFF_CHAINSHOT) < 1
    end

    local function triggerFlintlock(frigate, target)
        local group = nil
        local unit = nil
        local affected = {}

        if GetRandomInt(0, 100) > FLINTLOCK_CHANCE then
            return
        end

        group = CreateGroup()
        GroupEnumUnitsInRange(group, GetUnitX(target), GetUnitY(target), distance(frigate, target), nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isFlintlockable(frigate, unit) then
                UnitAddAbility(unit, IDS.FLINTLOCK_DOUBLE_SHOT)
                affected[#affected + 1] = unit
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)

        GameTimer.after(FLINTLOCK_DURATION, function()
            local i = 1
            while i <= #affected do
                if affected[i] and GetUnitTypeId(affected[i]) ~= 0 then
                    UnitRemoveAbility(affected[i], IDS.FLINTLOCK_DOUBLE_SHOT)
                end
                i = i + 1
            end
        end)
    end

    local function onDamaged()
        local target = GetTriggerUnit()
        local frigate = GetEventDamageSource()
        local damage = GetEventDamage()

        if not target or not frigate or not IsUnitEnemy(frigate, GetOwningPlayer(target)) then
            return
        end

        if GetUnitAbilityLevel(frigate, IDS.BUFF_ADMIRAL) > 0 then
            if GetUnitAbilityLevel(frigate, IDS.BUFF_CARRONADE) > 0 or
                GetUnitAbilityLevel(frigate, IDS.BUFF_CHAINSHOT) > 0 or
                GetUnitAbilityLevel(frigate, IDS.BUFF_FLINTLOCK) > 0 or
                not isFrigate(frigate) then
                if BlzSetEventDamage then
                    BlzSetEventDamage(damage / ADMIRAL_BONUS)
                end
            end
        elseif GetUnitAbilityLevel(frigate, IDS.BUFF_CARRONADE) > 0 and
            isFrigate(frigate) and
            distance(frigate, target) <= 600.0 and
            GetUnitAbilityLevel(frigate, IDS.BUFF_CHAINSHOT) < 1 and
            GetUnitAbilityLevel(frigate, IDS.BUFF_FLINTLOCK) < 1 then
            startCarronade(frigate)
        elseif GetUnitAbilityLevel(frigate, IDS.BUFF_CHAINSHOT) > 0 then
            if chainshotTriggers(frigate, target) and not IsUnitType(target, UNIT_TYPE_MAGIC_IMMUNE) then
                applyChainshot(target)
            end
        elseif GetUnitAbilityLevel(frigate, IDS.FLINTLOCK) > 0 then
            triggerFlintlock(frigate, target)
        end
    end

    local function onSpellEffect()
        local caster = GetTriggerUnit()
        local target = GetSpellTargetUnit()

        if GetSpellAbilityId() ~= IDS.BARREL_TRANSFORM then
            return
        end

        if target and GetUnitTypeId(target) == IDS.BARREL then
            UnitAddAbility(target, IDS.BARREL_TRANSFORM_ABILITY)
        else
            SetUnitState(caster, UNIT_STATE_MANA,
                GetUnitState(caster, UNIT_STATE_MANA) +
                GetUnitState(caster, UNIT_STATE_MAX_MANA) * INVALID_BARREL_MANA_REFUND)
        end
    end

    local researchTrigger = CreateTrigger()
    local deathTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local spellTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(researchTrigger, Player(i), EVENT_PLAYER_UNIT_RESEARCH_FINISH, nil)
        TriggerRegisterPlayerUnitEvent(deathTrigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        i = i + 1
    end

    TriggerAddAction(researchTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onResearchFinish)
        else
            onResearchFinish()
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

    TriggerAddAction(damageTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onDamaged)
        else
            onDamaged()
        end
    end)

    TriggerAddAction(spellTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onSpellEffect)
        else
            onSpellEffect()
        end
    end)

    AbilityRegistry.registerRace("Pirate", "structures", {
        notes = "Pirate tower/building abilities ported from FleetDeployments and SKOD.",
        abilities = {
            {
                name = "Fleet Deployments",
                source = "library FleetDeployments",
                behavior = "Frigates can research exactly one deployment: Admiral, Carronade, Chainshot or Flintlock."
            },
            {
                name = "Carronade",
                id = IDS.CARRONADE,
                source = "library FleetDeployments",
                behavior = "Carronade frigates gain temporary stacking attack speed when firing within 600 range."
            },
            {
                name = "Chainshot",
                id = IDS.CHAINSHOT,
                source = "library FleetDeployments",
                behavior = "Chainshot frigates can apply temporary armor reduction based on distance chance."
            },
            {
                name = "Flintlock",
                id = IDS.FLINTLOCK,
                source = "library FleetDeployments",
                behavior = "Flintlock shots can grant nearby friendly undeployed frigates a brief double-shot ability."
            },
            {
                name = "Barrel Transform",
                id = IDS.BARREL_TRANSFORM,
                source = "library SKOD",
                behavior = "Adds S00N to targeted u011 barrels; invalid targets refund 20 percent of the caster's maximum mana."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
