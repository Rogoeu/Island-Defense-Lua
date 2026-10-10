if Debug and Debug.beginFile then Debug.beginFile("Playground/IslandDefenseCoreTest") end

OnInit("IslandDefenseCoreTest", function(import)
    import.strict("CommandRegistry")
    import.strict("DebugCheatPack")
    import.strict("IslandDefenseGameMode")
    import.strict("UnitSpawner")
    import.strict("GameTimer")
    import.strict("IslandDefenseMultiboard")
    import.strict("RacePickModeAllPick")

    local function say(player, text)
        Command.say(player, text)
    end

    local function requireDebug(player)
        if DebugCheatPack.isEnabled(player) then
            return true
        end
        Command.say(player, "|cffff6060This command is only available in debug lobbies.|r")
        return false
    end

    local function classColor(classValue)
        if classValue == PlayerData.CLASS_TITAN then
            return "|cffff6060"
        elseif classValue == PlayerData.CLASS_DEFENDER then
            return "|cff80ff80"
        elseif classValue == PlayerData.CLASS_MINION then
            return "|cffffaa40"
        elseif classValue == PlayerData.CLASS_OBSERVER then
            return "|cff90b0d0"
        end
        return "|cffbbbbbb"
    end

    local function describePlayer(playerData)
        local race = playerData:race()
        local raceName = race and race:toString() or "_Null"
        local className = PlayerData.classToString(playerData:class())
        local fake = ""
        if playerData:isFake() then
            fake = " |cffbbbbbb(Fake)|r"
        end
        return classColor(playerData:class()) ..
            playerData:name() ..
            "|r |cff99b4d1=>|r " ..
            classColor(playerData:class()) ..
            className ..
            "|r |cff99b4d1/|r |cffffff80" ..
            raceName ..
            "|r" ..
            fake
    end

    local function setupPlayers(player)
        if Game.isState(Game.STATE_IDLE) then
            Game.initialize()
        elseif Game.isState(Game.STATE_FINISHED) then
            Game.setState(Game.STATE_STARTING)
        else
            Game.loadPlayers()
            Game.clearPlayerClasses()
            Game.setState(Game.STATE_STARTING)
        end

        Game.setMode(IslandDefenseGameMode)
        PlayerData.ensureFakePlayersWhenAlone(11)

        if not Game.setupPlayers() then
            say(player, "|cffff6060ID setup failed: no titan/player could be assigned.|r")
            return false
        end

        say(player, "|cff80ff80Island Defense setup complete.|r")
        IslandDefenseMultiboard.setPhase("Setup complete", 0)

        local list = PlayerData.allWithFake()
        local i = 0
        while i < list:size() do
            say(player, describePlayer(list:at(i)))
            i = i + 1
        end
        list:destroy()
        return true
    end

    local function status(player)
        say(player, "|cff99b4d1Game state:|r |cffffff80" .. Game.stateString(Game.state()) .. "|r")
        if Game.mode() then
            say(player, "|cff99b4d1Game mode:|r |cffffff80" .. Game.mode():name() .. "|r")
        else
            say(player, "|cff99b4d1Game mode:|r |cffbbbbbbnone|r")
        end
        say(player, "|cff99b4d1Players:|r |cffffff80" .. I2S(PlayerData.count()) .. "|r |cff99b4d1total,|r |cffffff80" .. I2S(PlayerData.countReal()) .. "|r |cff99b4d1real,|r |cffffff80" .. I2S(PlayerData.countFake()) .. "|r |cff99b4d1fake|r")

        local list = PlayerData.allWithFake()
        if list:size() == 0 then
            say(player, "|cffbbbbbbNo loaded PlayerData entries. Run -idsetup.|r")
        end

        local i = 0
        while i < list:size() do
            say(player, describePlayer(list:at(i)))
            i = i + 1
        end
        list:destroy()
    end

    local function reset(player)
        UnitSpawner.clearPlayerUnits()
        UnitSpawner.clearCore()
        Game.clearPlayerClasses()
        PlayerData.clear()
        Game.setState(Game.STATE_IDLE)
        say(player, "|cff80ff80Lua Island Defense test state reset.|r")
    end

    local function spawnForPlayer(player)
        local playerData = PlayerData.get(player)
        if not playerData then
            say(player, "|cffff6060Run -idsetup first.|r")
            return
        end

        local race = playerData:race()
        if not race or race == NullRace.instance() or race:widgetId() == 0 then
            say(player, "|cffff6060No spawnable race assigned.|r")
            return
        end

        local startLocation = GetPlayerStartLocation(player)
        local x = GetStartLocationX(startLocation)
        local y = GetStartLocationY(startLocation)
        local unit = UnitSpawner.spawnPlayerRace(playerData, x, y, 270)

        if unit then
            PanCameraToTimedForPlayer(player, x, y, 0)
            SelectUnitForPlayerSingle(unit, player)
            say(player, "|cff80ff80Spawned " .. race:toString() .. " at your start location.|r")
        else
            say(player, "|cffff6060Spawn failed.|r")
        end
    end

    local function spawnCore(player)
        UnitSpawner.spawnSpellWell()
        UnitSpawner.spawnShops()
        say(player, "|cff80ff80Spawned core test units: spell well and shops.|r")
    end

    local function startTest(player)
        if not setupPlayers(player) then
            return
        end

        Command.say(player, "|cff99b4d1Starting timed ID test...|r")
        IslandDefenseMultiboard.setPhase("Preparing start test", 3)

        GameTimer.after(1.0, function()
            IslandDefenseMultiboard.setPhase("Spawning core", 2)
            spawnCore(player)
        end)

        GameTimer.after(2.0, function()
            RacePickSystem.start("AP")
            say(player, "|cff80ff80ID pick test started.|r")
        end)
    end

    Command["-idsetup"].register(function(args)
        if not requireDebug(args:player()) then return end
        setupPlayers(args:player())
    end, "Loads players and assigns Island Defense classes/races.")

    Command["-idstatus"].register(function(args)
        if not requireDebug(args:player()) then return end
        status(args:player())
        IslandDefenseMultiboard.show()
    end, "Shows current Lua Island Defense test state.")

    Command["-idreset"].register(function(args)
        if not requireDebug(args:player()) then return end
        reset(args:player())
    end, "Resets Lua Island Defense test units and state.")

    Command["-idstarttest"].register(function(args)
        if not requireDebug(args:player()) then return end
        startTest(args:player())
    end, "Runs setup, core spawns and player race spawns.")

    Command["-idspawn"].register(function(args)
        local player = args:player()
        local mode = StringCase(args:at(0), false)

        if not requireDebug(player) then return end

        if mode == "me" then
            spawnForPlayer(player)
        elseif mode == "core" then
            spawnCore(player)
        else
            say(player, "|cff99b4d1Usage: -idspawn me | core|r")
        end
    end, "Spawns controlled Island Defense test units.")
end)

if Debug and Debug.endFile then Debug.endFile() end
