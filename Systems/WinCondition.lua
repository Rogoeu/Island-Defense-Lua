if Debug and Debug.beginFile then Debug.beginFile("Systems/WinCondition") end

OnInit("WinCondition", function(import)
    import.strict("GameTimer")
    import.strict("GameSettings")
    import.strict("PlayerData")
    import.strict("IslandDefenseSystem")
    import.strict("IslandDefenseMultiboard")
    import.strict("Races")

    local WinCondition = {}
    local finished = false
    local titanTypeIds = nil
    local minionTypeIds = nil

    local END_GAME_KEY = "WIN_CONDITION_END_GAME"
    local END_GAME_DELAY_SECONDS = 30.0
    local END_FOG_STYLE = 0
    local END_FOG_START = 350.0
    local END_FOG_END = 4200.0
    local END_FOG_DENSITY = 0.28
    local END_FOG_RED = 0.12
    local END_FOG_GREEN = 0.26
    local END_FOG_BLUE = 0.72

    local function isAlive(unit)
        if unit and GetWidgetLife(unit) > 0.405 then
            return true
        end

        local titanDeath = rawget(_G, "TitanDeath")
        return unit and titanDeath and titanDeath.isReincarnationPending and
            titanDeath.isReincarnationPending(unit) or false
    end

    local function shouldEndGame()
        if GameSettings.exists(END_GAME_KEY) then
            return GameSettings.getBool(END_GAME_KEY)
        end
        return false
    end

    local function debugCommandsEnabled(player)
        local cheatPack = rawget(_G, "DebugCheatPack")

        return cheatPack and cheatPack.isEnabled and cheatPack.isEnabled(player)
    end

    local function isTitanSide(classValue)
        return classValue == PlayerData.CLASS_TITAN or classValue == PlayerData.CLASS_MINION
    end

    local function ensureTitanSideTypeIds()
        local races = nil
        local i = 1

        if titanTypeIds then
            return
        end

        titanTypeIds = {}
        minionTypeIds = {}
        races = Races.all()
        while i <= #races do
            local race = races[i]

            if race:class() == PlayerData.CLASS_TITAN then
                local widgetIds = race:widgetIds()
                local childIds = race:childIds()
                local j = 1

                while j <= #widgetIds do
                    titanTypeIds[widgetIds[j]] = true
                    j = j + 1
                end
                j = 1
                while j <= #childIds do
                    minionTypeIds[childIds[j]] = true
                    j = j + 1
                end
            end
            i = i + 1
        end
    end

    local function countAliveDefenders()
        local list = PlayerData.withClass(PlayerData.CLASS_DEFENDER)
        local count = 0
        local i = 0

        while i < list:size() do
            if isAlive(list:at(i):unit()) then
                count = count + 1
            end
            i = i + 1
        end

        list:destroy()
        return count
    end

    local function countAliveTitanSide()
        local group = CreateGroup()
        local unit = nil
        local count = 0
        local counted = {}
        local players = PlayerData.allWithFake()
        local i = 0

        -- Hidden/transported main units may be absent from the spatial query
        -- (for example Fossurious during Crypt Tunnel). Count them directly.
        while i < players:size() do
            local data = players:at(i)
            local main = data:unit()
            if isTitanSide(data:class()) and main and GetUnitTypeId(main) ~= 0 and
                not IsUnitIllusion(main) and isAlive(main) and not counted[main] then
                counted[main] = true
                count = count + 1
            end
            i = i + 1
        end
        players:destroy()

        ensureTitanSideTypeIds()
        GroupEnumUnitsInRect(group, GetWorldBounds(), nil)
        unit = FirstOfGroup(group)
        while unit do
            local ownerData = PlayerData.get(GetOwningPlayer(unit))
            local mainClass = PlayerData.mainUnitClass(unit)
            local isTitanSideMain = isTitanSide(mainClass)
            local isKnownTitanSideType =
                titanTypeIds[GetUnitTypeId(unit)] or minionTypeIds[GetUnitTypeId(unit)]

            GroupRemoveUnit(group, unit)
            -- Legacy cosmetic abilities can morph a Titan's unit type. Its
            -- registered main-unit identity remains stable across that morph,
            -- while rawcodes still cover additional Minions owned by a player.
            if (isTitanSideMain or (isKnownTitanSideType and
                ownerData and isTitanSide(ownerData:class()))) and
                not counted[unit] and not IsUnitIllusion(unit) and isAlive(unit) then
                counted[unit] = true
                count = count + 1
            end
            unit = FirstOfGroup(group)
        end

        DestroyGroup(group)
        return count
    end

    local function applyFinalResults(winner)
        local list = PlayerData.allWithFake()
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            if winner == "titan" and isTitanSide(playerData:class()) then
                CustomVictoryBJ(playerData:player(), true, true)
            elseif winner == "defenders" and playerData:class() == PlayerData.CLASS_DEFENDER then
                CustomVictoryBJ(playerData:player(), true, true)
            else
                CustomDefeatBJ(playerData:player(), "Defeat!")
            end
            i = i + 1
        end
        list:destroy()
    end

    local function applyEndFog()
        SetTerrainFogEx(END_FOG_STYLE, END_FOG_START, END_FOG_END, END_FOG_DENSITY,
            END_FOG_RED, END_FOG_GREEN, END_FOG_BLUE)
    end

    local function resetEndFog()
        ResetTerrainFog()
    end

    local function finish(winner)
        if finished or not Game.isState(Game.STATE_STARTED) then
            return false
        end

        finished = true
        Game.finish(winner)
        applyEndFog()

        if winner == "titan" then
            IslandDefenseMultiboard.setPhase("Titan victory", 0)
            Game.say("|cffff6060The Titan has won!|r |cff99b4d1All Defenders have fallen.|r")
        else
            IslandDefenseMultiboard.setPhase("Defender victory", 0)
            Game.say("|cff80ff80The Defenders have won!|r |cff99b4d1The Titan side has been defeated.|r")
        end

        if shouldEndGame() then
            Game.say("|cff99b4d1The game will close in |r|cffffff80" ..
                I2S(R2I(END_GAME_DELAY_SECONDS)) .. " seconds|r|cff99b4d1.|r")
            GameTimer.after(END_GAME_DELAY_SECONDS, function()
                applyFinalResults(winner)
            end)
        end

        return true
    end

    function WinCondition.reset()
        finished = false
        resetEndFog()
    end

    function WinCondition.check()
        if finished or not Game.isState(Game.STATE_STARTED) then
            return false
        end

        if countAliveDefenders() <= 0 then
            return finish("titan")
        end

        if countAliveTitanSide() <= 0 then
            return finish("defenders")
        end

        return false
    end

    function WinCondition.checkSoon()
        GameTimer.after(0.05, WinCondition.check)
    end

    local trigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_DEATH, nil)
        i = i + 1
    end

    TriggerAddAction(trigger, function()
        local debugApi = rawget(_G, "Debug")
        if debugApi and debugApi.try then
            debugApi.try(WinCondition.checkSoon)
        else
            WinCondition.checkSoon()
        end
    end)

    if rawget(_G, "Command") then
        Command["-wincheck"].register(function(args)
            if not debugCommandsEnabled(args:player()) then
                return
            end
            if not WinCondition.check() then
                Command.say(args:player(),
                    "|cff99b4d1Alive:|r Defenders=" ..
                    I2S(countAliveDefenders()) ..
                    " TitanSide=" ..
                    I2S(countAliveTitanSide()))
            end
        end, "Debug: checks current win condition.")

        Command["-endgame"].register(function(args)
            local value = StringCase(args:at(0), false)
            if not debugCommandsEnabled(args:player()) then
                return
            end
            if value == "on" then
                GameSettings.setBool(END_GAME_KEY, true)
            elseif value == "off" then
                GameSettings.setBool(END_GAME_KEY, false)
            end

            if shouldEndGame() then
                Command.say(args:player(), "|cff80ff80Real victory/defeat enabled.|r")
            else
                Command.say(args:player(), "|cff99b4d1Real victory/defeat disabled. Lua will only announce winners.|r")
            end
        end, "Toggles actual CustomVictory/CustomDefeat: -endgame on/off")
    end

    _G.WinCondition = WinCondition
end)

if Debug and Debug.endFile then Debug.endFile() end
