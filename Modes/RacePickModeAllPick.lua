if Debug and Debug.beginFile then Debug.beginFile("Modes/RacePickModeAllPick") end

OnInit("RacePickModeAllPick", function(import)
    import.strict("RacePickSystem")

    local mode = {}

    function mode:name()
        return "All Pick"
    end

    function mode:shortName()
        return "AP"
    end

    function mode:description()
        return "Defenders pick first, then the Titan picks."
    end

    function mode:start(system)
        local defenderPickSeconds = GameSettings.getReal("DEFENDER_PICK_TIME")
        local titanPickSeconds = GameSettings.getReal("TITAN_PICK_TIME")

        if defenderPickSeconds <= 0 then defenderPickSeconds = 10.0 end
        if titanPickSeconds <= 0 then titanPickSeconds = 10.0 end

        system.preparePickers()

        local defenders = PlayerData.withClass(PlayerData.CLASS_DEFENDER)
        local i = 0
        while i < defenders:size() do
            local playerData = defenders:at(i)
            playerData:setGold(playerData:gold() + 1)
            i = i + 1
        end
        defenders:destroy()
        system.enableClass(PlayerData.CLASS_DEFENDER)

        IslandDefenseMultiboard.setPhase("Defender picking", defenderPickSeconds)
        system.setTimer(defenderPickSeconds, function()
            system.autopickClass(PlayerData.CLASS_DEFENDER)
            system.spawnClass(PlayerData.CLASS_DEFENDER)
            local titans = PlayerData.withClass(PlayerData.CLASS_TITAN)
            local j = 0
            while j < titans:size() do
                local playerData = titans:at(j)
                playerData:setGold(playerData:gold() + 1)
                j = j + 1
            end
            titans:destroy()
            system.enableClass(PlayerData.CLASS_TITAN)

            IslandDefenseMultiboard.setPhase("Titan picking", titanPickSeconds)
            system.setTimer(titanPickSeconds, function()
                system.autopickClass(PlayerData.CLASS_TITAN)
                system.spawnClass(PlayerData.CLASS_TITAN)
                system.finish()
            end)
        end)
    end

    RacePickSystem.register(mode)
end)

if Debug and Debug.endFile then Debug.endFile() end
