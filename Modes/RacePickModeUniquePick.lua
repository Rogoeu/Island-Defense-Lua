if Debug and Debug.beginFile then Debug.beginFile("Modes/RacePickModeUniquePick") end

OnInit("RacePickModeUniquePick", function(import)
    import.strict("RacePickSystem")

    local mode = {}
    local choices = {}
    local DEFENDER_PICK_BONUS_SECONDS = 5.0

    local function maxChoices()
        local count = GameSettings.getInt("UNIQUE_PICK_MAX_CHOICES")
        if count <= 0 then count = 6 end
        return count
    end

    local function defenderPickSeconds()
        local seconds = GameSettings.getReal("DEFENDER_PICK_TIME")
        if seconds <= 0 then seconds = 10.0 end
        return seconds + DEFENDER_PICK_BONUS_SECONDS
    end

    local function titanPickSeconds()
        local seconds = GameSettings.getReal("TITAN_PICK_TIME")
        if seconds <= 0 then seconds = 10.0 end
        return seconds
    end

    local function defenderRaces()
        local result = {}
        local all = Races.all()
        local i = 1
        while i <= #all do
            -- Unique Pick must reserve every race that can be selected from
            -- the shop. Some manually selectable races, such as Huntress, are
            -- intentionally excluded only from random assignments.
            if all[i]:class() == PlayerData.CLASS_DEFENDER and all[i]:itemId() ~= 0 then
                result[#result + 1] = all[i]
            end
            i = i + 1
        end
        return result
    end

    local function removeRace(pool, race)
        local i = 1
        while i <= #pool do
            if pool[i] == race then
                table.remove(pool, i)
                return
            end
            i = i + 1
        end
    end

    local function randomFromPool(pool, playerData)
        local options = {}
        local i = 1

        while i <= #pool do
            if pool[i]:inRandomPool() and not RacePickSystem.isRaceBanned(playerData, pool[i]) then
                options[#options + 1] = pool[i]
            end
            i = i + 1
        end

        if #options == 0 then
            return RacePickSystem.randomRaceForPlayer(playerData)
        end

        local index = GetRandomInt(1, #options)
        local race = options[index]
        removeRace(pool, race)
        return race
    end

    local function shuffle(players)
        local i = #players
        while i > 1 do
            local j = GetRandomInt(1, i)
            local temp = players[i]
            players[i] = players[j]
            players[j] = temp
            i = i - 1
        end
    end

    local function hasRace(choice, race)
        local i = 1
        while i <= #choice.races do
            if choice.races[i] == race then
                return true
            end
            i = i + 1
        end
        return false
    end

    local function isRaceAvailable(pool, race)
        local i = 1
        while i <= #pool do
            if pool[i] == race then
                return true
            end
            i = i + 1
        end
        return false
    end

    local function ensureChoice(playerData)
        local choice = choices[playerData:id()]
        if not choice then
            choice = {
                races = {},
                randomed = false,
                count = 0
            }
            choices[playerData:id()] = choice
        end
        return choice
    end

    local function choiceCount(choice)
        return choice.count or #choice.races
    end

    local function pickerHasInventorySpace(playerData)
        local picker = playerData:picker()
        local slot = 0
        if not picker then
            return false
        end

        while slot < bj_MAX_INVENTORY do
            if UnitItemInSlot(picker, slot) == nil then
                return true
            end
            slot = slot + 1
        end
        return false
    end

    local function keepSoldChoiceItem()
        local item = GetSoldItem()
        if item then
            SetItemDroppable(item, false)
            SetItemPawnable(item, false)
        end
    end

    local function grantNextPickGold(playerData, choice)
        if choiceCount(choice) < maxChoices() and pickerHasInventorySpace(playerData) then
            playerData:setGold(playerData:gold() + 1)
        else
            playerData:setCanPick(false)
            playerData:say("|cff80ff80Unique Pick list full. Waiting for resolution.|r")
        end
    end

    local function setResolvedRace(playerData, race)
        playerData:setRace(race)
        playerData:setPicked(true)
        playerData:setCanPick(false)
    end

    local function markChoice(playerData, race, randomed)
        local choice = ensureChoice(playerData)
        local limit = maxChoices()
        local pickNumber = choiceCount(choice) + 1
        local pickLabel = "Your #" .. I2S(pickNumber) .. " pick is: "

        if (not playerData:isFake()) and choiceCount(choice) >= limit then
            playerData:say("|cffff6060Unique Pick choice limit reached.|r")
            return false
        end

        if randomed then
            choice.randomed = true
            choice.count = choiceCount(choice) + 1
            playerData:setPicked(true)
            playerData:setRandoming(true)
            playerData:setCanPick(false)
            keepSoldChoiceItem()
            RacePickSystem.say(playerData, "|cff99b4d1" .. pickLabel .. "|r|cffffff80Random|r|cff99b4d1. Waiting for resolution.|r")
            return "keep-item"
        elseif race and race ~= NullRace.instance() then
            if choiceCount(choice) >= limit then
                playerData:say("|cffff6060Unique Pick choice limit reached.|r")
                return false
            end
            if hasRace(choice, race) then
                playerData:say("|cffffcc00That race is already in your Unique Pick list.|r")
                return false
            end

            choice.races[#choice.races + 1] = race
            choice.count = choiceCount(choice) + 1
            playerData:setPicked(true)
            playerData:setRandoming(false)
            keepSoldChoiceItem()
            RacePickSystem.say(playerData, "|cff99b4d1" .. pickLabel .. "|r|cffffff80" .. race:toString() .. "|r")
        else
            return false
        end

        grantNextPickGold(playerData, choice)
        return "keep-item"
    end

    local function enableDefenders()
        local list = PlayerData.withClass(PlayerData.CLASS_DEFENDER)
        local i = 0
        while i < list:size() do
            local playerData = list:at(i)
            playerData:setGold(0)
            playerData:setCanPick(true)
            playerData:setPicked(false)
            playerData:setRace(NullRace.instance())
            playerData:setRandoming(false)

            if playerData:isFake() then
                markChoice(playerData, NullRace.instance(), true)
            else
                UnitSpawner.spawnPicker(playerData)
                UnitSpawner.focusPickerCamera(playerData)
                playerData:setGold(1)
            end
            i = i + 1
        end
        list:destroy()
    end

    local function resolveDefenders()
        local list = PlayerData.withClass(PlayerData.CLASS_DEFENDER)
        local pool = defenderRaces()
        local randomOrder = {}
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)

            playerData:setRace(NullRace.instance())
            playerData:setCanPick(false)
            i = i + 1
        end

        i = 0
        while i < list:size() do
            local playerData = list:at(i)
            local choice = choices[playerData:id()]
            local race = NullRace.instance()
            local j = 1

            if not choice then
                choice = { races = {}, randomed = true }
                choices[playerData:id()] = choice
            end

            -- Random is the fallback for this player's priority list. A player who
            -- chose Faerie first and Random second should still receive Faerie when
            -- no other defender claimed it.
            if #choice.races > 0 then
                while j <= #choice.races and race == NullRace.instance() do
                    if isRaceAvailable(pool, choice.races[j]) then
                        race = choice.races[j]
                    end
                    j = j + 1
                end

                if race ~= NullRace.instance() then
                    playerData:setRandoming(false)
                    setResolvedRace(playerData, race)
                    removeRace(pool, race)
                else
                    randomOrder[#randomOrder + 1] = playerData
                end
            else
                randomOrder[#randomOrder + 1] = playerData
            end

            i = i + 1
        end

        shuffle(randomOrder)

        i = 1
        while i <= #randomOrder do
            local playerData = randomOrder[i]
            if playerData:race() == NullRace.instance() then
                playerData:setRandoming(true)
                setResolvedRace(playerData, randomFromPool(pool, playerData))
            end
            i = i + 1
        end

        list:destroy()
        IslandDefenseMultiboard.refresh()
    end

    local function runTitanPick(system)
        local titans = PlayerData.withClass(PlayerData.CLASS_TITAN)
        local i = 0
        while i < titans:size() do
            local playerData = titans:at(i)
            playerData:setGold(playerData:gold() + 1)
            i = i + 1
        end
        titans:destroy()

        system.enableClass(PlayerData.CLASS_TITAN)
        IslandDefenseMultiboard.setPhase("Titan picking", titanPickSeconds())
        system.setTimer(titanPickSeconds(), function()
            system.autopickClass(PlayerData.CLASS_TITAN)
            system.spawnClass(PlayerData.CLASS_TITAN)
            system.finish()
        end)
    end

    function mode:name()
        return "Unique Pick"
    end

    function mode:shortName()
        return "UP"
    end

    function mode:description()
        return "Defenders may request races, but each defender race is assigned only once."
    end

    function mode:start(system)
        choices = {}
        system.preparePickers()
        enableDefenders()

        IslandDefenseMultiboard.setPhase("Unique defender picking", defenderPickSeconds())
        system.setTimer(defenderPickSeconds(), function()
            resolveDefenders()
            system.spawnClass(PlayerData.CLASS_DEFENDER)
            runTitanPick(system)
        end)
    end

    function mode:pickFromItem(system, playerData, itemTypeId)
        if playerData:class() == PlayerData.CLASS_TITAN then
            if itemTypeId == UnitSpawner.ids.RANDOM_RACE_ITEM then
                return system.randomPick(playerData)
            end
            return nil
        end
        if playerData:class() ~= PlayerData.CLASS_DEFENDER then
            return nil
        end
        if not playerData:canPick() then
            return false
        end

        if itemTypeId == UnitSpawner.ids.RANDOM_RACE_ITEM then
            return markChoice(playerData, NullRace.instance(), true)
        end

        local race = Races.fromItemId(itemTypeId)
        if race ~= NullRace.instance() and race:class() == PlayerData.CLASS_DEFENDER then
            return markChoice(playerData, race, false)
        end

        return false
    end

    RacePickSystem.register(mode)
end)

if Debug and Debug.endFile then Debug.endFile() end
