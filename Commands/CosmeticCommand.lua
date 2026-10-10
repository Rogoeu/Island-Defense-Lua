if Debug and Debug.beginFile then Debug.beginFile("Commands/CosmeticCommand") end

OnInit("CosmeticCommand", function(import)
    import.strict("CommandRegistry")
    import.strict("Cosmetics")

    local function redeem(args)
        local player = args:player()
        local code = args:joinedFrom(0)
        local success, cosmetic, reason = Cosmetics.redeemCode(player, code)

        if not success then
            Command.say(player, "|cffff6060Unknown cosmetic code.|r")
        elseif reason == "already-unlocked" then
            Command.say(player, "|cff99b4d1Already unlocked: |r|cffffff80" .. cosmetic.name .. "|r")
        else
            Command.say(player, "|cff80ff80Cosmetic unlocked: |r|cffffff80" .. cosmetic.name .. "|r")
        end
    end

    Command["-cosmetic"].register(redeem, "Unlocks a cosmetic code: -cosmetic <code>")
    Command["-redeem"].register(redeem, "Alias for -cosmetic <code>.")
end)

if Debug and Debug.endFile then Debug.endFile() end
