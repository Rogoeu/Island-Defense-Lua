if Debug and Debug.beginFile then Debug.beginFile("Island Defense System/Game") end

OnInit("IslandDefenseSystem", function(import)
    import.strict("PlayerData")
    import.strict("RaceData")
    import.strict("GameSettings")
    import.strict("DefaultGameSettings")

    local modes = {}
    local modeIndex = {}
    local ignorePlayers = {}
    local currentMode = nil
    local state = 0
    local oldState = 0
    local gameId = 0
    local gameClock = nil
    local finishHandlers = {}

    local Game = {
        STATE_IDLE = 0,
        STATE_STARTING = 1,
        STATE_STARTED = 2,
        STATE_PAUSED = 3,
        STATE_FINISHED = 4,
        ignorePlayers = ignorePlayers
    }

    function Game.register(mode)
        modes[#modes + 1] = mode
        modeIndex[StringCase(mode:shortName(), false)] = mode
        modeIndex[StringCase(mode:name(), false)] = mode
        if not currentMode then
            currentMode = mode
        end
    end

    function Game.onFinish(callback)
        finishHandlers[#finishHandlers + 1] = callback
    end

    function Game.mode()
        return currentMode
    end

    function Game.setMode(mode)
        currentMode = mode
    end

    function Game.getMode(name)
        return modeIndex[StringCase(tostring(name or ""), false)]
    end

    function Game.isMode(name)
        return currentMode ~= nil and StringCase(currentMode:shortName(), false) == StringCase(tostring(name or ""), false)
    end

    function Game.id()
        return gameId
    end

    function Game.currentGameElapsed()
        if gameClock then
            return TimerGetElapsed(gameClock)
        end
        return 0.0
    end

    function Game.state()
        return state
    end

    function Game.isState(value)
        return state == value
    end

    function Game.setState(value)
        state = value
    end

    function Game.pausedState()
        return oldState
    end

    function Game.stateString(value)
        if value == Game.STATE_IDLE then
            return "STATE_IDLE"
        elseif value == Game.STATE_STARTING then
            return "STATE_STARTING"
        elseif value == Game.STATE_STARTED then
            return "STATE_STARTED"
        elseif value == Game.STATE_PAUSED then
            return "STATE_PAUSED"
        elseif value == Game.STATE_FINISHED then
            return "STATE_FINISHED"
        end
        return "STATE_UNKNOWN"
    end

    function Game.say(text)
        DisplayTimedTextToPlayer(GetLocalPlayer(), 0, 0, 15, text)
    end

    function Game.error(text)
        Game.say(text)
    end

    function Game.sayClass(classValue, text)
        local playerData = PlayerData.get(GetLocalPlayer())
        if playerData and playerData:class() == classValue then
            Game.say(text)
        end
    end

    function Game.applyPlayerDefaults()
        local foodCap = GameSettings.getInt("MAX_FOOD_SUPPLY")
        local list = PlayerData.allWithFake()
        local i = 0

        if foodCap <= 0 then
            foodCap = 150
        end

        while i < list:size() do
            local player = list:at(i):player()
            SetPlayerState(player, PLAYER_STATE_FOOD_CAP_CEILING, foodCap)
            i = i + 1
        end

        list:destroy()
    end

    function Game.revealMapForPlayers()
        if not GameSettings.getBool("REVEAL_MAP_ON_START") then
            return
        end

        local bounds = GetWorldBounds()
        local list = PlayerData.allWithFake()
        local modifiers = {}
        local i = 0
        local duration = GameSettings.getReal("REVEAL_MAP_ON_START_SECONDS")

        if duration <= 0.0 then
            duration = 1.0
        end

        while i < list:size() do
            local modifier = CreateFogModifierRect(list:at(i):player(), FOG_OF_WAR_VISIBLE, bounds, true, false)
            FogModifierStart(modifier)
            modifiers[#modifiers + 1] = modifier
            i = i + 1
        end

        list:destroy()

        local timer = CreateTimer()
        TimerStart(timer, duration, false, function()
            local j = 1
            while j <= #modifiers do
                FogModifierStop(modifiers[j])
                DestroyFogModifier(modifiers[j])
                j = j + 1
            end
            DestroyTimer(timer)
        end)
    end

    function Game.clearPlayerClasses()
        local list = PlayerData.all()
        local i = 0
        while i < list:size() do
            local playerData = list:at(i)
            playerData:resetClass()
            playerData:setRace(NullRace.instance())
            i = i + 1
        end
        list:destroy()
    end

    function Game.loadPlayers()
        local maxPlayers = GameSettings.getInt("MAX_PLAYERS")
        if maxPlayers <= 0 then
            maxPlayers = bj_MAX_PLAYER_SLOTS
        elseif maxPlayers > bj_MAX_PLAYER_SLOTS then
            maxPlayers = bj_MAX_PLAYER_SLOTS
        end

        local i = 0
        while i < maxPlayers do
            local player = Player(i)
            if not ignorePlayers[i]
                and GetPlayerController(player) == MAP_CONTROL_USER
                and GetPlayerSlotState(player) == PLAYER_SLOT_STATE_PLAYING then
                PlayerData.register(player)
            end
            SetPlayerState(player, PLAYER_STATE_GIVES_BOUNTY, 1)
            i = i + 1
        end
        return true
    end

    function Game.setupPlayers()
        if currentMode and currentMode.setupPlayers then
            return currentMode:setupPlayers()
        end
        return false
    end

    function Game.initialize()
        if not Game.isState(Game.STATE_IDLE) then
            return false
        end
        DefaultGameSettings.apply()
        gameId = gameId + 1
        Game.loadPlayers()
        if rawget(_G, "PlayerNameDisplay") then
            PlayerNameDisplay.update()
        end
        if rawget(_G, "PlayerProfile") then
            PlayerProfile.loadAllPlayers()
        end
        Game.applyPlayerDefaults()
        Game.revealMapForPlayers()
        Game.clearPlayerClasses()
        Game.setState(Game.STATE_STARTING)
        Game.say("[|cff20bb20Game Initializing|r]")
        return true
    end

    function Game.start()
        if not Game.isState(Game.STATE_STARTING) then
            return false
        end
        if rawget(_G, "WinCondition") then
            WinCondition.reset()
        end
        if gameClock then
            PauseTimer(gameClock)
            DestroyTimer(gameClock)
        end
        gameClock = CreateTimer()
        TimerStart(gameClock, 86400.0, false, function()
        end)
        if rawget(_G, "ExperienceSystem") then
            ExperienceSystem.initialize()
        end
        if rawget(_G, "PenaltyTimer") then
            PenaltyTimer.initialize()
        end
        if rawget(_G, "MercyLumber") then
            MercyLumber.initialize()
        end
        Game.setState(Game.STATE_STARTED)
        Game.say("[|cff20bb20Game Started|r]")
        -- A side can already be empty at start (every builder removed as AFK, or
        -- no builder spawned); nothing dies in that case to trigger the check.
        if rawget(_G, "WinCondition") and WinCondition.checkSoon then
            WinCondition.checkSoon()
        end
        if currentMode and currentMode.start then
            return currentMode:start()
        end
        return true
    end

    function Game.pause()
        oldState = state
        state = Game.STATE_PAUSED
        Game.say("[|cffbbbb20Game Paused|r]")
        if currentMode and currentMode.pause then
            currentMode:pause()
        end
    end

    function Game.resume()
        if not Game.isState(Game.STATE_PAUSED) then
            return
        end
        state = oldState
        Game.say("[|cff20bb20Game Resumed|r]")
        if currentMode and currentMode.resume then
            currentMode:resume()
        end
    end

    function Game.finish(result)
        local i = 1

        if rawget(_G, "ExperienceSystem") then
            ExperienceSystem.terminate()
        end
        if rawget(_G, "PenaltyTimer") then
            PenaltyTimer.terminate()
        end
        if rawget(_G, "MercyLumber") then
            MercyLumber.terminate()
        end
        state = Game.STATE_FINISHED
        while i <= #finishHandlers do
            finishHandlers[i](result)
            i = i + 1
        end
    end

    _G.Game = Game
end)

if Debug and Debug.endFile then Debug.endFile() end
