if Debug and Debug.beginFile then Debug.beginFile("Races/RacePickSystem") end

OnInit("RacePickSystem", function(import)
    import.strict("MapAreas")
    import.strict("GameTimer")
    import.strict("UnitSpawner")
    import.strict("IslandDefenseMultiboard")
    import.strict("GameSettings")
    import.strict("PlayerProfile")
    import.strict("TeamAlliances")

    local modes = {}
    local currentMode = nil
    local state = "idle"
    local activeTimer = nil
    local builderSpawnHandlers = {}
    local titanSpawnHandlers = {}
    local randomBans = {}
    local builderSpawnPositions = {}
    local afkBuildersChecked = false
    local pendingModeName = nil
    local profileSyncWaitRegistered = false
    local TITAN_START_ITEM_SETTING_KEYS = {
        "TITAN_START_ITEM_SLOT_1",
        "TITAN_START_ITEM_SLOT_2",
        "TITAN_START_ITEM_SLOT_3",
        "TITAN_START_ITEM_SLOT_4",
        "TITAN_START_ITEM_SLOT_5",
        "TITAN_START_ITEM_SLOT_6"
    }

    local RacePickSystem = {}

    local function removePlayerUnits(player)
        local group = CreateGroup()
        local unit = nil

        GroupEnumUnitsOfPlayer(group, player, nil)
        unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            RemoveUnit(unit)
            unit = FirstOfGroup(group)
        end
        DestroyGroup(group)
    end

    local function removeAfkBuilders()
        local list = nil
        local changed = false
        local i = 0

        if afkBuildersChecked or
            not GameSettings.getBool("PICKMODE_REMOVE_AFK") then
            return
        end
        afkBuildersChecked = true

        list = PlayerData.withClass(PlayerData.CLASS_DEFENDER)
        while i < list:size() do
            local playerData = list:at(i)
            local unit = playerData:unit()
            local initial = builderSpawnPositions[playerData:id()]

            if not playerData:isFake() and
                not playerData:hasLeft() and
                unit and GetUnitTypeId(unit) ~= 0 and
                initial and
                GetUnitX(unit) == initial.x and
                GetUnitY(unit) == initial.y then
                Game.say(playerData:nameColored() ..
                    "|cff99b4d1 has been changed to an observer for not moving in the allocated time.|r")
                removePlayerUnits(playerData:player())
                playerData:setUnit(nil)
                playerData:setClass(PlayerData.CLASS_OBSERVER)
                playerData:setObserver(true)
                playerData:setObserveTeam("builder")
                playerData:setRace(NullRace.instance())
                changed = true
            end
            i = i + 1
        end
        list:destroy()

        if changed then
            TeamAlliances.refresh()
            if rawget(_G, "RefreshObserverViews") then
                RefreshObserverViews()
            end
            IslandDefenseMultiboard.refresh()
        end
    end

    local function privateSay(playerData, text)
        if playerData and not playerData:isFake() then
            DisplayTimedTextToPlayer(playerData:player(), 0, 0, 10, text)
        end
    end

    local function saveProfileIfLocal(playerData)
        if playerData and GetLocalPlayer() == playerData:player() then
            PlayerProfile.saveAllPlayers()
        end
    end

    local function banList(playerData)
        local id = playerData:id()
        if not randomBans[id] then
            randomBans[id] = {}
        end
        return randomBans[id]
    end

    local function findRacePartialForClass(name, classValue)
        local wanted = tostring(name or "")
        local found = NullRace.instance()
        local races = Races.all()
        local i = 1

        while i <= #races do
            local race = races[i]
            if race:class() == classValue and StringIndexOf(race:toString(), wanted, false) == 0 then
                if found == NullRace.instance() then
                    found = race
                else
                    return NullRace.instance()
                end
            end
            i = i + 1
        end

        return found
    end

    local function raceIsBanned(playerData, race)
        local list = banList(playerData)
        local i = 1
        while i <= #list do
            if list[i] == race then
                return true
            end
            i = i + 1
        end
        return false
    end

    local function addRandomBan(playerData, race, saveImmediately)
        local list = banList(playerData)
        local role = playerData:class() == PlayerData.CLASS_TITAN and "titan" or "builder"
        if raceIsBanned(playerData, race) then
            return false
        end
        list[#list + 1] = race
        PlayerProfile.bans(playerData, role)[race:toString()] = true
        if saveImmediately ~= false then
            saveProfileIfLocal(playerData)
        end
        return true
    end

    local function clearRandomBans(playerData, saveImmediately)
        local role = playerData:class() == PlayerData.CLASS_TITAN and "titan" or "builder"
        local saved = PlayerProfile.bans(playerData, role)
        local raceName = nil

        randomBans[playerData:id()] = {}
        for raceName in pairs(saved) do
            saved[raceName] = nil
        end
        if saveImmediately ~= false then
            saveProfileIfLocal(playerData)
        end
    end

    local function restoreRandomBans(playerData)
        local role = playerData:class() == PlayerData.CLASS_TITAN and "titan" or "builder"
        local saved = PlayerProfile.bans(playerData, role)
        local list = nil
        local restoredNames = {}
        local raceName = nil

        randomBans[playerData:id()] = {}
        list = banList(playerData)
        for raceName in pairs(saved) do
            local race = Races.fromName(raceName)
            if race ~= NullRace.instance() and race:class() == playerData:class() and race:inRandomPool() then
                list[#list + 1] = race
                restoredNames[#restoredNames + 1] = race:toString()
            else
                saved[raceName] = nil
            end
        end

        if #restoredNames > 0 and not playerData:isFake() then
            table.sort(restoredNames)
            privateSay(playerData, "|cff99b4d1Loaded saved bans: |r|cffffff80" .. table.concat(restoredNames, ", ") .. "|r")
        end
    end

    local function randomRaceForPlayer(playerData)
        local pool = {}
        local races = Races.all()
        local i = 1

        while i <= #races do
            local race = races[i]
            if race:inRandomPool() and race:class() == playerData:class() and not raceIsBanned(playerData, race) then
                pool[#pool + 1] = race
            end
            i = i + 1
        end

        if #pool == 0 then
            return Races.random(playerData:class())
        end

        return pool[GetRandomInt(1, #pool)]
    end

    local function maxBansFor(playerData)
        if playerData:class() == PlayerData.CLASS_TITAN then
            return GameSettings.getInt("PICKMODE_RACE_BAN_MAX_TITANS")
        end
        return GameSettings.getInt("PICKMODE_RACE_BAN_MAX")
    end

    local function isBuilderView(playerData)
        if playerData:class() == PlayerData.CLASS_DEFENDER then
            return true
        end
        if playerData.isObserver and playerData:isObserver() then
            return playerData:observeTeam() ~= "titan"
        end
        return false
    end

    function RacePickSystem.register(mode)
        modes[StringCase(mode:shortName(), false)] = mode
        modes[StringCase(mode:name(), false)] = mode
        if not currentMode then
            currentMode = mode
        end
        return mode
    end

    function RacePickSystem.mode()
        return currentMode
    end

    function RacePickSystem.setMode(name)
        currentMode = modes[StringCase(tostring(name or ""), false)] or currentMode
        return currentMode
    end

    function RacePickSystem.state()
        return state
    end

    function RacePickSystem.clearRandomBans(playerData)
        clearRandomBans(playerData)
    end

    function RacePickSystem.addRandomBan(playerData, race)
        return addRandomBan(playerData, race)
    end

    function RacePickSystem.isRaceBanned(playerData, race)
        return raceIsBanned(playerData, race)
    end

    function RacePickSystem.randomBanCount(playerData)
        return #banList(playerData)
    end

    function RacePickSystem.randomRaceForPlayer(playerData)
        return randomRaceForPlayer(playerData)
    end

    function RacePickSystem.say(playerData, text)
        privateSay(playerData, text)
    end

    function RacePickSystem.sayBuilderTeam(text)
        local list = PlayerData.allReal()
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            if isBuilderView(playerData) then
                DisplayTimedTextToPlayer(playerData:player(), 0, 0, 10, text)
            end
            i = i + 1
        end

        list:destroy()
    end

    function RacePickSystem.cancelTimer()
        if activeTimer then
            activeTimer:destroy()
            activeTimer = nil
        end
    end

    function RacePickSystem.setTimer(seconds, callback)
        RacePickSystem.cancelTimer()
        activeTimer = GameTimer.after(seconds, function()
            activeTimer = nil
            callback()
        end)
    end

    function RacePickSystem.onBuilderSpawn(callback)
        if callback then
            builderSpawnHandlers[#builderSpawnHandlers + 1] = callback
        end
    end

    RacePickSystem.onBuilderspawn = RacePickSystem.onBuilderSpawn

    function RacePickSystem.onTitanSpawn(callback)
        if callback then
            titanSpawnHandlers[#titanSpawnHandlers + 1] = callback
        end
    end

    RacePickSystem.onTitanspawn = RacePickSystem.onTitanSpawn

    function RacePickSystem.runBuilderSpawnHandlers(playerData, unit)
        local i = 1
        while i <= #builderSpawnHandlers do
            builderSpawnHandlers[i](playerData, unit)
            i = i + 1
        end
    end

    function RacePickSystem.runTitanSpawnHandlers(playerData, unit)
        local i = 1
        while i <= #titanSpawnHandlers do
            titanSpawnHandlers[i](playerData, unit)
            i = i + 1
        end
    end

    RacePickSystem.onBuilderSpawn(function(playerData)
        local player = playerData:player()

        -- Old DefenderUnit.prepare allowed every Defender exactly one hero.
        SetPlayerTechMaxAllowed(player, FourCC("HERO"), 1)

        if not GameSettings.getBool("APPLY_RACE_TECH_LIMITS") then
            return
        end

        local race = playerData:race()
        local ultimateTowers = race:ultimateTowerIds()
        local techLimits = race:techLimits()
        local hunterIds = race:childIds()
        local i = 1

        -- The old DefenderUnit.prepare disabled the standard Root ability globally.
        -- Some builder structures inherit it, but Island Defense does not allow rooting or uprooting them.
        SetPlayerAbilityAvailable(player, FourCC("Aro1"), false)

        while i <= #ultimateTowers do
            SetPlayerTechMaxAllowed(player, ultimateTowers[i], 0)
            i = i + 1
        end

        i = 1
        while i <= #techLimits do
            SetPlayerTechMaxAllowed(player, techLimits[i].id, techLimits[i].max)
            i = i + 1
        end

        -- Old DefenderUnit.prepare capped every Titan Hunter child unit at one.
        -- Keep this generic so new builder races automatically receive the same limit.
        i = 1
        while i <= #hunterIds do
            if hunterIds[i] ~= 0 then
                SetPlayerTechMaxAllowed(player, hunterIds[i], 1)
            end
            i = i + 1
        end
    end)

    local function setBuilderStartResources(playerData)
        local gold = GameSettings.getInt("BUILDER_START_GOLD")
        local lumber = GameSettings.getInt("BUILDER_START_LUMBER")

        if playerData.isRandoming and playerData:isRandoming() then
            gold = gold + GameSettings.getInt("BUILDER_RANDOM_BONUS_GOLD")
            lumber = lumber + GameSettings.getInt("BUILDER_RANDOM_BONUS_LUMBER")
        end

        playerData:setGold(gold)
        playerData:setLumber(lumber)
    end

    local function giveTitanStartItems(unit)
        local i = 1

        while i <= #TITAN_START_ITEM_SETTING_KEYS do
            local rawcode = GameSettings.getStr(TITAN_START_ITEM_SETTING_KEYS[i])

            -- Empty slots are intentional; only valid four-character Warcraft rawcodes are used.
            if string.len(rawcode) == 4 then
                UnitAddItemById(unit, FourCC(rawcode))
            end
            i = i + 1
        end
    end

    RacePickSystem.onTitanSpawn(function(playerData, unit)
        UnitSpawner.setHeroLevel(unit, UnitSpawner.titanStartingLevel())
        UnitSpawner.unlockTitanSpellWell()
        giveTitanStartItems(unit)

        local gold = GameSettings.getInt("TITAN_START_GOLD")
        local lumber = GameSettings.getInt("TITAN_START_LUMBER")

        if playerData.isRandoming and playerData:isRandoming() then
            gold = gold + GameSettings.getInt("TITAN_RANDOM_GOLD_BONUS")
            lumber = lumber + GameSettings.getInt("TITAN_RANDOM_WOOD_BONUS")
        end

        playerData:setGold(gold)
        playerData:setLumber(lumber)
    end)

    function RacePickSystem.preparePickers()
        builderSpawnPositions = {}
        afkBuildersChecked = false
        UnitSpawner.spawnPickShops()
        UnitSpawner.populatePickShops()

        local list = PlayerData.allWithFake()
        local i = 0
        while i < list:size() do
            local playerData = list:at(i)
            playerData:setPicked(false)
            playerData:setCanPick(false)
            if playerData:class() ~= PlayerData.CLASS_OBSERVER then
                playerData:setRace(NullRace.instance())
            end
            playerData:setRandoming(false)
            restoreRandomBans(playerData)
            UnitSpawner.clearPicker(playerData)
            i = i + 1
        end
        list:destroy()
    end

    function RacePickSystem.enableClass(classValue)
        local list = PlayerData.withClass(classValue)
        local i = 0
        while i < list:size() do
            local playerData = list:at(i)
            if not playerData:hasPicked() then
                if playerData:isFake() then
                    RacePickSystem.randomPick(playerData)
                else
                    UnitSpawner.spawnPicker(playerData)
                    UnitSpawner.focusPickerCamera(playerData)
                    playerData:setCanPick(true)
                end
            end
            i = i + 1
        end
        list:destroy()
    end

    function RacePickSystem.showClassPickerVision(classValue)
        local list = PlayerData.withClass(classValue)
        local i = 0
        while i < list:size() do
            local playerData = list:at(i)
            if not playerData:isFake() and playerData:race() == NullRace.instance() then
                UnitSpawner.spawnPicker(playerData)
                UnitSpawner.focusPickerCamera(playerData)
                playerData:setCanPick(false)
            end
            i = i + 1
        end
        list:destroy()
    end

    function RacePickSystem.spawnClass(classValue)
        if classValue == PlayerData.CLASS_TITAN then
            removeAfkBuilders()
        end

        local list = PlayerData.withClass(classValue)
        local players = {}
        local i = 0
        while i < list:size() do
            local playerData = list:at(i)
            if playerData:race() ~= NullRace.instance() and playerData:unit() == nil then
                players[#players + 1] = playerData
            end
            i = i + 1
        end
        list:destroy()

        if #players == 0 then
            return
        end

        local baseRadius = 150.0
        if classValue == PlayerData.CLASS_TITAN then
            baseRadius = 190.0
        end

        local offset = GetRandomReal(0.0, 360.0)
        local j = 1
        local titanSpawned = false
        while j <= #players do
            local playerData = players[j]
            if classValue == PlayerData.CLASS_TITAN then
                UnitSpawner.setTitanShopOwner(playerData:player())
                if rawget(_G, "PunishmentCentre") and PunishmentCentre.update then
                    PunishmentCentre.update()
                end
            elseif classValue == PlayerData.CLASS_DEFENDER then
                -- Grant start resources before unit creation. Cosmetic or
                -- race-specific spawn failures must not skip the random bonus.
                setBuilderStartResources(playerData)
            end

            local angle = offset + ((j - 1) * 360.0 / #players) + GetRandomReal(-8.0, 8.0)
            local radius = baseRadius + GetRandomReal(-25.0, 25.0)
            local unit = UnitSpawner.spawnPlayerRaceAtStart(playerData, angle, radius)
            if unit then
                if classValue == PlayerData.CLASS_DEFENDER then
                    builderSpawnPositions[playerData:id()] = {
                        x = GetUnitX(unit),
                        y = GetUnitY(unit)
                    }
                    RacePickSystem.runBuilderSpawnHandlers(playerData, unit)
                    RacePickSystem.sayBuilderTeam("|cff99b4d1" .. playerData:displayName() ..
                        "'s builder is |r|cffffff80" .. playerData:race():toString() .. "|r|cff99b4d1.|r")
                elseif classValue == PlayerData.CLASS_TITAN then
                    RacePickSystem.runTitanSpawnHandlers(playerData, unit)
                    titanSpawned = true
                end
                UnitSpawner.clearPicker(playerData)
                UnitSpawner.focusMainUnitCamera(playerData)
            end
            j = j + 1
        end

        if titanSpawned and rawget(_G, "gg_snd_Titan_Ready") then
            StartSound(gg_snd_Titan_Ready)
        end
    end

    function RacePickSystem.finishPickers()
        local list = PlayerData.allWithFake()
        local i = 0
        while i < list:size() do
            local playerData = list:at(i)
            playerData:setCanPick(false)
            UnitSpawner.clearPicker(playerData)
            i = i + 1
        end
        list:destroy()
        UnitSpawner.clearPickShops()
    end

    function RacePickSystem.pick(playerData, race, silent)
        if not playerData or not race or race == NullRace.instance() then
            return false
        end
        if not playerData:canPick() then
            return false
        end
        if race:class() ~= playerData:class() then
            return false
        end

        playerData:setRace(race)
        playerData:setPicked(true)
        playerData:setCanPick(false)
        playerData:setRandoming(false)
        if not silent then
            privateSay(playerData, "|cff99b4d1Your first pick is: |r|cffffff80" .. race:toString() .. "|r")
        end
        IslandDefenseMultiboard.refresh()
        return true
    end

    function RacePickSystem.randomPick(playerData)
        local race = randomRaceForPlayer(playerData)
        playerData:setCanPick(true)
        if RacePickSystem.pick(playerData, race, true) then
            playerData:setRandoming(true)
            privateSay(playerData, "|cff99b4d1Your first pick is: |r|cffffff80Random|r")
            return true
        end
        return false
    end

    function RacePickSystem.pickFromItem(playerData, itemTypeId)
        if currentMode and currentMode.pickFromItem then
            local handled = currentMode:pickFromItem(RacePickSystem, playerData, itemTypeId)
            if handled ~= nil then
                return handled
            end
        end

        return RacePickSystem.defaultPickFromItem(playerData, itemTypeId)
    end

    function RacePickSystem.defaultPickFromItem(playerData, itemTypeId)
        if itemTypeId == UnitSpawner.ids.RANDOM_RACE_ITEM then
            return RacePickSystem.randomPick(playerData)
        end
        return RacePickSystem.pick(playerData, Races.fromItemId(itemTypeId))
    end

    function RacePickSystem.autopickClass(classValue)
        local list = PlayerData.withClass(classValue)
        local i = 0
        while i < list:size() do
            local playerData = list:at(i)
            if not playerData:hasPicked() then
                RacePickSystem.randomPick(playerData)
            end
            i = i + 1
        end
        list:destroy()
    end

    function RacePickSystem.autopickClassUnique(classValue)
        local pool = {}
        local players = {}
        local races = Races.all()
        local i = 1

        while i <= #races do
            local race = races[i]
            if race:class() == classValue and race:inRandomPool() then
                pool[#pool + 1] = race
            end
            i = i + 1
        end

        local list = PlayerData.withClass(classValue)
        i = 0
        while i < list:size() do
            local playerData = list:at(i)
            if not playerData:hasPicked() then
                players[#players + 1] = playerData
            end
            i = i + 1
        end
        list:destroy()

        -- Randomize the assignment order so a fixed player slot does not always receive
        -- the first available race from the shared pool.
        i = #players
        while i > 1 do
            local index = GetRandomInt(1, i)
            local temporary = players[i]
            players[i] = players[index]
            players[index] = temporary
            i = i - 1
        end

        i = 1
        while i <= #players do
            local playerData = players[i]
            local options = {}
            local race = nil
            local j = 1

            while j <= #pool do
                if not raceIsBanned(playerData, pool[j]) then
                    options[#options + 1] = pool[j]
                end
                j = j + 1
            end

            if #options > 0 then
                race = options[GetRandomInt(1, #options)]
                j = 1
                while j <= #pool do
                    if pool[j] == race then
                        table.remove(pool, j)
                        break
                    end
                    j = j + 1
                end
            else
                -- A duplicate is only possible when there are fewer eligible races than
                -- players, or a player's bans exclude every remaining unique option.
                race = randomRaceForPlayer(playerData)
            end

            playerData:setCanPick(true)
            if RacePickSystem.pick(playerData, race, true) then
                playerData:setRandoming(true)
                privateSay(playerData, "|cff99b4d1Your first pick is: |r|cffffff80Random|r")
            end
            i = i + 1
        end
    end

    function RacePickSystem.start(modeName)
        if not PlayerProfile.areProfilesSynchronized() then
            pendingModeName = modeName or "UP"
            state = "waiting-profiles"
            if not profileSyncWaitRegistered then
                profileSyncWaitRegistered = true
                PlayerProfile.onSynchronized(function()
                    local synchronizedModeName = pendingModeName

                    pendingModeName = nil
                    if synchronizedModeName and state == "waiting-profiles" then
                        RacePickSystem.start(synchronizedModeName)
                    end
                end)
            end
            return true
        end

        local mode = RacePickSystem.setMode(modeName or "UP")
        if not mode then
            Game.say("|cffff6060No race pick mode registered.|r")
            return false
        end
        currentMode = mode
        state = "running"
        mode:start(RacePickSystem)
        return true
    end

    function RacePickSystem.finish()
        state = "finished"
        RacePickSystem.cancelTimer()
        RacePickSystem.finishPickers()
        MapAreas.applyCameraBounds()
        if rawget(_G, "PlayerNameDisplay") then
            PlayerNameDisplay.update()
        end
        IslandDefenseMultiboard.setPhase("Game started", 0)
        Game.say("|cff80ff80Race picking complete.|r")
        PlayerProfile.captureEloMatchEligibility()
        Game.start()
    end

    local trigger = CreateTrigger()
    local i = 0
    while i < bj_MAX_PLAYER_SLOTS do
        TriggerRegisterPlayerUnitEvent(trigger, Player(i), EVENT_PLAYER_UNIT_SELL_ITEM, nil)
        i = i + 1
    end
    TriggerAddAction(trigger, function()
        local buyer = GetBuyingUnit()
        local item = GetSoldItem()
        local playerData = PlayerData.get(GetOwningPlayer(buyer))
        local handled = nil
        local removeSoldItem = true

        if not playerData or playerData:picker() ~= buyer then
            return
        end

        handled = RacePickSystem.pickFromItem(playerData, GetItemTypeId(item))
        if handled == "keep-item" then
            removeSoldItem = false
        elseif handled == false and playerData:canPick() then
            playerData:setGold(playerData:gold() + 1)
        end

        if item and removeSoldItem then
            RemoveItem(item)
        end
    end)

    if rawget(_G, "Command") then
        local function randomBanCommand(args)
            local playerData = PlayerData.get(args:player())
            local max = 0
            local index = 0
            local added = 0

            if not playerData or (playerData:class() ~= PlayerData.CLASS_DEFENDER and playerData:class() ~= PlayerData.CLASS_TITAN) then
                return
            end

            if state ~= "running" or not playerData:canPick() then
                Command.say(args:player(), "|cffbb2020You can only ban races during your race selection.|r")
                return
            end

            max = maxBansFor(playerData)
            clearRandomBans(playerData, false)

            if args:count() == 0 then
                saveProfileIfLocal(playerData)
                Command.say(args:player(), "|cff90b0d0Your random-ban list has been cleared.|r")
                return
            end

            while index < args:count() do
                if added >= max then
                    Command.say(args:player(), "|cffbb2020Only " .. I2S(max) .. " races are allowed to be banned.|r")
                    break
                end

                local match = args:at(index)
                local race = findRacePartialForClass(match, playerData:class())
                if race ~= NullRace.instance() then
                    if addRandomBan(playerData, race, false) then
                        added = added + 1
                        Command.say(args:player(), "|cff90b0d0Banned |r" .. race:toString() ..
                            "|cff90b0d0 from being randomed (|r" .. I2S(added) ..
                            "|cff90b0d0/|r" .. I2S(max) .. "|cff90b0d0).|r")
                    end
                else
                    Command.say(args:player(), "|cffbb2020Unknown or conflicting race: |r" .. match)
                end

                index = index + 1
            end

            saveProfileIfLocal(playerData)
            if added == 0 then
                Command.say(args:player(), "|cff90b0d0No random bans active.|r")
            end
        end

        Command["-pick"].register(function(args)
            local playerData = PlayerData.get(args:player())
            local race = Races.fromNamePartial(args:joinedFrom(0), true)
            if RacePickSystem.pick(playerData, race) then
                Command.say(args:player(), "|cff80ff80Picked " .. race:toString() .. ".|r")
            else
                Command.say(args:player(), "|cffff6060Could not pick that race right now.|r")
            end
        end, "Debug fallback for race picking.")

        Command["-b"].register(randomBanCommand, "Bans races from your random pool during selection.")
        Command["-ban"].register(randomBanCommand, "Bans races from your random pool during selection.")
        Command["-banrandom"].register(randomBanCommand, "Bans races from your random pool during selection.")
        Command["-bb"].register(randomBanCommand, "Bans races from your random pool during selection.")
        Command["-veto"].register(randomBanCommand, "Bans races from your random pool during selection.")
    end

    _G.RacePickSystem = RacePickSystem
end)

if Debug and Debug.endFile then Debug.endFile() end
