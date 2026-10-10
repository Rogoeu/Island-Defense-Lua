if Debug and Debug.beginFile then Debug.beginFile("Abilities/Global/DisableAttack") end

OnInit("DisableAttack", function(import)
    import.strict("PlayerData")
    import.strict("UnitSpawner")
    import.strict("UnitFilter")

    local IDS = {
        GOLDING = FourCC("A041"),
        SHALLOW_SPAWN_ATTACKER = FourCC("SHTR"),
        BUILDER_CLASSIFICATION = FourCC("BLDR")
    }

    local GOLDING_MOVE_DISTANCE = 95.0

    local function isDefender(playerData)
        return playerData and playerData:class() == PlayerData.CLASS_DEFENDER
    end

    local function isTitanSide(playerData)
        return playerData and (
            playerData:class() == PlayerData.CLASS_TITAN or
            playerData:class() == PlayerData.CLASS_MINION
        )
    end

    local function isMainUnit(unit, classValue)
        return UnitFilter.isMainUnit(unit, classValue)
    end

    local function isMainTitanSideUnit(unit)
        return UnitFilter.isTitanSideMain(unit)
    end

    local function titanSpellWell()
        return UnitSpawner.get("TITAN_SPELL_WELL")
    end

    local function shouldStopAttack(target, attacker)
        local targetData = nil
        local attackerData = nil

        if not target or not attacker then
            return false
        end

        targetData = PlayerData.get(GetOwningPlayer(target))
        attackerData = PlayerData.get(GetOwningPlayer(attacker))

        if GetUnitAbilityLevel(attacker, IDS.SHALLOW_SPAWN_ATTACKER) > 0 and GetUnitAbilityLevel(target, IDS.BUILDER_CLASSIFICATION) > 0 then
            return true
        end

        if isDefender(attackerData) then
            if target == titanSpellWell() then
                return true
            end

            if isDefender(targetData) and isMainUnit(target, PlayerData.CLASS_DEFENDER) then
                return true
            end
        elseif isTitanSide(attackerData) then
            if isTitanSide(targetData) then
                if isMainTitanSideUnit(target) then
                    return true
                end

                if target == titanSpellWell() then
                    return true
                end
            end
        elseif GetOwningPlayer(attacker) == Player(PLAYER_NEUTRAL_PASSIVE) and GetUnitAbilityLevel(target, IDS.BUILDER_CLASSIFICATION) > 0 then
            return true
        end

        return false
    end

    local function onAttacked()
        local target = GetTriggerUnit()
        local attacker = GetAttacker()

        if shouldStopAttack(target, attacker) then
            IssueImmediateOrder(attacker, "stop")
        end
    end

    local function isGoldingMoundOrder()
        local ordered = GetOrderedUnit()
        local target = GetOrderTargetUnit()
        local orderId = GetIssuedOrderId()

        return ordered and
            target and
            target == titanSpellWell() and
            GetUnitAbilityLevel(ordered, IDS.GOLDING) > 0 and
            (orderId == OrderId("smart") or orderId == OrderId("attack"))
    end

    local function onGoldingMoundOrder()
        local unit = GetOrderedUnit()
        local well = titanSpellWell()
        local x = 0.0
        local y = 0.0
        local angle = 0.0

        if not unit or not well then
            return
        end

        x = GetUnitX(well)
        y = GetUnitY(well)
        angle = bj_RADTODEG * Atan2(GetUnitY(unit) - y, GetUnitX(unit) - x)
        x = x + GOLDING_MOVE_DISTANCE * Cos(angle * bj_DEGTORAD)
        y = y + GOLDING_MOVE_DISTANCE * Sin(angle * bj_DEGTORAD)
        IssuePointOrder(unit, "restoration", x, y)
    end

    local attackTrigger = CreateTrigger()
    local orderTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(attackTrigger, Player(i), EVENT_PLAYER_UNIT_ATTACKED, nil)
        TriggerRegisterPlayerUnitEvent(orderTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, nil)
        i = i + 1
    end

    TriggerAddAction(attackTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onAttacked)
        else
            onAttacked()
        end
    end)

    TriggerAddAction(orderTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if isGoldingMoundOrder() then
            if debugApi and debugApi.try then
                debugApi.try(onGoldingMoundOrder)
            else
                onGoldingMoundOrder()
            end
        end
    end)
end)

if Debug and Debug.endFile then Debug.endFile() end
