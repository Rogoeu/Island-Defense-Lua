if Debug and Debug.beginFile then Debug.beginFile("Commands/ObserverCommand") end

OnInit("ObserverCommand", function(import)
    import.strict("CommandRegistry")
    import.strict("PlayerData")
    import.strict("TeamAlliances")
    import.strict("IslandDefenseMultiboard")

    local ObserverCommand = {}

    local function transferUnits(fromPlayer, toPlayer)
        local group = CreateGroup()
        GroupEnumUnitsOfPlayer(group, fromPlayer, nil)

        local unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            SetUnitOwner(unit, toPlayer, true)
            unit = FirstOfGroup(group)
        end

        DestroyGroup(group)
    end

    function ObserverCommand.findTitanForMinion(minionData)
        local titans = PlayerData.withClass(PlayerData.CLASS_TITAN)
        local found = nil
        local i = 0

        while i < titans:size() do
            local titanData = titans:at(i)
            if found == nil then
                found = titanData
            end
            if minionData:race() ~= NullRace.instance() and titanData:race() == minionData:race() then
                found = titanData
                i = titans:size()
            end
            i = i + 1
        end

        titans:destroy()
        return found
    end

    function ObserverCommand.applyObserverView(observerData, team)
        observerData:setObserver(true)
        observerData:setObserveTeam(team)
        observerData:setRace(NullRace.instance())

        if team == "titan" then
            observerData:setClass(PlayerData.CLASS_MINION)
        else
            observerData:setClass(PlayerData.CLASS_OBSERVER)
        end
        TeamAlliances.refresh()
    end

    function ObserverCommand.refreshObserverViews()
        local observers = PlayerData.observers()
        local i = 0

        while i < observers:size() do
            local observerData = observers:at(i)
            local team = observerData:observeTeam()
            if team == "" then
                team = "builder"
            end
            ObserverCommand.applyObserverView(observerData, team)
            i = i + 1
        end

        observers:destroy()
    end

    function ObserverCommand.moveMinionToBuilderObserver(minionData)
        local titanData = ObserverCommand.findTitanForMinion(minionData)

        if titanData then
            transferUnits(minionData:player(), titanData:player())
            titanData:setGold(titanData:gold() + minionData:gold())
            titanData:setLumber(titanData:lumber() + minionData:lumber())
        else
            transferUnits(minionData:player(), Player(PLAYER_NEUTRAL_PASSIVE))
        end

        minionData:setUnit(nil)
        minionData:setGold(0)
        minionData:setLumber(0)
        ObserverCommand.applyObserverView(minionData, "builder")
        IslandDefenseMultiboard.refresh()

        Game.say(minionData:nameColored() ..
            "|cff00bfff has moved themselves from being a minion and now is an observer of the defenders.|r")
    end

    local function run(args)
        local playerData = PlayerData.get(args:player())
        local team = StringCase(args:at(0), false)

        if not playerData then
            Command.say(args:player(), "|cffff6060No PlayerData found for observer command.|r")
            return
        end

        if team == "" or team == "builder" or team == "builders" or team == "defender" or team == "defenders" or team == "d" then
            if playerData:class() == PlayerData.CLASS_MINION then
                ObserverCommand.moveMinionToBuilderObserver(playerData)
            elseif playerData:isObserver() then
                ObserverCommand.applyObserverView(playerData, "builder")
                IslandDefenseMultiboard.refresh()
                Command.say(args:player(), "|cff80ff80Observing Builder team.|r")
            else
                Command.say(args:player(), "|cffff6060Only Minions can move themselves to Builder observer.|r")
            end
        elseif team == "titan" or team == "t" then
            if playerData:isObserver() then
                ObserverCommand.applyObserverView(playerData, "titan")
                IslandDefenseMultiboard.refresh()
                Command.say(args:player(), "|cff80ff80Observing Titan team.|r")
            else
                Command.say(args:player(), "|cffff6060Only Observers can switch to Titan observer.|r")
            end
        else
            Command.say(args:player(), "|cff99b4d1Usage: -obs builder | titan|r")
        end
    end

    Command["-obs"].register(run, "Minion: move to Builder observer. Observer: choose view.")
    Command["-observer"].register(run, "Observer command alias.")
    Command["-spec"].register(run, "Observer command alias.")
    Command["-spectate"].register(run, "Observer command alias.")

    _G.ObserverCommand = ObserverCommand
    _G.RefreshObserverViews = ObserverCommand.refreshObserverViews
end)

if Debug and Debug.endFile then Debug.endFile() end
