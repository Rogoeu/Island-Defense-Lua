if Debug and Debug.beginFile then Debug.beginFile("Abilities/Global/GoldToLumber") end

OnInit("GoldToLumber", function(import)
    import.strict("GameTimer")
    import.strict("ShowTagFromUnit")

    local IDS = {
        EXCHANGE_RESEARCH = FourCC("R057") -- Gold to Lumber research.
    }

    local BONUS_LUMBER = 750
    local STANDARD_LUMBER = 450
    local REPEAT_LUMBER = 250
    local STANDARD_COOLDOWN = 300.0 -- Five minutes before the 450-lumber exchange returns.
    local BONUS_COOLDOWN = 600.0 -- Ten minutes without an exchange restores the 750-lumber bonus.
    local EFFECT = "Abilities\\Spells\\Items\\ResourceItems\\ResourceEffectTarget.mdl"

    local GoldToLumber = {}
    local standardTimers = {}
    local bonusTimers = {}

    local function clearTimer(timers, playerId)
        local timer = timers[playerId]

        if timer then
            timer:destroy()
            timers[playerId] = nil
        end
    end

    local function restoreStandardExchange(player)
        local playerId = GetPlayerId(player)

        standardTimers[playerId] = nil
        SetPlayerTechResearched(player, IDS.EXCHANGE_RESEARCH, 1)
    end

    local function restoreBonusExchange(player)
        local playerId = GetPlayerId(player)

        bonusTimers[playerId] = nil
        clearTimer(standardTimers, playerId)
        SetPlayerTechResearched(player, IDS.EXCHANGE_RESEARCH, 0)
    end

    local function startStandardCooldown(player)
        local playerId = GetPlayerId(player)

        if standardTimers[playerId] then
            return
        end

        SetPlayerTechResearched(player, IDS.EXCHANGE_RESEARCH, 1)
        standardTimers[playerId] = GameTimer.after(STANDARD_COOLDOWN, function()
            restoreStandardExchange(player)
        end)
    end

    local function startBonusCooldown(player)
        local playerId = GetPlayerId(player)

        clearTimer(bonusTimers, playerId)
        bonusTimers[playerId] = GameTimer.after(BONUS_COOLDOWN, function()
            restoreBonusExchange(player)
        end)
    end

    local function lumberForResearch(player)
        local rate = GetPlayerTechCount(player, IDS.EXCHANGE_RESEARCH, false)

        if rate >= 3 then
            SetPlayerTechResearched(player, IDS.EXCHANGE_RESEARCH, 2)
            return REPEAT_LUMBER
        end

        startStandardCooldown(player)
        if rate == 2 then
            return STANDARD_LUMBER
        end
        return BONUS_LUMBER
    end

    local function exchange(unit)
        local player = GetOwningPlayer(unit)
        local lumber = lumberForResearch(player)

        startBonusCooldown(player)
        DestroyEffect(AddSpecialEffect(EFFECT, GetUnitX(unit), GetUnitY(unit)))
        SetPlayerState(player, PLAYER_STATE_RESOURCE_LUMBER, GetPlayerState(player, PLAYER_STATE_RESOURCE_LUMBER) + lumber)
        ShowTagFromUnit.fromUnitWithColor("+" .. I2S(lumber), unit, 50, 205, 50)
        return lumber
    end

    function GoldToLumber.exchange(unit)
        if not unit or GetUnitTypeId(unit) == 0 then
            return 0
        end
        return exchange(unit)
    end

    local function onResearchFinish()
        if GetResearched() == IDS.EXCHANGE_RESEARCH then
            exchange(GetTriggerUnit())
        end
    end

    local trigger = CreateTrigger()
    local i = 0

    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_RESEARCH_FINISH, nil)
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

    TriggerAddAction(trigger, function() guarded(onResearchFinish) end)

    GoldToLumber.ids = IDS

    _G.GoldToLumber = GoldToLumber
end)

if Debug and Debug.endFile then Debug.endFile() end
