if Debug and Debug.beginFile then Debug.beginFile("Modes/IslandDefenseGameMode") end

OnInit("IslandDefenseGameMode", function(import)
    import.strict("IslandDefenseSystem")

    local mode = {}

    function mode:name()
        return "Island Defense"
    end

    function mode:shortName()
        return "ID"
    end

    function mode:description()
        return "The normal Island Defense mode."
    end

    function mode:isAvailable()
        return true
    end

    function mode:setupPlayers()
        local list = PlayerData.playingReal()
        local fakes = PlayerData.allWithFake()
        local observers = PlayerData.observers()
        local players = {}
        local titanAssigned = false
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

        i = 1
        while i <= #players do
            local playerData = players[i]
            if not titanAssigned then
                playerData:setClass(PlayerData.CLASS_TITAN)
                playerData:setRace(Races.random(PlayerData.CLASS_TITAN))
                titanAssigned = true
            else
                playerData:setClass(PlayerData.CLASS_DEFENDER)
                playerData:setRace(Races.random(PlayerData.CLASS_DEFENDER))
            end
            i = i + 1
        end

        i = 0
        while i < observers:size() do
            local playerData = observers:at(i)
            playerData:setClass(PlayerData.CLASS_OBSERVER)
            playerData:setRace(NullRace.instance())
            i = i + 1
        end

        list:destroy()
        fakes:destroy()
        observers:destroy()
        return titanAssigned
    end

    function mode:start()
        return true
    end

    function mode:pause()
    end

    function mode:resume()
    end

    function mode:stop()
    end

    function mode:restart()
    end

    Game.register(mode)
    _G.IslandDefenseGameMode = mode
end)

if Debug and Debug.endFile then Debug.endFile() end
