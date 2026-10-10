if Debug and Debug.beginFile then Debug.beginFile("Abilities/Builders/TrollStructureAbilities") end

OnInit("TrollStructureAbilities", function(import)
    import.strict("AbilityRegistry")
    import.strict("PlayerData")
    import.strict("DebugCheatPack")

    local IDS = {
        TROLL_WORKER = FourCC("h03R")
    }

    local TrollStructureAbilities = {}

    local function isTrollPlayer(player)
        local playerData = PlayerData.get(player)
        local race = playerData and playerData:race() or nil
        return race and race ~= NullRace.instance() and race:toString() == "Troll"
    end

    function TrollStructureAbilities.lockWorker(player)
        SetPlayerTechMaxAllowed(player, IDS.TROLL_WORKER, 0)
    end

    function TrollStructureAbilities.unlockWorker(player)
        SetPlayerTechMaxAllowed(player, IDS.TROLL_WORKER, -1)
    end

    local function requireDebug(player)
        if DebugCheatPack.isEnabled(player) then
            return true
        end
        Command.say(player, "|cffff6060This command is only available in debug lobbies.|r")
        return false
    end

    if rawget(_G, "Command") then
        Command["-trollworker"].register(function(args)
            local player = args:player()
            if not requireDebug(player) then
                return
            end
            if isTrollPlayer(player) then
                TrollStructureAbilities.unlockWorker(player)
                Command.say(player, "|cff80ff80Troll Workers unlocked for testing.|r")
            else
                Command.say(player, "|cffff6060You need to be Troll to use this test unlock.|r")
            end
        end, "Debug: unlocks Troll Workers.")
    end

    AbilityRegistry.registerRace("Troll", "structures", {
        notes = "Troll structure availability ported from old defender preparation tech locks.",
        abilities = {
            {
                name = "Troll Worker lock",
                id = IDS.TROLL_WORKER,
                source = "old defender preparation tech lock",
                behavior = "h03R starts disabled. Later Troll research ports can call TrollStructureAbilities.unlockWorker(player); -trollworker unlocks it in debug tests."
            }
        }
    })

    _G.TrollStructureAbilities = TrollStructureAbilities
end)

if Debug and Debug.endFile then Debug.endFile() end
