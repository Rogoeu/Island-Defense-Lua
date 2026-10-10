if Debug and Debug.beginFile then Debug.beginFile("Systems/DefenderGhostBuildings") end

OnInit("DefenderGhostBuildings", function(import)
    import.strict("CommandRegistry")
    import.strict("GameSettings")
    import.strict("PlayerData")
    import.strict("GameTimer")

    local CONFIG = {
        enabledKey = "DEFENDER_GHOST_BUILDINGS_ENABLED",
        durationKey = "DEFENDER_GHOST_BUILDING_SECONDS",
        removeKey = "DEFENDER_GHOST_BUILDINGS_REMOVE",
        legacyEnabledKey = "NEUTRALIZE_STRUCTURES",
        legacyDurationKey = "NEUTRALIZE_STRUCTURES_DECAY_TIME",
        legacyRemoveKey = "NEUTRALIZE_STRUCTURES_DECAY",
        defaultEnabled = true,
        defaultDuration = 120.0,
        defaultRemove = true,
        ghostOwnerPlayerId = PLAYER_NEUTRAL_AGGRESSIVE,
        ghostAbility = FourCC("Abun"),
        removedAbility = FourCC("A0SL"),
        timedLifeBuff = FourCC("BTLF"),
        red = 50,
        green = 50,
        blue = 50,
        alpha = 130
    }

    local DefenderGhostBuildings = {}
    DefenderGhostBuildings.CONFIG = CONFIG
    local feedCreditByUnit = {}

    local function settingBool(key, legacyKey, defaultValue)
        if GameSettings.exists(key) then
            return GameSettings.getBool(key)
        end
        if legacyKey and GameSettings.exists(legacyKey) then
            return GameSettings.getBool(legacyKey)
        end
        return defaultValue
    end

    local function settingReal(key, legacyKey, defaultValue)
        if GameSettings.exists(key) then
            return GameSettings.getReal(key)
        end
        if legacyKey and GameSettings.exists(legacyKey) then
            return GameSettings.getReal(legacyKey)
        end
        return defaultValue
    end

    local function isAlive(unit)
        return unit and GetWidgetLife(unit) > 0.405
    end

    local function collectBuildings(player)
        local group = CreateGroup()
        local buildings = {}
        local unit = nil

        GroupEnumUnitsOfPlayer(group, player, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if isAlive(unit) and IsUnitType(unit, UNIT_TYPE_STRUCTURE) then
                buildings[#buildings + 1] = unit
            end
            unit = FirstOfGroup(group)
        end

        DestroyGroup(group)
        return buildings
    end

    local function setAllianceFlagBothWays(first, second, allianceType, enabled)
        SetPlayerAlliance(first, second, allianceType, enabled)
        SetPlayerAlliance(second, first, allianceType, enabled)
    end

    local function configureGhostAlliances()
        local ghostOwner = Player(CONFIG.ghostOwnerPlayerId)
        local list = PlayerData.allWithFake()
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            local player = playerData:player()
            local friendly = playerData:class() == PlayerData.CLASS_DEFENDER

            -- Ghost buildings behave like neutral critters for defenders: they
            -- are friendly, but never provide vision, control, XP or spells.
            setAllianceFlagBothWays(player, ghostOwner, ALLIANCE_PASSIVE, friendly)
            setAllianceFlagBothWays(player, ghostOwner, ALLIANCE_HELP_REQUEST, false)
            setAllianceFlagBothWays(player, ghostOwner, ALLIANCE_HELP_RESPONSE, false)
            setAllianceFlagBothWays(player, ghostOwner, ALLIANCE_SHARED_XP, false)
            setAllianceFlagBothWays(player, ghostOwner, ALLIANCE_SHARED_SPELLS, false)
            setAllianceFlagBothWays(player, ghostOwner, ALLIANCE_SHARED_VISION, false)
            setAllianceFlagBothWays(player, ghostOwner, ALLIANCE_SHARED_CONTROL, false)
            setAllianceFlagBothWays(player, ghostOwner, ALLIANCE_SHARED_ADVANCED_CONTROL, false)
            i = i + 1
        end
        list:destroy()
    end

    function DefenderGhostBuildings.enabled()
        return settingBool(CONFIG.enabledKey, CONFIG.legacyEnabledKey, CONFIG.defaultEnabled)
    end

    function DefenderGhostBuildings.setEnabled(value)
        GameSettings.setBool(CONFIG.enabledKey, value == true)
        GameSettings.setBool(CONFIG.legacyEnabledKey, value == true)
    end

    function DefenderGhostBuildings.duration()
        return settingReal(CONFIG.durationKey, CONFIG.legacyDurationKey, CONFIG.defaultDuration)
    end

    function DefenderGhostBuildings.setDuration(seconds)
        local value = seconds or CONFIG.defaultDuration
        GameSettings.setReal(CONFIG.durationKey, value)
        GameSettings.setReal(CONFIG.legacyDurationKey, value)
    end

    function DefenderGhostBuildings.removeAfterDuration()
        return settingBool(CONFIG.removeKey, CONFIG.legacyRemoveKey, CONFIG.defaultRemove)
    end

    function DefenderGhostBuildings.setRemoveAfterDuration(value)
        GameSettings.setBool(CONFIG.removeKey, value == true)
        GameSettings.setBool(CONFIG.legacyRemoveKey, value == true)
    end

    function DefenderGhostBuildings.refreshTitanHostility()
        configureGhostAlliances()
    end

    function DefenderGhostBuildings.feedCreditOwner(unit)
        if not unit then
            return nil
        end
        return feedCreditByUnit[GetHandleId(unit)]
    end

    function DefenderGhostBuildings.clearFeedCredit(unit)
        if unit then
            feedCreditByUnit[GetHandleId(unit)] = nil
        end
    end

    function DefenderGhostBuildings.removeNonStructureUnits(playerData)
        local group = CreateGroup()
        local units = {}
        local unit = nil
        local i = 1

        if not playerData then
            DestroyGroup(group)
            return 0
        end

        GroupEnumUnitsOfPlayer(group, playerData:player(), nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            if not IsUnitType(unit, UNIT_TYPE_STRUCTURE) then
                units[#units + 1] = unit
            end
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)

        while i <= #units do
            RemoveUnit(units[i])
            i = i + 1
        end

        return #units
    end

    function DefenderGhostBuildings.apply(playerData)
        local buildings = collectBuildings(playerData:player())
        local i = 1

        if not DefenderGhostBuildings.enabled() then
            while i <= #buildings do
                RemoveUnit(buildings[i])
                i = i + 1
            end
            return 0
        end

        configureGhostAlliances()
        while i <= #buildings do
            local building = buildings[i]
            feedCreditByUnit[GetHandleId(building)] = playerData
            SetUnitOwner(building, Player(CONFIG.ghostOwnerPlayerId), true)
            UnitAddAbility(building, CONFIG.ghostAbility)
            UnitRemoveAbility(building, CONFIG.removedAbility)
            SetUnitVertexColor(building, CONFIG.red, CONFIG.green, CONFIG.blue, CONFIG.alpha)
            if DefenderGhostBuildings.removeAfterDuration() then
                local duration = DefenderGhostBuildings.duration()
                UnitApplyTimedLife(building, CONFIG.timedLifeBuff, duration)
                GameTimer.after(duration + 1.0, function()
                    DefenderGhostBuildings.clearFeedCredit(building)
                end)
            end
            i = i + 1
        end

        return #buildings
    end

    if rawget(_G, "Command") then
        Command["-ghostbuildings"].register(function(args)
            local value = StringCase(args:at(0), false)
            if value == "on" then
                DefenderGhostBuildings.setEnabled(true)
            elseif value == "off" then
                DefenderGhostBuildings.setEnabled(false)
            end

            if DefenderGhostBuildings.enabled() then
                Command.say(args:player(), "|cff80ff80Ghost buildings enabled.|r")
            else
                Command.say(args:player(), "|cffff6060Ghost buildings disabled.|r")
            end
        end, "Toggles defender ghost buildings: -ghostbuildings on/off")

        Command["-ghostduration"].register(function(args)
            local seconds = tonumber(args:at(0) or "")
            if seconds and seconds >= 0 then
                DefenderGhostBuildings.setDuration(seconds)
            end
            Command.say(args:player(), "|cff99b4d1Ghost duration: |r|cffffff80" .. I2S(R2I(DefenderGhostBuildings.duration())) .. "s|r")
        end, "Sets defender ghost building duration.")
    end

    _G.DefenderGhostBuildings = DefenderGhostBuildings
end)

if Debug and Debug.endFile then Debug.endFile() end
