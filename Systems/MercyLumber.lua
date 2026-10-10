if Debug and Debug.beginFile then Debug.beginFile("Systems/MercyLumber") end

OnInit("MercyLumber", function(import)
    import.strict("GameTimer")
    import.strict("PlayerData")

    local LUMBER_PER_TICK = 10
    local TICK_INTERVAL = 60.0
    local tickTimer = nil

    local MercyLumber = {}

    local function giveDefendersLumber()
        local defenders = PlayerData.withClass(PlayerData.CLASS_DEFENDER)
        local i = 0

        while i < defenders:size() do
            local playerData = defenders:at(i)
            playerData:setLumber(playerData:lumber() + LUMBER_PER_TICK)
            i = i + 1
        end

        defenders:destroy()
    end

    function MercyLumber.initialize()
        MercyLumber.terminate()
        tickTimer = GameTimer.every(TICK_INTERVAL, giveDefendersLumber)
    end

    function MercyLumber.terminate()
        if tickTimer then
            tickTimer:destroy()
            tickTimer = nil
        end
    end

    _G.MercyLumber = MercyLumber
end)

if Debug and Debug.endFile then Debug.endFile() end
