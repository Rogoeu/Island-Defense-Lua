if Debug and Debug.beginFile then Debug.beginFile("Systems/DefenderLeave") end

OnInit("DefenderLeave", function(import)
    import.strict("CommandRegistry")
    import.strict("IslandDefenseSystem")
    import.strict("GameTimer")
    import.strict("GameSettings")
    import.strict("PlayerData")
    import.strict("TeamAlliances")
    import.strict("UnitSpawner")
    import.strict("IslandDefenseMultiboard")
    import.strict("DefenderDeath")
    import.strict("PlayerProfile")

    local LEAVE_GRACE_KEY = "DEFENDER_LEAVE_GRACE_SECONDS"
    local LEAVE_GRACE_DEFAULT = 30.0
    local TITAN_AFK_WARNING_DEFAULT = 240.0
    local TITAN_AFK_TIMEOUT_DEFAULT = 300.0
    local TITAN_AFK_VOTE_DEFAULT = 30.0

    local DefenderLeave = {}
    local titanRecovery = {
        active = false,
        titanData = nil,
        pausedGame = false,
        reason = ""
    }
    local titanAfk = {
        playerId = -1,
        idleSeconds = 0.0,
        warned = false
    }
    local titanAfkVote = nil
    local finishTitanAfkVote = nil

    local function leaveGraceSeconds()
        if GameSettings.exists(LEAVE_GRACE_KEY) then
            return GameSettings.getReal(LEAVE_GRACE_KEY)
        end
        return LEAVE_GRACE_DEFAULT
    end

    local function titanAfkWarningSeconds()
        local seconds = GameSettings.getReal("TITAN_AFK_WARNING_SECONDS")
        if seconds <= 0.0 then
            return TITAN_AFK_WARNING_DEFAULT
        end
        return seconds
    end

    local function titanAfkTimeoutSeconds()
        local seconds = GameSettings.getReal("TITAN_AFK_TIMEOUT_SECONDS")
        if seconds <= 0.0 then
            return TITAN_AFK_TIMEOUT_DEFAULT
        end
        return seconds
    end

    local function titanAfkVoteSeconds()
        local seconds = GameSettings.getReal("TITAN_AFK_VOTE_SECONDS")
        if seconds <= 0.0 then
            return TITAN_AFK_VOTE_DEFAULT
        end
        return seconds
    end

    local function nameColored(playerData)
        if playerData and playerData.nameColored then
            return playerData:nameColored()
        end
        if playerData then
            return playerData:name()
        end
        return "Unknown"
    end

    local function isBuilderSideReceiver(playerData)
        if not playerData or playerData:hasLeft() then
            return false
        end
        return playerData:class() == PlayerData.CLASS_DEFENDER and not playerData:isObserver()
    end

    local function refreshAlliances()
        TeamAlliances.refresh()
    end

    local function setSharedControl(owner, receiver, enabled)
        SetPlayerAlliance(owner, receiver, ALLIANCE_PASSIVE, enabled)
        SetPlayerAlliance(owner, receiver, ALLIANCE_SHARED_VISION, enabled)
        SetPlayerAlliance(owner, receiver, ALLIANCE_SHARED_CONTROL, enabled)
        SetPlayerAlliance(owner, receiver, ALLIANCE_SHARED_ADVANCED_CONTROL, enabled)
    end

    local function shareLeavingDefender(playerData, enabled)
        local list = PlayerData.allWithFake()
        local owner = playerData:player()
        local i = 0

        while i < list:size() do
            local receiver = list:at(i)
            if receiver ~= playerData and isBuilderSideReceiver(receiver) then
                setSharedControl(owner, receiver:player(), enabled)
            end
            i = i + 1
        end

        list:destroy()
    end

    TeamAlliances.onRefresh(function()
        local list = PlayerData.withClass(PlayerData.CLASS_DEFENDER)
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            if playerData:isLeaving() and not playerData:hasLeft() then
                shareLeavingDefender(playerData, true)
            end
            i = i + 1
        end
        list:destroy()
    end)

    local function transferUnits(fromPlayer, toPlayer)
        local group = CreateGroup()
        local unit = nil

        GroupEnumUnitsOfPlayer(group, fromPlayer, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            SetUnitOwner(unit, toPlayer, true)
            unit = FirstOfGroup(group)
        end

        DestroyGroup(group)
    end

    local function removeNonStructures(player)
        local group = CreateGroup()
        local unit = nil

        GroupEnumUnitsOfPlayer(group, player, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if not IsUnitType(unit, UNIT_TYPE_STRUCTURE) then
                RemoveUnit(unit)
            end
            unit = FirstOfGroup(group)
        end

        DestroyGroup(group)
    end

    local function removeAllUnits(player)
        local group = CreateGroup()
        local unit = nil

        GroupEnumUnitsOfPlayer(group, player, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            RemoveUnit(unit)
            unit = FirstOfGroup(group)
        end

        DestroyGroup(group)
    end

    local function knownRaceTechIds(race)
        local ids = {}
        local seen = {}

        local function add(id)
            if type(id) == "string" then
                id = FourCC(id)
            end
            if id and id ~= 0 and not seen[id] then
                ids[#ids + 1] = id
                seen[id] = true
            end
        end

        if race and race ~= NullRace.instance() then
            local techIds = race:techIds()
            local limits = race:techLimits()
            local ultimateTowers = race:ultimateTowerIds()
            local i = 1

            while i <= #techIds do
                add(techIds[i])
                i = i + 1
            end

            i = 1
            while i <= #limits do
                add(limits[i].id)
                i = i + 1
            end

            i = 1
            while i <= #ultimateTowers do
                add(ultimateTowers[i])
                i = i + 1
            end
        end

        return ids
    end

    local function copyKnownTech(fromPlayer, toPlayer, race)
        local ids = knownRaceTechIds(race)
        local i = 1

        while i <= #ids do
            local id = ids[i]
            local count = GetPlayerTechCount(fromPlayer, id, true)
            if count > 0 then
                SetPlayerTechResearched(toPlayer, id, count)
            end
            i = i + 1
        end
    end

    local function applyRaceTechLimits(player, race)
        if not race or race == NullRace.instance() then
            return
        end

        local ultimateTowers = race:ultimateTowerIds()
        local techLimits = race:techLimits()
        local i = 1

        while i <= #ultimateTowers do
            local id = ultimateTowers[i]
            if type(id) == "string" then
                id = FourCC(id)
            end
            SetPlayerTechMaxAllowed(player, id, 0)
            i = i + 1
        end

        i = 1
        while i <= #techLimits do
            local id = techLimits[i].id
            if type(id) == "string" then
                id = FourCC(id)
            end
            SetPlayerTechMaxAllowed(player, id, techLimits[i].max)
            i = i + 1
        end
    end

    local function copyFeedData(fromData, toData)
        local feedApi = rawget(_G, "PlayerDataFed")
        if not feedApi or not feedApi.get then
            return
        end

        local from = feedApi.get(fromData)
        local to = feedApi.get(toData)
        if from and to then
            to.fed = from.fed
            to.fedRecent = from.fedRecent
            to.rate = from.rate
            to.burstMult = from.burstMult
            to.goldFed = from.goldFed
            to.burstPending = from.burstPending
            to.burstApplyAt = from.burstApplyAt
        end
    end

    local function findReplacementMinion()
        local list = PlayerData.withClass(PlayerData.CLASS_MINION)
        local found = nil
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            if not playerData:isFake() and not playerData:isLeaving() and not playerData:hasLeft() then
                found = playerData
                i = list:size()
            end
            i = i + 1
        end

        list:destroy()
        return found
    end

    local function currentTitanData()
        local list = PlayerData.withClass(PlayerData.CLASS_TITAN)
        local found = nil
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            if not playerData:isLeaving() and not playerData:hasLeft() then
                found = playerData
                i = list:size()
            end
            i = i + 1
        end

        list:destroy()
        return found
    end

    local function canVolunteerAsTitan(playerData)
        if not playerData or playerData:isFake() or playerData:hasLeft() or playerData:isLeaving() then
            return false
        end
        return playerData:isObserver() or
            playerData:class() == PlayerData.CLASS_MINION or
            playerData:class() == PlayerData.CLASS_DEFENDER
    end

    local function clearTitanRecovery()
        if titanRecovery.active and titanRecovery.pausedGame then
            PauseGame(false)
            Game.resume()
        end

        titanRecovery.active = false
        titanRecovery.titanData = nil
        titanRecovery.pausedGame = false
        titanRecovery.reason = ""
    end

    local function retireOldTitan(titanData)
        titanData:setClass(PlayerData.CLASS_OBSERVER)
        titanData:setObserver(true)
        titanData:setObserveTeam("titan")
        titanData:setRace(NullRace.instance())
        titanData:setPicked(false)
        titanData:setRandoming(false)
        titanData:setCanPick(false)
        titanData:setUnit(nil)
        titanData:setGold(0)
        titanData:setLumber(0)
        titanData:setLeaving(false)
        titanData:setLeft(true)
    end

    local function promoteToTitan(newTitanData, oldTitanData, volunteered, reason)
        if not newTitanData or not oldTitanData then
            return false
        end

        local oldPlayer = oldTitanData:player()
        local newPlayer = newTitanData:player()
        local oldRace = oldTitanData:race()
        local oldUnit = oldTitanData:unit()
        local oldGold = oldTitanData:gold()
        local oldLumber = oldTitanData:lumber()
        local oldPicked = oldTitanData:hasPicked()
        local oldRandoming = oldTitanData:isRandoming()
        local previousUnit = newTitanData:unit()
        local previousClass = newTitanData:class()

        if previousClass == PlayerData.CLASS_DEFENDER then
            removeAllUnits(newPlayer)
            previousUnit = nil
            newTitanData:setUnit(nil)
        elseif previousClass ~= PlayerData.CLASS_MINION and
            previousUnit and previousUnit ~= oldUnit and GetUnitTypeId(previousUnit) ~= 0 then
            RemoveUnit(previousUnit)
        end

        newTitanData:setObserver(false)
        newTitanData:setObserveTeam("")
        newTitanData:setClass(PlayerData.CLASS_TITAN)
        newTitanData:setRace(oldRace)
        newTitanData:setPicked(oldPicked)
        newTitanData:setRandoming(oldRandoming)
        newTitanData:setCanPick(false)
        newTitanData:setGold(oldGold)
        newTitanData:setLumber(oldLumber)
        newTitanData:setUnit(oldUnit)

        transferUnits(oldPlayer, newPlayer)
        UnitSpawner.setTitanShopOwner(newPlayer)
        if rawget(_G, "PunishmentCentre") and PunishmentCentre.update then
            PunishmentCentre.update()
        end
        retireOldTitan(oldTitanData)
        clearTitanRecovery()

        if PlayerProfile.isMatchResultRecorded() then
            IslandDefenseMultiboard.setPhase("Playing for fun - no Elo", 0)
            Game.say("|cffffff80The rated result is final. This continuation does not count for Elo or match statistics.|r")
        end

        refreshAlliances()
        if rawget(_G, "RefreshObserverViews") then
            RefreshObserverViews()
        end
        UnitSpawner.focusMainUnitCamera(newTitanData, true)
        IslandDefenseMultiboard.refresh()

        if volunteered then
            Game.say(nameColored(newTitanData) .. "|cff00bfff has taken over as the Titan. Game resumed.|r")
        elseif reason == "afk" then
            Game.say(nameColored(oldTitanData) .. "|cffff6060 was removed for inactivity. |r" ..
                nameColored(newTitanData) .. "|cff00bfff is now the Titan.|r")
        else
            Game.say(nameColored(oldTitanData) .. "|cff90b0d0 has left the game. |r" .. nameColored(newTitanData) .. "|cff00bfff is now the Titan.|r")
        end
        return true
    end

    local function pauseForTitanReplacement(titanData, reason)
        titanRecovery.active = true
        titanRecovery.titanData = titanData
        titanRecovery.pausedGame = not Game.isState(Game.STATE_PAUSED)
        titanRecovery.reason = reason or "leave"

        titanData:setLeaving(true)
        if titanRecovery.pausedGame then
            Game.pause()
            PauseGame(true)
        end
        IslandDefenseMultiboard.refresh()

        if reason == "afk" then
            Game.say(nameColored(titanData) ..
                "|cffff6060 is inactive and no Minion can take over. Game paused. The Titan may return with |r|cffffff80-titan|r" ..
                "|cffff6060, or a Builder/Observer can take over with the same command.|r")
        else
            Game.say(nameColored(titanData) .. "|cffff6060 has left. Game paused. A Builder, Observer or Minion can volunteer as Titan with |r|cffffff80-titan|r|cffff6060 to continue playing.|r")
        end
    end

    function DefenderLeave.handleTitanLeave(titanData)
        local replacement = nil

        if not titanData or titanData:hasLeft() then
            return
        end
        if titanData:isLeaving() and not
            (titanRecovery.active and titanRecovery.titanData == titanData and titanRecovery.reason == "afk") then
            return
        end

        if Game.isState(Game.STATE_FINISHED) then
            titanData:setLeft(true)
            titanData:setLeaving(false)
            return
        end

        -- Settle the rated match before changing roles, but keep gameplay alive
        -- so a volunteer can resume it without any further rating/stat changes.
        if Game.isState(Game.STATE_STARTED) or
            (Game.isState(Game.STATE_PAUSED) and Game.pausedState() == Game.STATE_STARTED) then
            clearTitanRecovery()
            if Game.isState(Game.STATE_PAUSED) then
                PauseGame(false)
                Game.resume()
            end
            -- allReal() excludes leaving players; include the original Titan
            -- in settlement even if AFK recovery had already marked them.
            titanData:setLeaving(false)
            local recorded = PlayerProfile.finishMatch("defenders")
            if recorded then
                Game.say("|cff80ff80The Defenders have won the rated match: the Titan has left.|r")
            end
            pauseForTitanReplacement(titanData, "leave")
            if recorded then
                IslandDefenseMultiboard.showEndBoard("defenders")
            end
            Game.say("|cffffff80The result is saved. Use -titan to continue for fun without further Elo or match statistics.|r")
            return
        end

        if titanData:isLeaving() then
            return
        end
        titanData:setLeaving(true)
        replacement = findReplacementMinion()
        if replacement then
            promoteToTitan(replacement, titanData, false)
        else
            pauseForTitanReplacement(titanData, "leave")
        end
    end

    function DefenderLeave.handleTitanAfk(titanData)
        local replacement = nil

        if not titanData or titanData:isFake() or titanData:isLeaving() or titanData:hasLeft() then
            return false
        end

        titanData:setLeaving(true)
        replacement = findReplacementMinion()
        if replacement then
            return promoteToTitan(replacement, titanData, false, "afk")
        end

        pauseForTitanReplacement(titanData, "afk")
        return true
    end

    function DefenderLeave.handleMinionLeave(minionData)
        local titanData = currentTitanData()

        if not minionData or minionData:isLeaving() or minionData:hasLeft() then
            return
        end

        minionData:setLeaving(true)
        if titanData then
            transferUnits(minionData:player(), titanData:player())
            if rawget(_G, "PunishmentCentre") and PunishmentCentre.update then
                PunishmentCentre.update()
            end
            Game.say(nameColored(minionData) .. "|cff90b0d0 has left the game. Their units were given to |r" .. nameColored(titanData) .. "|cff90b0d0.|r")
        else
            Game.say(nameColored(minionData) .. "|cff90b0d0 has left the game.|r")
        end

        minionData:setUnit(nil)
        minionData:setLeft(true)
        minionData:setLeaving(false)

        refreshAlliances()
        if rawget(_G, "RefreshObserverViews") then
            RefreshObserverViews()
        end
        IslandDefenseMultiboard.refresh()
    end

    local function finishLeavingDefender(playerData)
        if not playerData:isLeaving() or playerData:hasLeft() then
            return
        end

        shareLeavingDefender(playerData, false)
        removeNonStructures(playerData:player())
        local ghosted = DefenderDeath.ghostBuildings(playerData)

        playerData:setUnit(nil)
        playerData:setLeft(true)
        playerData:setLeaving(false)
        GameSettings.setInt("KILLED_DEFENDERS_COUNT", GameSettings.getInt("KILLED_DEFENDERS_COUNT") + 1)

        refreshAlliances()
        if rawget(_G, "RefreshObserverViews") then
            RefreshObserverViews()
        end
        IslandDefenseMultiboard.refresh()

        if ghosted > 0 then
            if DefenderDeath.removeGhostBuildings() then
                Game.say(nameColored(playerData) .. "|cff90b0d0's units have been removed. Their structures will remain for an additional " .. I2S(R2I(DefenderDeath.ghostBuildingsDuration())) .. " seconds.|r")
            else
                Game.say(nameColored(playerData) .. "|cff90b0d0's units have been removed. Their structures will remain until killed.|r")
            end
        else
            Game.say(nameColored(playerData) .. "|cff90b0d0's units have been removed.|r")
        end
    end

    function DefenderLeave.begin(playerData)
        if not playerData or playerData:isLeaving() or playerData:hasLeft() then
            return
        end

        playerData:setLeaving(true)
        shareLeavingDefender(playerData, true)

        Game.say(nameColored(playerData) .. "|cff90b0d0 has left the game. Builder-side players can control their units for |r|cffffff80" .. I2S(R2I(leaveGraceSeconds())) .. " seconds|r|cff90b0d0 or an observer can take over with |r|cffffff80-defender|r|cff90b0d0.|r")
        IslandDefenseMultiboard.refresh()

        GameTimer.after(leaveGraceSeconds(), function()
            finishLeavingDefender(playerData)
        end)
    end

    function DefenderLeave.takeOver(observerData, leaverData)
        if not observerData or not observerData:isObserver() or observerData:observeTeam() == "titan" then
            return false
        end
        if not leaverData or leaverData:class() ~= PlayerData.CLASS_DEFENDER or not leaverData:isLeaving() or leaverData:hasLeft() then
            return false
        end

        local oldPlayer = leaverData:player()
        local newPlayer = observerData:player()
        local race = leaverData:race()

        shareLeavingDefender(leaverData, false)
        observerData:setObserver(false)
        observerData:setObserveTeam("")
        observerData:setClass(PlayerData.CLASS_DEFENDER)
        observerData:setRace(race)
        observerData:setPicked(leaverData:hasPicked())
        observerData:setRandoming(leaverData:isRandoming())
        observerData:setCanPick(false)
        observerData:setGold(leaverData:gold())
        observerData:setLumber(leaverData:lumber())
        observerData:setUnit(leaverData:unit())

        transferUnits(oldPlayer, newPlayer)
        applyRaceTechLimits(newPlayer, race)
        copyKnownTech(oldPlayer, newPlayer, race)
        copyFeedData(leaverData, observerData)

        leaverData:setClass(PlayerData.CLASS_OBSERVER)
        leaverData:setObserver(true)
        leaverData:setObserveTeam("builder")
        leaverData:setRace(NullRace.instance())
        leaverData:setUnit(nil)
        leaverData:setGold(0)
        leaverData:setLumber(0)
        leaverData:setLeaving(false)
        leaverData:setLeft(true)

        refreshAlliances()
        if rawget(_G, "RefreshObserverViews") then
            RefreshObserverViews()
        end
        UnitSpawner.focusMainUnitCamera(observerData, true)
        IslandDefenseMultiboard.refresh()

        Game.say(nameColored(observerData) .. "|cff00bfff is taking over |r" .. nameColored(leaverData) .. "|cff00bfff's units!|r")
        return true
    end

    local function findLeavingDefender(targetId)
        local list = PlayerData.withClass(PlayerData.CLASS_DEFENDER)
        local found = nil
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            if playerData:isLeaving() and not playerData:hasLeft() then
                if not targetId or playerData:id() == targetId then
                    found = playerData
                    i = list:size()
                end
            end
            i = i + 1
        end

        list:destroy()
        return found
    end

    local function targetIdFromArgs(args)
        local value = tonumber(args:at(0) or "")
        if value and value >= 0 and value < bj_MAX_PLAYER_SLOTS then
            return R2I(value)
        end
        return nil
    end

    function DefenderLeave.handle(playerData)
        if not playerData then
            return false
        end
        -- AFK recovery marks the Titan as leaving before an actual disconnect.
        -- Route that disconnect through the match-concession path as well.
        if playerData:class() == PlayerData.CLASS_TITAN and not playerData:hasLeft() then
            DefenderLeave.handleTitanLeave(playerData)
            return true
        end
        if playerData:isLeaving() or playerData:hasLeft() then
            return false
        end

        if playerData:class() == PlayerData.CLASS_DEFENDER then
            DefenderLeave.begin(playerData)
        elseif playerData:class() == PlayerData.CLASS_MINION then
            DefenderLeave.handleMinionLeave(playerData)
        else
            playerData:setLeft(true)
            playerData:setLeaving(false)
            Game.say(nameColored(playerData) .. "|cff90b0d0 has left the game.|r")
            IslandDefenseMultiboard.refresh()
        end
        return true
    end

    local function onLeave()
        local playerData = PlayerData.get(GetTriggerPlayer())

        if titanAfkVote and titanAfkVote.titanData == playerData then
            finishTitanAfkVote(false, "cancelled")
        end
        DefenderLeave.handle(playerData)
    end

    local function resetTitanAfk(player)
        local playerId = player and GetPlayerId(player) or -1

        titanAfk.playerId = playerId
        titanAfk.idleSeconds = 0.0
        titanAfk.warned = false
    end

    local function eligibleAfkVoters()
        local list = PlayerData.withClass(PlayerData.CLASS_DEFENDER)
        local voters = {}
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            if not playerData:isFake() and not playerData:isObserver() and
                not playerData:isLeaving() and not playerData:hasLeft() then
                voters[#voters + 1] = playerData
            end
            i = i + 1
        end

        list:destroy()
        return voters
    end

    local function closeTitanAfkVote(vote)
        local i = 1
        local trigger = nil
        local dialog = nil

        if not vote then
            return
        end
        if vote.timer then
            vote.timer:destroy()
            vote.timer = nil
        end
        while i <= #vote.eligible do
            DialogDisplay(vote.eligible[i]:player(), vote.dialog, false)
            i = i + 1
        end
        trigger = vote.trigger
        dialog = vote.dialog
        vote.trigger = nil
        vote.dialog = nil
        if trigger then
            DisableTrigger(trigger)
        end
        GameTimer.after(0.0, function()
            if trigger then
                DestroyTrigger(trigger)
            end
            if dialog then
                DialogClear(dialog)
                DialogDestroy(dialog)
            end
        end)
    end

    finishTitanAfkVote = function(removeTitan, reason)
        local vote = titanAfkVote

        if not vote then
            return
        end
        titanAfkVote = nil
        closeTitanAfkVote(vote)

        if removeTitan and Game.isState(Game.STATE_STARTED) and
            vote.titanData and not vote.titanData:isLeaving() and not vote.titanData:hasLeft() then
            Game.say("|cffff6060The Defenders voted to remove the inactive Titan.|r")
            resetTitanAfk(nil)
            DefenderLeave.handleTitanAfk(vote.titanData)
        else
            resetTitanAfk(vote.titanData and vote.titanData:player() or nil)
            if reason == "returned" then
                Game.say(nameColored(vote.titanData) ..
                    "|cff80ff80 is active again. The AFK vote was cancelled.|r")
            elseif reason ~= "cancelled" then
                Game.say("|cff80ff80The Defenders chose to wait for the Titan.|r")
            end
        end
    end

    local function countAfkVotes(vote, removeTitan)
        local count = 0

        for _, choice in pairs(vote.votes) do
            if choice == removeTitan then
                count = count + 1
            end
        end
        return count
    end

    local function castTitanAfkVote(player, removeTitan)
        local vote = titanAfkVote
        local playerData = player and PlayerData.get(player) or nil
        local id = playerData and playerData:id() or -1

        if not vote or not vote.eligibleById[id] or vote.votes[id] ~= nil then
            return
        end

        vote.votes[id] = removeTitan == true
        DialogDisplay(player, vote.dialog, false)

        if countAfkVotes(vote, true) >= vote.required then
            finishTitanAfkVote(true, "majority")
        elseif countAfkVotes(vote, false) >= vote.required then
            finishTitanAfkVote(false, "majority")
        elseif countAfkVotes(vote, true) + countAfkVotes(vote, false) >= #vote.eligible then
            finishTitanAfkVote(false, "tie")
        end
    end

    local function beginTitanAfkVote(titanData)
        local eligible = eligibleAfkVoters()
        local vote = nil
        local duration = titanAfkVoteSeconds()
        local i = 1

        if titanAfkVote or not titanData or titanData:isLeaving() or titanData:hasLeft() then
            return
        end
        if #eligible == 0 then
            resetTitanAfk(titanData:player())
            Game.say("|cffffcc00The Titan appears inactive, but no active Defender is available to vote.|r")
            return
        end

        vote = {
            titanData = titanData,
            eligible = eligible,
            eligibleById = {},
            votes = {},
            required = R2I(I2R(#eligible) / 2.0) + 1,
            dialog = DialogCreate(),
            trigger = CreateTrigger(),
            timer = nil,
            waitButton = nil,
            removeButton = nil
        }
        titanAfkVote = vote

        DialogSetMessage(vote.dialog, "Titan is AFK. What should happen?")
        vote.waitButton = DialogAddButton(vote.dialog, "Wait for Titan", 0)
        vote.removeButton = DialogAddButton(vote.dialog, "Remove Titan", 0)
        TriggerRegisterDialogButtonEvent(vote.trigger, vote.waitButton)
        TriggerRegisterDialogButtonEvent(vote.trigger, vote.removeButton)
        TriggerAddAction(vote.trigger, function()
            local removeTitan = GetClickedButton() == vote.removeButton
            local debugApi = rawget(_G, "Debug")

            if debugApi and debugApi.try then
                debugApi.try(castTitanAfkVote, GetTriggerPlayer(), removeTitan)
            else
                castTitanAfkVote(GetTriggerPlayer(), removeTitan)
            end
        end)

        while i <= #eligible do
            vote.eligibleById[eligible[i]:id()] = true
            DialogDisplay(eligible[i]:player(), vote.dialog, true)
            i = i + 1
        end

        vote.timer = GameTimer.after(duration, function()
            if titanAfkVote == vote then
                finishTitanAfkVote(false, "timeout")
            end
        end)
        Game.say(nameColored(titanData) ..
            "|cffffcc00 appears to be inactive. Defenders have " ..
            I2S(R2I(duration)) ..
            " seconds to vote whether to wait or remove the Titan. " ..
            I2S(vote.required) .. " remove votes are required.|r")
    end

    local function recordTitanActivity(player, unit, canCancelVote)
        local playerData = player and PlayerData.get(player) or nil

        if playerData and playerData:class() == PlayerData.CLASS_TITAN and
            not playerData:isFake() and not playerData:isLeaving() and not playerData:hasLeft() then
            if unit and playerData:unit() ~= unit then
                return
            end
            if titanAfkVote and titanAfkVote.titanData == playerData then
                -- Automatic acquisition and combat orders also fire issued-order
                -- events. They must not cancel a Defender vote that is already
                -- running; only explicit chat proves that the player returned.
                if canCancelVote then
                    finishTitanAfkVote(false, "returned")
                end
            else
                resetTitanAfk(player)
            end
        end
    end

    local leaveTrigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerEvent(leaveTrigger, Player(i), EVENT_PLAYER_LEAVE)
        i = i + 1
    end

    TriggerAddAction(leaveTrigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(onLeave)
        else
            onLeave()
        end
    end)

    local activityTrigger = CreateTrigger()
    local chatTrigger = CreateTrigger()
    i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(activityTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_ORDER, nil)
        TriggerRegisterPlayerUnitEvent(activityTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER, nil)
        TriggerRegisterPlayerUnitEvent(activityTrigger, Player(i), EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, nil)
        TriggerRegisterPlayerUnitEvent(activityTrigger, Player(i), EVENT_PLAYER_UNIT_SPELL_EFFECT, nil)
        TriggerRegisterPlayerUnitEvent(activityTrigger, Player(i), EVENT_PLAYER_UNIT_USE_ITEM, nil)
        TriggerRegisterPlayerChatEvent(chatTrigger, Player(i), "", false)
        i = i + 1
    end

    TriggerAddAction(activityTrigger, function()
        recordTitanActivity(GetTriggerPlayer(), GetTriggerUnit(), false)
    end)
    TriggerAddAction(chatTrigger, function()
        recordTitanActivity(GetTriggerPlayer(), nil, true)
    end)

    GameTimer.every(1.0, function()
        local titanData = nil
        local playerId = -1
        local warningSeconds = titanAfkWarningSeconds()
        local timeoutSeconds = titanAfkTimeoutSeconds()

        if not GameSettings.getBool("TITAN_AFK_ENABLED") or not Game.isState(Game.STATE_STARTED) then
            if titanAfkVote then
                finishTitanAfkVote(false, "cancelled")
            end
            resetTitanAfk(nil)
            return
        end

        if titanAfkVote then
            return
        end

        titanData = currentTitanData()
        if not titanData or titanData:isFake() then
            resetTitanAfk(nil)
            return
        end

        playerId = titanData:id()
        if titanAfk.playerId ~= playerId then
            resetTitanAfk(titanData:player())
            return
        end

        titanAfk.idleSeconds = titanAfk.idleSeconds + 1.0
        if titanAfk.idleSeconds >= timeoutSeconds then
            beginTitanAfkVote(titanData)
        elseif not titanAfk.warned and titanAfk.idleSeconds >= math.min(warningSeconds, timeoutSeconds) then
            titanAfk.warned = true
            Game.say(nameColored(titanData) ..
                "|cffffcc00 appears to be inactive. A Defender vote begins in |r|cffffff80" ..
                I2S(R2I(math.max(0.0, timeoutSeconds - titanAfk.idleSeconds))) ..
                " seconds|r|cffffcc00 unless the Titan performs an action or writes in chat.|r")
        end
    end)

    Command["-defender"].register(function(args)
        local observerData = PlayerData.get(args:player())
        local leaverData = findLeavingDefender(targetIdFromArgs(args))

        if not observerData or not observerData:isObserver() or observerData:observeTeam() == "titan" then
            Command.say(args:player(), "|cffff6060Only Builder Observers can take over a leaving Defender.|r")
            return
        end
        if not DefenderLeave.takeOver(observerData, leaverData) then
            Command.say(args:player(), "|cffff6060No leaving Defender is available to take over.|r")
        end
    end, "Observer: takes over a leaving Defender. Optional player id.")

    Command["-builder"].register(function(args)
        Command["-defender"].run(args)
    end, "Alias for -defender.")

    Command["-titan"].register(function(args)
        local playerData = PlayerData.get(args:player())

        if not titanRecovery.active or not titanRecovery.titanData then
            Command.say(args:player(), "|cffff6060No Titan replacement is needed right now.|r")
            return
        end

        if titanRecovery.reason == "afk" and playerData == titanRecovery.titanData then
            playerData:setLeaving(false)
            clearTitanRecovery()
            resetTitanAfk(playerData:player())
            refreshAlliances()
            IslandDefenseMultiboard.refresh()
            Game.say(nameColored(playerData) .. "|cff80ff80 has returned. Game resumed.|r")
            return
        end

        if not canVolunteerAsTitan(playerData) then
            Command.say(args:player(), "|cffff6060Only Builders, Builder Observers or Minions can take over as Titan.|r")
            return
        end

        promoteToTitan(playerData, titanRecovery.titanData, true, titanRecovery.reason)
    end, "Titan: returns after AFK pause. Builder/Observer/Minion: takes over when needed.")

    _G.DefenderLeave = DefenderLeave
end)

if Debug and Debug.endFile then Debug.endFile() end
