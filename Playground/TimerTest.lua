if Debug and Debug.beginFile then Debug.beginFile("Playground/TimerTest") end

OnInit("TimerTest", function(import)
    import.strict("CommandRegistry")
    import.strict("DebugCheatPack")
    import.strict("GameTimer")

    Command["-timertest"].register(function(args)
        local player = args:player()
        local tick = 0

        if not DebugCheatPack.isEnabled(player) then
            return
        end

        Command.say(player, "|cff99b4d1Timer test started.|r")

        local timer
        timer = GameTimer.every(1.0, function()
            tick = tick + 1
            Command.say(player, "|cff80ff80Timer tick " .. I2S(tick) .. "|r")

            if tick >= 3 then
                timer:destroy()
                Command.say(player, "|cff80ff80Timer test complete.|r")
            end
        end)
    end, "Runs a three tick GameTimer test.")
end)

if Debug and Debug.endFile then Debug.endFile() end
