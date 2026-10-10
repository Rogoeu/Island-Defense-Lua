if Debug and Debug.beginFile then Debug.beginFile("Island Defense System/AutoStart") end

OnInit.final("IslandDefenseAutoStart", function(import)
    import.strict("IslandDefenseGameMode")
    import.strict("UnitSpawner")
    import.strict("GameTimer")
    import.strict("IslandDefenseMultiboard")
    import.strict("PickModeSelectionUI")
    import.strict("RacePickSystem")
    import.strict("RacePickModeAllPick")
    import.strict("RacePickModeUniquePick")
    import.strict("RacePickModeAllRandom")
    import.strict("DefenderLeave")
    import.strict("DebugCheatPack")
    import.strict("ObserverCommand")
    import.strict("TeamAlliances")
    import.strict("PlayerProfile")

    local DEFAULT_PICK_SECONDS = 20.0
    local DEFAULT_MODE_SELECTION_SECONDS = 10.0
    local SAVE_BUTTON_NAMES = {
        "EscMenuSaveGameButton",
        "SaveGameButton"
    }
    local volunteers = {}
    local dialogs = {}
    local yesButtons = {}
    local noButtons = {}
    local buttonPlayerIds = {}
    local buttonTriggers = {}
    local closed = false
    local observerBuilderViewForced = false
    local observerViewSelected = {}
    local selectedPickMode = "UP"
    local startHostModeSelection
    local startTitanSelection
    local registerButton

    local function say(text)
        Game.say(text)
    end

    local function disableGameSaving()
        local retryTimer = nil
        local attempts = 0

        if not GameSettings.getBool("DISABLE_GAME_SAVING") or
            not rawget(_G, "BlzGetFrameByName") or
            not rawget(_G, "BlzFrameSetEnable") or
            not rawget(_G, "BlzFrameSetVisible") then
            return
        end

        retryTimer = GameTimer.every(0.25, function()
            local found = false
            local i = 1

            attempts = attempts + 1
            while i <= #SAVE_BUTTON_NAMES do
                local frame = BlzGetFrameByName(SAVE_BUTTON_NAMES[i], 0)
                if frame then
                    BlzFrameSetEnable(frame, false)
                    BlzFrameSetVisible(frame, false)
                    if rawget(_G, "BlzFrameSetFocus") then
                        BlzFrameSetFocus(frame, false)
                    end
                    found = true
                end
                i = i + 1
            end

            if found or attempts >= 40 then
                retryTimer:destroy()
            end
        end)
    end

    local function settingSeconds(key, defaultValue)
        local seconds = GameSettings.getReal(key)
        if seconds <= 0 then
            return defaultValue
        end
        return seconds
    end

    local function titanSelectionSeconds()
        return settingSeconds("TITAN_SELECTION_TIME", DEFAULT_PICK_SECONDS)
    end

    local function modeSelectionSeconds()
        return settingSeconds("PICK_MODE_SELECTION_TIME", DEFAULT_MODE_SELECTION_SECONDS)
    end

    local function fakeTargetPlayers()
        local count = GameSettings.getInt("SOLO_FAKE_TARGET_PLAYERS")
        if count <= 0 then
            return 11
        end
        return count
    end

    local function playerName(playerData)
        if playerData then
            return playerData:displayName()
        end
        return "Unknown"
    end

    local function chooseRandom(list)
        if #list == 0 then
            return nil
        end
        return list[GetRandomInt(1, #list)]
    end

    local function collectPlayers()
        Game.loadPlayers()
        PlayerData.ensureFakePlayersWhenAlone(fakeTargetPlayers())
        Game.applyPlayerDefaults()
        local list = PlayerData.playingReal()
        local fakes = PlayerData.allWithFake()
        local players = {}
        local i = 0
        while i < list:size() do
            players[#players + 1] = list:at(i)
            i = i + 1
        end
        if list:size() == 1 and PlayerData.countFake() > 0 then
            i = 0
            while i < fakes:size() do
                if fakes:at(i):isFake() then
                    players[#players + 1] = fakes:at(i)
                end
                i = i + 1
            end
        end
        list:destroy()
        fakes:destroy()
        return players
    end

    local function hideDialogs()
        local list = PlayerData.playingReal()
        local i = 1
        while i <= list:size() do
            local playerData = list:at(i - 1)
            local id = playerData:id()
            if dialogs[id] then
                DialogDisplay(playerData:player(), dialogs[id], false)
                DialogClear(dialogs[id])
            end
            i = i + 1
        end
        list:destroy()
    end

    local showObserverDialog

    local function assignPlayers(titanPlayerData)
        local players = collectPlayers()
        local observers = PlayerData.observers()
        local i = 1

        Game.clearPlayerClasses()
        Game.setMode(IslandDefenseGameMode)

        while i <= #players do
            local playerData = players[i]
            if playerData == titanPlayerData then
                playerData:setObserver(false)
                playerData:setClass(PlayerData.CLASS_TITAN)
            else
                playerData:setObserver(false)
                playerData:setClass(PlayerData.CLASS_DEFENDER)
            end
            playerData:setRace(NullRace.instance())
            i = i + 1
        end

        i = 0
        while i < observers:size() do
            local playerData = observers:at(i)
            observerViewSelected[playerData:id()] = false
            ObserverCommand.applyObserverView(playerData, "builder")
            showObserverDialog(playerData)
            i = i + 1
        end
        observers:destroy()
        ObserverCommand.refreshObserverViews()
    end

    local function configureTeams()
        TeamAlliances.refresh()
    end

    local function titanMinimumGames()
        return math.max(0, GameSettings.getInt("TITAN_SELECTION_MIN_GAMES"))
    end

    local function playedGames(playerData)
        local stats = PlayerProfile.stats(playerData)
        return (stats.builder or 0) + (stats.titan or 0)
    end

    local function canVolunteer(playerData)
        return playerData and not playerData:isFake() and not playerData:isLeaving() and
            not playerData:hasLeft() and playedGames(playerData) >= titanMinimumGames()
    end

    local function finishSelection()
        if closed then
            return
        end
        closed = true
        PickModeSelectionUI.endTitanSelection()
        hideDialogs()

        local players = collectPlayers()
        local candidates = {}
        local eligible = {}
        local i = 1

        while i <= #players do
            if canVolunteer(players[i]) then
                eligible[#eligible + 1] = players[i]
                if volunteers[players[i]:id()] then
                    candidates[#candidates + 1] = players[i]
                end
            end
            i = i + 1
        end

        local titan = chooseRandom(candidates)
        if not titan then
            titan = chooseRandom(eligible)
            if not titan then
                titan = chooseRandom(players)
                if titan then
                    say("|cffffff80No player meets the Titan experience requirement. Selecting a random Titan so the game can start.|r")
                end
            end
            if titan then
                say("|cff99b4d1No titan volunteer found. Random titan selected.|r")
            end
        elseif #candidates > 1 then
            say("|cff99b4d1Multiple titan volunteers found. Random volunteer selected.|r")
        end

        if not titan then
            say("|cffff6060Lua autostart failed: no active players.|r")
            return
        end

        assignPlayers(titan)
        configureTeams(titan)
        say("|cffff6060" .. playerName(titan) .. "|r |cff99b4d1will play Titan.|r")
        if PlayerData.countFake() > 0 then
            say("|cff99b4d1Solo lobby detected: added " .. I2S(PlayerData.countFake()) .. " fake players for testing.|r")
        end

        GameTimer.after(1.0, function()
            DebugCheatPack.activateDebugLobby()
            RacePickSystem.start(selectedPickMode)
        end)
    end

    startHostModeSelection = function()
        PickModeSelectionUI.start(modeSelectionSeconds(), function(settings)
            local mode = settings.pickMode or "UP"
            say("|cff99b4d1Pick mode selected: |r|cffffff80" .. mode .. "|r")
            selectedPickMode = mode
            startTitanSelection()
        end)
    end

    local function setVolunteer(playerId, value)
        if closed then
            return
        end

        if value == true and not canVolunteer(PlayerData.get(Player(playerId))) then
            DisplayTimedTextToPlayer(Player(playerId), 0, 0, 8,
                "|cffffcc00You need " .. I2S(titanMinimumGames()) .. " games to volunteer for Titan.|r")
            return
        end

        local wasVolunteer = volunteers[playerId] == true
        volunteers[playerId] = value == true
        if volunteers[playerId] then
            if not wasVolunteer then
                say("|cffffff80" .. playerName(PlayerData.get(Player(playerId))) ..
                    "|r |cff80ff80volunteered for Titan.|r")
            end
        else
            DisplayTimedTextToPlayer(Player(playerId), 0, 0, 8, "|cff99b4d1You will not volunteer for Titan.|r")
        end

        if dialogs[playerId] then
            DialogDisplay(Player(playerId), dialogs[playerId], false)
        end
    end

    registerButton = function(button, callback)
        local trigger = CreateTrigger()
        buttonTriggers[#buttonTriggers + 1] = trigger
        TriggerRegisterDialogButtonEvent(trigger, button)
        TriggerAddAction(trigger, function()
            local debugApi = rawget(_G, "Debug")
            if debugApi and debugApi.try then
                debugApi.try(callback)
            else
                callback()
            end
        end)
    end

    local function showDialog(playerData)
        local id = playerData:id()
        local dialog = DialogCreate()

        local eligible = canVolunteer(playerData)
        local message = PickModeSelectionUI.selectionSummary() .. "\n\n"
        if eligible then
            message = message .. "Do you want to play Titan?"
        else
            message = message .. "Titan requires " .. I2S(titanMinimumGames()) .. " games (you have " ..
                I2S(playedGames(playerData)) .. ").\nPlay as Defender to learn the game.\n" ..
                "If nobody qualifies, a random Titan is chosen."
        end
        DialogSetMessage(dialog, message)
        if eligible then
            yesButtons[id] = DialogAddButton(dialog, "Yes, Titan", 0)
            buttonPlayerIds[yesButtons[id]] = id
            registerButton(yesButtons[id], function()
                setVolunteer(id, true)
            end)
        end
        noButtons[id] = DialogAddButton(dialog, "No, Defender", 0)
        buttonPlayerIds[noButtons[id]] = id
        dialogs[id] = dialog

        registerButton(noButtons[id], function()
            setVolunteer(id, false)
        end)

        DialogDisplay(playerData:player(), dialog, true)
    end

    showObserverDialog = function(playerData)
        local id = playerData:id()
        local dialog = DialogCreate()
        local builderButton = nil
        local titanButton = nil

        DialogSetMessage(dialog, PickModeSelectionUI.selectionSummary() .. "\n\nObserver View")
        builderButton = DialogAddButton(dialog, "Observe Builders", 0)
        titanButton = DialogAddButton(dialog, "Observe Titan", 0)

        registerButton(builderButton, function()
            if observerBuilderViewForced then
                ObserverCommand.applyObserverView(playerData, "builder")
                DialogDisplay(playerData:player(), dialog, false)
                DialogClear(dialog)
                dialogs[id] = nil
                return
            end
            observerViewSelected[id] = true
            ObserverCommand.applyObserverView(playerData, "builder")
            DialogDisplay(playerData:player(), dialog, false)
            DialogClear(dialog)
            dialogs[id] = nil
            playerData:say("|cff80ff80Observing Builder team.|r")
            IslandDefenseMultiboard.refresh()
        end)

        registerButton(titanButton, function()
            if observerBuilderViewForced then
                ObserverCommand.applyObserverView(playerData, "builder")
                DialogDisplay(playerData:player(), dialog, false)
                DialogClear(dialog)
                dialogs[id] = nil
                return
            end
            observerViewSelected[id] = true
            ObserverCommand.applyObserverView(playerData, "titan")
            DialogDisplay(playerData:player(), dialog, false)
            DialogClear(dialog)
            dialogs[id] = nil
            playerData:say("|cff80ff80Observing Titan team.|r")
            IslandDefenseMultiboard.refresh()
        end)

        dialogs[id] = dialog
        DialogDisplay(playerData:player(), dialog, true)
    end

    local function forceObserversToBuilderView()
        local observers = nil
        local i = 0

        if observerBuilderViewForced then
            return
        end
        observerBuilderViewForced = true
        observers = PlayerData.observers()

        while i < observers:size() do
            local playerData = observers:at(i)
            local id = playerData:id()
            local dialog = dialogs[id]

            if not observerViewSelected[id] then
                observerViewSelected[id] = true
                ObserverCommand.applyObserverView(playerData, "builder")
                if dialog then
                    DialogDisplay(playerData:player(), dialog, false)
                    DialogClear(dialog)
                    dialogs[id] = nil
                end
                playerData:say("|cff80ff80Builder spawning started. You are now observing the Builder team.|r")
            end
            i = i + 1
        end

        observers:destroy()
        IslandDefenseMultiboard.refresh()
    end

    RacePickSystem.onBuilderSpawn(forceObserversToBuilderView)

    if rawget(_G, "Command") then
        local function requireDebug(player)
            if DebugCheatPack.isEnabled(player) then
                return true
            end
            Command.say(player, "|cffff6060This command is only available in debug lobbies.|r")
            return false
        end

        Command["-mb"].register(function(args)
            local playerData = PlayerData.get(args:player())
            if not requireDebug(args:player()) then
                return
            end
            IslandDefenseMultiboard.show()
            Command.say(args:player(), "|cff80ff80Multiboard refreshed.|r")
            if playerData then
                Command.say(args:player(), "|cff99b4d1MB debug: class=" .. PlayerData.classToString(playerData:class()) ..
                    " real=" .. I2S(PlayerData.countReal()) ..
                    " all=" .. I2S(PlayerData.count()) ..
                    " fake=" .. I2S(PlayerData.countFake()) ..
                    " split=" .. (IslandDefenseMultiboard.splitByTeam() and "on" or "off") .. "|r")
            else
                Command.say(args:player(), "|cffff6060MB debug: no PlayerData for this player.|r")
            end
        end, "Debug: refreshes and shows the Island Defense multiboard.")

        Command["-mbsplit"].register(function(args)
            local value = StringCase(args:at(0), false)
            if not requireDebug(args:player()) then
                return
            end

            if value == "on" then
                IslandDefenseMultiboard.setSplitByTeam(true)
            elseif value == "off" then
                IslandDefenseMultiboard.setSplitByTeam(false)
            else
                Command.say(args:player(), "|cff99b4d1Usage: -mbsplit on | off|r")
            end

            if IslandDefenseMultiboard.splitByTeam() then
                Command.say(args:player(), "|cff80ff80Multiboard team split enabled.|r")
            else
                Command.say(args:player(), "|cffff6060Multiboard team split disabled.|r")
            end
        end, "Debug: toggles separate builder/titan multiboards.")

        Command["-startlevels"].register(function(args)
            if not requireDebug(args:player()) then
                return
            end
            Command.say(args:player(), "|cff99b4d1Titan start level: |r|cffffff80" .. I2S(UnitSpawner.titanStartingLevel()) .. "|r")
            Command.say(args:player(), "|cff99b4d1Minion start level now: |r|cffffff80" .. I2S(UnitSpawner.minionStartingLevel()) .. "|r")
        end, "Debug: shows current Titan and Minion starting levels.")

    end

    startTitanSelection = function()
        if not PlayerProfile.areProfilesSynchronized() then
            say("|cff99b4d1Waiting for player profiles before Titan selection.|r")
            GameTimer.every(0.25, function(timer)
                if PlayerProfile.areProfilesSynchronized() then
                    timer:destroy()
                    startTitanSelection()
                end
            end)
            return
        end
        closed = false
        volunteers = {}
        observerBuilderViewForced = false

        Game.setMode(IslandDefenseGameMode)
        UnitSpawner.spawnPickShops()
        UnitSpawner.populatePickShops()
        UnitSpawner.spawnSpellWell()
        UnitSpawner.spawnShops()
        IslandDefenseMultiboard.setPhase("Titan selection", titanSelectionSeconds())
        say("|cff99b4d1Titan selection started. Choose within " .. I2S(R2I(titanSelectionSeconds())) .. " seconds.|r")

        local embedded = PickModeSelectionUI.startTitanSelection(titanSelectionSeconds(), {
            canVolunteer = canVolunteer,
            playedGames = playedGames,
            minimum = titanMinimumGames(),
            onChoice = setVolunteer
        })
        if not embedded then
            local list = PlayerData.playingReal()
            local i = 0
            while i < list:size() do
                showDialog(list:at(i))
                i = i + 1
            end
            list:destroy()
        end

        GameTimer.after(titanSelectionSeconds(), finishSelection)
    end

    local function startSelection()
        if GameSettings.getBool("LUA_AUTOSTART_DISABLED") then
            return
        end

        Game.initialize()
        PlayerData.ensureFakePlayersWhenAlone(fakeTargetPlayers())
        Game.applyPlayerDefaults()
        startHostModeSelection()
    end

    disableGameSaving()
    GameTimer.after(1.0, startSelection)
end)

if Debug and Debug.endFile then Debug.endFile() end
