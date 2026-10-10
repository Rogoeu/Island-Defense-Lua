if Debug and Debug.beginFile then Debug.beginFile("Player/PlayerNameDisplay") end

OnInit("PlayerNameDisplay", function(import)
    import.strict("PlayerData")
    import.strict("PlayerColorUtils")

    local PlayerNameDisplay = {}

    local function classLabel(playerData)
        local classValue = playerData:class()

        if classValue == PlayerData.CLASS_DEFENDER then
            return "Builder"
        end
        return PlayerData.classToString(classValue)
    end

    local function raceLabel(playerData)
        local race = playerData:race()

        if race and race ~= NullRace.instance() then
            return race:toString()
        end
        return classLabel(playerData)
    end

    local function visibleLabel(viewer, target)
        local viewerClass = viewer:class()
        local targetClass = target:class()

        if targetClass == PlayerData.CLASS_NONE then
            return ""
        end

        -- Match the old ClassTweak visibility rules. A team sees its own picked
        -- races, while opponents only see Builder/Titan/Minion role labels.
        if viewerClass == PlayerData.CLASS_DEFENDER or viewerClass == PlayerData.CLASS_OBSERVER then
            if targetClass == PlayerData.CLASS_DEFENDER then
                return raceLabel(target)
            end
            return classLabel(target)
        end
        if viewerClass == PlayerData.CLASS_TITAN or viewerClass == PlayerData.CLASS_MINION then
            if targetClass == PlayerData.CLASS_TITAN then
                return raceLabel(target)
            end
            return classLabel(target)
        end
        return classLabel(target)
    end

    local function displayNameFor(viewer, target)
        local label = visibleLabel(viewer, target)
        local name = target:displayName()

        if label ~= "" then
            name = name .. " (" .. label .. ")"
        end
        return PlayerColorUtils.wrap(target:player(), name)
    end

    function PlayerNameDisplay.updateForPlayer(viewer)
        local list = nil
        local i = 0

        if not viewer or viewer:player() ~= GetLocalPlayer() then
            return false
        end

        list = PlayerData.allWithFake()
        while i < list:size() do
            local target = list:at(i)
            SetPlayerName(target:player(), displayNameFor(viewer, target))
            i = i + 1
        end
        list:destroy()
        return true
    end

    function PlayerNameDisplay.update()
        local list = PlayerData.allWithFake()
        local i = 0

        while i < list:size() do
            local viewer = list:at(i)
            if viewer:player() == GetLocalPlayer() then
                list:destroy()
                return PlayerNameDisplay.updateForPlayer(viewer)
            end
            i = i + 1
        end
        list:destroy()
        return false
    end

    _G.PlayerNameDisplay = PlayerNameDisplay
end)

if Debug and Debug.endFile then Debug.endFile() end
