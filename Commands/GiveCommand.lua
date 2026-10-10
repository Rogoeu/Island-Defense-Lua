if Debug and Debug.beginFile then Debug.beginFile("Commands/GiveCommand") end

OnInit("GiveCommand", function(import)
    import.strict("CommandRegistry")
    import.strict("PlayerData")

    local function normalized(text)
        return StringCase(tostring(text or ""), false)
    end

    local function isTitanSide(playerData)
        return playerData and (
            playerData:class() == PlayerData.CLASS_TITAN or
            playerData:class() == PlayerData.CLASS_MINION
        )
    end

    local function isActiveMinion(playerData)
        return playerData and
            playerData:class() == PlayerData.CLASS_MINION and
            not playerData:isFake() and
            not playerData:isLeaving() and
            not playerData:hasLeft()
    end

    local function findTitanSideByQuery(query)
        local wanted = normalized(query)
        local numeric = tonumber(wanted or "")
        local list = PlayerData.allReal()
        local found = nil
        local i = 0

        while i < list:size() do
            local playerData = list:at(i)
            local id = playerData:id()
            local name = normalized(playerData:name())
            local displayName = normalized(playerData:displayName())

            if isTitanSide(playerData) then
                if numeric and (numeric == id or numeric == id + 1) then
                    if found then
                        list:destroy()
                        return nil
                    end
                    found = playerData
                elseif wanted ~= "" and (
                    name == wanted or
                    displayName == wanted or
                    StringIndexOf(name, wanted, false) == 0 or
                    StringIndexOf(displayName, wanted, false) == 0
                ) then
                    if found then
                        list:destroy()
                        return nil
                    end
                    found = playerData
                end
            end
            i = i + 1
        end

        list:destroy()
        return found
    end

    local function amountFromArgs(args, giverData)
        local amount = nil

        if args:count() > 1 then
            amount = tonumber(args:at(1) or "")
            if amount then
                amount = R2I(amount)
                if giverData:gold() < amount then
                    amount = giverData:gold()
                end
            end
        else
            amount = giverData:gold()
        end

        return amount or 0
    end

    Command["-give"].register(function(args)
        local giverData = PlayerData.get(args:player())
        local receiverData = nil
        local amount = 0

        if not isTitanSide(giverData) then
            return
        end

        receiverData = findTitanSideByQuery(args:at(0))
        if not receiverData then
            Command.say(args:player(), "|cffff0000Please specify a valid player.|r")
            return
        end

        amount = amountFromArgs(args, giverData)
        if amount <= 0 then
            Command.say(args:player(), "|cff00bfffCommand Usage: -give <player> [amount]|r")
            return
        end

        if amount == giverData:gold() then
            giverData:say("|cff00bfffYou have given|r " .. receiverData:nameColored() .. " |cff00bfffall of your gold.|r")
        else
            giverData:say("|cff00bfffYou have given|r " .. receiverData:nameColored() .. " |cffffff00" .. I2S(amount) .. " |r|cff00bfffgold|r.")
        end
        giverData:setGold(giverData:gold() - amount)
        receiverData:setGold(receiverData:gold() + amount)
        receiverData:say("|cff00bfffYou have received|r |cffffff00" .. I2S(amount) .. " |r|cff00bfffgold from |r" ..
            giverData:nameColored() .. "|cff00bfff.|r")
    end, "Titan/Minion: gives gold to another Titan-side player.")

    Command["-collect"].register(function(args)
        local titanData = PlayerData.get(args:player())
        local list = nil
        local total = 0
        local i = 0

        if not titanData or titanData:class() ~= PlayerData.CLASS_TITAN then
            return
        end

        list = PlayerData.withClass(PlayerData.CLASS_MINION)
        while i < list:size() do
            local minionData = list:at(i)
            local gold = minionData:gold()

            if isActiveMinion(minionData) and gold > 0 then
                total = total + gold
                minionData:setGold(0)
                minionData:say("|cff99b4d1The Titan has collected your |r|cffffcc00" .. I2S(gold) .. " gold|r|cff99b4d1.|r")
            end
            i = i + 1
        end
        list:destroy()

        if total > 0 then
            titanData:setGold(titanData:gold() + total)
            titanData:say("|cff99b4d1Collected |r|cffffcc00" .. I2S(total) .. " gold|r|cff99b4d1 from your Minions.|r")
        else
            titanData:say("|cff99b4d1Your Minions have no gold to collect.|r")
        end
    end, "Titan: collects all gold from Minions.")
end)

if Debug and Debug.endFile then Debug.endFile() end
