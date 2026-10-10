if Debug and Debug.beginFile then Debug.beginFile("Systems/PenaltyTimer") end

OnInit("PenaltyTimer", function(import)
    import.strict("GameTimer")
    import.strict("PlayerData")

    local FIRST_PENALTY_SECONDS = 1800.0
    local REPEAT_PENALTY_SECONDS = 600.0
    local ANNOUNCE_SECONDS = 300.0
    local FIRST_PENALTY_GOLD = 90
    local REPEAT_PENALTY_GOLD = 45

    local active = false
    local firstPenalty = true
    local nextPenaltyAt = 0.0
    local penaltyTimer = nil
    local announceTimer = nil

    local PenaltyTimer = {}

    local function elapsed()
        if rawget(_G, "Game") and Game.currentGameElapsed then
            return Game.currentGameElapsed()
        end
        return 0.0
    end

    local function minutes(value)
        return I2S(math.max(0, R2I(value / 60.0 + 0.5)))
    end

    local function defenderList()
        return PlayerData.withClass(PlayerData.CLASS_DEFENDER)
    end

    local function giveDefendersGold(amount)
        local list = defenderList()
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)

            if not playerData:isLeaving() then
                playerData:setGold(playerData:gold() + amount)
            end
            i = i + 1
        end
        list:destroy()
    end

    local function announceUpcoming()
        local remaining = nextPenaltyAt - elapsed()
        local amount = firstPenalty and FIRST_PENALTY_GOLD or REPEAT_PENALTY_GOLD
        local label = firstPenalty and "30 minute gold penalty" or "10 minute penalty"

        if not active or remaining <= 0.5 then
            return
        end

        Game.say("|r" .. minutes(remaining) .. "|cff99b4d1 minutes until the " .. label .. " will be enforced.\n" ..
            "All remaining Defenders will gain |cffffcc00" .. I2S(amount) .. " Gold|cff99b4d1.|r")
    end

    local function enforcePenalty()
        local amount = firstPenalty and FIRST_PENALTY_GOLD or REPEAT_PENALTY_GOLD
        local label = firstPenalty and "30 minute penalty" or "10 minute penalty"

        if not active then
            return
        end

        Game.say("|cff99b4d1The " .. label .. " has been enforced.\n" ..
            "All remaining Defenders have now gained |cffffcc00" .. I2S(amount) .. " Gold|cff99b4d1.|r")
        giveDefendersGold(amount)

        firstPenalty = false
        nextPenaltyAt = elapsed() + REPEAT_PENALTY_SECONDS
        if penaltyTimer then
            penaltyTimer:destroy()
        end
        penaltyTimer = GameTimer.after(REPEAT_PENALTY_SECONDS, enforcePenalty)
    end

    function PenaltyTimer.initialize()
        PenaltyTimer.terminate()

        active = true
        firstPenalty = true
        nextPenaltyAt = elapsed() + FIRST_PENALTY_SECONDS
        penaltyTimer = GameTimer.after(FIRST_PENALTY_SECONDS, enforcePenalty)
        announceTimer = GameTimer.every(ANNOUNCE_SECONDS, announceUpcoming)
    end

    function PenaltyTimer.terminate()
        active = false
        firstPenalty = true
        nextPenaltyAt = 0.0

        if penaltyTimer then
            penaltyTimer:destroy()
            penaltyTimer = nil
        end
        if announceTimer then
            announceTimer:destroy()
            announceTimer = nil
        end
    end

    _G.PenaltyTimer = PenaltyTimer
end)

if Debug and Debug.endFile then Debug.endFile() end
