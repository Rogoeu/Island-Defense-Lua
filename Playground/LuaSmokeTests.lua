if Debug and Debug.beginFile then Debug.beginFile("Playground/LuaSmokeTests") end

OnInit("LuaSmokeTests", function(import)
    import.strict("CommandRegistry")
    import.strict("DebugCheatPack")
    import.strict("GameSettings")
    import.strict("StringLib")
    import.strict("ObjectIds")
    import.strict("IslandDefenseGameMode")
    import.strict("UnitSpawner")

    local function assertEqual(name, actual, expected)
        if actual ~= expected then
            return false, name .. " expected `" .. tostring(expected) .. "` got `" .. tostring(actual) .. "`"
        end
        return true, name .. " ok"
    end

    local function run(player)
        local checks = {}

        GameSettings.setBool("LUATEST_BOOL", true)
        checks[#checks + 1] = { assertEqual("GameSettings bool", GameSettings.getBool("LUATEST_BOOL"), true) }

        GameSettings["LUATEST_INT"] = "42"
        checks[#checks + 1] = { assertEqual("GameSettings int", GameSettings.getInt("LUATEST_INT"), 42) }

        checks[#checks + 1] = { assertEqual("StringTrim", StringTrim("  Island Defense  "), "Island Defense") }
        checks[#checks + 1] = { assertEqual("StringIndexOf", StringIndexOf("Island Defense", "def", false), 7) }
        checks[#checks + 1] = { assertEqual("StringReplace", StringReplace("a-b-a", "a", "x", true), "x-b-x") }

        local segments = StringSegments.create("red blue  teal", " ")
        checks[#checks + 1] = { assertEqual("StringSegments count", segments:countSegments(), 3) }
        checks[#checks + 1] = { assertEqual("StringSegments next", segments:nextSegment(), "red") }

        ObjectIds.register("LuaTestUnit", "hfoo")
        checks[#checks + 1] = { assertEqual("ObjectIds has", ObjectIds.has("LuaTestUnit"), true) }

        checks[#checks + 1] = { assertEqual("Race count", Races.count(), 33) }
        checks[#checks + 1] = { assertEqual("Race partial", Races.fromNamePartial("Ara", true):toString(), "Arachnid") }
        checks[#checks + 1] = { assertEqual("Titan race", Races.fromName("Arborius"):class(), PlayerData.CLASS_TITAN) }

        local playerData = PlayerData.register(player)
        playerData:setClass(PlayerData.CLASS_DEFENDER)
        playerData:setRace(Races.fromName("Arachnid"))
        checks[#checks + 1] = { assertEqual("PlayerData class", playerData:class(), PlayerData.CLASS_DEFENDER) }
        checks[#checks + 1] = { assertEqual("PlayerData race", playerData:race():toString(), "Arachnid") }

        checks[#checks + 1] = { assertEqual("Game mode", Game.mode():shortName(), "ID") }
        checks[#checks + 1] = { assertEqual("Game state", Game.stateString(Game.STATE_IDLE), "STATE_IDLE") }
        checks[#checks + 1] = { assertEqual("Spawner rawcode", UnitSpawner.ids.DEFENDER_PICK_BASER, FourCC("n01G")) }

        return checks
    end

    Command["-luatest"].register(function(args)
        if not DebugCheatPack.isEnabled(args:player()) then
            return
        end
        local player = args:player()
        local checks = run(player)
        local failed = 0

        local i = 1
        while i <= #checks do
            local ok = checks[i][1]
            local message = checks[i][2]
            if ok then
                Command.say(player, "|cff80ff80" .. message .. "|r")
            else
                failed = failed + 1
                Command.say(player, "|cffff6060" .. message .. "|r")
            end
            i = i + 1
        end

        if failed == 0 then
            Command.say(player, "|cff80ff80Lua smoke tests passed.|r")
        else
            Command.say(player, "|cffff6060Lua smoke tests failed: " .. I2S(failed) .. "|r")
        end
    end, "Runs Lua migration smoke tests.")
end)

if Debug and Debug.endFile then Debug.endFile() end
