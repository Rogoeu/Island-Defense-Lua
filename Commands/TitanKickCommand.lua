if Debug and Debug.beginFile then Debug.beginFile("Commands/TitanKickCommand") end

OnInit("TitanKickCommand", function(import)
    import.strict("CommandRegistry")
    import.strict("PlayerData")
    import.strict("ObserverCommand")
    import.strict("IslandDefenseMultiboard")

    local function normalized(text)
        return StringCase(tostring(text or ""), false)
    end

    local function isMinion(playerData)
        return playerData and playerData:class() == PlayerData.CLASS_MINION
    end

    local function findMinionByQuery(query)
        local wanted = normalized(query)
        local numeric = tonumber(wanted or "")
        local list = PlayerData.withClass(PlayerData.CLASS_MINION)
        local found = nil
        local i = 0

        if wanted == "" then
            if list:size() == 1 then
                found = list:at(0)
            end
            list:destroy()
            return found
        end

        while i < list:size() do
            local playerData = list:at(i)
            local id = playerData:id()
            local name = normalized(playerData:name())

            if numeric and (numeric == id or numeric == id + 1) then
                if found then
                    list:destroy()
                    return nil
                end
                found = playerData
            elseif name == wanted or StringIndexOf(name, wanted, false) == 0 then
                if found then
                    list:destroy()
                    return nil
                end
                found = playerData
            end

            i = i + 1
        end

        list:destroy()
        return found
    end

    local function transferMinionToTitan(titanData, minionData)
        local group = CreateGroup()
        GroupEnumUnitsOfPlayer(group, minionData:player(), nil)

        local unit = FirstOfGroup(group)
        while unit do
            GroupRemoveUnit(group, unit)
            SetUnitOwner(unit, titanData:player(), true)
            unit = FirstOfGroup(group)
        end

        DestroyGroup(group)

        titanData:setGold(titanData:gold() + minionData:gold())
        titanData:setLumber(titanData:lumber() + minionData:lumber())
        minionData:setGold(0)
        minionData:setLumber(0)
        minionData:setUnit(nil)
    end

    local function kick(titanData, minionData)
        transferMinionToTitan(titanData, minionData)
        ObserverCommand.applyObserverView(minionData, "builder")
        IslandDefenseMultiboard.refresh()

        Game.say(minionData:nameColored() ..
            "|cff00bfff is now an observer of the defenders. Should this player become an annoyance you can remove them by using the -boot command.|r")
    end

    Command["-kick"].register(function(args)
        local titanData = PlayerData.get(args:player())
        local target = nil

        if not titanData or titanData:class() ~= PlayerData.CLASS_TITAN then
            return
        end

        target = findMinionByQuery(args:joinedFrom(0))
        if not isMinion(target) then
            Command.say(args:player(), "|cffff0000The player you specified was not a minion player.|r")
            return
        end

        kick(titanData, target)
    end, "Titan: kicks a minion to Builder observer.")

    _G.TitanKickCommand = {
        kick = kick,
        findMinionByQuery = findMinionByQuery
    }
end)

if Debug and Debug.endFile then Debug.endFile() end
