if Debug and Debug.beginFile then Debug.beginFile("Commands/ClearMessagesCommand") end

OnInit("ClearMessagesCommand", function(import)
    import.strict("CommandRegistry")
    import.strict("GameTimer")

    local permanentClear = {}

    local function clearForPlayer(player)
        if not rawget(_G, "ClearTextMessages") then
            return
        end

        -- The chat event fires before Warcraft adds the submitted line to the
        -- message log. Clearing on the next timer tick removes that line too.
        GameTimer.after(0.0, function()
            if GetLocalPlayer() == player then
                ClearTextMessages()
            end
        end)
    end

    local function setPermanentClear(player, enabled)
        permanentClear[GetPlayerId(player)] = enabled == true
        clearForPlayer(player)
    end

    Command["-cls"].register(function(args)
        clearForPlayer(args:player())
    end, "Clears your text messages.")

    Command["-clear"].register(function(args)
        clearForPlayer(args:player())
    end, "Alias for -cls.")

    Command["-permacls"].register(function(args)
        local player = args:player()
        local id = GetPlayerId(player)
        local value = StringCase(tostring(args:at(0) or ""), false)
        local enabled = permanentClear[id] ~= true

        if value == "on" then
            enabled = true
        elseif value == "off" then
            enabled = false
        end

        setPermanentClear(player, enabled)
        if enabled then
            Command.say(player, "|cff99b4d1Permanent message clearing enabled.|r")
        else
            Command.say(player, "|cff99b4d1Permanent message clearing disabled.|r")
        end
    end, "Toggles automatic text-message clearing: -permacls on/off.")

    GameTimer.every(0.03, function()
        local player = GetLocalPlayer()

        if permanentClear[GetPlayerId(player)] then
            ClearTextMessages()
        end
    end)
end)

if Debug and Debug.endFile then Debug.endFile() end
