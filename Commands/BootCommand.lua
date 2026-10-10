if Debug and Debug.beginFile then Debug.beginFile("Commands/BootCommand") end

OnInit("BootCommand", function(import)
    import.strict("CommandRegistry")
    import.strict("PlayerData")

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
            if voterData:class() == PlayerData.CLASS_DEFENDER and not voterData:isLeaving() and not voterData:hasLeft() then
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

    local function requiredVotes()
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
        -- Zinc used integer division here. Lua's / would produce fractional
        -- thresholds for even counts and make I2S(required - votes) fail.
        return math.floor((count + 1) / 2)
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

        DialogSetMessage(dialog, "You have been booted from the game!")
        DialogAddButton(dialog, "Quit", 0)
        RemovePlayer(targetData:player(), PLAYER_GAME_RESULT_DEFEAT)
        DialogDisplay(targetData:player(), dialog, true)
    end

    local function checkVotes(targetData)
        local votes = countVotes(targetData)
        local required = requiredVotes()

        if targetData:hasLeft() or targetData:isLeaving() then
            return false
        end

        if votes >= required then
            Game.say("|cff00bfffVote has succeeded, |r" .. targetData:nameColored() ..
                "|cff00bfff will now be removed from the game.|r")
            boot(targetData)
            return true
        end

        Game.say(I2S(required - votes) .. "|cff00bfff more votes are required to remove |r" ..
            targetData:nameColored() .. "|cff00bfff from the game.|r")
        return false
    end

    Command["-boot"].register(function(args)
        local voterData = PlayerData.get(args:player())
        local targetData = nil

        if not voterData then
            return
        end

        if voterData:class() ~= PlayerData.CLASS_DEFENDER then
            Command.say(args:player(), "|cffff0000Sorry, only Defenders are allowed to remove Observers from the game.|r")
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

        if targetData:class() ~= PlayerData.CLASS_OBSERVER then
            Command.say(args:player(), "|cffff0000You must specify an Observer.|r")
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
    end, "Defenders: votes to boot an observer.")

    _G.BootCommand = {
        requiredVotes = requiredVotes,
        countVotes = countVotes,
        clearVotes = clearVotes
    }
end)

if Debug and Debug.endFile then Debug.endFile() end
