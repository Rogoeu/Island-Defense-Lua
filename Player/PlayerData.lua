if Debug and Debug.beginFile then Debug.beginFile("Player/PlayerData") end

OnInit("PlayerData", function(import)
    import.strict("Races")

    local players = {}
    local lastPlayers = {}
    local mainUnits = {}

    local PlayerData = {
        CLASS_NONE = 0,
        CLASS_MINION = 1,
        CLASS_TITAN = 2,
        CLASS_DEFENDER = 3,
        CLASS_OBSERVER = 4,
        MaxPlayers = bj_MAX_PLAYER_SLOTS
    }

    local PlayerDataObject = {}
    PlayerDataObject.__index = PlayerDataObject

    local PlayerDataArray = {}
    PlayerDataArray.__index = PlayerDataArray

    function PlayerDataArray.create()
        return setmetatable({ items = {} }, PlayerDataArray)
    end

    function PlayerDataArray:append(value)
        self.items[#self.items + 1] = value
    end

    function PlayerDataArray:size()
        return #self.items
    end

    function PlayerDataArray:at(index)
        return self.items[index + 1]
    end

    function PlayerDataArray:indexOf(value)
        local i = 1
        while i <= #self.items do
            if self.items[i] == value then
                return i - 1
            end
            i = i + 1
        end
        return -1
    end

    function PlayerDataArray:destroy()
        self.items = {}
    end

    setmetatable(PlayerDataArray, {
        __call = function(_, index)
            return players[index]
        end
    })

    function PlayerDataObject:player()
        return self.playerValue
    end

    function PlayerDataObject:id()
        return self.idValue
    end

    function PlayerDataObject:name()
        if self.fakeValue then
            return "Fake Player " .. I2S(self.idValue + 1)
        end
        return self:originalName()
    end

    -- Keep the complete BattleTag as the immutable profile identity, but let
    -- presentation UIs show the readable name without its numeric tag.
    function PlayerDataObject:displayName()
        if self.fakeValue then
            return self:name()
        end
        return string.gsub(self:originalName(), "#%d+$", "")
    end

    -- Lobby identity is immutable for the current match. Display systems may use
    -- SetPlayerName later, but save data must remain bound to this original name.
    function PlayerDataObject:originalName()
        return self.originalNameValue
    end

    function PlayerDataObject:nameColored()
        local playerColors = rawget(_G, "PlayerColorUtils")
        if playerColors and playerColors.wrap then
            return playerColors.wrap(self.playerValue, self:displayName())
        end
        return self:displayName()
    end

    function PlayerDataObject:class()
        return self.classValue
    end

    function PlayerDataObject:initialClass()
        return self.initialClassValue or PlayerData.CLASS_NONE
    end

    function PlayerDataObject:isClass(classValue)
        return self.classValue == classValue
    end

    function PlayerDataObject:setClass(classValue)
        self.classValue = classValue or PlayerData.CLASS_NONE
        if (self.initialClassValue or PlayerData.CLASS_NONE) == PlayerData.CLASS_NONE then
            if self.classValue == PlayerData.CLASS_TITAN or
                self.classValue == PlayerData.CLASS_DEFENDER or
                self.classValue == PlayerData.CLASS_OBSERVER then
                self.initialClassValue = self.classValue
            end
        end
        if rawget(_G, "PlayerNameDisplay") then
            PlayerNameDisplay.update()
        end
    end

    function PlayerDataObject:resetClass()
        self.classValue = PlayerData.CLASS_NONE
        self.initialClassValue = PlayerData.CLASS_NONE
        if rawget(_G, "PlayerNameDisplay") then
            PlayerNameDisplay.update()
        end
    end

    function PlayerDataObject:race()
        return self.raceValue or NullRace.instance()
    end

    function PlayerDataObject:setRace(race)
        self.raceValue = race or NullRace.instance()
        if rawget(_G, "PlayerNameDisplay") then
            PlayerNameDisplay.update()
        end
    end

    function PlayerDataObject:unit()
        return self.unitValue
    end

    function PlayerDataObject:setUnit(unitValue)
        self.unitValue = unitValue
        if unitValue then
            -- Keep this identity after setUnit(nil): death/leave processing can
            -- outlive the active player slot while the unit handle still exists.
            mainUnits[GetHandleId(unitValue)] = {
                unit = unitValue,
                playerData = self,
                classValue = self.classValue
            }
        end
    end

    function PlayerDataObject:hunter()
        return self.hunterValue
    end

    function PlayerDataObject:setHunter(unitValue)
        self.hunterValue = unitValue
    end

    function PlayerDataObject:picker()
        return self.pickerValue
    end

    function PlayerDataObject:setPicker(unitValue)
        self.pickerValue = unitValue
    end

    function PlayerDataObject:hasPicked()
        return self.pickedValue
    end

    function PlayerDataObject:setPicked(value)
        self.pickedValue = value == true
    end

    function PlayerDataObject:canPick()
        return self.canPickValue
    end

    function PlayerDataObject:setCanPick(value)
        self.canPickValue = value == true
    end

    function PlayerDataObject:isRandoming()
        return self.randomingValue == true
    end

    function PlayerDataObject:setRandoming(value)
        self.randomingValue = value == true
    end

    function PlayerDataObject:observeTeam()
        return self.observeTeamValue or ""
    end

    function PlayerDataObject:setObserveTeam(value)
        self.observeTeamValue = tostring(value or "")
    end

    function PlayerDataObject:isObserver()
        return self.observerValue == true
    end

    function PlayerDataObject:setObserver(value)
        self.observerValue = value == true
    end

    function PlayerDataObject:gold()
        return GetPlayerState(self.playerValue, PLAYER_STATE_RESOURCE_GOLD)
    end

    function PlayerDataObject:setGold(value)
        SetPlayerState(self.playerValue, PLAYER_STATE_RESOURCE_GOLD, value or 0)
    end

    function PlayerDataObject:lumber()
        return GetPlayerState(self.playerValue, PLAYER_STATE_RESOURCE_LUMBER)
    end

    function PlayerDataObject:setLumber(value)
        SetPlayerState(self.playerValue, PLAYER_STATE_RESOURCE_LUMBER, value or 0)
    end

    function PlayerDataObject:isLeaving()
        return self.leavingValue
    end

    function PlayerDataObject:setLeaving(value)
        self.leavingValue = value == true
    end

    function PlayerDataObject:hasLeft()
        return self.leftValue
    end

    function PlayerDataObject:setLeft(value)
        self.leftValue = value == true
    end

    function PlayerDataObject:isFake()
        return self.fakeValue
    end

    function PlayerDataObject:setFake(value)
        self.fakeValue = value == true
    end

    function PlayerDataObject:say(text)
        DisplayTimedTextToPlayer(self.playerValue, 0, 0, 15, text)
    end

    function PlayerData.register(player)
        local id = GetPlayerId(player)
        local existing = players[id]
        if existing then
            return existing
        end

        local this = setmetatable({
            playerValue = player,
            idValue = id,
            originalNameValue = GetPlayerName(player),
            classValue = PlayerData.CLASS_NONE,
            initialClassValue = PlayerData.CLASS_NONE,
            raceValue = NullRace.instance(),
            unitValue = nil,
            hunterValue = nil,
            pickerValue = nil,
            pickedValue = false,
            canPickValue = false,
            randomingValue = false,
            observeTeamValue = "",
            observerValue = false,
            leavingValue = false,
            leftValue = false,
            fakeValue = false
        }, PlayerDataObject)

        players[id] = this
        lastPlayers[id] = this
        return this
    end

    function PlayerData.registerFake(player)
        local this = PlayerData.register(player)
        this:setFake(true)
        this:setLeaving(false)
        this:setLeft(false)
        return this
    end

    function PlayerData.clear()
        players = {}
        mainUnits = {}
    end

    function PlayerData.mainUnitRecord(unit)
        local id = unit and GetHandleId(unit) or 0
        local record = id ~= 0 and mainUnits[id] or nil

        if not record or record.unit ~= unit then
            return nil
        end
        if GetUnitTypeId(unit) == 0 then
            mainUnits[id] = nil
            return nil
        end
        return record
    end

    function PlayerData.mainUnitData(unit)
        local record = PlayerData.mainUnitRecord(unit)
        return record and record.playerData or nil
    end

    function PlayerData.mainUnitClass(unit)
        local record = PlayerData.mainUnitRecord(unit)
        return record and record.classValue or PlayerData.CLASS_NONE
    end

    function PlayerData.get(player)
        return players[GetPlayerId(player)]
    end

    function PlayerData.has(player)
        return PlayerData.get(player) ~= nil
    end

    function PlayerData.hasById(id)
        return players[id] ~= nil
    end

    function PlayerData.remove(player)
        players[GetPlayerId(player)] = nil
    end

    function PlayerData.at(index)
        return players[index]
    end

    function PlayerData.count()
        local count = 0
        local i = 0
        while i < PlayerData.MaxPlayers do
            if players[i] then
                count = count + 1
            end
            i = i + 1
        end
        return count
    end

    function PlayerData.countReal()
        local list = PlayerData.allReal()
        local count = list:size()
        list:destroy()
        return count
    end

    function PlayerData.countFake()
        local count = 0
        local i = 0
        while i < PlayerData.MaxPlayers do
            if players[i] and players[i]:isFake() and not players[i]:hasLeft() then
                count = count + 1
            end
            i = i + 1
        end
        return count
    end

    function PlayerData.allWithFake()
        local list = PlayerDataArray.create()
        local i = 0
        while i < PlayerData.MaxPlayers do
            if players[i] and not players[i]:hasLeft() then
                list:append(players[i])
            end
            i = i + 1
        end
        return list
    end

    function PlayerData.allWithFakeAndLeft()
        local list = PlayerDataArray.create()
        local i = 0
        while i < PlayerData.MaxPlayers do
            if players[i] then
                list:append(players[i])
            end
            i = i + 1
        end
        return list
    end

    function PlayerData.all()
        local list = PlayerDataArray.create()
        local i = 0
        while i < PlayerData.MaxPlayers do
            if players[i] and not players[i]:hasLeft() then
                list:append(players[i])
            end
            i = i + 1
        end
        return list
    end

    function PlayerData.allReal()
        local list = PlayerDataArray.create()
        local i = 0
        while i < PlayerData.MaxPlayers do
            if players[i] and not players[i]:isLeaving() and not players[i]:hasLeft() and not players[i]:isFake() then
                list:append(players[i])
            end
            i = i + 1
        end
        return list
    end

    function PlayerData.playingReal()
        local list = PlayerDataArray.create()
        local maxActive = 11
        local i = 0

        if rawget(_G, "GameSettings") then
            maxActive = GameSettings.getInt("MAX_ACTIVE_PLAYERS")
            if maxActive <= 0 then
                maxActive = 11
            end
        end

        while i < PlayerData.MaxPlayers and i < maxActive do
            if players[i] and not players[i]:isLeaving() and not players[i]:hasLeft() and not players[i]:isFake() and not players[i]:isObserver() then
                list:append(players[i])
            end
            i = i + 1
        end

        return list
    end

    function PlayerData.observers()
        local list = PlayerDataArray.create()
        local maxActive = 11
        local i = 0

        if rawget(_G, "GameSettings") then
            maxActive = GameSettings.getInt("MAX_ACTIVE_PLAYERS")
            if maxActive <= 0 then
                maxActive = 11
            end
        end

        while i < PlayerData.MaxPlayers do
            if players[i] and not players[i]:isLeaving() and not players[i]:hasLeft() and not players[i]:isFake() then
                if players[i]:isObserver() or (i >= maxActive and players[i]:class() == PlayerData.CLASS_NONE) then
                    list:append(players[i])
                end
            end
            i = i + 1
        end

        return list
    end

    function PlayerData.ensureFakePlayersWhenAlone(targetCount)
        targetCount = targetCount or 11

        if PlayerData.countReal() ~= 1 then
            return 0
        end

        local added = 0
        local i = 0
        while i < PlayerData.MaxPlayers and PlayerData.count() < targetCount do
            if not players[i] then
                PlayerData.registerFake(Player(i))
                added = added + 1
            end
            i = i + 1
        end

        return added
    end

    function PlayerData.withClass(classValue)
        local list = PlayerDataArray.create()
        local i = 0
        while i < PlayerData.MaxPlayers do
            if players[i] and not players[i]:hasLeft() and players[i]:class() == classValue then
                list:append(players[i])
            end
            i = i + 1
        end
        return list
    end

    function PlayerData.countClass(classValue)
        local list = PlayerData.withClass(classValue)
        local count = list:size()
        list:destroy()
        return count
    end

    function PlayerData.classToString(classValue)
        if classValue == PlayerData.CLASS_NONE then
            return ""
        elseif classValue == PlayerData.CLASS_MINION then
            return "Minion"
        elseif classValue == PlayerData.CLASS_TITAN then
            return "Titan"
        elseif classValue == PlayerData.CLASS_DEFENDER then
            return "Defender"
        elseif classValue == PlayerData.CLASS_OBSERVER then
            return "Observer"
        end
        return "Unknown #" .. I2S(classValue)
    end

    setmetatable(PlayerData, {
        __index = function(_, index)
            if type(index) == "number" then
                return players[index]
            end
            return nil
        end
    })

    _G.PlayerData = PlayerData
    _G.PlayerDataArray = PlayerDataArray
end)

if Debug and Debug.endFile then Debug.endFile() end
