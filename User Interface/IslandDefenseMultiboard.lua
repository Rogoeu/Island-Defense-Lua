if Debug and Debug.beginFile then Debug.beginFile("User Interface/IslandDefenseMultiboard") end

OnInit("IslandDefenseMultiboard", function(import)
    import.strict("GameTimer")
    import.strict("PlayerColorUtils")
    import.strict("PlayerData")
    import.strict("PlayerProfile")
    import.strict("GameSettings")
    import.strict("VictoryLinks")

    local builderBoard = nil
    local titanBoard = nil
    local voteBoard = nil
    local renderBoard = nil
    local phaseText = "Loading"
    local phaseRemaining = 0
    local titleTweaks = ""
    local voteState = nil
    local voteBoardEnabled = {}
    local endBoardActive = false
    local endBoardWinner = ""

    local HEADERS = { "", "Name", "Gold", "Lumber", "Fed", "Rate", "Goldfed" }
    local WIDTHS = { 0.028, 0.105, 0.045, 0.055, 0.035, 0.04, 0.055 }
    local END_HEADERS = { "", "Name", "Role", "Race", "Elo (+/-)", "Matches", "Games", "W/L", "Goldfed" }
    local END_WIDTHS = { 0.030, 0.150, 0.060, 0.105, 0.070, 0.055, 0.050, 0.060, 0.060 }

    local function twoDigits(value)
        if value < 10 then
            return "0" .. I2S(value)
        end
        return I2S(value)
    end

    local function gameTime()
        local elapsed = 0
        if rawget(_G, "Game") and Game.currentGameElapsed then
            elapsed = R2I(Game.currentGameElapsed())
        end

        local hours = R2I(elapsed / 3600)
        local minutes = R2I((elapsed - (hours * 3600)) / 60)
        local seconds = elapsed - (hours * 3600) - (minutes * 60)

        return "[" .. twoDigits(hours) .. ":" .. twoDigits(minutes) .. ":" .. twoDigits(seconds) .. "]"
    end

    local function currentTweaks()
        if titleTweaks ~= "" then
            return titleTweaks
        end
        return GameSettings.getStr("MULTIBOARD_TWEAKS")
    end

    local function titanHunterProgressTitle()
        local hunterExperience = rawget(_G, "TitanHunterExperience")
        local points = 0
        local goal = 0

        if not hunterExperience or not hunterExperience.stormTrooperPoints or not hunterExperience.stormTrooperGoal then
            return ""
        end
        if hunterExperience.superCritterEnabled and not hunterExperience.superCritterEnabled() then
            return ""
        end

        points = hunterExperience.stormTrooperPoints()
        goal = hunterExperience.stormTrooperGoal()
        if goal <= 0 then
            return ""
        end
        if points > goal then
            points = goal
        end

        return " - |cff99b4d1Critters " .. I2S(points) .. "/" .. I2S(goal) .. "|r"
    end

    local function phaseTitle()
        local tweaks = currentTweaks()
        local title = "|cffffcc00Island Defense|r"

        if tweaks ~= "" then
            title = title .. " - |cffffff80" .. tweaks .. "|r"
        end

        title = title .. titanHunterProgressTitle()

        if phaseRemaining > 0 then
            return title .. " - " .. phaseText .. " |cff99b4d1(" .. I2S(R2I(phaseRemaining)) .. "s) " .. gameTime() .. "|r"
        end
        return title .. " - " .. phaseText .. " |cff99b4d1" .. gameTime() .. "|r"
    end

    local function setItem(row, col, value, icon, width)
        local item = MultiboardGetItem(renderBoard, row, col)
        MultiboardSetItemWidth(item, width or WIDTHS[col + 1] or 0.04)
        MultiboardSetItemStyle(item, value ~= nil and value ~= "", icon ~= nil and icon ~= "")
        if value ~= nil then
            MultiboardSetItemValue(item, value)
        end
        if icon ~= nil and icon ~= "" then
            MultiboardSetItemIcon(item, icon)
        end
        MultiboardReleaseItem(item)
    end

    local function setEndItem(row, col, value, icon)
        local item = MultiboardGetItem(renderBoard, row, col)

        MultiboardSetItemWidth(item, END_WIDTHS[col + 1] or 0.050)
        MultiboardSetItemStyle(item, value ~= nil and value ~= "", icon ~= nil and icon ~= "")
        if value ~= nil then
            MultiboardSetItemValue(item, value)
        end
        if icon ~= nil and icon ~= "" then
            MultiboardSetItemIcon(item, icon)
        end
        MultiboardReleaseItem(item)
    end

    local function playerLabel(playerData)
        local fake = ""
        local observer = ""
        if playerData:isFake() then
            fake = " |cff777777(F)|r"
        end
        if playerData.isObserver and playerData:isObserver() then
            observer = " |cff90b0d0(Observer)|r"
        end
        return PlayerColorUtils.wrap(playerData:player(), playerData:displayName()) .. fake .. observer
    end

    local function raceIcon(playerData)
        local race = playerData:race()
        if race and race ~= NullRace.instance() then
            return race:icon()
        end
        return "ReplaceableTextures\\CommandButtons\\BTNCancel.blp"
    end

    local function resource(player, state)
        return I2S(GetPlayerState(player, state))
    end

    local function feedValue(playerData)
        local feedApi = rawget(_G, "PlayerDataFed")
        if feedApi and feedApi.stats then
            local fed = feedApi.stats(playerData)
            return I2S(fed)
        end
        return "0"
    end

    local function feedRate(playerData)
        local feedApi = rawget(_G, "PlayerDataFed")
        if feedApi and feedApi.stats then
            local _, _, rate = feedApi.stats(playerData)
            return I2S(R2I(rate * 100.0)) .. "%"
        end
        return "100%"
    end

    local function goldFeedValue(playerData)
        local feedApi = rawget(_G, "PlayerDataFed")
        if feedApi and feedApi.stats then
            local _, _, _, _, goldFed = feedApi.stats(playerData)
            return I2S(goldFed)
        end
        return "0"
    end

    local function fillHeader()
        local i = 1
        while i <= #HEADERS do
            setItem(0, i - 1, "|cff99b4d1" .. HEADERS[i] .. "|r", "", WIDTHS[i])
            i = i + 1
        end
    end

    local function fillEndHeader()
        local i = 1

        while i <= #END_HEADERS do
            setEndItem(0, i - 1, "|cff99b4d1" .. END_HEADERS[i] .. "|r", "")
            i = i + 1
        end
    end

    local function fillPlayerRow(row, playerData, hideRaceDetails)
        local player = playerData:player()
        local hidden = hideRaceDetails == true

        if hidden then
            setItem(row, 0, "", "ReplaceableTextures\\CommandButtons\\BTNCancel.blp", WIDTHS[1])
        else
            setItem(row, 0, "", raceIcon(playerData), WIDTHS[1])
        end
        setItem(row, 1, playerLabel(playerData), "", WIDTHS[2])
        if hidden then
            setItem(row, 2, "", "", WIDTHS[3])
            setItem(row, 3, "", "", WIDTHS[4])
        else
            setItem(row, 2, resource(player, PLAYER_STATE_RESOURCE_GOLD), "", WIDTHS[3])
            setItem(row, 3, resource(player, PLAYER_STATE_RESOURCE_LUMBER), "", WIDTHS[4])
        end
        setItem(row, 4, feedValue(playerData), "", WIDTHS[5])
        setItem(row, 5, feedRate(playerData), "", WIDTHS[6])
        setItem(row, 6, goldFeedValue(playerData), "", WIDTHS[7])
    end

    local function fillSectionRow(row, label)
        setItem(row, 0, "", "", WIDTHS[1])
        setItem(row, 1, "|cffffcc00" .. label .. "|r", "", WIDTHS[2])
        setItem(row, 2, "", "", WIDTHS[3])
        setItem(row, 3, "", "", WIDTHS[4])
        setItem(row, 4, "", "", WIDTHS[5])
        setItem(row, 5, "", "", WIDTHS[6])
        setItem(row, 6, "", "", WIDTHS[7])
    end

    local function splitByTeam()
        if not GameSettings.exists("MULTIBOARD_SPLIT_BY_TEAM") then
            return false
        end
        return GameSettings.getBool("MULTIBOARD_SPLIT_BY_TEAM")
    end

    local function ensureBoard(kind, rowCount)
        if kind == "titan" then
            if not titanBoard then
                titanBoard = CreateMultiboard()
                MultiboardSetColumnCount(titanBoard, #HEADERS)
            end
            renderBoard = titanBoard
        else
            if not builderBoard then
                builderBoard = CreateMultiboard()
                MultiboardSetColumnCount(builderBoard, #HEADERS)
            end
            renderBoard = builderBoard
        end

        MultiboardSetRowCount(renderBoard, rowCount)
        MultiboardSetColumnCount(renderBoard, #HEADERS)
        MultiboardSetTitleText(renderBoard, phaseTitle())
    end

    local function ensureEndBoard(kind, rowCount)
        if kind == "titan" then
            if not titanBoard then
                titanBoard = CreateMultiboard()
            end
            renderBoard = titanBoard
        else
            if not builderBoard then
                builderBoard = CreateMultiboard()
            end
            renderBoard = builderBoard
        end

        MultiboardSetRowCount(renderBoard, rowCount)
        MultiboardSetColumnCount(renderBoard, #END_HEADERS)
        MultiboardMinimize(renderBoard, false)
        MultiboardSetTitleText(renderBoard, "|cffffcc00Island Defense Results|r - " ..
            (endBoardWinner == "titan" and "|cffff6060Titan victory|r " or "|cff80ff80Defender victory|r ") ..
            "|cff99b4d1" .. gameTime() .. "|r")
    end

    local function isTitanSide(playerData)
        if playerData.isObserver and playerData:isObserver() then
            return playerData:observeTeam() == "titan"
        end
        return playerData:class() == PlayerData.CLASS_TITAN or playerData:class() == PlayerData.CLASS_MINION
    end

    local function setBoardVisibleForPlayer(whichBoard, player, show)
        if whichBoard and GetLocalPlayer() == player then
            MultiboardDisplay(whichBoard, show)
        end
    end

    local function voteRemaining()
        local elapsed = 0.0

        if not voteState then
            return 0
        end
        if rawget(_G, "Game") and Game.currentGameElapsed then
            elapsed = Game.currentGameElapsed()
        end
        return math.max(0, R2I(voteState.expiresAt - elapsed + 0.999))
    end

    local function renderVoteBoard()
        local voters = {}
        local playerId = nil
        local row = 0
        local i = 1

        if not voteState then
            return
        end

        for playerId in pairs(voteState.voters) do
            local playerData = PlayerData.get(Player(playerId))
            if playerData then
                voters[#voters + 1] = playerData
            end
        end

        if not voteBoard then
            voteBoard = CreateMultiboard()
        end
        MultiboardSetColumnCount(voteBoard, 2)
        MultiboardSetRowCount(voteBoard, #voters + 3)
        MultiboardSetTitleText(voteBoard, "Vote for: " .. voteState.title)

        local function setVoteItem(targetRow, column, value, icon, width)
            local item = MultiboardGetItem(voteBoard, targetRow, column)

            MultiboardSetItemWidth(item, width)
            MultiboardSetItemStyle(item, value ~= nil and value ~= "", icon ~= nil and icon ~= "")
            if value ~= nil then
                MultiboardSetItemValue(item, value)
            end
            if icon ~= nil and icon ~= "" then
                MultiboardSetItemIcon(item, icon)
            end
            MultiboardReleaseItem(item)
        end

        setVoteItem(row, 0, "|cff99b4d1Voters|r", "", 0.140)
        setVoteItem(row, 1, "", "ReplaceableTextures\\CommandButtons\\BTNSelectHeroOn.blp", 0.030)
        row = row + 1

        while i <= #voters do
            setVoteItem(row, 0, PlayerColorUtils.wrap(voters[i]:player(), voters[i]:displayName()), "", 0.140)
            setVoteItem(row, 1, "|cff80ff80YES|r", "", 0.030)
            row = row + 1
            i = i + 1
        end

        setVoteItem(row, 0, "", "", 0.010)
        setVoteItem(row, 1, "", "", 0.030)
        row = row + 1
        setVoteItem(row, 0, "|cff99b4d1Expires in:|r", "", 0.140)
        setVoteItem(row, 1, "|cffffff80" .. I2S(voteRemaining()) .. "|r", "", 0.030)
    end

    local function displayBoards(show)
        local split = splitByTeam()
        local i = 0

        local list = PlayerData.allReal()
        while i < list:size() do
            local playerData = list:at(i)
            local player = playerData:player()
            local titanSide = (endBoardActive or split) and titanBoard and isTitanSide(playerData)
            local showVote = voteState and voteBoardEnabled[playerData:id()] ~= false

            if show then
                if endBoardActive then
                    setBoardVisibleForPlayer(voteBoard, player, false)
                    if titanSide then
                        setBoardVisibleForPlayer(builderBoard, player, false)
                        setBoardVisibleForPlayer(titanBoard, player, true)
                    else
                        setBoardVisibleForPlayer(titanBoard, player, false)
                        setBoardVisibleForPlayer(builderBoard, player, true)
                    end
                elseif showVote then
                    setBoardVisibleForPlayer(builderBoard, player, false)
                    setBoardVisibleForPlayer(titanBoard, player, false)
                    setBoardVisibleForPlayer(voteBoard, player, true)
                elseif titanSide then
                    setBoardVisibleForPlayer(voteBoard, player, false)
                    setBoardVisibleForPlayer(builderBoard, player, false)
                    setBoardVisibleForPlayer(titanBoard, player, true)
                else
                    setBoardVisibleForPlayer(voteBoard, player, false)
                    setBoardVisibleForPlayer(titanBoard, player, false)
                    setBoardVisibleForPlayer(builderBoard, player, true)
                end
            else
                setBoardVisibleForPlayer(titanBoard, player, false)
                setBoardVisibleForPlayer(builderBoard, player, false)
                setBoardVisibleForPlayer(voteBoard, player, false)
            end

            i = i + 1
        end

        list:destroy()
    end

    local IslandDefenseMultiboard = {}

    local function scoreboardPlayers()
        if PlayerData.allWithFakeAndLeft then
            return PlayerData.allWithFakeAndLeft()
        end
        return PlayerData.allWithFake()
    end

    local function raceName(playerData)
        local race = playerData:race()

        if race and race ~= NullRace.instance() then
            return race:toString()
        end
        return "-"
    end

    local function roleName(playerData)
        if playerData:isObserver() then
            if playerData:observeTeam() == "titan" then
                return "Titan Obs"
            end
            return "Observer"
        end
        return PlayerData.classToString(playerData:class())
    end

    local function endRoleFor(playerData)
        if playerData.initialClass then
            return playerData:initialClass()
        end
        return playerData:class()
    end

    local function endElo(profile, role, playerData)
        local rating = profile.rating
        local delta = PlayerProfile.matchEloDelta(playerData, role)
        local value = nil

        if role == PlayerData.CLASS_TITAN then
            value = I2S(R2I(rating.titanElo or 0))
            if delta ~= nil then
                value = value .. " (" .. (delta > 0 and "+" or "") .. I2S(delta) .. ")"
            end
            return value, I2S(rating.titanMatches or 0)
        elseif role == PlayerData.CLASS_DEFENDER then
            value = I2S(R2I(rating.builderElo or 0))
            if delta ~= nil then
                value = value .. " (" .. (delta > 0 and "+" or "") .. I2S(delta) .. ")"
            end
            return value, I2S(rating.builderMatches or 0)
        end
        return "-", "-"
    end

    local function endGames(profile, role)
        local stats = profile.stats
        local games = 0
        local wins = 0

        if role == PlayerData.CLASS_TITAN then
            games = stats.titan or 0
            wins = stats.winsTitan or 0
        elseif role == PlayerData.CLASS_DEFENDER then
            games = stats.builder or 0
            wins = stats.winsBuilder or 0
        else
            return "-", "-"
        end

        local losses = math.max(0, games - wins)

        return I2S(games), I2S(wins) .. "/" .. I2S(losses)
    end

    local function renderEnd(kind)
        local list = scoreboardPlayers()
        local row = 1
        local i = 0

        ensureEndBoard(kind, list:size() + 1)
        fillEndHeader()

        while i < list:size() do
            local playerData = list:at(i)
            local profile = PlayerProfile.get(playerData)
            local endRole = endRoleFor(playerData)
            local elo, matches = endElo(profile, endRole, playerData)
            local games, winLoss = endGames(profile, endRole)
            local icon = raceIcon(playerData)

            setEndItem(row, 0, "", icon)
            setEndItem(row, 1, playerLabel(playerData), "")
            setEndItem(row, 2, "|cffd8e6ff" .. roleName(playerData) .. "|r", "")
            setEndItem(row, 3, "|cffffffff" .. raceName(playerData) .. "|r", "")
            setEndItem(row, 4, "|cffffff80" .. elo .. "|r", "")
            setEndItem(row, 5, matches, "")
            setEndItem(row, 6, games, "")
            setEndItem(row, 7, winLoss, "")
            setEndItem(row, 8, goldFeedValue(playerData), "")
            row = row + 1
            i = i + 1
        end

        list:destroy()
    end

    local function render(kind)
        local list = scoreboardPlayers()
        local defenders = {}
        local titans = {}
        local minions = {}
        local observers = {}
        local others = {}
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            if playerData.isObserver and playerData:isObserver() and playerData:observeTeam() ~= "titan" then
                observers[#observers + 1] = playerData
            elseif playerData:class() == PlayerData.CLASS_DEFENDER then
                defenders[#defenders + 1] = playerData
            elseif playerData:class() == PlayerData.CLASS_TITAN then
                titans[#titans + 1] = playerData
            elseif playerData:class() == PlayerData.CLASS_MINION then
                minions[#minions + 1] = playerData
            elseif playerData:class() == PlayerData.CLASS_OBSERVER then
                observers[#observers + 1] = playerData
            else
                others[#others + 1] = playerData
            end
            i = i + 1
        end

        local sectionCount = 0
        if #defenders > 0 then sectionCount = sectionCount + 1 end
        if #titans > 0 then sectionCount = sectionCount + 1 end
        if #minions > 0 then sectionCount = sectionCount + 1 end
        if #observers > 0 then sectionCount = sectionCount + 1 end
        if #others > 0 then sectionCount = sectionCount + 1 end

        ensureBoard(kind, list:size() + 1 + sectionCount)
        fillHeader()

        local row = 1
        local function writeSection(label, players)
            local j = 1
            if #players == 0 then
                return
            end

            fillSectionRow(row, label)
            row = row + 1

            while j <= #players do
                local playerData = players[j]
                local hideRaceDetails =
                    (kind == "builder" and playerData:class() == PlayerData.CLASS_TITAN) or
                    (kind == "titan" and playerData:class() == PlayerData.CLASS_DEFENDER)

                fillPlayerRow(row, playerData, hideRaceDetails)
                row = row + 1
                j = j + 1
            end
        end

        writeSection("Defenders", defenders)
        writeSection("Titan", titans)
        writeSection("Minions", minions)
        writeSection("Observers", observers)
        writeSection("Unassigned", others)

        list:destroy()
    end

    function IslandDefenseMultiboard.refresh()
        renderVoteBoard()
        if endBoardActive then
            renderEnd("builder")
            renderEnd("titan")
        else
            render("builder")
            if splitByTeam() then
                render("titan")
            end
        end
        displayBoards(true)
    end

    function IslandDefenseMultiboard.showEndBoard(winner)
        VictoryLinks.show()
        endBoardActive = true
        endBoardWinner = winner or ""
        renderEnd("builder")
        renderEnd("titan")
        displayBoards(true)
    end

    function IslandDefenseMultiboard.clearEndBoard()
        VictoryLinks.hide()
        endBoardActive = false
        endBoardWinner = ""
        render("builder")
        if splitByTeam() then
            render("titan")
        end
        displayBoards(true)
    end

    function IslandDefenseMultiboard.beginVote(title, voters, duration)
        local elapsed = 0.0

        if rawget(_G, "Game") and Game.currentGameElapsed then
            elapsed = Game.currentGameElapsed()
        end
        voteState = {
            title = title or "Vote",
            voters = voters or {},
            expiresAt = elapsed + (duration or 30.0)
        }
        if rawget(_G, "gg_snd_Ready") then
            PlaySoundBJ(gg_snd_Ready)
        end
        IslandDefenseMultiboard.refresh()
    end

    function IslandDefenseMultiboard.updateVote(voters)
        if voteState then
            voteState.voters = voters or voteState.voters
            IslandDefenseMultiboard.refresh()
        end
    end

    function IslandDefenseMultiboard.endVote()
        if voteState then
            voteState = nil
            IslandDefenseMultiboard.refresh()
        end
    end

    function IslandDefenseMultiboard.setVotingBoardEnabled(player, enabled)
        if not player then
            return
        end

        voteBoardEnabled[GetPlayerId(player)] = enabled == true
        IslandDefenseMultiboard.refresh()
    end

    function IslandDefenseMultiboard.isVotingBoardEnabled(player)
        return player and voteBoardEnabled[GetPlayerId(player)] ~= false
    end

    function IslandDefenseMultiboard.isVoteActive()
        return voteState ~= nil
    end

    function IslandDefenseMultiboard.show()
        IslandDefenseMultiboard.refresh()
    end

    function IslandDefenseMultiboard.hide()
        displayBoards(false)
    end

    function IslandDefenseMultiboard.setPhase(text, seconds)
        if endBoardActive and rawget(_G, "Game") and not Game.isState(Game.STATE_FINISHED) then
            VictoryLinks.hide()
            endBoardActive = false
            endBoardWinner = ""
        end
        phaseText = text or phaseText
        phaseRemaining = seconds or 0
        IslandDefenseMultiboard.show()
    end

    function IslandDefenseMultiboard.setTweaks(text)
        titleTweaks = text or ""
        if builderBoard then
            MultiboardSetTitleText(builderBoard, phaseTitle())
        end
        if titanBoard then
            MultiboardSetTitleText(titanBoard, phaseTitle())
        end
    end

    function IslandDefenseMultiboard.addTweak(text)
        if not text or text == "" then
            return
        end
        if currentTweaks() == "" then
            IslandDefenseMultiboard.setTweaks(text)
        else
            IslandDefenseMultiboard.setTweaks(currentTweaks() .. "/" .. text)
        end
    end

    function IslandDefenseMultiboard.phase()
        return phaseText
    end

    function IslandDefenseMultiboard.splitByTeam()
        return splitByTeam()
    end

    function IslandDefenseMultiboard.setSplitByTeam(value)
        GameSettings.setBool("MULTIBOARD_SPLIT_BY_TEAM", value == true)
        if value ~= true and titanBoard then
            MultiboardDisplay(titanBoard, false)
            DestroyMultiboard(titanBoard)
            titanBoard = nil
        end
        IslandDefenseMultiboard.refresh()
    end

    GameTimer.every(1.0, function()
        if phaseRemaining > 0 then
            phaseRemaining = phaseRemaining - 1
            if phaseRemaining < 0 then
                phaseRemaining = 0
            end
        end
        if builderBoard or titanBoard then
            IslandDefenseMultiboard.refresh()
        end
    end)

    if rawget(_G, "Game") and Game.onFinish then
        Game.onFinish(function(winner)
            -- PlayerProfile also updates on Game.finish. Delay one tick so the
            -- result board can display the post-match Elo values.
            GameTimer.after(0.05, function()
                IslandDefenseMultiboard.showEndBoard(winner)
            end)
        end)
    end

    _G.IslandDefenseMultiboard = IslandDefenseMultiboard
end)

if Debug and Debug.endFile then Debug.endFile() end
