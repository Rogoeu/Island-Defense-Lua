if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/MorphlingStructureAbilities") end

OnInit("MorphlingStructureAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("AbilityMeta")
    import.strict("GameTimer")
    import.strict("RaceData")
    import.strict("UnitFilter")

    local IDS = {
        PULSE_CARGO_HOLD = FourCC("A075"),
        CURSE_TARGET_CLASSIFICATION = FourCC("CTIT"),
        TOWER_CURSE = FourCC("A0JT"),
        REPLICATE = FourCC("A0QT"),
        REPLICATOR = FourCC("o01V")
    }

    local CURSE_CHANCE = 2
    local CURSE_DURATION = 30.0
    local REPLICATE_SUCCESS_COOLDOWN = 180.0
    local REPLICATE_FAIL_COOLDOWN = 0.5
    local CURSE_MODEL = "Abilities\\Spells\\Other\\Doom\\DoomTarget.mdl"
    local REPLICATE_MODEL = "Abilities\\Spells\\Undead\\DeathPact\\DeathPactTarget.mdl"
    local REPLICATE_DEBUG = false

    local CURSE_TOWER = {
        [FourCC("o018")] = true,
        [FourCC("o01A")] = true,
        [FourCC("o01B")] = true,
        [FourCC("o01C")] = true
    }

    local UNLOAD_ORDERS = {
        [OrderId("unload")] = true,
        [OrderId("unloadall")] = true,
        [OrderId("unloadallinstant")] = true
    }

    local loadedByTransport = {}
    local currentTransportByPassenger = {}
    local cursed = {}
    local ultimateTowerTypes = {}

    local function buildUltimateTowerTypes()
        local ids = RaceData and RaceData.tech and RaceData.tech.ULTIMATE_TOWERS or {}
        local index = 1

        while index <= #ids do
            local unitTypeId = ids[index]
            if type(unitTypeId) == "string" then
                unitTypeId = FourCC(unitTypeId)
            end
            if unitTypeId and unitTypeId ~= 0 then
                ultimateTowerTypes[unitTypeId] = true
            end
            index = index + 1
        end
    end

    local function isAlive(unit)
        return unit and GetWidgetLife(unit) > 0.405 and not IsUnitType(unit, UNIT_TYPE_DEAD)
    end

    local function isPulseTower(unit)
        return isAlive(unit) and GetUnitAbilityLevel(unit, IDS.PULSE_CARGO_HOLD) > 0
    end

    local function isCurseTower(unit)
        return unit and CURSE_TOWER[GetUnitTypeId(unit)] == true
    end

    local function isUltimateTower(unit)
        if unit and ultimateTowerTypes[GetUnitTypeId(unit)] then
            return true
        end
        if UnitFilter and UnitFilter.isUltimateTower then
            return UnitFilter.isUltimateTower(unit)
        end
        if rawget(_G, "IsUnitUltimateTower") then
            return IsUnitUltimateTower(unit)
        end
        return unit and GetUnitAbilityLevel(unit, FourCC("ULTT")) > 0
    end

    local function startCooldown(unit, abilityId, seconds)
        if AbilityMeta and AbilityMeta.startCooldown then
            AbilityMeta.startCooldown(unit, abilityId, seconds)
        elseif BlzStartUnitAbilityCooldown then
            BlzStartUnitAbilityCooldown(unit, abilityId, seconds)
        end
    end

    local function replicateDebug(player, text)
        if REPLICATE_DEBUG then
            DisplayTimedTextToPlayer(player, 0, 0, 8, "|cff99b4d1Replicator debug:|r " .. text)
        end
    end

    local function passengerStillLoaded(passenger)
        local isUnitLoaded = rawget(_G, "IsUnitLoaded")
        if isUnitLoaded then
            return isAlive(passenger) and isUnitLoaded(passenger)
        end
        return isAlive(passenger)
    end

    local function passengerCount(transport)
        local id = GetHandleId(transport)
        local passengers = loadedByTransport[id]
        local count = 0

        if not passengers then
            return 0
        end

        for passengerId, passenger in pairs(passengers) do
            if currentTransportByPassenger[passengerId] == transport and passengerStillLoaded(passenger) then
                count = count + 1
            else
                passengers[passengerId] = nil
                currentTransportByPassenger[passengerId] = nil
            end
        end

        return count
    end

    local function refreshPulseTower(transport)
        if not transport or not isPulseTower(transport) then
            return
        end

        if passengerCount(transport) > 0 then
            SetUnitVertexColor(transport, 255, 125, 125, 255)
        else
            SetUnitVertexColor(transport, 255, 255, 255, 255)
        end
    end

    local function delayedRefresh(transport)
        refreshPulseTower(transport)
        GameTimer.after(0.10, function()
            refreshPulseTower(transport)
        end)
        GameTimer.after(0.50, function()
            refreshPulseTower(transport)
        end)
    end

    local function trackLoadedPassenger(transport, passenger)
        local transportId = GetHandleId(transport)
        local passengerId = GetHandleId(passenger)

        if not loadedByTransport[transportId] then
            loadedByTransport[transportId] = {}
        end

        loadedByTransport[transportId][passengerId] = passenger
        currentTransportByPassenger[passengerId] = transport
        refreshPulseTower(transport)
    end

    local function onLoaded()
        local getTransportUnit = rawget(_G, "GetTransportUnit")
        local getLoadedUnit = rawget(_G, "GetLoadedUnit")
        local transport = getTransportUnit and getTransportUnit() or nil
        local passenger = getLoadedUnit and getLoadedUnit() or nil

        if transport and passenger and isPulseTower(transport) then
            trackLoadedPassenger(transport, passenger)
        end
    end

    local function onUpgradeFinish()
        refreshPulseTower(GetTriggerUnit())
    end

    local function onOrder()
        local unit = GetOrderedUnit()
        if unit and UNLOAD_ORDERS[GetIssuedOrderId()] and isPulseTower(unit) then
            delayedRefresh(unit)
        end
    end

    local function removeCurse(unit, effect)
        if unit then
            UnitRemoveAbility(unit, IDS.TOWER_CURSE)
            cursed[GetHandleId(unit)] = nil
        end
        if effect then
            DestroyEffect(effect)
        end
    end

    local function applyCurse(unit)
        local id = GetHandleId(unit)
        local effect = nil

        if not isAlive(unit) or cursed[id] then
            return
        end

        cursed[id] = true
        UnitAddAbility(unit, IDS.TOWER_CURSE)
        effect = AddSpecialEffect(CURSE_MODEL, GetUnitX(unit), GetUnitY(unit))

        GameTimer.after(CURSE_DURATION, function()
            removeCurse(unit, effect)
        end)
    end

    local function onDamaged()
        local attacker = GetEventDamageSource()
        local target = GetTriggerUnit()

        if not attacker or not target or GetEventDamage() <= 0.0 then
            return
        end
        if not isCurseTower(attacker) or not isAlive(attacker) or cursed[GetHandleId(attacker)] then
            return
        end
        if GetUnitAbilityLevel(target, IDS.CURSE_TARGET_CLASSIFICATION) <= 0 then
            return
        end
        if GetRandomInt(1, 100) > CURSE_CHANCE then
            return
        end

        applyCurse(attacker)
    end

    local function replicate(caster, target)
        local owner = nil
        local unitType = target and GetUnitTypeId(target) or 0
        local ratio = 1.0
        local newUnit = nil

        if not caster or unitType == 0 then
            if caster then
                replicateDebug(GetOwningPlayer(caster), "no valid target unit")
            end
            return
        end

        if not target or not isUltimateTower(target) or unitType == IDS.REPLICATOR then
            startCooldown(caster, IDS.REPLICATE, REPLICATE_FAIL_COOLDOWN)
            replicateDebug(GetOwningPlayer(caster), "invalid target type=" .. I2S(unitType) ..
                " ultimate=" .. (isUltimateTower(target) and "yes" or "no"))
            return
        end

        owner = GetOwningPlayer(caster)
        if GetUnitState(caster, UNIT_STATE_MAX_LIFE) > 0.0 then
            ratio = GetUnitState(caster, UNIT_STATE_LIFE) / GetUnitState(caster, UNIT_STATE_MAX_LIFE)
        end

        ShowUnit(caster, false)
        newUnit = CreateUnit(owner, unitType, GetUnitX(caster), GetUnitY(caster), GetUnitFacing(target))
        KillUnit(caster)
        RemoveUnit(caster)
        SetUnitState(newUnit, UNIT_STATE_LIFE, ratio * GetUnitState(newUnit, UNIT_STATE_MAX_LIFE))
        UnitAddAbility(newUnit, IDS.REPLICATE)
        DestroyEffect(AddSpecialEffectTarget(REPLICATE_MODEL, newUnit, "origin"))
        startCooldown(newUnit, IDS.REPLICATE, REPLICATE_SUCCESS_COOLDOWN)
        replicateDebug(owner, "created type=" .. I2S(unitType) .. " life=" .. I2S(R2I(ratio * 100.0)) .. "%")

        if GetLocalPlayer() == owner then
            SelectUnit(newUnit, true)
        end
    end

    local function onSpellEffect()
        if GetSpellAbilityId() == IDS.REPLICATE then
            replicate(GetTriggerUnit(), GetSpellTargetUnit())
        end
    end

    buildUltimateTowerTypes()

    local loadEvent = rawget(_G, "EVENT_PLAYER_UNIT_LOADED")
    local loadTrigger = CreateTrigger()
    local upgradeTrigger = CreateTrigger()
    local orderTrigger = CreateTrigger()
    local damageTrigger = CreateTrigger()
    local spellTrigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        if loadEvent then
            TriggerRegisterPlayerUnitEvent(loadTrigger, Player(i), loadEvent, nil)
        end
        TriggerRegisterPlayerUnitEvent(upgradeTrigger, Player(i), EVENT_PLAYER_UNIT_UPGRADE_FINISH, nil)
        TriggerRegisterPlayerUnitEvent(orderTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_ORDER, nil)
        TriggerRegisterPlayerUnitEvent(orderTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER, nil)
        TriggerRegisterPlayerUnitEvent(orderTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, nil)
        TriggerRegisterPlayerUnitEvent(damageTrigger, Player(i), EVENT_PLAYER_UNIT_DAMAGED, nil)
        TriggerRegisterPlayerUnitEvent(spellTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        i = i + 1
    end

    TriggerAddAction(loadTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onLoaded)
        else
            onLoaded()
        end
    end)

    TriggerAddAction(upgradeTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onUpgradeFinish)
        else
            onUpgradeFinish()
        end
    end)

    TriggerAddAction(orderTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onOrder)
        else
            onOrder()
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

    AbilityRegistry.registerRace("Morphling", "structures", {
        notes = "Morphling tower/building/upgrade abilities ported from MorphlingPulseTower and TowerCurseSystem.",
        abilities = {
            {
                name = "Pulse Tower Cargo Color",
                id = IDS.PULSE_CARGO_HOLD,
                source = "library MorphlingPulseTower",
                behavior = "Pulse towers with A075 turn red while carrying units and reset to normal color after unloading."
            },
            {
                name = "Tower Curse",
                id = IDS.TOWER_CURSE,
                source = "library TowerCurseSystem",
                behavior = "Morphling curse towers 0018/o01A/o01B/o01C have a 2 percent chance when hitting CTIT targets to curse themselves with A0JT for 30 seconds."
            },
            {
                name = "Replicator",
                id = IDS.REPLICATE,
                source = "library MorphlingReplicator",
                behavior = "A0QT turns the Replicator into the targeted ultimate tower, keeps its life ratio, adds A0QT back and starts a 180 second cooldown; invalid targets get a 0.5 second cooldown."
            }
        }
    })
end)

if Debug and Debug.endFile then Debug.endFile() end
