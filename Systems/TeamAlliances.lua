if Debug and Debug.beginFile then Debug.beginFile("Systems/TeamAlliances") end

OnInit("TeamAlliances", function(import)
    import.strict("PlayerData")

    local TeamAlliances = {}
    local refreshCallbacks = {}

    local function setTeamAlliance(from, to, allied, sharedResources)
        SetPlayerAlliance(from, to, ALLIANCE_PASSIVE, allied)
        SetPlayerAlliance(from, to, ALLIANCE_HELP_REQUEST, allied)
        SetPlayerAlliance(from, to, ALLIANCE_HELP_RESPONSE, allied)
        SetPlayerAlliance(from, to, ALLIANCE_SHARED_XP, sharedResources)
        SetPlayerAlliance(from, to, ALLIANCE_SHARED_SPELLS, sharedResources)
        SetPlayerAlliance(from, to, ALLIANCE_SHARED_VISION, allied)
    end

    local function setSharedControl(from, to, enabled)
        SetPlayerAlliance(from, to, ALLIANCE_SHARED_CONTROL, enabled)
        SetPlayerAlliance(from, to, ALLIANCE_SHARED_ADVANCED_CONTROL, enabled)
    end

    local function isObserver(playerData)
        return playerData and playerData:isObserver()
    end

    local function observesTitan(playerData)
        return isObserver(playerData) and playerData:observeTeam() == "titan"
    end

    local function observesDefenders(playerData)
        return isObserver(playerData) and playerData:observeTeam() ~= "titan"
    end

    local function isActiveDefender(playerData)
        return playerData and not isObserver(playerData) and playerData:class() == PlayerData.CLASS_DEFENDER
    end

    local function isActiveTitanSide(playerData)
        return playerData and not isObserver(playerData) and (
            playerData:class() == PlayerData.CLASS_TITAN or
            playerData:class() == PlayerData.CLASS_MINION
        )
    end

    function TeamAlliances.isTitanSide(playerData)
        return isActiveTitanSide(playerData) or observesTitan(playerData)
    end

    function TeamAlliances.isBuilderSide(playerData)
        return isActiveDefender(playerData) or observesDefenders(playerData)
    end

    function TeamAlliances.areAllied(a, b)
        if not a or not b then
            return false
        end
        if TeamAlliances.isTitanSide(a) or TeamAlliances.isTitanSide(b) then
            return TeamAlliances.isTitanSide(a) and TeamAlliances.isTitanSide(b)
        end
        return TeamAlliances.isBuilderSide(a) and TeamAlliances.isBuilderSide(b)
    end

    function TeamAlliances.canGameplayShare(a, b)
        if not a or not b then
            return false
        end
        return TeamAlliances.areAllied(a, b)
    end

    function TeamAlliances.canSharedControl(a, b)
        return a and not a:hasLeft() and a:isLeaving() and TeamAlliances.areAllied(a, b)
    end

    local function setAllianceState(from, to, state)
        if rawget(_G, "SetPlayerAllianceStateBJ") then
            SetPlayerAllianceStateBJ(from, to, state)
        else
            SetPlayerAlliance(from, to, ALLIANCE_PASSIVE, state == bj_ALLIANCE_ALLIED)
        end
    end

    local function applyNeutralRelations(playerData)
        local player = playerData:player()
        local neutralPassive = Player(PLAYER_NEUTRAL_PASSIVE)
        local neutralAggressive = Player(PLAYER_NEUTRAL_AGGRESSIVE)

        if TeamAlliances.isBuilderSide(playerData) then
            setAllianceState(neutralPassive, player, bj_ALLIANCE_ALLIED)
            setAllianceState(neutralAggressive, player, bj_ALLIANCE_NEUTRAL)
            setAllianceState(player, neutralAggressive, bj_ALLIANCE_NEUTRAL)
        else
            setAllianceState(neutralPassive, player, bj_ALLIANCE_NEUTRAL)
            setAllianceState(neutralAggressive, player, bj_ALLIANCE_UNALLIED)
            setAllianceState(player, neutralAggressive, bj_ALLIANCE_UNALLIED)
            SetPlayerAlliance(neutralAggressive, player, ALLIANCE_PASSIVE, false)
            SetPlayerAlliance(player, neutralAggressive, ALLIANCE_PASSIVE, false)
        end
    end

    function TeamAlliances.refresh()
        local list = PlayerData.allWithFake()
        local i = 0

        while i < list:size() do
            local j = 0
            local a = list:at(i)

            while j < list:size() do
                if i ~= j then
                    local b = list:at(j)
                    local allied = TeamAlliances.areAllied(a, b)
                    setTeamAlliance(a:player(), b:player(), allied, TeamAlliances.canGameplayShare(a, b))
                    if TeamAlliances.canSharedControl(a, b) then
                        setSharedControl(a:player(), b:player(), true)
                    elseif not allied then
                        setSharedControl(a:player(), b:player(), false)
                    end
                end
                j = j + 1
            end
            applyNeutralRelations(a)
            i = i + 1
        end

        list:destroy()

        i = 1
        while i <= #refreshCallbacks do
            refreshCallbacks[i]()
            i = i + 1
        end

        local ghostBuildings = rawget(_G, "DefenderGhostBuildings")
        if ghostBuildings and ghostBuildings.refreshTitanHostility then
            ghostBuildings.refreshTitanHostility()
        end
    end

    function TeamAlliances.onRefresh(callback)
        if callback then
            refreshCallbacks[#refreshCallbacks + 1] = callback
        end
    end

    _G.TeamAlliances = TeamAlliances
end)

if Debug and Debug.endFile then Debug.endFile() end
