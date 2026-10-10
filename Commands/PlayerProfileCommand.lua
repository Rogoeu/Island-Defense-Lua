if Debug and Debug.beginFile then Debug.beginFile("Commands/PlayerProfileCommand") end

OnInit("PlayerProfileCommand", function(import)
    import.strict("CommandRegistry")
    import.strict("PlayerProfile")

    local function forceSave(args)
        if GetLocalPlayer() ~= args:player() then
            return
        end

        if PlayerProfile.saveAllPlayers() then
            Command.say(args:player(), "|cff80ff80Profile saved locally: |r|cffffff80" .. PlayerProfile.localSavePath() .. "|r")
        else
            Command.say(args:player(), "|cffff6060Could not save the local profile.|r")
        end
    end

    Command["-profilesave"].register(forceSave, "Forces an immediate local PlayerProfile save.")
    Command["-saveprofile"].register(forceSave, "Alias for -profilesave.")
    Command["-forcesave"].register(forceSave, "Alias for -profilesave.")
end)

if Debug and Debug.endFile then Debug.endFile() end
