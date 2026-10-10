if Debug and Debug.beginFile then Debug.beginFile("Commands/VoteKickCommand") end

OnInit("VoteKickCommand", function(import)
    import.strict("CommandRegistry")
    import.strict("PlayerData")
    import.strict("DefenderLeave")

    local votesAgainst = {}

    local function normalized(text)
        return StringCase(tostring(text or ""), false)
    end

    local function voteList(targetData)
        local id = targetData:id()
        if not votesAgainst[id] then
            votesAgainst[id] = {}
        end
        return votesAgainst[id]
    end

    local function hasVoted(targetData, voterData)
        local list = voteList(targetData)
        local i = 1
        while i <= #list do
            if list[i] == voterData then
                return true
            end
            i = i + 1
        end
        return false
    end

    local function countVotes(targetData)
        local list = voteList(targetData)
        local count = 0
        local i = 1

        while i <= #list do
            local voterData = list[i]
            if voterData:class() ~= PlayerData.CLASS_OBSERVER and not voterData:isLeaving() and not voterData:hasLeft() then
                count = count + 1
            end
            i = i + 1
        end

        return count
    end

    local function clearVotes(targetData)
        votesAgainst[targetData:id()] = {}
    end

    local function addVote(targetData, voterData)
        if not hasVoted(targetData, voterData) then
            voteList(targetData)[#voteList(targetData) + 1] = voterData
        end
        return countVotes(targetData)
    end

    local function countEligibleRealPlayers()
        local count = 0
        local classes = {
            PlayerData.CLASS_DEFENDER,
            PlayerData.CLASS_TITAN,
            PlayerData.CLASS_MINION
        }
        local c = 1

        while c <= #classes do
            local list = PlayerData.withClass(classes[c])
            local i = 0
            while i < list:size() do
                local playerData = list:at(i)
                if not playerData:isFake() and not playerData:isLeaving() and not playerData:hasLeft() then
                    count = count + 1
                end
                i = i + 1
            end
            list:destroy()
            c = c + 1
        end

        return count
    end

    local function requiredVotes()
        local count = countEligibleRealPlayers()
        local required = R2I((I2R(count) + 1.0) * 0.65)
        if required <= 1 then
            return 12
        end
        return required
    end

    local function findPlayerByQuery(query)
        local wanted = normalized(query)
        local numeric = tonumber(wanted or "")
        local list = PlayerData.allReal()
        local found = nil
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            local id = playerData:id()
            local name = normalized(playerData:name())

            if numeric and (numeric == id or numeric == id + 1) then
                if found then
                    list:destroy()
                    return nil
                end
                found = playerData
            elseif wanted ~= "" and (name == wanted or StringIndexOf(name, wanted, false) == 0) then
                if found then
                    list:destroy()
                    return nil
                end
                found = playerData
            end

            i = i + 1
        end

        list:destroy()
        return found
    end

    local function boot(targetData)
        local dialog = DialogCreate()
        local player = targetData:player()

        DialogSetMessage(dialog, "You have been voted off the Island!")
        DialogAddButton(dialog, "Quit", 0)
        -- Run the same class-specific transfer/cleanup flow as a normal leave
        -- before Warcraft removes the player and emits its leave event.
        DefenderLeave.handle(targetData)
        -- Keep the original RemovePlayer behavior, then explicitly enter the
        -- defeat flow as well. RemovePlayer alone does not reliably show the
        -- defeat screen in current Warcraft clients.
        RemovePlayer(player, PLAYER_GAME_RESULT_DEFEAT)
        if rawget(_G, "CustomDefeatBJ") then
            CustomDefeatBJ(player, "You have been voted off the Island!")
        end
        DialogDisplay(player, dialog, true)
    end

    local function checkVotes(targetData)
        local votes = countVotes(targetData)
        local required = requiredVotes()

        if targetData:hasLeft() or targetData:isLeaving() then
            return false
        end

        if votes >= required then
            Game.say("|cff00bfffVote has succeeded, |r" .. targetData:nameColored() ..
                "|cff00bfff will now be removed from the Island.|r")
            boot(targetData)
            return true
        end

        Game.say(I2S(required - votes) .. "|cff00bfff more votes are required to remove |r" ..
            targetData:nameColored() .. "|cff00bfff from the game.|r")
        return false
    end

    local function run(args)
        local voterData = PlayerData.get(args:player())
        local targetData = nil

        if not voterData then
            return
        end

        if voterData:class() == PlayerData.CLASS_OBSERVER then
            Command.say(args:player(), "|cffff0000Sorry, only people that aren't watchers are allowed to remove others from the game.|r")
            return
        end

        if args:count() == 0 then
            Command.say(args:player(), "|cffff0000Please specify a player you would like to boot.|r")
            return
        end

        targetData = findPlayerByQuery(args:joinedFrom(0))
        if not targetData or targetData:isLeaving() or targetData:hasLeft() then
            Command.say(args:player(), "|cffff0000You have specified an invalid player.|r")
            return
        end

        if targetData:class() == PlayerData.CLASS_OBSERVER then
            Command.say(args:player(), "|cffff0000You must specify a Defender, Titan, or a Minion|r")
            clearVotes(targetData)
            return
        end

        if targetData:class() == PlayerData.CLASS_TITAN then
            Command.say(args:player(), "|cffff0000You can't votekick a Titan. This isn't a democracy, it's the Island!|r")
            clearVotes(targetData)
            return
        end

        if targetData:class() == PlayerData.CLASS_MINION then
            Command.say(args:player(), "|cffff0000You can't votekick a Minion. Minions follow orders, not popularity polls.|r")
            clearVotes(targetData)
            return
        end

        if PlayerData.countReal() <= 2 then
            Command.say(args:player(), "|cffff0000You may not use votekick with 2 players or less|r")
            clearVotes(targetData)
            return
        end

        if hasVoted(targetData, voterData) then
            if checkVotes(targetData) then
                return
            end
            Command.say(args:player(), "|cff00bfffYou have already voted to remove " ..
                targetData:nameColored() .. " from the game.|r")
            return
        end

        addVote(targetData, voterData)
        checkVotes(targetData)
    end

    Command["-vk"].register(run, "Votes to kick a defender from the game.")
    Command["-votekick"].register(run, "Votes to kick a defender from the game.")

    _G.VoteKickCommand = {
        requiredVotes = requiredVotes,
        countVotes = countVotes,
        clearVotes = clearVotes
    }
end)

if Debug and Debug.endFile then Debug.endFile() end
