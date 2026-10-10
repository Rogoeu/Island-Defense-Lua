if Debug and Debug.beginFile then Debug.beginFile("Systems/MinionLumberTribute") end

OnInit("MinionLumberTribute", function(import)
    import.strict("GameTimer")
    import.strict("PlayerData")

    local TRIBUTE_INTERVAL = 30.0

    local function currentTitan()
        local list = PlayerData.withClass(PlayerData.CLASS_TITAN)
        local titanData = nil
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            if not playerData:isLeaving() and not playerData:hasLeft() then
                titanData = playerData
                i = list:size()
            end
            i = i + 1
        end

        list:destroy()
        return titanData
    end

    local function transferMinionLumber()
        local titanData = currentTitan()
        local list = nil
        local total = 0
        local i = 0

        if not titanData then
            return
        end

        list = PlayerData.withClass(PlayerData.CLASS_MINION)
        while i < list:size() do
            local minionData = list:at(i)
            local lumber = minionData:lumber()

            if not minionData:isFake() and not minionData:isLeaving() and lumber > 0 then
                minionData:setLumber(0)
                total = total + lumber
            end
            i = i + 1
        end
        list:destroy()

        if total > 0 then
            titanData:setLumber(titanData:lumber() + total)
        end
    end

    GameTimer.every(TRIBUTE_INTERVAL, transferMinionLumber)
end)

if Debug and Debug.endFile then Debug.endFile() end
