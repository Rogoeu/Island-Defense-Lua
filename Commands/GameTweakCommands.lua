if Debug and Debug.beginFile then Debug.beginFile("Commands/GameTweakCommands") end

OnInit("GameTweakCommands", function(import)
    import.strict("CommandRegistry")
    import.strict("GameSettings")
    import.strict("PlayerData")
    import.strict("IslandDefenseMultiboard")
    import.strict("GameTimer")

    local activeVote = nil

    local function sayAll(text)
        if rawget(_G, "Game") and Game.say then
            Game.say(text)
        else
            DisplayTimedTextToForce(GetPlayersAll(), 10, text)
        end
    end

    local function boolText(value)
        if value then
            return "|cff80ff80on|r"
        end
        return "|cffff6060off|r"
    end

    local function refresh()
        local parts = {}

        if GameSettings.getBool("TITAN_EXP_GLOBAL_FACTOR_DOUBLED") then
            parts[#parts + 1] = "EXP"
        end
        if not GameSettings.getBool("TITAN_EXP_REDUCTION_ENABLED") then
            parts[#parts + 1] = "FROFF"
        end
        if GameSettings.getStr("TWEAK_GC") == "on" then
            parts[#parts + 1] = "GC"
        end

        if #parts == 0 then
            GameSettings.setStr("MULTIBOARD_TWEAKS", "")
        elseif #parts == 1 then
            GameSettings.setStr("MULTIBOARD_TWEAKS", parts[1])
        else
            local text = parts[1]
            local i = 2
            while i <= #parts do
                text = text .. "/" .. parts[i]
                i = i + 1
            end
            GameSettings.setStr("MULTIBOARD_TWEAKS", text)
        end

        if rawget(_G, "IslandDefenseMultiboard") then
            IslandDefenseMultiboard.setTweaks("")
            IslandDefenseMultiboard.refresh()
        end
    end

    local function requireStarted(player)
        if rawget(_G, "Game") and Game.isState and not Game.isState(Game.STATE_STARTED) then
            Command.say(player, "|cffff6060This tweak can only be changed after the game has started.|r")
            return false
        end
        return true
    end

    local function requireDefender(player)
        local playerData = PlayerData.get(player)
        if not playerData or playerData:class() ~= PlayerData.CLASS_DEFENDER then
            Command.say(player, "|cffff6060Only Defenders can vote/change this tweak.|r")
            return false
        end
        return true
    end

    local function defenderCount()
        local list = PlayerData.withClass(PlayerData.CLASS_DEFENDER)
        local count = 0
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            if not playerData:isFake() and not playerData:isLeaving() and not playerData:hasLeft() then
                count = count + 1
            end
            i = i + 1
        end

        list:destroy()
        return count
    end

    local function requiredDefenderVotes()
        return R2I((I2R(defenderCount()) + 1.0) / 2.0)
    end

    local function voteCount(vote)
        local count = 0
        for _ in pairs(vote.voters) do
            count = count + 1
        end
        return count
    end

    local function finishVote(success)
        local vote = activeVote
        activeVote = nil

        if not vote then
            return
        end

        if vote.timer then
            vote.timer:destroy()
        end
        IslandDefenseMultiboard.endVote()

        if success then
            sayAll("|cff00bfffVote has succeeded: |r|cffffff80" .. vote.name .. "|r|cff00bfff.|r")
            vote.apply(vote.value)
        else
            sayAll("|cffff6060Vote failed: |r|cffffff80" .. vote.name .. "|r|cffff6060.|r")
        end
    end

    local function addVote(playerData)
        local id = playerData:id()
        if activeVote.voters[id] then
            playerData:say("|cff00bfffYou have already voted for " .. activeVote.name .. ".|r")
            return
        end

        activeVote.voters[id] = true
        IslandDefenseMultiboard.updateVote(activeVote.voters)
        local votes = voteCount(activeVote)
        if votes >= activeVote.required then
            finishVote(true)
        else
            sayAll(I2S(activeVote.required - votes) ..
                "|cff00bfff more Defender votes are required for |r|cffffff80" ..
                activeVote.name .. "|r|cff00bfff.|r")
        end
    end

    local function beginOrVote(playerData, name, value, apply)
        if defenderCount() <= 1 then
            apply(value)
            return
        end

        if activeVote then
            if activeVote.name ~= name or activeVote.value ~= value then
                playerData:say("|cffff6060Another tweak vote is already running.|r")
                return
            end
            addVote(playerData)
            return
        end

        activeVote = {
            name = name,
            value = value,
            apply = apply,
            required = requiredDefenderVotes(),
            voters = {}
        }
        activeVote.timer = GameTimer.after(30.0, function()
            if activeVote then
                finishVote(false)
            end
        end)

        IslandDefenseMultiboard.beginVote(name, activeVote.voters, 30.0)
        sayAll("|cff00bfffVote started for |r|cffffff80" .. name ..
            "|r|cff00bfff. Only Defender votes count.|r")
        addVote(playerData)
    end

    local function setExp(value)
        GameSettings.setBool("TITAN_EXP_GLOBAL_FACTOR_DOUBLED", value)
        if value then
            sayAll("|cff00bfffEXP enabled: Titan and Minions gain double experience.|r")
        else
            sayAll("|cff00bfffEXP disabled: Titan and Minions gain normal experience.|r")
        end
        refresh()
    end

    local function setFeedReductionEnabled(value)
        GameSettings.setBool("TITAN_EXP_REDUCTION_ENABLED", value)
        if value then
            sayAll("|cff00bfffFR enabled: Titan feed reduction is active.|r")
        else
            sayAll("|cff00bfffFR disabled: Titan gains experience at full rate.|r")
        end
        refresh()
    end

    local function setGoldCoin(value)
        GameSettings.setStr("TWEAK_GC", value and "on" or "off")
        if value then
            sayAll("|cff00bfffGC enabled: Titan-side kills can award gold coins.|r")
        else
            sayAll("|cff00bfffGC disabled: gold coin drops are off.|r")
        end
        refresh()
    end

    local function requestedState(args, current)
        local value = StringCase(args:at(0), false)
        if value == "on" or value == "enable" or value == "enabled" then
            return true
        elseif value == "off" or value == "disable" or value == "disabled" then
            return false
        end
        return not current
    end

    Command["-exp"].register(function(args)
        if not requireStarted(args:player()) or not requireDefender(args:player()) then
            return
        end
        local value = requestedState(args, GameSettings.getBool("TITAN_EXP_GLOBAL_FACTOR_DOUBLED"))
        beginOrVote(PlayerData.get(args:player()), value and "EXP on" or "EXP off", value, setExp)
    end, "Toggles double Titan/Minion experience.")

    Command["-dxp"].register(function(args)
        Command["-exp"].run(args)
    end, "Alias for -exp.")

    Command["-xp"].register(function(args)
        Command["-exp"].run(args)
    end, "Alias for -exp.")

    Command["-fr"].register(function(args)
        if not requireStarted(args:player()) or not requireDefender(args:player()) then
            return
        end
        local value = requestedState(args, GameSettings.getBool("TITAN_EXP_REDUCTION_ENABLED"))
        beginOrVote(PlayerData.get(args:player()), value and "FR on" or "FR off", value, setFeedReductionEnabled)
    end, "Toggles feed reduction off/on.")

    Command["-froff"].register(function(args)
        if not requireStarted(args:player()) or not requireDefender(args:player()) then
            return
        end
        local value = requestedState(args, not GameSettings.getBool("TITAN_EXP_REDUCTION_ENABLED"))
        beginOrVote(PlayerData.get(args:player()), value and "FROFF on" or "FROFF off", not value, setFeedReductionEnabled)
    end, "Alias for -fr.")

    Command["-gc"].register(function(args)
        if not requireStarted(args:player()) or not requireDefender(args:player()) then
            return
        end
        local value = requestedState(args, GameSettings.getStr("TWEAK_GC") == "on")
        beginOrVote(PlayerData.get(args:player()), value and "GC on" or "GC off", value, setGoldCoin)
    end, "Toggles gold coin drops for Titan-side kills.")

    Command["-vb"].register(function(args)
        local value = StringCase(tostring(args:at(0) or ""), false)

        if value == "on" then
            IslandDefenseMultiboard.setVotingBoardEnabled(args:player(), true)
            Command.say(args:player(), "|cff00bfffThe voting board will now be displayed.|r")
        elseif value == "off" then
            IslandDefenseMultiboard.setVotingBoardEnabled(args:player(), false)
            Command.say(args:player(), "|cff00bfffThe voting board will no longer be displayed.|r")
        else
            Command.say(args:player(), "|cff99b4d1Command usage: |r-vb <on/off>|r")
        end
    end, "Shows or hides the voting board for you.")

    Command["-tweaks"].register(function(args)
        Command.say(args:player(), "|cff99b4d1EXP: |r" .. boolText(GameSettings.getBool("TITAN_EXP_GLOBAL_FACTOR_DOUBLED")))
        Command.say(args:player(), "|cff99b4d1FROFF: |r" .. boolText(not GameSettings.getBool("TITAN_EXP_REDUCTION_ENABLED")))
        Command.say(args:player(), "|cff99b4d1GC: |r" .. boolText(GameSettings.getStr("TWEAK_GC") == "on"))
    end, "Shows current game tweak settings.")

    refresh()

    _G.GameTweakCommands = {
        setExp = setExp,
        setFeedReductionEnabled = setFeedReductionEnabled,
        setGoldCoin = setGoldCoin
    }
end)

if Debug and Debug.endFile then Debug.endFile() end
