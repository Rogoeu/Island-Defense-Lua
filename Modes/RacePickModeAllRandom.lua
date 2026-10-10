if Debug and Debug.beginFile then Debug.beginFile("Modes/RacePickModeAllRandom") end

OnInit("RacePickModeAllRandom", function(import)
    import.strict("RacePickSystem")

    local mode = {}

    function mode:name()
        return "All Random"
    end

    function mode:shortName()
        return "AR"
    end

    function mode:description()
        return "Defenders and the Titan receive random races."
    end

    local function markClassRandoming(classValue)
        local list = PlayerData.withClass(classValue)
        local i = 0

        while i < list:size() do
            list:at(i):setRandoming(true)
            i = i + 1
        end
        list:destroy()
    end

    function mode:start(system)
        local graceSeconds = GameSettings.getReal("TITAN_SPAWN_GRACE_TIME")

        if graceSeconds <= 0.0 then
            graceSeconds = 55.0
        end

        system.preparePickers()
        markClassRandoming(PlayerData.CLASS_DEFENDER)
        Game.say("|cff99b4d1All Random: defender races are being rolled.|r")
        system.autopickClassUnique(PlayerData.CLASS_DEFENDER)
        system.spawnClass(PlayerData.CLASS_DEFENDER)

        Game.say("|cff99b4d1All Random: Titan spawns after the grace period.|r")
        IslandDefenseMultiboard.setPhase("Grace period", graceSeconds)
        system.setTimer(graceSeconds, function()
            Game.say("|cff99b4d1All Random: titan race is being rolled.|r")
            markClassRandoming(PlayerData.CLASS_TITAN)
            system.autopickClass(PlayerData.CLASS_TITAN)
            system.spawnClass(PlayerData.CLASS_TITAN)
            system.finish()
        end)
    end

    RacePickSystem.register(mode)
end)

if Debug and Debug.endFile then Debug.endFile() end
